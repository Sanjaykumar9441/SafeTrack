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

## Modulesx

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
- AI-powered safety assistant using Groq API and LLaMA 3 via Firebase Cloud Functions.
- The RECORD_AUDIO permission is exclusively used for optional speech-to-text interaction within the AI Safety Chat module and is not used for continuous audio monitoring or surveillance.
- Safety alerts with sensor data visualization.

### Firebase Configuration Security

The Flutter application does not hardcode Firebase credentials directly in source files. Firebase configuration values are injected securely at build time using Flutter `--dart-define` environment variables and accessed through `String.fromEnvironment(...)` inside `firebase_options.dart`.

### Runtime Stability & Null Safety

The Flutter application implements defensive Firestore parsing with explicit fallback values (`??`) and typed normalization helpers (`_toInt`, `_toDouble`) to safely handle incomplete realtime telemetry uploads, delayed GPS synchronization, and partially available sensor data without runtime crashes.

### GPS Permission Handling

The Nearby Stops module implements graceful runtime GPS permission handling using the Geolocator package. If location services are disabled or permission is denied, the application presents a user-friendly fallback interface with retry functionality instead of crashing or blocking the UI.

### Frontend Runtime Resilience

The React administrative dashboard implements realtime loading states, asynchronous Firestore error handling, toast-based operational notifications, and a global React Error Boundary to prevent complete dashboard failure during unexpected runtime exceptions or network instability.

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
| `lib/screens/ai_safety_chat_screen.dart` | AI chat interface (Groq/LLaMA) |
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

### Live Tracking System

The Flutter application implements a real-time live tracking interface using the `google_maps_flutter` package and Firebase telemetry streams. The `live_tracking_screen.dart` module subscribes to Firestore live telemetry updates through `ApiService.liveDataStream()` and dynamically updates bus marker positions, safety status, emergency indicators, and GPS coordinates in real time.

Implemented features:

* Real-time GPS tracking
* Google Maps integration
* Dynamic bus marker updates
* Live speed and temperature monitoring
* Emergency detection visualization
* Camera auto-follow system
* Re-center map controls
* Last updated telemetry timestamps
* Safety status classification (SAFE/WARNING/DANGER)

## Experimental Validation

The SafeTrack system was experimentally verified across FPGA, IoT, cloud, and application layers.

| Test | Result |
|------|---------|
| GPS Tracking | Successful |
| Fire Detection | Successful |
| Smoke Detection | Successful |
| Crash Detection | Successful |
| Firebase Sync | Successful |
| GSM Emergency SMS | Successful |
| Real-time Dashboard Monitoring | Successful |
| Driver Terminal Communication | Successful |
| Seat Occupancy Detection | Successful |
| Cloud Alert Propagation | Successful |

### Driver Terminal Validation

The dedicated Driver Terminal module was experimentally validated with realtime Firestore synchronization. Driver-side operational controls including SOS emergency override, passenger waiting visualization, route guidance, next-stop display, and driver status updates were successfully synchronized between the React dashboard and Firebase backend in realtime.

### Validation Summary

- Real-time GPS data was successfully transmitted from the ESP32 gateway to Firebase.
- Emergency events generated immediate FPGA-triggered GSM alerts.
- Firebase synchronization updated both the React dashboard and Flutter application in real time.
- Driver terminal communication was validated successfully.
- Seat occupancy changes were correctly reflected in the cloud dashboard.

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

The SafeTrack system currently uses a flat Firestore collection structure for realtime monitoring and simplified cloud synchronization.

### Main Collections

| Collection | Purpose |
|------------|---------|
| `buses` | Stores registered bus details |
| `routes` | Stores source, destination, and stop information |
| `live_data` | Stores realtime telemetry from ESP32 devices |
| `alerts` | Stores emergency and safety alerts |
| `users` | Stores admin and driver authentication roles |

### Architecture Flow

ESP32 devices transmit realtime telemetry data to Firebase Firestore through HTTPS REST requests. The Flutter mobile application and React admin dashboard subscribe to Firestore realtime streams for live synchronization.

### Benefits of Current Structure

- Simpler realtime querying
- Faster prototype development
- Easy dashboard integration
- Efficient Firebase realtime listeners
- Simplified CRUD operations

The architecture is optimized for prototype-scale deployment and realtime smart transportation monitoring.

## Tech Stack

| Layer      | Technology                                         |
|------------|--------------------------------------------------- |
| FPGA       | Verilog HDL (Gowin GW1NR-9, Tang Nano 9K)          |
| IoT Gateway| Arduino (ESP32), TinyGPSPlus, ArduinoJson          |
| Backend    | Firebase Firestore, Cloud Functions (Node.js)      |
| Mobile     | Flutter, Provider, Cloud Firestore SDK             |
| Admin      | React, Tailwind CSS, react-hot-toast               |
| AI         | Groq API + LLaMA 3                                 |
| Alerts     | Twilio (voice), Slack Webhooks, Telegram Bot API   |

### AI Model Clarification

The project initially evaluated Gemini API integration during the early design phase. However, the final deployed implementation uses the Groq API with the LLaMA 3 model due to lower latency, simpler Firebase Cloud Functions integration, and improved realtime conversational performance for the AI Safety Chat module.

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

This project was developed as part of a project Space 2026 at Aditya University, ECE Department (2026).