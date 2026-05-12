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
 * Tang Nano GND -> ESP32 GND
 * GPS TX        -> ESP32 GPIO4  (RX1)
 * GPS RX        -> ESP32 GPIO12 (TX1)
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
#include <WiFiClientSecure.h> // HTTPS secure client
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

// FPGA transmits telemetry data to ESP32 UART2 RX
#define FPGA_RX_PIN 16

// GPS module serial communication pins
#define GPS_RX_PIN 4

// GPIO12 used for GPS TX communication
// Avoided GPIO2 because it affects ESP32 boot mode
#define GPS_TX_PIN 12

// =============================================================
// TIMING
// =============================================================

// Upload sensor data to Firebase every 10 seconds
#define SEND_INTERVAL 10000UL

// Invalidate FPGA data if no packet received for 30 seconds
#define FPGA_STALE_TIMEOUT 30000UL

// Delay before reconnecting WiFi
#define WIFI_RETRY_DELAY 5000UL

// =============================================================
// SERIAL PORTS
// =============================================================

// UART2 used for FPGA communication
HardwareSerial fpgaSerial(2);

// UART1 used for GPS communication
HardwareSerial gpsSerial(1);

// =============================================================
// GPS OBJECT
// =============================================================

// TinyGPSPlus library object for GPS parsing
TinyGPSPlus gps;

// =============================================================
// TIMERS
// =============================================================

// Stores last Firebase upload time
unsigned long lastSendTime = 0;

// =============================================================
// LAST VALID GPS VALUES
// =============================================================

// Default coordinates used until valid GPS lock obtained
double lastLat = 16.9800;
double lastLng = 82.2300;

// Last measured GPS speed in km/h
float lastSpeed = 0.0;

// =============================================================
// FPGA DATA STRUCTURE
// =============================================================

// Stores latest telemetry received from FPGA
struct FpgaData {

  // Fire detection status
  bool flame = false;

  // Smoke detection status
  bool smoke = false;

  // Tilt/crash detection status
  bool tilt = false;

  // Seat occupancy status
  bool seatOccupied = false;

  // Temperature received from FPGA
  uint8_t temperature = 25;

  // Emergency flag from FPGA
  bool emergency = false;

  // Indicates whether packet data is valid
  bool valid = false;

  // Stores last packet receive timestamp
  unsigned long lastReceived = 0;
};

FpgaData fpgaData;

// =============================================================
// UART PACKET BUFFER
// =============================================================

// Buffer stores complete 8-byte FPGA packet
uint8_t pktBuf[8];

// Current packet byte index
uint8_t pktIdx = 0;

// Indicates packet reception is in progress
bool inPacket = false;

// =============================================================
// TLS CLIENT
// =============================================================

// Secure HTTPS client for Firebase communication
WiFiClientSecure tlsClient;

// =============================================================
// SETUP
// =============================================================
void setup() {

  // Initialize serial monitor for debugging
  Serial.begin(115200);

  Serial.println("\n================================================");
  Serial.println("      SafeTrack ESP32 IoT Module Starting");
  Serial.println("================================================");

  // Configure ESP32 as WiFi station device
  WiFi.mode(WIFI_STA);

  // Initialize UART2 for FPGA communication
  // 9600 baud, 8-bit data, no parity, 1 stop bit
  fpgaSerial.begin(9600, SERIAL_8N1, FPGA_RX_PIN, -1);

  // Initialize UART1 for GPS communication
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  // Connect ESP32 to WiFi network
  connectWiFi();

  // Disable TLS certificate verification
  // Suitable only for prototype/demo systems
  tlsClient.setInsecure();
}

// =============================================================
// MAIN LOOP
// =============================================================
void loop() {

  // Read incoming FPGA UART packets
  readFpgaPacket();

  // Read and decode GPS serial data
  while (gpsSerial.available() > 0) {

    // TinyGPSPlus converts NMEA data into coordinates
    gps.encode(gpsSerial.read());
  }

  // Update GPS coordinates only if valid fix available
  if (gps.location.isValid()) {

    lastLat = gps.location.lat();
    lastLng = gps.location.lng();
  }

  // Update speed only if GPS speed is valid
  if (gps.speed.isValid()) {

    lastSpeed = gps.speed.kmph();
  }

  // Expire stale FPGA telemetry after timeout
  if (fpgaData.valid &&
      (millis() - fpgaData.lastReceived) > FPGA_STALE_TIMEOUT) {

    fpgaData.valid = false;

    Serial.println("[FPGA] Data marked stale — no packet in 30 s");
  }

  // Upload data periodically to Firebase
  if (millis() - lastSendTime >= SEND_INTERVAL) {

    lastSendTime = millis();

    // Print local debug information
    printStatus();

    // Upload telemetry to cloud
    sendToFirestore();
  }
}

// =============================================================
// FPGA UART PACKET PARSER
// =============================================================
void readFpgaPacket() {

  while (fpgaSerial.available() > 0) {

    // Read one byte from UART
    uint8_t b = fpgaSerial.read();

    // '$' indicates start of packet
    if (b == 0x24) {

      pktIdx = 0;

      pktBuf[pktIdx++] = b;

      // Packet reception started
      inPacket = true;

    } else if (inPacket) {

      // Store incoming bytes into packet buffer
      if (pktIdx < 8) {

        pktBuf[pktIdx++] = b;
      }

      // Check if full packet received
      if (pktIdx >= 8) {

        inPacket = false;

        // Validate end marker '\n'
        if (pktBuf[7] == 0x0A) {

          // Decode sensor values from packet bytes
          fpgaData.flame = (pktBuf[1] == 1);
          fpgaData.smoke = (pktBuf[2] == 1);
          fpgaData.tilt = (pktBuf[3] == 1);
          fpgaData.seatOccupied = (pktBuf[4] == 1);
          fpgaData.temperature = pktBuf[5];
          fpgaData.emergency = (pktBuf[6] == 1);

          // Mark packet as valid
          fpgaData.valid = true;

          // Save packet receive time
          fpgaData.lastReceived = millis();

          Serial.println("[FPGA] Valid packet received");

        } else {

          // Packet corrupted or incomplete
          Serial.printf("[FPGA] Bad end marker: 0x%02X\n", pktBuf[7]);
        }

        // Reset packet index for next frame
        pktIdx = 0;
      }
    }
  }
}