# SafeTrack FPGA Core (`/fpga_tang_nano_9k`)

The Gowin Tang Nano 9K serves as the deterministic brain of the system. It is strictly responsible for hardwired safety monitoring and emergency execution, completely decoupled from internet dependencies.

## Key Features
- **Hardware-Level Sensor Polling:** Reads flame, smoke, crash (MPU-6050 via I2C), and physical seat occupancy sensors concurrently with Low software overhead.
- **Hardware GPS Passthrough:** Temporarily bridges the NEO-6M GPS `TX` directly to the SIM800L GSM `RX` during an emergency, injecting raw NMEA data directly into an SMS without complex string parsing in Verilog.
- **Internet Bypass:** On crash or fire, the FPGA latches an independent GSM state machine that dials 112 and dispatches an SMS to authorities — ensuring safety even if Wi-Fi or Cloud infrastructure fails.

---

## Emergency Flow

1. FPGA continuously monitors all connected sensors in hardware.
2. MPU-6050 communicates through the custom I2C controller.
3. When crash, fire, or smoke thresholds are exceeded:
   - FPGA latches the emergency state
   - GPS data is forwarded to the GSM module
   - SIM800L sends emergency SMS and initiates a call
4. Telemetry data is simultaneously transmitted to ESP32 through UART.
5. ESP32 uploads real-time data to Firebase for dashboard and mobile application monitoring.

---

## Source Files

| File | Purpose |
|------|---------|
| `sensors.v` | Top module — sensor sync, UART TX, GSM/GPS emergency state machine |
| `mpu6050_I2C.v` | I2C engine for MPU-6050 accelerometer crash detection |
| `constraint.cst` | Gowin pin constraint file |
| `test_bench.v` | Icarus Verilog simulation testbench |

---

## Crash Detection Logic

The MPU-6050 accelerometer continuously provides motion and acceleration data through I2C communication.

The FPGA checks:
- Sudden acceleration spikes
- Rapid orientation changes
- High-impact threshold violations

If the measured values exceed predefined limits, the FPGA activates emergency handling logic and GSM communication.

---

## Tech Stack

| Component  | Technology                                         |
|------------|---------------------------------------------------|
| FPGA       | Verilog HDL                                        |
| Hardware   | Gowin Tang Nano 9K (GW1NR-LV9QN88PC6/I5)          |
| Toolchain  | Gowin EDA                                          |
| Simulation | Icarus Verilog + GTKWave                          |

---

## Setup

1. Open the `.gprj` project file in **Gowin EDA**.
2. Ensure your device is set to the Tang Nano 9K (`GW1NR-LV9QN88PC6/I5`).
3. Run **Synthesize** -> **Place & Route**.
4. Use the Gowin Programmer tool to flash the `.fs` bitstream directly to SRAM or onboard Flash.

---

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

---

## Repository Structure

```text
fpga_tang_nano_9k/
├── sensors.v
├── mpu6050_I2C.v
├── test_bench.v
├── constraint.cst
├── SafeTrack.gprj
└── simulation_results/
```

---

## Verification & Testing

- Sensor logic verified using `test_bench.v`
- UART communication tested with ESP32 and SIM800L
- MPU-6050 I2C communication validated on hardware
- Emergency SMS transmission tested using SIM800L
- Seat occupancy detection verified using physical limit switches
- FPGA synthesis and routing completed successfully using Gowin EDA

---

## Simulation Results

Simulation waveforms generated using:
- Icarus Verilog
- GTKWave

Simulation outputs and waveform screenshots can be stored in:

```text
/simulation_results
```

---

## System Integration

The FPGA core integrates with:
- ESP32 telemetry controller
- Firebase cloud backend
- Admin dashboard
- Flutter mobile application

The FPGA handles deterministic emergency logic, while the ESP32 and cloud infrastructure manage real-time monitoring and user-facing services.

## Verification Support

The FPGA subsystem includes simulation-oriented validation support through `test_bench.v` for prototype-level UART/I2C communication and sensor-integration verification.

## Simulation and Validation

The FPGA subsystem includes `test_bench.v` for prototype-level simulation and validation of UART/I2C communication workflows and sensor-event processing.

---

## License

This project was developed as part of a project Space 2026 at Aditya University, ECE Department (2026).