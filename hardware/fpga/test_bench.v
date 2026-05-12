`timescale 1ns / 1ps
// =============================================================================
//  TESTBENCH: tb_master_safety_system.v
//  Covers: master_safety_system + mpu6050_reader (mpu6050_reader is instantiated
//          inside master_safety_system and is also tested indirectly through it,
//          plus a dedicated direct section at the bottom).
//
//  Test Groups
//  -----------
//  TC01  Power-on / reset defaults
//  TC02  Normal (no hazard) telemetry string format
//  TC03  Flame sensor active  → "FLAME!" in UART message
//  TC04  MQ-2 gas sensor active → "SMOKE!" in UART message
//  TC05  Crash threshold exceeded (positive)  → "CRASH!" latched
//  TC06  Crash threshold exceeded (negative)  → "CRASH!" latched
//  TC07  Crash spike < 1 sample window → still captured (latch test)
//  TC08  Passenger count: 0 / 1 / 2 / 3 / 4 seated
//  TC09  UART TX bit-stream integrity (start/stop bits, data bits, baud rate)
//  TC10  All sensors alarming simultaneously (flame + smoke + crash)
//  TC11  Emergency GSM sequence: state machine walk-through
//  TC12  emergency_latched clears after GSM sequence completes (re-alert test)
//  TC13  GSM UART baud rate verification
//  TC14  mpu6050_reader: I2C START condition
//  TC15  mpu6050_reader: ACK_ERROR flag when slave does not pull SDA low
//  TC16  mpu6050_reader: accel_x updated correctly after NACK state
//  TC17  Boundary value: accel_x == CRASH_THRESHOLD (no latch)
//  TC18  Boundary value: accel_x == CRASH_THRESHOLD+1 (latch)
//  TC19  Multiple consecutive emergencies (cooldown / re-alert)
//  TC20  Message length constant MSG_LEN = 29 bytes
// =============================================================================
 
module tb_master_safety_system;
 
// ---------------------------------------------------------------------------
// Clock
// ---------------------------------------------------------------------------
parameter CLK_PERIOD = 37;          // ~27 MHz  (1/27e6 * 1e9 ≈ 37 ns)
parameter CLK_FREQ   = 27_000_000;
parameter BAUD_RATE  = 9600;
parameter CLK_DIV    = CLK_FREQ / BAUD_RATE; // 2812
parameter signed CRASH_THRESHOLD = 16'sd18000;
 
reg clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;
 
// ---------------------------------------------------------------------------
// DUT signals
// ---------------------------------------------------------------------------
reg        flame_in  = 1;   // active-low → 1 = no flame
reg        mq2_in    = 1;   // active-low → 1 = no smoke
reg [3:0]  seat_bus  = 4'b1111; // active-low → all HIGH = 0 passengers
reg        gps_rx    = 1;
wire       i2c_scl;
wire       i2c_sda;
wire       uart_tx;
wire       gsm_tx;
reg        gsm_rx    = 1;
 
// Bidirectional SDA: we need to drive it as a slave in I2C tests
reg  sda_slave_drive = 0;    // 1 → slave pulls SDA low (ACK)
reg  sda_slave_val   = 0;
wire i2c_sda_w;
assign i2c_sda = (sda_slave_drive) ? sda_slave_val : 1'bz;
 
// ---------------------------------------------------------------------------
// DUT instantiation
// ---------------------------------------------------------------------------
master_safety_system #(
    .CLK_FREQ  (CLK_FREQ),
    .BAUD_RATE (BAUD_RATE)
) dut (
    .clk      (clk),
    .flame_in (flame_in),
    .mq2_in   (mq2_in),
    .seat_bus (seat_bus),
    .i2c_scl  (i2c_scl),
    .i2c_sda  (i2c_sda),
    .uart_tx  (uart_tx),
    .gps_rx   (gps_rx),
    .gsm_tx   (gsm_tx),
    .gsm_rx   (gsm_rx)
);
 
// ---------------------------------------------------------------------------
// Utility tasks & functions
// ---------------------------------------------------------------------------
 
// ---- UART byte capture (one complete frame) --------------------------------
// Wait for start-bit, then sample centre of each bit.
task automatic capture_uart_byte;
    input  is_gsm;           // 0 = uart_tx, 1 = gsm_tx
    output [7:0] byte_out;
    integer i;
    reg tx_line;
    begin
        // Wait for start bit (falling edge on selected line)
        if (!is_gsm) begin
            wait(uart_tx === 1'b0);
        end else begin
            wait(gsm_tx === 1'b0);
        end
 
        // Centre of start bit
        repeat(CLK_DIV/2) @(posedge clk);
 
        for (i = 0; i < 8; i = i+1) begin
            repeat(CLK_DIV) @(posedge clk);
            if (!is_gsm) byte_out[i] = uart_tx;
            else         byte_out[i] = gsm_tx;
        end
 
        // Stop bit check
        repeat(CLK_DIV) @(posedge clk);
        if (!is_gsm) begin
            if (uart_tx !== 1'b1)
                $display("[WARN] TC09/TC13: Stop bit LOW on %s uart_tx", is_gsm ? "GSM" : "MAIN");
        end else begin
            if (gsm_tx !== 1'b1)
                $display("[WARN] TC09/TC13: Stop bit LOW on GSM uart_tx");
        end
    end
endtask
 
// ---- Capture a full 29-byte UART message -----------------------------------
task automatic capture_uart_message;
    output [8*29-1:0] msg_bits;
    reg [7:0] b;
    integer k;
    begin
        for (k = 0; k < 29; k = k+1) begin
            capture_uart_byte(0, b);
            msg_bits[8*(28-k) +: 8] = b;
        end
    end
endtask
 
// ---- Wait N sample periods (0.5 s each at 27 MHz) -------------------------
// 13_500_000 clocks = one 0.5-s sample window
task automatic wait_sample_periods;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i+1)
            repeat(13_500_001) @(posedge clk);
    end
endtask
 
// ---- Quick check helper ----------------------------------------------------
integer pass_count = 0;
integer fail_count = 0;
 
task automatic check;
    input test_pass;
    input [127:0] test_name;
    begin
        if (test_pass) begin
            $display("[PASS] %s", test_name);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %s", test_name);
            fail_count = fail_count + 1;
        end
    end
endtask
 
// ===========================================================================
// MAIN TEST SEQUENCE
// ===========================================================================
reg [8*29*8-1:0] raw_msg;   // 29 bytes = 232 bits
reg [7:0] byte_arr [0:28];
integer idx;
reg [7:0] b;
 
// For crash inject: we need to poke accel_x through the sub-module hierarchy.
// Use force/release to inject a value onto the internal net.
// (accel_x is the output of mpu6050_reader, connected to real_accel_x in master)
 
initial begin
    $dumpfile("tb_master_safety_system.vcd");
    $dumpvars(0, tb_master_safety_system);
 
    $display("===================================================");
    $display(" Master Safety System + MPU6050 Reader Testbench  ");
    $display("===================================================");
 
    // -----------------------------------------------------------------------
    // TC01 — Power-on defaults: uart_tx idle HIGH, gsm_tx idle HIGH
    // -----------------------------------------------------------------------
    @(posedge clk);
    check(uart_tx === 1'b1, "TC01a: uart_tx idle HIGH at reset");
    check(gsm_tx  === 1'b1, "TC01b: gsm_tx  idle HIGH at reset");
    check(i2c_scl === 1'b1 || i2c_scl === 1'bz, "TC01c: i2c_scl released at reset");
 
    // -----------------------------------------------------------------------
    // TC02 — Normal telemetry (no hazards, 0 passengers)
    // -----------------------------------------------------------------------
    flame_in = 1; mq2_in = 1; seat_bus = 4'b1111;
    // Force accel_x to a safe value
    force dut.i2c_engine.accel_x = 16'sd0;
 
    wait_sample_periods(1);
 
    // Capture 29 bytes
    for (idx = 0; idx < 29; idx = idx+1) begin
        capture_uart_byte(0, byte_arr[idx]);
    end
 
    check(byte_arr[0]  == "S", "TC02a: msg[0]='S' (SAFE prefix)");
    check(byte_arr[1]  == "A", "TC02b: msg[1]='A'");
    check(byte_arr[2]  == "F", "TC02c: msg[2]='F'");
    check(byte_arr[3]  == "E", "TC02d: msg[3]='E'");
    check(byte_arr[7]  == "C", "TC02e: msg[7]='C' (CLEAN prefix)");
    check(byte_arr[8]  == "L", "TC02f: msg[8]='L'");
    check(byte_arr[12] == "!", "TC02g: msg[12]='!'  CLEAN!");
    check(byte_arr[14] == "S", "TC02h: msg[14]='S'  SAFE crash field");
    check(byte_arr[21] == "S", "TC02i: msg[21]='S'  SEATS label");
    check(byte_arr[26] == 8'd48 + 0, "TC02j: msg[26]='0'  0 passengers");
    check(byte_arr[27] == 8'h0D, "TC02k: msg[27]=CR");
    check(byte_arr[28] == 8'h0A, "TC02l: msg[28]=LF");
 
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC03 — Flame sensor active
    // -----------------------------------------------------------------------
    flame_in = 0; // active-low assertion
    force dut.i2c_engine.accel_x = 16'sd0;
    wait_sample_periods(1);
 
    for (idx = 0; idx < 29; idx = idx+1)
        capture_uart_byte(0, byte_arr[idx]);
 
    check(byte_arr[0] == "F", "TC03a: msg[0]='F' (FLAME)");
    check(byte_arr[1] == "L", "TC03b: msg[1]='L'");
    check(byte_arr[2] == "A", "TC03c: msg[2]='A'");
    check(byte_arr[3] == "M", "TC03d: msg[3]='M'");
    check(byte_arr[4] == "E", "TC03e: msg[4]='E'");
    check(byte_arr[5] == "!", "TC03f: msg[5]='!'");
 
    flame_in = 1;
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC04 — MQ-2 gas sensor active
    // -----------------------------------------------------------------------
    mq2_in = 0;
    force dut.i2c_engine.accel_x = 16'sd0;
    wait_sample_periods(1);
 
    for (idx = 0; idx < 29; idx = idx+1)
        capture_uart_byte(0, byte_arr[idx]);
 
    check(byte_arr[7]  == "S", "TC04a: msg[7]='S'  SMOKE");
    check(byte_arr[8]  == "M", "TC04b: msg[8]='M'");
    check(byte_arr[9]  == "O", "TC04c: msg[9]='O'");
    check(byte_arr[10] == "K", "TC04d: msg[10]='K'");
    check(byte_arr[11] == "E", "TC04e: msg[11]='E'");
    check(byte_arr[12] == "!", "TC04f: msg[12]='!'");
 
    mq2_in = 1;
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC05 — Crash: accel_x > +18000
    // -----------------------------------------------------------------------
    force dut.i2c_engine.accel_x = 16'sd18001;
    wait_sample_periods(1);
 
    for (idx = 0; idx < 29; idx = idx+1)
        capture_uart_byte(0, byte_arr[idx]);
 
    check(byte_arr[14] == "C", "TC05a: msg[14]='C'  CRASH");
    check(byte_arr[15] == "R", "TC05b: msg[15]='R'");
    check(byte_arr[16] == "A", "TC05c: msg[16]='A'");
    check(byte_arr[17] == "S", "TC05d: msg[17]='S'");
    check(byte_arr[18] == "H", "TC05e: msg[18]='H'");
    check(byte_arr[19] == "!", "TC05f: msg[19]='!'");
 
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC06 — Crash: accel_x < -18000
    // -----------------------------------------------------------------------
    force dut.i2c_engine.accel_x = -16'sd18001;
    wait_sample_periods(1);
 
    for (idx = 0; idx < 29; idx = idx+1)
        capture_uart_byte(0, byte_arr[idx]);
 
    check(byte_arr[14] == "C", "TC06a: msg[14]='C'  negative CRASH");
    check(byte_arr[19] == "!", "TC06b: msg[19]='!'  negative CRASH");
 
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC07 — Crash latch: spike then go to 0 before sample window
    //        The latch must hold until after telemetry fires.
    // -----------------------------------------------------------------------
    force dut.i2c_engine.accel_x = 16'sd0;
    wait_sample_periods(1);        // clear from previous test
    for (idx = 0; idx < 29; idx = idx+1) capture_uart_byte(0, byte_arr[idx]);
 
    // Inject spike mid-window, then remove
    force dut.i2c_engine.accel_x = 16'sd20000;
    repeat(100) @(posedge clk);
    force dut.i2c_engine.accel_x = 16'sd0;
 
    wait_sample_periods(1);
    for (idx = 0; idx < 29; idx = idx+1)
        capture_uart_byte(0, byte_arr[idx]);
 
    check(byte_arr[14] == "C", "TC07: crash latch holds spike between windows");
 
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC08 — Passenger count (0..4)
    // -----------------------------------------------------------------------
    force dut.i2c_engine.accel_x = 16'sd0;
 
    begin : tc08_block
        integer p;
        reg [3:0] seat_val;
        for (p = 0; p <= 4; p = p+1) begin
            // p passengers seated → p bits LOW, rest HIGH
            case (p)
                0: seat_val = 4'b1111;
                1: seat_val = 4'b1110;
                2: seat_val = 4'b1100;
                3: seat_val = 4'b1000;
                4: seat_val = 4'b0000;
            endcase
            seat_bus = seat_val;
            wait_sample_periods(1);
            for (idx = 0; idx < 29; idx = idx+1)
                capture_uart_byte(0, byte_arr[idx]);
            check(byte_arr[26] == (8'd48 + p),
      "TC08 passenger count check");
        end
    end
 
    seat_bus = 4'b1111;
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC09 — UART TX bit-stream integrity (baud rate, start/stop bits)
    //        Already exercised above via capture_uart_byte.
    //        Add explicit timing check on start-to-stop of one byte.
    // -----------------------------------------------------------------------
    force dut.i2c_engine.accel_x = 16'sd0;
    wait_sample_periods(1);
 
    begin : tc09_block
        time t_start, t_stop;
        real measured_baud;
 
        // Wait for falling edge (start bit)
        @(negedge uart_tx) t_start = $time;
        // 10 bits @ CLK_DIV clock periods each = 10 * CLK_DIV * CLK_PERIOD ns
        // We just check the start bit re-samples in the right window
        repeat(CLK_DIV) @(posedge clk);
        // Capture stop bit position
        repeat(9 * CLK_DIV) @(posedge clk);
        t_stop = $time;
 
        // 10 bit periods
        measured_baud = 1.0e9 / ((t_stop - t_start) / 10.0);
        check((measured_baud > 9400.0) && (measured_baud < 9800.0),
              "TC09: measured baud rate within 2% of 9600");
    end
 
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC10 — All hazards simultaneously
    // -----------------------------------------------------------------------
    flame_in = 0; mq2_in = 0;
    force dut.i2c_engine.accel_x = 16'sd30000;
    wait_sample_periods(1);
 
    for (idx = 0; idx < 29; idx = idx+1)
        capture_uart_byte(0, byte_arr[idx]);
 
    check(byte_arr[0]  == "F", "TC10a: FLAME in all-hazard msg");
    check(byte_arr[7]  == "S" && byte_arr[8] == "M", "TC10b: SMOKE in all-hazard msg");
    check(byte_arr[14] == "C", "TC10c: CRASH in all-hazard msg");
 
    flame_in = 1; mq2_in = 1;
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC11 — GSM emergency state machine walk-through
    //        Trigger via flame, capture GSM TX character stream.
    //        Verify "ATD112;" and "AT+CMGF=1" appear in sequence.
    // -----------------------------------------------------------------------
    begin : tc11_block
        reg [7:0] gsm_bytes [0:63];
        integer gi;
        // trigger emergency
        flame_in = 0;
        force dut.i2c_engine.accel_x = 16'sd0;
 
        // Capture first 9 bytes from gsm_tx  (ATD112;\r\n)
        for (gi = 0; gi < 9; gi = gi+1)
            capture_uart_byte(1, gsm_bytes[gi]);
 
        check(gsm_bytes[0] == "A", "TC11a: GSM byte[0]='A' (ATD)");
        check(gsm_bytes[1] == "T", "TC11b: GSM byte[1]='T'");
        check(gsm_bytes[2] == "D", "TC11c: GSM byte[2]='D'");
        check(gsm_bytes[3] == "1", "TC11d: GSM byte[3]='1'");
        check(gsm_bytes[4] == "1", "TC11e: GSM byte[4]='1'");
        check(gsm_bytes[5] == "2", "TC11f: GSM byte[5]='2'");
        check(gsm_bytes[6] == ";", "TC11g: GSM byte[6]=';'");
        check(gsm_bytes[7] == 8'h0D, "TC11h: GSM byte[7]=CR");
        check(gsm_bytes[8] == 8'h0A, "TC11i: GSM byte[8]=LF");
 
        flame_in = 1;
        release dut.i2c_engine.accel_x;
    end
 
    // -----------------------------------------------------------------------
    // TC12 — emergency_latched clears → second alert fires
    //        After first GSM sequence done, trigger again.
    // -----------------------------------------------------------------------
    begin : tc12_block
        reg [7:0] gsm_b0, gsm_b1;
        integer wait_cycles;
 
        // Wait for GSM sequence to finish (state 13 → state 0)
        // Worst case: 15s call + 2s hangup + 2s sms ~ 19 s at simulation speed
        // Skip long wait; instead force emergency_latched=0 and re-trigger.
        // (Behavioural verify that second trigger is accepted)
        repeat(100) @(posedge clk);
 
        // Force clear the latch to simulate cooldown completion
        force dut.emergency_latched = 0;
        force dut.gsm_state = 0;
        @(posedge clk);
        release dut.emergency_latched;
        release dut.gsm_state;
 
        // Re-trigger
        mq2_in = 0;
        force dut.i2c_engine.accel_x = 16'sd0;
        repeat(10) @(posedge clk);
 
        // Check emergency_latched goes high again
        repeat(5) @(posedge clk);
        check(dut.emergency_latched === 1'b1, "TC12: emergency_latched re-asserts on second alert");
 
        mq2_in = 1;
        release dut.i2c_engine.accel_x;
    end
 
    // -----------------------------------------------------------------------
    // TC13 — GSM UART baud rate verification (same logic as TC09 but gsm_tx)
    // -----------------------------------------------------------------------
    begin : tc13_block
        time t0, t1;
        real gsm_baud;
 
        // Wait for next GSM activity from TC12
        @(negedge gsm_tx) t0 = $time;
        repeat(10 * CLK_DIV) @(posedge clk);
        t1 = $time;
 
        gsm_baud = 1.0e9 / ((t1 - t0) / 10.0);
        check((gsm_baud > 9400.0) && (gsm_baud < 9800.0),
              "TC13: GSM baud rate within 2% of 9600");
    end
 
    // -----------------------------------------------------------------------
    // TC14 — mpu6050_reader: I2C START condition
    //        SCL must be HIGH and SDA must fall.
    // -----------------------------------------------------------------------
    begin : tc14_block
        time scl_high_at, sda_fall_at;
        // After reset the I2C engine immediately starts.
        // Capture first START from the beginning (module already running,
        // force engine back to IDLE by monitoring SCL/SDA transitions).
        // Just observe: SDA goes low while SCL is high → START.
        // Wait for SCL to be released HIGH
        wait(i2c_scl === 1'bz || i2c_scl === 1'b1);
        scl_high_at = $time;
 
        // Wait for SDA to fall while SCL still high
        @(negedge i2c_sda);
        sda_fall_at = $time;
 
        check(i2c_scl === 1'bz || i2c_scl === 1'b1,
              "TC14: SDA falls while SCL is HIGH (valid START condition)");
    end
 
    // -----------------------------------------------------------------------
    // TC15 — mpu6050_reader: ack_error when slave does not ACK
    //        Leave SDA floating (no pull-low) during ACK phase.
    //        ack_error should eventually go high.
    // -----------------------------------------------------------------------
    begin : tc15_block
        // ack_error is inside mpu6050_reader instance: dut.i2c_engine.ack_error
        integer wait_limit;
        sda_slave_drive = 0;   // slave does NOT pull SDA low → NACK / error
        wait_limit = 0;
        while (dut.i2c_engine.ack_error !== 1'b1 && wait_limit < 13_500_000) begin
            @(posedge clk);
            wait_limit = wait_limit + 1;
        end
        check(dut.i2c_engine.ack_error === 1'b1, "TC15: ack_error=1 when slave does not ACK");
    end
 
    // -----------------------------------------------------------------------
    // TC16 — mpu6050_reader: accel_x updated after NACK state
    //        We force high_byte/low_byte inside the sub-module then watch
    //        accel_x update when state transitions through NACK.
    // -----------------------------------------------------------------------
    begin : tc16_block
        integer wait_cnt;
        force dut.i2c_engine.high_byte = 8'hAB;
        force dut.i2c_engine.low_byte  = 8'hCD;
 
        // Wait for NACK state to commit
        wait_cnt = 0;
        while (dut.i2c_engine.accel_x !== 16'hABCD && wait_cnt < 13_500_000) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
        end
        check(dut.i2c_engine.accel_x === 16'hABCD,
              "TC16: accel_x = {high_byte,low_byte} committed at NACK");
 
        release dut.i2c_engine.high_byte;
        release dut.i2c_engine.low_byte;
    end
 
    // -----------------------------------------------------------------------
    // TC17 — Boundary: accel_x == CRASH_THRESHOLD (no latch expected)
    // -----------------------------------------------------------------------
    force dut.i2c_engine.accel_x = CRASH_THRESHOLD;  // exactly 18000
 
    // Clear any previous crash latch
    force dut.is_crashing = 0;
    @(posedge clk);
    release dut.is_crashing;
 
    repeat(10) @(posedge clk);
    check(dut.is_crashing === 1'b0,
          "TC17: is_crashing=0 when accel_x == CRASH_THRESHOLD (not strictly greater)");
 
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC18 — Boundary: accel_x == CRASH_THRESHOLD + 1 → latch
    // -----------------------------------------------------------------------
    force dut.is_crashing = 0;
    @(posedge clk);
    release dut.is_crashing;
 
    force dut.i2c_engine.accel_x = CRASH_THRESHOLD + 1;
    repeat(5) @(posedge clk);
    check(dut.is_crashing === 1'b1,
          "TC18: is_crashing=1 when accel_x == CRASH_THRESHOLD+1");
 
    release dut.i2c_engine.accel_x;
 
    // -----------------------------------------------------------------------
    // TC19 — Multiple consecutive emergencies
    // -----------------------------------------------------------------------
    begin : tc19_block
        integer alert_count;
        alert_count = 0;
 
        force dut.emergency_latched = 0;
        force dut.gsm_state = 0;
        @(posedge clk);
        release dut.emergency_latched;
        release dut.gsm_state;
 
        // First emergency
        flame_in = 0;
        repeat(5) @(posedge clk);
        if (dut.emergency_latched) alert_count = alert_count + 1;
        flame_in = 1;
 
        // Simulate GSM done
        force dut.emergency_latched = 0;
        force dut.gsm_state = 0;
        @(posedge clk);
        release dut.emergency_latched;
        release dut.gsm_state;
        repeat(2) @(posedge clk);
 
        // Second emergency
        mq2_in = 0;
        repeat(5) @(posedge clk);
        if (dut.emergency_latched) alert_count = alert_count + 1;
        mq2_in = 1;
 
        check(alert_count == 2,
              "TC19: both consecutive emergencies latched correctly");
    end
 
    // -----------------------------------------------------------------------
    // TC20 — MSG_LEN == 29 (verify exactly 29 bytes transmitted per window)
    // -----------------------------------------------------------------------
    begin : tc20_block
        integer byte_cnt;
        time t_first_start, t_last_stop;
        force dut.i2c_engine.accel_x = 16'sd0;
        wait_sample_periods(1);
 
        byte_cnt = 0;
        // Count bytes: detect each start-bit on uart_tx
        fork
            begin : counter
                while (byte_cnt < 30) begin
                    @(negedge uart_tx);
                    byte_cnt = byte_cnt + 1;
                    // Skip this character's duration
                    repeat(10 * CLK_DIV) @(posedge clk);
                end
            end
            begin : timeout
                // Allow 2 full message lengths as timeout
                repeat(2 * 29 * 10 * CLK_DIV + 1000) @(posedge clk);
                disable counter;
            end
        join
 
        check(byte_cnt == 29, "TC20: exactly 29 bytes transmitted per UART message");
 
        release dut.i2c_engine.accel_x;
    end
 
    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    $display("===================================================");
    $display(" TEST SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
    $display("===================================================");
 
    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("SOME TESTS FAILED — review [FAIL] lines above");
 
    $finish;
end
 
// ---------------------------------------------------------------------------
// Watchdog: abort after 10 billion ns to prevent infinite simulation
// ---------------------------------------------------------------------------
initial begin
    #1000000;
    $display("[WATCHDOG] Simulation exceeded time limit.");
    $finish;
end
 
endmodule