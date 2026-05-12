module mpu6050_reader (
    input  wire clk,            // 27MHz system clock input
    output wire i2c_scl,        // I2C serial clock line
    inout  wire i2c_sda,        // I2C serial data line
    output reg signed [15:0] accel_x // 16-bit accelerometer X-axis output
);
 
// --- I2C Open-Drain Physical Layer ---
// scl_en=1 => SCL pulled LOW (open-drain active)
// scl_en=0 => SCL released HIGH (external pull-up takes over)
reg scl_en = 0;                // Controls SCL line driving
reg sda_en = 0;                // Controls SDA line driving

assign i2c_scl = scl_en ? 1'b0 : 1'bz; // Drive LOW or release line
assign i2c_sda = sda_en ? 1'b0 : 1'bz; // Drive LOW or release line
 
// --- ACK error flag ---
reg ack_error = 0;             // Set if slave does not acknowledge
 
// --- Clock Divider ---
// 27MHz / 135 = 200kHz tick
// With 4 phases per bit => 50kHz I2C (Standard Mode)
// 8-bit register (max 255) is sufficient for this divider value.
reg [7:0] clk_div = 0;         // Clock divider counter
reg i2c_tick = 0;              // Generates slower I2C timing pulse

always @(posedge clk) begin
    if (clk_div == 8'd134) begin
        clk_div  <= 0;         // Reset divider counter
        i2c_tick <= 1;         // Generate single tick pulse
    end else begin
        clk_div  <= clk_div + 1'b1; // Increment divider
        i2c_tick <= 0;         // No tick yet
    end
end
 
// --- Phase Generator (4 Phases per I2C bit: 0,1,2,3) ---
reg [1:0] phase = 0;           // Tracks I2C timing phases

always @(posedge clk) begin
    if (i2c_tick)
        phase <= phase + 1'b1; // Advance to next phase
end
 
// =========================================================
// CONTROL PATH
// =========================================================
 
localparam IDLE     = 5'd0,    // Idle state
           START_1  = 5'd1,    // Start condition for initialization
           ADDR_W   = 5'd2,    // Send MPU write address
           ACK_1    = 5'd3,    // Wait for ACK
           REG_PWR  = 5'd4,    // Send power register address
           ACK_2    = 5'd5,    // Wait for ACK
           DATA_PWR = 5'd6,    // Send wake-up data
           ACK_3    = 5'd7,    // Wait for ACK
           STOP_1   = 5'd8,    // Stop condition
           START_2  = 5'd9,    // Start for register selection
           ADDR_W2  = 5'd10,   // Send write address again
           ACK_4    = 5'd11,   // Wait for ACK
           REG_X    = 5'd12,   // Send accelerometer X register address
           ACK_5    = 5'd13,   // Wait for ACK
           START_3  = 5'd14,   // Repeated START
           ADDR_R   = 5'd15,   // Send MPU read address
           ACK_6    = 5'd16,   // Wait for ACK
           READ_H   = 5'd17,   // Read high byte
           ACK_7    = 5'd18,   // Master ACK
           READ_L   = 5'd19,   // Read low byte
           NACK     = 5'd20,   // Master NACK
           STOP_2   = 5'd21;   // Final STOP
 
reg [4:0] state      = IDLE;   // Current FSM state
reg [4:0] next_state;          // Next FSM state
reg [7:0] bit_cnt    = 0;      // Bit counter for byte transfers
 
// BLOCK 1: State Register Update (Sequential)
always @(posedge clk) begin
    if (i2c_tick && phase == 3) begin // Update only at phase 3
        state <= next_state;          // Move to next state
 
        // Handle bit counter
        if (state == ADDR_W  || state == REG_PWR  || state == DATA_PWR ||
            state == ADDR_W2 || state == REG_X    || state == ADDR_R   ||
            state == READ_H  || state == READ_L) begin

            if (bit_cnt == 7)
                bit_cnt <= 0;         // Reset after 8 bits
            else
                bit_cnt <= bit_cnt + 1'b1; // Next bit
        end else begin
            bit_cnt <= 0;             // Reset in non-transfer states
        end
 
        // FIX 3: Commit accel_x safely after NACK completes —
        // all 16 bits of high_byte/low_byte are fully captured before this point.
        if (state == NACK) begin
            accel_x <= {high_byte, low_byte}; // Combine bytes into final output
        end
    end
end
 
// BLOCK 2: Next State Logic (Combinational)
always @(*) begin
    next_state = state; // Default stay in same state

    case (state)

        IDLE:     next_state = START_1; // Begin initialization
        START_1:  next_state = ADDR_W;  // Send write address

        ADDR_W:
            if (bit_cnt == 7)
                next_state = ACK_1;     // After 8 bits wait for ACK

        ACK_1:    next_state = REG_PWR; // Send power register

        REG_PWR:
            if (bit_cnt == 7)
                next_state = ACK_2;

        ACK_2:    next_state = DATA_PWR; // Send wake-up value

        DATA_PWR:
            if (bit_cnt == 7)
                next_state = ACK_3;

        ACK_3:    next_state = STOP_1; // Finish initialization
        STOP_1:   next_state = START_2;

        START_2:  next_state = ADDR_W2;

        ADDR_W2:
            if (bit_cnt == 7)
                next_state = ACK_4;

        ACK_4:    next_state = REG_X; // Send X-axis register address

        REG_X:
            if (bit_cnt == 7)
                next_state = ACK_5;

        ACK_5:    next_state = START_3; // Repeated START
        START_3:  next_state = ADDR_R;  // Send read address

        ADDR_R:
            if (bit_cnt == 7)
                next_state = ACK_6;

        ACK_6:    next_state = READ_H; // Read high byte

        READ_H:
            if (bit_cnt == 7)
                next_state = ACK_7;

        ACK_7:    next_state = READ_L; // Read low byte

        READ_L:
            if (bit_cnt == 7)
                next_state = NACK;

        NACK:     next_state = STOP_2; // End read operation

        STOP_2:   next_state = START_2; // Continuous read loop

        default:  next_state = IDLE;
    endcase
end
 
// =========================================================
// DATAPATH
// =========================================================
 
localparam MPU_ADDR_W = 8'hD0; // MPU6050 write address
localparam MPU_ADDR_R = 8'hD1; // MPU6050 read address
 
reg [7:0] data_to_send = 0;    // Current byte to transmit
reg [7:0] high_byte    = 0;    // Stores high byte from MPU
reg [7:0] low_byte     = 0;    // Stores low byte from MPU
 
// BLOCK 3: Pin Driving and Data Shifting (Sequential)
always @(posedge clk) begin
    if (i2c_tick) begin
 
        // -------------------------------------------------------
        // 1. Data Capture (sample SDA at phase 2, while SCL HIGH)
        // -------------------------------------------------------
        if (phase == 2) begin

            if (state == READ_H)
                high_byte[7 - bit_cnt] <= i2c_sda; // Capture high byte bits

            if (state == READ_L)
                low_byte [7 - bit_cnt] <= i2c_sda; // Capture low byte bits
        end
 
        // -------------------------------------------------------
        // 2. Data Multiplexer
        // -------------------------------------------------------
        case (state)

            ADDR_W,
            ADDR_W2:
                data_to_send <= MPU_ADDR_W; // Send write address

            REG_PWR:
                data_to_send <= 8'h6B; // Power management register

            DATA_PWR:
                data_to_send <= 8'h00; // Wake MPU6050 from sleep

            REG_X:
                data_to_send <= 8'h3B; // ACCEL_XOUT_H register

            ADDR_R:
                data_to_send <= MPU_ADDR_R; // Send read address

            default:
                data_to_send <= 8'h00;
        endcase
 
        // -------------------------------------------------------
        // 3. I2C Pin State Machine
        // -------------------------------------------------------
        case (state)
 
            IDLE: begin
                sda_en <= 0;   // Release SDA HIGH
                scl_en <= 0;   // Release SCL HIGH
            end
 
            // START condition generation
            START_1, START_2, START_3: begin

                if (phase == 0) begin
                    scl_en <= 0; // Keep SCL HIGH
                    sda_en <= 0; // Keep SDA HIGH
                end

                if (phase == 1)
                    sda_en <= 1; // SDA falls LOW while SCL HIGH

                if (phase == 2)
                    scl_en <= 1; // Pull SCL LOW
            end
 
            // Data transmit states
            ADDR_W, REG_PWR, DATA_PWR, ADDR_W2, REG_X, ADDR_R: begin

                if (phase == 0)
                    sda_en <= ~data_to_send[7 - bit_cnt]; // Output current bit

                if (phase == 1)
                    scl_en <= 0; // Raise SCL HIGH

                if (phase == 3)
                    scl_en <= 1; // Pull SCL LOW
            end
 
            // ACK receive states
            ACK_1, ACK_2, ACK_3, ACK_4, ACK_5, ACK_6: begin

                if (phase == 0)
                    sda_en <= 0; // Release SDA for slave ACK

                if (phase == 1)
                    scl_en <= 0; // Raise SCL HIGH

                if (phase == 2) begin

                    if (i2c_sda !== 1'b0)
                        ack_error <= 1; // No ACK received
                end

                if (phase == 3)
                    scl_en <= 1; // Pull SCL LOW
            end
 
            // Data read states
            READ_H, READ_L: begin

                if (phase == 0)
                    sda_en <= 0; // Release SDA so slave can drive

                if (phase == 1)
                    scl_en <= 0; // Raise SCL HIGH

                if (phase == 3)
                    scl_en <= 1; // Pull SCL LOW
            end
 
            // Master ACK after high byte
            ACK_7: begin

                if (phase == 0)
                    sda_en <= 1; // Drive ACK LOW

                if (phase == 1)
                    scl_en <= 0; // Raise SCL HIGH

                if (phase == 3)
                    scl_en <= 1; // Pull SCL LOW
            end
 
            // Master NACK after low byte
            NACK: begin

                if (phase == 0)
                    sda_en <= 0; // Release SDA HIGH for NACK

                if (phase == 1)
                    scl_en <= 0; // Raise SCL HIGH

                if (phase == 3)
                    scl_en <= 1; // Pull SCL LOW
            end
 
            // STOP condition generation
            STOP_1, STOP_2: begin

                if (phase == 0) begin
                    scl_en <= 1; // SCL LOW
                    sda_en <= 1; // SDA LOW
                end

                if (phase == 1)
                    scl_en <= 0; // Release SCL HIGH

                if (phase == 2)
                    sda_en <= 0; // SDA rises HIGH while SCL HIGH
            end
 
        endcase
    end
end
 
endmodule