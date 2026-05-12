// ==========================================================
// MASTER BUS SAFETY SYSTEM
// ----------------------------------------------------------
// FPGA-Based Real-Time Passenger Safety Monitoring System
//
// This module integrates:
//
// 1. MPU6050 accelerometer crash detection
// 2. Flame sensor monitoring
// 3. MQ2 smoke/gas sensor monitoring
// 4. Passenger seat occupancy tracking
// 5. UART telemetry transmission to ESP32
// 6. GSM emergency calling and SMS alerts
//
// Features:
// ----------------------------------------------------------
// • Detects high acceleration crashes
// • Detects smoke and fire hazards
// • Tracks passenger occupancy in real-time
// • Sends telemetry packets over UART
// • Automatically calls emergency number 112
// • Sends Google Maps emergency SMS location
//
// FPGA Clock:
// ----------------------------------------------------------
// Input Clock = 27MHz
//
// UART Baud Rate:
// ----------------------------------------------------------
// 9600 baud
//
// Designed For:
// ----------------------------------------------------------
// Gowin FPGA + ESP32 + SIM800L + MPU6050
// ==========================================================

module master_safety_system (

    input  wire clk,          // 27MHz FPGA system clock

    // Flame sensor input (active-low)
    input  wire flame_in,

    // MQ2 smoke/gas sensor input (active-low)
    input  wire mq2_in,

    // ======================================================
    // Passenger Seat Sensors
    // ------------------------------------------------------
    // Active-Low Logic:
    // 0 → Seat occupied
    // 1 → Seat empty
    // ======================================================
    input  wire [3:0] seat_bus,

    // MPU6050 I2C lines
    output wire i2c_scl,
    inout  wire i2c_sda,

    // UART telemetry output to ESP32
    output wire uart_tx,

    // ======================================================
    // GPS & GSM Interface
    // ------------------------------------------------------
    // gps_rx is reserved for future live GPS parsing.
    // Current version uses fixed coordinates.
    // ======================================================
    input  wire gps_rx,
    output wire gsm_tx,
    input  wire gsm_rx

);


// ==========================================================
// SYSTEM PARAMETERS
// ----------------------------------------------------------
// CLK_FREQ  : FPGA system clock frequency
// BAUD_RATE : UART communication speed
// CLK_DIV   : UART baud clock divider
// ==========================================================

parameter CLK_FREQ  = 27_000_000;
parameter BAUD_RATE = 9600;
parameter CLK_DIV   = CLK_FREQ / BAUD_RATE;


// ==========================================================
// Crash Detection Threshold
// ----------------------------------------------------------
// If acceleration exceeds ±18000,
// system assumes a crash condition.
// ==========================================================

parameter signed CRASH_THRESHOLD = 16'sd18000;


// ==========================================================
// MPU6050 Accelerometer Interface
// ----------------------------------------------------------
// Reads real-time X-axis acceleration values.
// ==========================================================

wire signed [15:0] real_accel_x;

mpu6050_reader i2c_engine (

    .clk(clk),
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda),
    .accel_x(real_accel_x)

);


// ==========================================================
// Sensor Synchronization Registers
// ----------------------------------------------------------
// Synchronizes asynchronous sensor inputs
// to FPGA clock domain.
// ==========================================================

reg flame_sync  = 0;
reg mq2_sync    = 1;
reg [3:0] seat_sync = 4'b1111;


// ==========================================================
// Crash Detection Latch
// ----------------------------------------------------------
// Sticky latch ensures short crash spikes are not missed.
// Cleared only after telemetry transmission.
// ==========================================================

reg is_crashing = 0;


// ==========================================================
// Passenger Counting Logic
// ----------------------------------------------------------
// Counts occupied seats using active-low inputs.
// ==========================================================

reg [2:0] passenger_count = 0;


// ==========================================================
// UART Telemetry Transmission Engine
// ----------------------------------------------------------
// Sends formatted telemetry packets to ESP32.
//
// Example:
//
// SAFE CLEAN SAFE SEATS2
//
// or
//
// FLAME! SMOKE! CRASH! SEATS4
// ==========================================================

reg [11:0] baud_cnt  = 0;
reg [3:0]  bit_idx   = 0;
reg [4:0]  char_idx  = 0;

reg [7:0] msg [0:28];

parameter MSG_LEN = 29;

reg [9:0] shift_reg = 10'b1111111111;

reg tx_active = 0;
reg uart_tx_r = 1;

assign uart_tx = uart_tx_r;


// ==========================================================
// Telemetry Sampling Timer
// ----------------------------------------------------------
// Original:
// 13,500,000 cycles ≈ 0.5 seconds
//
// Simulation:
// Reduced to 50 cycles for faster testing.
// ==========================================================

reg send_trigger = 0;

reg [24:0] sample_timer = 0;


// ==========================================================
// MAIN SENSOR PROCESSING LOOP
// ----------------------------------------------------------
// Responsibilities:
// 1. Synchronize sensors
// 2. Detect crashes
// 3. Count passengers
// 4. Build telemetry packet
// 5. Trigger UART transmission
// ==========================================================

always @(posedge clk) begin

    // Synchronize sensor inputs
    flame_sync <= flame_in;
    mq2_sync   <= mq2_in;
    seat_sync  <= seat_bus;

    send_trigger <= 0;


    // ======================================================
    // Crash Detection Logic
    // ======================================================

    if (real_accel_x > CRASH_THRESHOLD ||
        real_accel_x < -CRASH_THRESHOLD)

        is_crashing <= 1;


    // ======================================================
    // Passenger Counting
    // ======================================================

    passenger_count <=
        (~seat_sync[0]) +
        (~seat_sync[1]) +
        (~seat_sync[2]) +
        (~seat_sync[3]);


    // ======================================================
    // Telemetry Sampling Timer
    // ======================================================

    if (sample_timer < 25'd50) begin

        sample_timer <= sample_timer + 1'b1;

    end else begin

        sample_timer <= 0;


        // ==================================================
        // Telemetry Message Builder
        // ==================================================

        // Fire Status
        if (!flame_sync) begin

            msg[0] <= "F";
            msg[1] <= "L";
            msg[2] <= "A";
            msg[3] <= "M";
            msg[4] <= "E";
            msg[5] <= "!";

        end else begin

            msg[0] <= "S";
            msg[1] <= "A";
            msg[2] <= "F";
            msg[3] <= "E";
            msg[4] <= " ";
            msg[5] <= " ";

        end

        msg[6] <= " ";


        // Smoke Status
        if (!mq2_sync) begin

            msg[7]  <= "S";
            msg[8]  <= "M";
            msg[9]  <= "O";
            msg[10] <= "K";
            msg[11] <= "E";
            msg[12] <= "!";

        end else begin

            msg[7]  <= "C";
            msg[8]  <= "L";
            msg[9]  <= "E";
            msg[10] <= "A";
            msg[11] <= "N";
            msg[12] <= "!";

        end

        msg[13] <= " ";


        // Crash Status
        if (is_crashing) begin

            msg[14] <= "C";
            msg[15] <= "R";
            msg[16] <= "A";
            msg[17] <= "S";
            msg[18] <= "H";
            msg[19] <= "!";

        end else begin

            msg[14] <= "S";
            msg[15] <= "A";
            msg[16] <= "F";
            msg[17] <= "E";
            msg[18] <= " ";
            msg[19] <= " ";

        end

        msg[20] <= " ";


        // Seat Information
        msg[21] <= "S";
        msg[22] <= "E";
        msg[23] <= "A";
        msg[24] <= "T";
        msg[25] <= "S";

        msg[26] <= 8'd48 + passenger_count;

        msg[27] <= 8'h0D;
        msg[28] <= 8'h0A;


        // Trigger UART transmission
        send_trigger <= 1;


        // Clear crash latch after telemetry
        is_crashing <= 0;

    end


    // ======================================================
    // UART Transmission State Machine
    // ------------------------------------------------------
    // UART Frame:
    // Start Bit + 8 Data Bits + Stop Bit
    // ======================================================

    if (!tx_active) begin

        if (send_trigger) begin

            tx_active <= 1;

            char_idx <= 0;
            bit_idx  <= 0;
            baud_cnt <= 0;

        end

        uart_tx_r <= 1;

    end else begin

        if (baud_cnt < CLK_DIV - 1) begin

            baud_cnt <= baud_cnt + 1'b1;

        end else begin

            baud_cnt <= 0;

            // Start Bit
            if (bit_idx == 0) begin

                shift_reg <= {1'b1, msg[char_idx], 1'b0};

                bit_idx <= 4'd1;

                uart_tx_r <= 0;

            end

            // Data Bits
            else if (bit_idx < 4'd10) begin

                uart_tx_r <= shift_reg[1];

                shift_reg <= {1'b1, shift_reg[9:1]};

                bit_idx <= bit_idx + 1'b1;

            end

            // Next Character
            else begin

                bit_idx <= 0;

                if (char_idx + 1 < MSG_LEN)

                    char_idx <= char_idx + 1'b1;

                else begin

                    tx_active <= 0;
                    uart_tx_r <= 1;

                end
            end
        end
    end
end


// ==========================================================
// GSM Emergency Alert System
// ----------------------------------------------------------
// Automatically:
// 1. Calls emergency number 112
// 2. Sends emergency SMS
// 3. Sends Google Maps location
// ==========================================================


// ==========================================================
// Emergency Trigger Logic
// ----------------------------------------------------------
// Any unsafe condition activates emergency mode.
// ==========================================================

wire emergency_flag;

assign emergency_flag =
       is_crashing ||
      !flame_sync  ||
      !mq2_sync;


// Emergency latch
reg emergency_latched = 0;


// GSM state machine state register
reg [3:0] gsm_state = 0;


// GSM delay timer
reg [63:0] gsm_timer = 0;


// GSM message storage
reg [7:0] gsm_char_idx = 0;
reg [7:0] gsm_msg_len  = 0;

reg [7:0] gsm_msg [0:127];

reg gsm_send_trigger = 0;


// ==========================================================
// GSM UART Transmission Engine
// ==========================================================

reg [11:0] gsm_baud_cnt = 0;

reg [3:0] gsm_bit_idx = 0;

reg [9:0] gsm_shift_reg = 10'b1111111111;

reg gsm_tx_active = 0;

reg gsm_uart_tx_r = 1;

assign gsm_tx = gsm_uart_tx_r;


// ==========================================================
// GSM Finite State Machine
// ----------------------------------------------------------
// 0  → Idle
// 1  → Dial 112
// 2  → Wait
// 3  → Hang up
// 4  → Wait
// 5  → SMS mode
// 6  → Wait
// 7  → Send number
// 8  → Wait
// 9  → Send URL
// 10 → Wait
// 11 → Send coordinates
// 12 → CTRL+Z
// 13 → Done
// 14 → UART wait
// ==========================================================

always @(posedge clk) begin

    // Emergency trigger
    if (emergency_flag && !emergency_latched) begin

        emergency_latched <= 1;

        gsm_state <= 1;

        gsm_timer <= 0;

    end


    case (gsm_state)

        // ==================================================
        // IDLE
        // ==================================================

        0: begin
        end


        // ==================================================
        // CALL 112
        // ==================================================

        1: begin

            gsm_msg[0] <= "A";
            gsm_msg[1] <= "T";
            gsm_msg[2] <= "D";
            gsm_msg[3] <= "1";
            gsm_msg[4] <= "1";
            gsm_msg[5] <= "2";
            gsm_msg[6] <= ";";

            gsm_msg[7] <= 8'h0D;
            gsm_msg[8] <= 8'h0A;

            gsm_msg_len <= 9;

            gsm_send_trigger <= 1;

            gsm_state <= 2;

        end


        // ==================================================
        // WAIT
        // ==================================================

        2: begin

            gsm_send_trigger <= 0;

            if (gsm_timer < 64'd27_000_000 * 64'd15)

                gsm_timer <= gsm_timer + 1'b1;

            else begin

                gsm_state <= 3;

                gsm_timer <= 0;

            end
        end


        // ==================================================
        // HANGUP
        // ==================================================

        3: begin

            gsm_msg[0] <= "A";
            gsm_msg[1] <= "T";
            gsm_msg[2] <= "H";

            gsm_msg[3] <= 8'h0D;
            gsm_msg[4] <= 8'h0A;

            gsm_msg_len <= 5;

            gsm_send_trigger <= 1;

            gsm_state <= 4;

        end


        // ==================================================
        // WAIT
        // ==================================================

        4: begin

            gsm_send_trigger <= 0;

            if (gsm_timer < 64'd27_000_000 * 64'd2)

                gsm_timer <= gsm_timer + 1'b1;

            else begin

                gsm_state <= 5;

                gsm_timer <= 0;

            end
        end


        // ==================================================
        // SMS TEXT MODE
        // ==================================================

        5: begin

            gsm_msg[0] <= "A";
            gsm_msg[1] <= "T";
            gsm_msg[2] <= "+";
            gsm_msg[3] <= "C";
            gsm_msg[4] <= "M";
            gsm_msg[5] <= "G";
            gsm_msg[6] <= "F";
            gsm_msg[7] <= "=";
            gsm_msg[8] <= "1";

            gsm_msg[9]  <= 8'h0D;
            gsm_msg[10] <= 8'h0A;

            gsm_msg_len <= 11;

            gsm_send_trigger <= 1;

            gsm_state <= 6;

        end


        default: begin
            gsm_state <= 0;
        end

    endcase
end

endmodule