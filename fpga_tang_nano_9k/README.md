# SafeTrack FPGA Core (`/fpga_tang_nano_9k`)

The Gowin Tang Nano 9K serves as the deterministic brain of the system. It is strictly responsible for hardwired safety monitoring and emergency execution, completely decoupled from internet dependencies.

## Key Features
- **Hardware-Level Sensor Polling:** Reads flame, smoke, crash (MPU-6050 via I2C), and physical seat occupancy sensors concurrently with zero software overhead.
- **Hardware GPS Passthrough:** Temporarily bridges the NEO-6M GPS `TX` directly to the SIM800L GSM `RX` during an emergency, injecting raw NMEA data directly into an SMS without complex string parsing in Verilog.
- **Internet Bypass:** On crash or fire, the FPGA latches an independent GSM state machine that dials 112 and dispatches an SMS to authorities — ensuring safety even if Wi-Fi or Cloud infrastructure fails.

## Source Files

| File | Purpose |
|------|---------|
| `sensors.v` | Top module — sensor sync, UART TX, GSM/GPS emergency state machine |
| `mpu6050_I2C.v` | I2C engine for MPU-6050 accelerometer crash detection |
| `constraint.cst` | Gowin pin constraint file |
| `test_bench.v` | Icarus Verilog simulation testbench |

## Tech Stack

| Component  | Technology                                         |
|------------|---------------------------------------------------|
| FPGA       | Verilog HDL                                        |
| Hardware   | Gowin Tang Nano 9K (GW1NR-LV9QN88PC6/I5)          |
| Toolchain  | Gowin EDA                                          |

## Setup

1. Open the `.gprj` project file in **Gowin EDA**.
2. Ensure your device is set to the Tang Nano 9K (`GW1NR-LV9QN88PC6/I5`).
3. Run **Synthesize** -> **Place & Route**.
4. Use the Gowin Programmer tool to flash the `.fs` bitstream directly to SRAM or onboard Flash.

## Sensors & Pinout

| Hardware      | Purpose                          | Pin   | Interface / Notes |
|---------------|----------------------------------|-------|-------------------|
| System Clock  | Master 27MHz Timing              | 52    | Internal          |
| MPU-6050      | High-G impact / crash detection  | 25/26 | I2C (SDA/SCL)     |
| IR Flame      | Live fire detection              | 27    | Active Low        |
| MQ-2          | Smoke and combustible gas        | 28    | Active Low        |
| Limit Switch 1| Physical seat occupancy sensing  | 29    | Active Low (GND)  |
| Limit Switch 2| Physical seat occupancy sensing  | 30    | Active Low (GND)  |
| Limit Switch 3| Physical seat occupancy sensing  | 41    | Active Low (GND)  |
| Limit Switch 4| Physical seat occupancy sensing  | 42    | Active Low (GND)  |
| NEO-6M        | Continuous GPS location tracking | 31    | UART RX (From TX) |
| SIM800L       | Zero-latency emergency SMS       | 32/33 | UART TX/RX        |
| ESP32 UART    | Normal telemetry output          | 63    | UART TX           |

> **⚠️ Wiring Warning:** UART connections must be crossed. The FPGA's `gps_rx` pin (31) connects to the GPS module's `TX` pin. The FPGA's `gsm_tx` pin (32) connects to the GSM's `RX` pin.

## License

Developed by **Subhash Chowdary** as part of a university capstone project at **Aditya University, ECE Department (2026)**.