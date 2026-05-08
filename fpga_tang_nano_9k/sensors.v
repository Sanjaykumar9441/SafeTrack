module top_safety_system (
    input  wire clk,         // Pin 52 (27MHz System Clock)
    
    // Safety Sensors
    input  wire flame_in,    // Pin 27 (Active Low = Fire)
    input  wire mq2_in,      // Pin 28 (Active Low = Smoke)
    input  wire seat_in,     // Pin 29 (Active Low/GND = Occupied)
    
    // I2C for MPU6050
    output wire i2c_scl,     // Pin 26
    inout  wire i2c_sda,     // Pin 25
    
    // GPS & GSM Modules
    input  wire gps_rx,      // Pin 31 (From GPS TX)
    output wire gsm_tx,      // Pin 32 (To GSM RX)
    input  wire gsm_rx       // Pin 33 (From GSM TX - unused but mapped)
);

parameter signed CRASH_THRESHOLD = 16'sd18000; 

// --- 1. SENSOR SYNCHRONIZATION ---
// Prevents metastability from external wires
reg flame_sync = 0;
reg mq2_sync   = 1;
reg seat_sync  = 1;

always @(posedge clk) begin
    flame_sync <= flame_in;
    mq2_sync   <= mq2_in;
    seat_sync  <= seat_in;
end

// --- 2. MPU6050 ACCELEROMETER ---
wire signed [15:0] real_accel_x;
mpu6050_reader accel_inst (
    .clk(clk),
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda),
    .accel_x(real_accel_x)
);

// --- 3. CORE LOGIC & TRIGGERS ---
// Detect Crash
wire is_crashing = (real_accel_x > CRASH_THRESHOLD || real_accel_x < -CRASH_THRESHOLD) ? 1'b1 : 1'b0;

// Detect Seat Occupancy (Assume Low = Occupied based on your limit switch)
wire seat_occupied = !seat_sync;

// THE MASTER TRIGGER: Crash OR Flame OR Smoke
wire trigger_emergency = (is_crashing || !flame_sync || !mq2_sync); 

// --- 4. GSM/GPS EMERGENCY CONTROLLER ---
gsm_gps_hardware_hack emergency_inst (
    .clk(clk),
    .trigger(trigger_emergency),
    .seat_occupied(seat_occupied),
    .gps_rx_pin(gps_rx),
    .gsm_tx_pin(gsm_tx)
);

endmodule