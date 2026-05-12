/*
 * ==============================================================
 * SafeTrack ESP32 IoT Module
 * ==============================================================
 *
 * Receives telemetry data from Tang Nano 9K FPGA over UART,
 * receives GPS coordinates from NEO-6M GPS module,
 * and uploads all live telemetry to Firebase Firestore
 * using the REST API over HTTPS.
 *
 * --------------------------------------------------------------
 * DATA FLOW
 * --------------------------------------------------------------
 * Tang Nano 9K FPGA
 *        |
 *     UART 9600
 *        |
 *      ESP32
 *        |
 *    WiFi / HTTPS
 *        |
 * Firebase Firestore
 *
 * --------------------------------------------------------------
 * FPGA UART PACKET FORMAT (8 BYTES)
 * --------------------------------------------------------------
 * Byte 0 : '$'  (0x24 start marker)
 * Byte 1 : Flame Sensor      (0=SAFE, 1=UNSAFE)
 * Byte 2 : Smoke Sensor      (0=SAFE, 1=UNSAFE)
 * Byte 3 : Tilt/Crash Sensor (0=SAFE, 1=UNSAFE)
 * Byte 4 : Seat Occupied     (0=EMPTY, 1=OCCUPIED)
 * Byte 5 : Temperature       (0-99 deg C)
 * Byte 6 : Emergency Flag    (0=no, 1=yes)
 * Byte 7 : '\n' (0x0A end marker)
 *
 * --------------------------------------------------------------
 * HARDWARE CONNECTIONS
 * --------------------------------------------------------------
 * Tang Nano TX  -> ESP32 GPIO16 (RX2)
 * Tang Nano GND -> ESP32 GND          [FIX: was documented as "TX->GND"]
 * GPS TX        -> ESP32 GPIO4  (RX1)
 * GPS RX        -> ESP32 GPIO12 (TX1) [FIX: was GPIO2, a boot-strapping pin]
 * FPGA GND      -> ESP32 GND
 *
 * --------------------------------------------------------------
 * REQUIRED LIBRARIES
 * --------------------------------------------------------------
 * ArduinoJson
 * TinyGPSPlus
 *
 * --------------------------------------------------------------
 * secrets.h FORMAT
 * --------------------------------------------------------------
 * #define SECRET_WIFI_SSID     "YOUR_WIFI"
 * #define SECRET_WIFI_PASSWORD "YOUR_PASSWORD"
 * #define SECRET_FIREBASE_PROJECT_ID "YOUR_PROJECT_ID"
 * #define SECRET_FIREBASE_API_KEY    "YOUR_API_KEY"
 *
 * ==============================================================
 */

#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <TinyGPSPlus.h>
#include <WiFi.h>
#include <WiFiClientSecure.h> // FIX: required for HTTPS to Firestore
#include <time.h>

#include "secrets.h"

// =============================================================
// WIFI CONFIGURATION
// =============================================================
const char *WIFI_SSID = SECRET_WIFI_SSID;
const char *WIFI_PASSWORD = SECRET_WIFI_PASSWORD;

// =============================================================
// FIREBASE CONFIGURATION
// =============================================================
const char *FIREBASE_PROJECT_ID = SECRET_FIREBASE_PROJECT_ID;
const char *FIREBASE_API_KEY = SECRET_FIREBASE_API_KEY;

// =============================================================
// DEVICE INFORMATION
// =============================================================
const char *DEVICE_ID = "ESP32_001";
const char *BUS_ID = "N50BLz45Iv8PiRnzytKt";
const char *BUS_NUMBER = "BUS-101";

// =============================================================
// PIN DEFINITIONS
// =============================================================
#define FPGA_RX_PIN 16 // FPGA TX  -> ESP32 GPIO16 (UART2 RX)

#define GPS_RX_PIN 4 // GPS TX   -> ESP32 GPIO4  (UART1 RX)
#define GPS_TX_PIN                                                             \
  12 // GPS RX   -> ESP32 GPIO12 (UART1 TX)
     // FIX: was GPIO2 — a bootstrapping pin that
     // holds Flash to download-mode when LOW at boot.

// =============================================================
// TIMING
// =============================================================
#define SEND_INTERVAL 10000UL // 10 seconds between Firestore uploads
#define FPGA_STALE_TIMEOUT                                                     \
  30000UL                       // FIX: mark FPGA data invalid after 30s silence
#define WIFI_RETRY_DELAY 5000UL // FIX: wait 5s before retrying WiFi

// =============================================================
// SERIAL PORTS
// =============================================================
HardwareSerial fpgaSerial(2); // UART2 — FPGA telemetry
HardwareSerial gpsSerial(1);  // UART1 — NEO-6M GPS

// =============================================================
// GPS OBJECT
// =============================================================
TinyGPSPlus gps;

// =============================================================
// TIMERS
// =============================================================
unsigned long lastSendTime = 0;

// =============================================================
// LAST VALID GPS VALUES  (default: Hyderabad area)
// =============================================================
double lastLat = 16.9800;
double lastLng = 82.2300;
float lastSpeed = 0.0;

// =============================================================
// FPGA DATA STRUCTURE
// =============================================================
struct FpgaData {
  bool flame = false;
  bool smoke = false;
  bool tilt = false;
  bool seatOccupied = false; // FIX: Byte 4 is seat status (0/1), not a count
  uint8_t temperature = 25;
  bool emergency = false;
  bool valid = false;
  unsigned long lastReceived = 0;
};

FpgaData fpgaData;

// =============================================================
// UART PACKET BUFFER
// =============================================================
uint8_t pktBuf[8];
uint8_t pktIdx = 0;
bool inPacket = false;

// =============================================================
// TLS CLIENT  (FIX: Firestore endpoint is HTTPS)
// =============================================================
WiFiClientSecure tlsClient;

// =============================================================
// SETUP
// =============================================================
void setup() {

  Serial.begin(115200);
  Serial.println("\n================================================");
  Serial.println("      SafeTrack ESP32 IoT Module Starting");
  Serial.println("================================================");

  WiFi.mode(WIFI_STA);

  // FPGA UART — receive only (TX pin unused, set to -1)
  fpgaSerial.begin(9600, SERIAL_8N1, FPGA_RX_PIN, -1);

  // GPS UART
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  connectWiFi();

  // FIX: skip TLS certificate verification — acceptable for IoT prototype;
  // replace with setInsecure() awareness: for production load the Google
  // root CA with tlsClient.setCACert(rootCACert).
  tlsClient.setInsecure();
}

// =============================================================
// MAIN LOOP
// =============================================================
void loop() {

  // Parse any waiting FPGA bytes
  readFpgaPacket();

  // Feed GPS bytes to TinyGPSPlus
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  // Latch valid GPS location
  if (gps.location.isValid()) {
    lastLat = gps.location.lat();
    lastLng = gps.location.lng();
  }

  // Latch valid speed
  if (gps.speed.isValid()) {
    lastSpeed = gps.speed.kmph();
  }

  // FIX: expire stale FPGA data so we don't upload 30-second-old sensor state
  if (fpgaData.valid &&
      (millis() - fpgaData.lastReceived) > FPGA_STALE_TIMEOUT) {
    fpgaData.valid = false;
    Serial.println("[FPGA] Data marked stale — no packet in 30 s");
  }

  // Periodic Firestore upload
  if (millis() - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = millis();
    printStatus();
    sendToFirestore();
  }
}

// =============================================================
// FPGA UART PACKET PARSER
// =============================================================
void readFpgaPacket() {

  while (fpgaSerial.available() > 0) {

    uint8_t b = fpgaSerial.read();

    // Start-of-packet marker
    if (b == 0x24) {
      pktIdx = 0;
      pktBuf[pktIdx++] = b;
      inPacket = true;
    } else if (inPacket) {

      if (pktIdx < 8) {
        pktBuf[pktIdx++] = b;
      }

      // Full 8-byte packet assembled
      if (pktIdx >= 8) {
        inPacket = false;

        // Validate end marker
        if (pktBuf[7] == 0x0A) {

          fpgaData.flame = (pktBuf[1] == 1);
          fpgaData.smoke = (pktBuf[2] == 1);
          fpgaData.tilt = (pktBuf[3] == 1);
          fpgaData.seatOccupied = (pktBuf[4] == 1); // FIX: 0=EMPTY 1=OCCUPIED
          fpgaData.temperature = pktBuf[5];
          fpgaData.emergency = (pktBuf[6] == 1);
          fpgaData.valid = true;
          fpgaData.lastReceived = millis();

          Serial.println("[FPGA] Valid packet received");

        } else {
          Serial.printf("[FPGA] Bad end marker: 0x%02X\n", pktBuf[7]);
        }

        pktIdx = 0;
      }
    }
  }
}

// =============================================================
// PRINT DEBUG STATUS
// =============================================================
void printStatus() {

  Serial.println("\n------------------------------------------------");

  if (fpgaData.valid) {
    unsigned long age = (millis() - fpgaData.lastReceived) / 1000;
    Serial.printf("FPGA AGE   : %lu s\n", age);
    Serial.printf(
        "FLAME=%d | SMOKE=%d | TILT=%d | SEAT=%d | TEMP=%d | EMG=%d\n",
        fpgaData.flame, fpgaData.smoke, fpgaData.tilt, fpgaData.seatOccupied,
        fpgaData.temperature, fpgaData.emergency);
  } else {
    Serial.println("[FPGA] No valid data");
  }

  Serial.printf("GPS  : %.5f , %.5f\n", lastLat, lastLng);
  Serial.printf("SPEED: %.1f km/h\n", lastSpeed);
}

// =============================================================
// SEND DATA TO FIREBASE FIRESTORE  (HTTPS POST)
// =============================================================
void sendToFirestore() {

  // Guard: ensure WiFi is up before attempting
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Disconnected — reconnecting...");
    connectWiFi();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Reconnect failed — skipping upload");
      return;
    }
  }

  // -----------------------------------------------------------
  // Resolve sensor values (default to SAFE when no FPGA data)
  // -----------------------------------------------------------
  String smokeStr = fpgaData.valid && fpgaData.smoke ? "UNSAFE" : "SAFE";
  String flameStr = fpgaData.valid && fpgaData.flame ? "UNSAFE" : "SAFE";
  String tiltStr = fpgaData.valid && fpgaData.tilt ? "UNSAFE" : "SAFE";
  bool isEmergency = fpgaData.valid && fpgaData.emergency;
  bool seatStatus = fpgaData.valid && fpgaData.seatOccupied;
  uint8_t tempVal = fpgaData.valid ? fpgaData.temperature : 0;

  // -----------------------------------------------------------
  // Build Firestore REST JSON payload
  // FIX: Firestore REST API requires integerValue to be a STRING,
  //      not a numeric literal — otherwise the field is silently dropped.
  // -----------------------------------------------------------
  StaticJsonDocument<1024> doc; // FIX: was 768 — too small for all fields
  JsonObject fields = doc.createNestedObject("fields");

  fields["deviceId"]["stringValue"] = DEVICE_ID;
  fields["busId"]["stringValue"] = BUS_ID;
  fields["busNumber"]["stringValue"] = BUS_NUMBER;
  fields["temperature"]["doubleValue"] = (double)tempVal;
  fields["smoke"]["stringValue"] = smokeStr;
  fields["flame"]["stringValue"] = flameStr;
  fields["tiltAngle"]["stringValue"] = tiltStr;
  fields["seatOccupied"]["booleanValue"] = seatStatus;

  // FIX: integerValue MUST be a JSON string in Firestore REST API
  // Passing a numeric type causes the field to be silently rejected.
  // Encode it as a string: {"integerValue": "3"} not {"integerValue": 3}
  // (We repurpose the field name to reflect actual semantics: 0 or 1)
  char seatInt[4];
  snprintf(seatInt, sizeof(seatInt), "%d", (int)seatStatus);
  fields["seatValue"]["integerValue"] = seatInt;

  fields["latitude"]["doubleValue"] = lastLat;
  fields["longitude"]["doubleValue"] = lastLng;
  fields["speed"]["doubleValue"] = (double)lastSpeed;
  fields["isEmergency"]["booleanValue"] = isEmergency;
  fields["timestamp"]["timestampValue"] = getISOTimestamp();

  String payload;
  serializeJson(doc, payload);
  Serial.println("\n[JSON PAYLOAD]");
  Serial.println(payload);

  // -----------------------------------------------------------
  // Firestore REST endpoint (POST creates a new document)
  // -----------------------------------------------------------
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += FIREBASE_PROJECT_ID;
  url += "/databases/(default)/documents/devices/";
  url += DEVICE_ID;
  url += "/readings?key=";
  url += FIREBASE_API_KEY;

  // FIX: use HTTPClient with the TLS-aware WiFiClientSecure instance
  HTTPClient http;
  http.begin(tlsClient, url);
  http.addHeader("Content-Type", "application/json");

  int httpCode = http.POST(payload);

  if (httpCode == 200 || httpCode == 201) {
    Serial.printf("[Firestore] Upload OK (HTTP %d) | SEAT=%d | TEMP=%d\n",
                  httpCode, (int)seatStatus, tempVal);
  } else {
    Serial.printf("[Firestore] Error HTTP %d\n", httpCode);
    Serial.println(http.getString());
  }

  http.end();
}

// =============================================================
// WIFI CONNECTION  (FIX: added retry backoff + NTP timeout cap)
// =============================================================
void connectWiFi() {

  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {

    Serial.printf("\n[WiFi] Connected — IP: %s\n",
                  WiFi.localIP().toString().c_str());

    // NTP sync
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    time_t now = time(nullptr);
    int ntpTries = 0;

    // FIX: original loop had no iteration limit — could block setup() forever.
    // Cap at 20 attempts (~10 s) so the device remains functional even if
    // NTP is unreachable (timestamps will be epoch-relative until synced).
    while (now < 8 * 3600 * 2 && ntpTries < 20) {
      delay(500);
      now = time(nullptr);
      ntpTries++;
    }

    if (now >= 8 * 3600 * 2) {
      Serial.println("[NTP] Time synchronized");
    } else {
      Serial.println("[NTP] Sync timed out — timestamps may be inaccurate");
    }

  } else {
    Serial.println("\n[WiFi] Connection failed");
    // FIX: back off before caller retries to avoid rapid reconnect storm
    delay(WIFI_RETRY_DELAY);
  }
}

// =============================================================
// ISO 8601 TIMESTAMP  (UTC)
// =============================================================
String getISOTimestamp() {

  time_t now = time(nullptr);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);

  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buffer);
}