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
 * Byte 4 : Passenger Count   (0 to 4)
 * Byte 5 : Temperature       (0-99 deg C)
 * Byte 6 : Emergency Flag    (0=no, 1=yes)
 * Byte 7 : '\n' (0x0A end marker)
 *
 * --------------------------------------------------------------
 * HARDWARE CONNECTIONS
 * --------------------------------------------------------------
 * Tang Nano TX  -> ESP32 GPIO16 (RX2)
 * GPS TX        -> ESP32 GPIO4
 * GPS RX        -> ESP32 GPIO2
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
 * #define SECRET_WIFI_SSID "YOUR_WIFI"
 * #define SECRET_WIFI_PASSWORD "YOUR_PASSWORD"
 * #define SECRET_FIREBASE_PROJECT_ID "YOUR_PROJECT_ID"
 * #define SECRET_FIREBASE_API_KEY "YOUR_API_KEY"
 *
 * ==============================================================
 */

#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <TinyGPSPlus.h>
#include <WiFi.h>
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
#define FPGA_RX_PIN 16

#define GPS_RX_PIN 4
#define GPS_TX_PIN 2

// =============================================================
// TIMING
// =============================================================
#define SEND_INTERVAL 10000 // 10 seconds

// =============================================================
// SERIAL PORTS
// =============================================================
HardwareSerial fpgaSerial(2);
HardwareSerial gpsSerial(1);

// =============================================================
// GPS OBJECT
// =============================================================
TinyGPSPlus gps;

// =============================================================
// TIMERS
// =============================================================
unsigned long lastSendTime = 0;

// =============================================================
// LAST VALID GPS VALUES
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

  uint8_t passengerCount = 0;

  uint8_t temperature = 25;

  bool emergency = false;

  bool valid = false;

  unsigned long lastReceived = 0;
};

FpgaData fpgaData;

// =============================================================
// UART PACKET VARIABLES
// =============================================================
uint8_t pktBuf[8];

uint8_t pktIdx = 0;

bool inPacket = false;

// =============================================================
// SETUP
// =============================================================
void setup() {

  Serial.begin(115200);

  Serial.println("\n================================================");
  Serial.println("      SafeTrack ESP32 IoT Module Starting");
  Serial.println("================================================");

  // -----------------------------------------------------------
  // WIFI STATION MODE
  // -----------------------------------------------------------
  WiFi.mode(WIFI_STA);

  // -----------------------------------------------------------
  // FPGA UART
  // -----------------------------------------------------------
  fpgaSerial.begin(9600, SERIAL_8N1, FPGA_RX_PIN, -1);

  // -----------------------------------------------------------
  // GPS UART
  // -----------------------------------------------------------
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  // -----------------------------------------------------------
  // CONNECT WIFI
  // -----------------------------------------------------------
  connectWiFi();
}

// =============================================================
// MAIN LOOP
// =============================================================
void loop() {

  // -----------------------------------------------------------
  // READ FPGA UART DATA
  // -----------------------------------------------------------
  readFpgaPacket();

  // -----------------------------------------------------------
  // READ GPS DATA
  // -----------------------------------------------------------
  while (gpsSerial.available() > 0) {

    gps.encode(gpsSerial.read());
  }

  // -----------------------------------------------------------
  // UPDATE GPS LOCATION
  // -----------------------------------------------------------
  if (gps.location.isValid()) {

    lastLat = gps.location.lat();

    lastLng = gps.location.lng();
  }

  // -----------------------------------------------------------
  // UPDATE SPEED
  // -----------------------------------------------------------
  if (gps.speed.isValid()) {

    lastSpeed = gps.speed.kmph();
  }

  // -----------------------------------------------------------
  // SEND TO FIREBASE
  // -----------------------------------------------------------
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

    // ---------------------------------------------------------
    // START MARKER
    // ---------------------------------------------------------
    if (b == 0x24) {

      pktIdx = 0;

      pktBuf[pktIdx++] = b;

      inPacket = true;

    }

    // ---------------------------------------------------------
    // STORE PACKET BYTES
    // ---------------------------------------------------------
    else if (inPacket) {

      if (pktIdx < 8) {

        pktBuf[pktIdx++] = b;
      }

      // -------------------------------------------------------
      // FULL PACKET RECEIVED
      // -------------------------------------------------------
      if (pktIdx >= 8) {

        inPacket = false;

        // -----------------------------------------------------
        // VERIFY END MARKER
        // -----------------------------------------------------
        if (pktBuf[7] == 0x0A) {

          fpgaData.flame = (pktBuf[1] == 1);

          fpgaData.smoke = (pktBuf[2] == 1);

          fpgaData.tilt = (pktBuf[3] == 1);

          fpgaData.passengerCount = pktBuf[4];

          fpgaData.temperature = pktBuf[5];

          fpgaData.emergency = (pktBuf[6] == 1);

          fpgaData.valid = true;

          fpgaData.lastReceived = millis();

          Serial.println("[FPGA] Valid packet received");

        } else {

          Serial.println("[FPGA] Invalid packet end marker");
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

    Serial.printf("FPGA AGE : %lu sec\n", age);

    Serial.printf("FLAME=%d | SMOKE=%d | TILT=%d | PAX=%d | TEMP=%d | EMG=%d\n",
                  fpgaData.flame, fpgaData.smoke, fpgaData.tilt,
                  fpgaData.passengerCount, fpgaData.temperature,
                  fpgaData.emergency);

  } else {

    Serial.println("No FPGA data yet");
  }

  Serial.printf("GPS : %.5f , %.5f\n", lastLat, lastLng);

  Serial.printf("SPEED : %.1f km/h\n", lastSpeed);
}

// =============================================================
// SEND DATA TO FIREBASE FIRESTORE
// =============================================================
void sendToFirestore() {

  // -----------------------------------------------------------
  // WIFI CHECK
  // -----------------------------------------------------------
  if (WiFi.status() != WL_CONNECTED) {

    Serial.println("WiFi disconnected. Reconnecting...");

    connectWiFi();

    return;
  }

  HTTPClient http;

  // -----------------------------------------------------------
  // FIRESTORE URL
  // -----------------------------------------------------------
  String url = "https://firestore.googleapis.com/v1/projects/";

  url += FIREBASE_PROJECT_ID;

  url += "/databases/(default)/documents/devices/";

  url += DEVICE_ID;

  url += "/readings?key=";

  url += FIREBASE_API_KEY;

  http.begin(url);

  http.addHeader("Content-Type", "application/json");

  // -----------------------------------------------------------
  // CONVERT STATUS FLAGS
  // -----------------------------------------------------------
  String smokeStr = fpgaData.smoke ? "UNSAFE" : "SAFE";

  String flameStr = fpgaData.flame ? "UNSAFE" : "SAFE";

  String tiltStr = fpgaData.tilt ? "UNSAFE" : "SAFE";

  bool isEmergency = fpgaData.emergency;

  uint8_t paxCount = fpgaData.passengerCount;

  // -----------------------------------------------------------
  // DEFAULT SAFE VALUES
  // -----------------------------------------------------------
  if (!fpgaData.valid) {

    smokeStr = "SAFE";

    flameStr = "SAFE";

    tiltStr = "SAFE";

    paxCount = 0;

    isEmergency = false;
  }

  // -----------------------------------------------------------
  // JSON DOCUMENT
  // -----------------------------------------------------------
  StaticJsonDocument<768> doc;

  JsonObject fields = doc.createNestedObject("fields");

  fields["deviceId"]["stringValue"] = DEVICE_ID;

  fields["busId"]["stringValue"] = BUS_ID;

  fields["busNumber"]["stringValue"] = BUS_NUMBER;

  fields["temperature"]["doubleValue"] = (double)fpgaData.temperature;

  fields["smoke"]["stringValue"] = smokeStr;

  fields["flame"]["stringValue"] = flameStr;

  fields["tiltAngle"]["stringValue"] = tiltStr;

  fields["passengerCount"]["integerValue"] = paxCount;

  fields["latitude"]["doubleValue"] = lastLat;

  fields["longitude"]["doubleValue"] = lastLng;

  fields["speed"]["doubleValue"] = (double)lastSpeed;

  fields["isEmergency"]["booleanValue"] = isEmergency;

  fields["timestamp"]["timestampValue"] = getISOTimestamp();

  // -----------------------------------------------------------
  // SERIALIZE JSON
  // -----------------------------------------------------------
  String payload;

  serializeJson(doc, payload);

  Serial.println("\n[JSON PAYLOAD]");
  Serial.println(payload);

  // -----------------------------------------------------------
  // SEND HTTP POST
  // -----------------------------------------------------------
  int httpCode = http.POST(payload);

  // -----------------------------------------------------------
  // RESPONSE
  // -----------------------------------------------------------
  if (httpCode == 200 || httpCode == 201) {

    Serial.printf("Firebase Upload Success | Pax=%d | Temp=%d\n", paxCount,
                  fpgaData.temperature);

  } else {

    Serial.printf("Firebase Error : %d\n", httpCode);

    Serial.println(http.getString());
  }

  http.end();
}

// =============================================================
// WIFI CONNECTION
// =============================================================
void connectWiFi() {

  Serial.printf("Connecting to WiFi : %s", WIFI_SSID);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;

  while (WiFi.status() != WL_CONNECTED && attempts < 20) {

    delay(500);

    Serial.print(".");

    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {

    Serial.printf("\nConnected! IP Address : %s\n",
                  WiFi.localIP().toString().c_str());

    // ---------------------------------------------------------
    // NTP TIME SYNC
    // ---------------------------------------------------------
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");

    time_t now = time(nullptr);

    while (now < 8 * 3600 * 2) {

      delay(500);

      now = time(nullptr);
    }

    Serial.println("NTP Time synchronized.");

  } else {

    Serial.println("\nWiFi connection failed.");
  }
}

// =============================================================
// ISO TIMESTAMP GENERATOR
// =============================================================
String getISOTimestamp() {

  time_t now = time(nullptr);

  struct tm timeinfo;

  gmtime_r(&now, &timeinfo);

  char buffer[25];

  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);

  return String(buffer);
}