# SafeTrack IoT Module

## Architecture

```
Tang Nano 9K (FPGA)  --UART 9600-->  ESP32  --WiFi/HTTPS-->  Firebase Firestore
  (sensor processing)               (gateway + GPS)            (live_data collection)
```

## FPGA (Tang Nano 9K)

Reads five digital sensors and the DHT11 temperature sensor, processes the data, and sends an 8-byte binary packet to the ESP32 over UART every ~5 seconds.

### Binary Packet Format

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

### Sensors

| Sensor      | Type    | Pin | Notes                    |
|-------------|---------|-----|--------------------------|
| Flame       | Digital | 25  | Active LOW               |
| MQ-2 smoke  | Digital | 26  | HIGH = smoke detected    |
| SW-420 tilt | Digital | 28  | HIGH = vibration          |
| Limit switch| Digital | 29  | LOW = seat occupied       |
| DHT11       | 1-Wire  | 30  | Temperature reading       |

### LEDs

| LED   | Pin | Function        |
|-------|-----|-----------------|
| Red   | 10  | Heartbeat blink |
| Green | 11  | UART TX activity|
| Blue  | 13  | Emergency state |

### Source Files

- `top.v` — Main module: sensor debouncing, DHT11 reading, packet assembly, UART TX scheduling
- `uart_tx.v` — UART transmitter (9600 baud, 8N1)
- `dht11_reader.v` — DHT11 single-wire protocol state machine
- `tangnano9k.cst` — Pin constraint file for the Gowin IDE

## ESP32

Receives the binary packet from the FPGA, reads GPS from a NEO-6M module, and pushes a combined JSON payload to Firebase Firestore every 10 seconds.

### Wiring

| Connection                  | ESP32 Pin |
|-----------------------------|-----------|
| Tang Nano TX (Pin 17) -> RX | GPIO 16   |
| NEO-6M GPS TX -> RX         | GPIO 4    |
| NEO-6M GPS RX -> TX         | GPIO 2    |

### Dependencies (Arduino IDE)

- `ArduinoJson`
- `TinyGPSPlus`
- WiFi (built-in ESP32)
- HTTPClient (built-in ESP32)

### Configuration

Before uploading, set your WiFi credentials and Firebase project details at the top of `esp32_safetrack.ino`.