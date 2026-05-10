/*
 * SafeTrack ESP32 IoT Module
 *
 * Receives sensor data from the Tang Nano 9K FPGA over UART,
 * reads GPS coordinates from a NEO-6M module, and pushes
 * all telemetry to Firebase Firestore via the REST API.
 *
 * Data flow:
 *   Tang Nano 9K (FPGA) --UART 9600--> ESP32 --WiFi/HTTPS--> Firebase
 *
 * FPGA binary packet (8 bytes):
 *   Byte 0: '$'  (0x24, start marker)
 *   Byte 1: flame    (0=SAFE, 1=UNSAFE)
 *   Byte 2: smoke    (0=SAFE, 1=UNSAFE)
 *   Byte 3: tilt     (0=SAFE, 1=UNSAFE)
 *   Byte 4: seat     (0=EMPTY, 1=OCCUPIED)
 *   Byte 5: temperature (0-99 deg C)
 *   Byte 6: emergency (0=no, 1=yes)
 *   Byte 7: '\n' (0x0A, end marker)
 *
 * Wiring:
 *   Tang Nano Pin 17 (TX) -> ESP32 GPIO16 (RX2)
 *   NEO-6M GPS TX         -> ESP32 GPIO4
 *   NEO-6M GPS RX         -> ESP32 GPIO2
 */

#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <TinyGPSPlus.h>
#include <WiFi.h>

// Credentials loaded from secrets.h (not tracked by git).
// Copy secrets.h.example to secrets.h and fill in your values.
#include "secrets.h"

const char *WIFI_SSID = SECRET_WIFI_SSID;
const char *WIFI_PASSWORD = SECRET_WIFI_PASSWORD;

// Firebase project settings
const char *FIREBASE_PROJECT_ID = SECRET_FIREBASE_PROJECT_ID;
const char *FIREBASE_API_KEY = SECRET_FIREBASE_API_KEY;

// device and bus identifiers (must match the Firestore bus document)
const char *DEVICE_ID = "ESP32_001";
const char *BUS_ID = "N50BLz45Iv8PiRnzytKt";
const char *BUS_NUMBER = "BUS-101";

// hardware pin assignments
#define FPGA_RX_PIN 16
#define GPS_RX_PIN 4
#define GPS_TX_PIN 2

#define SEND_INTERVAL 10000 // push to Firebase every 10 s

HardwareSerial fpgaSerial(2);
HardwareSerial gpsSerial(1);
TinyGPSPlus gps;

unsigned long lastSendTime = 0;
double lastLat = 16.98; // fallback coords near Aditya University
double lastLng = 82.23;
float lastSpeed = 0.0;

struct FpgaData {
  bool flame = false;
  bool smoke = false;
  bool tilt = false;
  bool seatOccupied = false;
  uint8_t temperature = 25;
  bool emergency = false;
  bool valid = false;
  unsigned long lastReceived = 0;
};
FpgaData fpgaData;

uint8_t pktBuf[8];
uint8_t pktIdx = 0;
bool inPacket = false;

void setup() {
  Serial.begin(115200);
  Serial.println("\nSafeTrack ESP32 starting...");

  fpgaSerial.begin(9600, SERIAL_8N1, FPGA_RX_PIN, -1);
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  connectWiFi();
}

void loop() {
  readFpgaPacket();

  while (gpsSerial.available() > 0)
    gps.encode(gpsSerial.read());

  if (gps.location.isValid()) {
    lastLat = gps.location.lat();
    lastLng = gps.location.lng();
  }
  if (gps.speed.isValid())
    lastSpeed = gps.speed.kmph();

  if (millis() - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = millis();
    printStatus();
    sendToFirestore();
  }
}

// parse the 8-byte binary packet from the FPGA
void readFpgaPacket() {
  while (fpgaSerial.available() > 0) {
    uint8_t b = fpgaSerial.read();

    if (b == 0x24) { // '$' = start
      pktIdx = 0;
      pktBuf[pktIdx++] = b;
      inPacket = true;
    } else if (inPacket) {
      if (pktIdx < 8)
        pktBuf[pktIdx++] = b;

      if (pktIdx >= 8) {
        inPacket = false;
        if (pktBuf[7] == 0x0A) { // valid end marker
          fpgaData.flame = (pktBuf[1] == 1);
          fpgaData.smoke = (pktBuf[2] == 1);
          fpgaData.tilt = (pktBuf[3] == 1);
          fpgaData.seatOccupied = (pktBuf[4] == 1);
          fpgaData.temperature = pktBuf[5];
          fpgaData.emergency = (pktBuf[6] == 1);
          fpgaData.valid = true;
          fpgaData.lastReceived = millis();
          Serial.println("[FPGA] packet OK");
        } else {
          Serial.println("[FPGA] bad end marker");
        }
        pktIdx = 0;
      }
    }
  }
}

void printStatus() {
  Serial.println("---");
  if (fpgaData.valid) {
    unsigned long age = (millis() - fpgaData.lastReceived) / 1000;
    Serial.printf(
        "FPGA (age %lus): flame=%d smoke=%d tilt=%d seat=%d temp=%d emg=%d\n",
        age, fpgaData.flame, fpgaData.smoke, fpgaData.tilt,
        fpgaData.seatOccupied, fpgaData.temperature, fpgaData.emergency);
  } else {
    Serial.println("No FPGA data yet");
  }
  Serial.printf("GPS: %.5f, %.5f  Speed: %.1f km/h\n", lastLat, lastLng,
                lastSpeed);
}

void sendToFirestore() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, reconnecting...");
    connectWiFi();
    return;
  }

  HTTPClient http;
  // MAC-address-based Firestore path: devices/{deviceId}/readings
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += FIREBASE_PROJECT_ID;
  url += "/databases/(default)/documents/devices/";
  url += DEVICE_ID;
  url += "/readings?key=";
  url += FIREBASE_API_KEY;

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // convert binary flags to status strings for the Flutter app
  String smokeStr = fpgaData.smoke ? "UNSAFE" : "SAFE";
  String flameStr = fpgaData.flame ? "UNSAFE" : "SAFE";
  String tiltStr = fpgaData.tilt ? "UNSAFE" : "SAFE";
  String seatStr = fpgaData.seatOccupied ? "OCCUPIED" : "EMPTY";
  bool isEmergency = fpgaData.emergency;

  if (!fpgaData.valid) {
    smokeStr = "SAFE";
    flameStr = "SAFE";
    tiltStr = "SAFE";
    seatStr = "EMPTY";
    isEmergency = false;
  }

  StaticJsonDocument<768> doc;
  JsonObject fields = doc.createNestedObject("fields");

  fields["deviceId"]["stringValue"] = DEVICE_ID;
  fields["busId"]["stringValue"] = BUS_ID;
  fields["busNumber"]["stringValue"] = BUS_NUMBER;
  fields["temperature"]["doubleValue"] = (double)fpgaData.temperature;
  fields["smoke"]["stringValue"] = smokeStr;
  fields["flame"]["stringValue"] = flameStr;
  fields["tiltAngle"]["stringValue"] = tiltStr;
  fields["seatStatus"]["stringValue"] = seatStr;
  fields["latitude"]["doubleValue"] = lastLat;
  fields["longitude"]["doubleValue"] = lastLng;
  fields["speed"]["doubleValue"] = (double)lastSpeed;
  fields["isEmergency"]["booleanValue"] = isEmergency;
  fields["timestamp"]["timestampValue"] = getISOTimestamp();

  String payload;
  serializeJson(doc, payload);

  int httpCode = http.POST(payload);
  if (httpCode == 200 || httpCode == 201) {
    Serial.printf("Firebase OK — %.5f, %.5f | %d C\n", lastLat, lastLng,
                  fpgaData.temperature);
  } else {
    Serial.printf("Firebase error: %d\n", httpCode);
    Serial.println(http.getString());
  }
  http.end();
}

void connectWiFi() {
  Serial.printf("Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\nConnected! IP: %s\n", WiFi.localIP().toString().c_str());
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    time_t now = time(nullptr);
    while (now < 8 * 3600 * 2) {
      delay(500);
      now = time(nullptr);
    }
    Serial.println("NTP time synced.");
  } else {
    Serial.println("\nWiFi connection failed.");
  }
}

String getISOTimestamp() {
  time_t now = time(nullptr);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buffer);
}