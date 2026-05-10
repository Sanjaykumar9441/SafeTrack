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

### 1. FPGA Sensor Core (`/fpga_tang_nano_9k`)
- **Gowin Tang Nano 9K** running Verilog HDL.
- Reads flame, smoke (MQ-2), crash (MPU-6050 via I2C), and seat occupancy sensors concurrently in hardware.
- Sends a 29-character ASCII telemetry string to the ESP32 over UART at 115200 baud every 0.5 s.
- On emergency detection (fire, smoke, or crash), the FPGA activates an independent GSM emergency subsystem using the SIM800L module to automatically place emergency calls and transmit SMS alerts containing live GPS coordinates.

#### Source Files
| File | Purpose |
|------|---------|
| `sensors.v` | Top module — sensor sync, UART TX, GSM/GPS emergency state machine |
| `mpu6050_I2C.v` | I2C engine for MPU-6050 accelerometer crash detection |
| `constraint.cst` | Gowin pin constraint file |
| `test_bench.v` | Icarus Verilog simulation testbench |

### 2. IoT Gateway (`/iot`)
- **ESP32** receives the FPGA telemetry over UART and reads GPS from a NEO-6M module.
- Pushes a combined JSON payload to Firebase Firestore via the REST API every 10 seconds.

#### Source Files
| File | Purpose |
|------|---------|
| `esp32_safetrack.ino` | Main firmware — FPGA packet parser, GPS reader, Firestore REST push |
| `secrets.h.example` | Template for WiFi and Firebase credentials |

### 3. Mobile App (`/mobile-app`)
- Built with **Flutter** and **Firebase**.
- Real-time bus tracking with live GPS map.
- Route search (source-to-destination, service number, vehicle number).
- Nearby bus stops with GPS proximity.
- AI-powered safety chat (Gemini via Firebase Cloud Functions).
- Safety alerts with sensor data visualization.

#### Key Files
| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entrypoint, Provider setup, bottom nav shell |
| `lib/config/theme.dart` | App-wide color palette and theme data |
| `lib/config/firebase_options.dart` | Firebase config via `--dart-define` build-time injection |
| `lib/screens/home_screen.dart` | Home dashboard with search, nearby stops, alerts |
| `lib/screens/bus_detail_screen.dart` | Bus detail view with live sensor data, map, route stops |
| `lib/screens/live_tracking_screen.dart` | Real-time GPS map tracking |
| `lib/screens/buses_screen.dart` | Browse all buses |
| `lib/screens/ai_home_screen.dart` | AI safety assistant home |
| `lib/screens/ai_safety_chat_screen.dart` | AI chat interface (Gemini/Groq) |
| `lib/screens/nearby_stops_screen.dart` | GPS-based nearby bus stop finder |
| `lib/screens/search_results_screen.dart` | Search results for routes/buses |
| `lib/screens/contact_screen.dart` | Contact & about page |
| `lib/screens/splash_screen.dart` | Animated splash screen |
| `lib/models/bus.dart` | Bus data model |
| `lib/models/route_model.dart` | Route & stop data model |
| `lib/models/alert.dart` | Alert data model |
| `lib/services/api_service.dart` | Firestore CRUD and live data streams |
| `lib/services/ai_service.dart` | Cloud Function AI integration |
| `lib/services/location_service.dart` | GPS / location utilities |
| `lib/providers/bus_provider.dart` | Real-time bus state management |
| `lib/providers/favorites_provider.dart` | Saved favorites (SharedPreferences) |
| `lib/widgets/bus_card.dart` | Bus list card with live status indicators |
| `lib/widgets/feature_card.dart` | Home screen feature cards |
| `lib/widgets/live_stats_card.dart` | Live sensor data card |
| `lib/widgets/bottom_nav_bar.dart` | Bottom navigation bar |

### 4. Admin Dashboard (`/admin-dashboard`)
- Built with **React** and **Tailwind CSS**.
- Real-time Firestore listeners for buses, routes, alerts, and live IoT data.
- Bus and route CRUD management.
- Driver terminal with SOS alerts and trip management.
- Emergency alert dispatch — triggers Twilio voice calls, Slack notifications, and Telegram alerts via Cloud Functions.

#### Key Files
| Path | Purpose |
|------|---------|
| `src/App.js` | Router, protected routes, driver routes |
| `src/firebase.js` | Firebase initialization (env-based config) |
| `src/context/AuthContext.jsx` | Firebase Auth provider (admin + driver roles) |
| `src/hooks/useAuth.js` | Auth context hook |
| `src/components/Auth/LoginPage.jsx` | Unified admin/driver login with tab switching |
| `src/components/Dashboard/DashboardHome.jsx` | Overview with stats cards and recent alerts |
| `src/components/Dashboard/StatsCard.jsx` | Reusable stats card component |
| `src/components/Bus/CreateBus.jsx` | Bus registration form |
| `src/components/Bus/BusList.jsx` | Bus listing with search |
| `src/components/Bus/BusCard.jsx` | Bus list card component |
| `src/components/Route/CreateRoute.jsx` | Route creation with stop management |
| `src/components/Route/RouteList.jsx` | Route listing |
| `src/components/Alerts/AlertsPanel.jsx` | Alert management with auto-dispatch |
| `src/components/Alerts/AlertCard.jsx` | Individual alert card |
| `src/components/LiveData/LiveDataPanel.jsx` | Real-time IoT device data viewer |
| `src/components/Driver/DriverLogin.jsx` | Driver PIN-based login |
| `src/components/Driver/DriverBusSelect.jsx` | Driver bus assignment screen |
| `src/components/Driver/DriverTerminal.jsx` | Driver dashboard with SOS and trip controls |
| `src/components/Layout/DashboardLayout.jsx` | Dashboard layout wrapper |
| `src/components/Layout/Sidebar.jsx` | Navigation sidebar |
| `src/components/Layout/Header.jsx` | Top header bar |

### 5. Cloud Functions (`/admin-dashboard/functions`)
| Function | Type | Purpose |
|----------|------|---------|
| `sendEmergencyAlert` | HTTP | Dispatches emergency notifications to Twilio, Slack, and Telegram |
| `askAI` | Callable | AI chat integration for the mobile app (Groq/LLaMA) |

### 6. Bus Simulator (`/simulate_bus.js`)
- Node.js simulator that generates synthetic GPS drift and sensor telemetry, pushing realtime readings to Firestore device subcollections every 5 seconds for testing without physical hardware.

## Firestore Architecture

The project uses a device-oriented Firestore hierarchy:

devices/{deviceId}/readings

Each ESP32 gateway pushes realtime telemetry into its own readings subcollection, improving scalability, isolation, and device-specific querying.

## Tech Stack

| Layer      | Technology                                         |
|------------|--------------------------------------------------- |
| FPGA       | Verilog HDL (Gowin GW1NR-9, Tang Nano 9K)          |
| IoT Gateway| Arduino (ESP32), TinyGPSPlus, ArduinoJson          |
| Backend    | Firebase Firestore, Cloud Functions (Node.js)      |
| Mobile     | Flutter, Provider, Cloud Firestore SDK             |
| Admin      | React, Tailwind CSS, react-hot-toast               |
| AI         | Google Gemini 1.5 Flash (via Groq)                 |
| Alerts     | Twilio (voice), Slack Webhooks, Telegram Bot API   |

## Setup

### Admin Dashboard
```bash
cd admin-dashboard
npm install
npm start
```
Create a `.env` file with `REACT_APP_FIREBASE_*` variables (API key, auth domain, project ID, storage bucket, messaging sender ID, app ID, measurement ID).

### Mobile App
```bash
cd mobile-app
flutter pub get
flutter run \
  --dart-define=FIREBASE_API_KEY=your-key \
  --dart-define=FIREBASE_APP_ID=your-app-id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-bucket
```
You also need `google-services.json` at `mobile-app/android/app/` — download it from the Firebase Console (Project Settings → Android app).

### Cloud Functions
```bash
cd admin-dashboard/functions
npm install
firebase deploy --only functions
```
Configure secrets (Twilio, Slack, Telegram, Groq) via `firebase functions:secrets:set` or a local `.env` file — see `functions/index.js` for the variable names.

### Bus Simulator
```bash
npm install
npm run simulate
```
Requires a `.env` file in the project root with `FIREBASE_*` variables.


### IoT (ESP32 + FPGA)
1. Flash the FPGA bitstream to the Tang Nano 9K using the Gowin IDE.
2. Copy `iot/secrets.h.example` to `iot/secrets.h` and fill in your WiFi and Firebase credentials.
3. Upload `esp32_safetrack.ino` to the ESP32 via Arduino IDE.
4. Connect wiring as documented in the source file headers.

## Sensors

| Sensor     | Purpose                          | Interface |
|------------|----------------------------------|-----------|
| IR Flame   | Fire detection                   | Digital   |
| MQ-2       | Smoke / gas detection            | Digital   |
| MPU-6050   | Crash / tilt detection           | I2C       |
| Limit SW   | Seat occupancy detection         | Digital   |
| NEO-6M     | GPS location                     | UART      |
| SIM800L    | Emergency voice call & SMS       | UART      |

## License

This project was developed as part of a university capstone project at Aditya University, ECE Department (2026).