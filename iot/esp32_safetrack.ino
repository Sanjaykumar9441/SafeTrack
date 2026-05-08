/**
 * Smart Bus Safety System - ESP32 Bridge
 * Reads FPGA (Smoke, Tilt, Limit Switch) + GPS, sends to Firestore REST API
 */

#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <TinyGPSPlus.h>
#include <WiFi.h>

// ==================== 1. CREDENTIALS ====================
const char* WIFI_SSID     = "Chaitu";
const char* WIFI_PASSWORD = "123456789@";

const char* FIREBASE_PROJECT_ID = "safedrive-144";
const char* FIREBASE_API_KEY    = "AIzaSyBTrDjbGYfv2vkRBheq4XjLhqY7jUMqEMs";

// ==================== 2. DEVICE INFO ====================
const char* DEVICE_ID  = "ESP32_001";
const char* BUS_ID     = "28NQwou8YjkkrmupjVC7";
const char* BUS_NUMBER = "BUS-101";

// ==================== 3. HARDWARE PINS ====================
// FPGA communicates on Serial1
#define FPGA_RX 16
#define FPGA_TX 17 

// GPS communicates on Serial2 (Move your GPS TX pin to ESP32 Pin 18)
#define GPS_RX 18 
#define GPS_TX 19 

#define SEND_INTERVAL 10000  // Send cloud update every 10 seconds

// ==================== 4. GLOBAL OBJECTS ====================
TinyGPSPlus gps;
HardwareSerial fpgaSerial(1);
HardwareSerial gpsSerial(2);

unsigned long lastSendTime = 0;
double currentLat = 17.05; // Default fallback if no GPS lock
double currentLng = 82.17; // Default fallback if no GPS lock
String latestFpgaData = "SAFE SAFE EMPTY"; // Default starting string

// Function Prototypes
void connectWiFi();
void sendToFirestore(double lat, double lng, String fpgaInfo);
String getISOTimestamp();

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== Smart Bus IoT Module Starting ===");

  // Initialize FPGA Serial
  fpgaSerial.begin(9600, SERIAL_8N1, FPGA_RX, FPGA_TX);
  Serial.println("FPGA connection initialized on Pins 16/17.");

  // Initialize GPS Serial
  gpsSerial.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);
  Serial.println("GPS connection initialized on Pins 18/19.");

  connectWiFi();
}

// ==================== MAIN LOOP ====================
void loop() {
  // 1. Constantly feed GPS data
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
    if (gps.location.isUpdated()) {
      currentLat = gps.location.lat();
      currentLng = gps.location.lng();
    }
  }

  // 2. Constantly listen to the FPGA
  if (fpgaSerial.available() > 0) {
    String incomingData = fpgaSerial.readStringUntil('\n');
    incomingData.trim();
    
    // Only update if we received actual text, not a blank line
    if (incomingData.length() > 2) {
      latestFpgaData = incomingData;
      Serial.println("FPGA Data Updated: " + latestFpgaData);
    }
  }

  // 3. Send to Cloud every 10 seconds
  if (millis() - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = millis();
    sendToFirestore(currentLat, currentLng, latestFpgaData);
  }
}

// ==================== SEND TO FIRESTORE ====================
void sendToFirestore(double lat, double lng, String fpgaInfo) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    connectWiFi();
    return;
  }

  HTTPClient http;

  String url = "https://firestore.googleapis.com/v1/projects/";
  url += FIREBASE_PROJECT_ID;
  url += "/databases/(default)/documents/live_data?key=";
  url += FIREBASE_API_KEY;

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Create JSON Document
  StaticJsonDocument<768> doc;
  JsonObject fields = doc.createNestedObject("fields");

  // --- STANDARD FIELDS ---
  fields["deviceId"]["stringValue"]  = DEVICE_ID;
  fields["busId"]["stringValue"]     = BUS_ID;
  fields["busNumber"]["stringValue"] = BUS_NUMBER;
  fields["latitude"]["doubleValue"]  = lat;
  fields["longitude"]["doubleValue"] = lng;

  // --- DYNAMIC FPGA PARSING LOGIC ---
  
  // Limit Switch Logic: Look for the word your Verilog code sends when the seat is pressed
  // (Change "OCCUPIED" to whatever word your FPGA actually sends)
  String seatStatus = (fpgaInfo.indexOf("OCCUPY") >= 0) ? "OCCUPIED" : "EMPTY";
  fields["seatStatus"]["stringValue"] = seatStatus;

  // Sensor Logic
  fields["smoke"]["stringValue"] = (fpgaInfo.indexOf("SMOKE") >= 0) ? "ALERT" : "SAFE";
  fields["tiltAngle"]["stringValue"] = (fpgaInfo.indexOf("TILT") >= 0) ? "WARNING" : "SAFE";
  fields["isEmergency"]["booleanValue"] = (fpgaInfo.indexOf("EMERGENCY") >= 0);
  
  // Raw Data & Time
  fields["rawFpgaData"]["stringValue"] = fpgaInfo;
  fields["timestamp"]["timestampValue"] = getISOTimestamp();

  // Serialize and Send
  String payload;
  serializeJson(doc, payload);

  int httpCode = http.POST(payload);
  
  if (httpCode == 200 || httpCode == 201) {
    Serial.println("✓ Cloud Update Success!");
    Serial.println("  Payload Map -> Smoke: " + fields["smoke"]["stringValue"].as<String>() + 
                   " | Seat: " + seatStatus);
  } else {
    Serial.printf("✗ Firestore error: %d\n", httpCode);
    Serial.println(http.getString());
  }

  http.end();
}

// ==================== WIFI ====================
void connectWiFi() {
  Serial.printf("Connecting to WiFi: %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\nConnected! IP: %s\n", WiFi.localIP().toString().c_str());
    
    // Sync internal clock for Firestore timestamps
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    time_t now = time(nullptr);
    while (now < 8 * 3600 * 2) {
      delay(500);
      now = time(nullptr);
    }
    Serial.println("Time synced.");
  } else {
    Serial.println("\nWiFi failed! Check SSID and password.");
  }
}

// ==================== TIMESTAMP ====================
String getISOTimestamp() {
  time_t now = time(nullptr);
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buffer);
}
