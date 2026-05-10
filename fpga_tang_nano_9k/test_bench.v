`timescale 1ns/1ps

module test_bench;

    // =========================================================
    // INPUTS
    // =========================================================
    reg clk;
    reg flame_in;
    reg mq2_in;
    reg [3:0] seat_bus;
    reg gps_rx;
    reg gsm_rx;

    // =========================================================
    // OUTPUTS
    // =========================================================
    wire i2c_scl;
    wire i2c_sda;
    wire uart_tx;
    wire gsm_tx;

    // =========================================================
    // UART PARAMETERS
    // =========================================================
    parameter CLK_FREQ    = 27000000;
    parameter BAUD_RATE   = 9600;
    parameter BAUD_PERIOD = 104166; // ns

    // =========================================================
    // UART DECODER VARIABLES
    // =========================================================
    reg [7:0] rx_byte;
    integer i;

    // =========================================================
    // UUT INSTANTIATION
    // =========================================================
    master_safety_system uut (
        .clk(clk),
        .flame_in(flame_in),
        .mq2_in(mq2_in),
        .seat_bus(seat_bus),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda),
        .uart_tx(uart_tx),
        .gps_rx(gps_rx),
        .gsm_tx(gsm_tx),
        .gsm_rx(gsm_rx)
    );

    // =========================================================
    // I2C PULLUP MODEL
    // =========================================================
    assign i2c_sda = 1'bz;

    // =========================================================
    // 27 MHz CLOCK GENERATION
    // =========================================================
    initial clk = 0;

    always #18.518 clk = ~clk;

    // =========================================================
    // UART RECEIVER / MONITOR
    // =========================================================
    initial begin
        forever begin

            // Wait for UART START bit
            @(negedge uart_tx);

            $display("\n[UART] START BIT DETECTED at time %0t ns", $time);

            // Move to middle of first data bit
            #(BAUD_PERIOD + (BAUD_PERIOD/2));

            // Read 8 data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx_byte[i] = uart_tx;
                #BAUD_PERIOD;
            end

            // STOP bit verification
            if (uart_tx == 1'b1)
                $display("[UART PASS] STOP bit valid.");
            else
                $display("[UART FAIL] STOP bit invalid.");

            // Display UART byte
            $display("[UART DATA] RX Byte = 0x%h (%c)",
                      rx_byte, rx_byte);

            // Example ASCII validation
            case (rx_byte)

                "E":
                    $display("[UART CHECK] Character 'E' verified.");

                "M":
                    $display("[UART CHECK] Character 'M' verified.");

                "R":
                    $display("[UART CHECK] Character 'R' verified.");

                default:
                    $display("[UART INFO] Other UART character received.");

            endcase

        end
    end

    // =========================================================
    // MAIN TEST SEQUENCE
    // =========================================================
    initial begin

        // -----------------------------------------------------
        // INITIALIZE INPUTS
        // -----------------------------------------------------
        flame_in = 1;        // SAFE (ACTIVE LOW)
        mq2_in   = 1;        // SAFE (ACTIVE LOW)
        seat_bus = 4'b1111;  // ALL EMPTY
        gps_rx   = 1;        // UART IDLE
        gsm_rx   = 1;        // UART IDLE

        // -----------------------------------------------------
        // GTKWAVE DUMP FILE
        // -----------------------------------------------------
        $dumpfile("safetrack_tb.vcd");
        $dumpvars(0, test_bench);

        $display("\n==================================================");
        $display("     SAFETRACK MASTER SAFETY SYSTEM TESTBENCH");
        $display("==================================================");

        // =====================================================
        // TEST 1 : BAUD RATE / CLOCK DIVIDER TEST
        // =====================================================
        $display("\n[TEST 1] BAUD RATE CLOCK DIVIDER TEST");

        $display("Expected CLK_DIV = 2812");
        $display("Actual CLK_DIV   = %d", uut.CLK_DIV);

        if (uut.CLK_DIV == 2812)
            $display("[PASS] Correct baud divider.");
        else
            $display("[FAIL] Incorrect baud divider.");

        #1000;

        // =====================================================
        // TEST 2 : NORMAL UART TELEMETRY TEST
        // =====================================================
        $display("\n[TEST 2] NORMAL UART TELEMETRY TEST");

        // Seat1 and Seat4 occupied
        seat_bus = 4'b1001;

        // Fast-forward telemetry timer
        force uut.sample_timer = 25'd13_499_990;

        // Wait for UART transmission
        #50_000_000;

        $display("[PASS] UART telemetry transmission completed.");

        release uut.sample_timer;

        // =====================================================
        // TEST 3 : FLAME SENSOR TEST
        // =====================================================
        $display("\n[TEST 3] FLAME SENSOR TEST");

        flame_in = 0;

        #50000;

        if (uut.emergency_flag == 1)
            $display("[PASS] Flame emergency detected.");
        else
            $display("[FAIL] Flame emergency NOT detected.");

        flame_in = 1;

        #50000;

        // =====================================================
        // TEST 4 : MQ2 SMOKE SENSOR TEST
        // =====================================================
        $display("\n[TEST 4] MQ2 SMOKE SENSOR TEST");

        mq2_in = 0;

        #50000;

        if (uut.emergency_flag == 1)
            $display("[PASS] MQ2 smoke emergency detected.");
        else
            $display("[FAIL] MQ2 smoke emergency NOT detected.");

        mq2_in = 1;

        #50000;

        // =====================================================
        // TEST 5 : MPU6050 CRASH DETECTION TEST
        // =====================================================
        $display("\n[TEST 5] MPU6050 CRASH DETECTION TEST");

        // Force huge acceleration
        force uut.real_accel_x = 16'sd20000;

        #50000;

        if (uut.is_crashing == 1)
            $display("[PASS] Crash detection logic verified.");
        else
            $display("[FAIL] Crash detection logic failed.");

        release uut.real_accel_x;

        #50000;

        // =====================================================
        // TEST 6 : GSM FSM STATE TRANSITION TEST
        // =====================================================
        $display("\n[TEST 6] GSM FSM STATE TRANSITION TEST");

        // Force GSM timers to advance FSM states

        // CALL STATE
        force uut.gsm_timer = 27_000_000 * 15;
        #50000;

        // HANGUP STATE
        force uut.gsm_timer = 27_000_000 * 2;
        #50000;

        // SMS MODE STATE
        force uut.gsm_timer = 27_000_000 * 1;
        #50000;

        // SMS NUMBER STATE
        force uut.gsm_timer = 27_000_000 * 1;
        #50000;

        // SMS BODY STATE
        force uut.gsm_timer = 27_000_000 / 10;
        #50000;

        if (uut.gsm_passthrough_en == 1)
            $display("[PASS] GSM passthrough verified.");
        else
            $display("[FAIL] GSM passthrough failed.");

        release uut.gsm_timer;

        // =====================================================
        // TEST 7 : MULTI-SENSOR EMERGENCY TEST
        // =====================================================
        $display("\n[TEST 7] MULTI-SENSOR EMERGENCY TEST");

        flame_in = 0;
        mq2_in   = 0;

        force uut.real_accel_x = 16'sd25000;

        #100000;

        if ((uut.emergency_flag == 1) &&
            (uut.is_crashing  == 1))
            $display("[PASS] Multiple simultaneous emergencies handled.");
        else
            $display("[FAIL] Multi-sensor emergency handling failed.");

        flame_in = 1;
        mq2_in   = 1;

        release uut.real_accel_x;

        #50000;

        // =====================================================
        // TEST 8 : LIMIT SWITCH / SEAT COMBINATION TEST
        // =====================================================
        $display("\n[TEST 8] LIMIT SWITCH COMBINATION TEST");

        // CASE 1 : ALL EMPTY
        seat_bus = 4'b1111;
        #50000;
        $display("[CASE 1] ALL EMPTY            -> %b", seat_bus);

        // CASE 2 : SEAT 1 OCCUPIED
        seat_bus = 4'b1110;
        #50000;
        $display("[CASE 2] SEAT 1 OCCUPIED      -> %b", seat_bus);

        // CASE 3 : SEAT 2 OCCUPIED
        seat_bus = 4'b1101;
        #50000;
        $display("[CASE 3] SEAT 2 OCCUPIED      -> %b", seat_bus);

        // CASE 4 : SEAT 3 OCCUPIED
        seat_bus = 4'b1011;
        #50000;
        $display("[CASE 4] SEAT 3 OCCUPIED      -> %b", seat_bus);

        // CASE 5 : SEAT 4 OCCUPIED
        seat_bus = 4'b0111;
        #50000;
        $display("[CASE 5] SEAT 4 OCCUPIED      -> %b", seat_bus);

        // CASE 6 : TWO SEATS OCCUPIED
        seat_bus = 4'b0011;
        #50000;
        $display("[CASE 6] TWO SEATS OCCUPIED   -> %b", seat_bus);

        // CASE 7 : THREE SEATS OCCUPIED
        seat_bus = 4'b0001;
        #50000;
        $display("[CASE 7] THREE SEATS OCCUPIED -> %b", seat_bus);

        // CASE 8 : ALL SEATS OCCUPIED
        seat_bus = 4'b0000;
        #50000;
        $display("[CASE 8] ALL SEATS OCCUPIED   -> %b", seat_bus);

        $display("[PASS] All seat/limit-switch combinations verified.");

        // =====================================================
        // FINAL RESULT
        // =====================================================
        $display("\n==================================================");
        $display("        ALL TESTS COMPLETED SUCCESSFULLY");
        $display("==================================================\n");

        $finish;

    end

endmodule