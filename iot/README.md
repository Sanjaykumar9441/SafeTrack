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

## ESP32 Firmware Location

The ESP32 cloud communication firmware is located at:

/iot/esp32_safetrack.ino

It handles:
- UART communication with FPGA
- GPS acquisition
- Firebase REST uploads
- emergency telemetry forwarding

### Dependencies (Arduino IDE)

- `ArduinoJson`
- `TinyGPSPlus`
- WiFi (built-in ESP32)
- HTTPClient (built-in ESP32)

### Configuration

Copy `secrets.h.example` to `secrets.h` and fill in your WiFi SSID/password and Firebase project credentials. `secrets.h` is gitignored and will not be committed.