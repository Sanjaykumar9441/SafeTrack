`timescale 1ns / 1ps

module tb_master_safety;

    // 1. Declare inputs as regs (we control these)
    reg clk;
    reg flame_in;
    reg mq2_in;
    reg seat_in;
    reg gps_rx;
    reg gsm_rx;

    // 2. Declare outputs as wires (we observe these)
    wire i2c_scl;
    wire i2c_sda;
    wire uart_tx;
    wire gsm_tx;

    // Simulate physical I2C pull-up resistors
    pullup(i2c_scl);
    pullup(i2c_sda);

    // 3. Instantiate your actual code
    master_safety_system uut (
        .clk(clk),
        .flame_in(flame_in),
        .mq2_in(mq2_in),
        .seat_in(seat_in),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda),
        .uart_tx(uart_tx),
        .gps_rx(gps_rx),
        .gsm_tx(gsm_tx),
        .gsm_rx(gsm_rx)
    );

    // 4. Generate the 27MHz System Clock
    // 1 second / 27,000,000 = 37.03ns per cycle. Toggle every 18.51ns.
    initial clk = 0;
    always #18.51 clk = ~clk;

    // Simulate dummy GPS NMEA data coming in (toggling the RX line)
    initial gps_rx = 1;
    always #52000 gps_rx = ~gps_rx; 

    // 5. The Simulation Sequence
    initial begin
        // Tell Icarus Verilog to create the waveform file for GTKWave
        $dumpfile("master_sim.vcd");
        $dumpvars(0, tb_master_safety);

        // -- STATE 1: NORMAL SAFE OPERATION --
        // (Remember your sensors are Active Low, so 1 means Safe)
        flame_in = 1; 
        mq2_in   = 1;
        seat_in  = 1;
        gsm_rx   = 1;

        // Wait a little bit for the normal UART telemetry to fire off
        #5_000_000;

        // -- STATE 2: EMERGENCY TRIGGERED --
        // Pull the flame sensor to 0V (Fire Detected!)
        flame_in = 0;

        // Wait long enough to watch the FPGA start sending the AT commands 
        // to the GSM module on the gsm_tx line
        #5_000_000; 

        // End the simulation
        $finish;
    end

endmodule