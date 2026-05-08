# SafeTrack

Smart Bus Tracking & Safety System — an IoT-based solution that monitors bus conditions in real time and alerts emergency services when accidents or hazardous events are detected.

## Architecture

```
Tang Nano 9K (FPGA)  --UART-->  ESP32  --WiFi/HTTPS-->  Firebase Firestore
   (sensors)                  (GPS + WiFi gateway)          (cloud DB)
                                                              |
                                              +---------------+---------------+
                                              |                               |
                                     Flutter Mobile App              React Admin Dashboard
                                     (passenger-facing)              (fleet management)
```

## Modules

### 1. IoT Hardware (`/iot`)
- **FPGA (Tang Nano 9K):** Reads flame, smoke, tilt, temperature, and seat sensors. Sends processed binary packets to the ESP32 over UART at 9600 baud.
- **ESP32:** Receives FPGA packets, reads GPS coordinates from a NEO-6M module, and pushes all telemetry to Firebase Firestore via the REST API every 10 seconds.

### 2. Mobile App (`/mobile-app`)
- Built with **Flutter** and **Firebase**.
- Real-time bus tracking with live GPS map.
- Route search (source-to-destination, service number, vehicle number).
- Nearby bus stops with GPS proximity.
- AI-powered safety chat (Gemini via Firebase Cloud Functions).
- Safety alerts with sensor data visualization.

### 3. Admin Dashboard (`/admin-dashboard`)
- Built with **React** and **Tailwind CSS**.
- Real-time Firestore listeners for buses, routes, alerts, and live IoT data.
- Bus and route CRUD management.
- Emergency alert dispatch — triggers Twilio voice calls, Slack notifications, and Telegram alerts via Cloud Functions.

### 4. Cloud Functions (`/admin-dashboard/functions`)
- `sendEmergencyAlert` — HTTP endpoint that dispatches emergency notifications to Twilio, Slack, and Telegram.
- `askGemini` — Callable function for Gemini AI integration in the mobile app.

## Tech Stack

| Layer      | Technology                                         |
|------------|----------------------------------------------------|
| FPGA       | Verilog (Gowin GW1NR-9, Tang Nano 9K)             |
| IoT Gateway| Arduino (ESP32), TinyGPSPlus, ArduinoJson          |
| Backend    | Firebase Firestore, Cloud Functions (Node.js)       |
| Mobile     | Flutter, Provider, Cloud Firestore SDK              |
| Admin      | React, Tailwind CSS, react-hot-toast                |
| AI         | Google Gemini 1.5 Flash                             |
| Alerts     | Twilio (voice), Slack Webhooks, Telegram Bot API    |

## Setup

### Mobile App
```bash
cd mobile-app
flutter pub get
flutter run
```

### Admin Dashboard
```bash
cd admin-dashboard
npm install
npm start
```

### Cloud Functions
```bash
cd admin-dashboard/functions
npm install
firebase deploy --only functions
```

### IoT
1. Flash the FPGA bitstream to the Tang Nano 9K using the Gowin IDE.
2. Upload `esp32_safetrack.ino` to the ESP32 via Arduino IDE (set WiFi credentials first).
3. Connect wiring as documented in the source file headers.

## Sensors Used

| Sensor     | Purpose                          | Interface |
|------------|----------------------------------|-----------|
| Flame      | Fire detection (IR)              | Digital   |
| MQ-2       | Smoke / gas detection            | Digital   |
| SW-420     | Vibration / tilt detection       | Digital   |
| DHT11      | Temperature reading              | 1-Wire    |
| Limit SW   | Seat occupancy detection         | Digital   |
| NEO-6M     | GPS location                     | UART      |

## License

This project was developed as part of a university capstone project at Aditya University, ECE Department (2026).