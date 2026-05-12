# SafeTrack IoT Module

## Architecture

```
Tang Nano 9K (FPGA)  --UART 9600-->  ESP32  --WiFi/HTTPS-->  Firebase Firestore
  (sensor processing)               (gateway + GPS)            (cloud DB)
```

## ESP32

Receives sensor telemetry from the FPGA over UART, reads GPS from a NEO-6M module, and pushes a combined JSON payload to Firebase Firestore via the REST API every 10 seconds.

### Source Files

| File | Purpose |
|------|---------|
| `esp32_safetrack.ino` | Main firmware — FPGA packet parser, GPS reader, Firestore REST push |
| `secrets.h.example` | Template for WiFi and Firebase credentials |

### Wiring

| Connection                  | ESP32 Pin |
|-----------------------------|-----------|
| Tang Nano TX (Pin 63) -> RX | GPIO 16   |
| Tang Nano TX  -> GND | GND   |

### FPGA Binary Packet Format (8 bytes)

| Byte | Field       | Values                      |
|------|-------------|-----------------------------|
| 0    | Start       | `$` (0x24)                  |
| 1    | Flame       | 0 = SAFE, 1 = UNSAFE        |
| 2    | Smoke       | 0 = SAFE, 1 = UNSAFE        |
| 3    | Tilt        | 0 = SAFE, 1 = UNSAFE        |
| 4    | Seat        | 0 = EMPTY, 1 = OCCUPIED     |
| 5    | Temperature | 0-99 (raw integer, deg C)   |
| 6    | Emergency   | 0 = no, 1 = yes             |
| 7    | End         | `\n` (0x0A)                 |

## ESP32 Firmware Workflow

The ESP32 acts as the IoT gateway between the FPGA hardware layer and the cloud infrastructure.

### Internal Data Flow

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
React Dashboard + Flutter App Synchronization

### Firmware Responsibilities

- Receives binary telemetry packets from FPGA
- Parses safety sensor data
- Reads real-time GPS coordinates
- Merges GPS and FPGA telemetry
- Formats structured JSON payloads
- Uploads live telemetry to Firebase Firestore
- Enables real-time monitoring in dashboard and mobile app

## Example Firebase JSON Payload

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
## Experimental Validation

| Test | Result |
|------|---------|
| UART Packet Reception | Successful |
| GPS Coordinate Acquisition | Successful |
| Firebase Synchronization | Successful |
| Real-time Dashboard Monitoring | Successful |
| Flutter Mobile App Sync | Successful |
| Emergency Alert Upload | Successful |
| Seat Occupancy Monitoring | Successful |
| GSM Emergency SMS | Successful |

### Validation Summary

- FPGA telemetry was successfully transmitted to the ESP32 over UART.
- GPS coordinates were acquired and merged with sensor telemetry.
- JSON payloads were uploaded successfully to Firebase Firestore.
- Dashboard and mobile applications updated in real time.
- Emergency alerts were propagated successfully across the system.

## ESP32 Firmware Location

The ESP32 cloud communication firmware is located at:

/iot/esp32_safetrack.ino

It handles:
- UART communication with FPGA
- GPS acquisition
- Firebase REST uploads
- emergency telemetry forwarding

## UART Buffer Management

The ESP32 processes FPGA telemetry UART and GPS UART independently using non-blocking serial handlers.

To prevent UART buffer overflow:
- RX buffer sizes are increased to 1024 bytes
- UART reads are processed continuously in the main loop
- CRLF packet framing is used for FPGA telemetry
- GPS NMEA parsing uses incremental character decoding
- Blocking delays are avoided during Firebase communication

### Dependencies (Arduino IDE)

- `ArduinoJson`
- `TinyGPSPlus`
- WiFi (built-in ESP32)
- HTTPClient (built-in ESP32)

## ESP32 Verification

- UART packet parsing verified
- GPS NMEA decoding validated
- Firebase HTTPS upload tested
- Buffer overflow mitigation added using 1024-byte UART buffers

## Firmware Responsibilities

The ESP32 firmware handles GPS telemetry acquisition, Firebase cloud synchronization, UART communication with FPGA modules, sensor-data forwarding, and emergency escalation workflows.

### Configuration

Copy `secrets.h.example` to `secrets.h` and fill in your WiFi SSID/password and Firebase project credentials. `secrets.h` is gitignored and will not be committed.