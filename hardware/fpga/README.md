# SafeTrack FPGA Core (`/fpga_tang_nano_9k`)

> FPGA-Based Real-Time Bus Safety Monitoring and Emergency Response System

---

## Overview

The **SafeTrack FPGA Core** is the deterministic hardware engine responsible for real-time passenger safety monitoring and emergency handling inside the Smart Bus Safety System.

Built on the **Gowin Tang Nano 9K FPGA**, the subsystem continuously monitors multiple onboard sensors and independently executes emergency actions without relying on cloud connectivity, Wi-Fi, or external software services.

The FPGA performs:

* Crash detection using MPU6050 accelerometer data
* Fire and smoke detection
* Passenger occupancy monitoring
* UART telemetry transmission
* Emergency GSM calling and SMS dispatch
* GPS emergency location forwarding

This architecture ensures ultra-low-latency emergency response during critical situations.

---

# Key Features

## Hardware-Level Parallel Monitoring

The FPGA continuously monitors all connected sensors concurrently using deterministic hardware logic.

### Monitored Sensors

* MPU6050 Accelerometer (Crash Detection)
* Flame Sensor
* MQ2 Smoke/Gas Sensor
* Passenger Seat Limit Switches

Unlike software-driven polling systems, the FPGA executes monitoring in parallel with minimal processing latency.

---

## Internet-Independent Emergency Handling

The FPGA includes an independent GSM emergency controller capable of:

* Dialing emergency services
* Sending emergency SMS alerts
* Forwarding GPS location data

This emergency path remains operational even when:

* Wi-Fi is unavailable
* Firebase is offline
* ESP32 crashes
* Internet connectivity fails

---

## GPS Emergency Location Forwarding

During emergency conditions, GPS data from the NEO-6M module is forwarded directly to the SIM800L GSM module for emergency SMS generation.

This hardware-assisted passthrough architecture:

* reduces FPGA complexity
* avoids large string parsing logic
* minimizes emergency latency

---

## UART Telemetry Transmission

The FPGA periodically transmits telemetry data to the ESP32 using UART communication.

### Example Telemetry

```text
SAFE CLEAN SAFE SEATS2
FLAME! SMOKE! CRASH! SEATS4
```

---

# System Architecture

```text
                    +----------------------+
                    |   Gowin Tang Nano    |
                    |       FPGA Core      |
                    +----------+-----------+
                               |
        -------------------------------------------------
        |               |               |               |
   MPU6050         Flame Sensor     MQ2 Sensor     Seat Sensors
   (I2C)              (GPIO)          (GPIO)          (GPIO)
        |
        |
  Crash Detection
        |
        +-----------------------------+
                                      |
                               Emergency FSM
                                      |
                    --------------------------------
                    |                              |
                SIM800L                        ESP32
              GSM Module                  Telemetry Node
                    |                              |
           Emergency SMS                  Firebase Upload
           Emergency Call                 Dashboard Sync
                                                   |
                                             Mobile App
```

---

# Emergency Flow

## 1. Continuous Sensor Monitoring

The FPGA continuously samples:

* acceleration values
* smoke detection signals
* fire detection signals
* passenger occupancy

using synchronized hardware logic.

---

## 2. Crash Detection

The MPU6050 communicates through a custom Verilog I2C controller.

The FPGA evaluates:

* sudden acceleration spikes
* high-impact threshold violations
* abnormal motion changes

### Crash Threshold

```verilog
parameter signed CRASH_THRESHOLD = 16'sd18000;
```

If the threshold is exceeded, emergency logic activates immediately.

---

## 3. Emergency Trigger

The FPGA activates emergency mode when any hazardous condition occurs.

### Trigger Conditions

```verilog
assign emergency_flag =
       is_crashing ||
      !flame_sync  ||
      !mq2_sync;
```

---

## 4. GSM Emergency Execution

The FPGA:

1. Dials emergency number `112`
2. Sends emergency SMS
3. Forwards GPS coordinates

### Example SMS

```text
EMG! Loc: https://maps.google.com/?q=17.3850,78.4867
```

---

## 5. Cloud Telemetry

Simultaneously:

* telemetry is sent to ESP32
* ESP32 uploads data to Firebase
* dashboard and mobile applications update in real-time

---

# Communication Parameters

| Interface        | Configuration |
| ---------------- | ------------- |
| UART             | 9600 baud     |
| I2C              | 100 kHz       |
| FPGA Clock       | 27 MHz        |
| Sensor Interface | GPIO + I2C    |

---

# Source Files

| File             | Description                      |
| ---------------- | -------------------------------- |
| `sensors.v`      | Main FPGA safety controller      |
| `mpu6050_I2C.v`  | MPU6050 I2C communication engine |
| `constraint.cst` | FPGA pin constraints             |
| `test_bench.v`   | Simulation testbench             |
| `SafeTrack.gprj` | Gowin EDA project                |

---

# Hardware Pinout

| Hardware      | Purpose             | FPGA Pin | Interface |
| ------------- | ------------------- | -------- | --------- |
| System Clock  | 27MHz Timing        | 52       | Clock     |
| MPU6050 SDA   | Accelerometer Data  | 25       | I2C       |
| MPU6050 SCL   | Accelerometer Clock | 26       | I2C       |
| Flame Sensor  | Fire Detection      | 27       | GPIO      |
| MQ2 Sensor    | Smoke Detection     | 28       | GPIO      |
| Seat Sensor 1 | Passenger Detection | 29       | GPIO      |
| Seat Sensor 2 | Passenger Detection | 30       | GPIO      |
| Seat Sensor 3 | Passenger Detection | 41       | GPIO      |
| Seat Sensor 4 | Passenger Detection | 42       | GPIO      |
| GPS RX        | GPS Serial Input    | 31       | UART      |
| GSM TX        | GSM Communication   | 32       | UART      |
| GSM RX        | GSM Communication   | 33       | UART      |
| UART TX       | ESP32 Telemetry     | 63       | UART      |

---

# Simulation & Verification

The FPGA subsystem was validated using:

* Icarus Verilog
* GTKWave waveform analysis
* UART verification
* I2C verification
* GSM FSM testing
* Passenger occupancy simulation
* Crash detection testing

### Verified Features

* Sensor synchronization
* UART transmission
* GSM emergency state transitions
* Crash threshold detection
* Seat occupancy counting
* I2C communication behavior

---

# Simulation Results

Waveform and simulation artifacts may be stored in:

```text
simulation_results/
```

Example artifacts:

* UART waveform screenshots
* GSM FSM transitions
* Crash detection waveforms
* Simulation logs
* VCD waveform files

---

# Setup Instructions

## 1. Open Project

Open the project inside **Gowin EDA**:

```text
SafeTrack.gprj
```

---

## 2. Configure Device

Ensure target FPGA device is:

```text
GW1NR-LV9QN88PC6/I5
```

---

## 3. Build FPGA Design

Run:

1. Synthesize
2. Place & Route

---

## 4. Generate Bitstream

Generate:

```text
.fs
```

bitstream file.

---

## 5. Program FPGA

Using Gowin Programmer:

* Flash to SRAM
  OR
* Flash to onboard memory

---

# Repository Structure

```text
fpga_tang_nano_9k/
├── sensors.v
├── mpu6050_I2C.v
├── constraint.cst
├── test_bench.v
├── SafeTrack.gprj
├── simulation_results/
└── hardware-validation/
```

---

# Out of Scope

* Automated fire suppression systems
* Live video surveillance
* Audio recording
* AI-based passenger recognition
* Cloud-independent GPS parsing

---

# Tech Stack

| Category            | Technology               |
| ------------------- | ------------------------ |
| FPGA Design         | Verilog HDL              |
| FPGA Board          | Gowin Tang Nano 9K       |
| Toolchain           | Gowin EDA                |
| Simulation          | Icarus Verilog + GTKWave |
| Cloud               | Firebase                 |
| Embedded Controller | ESP32                    |
| GSM                 | SIM800L                  |
| GPS                 | NEO-6M                   |

---
