## FPGA Core (`/iot-fpga`)

The Gowin Tang Nano 9K serves as the deterministic brain of the system. It is strictly responsible for hardwired safety monitoring and emergency execution, completely decoupled from internet dependencies.

### Key FPGA Features
- **Hardware-Level Sensor Polling:** Reads flame, smoke, crash (via I2C), and physical seat occupancy sensors concurrently with zero software overhead.
- **Hardware GPS Passthrough:** A unique logic hack that temporarily bridges the NEO-6M GPS `TX` directly to the SIM800L GSM `RX` during an emergency. This allows the raw NMEA `$GPGGA` stream to be injected directly into an SMS without complex string parsing in Verilog.
- **Internet Bypass:** In the event of a crash or fire, the FPGA suspends normal UART telemetry to the ESP32 and directly triggers the GSM module to dispatch an SMS to authorities, ensuring safety even if Wi-Fi or Cloud infrastructure fails.

## Tech Stack

| Component  | Technology                                         |
|------------|----------------------------------------------------|
| FPGA Edge  | Verilog HDL                                        |
| Hardware   | Gowin Tang Nano 9K (GW1NR-LV9QN88PC6/I5)           |
| Toolchain  | Gowin EDA                                          |

## Setup

### IoT Edge Synthesis
1. Open the `.gprj` project file in **Gowin EDA**.
2. Ensure your device is set to the Tang Nano 9K (`GW1NR-LV9QN88PC6/I5`).
3. Run **Synthesize** -> **Place & Route**.
4. Use the Gowin Programmer tool to flash the `.fs` bitstream directly to SRAM or onboard Flash.

## Sensors & Pinout (Gowin `.cst`)

| Hardware      | Purpose                          | Pin | Interface / Notes |
|---------------|----------------------------------|-----|-------------------|
| System Clock  | Master 27MHz Timing              | 52  | Internal          |
| MPU-6050      | High-G impact / crash detection  | 25/26| I2C (SDA/SCL)     |
| IR Flame      | Live fire detection              | 27  | Active Low        |
| MQ-2          | Smoke and combustible gas        | 28  | Active Low        |
| Limit Switch  | Physical seat occupancy sensing  | 29  | Active Low (GND)  |
| NEO-6M        | Continuous GPS location tracking | 31  | UART RX (From TX) |
| SIM800L       | Zero-latency emergency SMS       | 32/33| UART TX/RX        |

> **⚠️ Wiring Warning:** Remember that UART connections must be crossed. The FPGA's `gps_rx` pin (31) must connect to the GPS module's `TX` pin. The FPGA's `gsm_tx` pin (32) connects to the GSM's `RX` pin.

## License

Developed by **Subhash Chowdary** as part of a university capstone project at **Aditya University, ECE Department (2026)**.
"""

with open("SmartBus_FPGA_README.md", "w", encoding="utf-8") as f:
    f.write(readme_content)

print("SmartBus_FPGA_README.md generated successfully.")