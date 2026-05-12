# SafeTrack IoT Module

> ESP32-Based Cloud Telemetry Gateway for the SafeTrack Smart Bus Safety System

---

# Overview

The **SafeTrack IoT Module** acts as the communication bridge between the FPGA hardware safety layer and the cloud infrastructure.

Built on the **ESP32**, the subsystem:

* receives FPGA telemetry through UART
* acquires GPS coordinates from the NEO-6M module
* formats structured JSON payloads
* uploads real-time safety data to Firebase Firestore using HTTPS REST APIs

The ESP32 enables:

* cloud synchronization
* dashboard updates
* mobile app monitoring
* real-time emergency visibility

---

# System Architecture

```text id="rjyvhg"
Tang Nano 9K FPGA  --UART 9600-->  ESP32  --WiFi/HTTPS-->  Firebase Firestore
(sensor processing)               (IoT Gateway)              (Cloud Database)
```

---

# ESP32 Responsibilities

The ESP32 firmware acts as the intelligent IoT communication layer.

### Core Responsibilities

* Receives FPGA UART telemetry
* Parses binary telemetry packets
* Reads GPS coordinates from NEO-6M
* Merges telemetry and GPS data
* Creates structured JSON payloads
* Uploads telemetry to Firebase Firestore
* Enables dashboard and mobile app synchronization
* Handles emergency telemetry forwarding

---

# Internal Firmware Data Flow

```text id="n17z7p"
FPGA UART Telemetry
        ↓
ESP32 UART Packet Parser
        ↓
GPS Coordinate Acquisition
        ↓
JSON Payload Formatting
        ↓
Firebase REST API Upload
        ↓
React Dashboard + Flutter App Sync
```

---

# Source Files

| File                  | Purpose                               |
| --------------------- | ------------------------------------- |
| `esp32_safetrack.ino` | Main ESP32 firmware                   |
| `secrets.h.example`   | WiFi and Firebase credential template |

---

# Hardware Connections

| Connection                       | ESP32 Pin                   |
| -------------------------------- | --------------------------- |
| Tang Nano TX (Pin 63) → ESP32 RX | GPIO 16                     |
| Tang Nano GND → ESP32 GND        | GND                         |
| NEO-6M GPS TX → ESP32 RX2        | GPIO 17                     |
| SIM800L UART                     | Optional Future Integration |

---

# FPGA Binary Packet Format

The FPGA transmits compact binary telemetry packets over UART.

### Packet Size

* 8 bytes
* CRLF framed

---

## Packet Structure

| Byte | Field       | Description           |
| ---- | ----------- | --------------------- |
| 0    | Start       | `$` (0x24)            |
| 1    | Flame       | 0 = SAFE, 1 = UNSAFE  |
| 2    | Smoke       | 0 = SAFE, 1 = UNSAFE  |
| 3    | Tilt/Crash  | 0 = SAFE, 1 = UNSAFE  |
| 4    | Seat        | Occupancy information |
| 5    | Temperature | Raw integer °C        |
| 6    | Emergency   | 0 = No, 1 = Yes       |
| 7    | End         | `\n` (0x0A)           |

---

# UART Communication

## UART Configuration

| Parameter | Value |
| --------- | ----- |
| Baud Rate | 9600  |
| Data Bits | 8     |
| Stop Bits | 1     |
| Parity    | None  |

---

## UART Buffer Management

To prevent packet corruption and overflow:

* RX buffer sizes increased to 1024 bytes
* Non-blocking UART handlers used
* Continuous UART polling implemented
* CRLF packet framing added
* GPS decoding handled incrementally

This ensures stable communication during:

* continuous telemetry upload
* GPS acquisition
* Firebase HTTPS requests

---

# GPS Integration

The ESP32 receives live GPS coordinates from the NEO-6M module.

### GPS Responsibilities

* NMEA sentence parsing
* Coordinate extraction
* Timestamp synchronization
* GPS validity checking

### GPS Output Example

```text id="i8moh6"
Latitude  : 17.3850
Longitude : 78.4867
```

---

# Firebase Integration

The ESP32 uploads real-time telemetry to Firebase Firestore using HTTPS REST APIs.

---

# Example Firebase JSON Payload

```json
{
  "bus_id": "BUS_101",
  "latitude": 17.3850,
  "longitude": 78.4867,
  "flame": false,
  "smoke": false,
  "crash": true,
  "seat_count": 3,
  "emergency": true,
  "timestamp": "2026-05-11T10:15:00Z"
}
```

---

# Cloud Synchronization Workflow

The uploaded telemetry is consumed by:

* React Admin Dashboard
* Flutter Mobile Application
* Emergency Monitoring Interfaces

This enables:

* live bus tracking
* emergency visualization
* occupancy monitoring
* cloud analytics

---

# Experimental Validation

| Test                           | Result     |
| ------------------------------ | ---------- |
| UART Packet Reception          | Successful |
| GPS Coordinate Acquisition     | Successful |
| Firebase Synchronization       | Successful |
| Real-time Dashboard Monitoring | Successful |
| Flutter Mobile App Sync        | Successful |
| Emergency Alert Upload         | Successful |
| Seat Occupancy Monitoring      | Successful |
| Cloud Telemetry Upload         | Successful |

---

# Validation Summary

The IoT subsystem was validated successfully under prototype-level testing.

### Verified Operations

* FPGA telemetry reception through UART
* GPS coordinate acquisition
* Firebase HTTPS communication
* Real-time dashboard updates
* Flutter mobile synchronization
* Emergency telemetry propagation
* UART buffer overflow mitigation

---

# Firmware Communication Features

The ESP32 firmware supports:

* UART telemetry reception
* GPS NMEA decoding
* Firebase REST uploads
* Emergency alert forwarding
* Cloud synchronization workflows

---

# Dependencies

## Arduino IDE Libraries

| Library       | Purpose         |
| ------------- | --------------- |
| `ArduinoJson` | JSON formatting |
| `TinyGPSPlus` | GPS decoding    |
| `WiFi`        | ESP32 WiFi      |
| `HTTPClient`  | HTTPS requests  |

---

# ESP32 Verification

The following features were verified successfully:

* UART packet parsing
* GPS coordinate extraction
* Firebase HTTPS uploads
* Telemetry synchronization
* Buffer overflow handling
* Cloud telemetry forwarding

---

# Firmware Location

```text id="4cw49m"
/iot/esp32_safetrack.ino
```

---

# Configuration

## Credential Setup

Copy:

```text id="p4t8yz"
secrets.h.example
```

to:

```text id="j9x22u"
secrets.h
```

and configure:

* WiFi SSID
* WiFi Password
* Firebase credentials
* Firestore project details

---

# Security Note

```text id="wx4qgm"
secrets.h
```

is gitignored and must not be committed to the repository.

---

# Repository Structure

```text id="2gjmvt"
iot/
├── esp32_safetrack.ino
├── secrets.h.example
└── README.md
```

---

# System Integration

The ESP32 integrates with:

* Tang Nano 9K FPGA
* Firebase Firestore
* React Admin Dashboard
* Flutter Mobile Application
* GPS Telemetry Services

---

# Tech Stack

| Category       | Technology         |
| -------------- | ------------------ |
| IoT Controller | ESP32              |
| Communication  | UART               |
| Cloud          | Firebase Firestore |
| GPS            | NEO-6M             |
| Firmware       | Arduino Framework  |
| Protocol       | HTTPS REST API     |

---

# License

Developed as part of **Project Space 2026**
Department of Electronics & Communication Engineering
Aditya University, India.