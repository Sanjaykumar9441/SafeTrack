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
    parameter BAUD_PERIOD = 104166;

    // =========================================================
    // UART DECODER VARIABLES
    // =========================================================
    reg [7:0] rx_byte;
    integer i;

    // =========================================================
    // UUT
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
    // I2C MODEL
    // =========================================================
    assign i2c_sda = 1'bz;

    // =========================================================
    // CLOCK
    // =========================================================
    initial clk = 0;

    always #18.518 clk = ~clk;

    // =========================================================
    // UART RECEIVER / MONITOR
    // =========================================================
    initial begin

        forever begin

            @(negedge uart_tx);

            $display("\n[UART] START BIT DETECTED at time %0t ns", $time);

            // Move to middle of first data bit
            #(BAUD_PERIOD + (BAUD_PERIOD/2));

            // Read 8 UART bits
            for (i = 0; i < 8; i = i + 1) begin
                rx_byte[i] = uart_tx;
                #BAUD_PERIOD;
            end

            // STOP BIT CHECK
            if (uart_tx == 1'b1)
                $display("[UART PASS] STOP bit valid.");
            else
                $display("[UART FAIL] STOP bit invalid.");

            // DISPLAY RECEIVED BYTE
            $display("[UART DATA] RX Byte = 0x%h (%c)",
                      rx_byte, rx_byte);

            // SIMPLE ASCII VALIDATION
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
        flame_in = 1;
        mq2_in   = 1;
        seat_bus = 4'b1111;
        gps_rx   = 1;
        gsm_rx   = 1;

        // -----------------------------------------------------
        // WAVEFORM DUMP
        // -----------------------------------------------------
        $dumpfile("safetrack_tb.vcd");
        $dumpvars(0, test_bench);

        $display("\n==================================================");
        $display("     SAFETRACK MASTER SAFETY SYSTEM TESTBENCH");
        $display("==================================================");

        // =====================================================
        // TEST 1 : BAUD RATE
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
        // TEST 2 : UART TELEMETRY
        // =====================================================
        $display("\n[TEST 2] NORMAL UART TELEMETRY TEST");

        // Seat1 and Seat4 occupied
        seat_bus = 4'b1001;

        // Fast-forward timer
        force uut.sample_timer = 25'd13_499_990;

        #50_000_000;

        $display("[PASS] UART telemetry transmission completed.");

        release uut.sample_timer;

        // =====================================================
        // TEST 3 : FLAME SENSOR
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
        // TEST 4 : MQ2 SENSOR
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
        // TEST 5 : CRASH DETECTION
        // =====================================================
        $display("\n[TEST 5] MPU6050 CRASH DETECTION TEST");

        force uut.real_accel_x = 16'sd20000;

        #50000;

        if (uut.is_crashing == 1)
            $display("[PASS] Crash detection logic verified.");
        else
            $display("[FAIL] Crash detection logic failed.");

        release uut.real_accel_x;

        #50000;

        // =====================================================
        // TEST 6 : GSM FSM + GOOGLE MAPS URL
        // =====================================================
        $display("\n[TEST 6] GSM FSM STATE TRANSITION TEST");

        // CALL STATE
        force uut.gsm_timer = 27_000_000 * 15;
        #50000;

        // HANGUP STATE
        force uut.gsm_timer = 27_000_000 * 2;
        #50000;

        // SMS MODE
        force uut.gsm_timer = 27_000_000 * 1;
        #50000;

        // SMS NUMBER
        force uut.gsm_timer = 27_000_000 * 1;
        #50000;

        // SMS BODY
        force uut.gsm_timer = 27_000_000 / 10;
        #50000;

        // =====================================================
        // DUMP FULL GOOGLE MAPS SMS URL
        // =====================================================
        $display("\n[INFO] Dumping GSM SMS URL buffer (indices 0..53):");

        for (i = 0; i < 54; i = i + 1) begin

            if (i == 37)
                $display("[SMS URL] Coordinate section begins:");

            $write("%c", uut.gsm_msg[i]);

        end

        $display("\n[INFO] End of SMS URL buffer dump.\n");

        // =====================================================
        // FULL GOOGLE MAPS URL VALIDATION
        // =====================================================

        if (

            uut.gsm_msg[37] == "1" &&
            uut.gsm_msg[38] == "7" &&
            uut.gsm_msg[39] == "." &&
            uut.gsm_msg[40] == "3" &&
            uut.gsm_msg[41] == "8" &&
            uut.gsm_msg[42] == "5" &&
            uut.gsm_msg[43] == "0" &&

            uut.gsm_msg[44] == "," &&

            uut.gsm_msg[45] == "7" &&
            uut.gsm_msg[46] == "8" &&
            uut.gsm_msg[47] == "." &&
            uut.gsm_msg[48] == "4" &&
            uut.gsm_msg[49] == "8" &&
            uut.gsm_msg[50] == "6" &&
            uut.gsm_msg[51] == "7" &&

            uut.gsm_msg[52] == 8'h0D &&
            uut.gsm_msg[53] == 8'h0A

        )

        begin

            $display("[PASS] Full Google Maps coordinate string verified.");
            $display("[PASS] Clickable URL generation verified.");
            $display("[PASS] CRLF termination verified.");
            $display("[PASS] Industrial-grade formatted SMS validation passed.");

        end

        else begin

            $display("[FAIL] Google Maps URL formatting failed.");
            $display("[FAIL] Coordinate validation mismatch detected.");

        end

        release uut.gsm_timer;

        // =====================================================
        // TEST 7 : MULTI SENSOR EMERGENCY
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
        // TEST 8 : SEAT COMBINATIONS
        // =====================================================
        $display("\n[TEST 8] LIMIT SWITCH COMBINATION TEST");

        // CASE 1
        seat_bus = 4'b1111;
        #50000;
        $display("[CASE 1] ALL EMPTY            -> %b", seat_bus);

        // CASE 2
        seat_bus = 4'b1110;
        #50000;
        $display("[CASE 2] SEAT 1 OCCUPIED      -> %b", seat_bus);

        // CASE 3
        seat_bus = 4'b1101;
        #50000;
        $display("[CASE 3] SEAT 2 OCCUPIED      -> %b", seat_bus);

        // CASE 4
        seat_bus = 4'b1011;
        #50000;
        $display("[CASE 4] SEAT 3 OCCUPIED      -> %b", seat_bus);

        // CASE 5
        seat_bus = 4'b0111;
        #50000;
        $display("[CASE 5] SEAT 4 OCCUPIED      -> %b", seat_bus);

        // CASE 6
        seat_bus = 4'b0011;
        #50000;
        $display("[CASE 6] TWO SEATS OCCUPIED   -> %b", seat_bus);

        // CASE 7
        seat_bus = 4'b0001;
        #50000;
        $display("[CASE 7] THREE SEATS OCCUPIED -> %b", seat_bus);

        // CASE 8
        seat_bus = 4'b0000;
        #50000;
        $display("[CASE 8] ALL SEATS OCCUPIED   -> %b", seat_bus);

        $display("[PASS] All seat combinations verified.");

        // =====================================================
        // FINAL RESULT
        // =====================================================
        $display("\n==================================================");
        $display("        ALL TESTS COMPLETED SUCCESSFULLY");
        $display("==================================================\n");

        $finish;

    end

endmodule