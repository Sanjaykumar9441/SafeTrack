# SafeTrack Embedded Hardware Layer

The SafeTrack hardware subsystem provides FPGA-assisted telemetry processing, ESP32-based sensor acquisition, UART/I2C communication workflows, GPS telemetry handling, and GSM emergency escalation support for the intelligent public transportation safety platform.

---

# Hardware Architecture

The embedded hardware layer is divided into two major sections:

1. FPGA Logic Layer
2. ESP32 Telemetry Firmware Layer

These components work together to provide realtime telemetry acquisition, emergency detection, and low-latency emergency communication support.

---

# FPGA Modules

Located in:

```txt
hardware/fpga/