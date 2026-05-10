module mpu6050_reader (
    input  wire clk,            // 27MHz
    output wire i2c_scl,        // Pin 26
    inout  wire i2c_sda,        // Pin 25
    output reg signed [15:0] accel_x
);

// --- I2C Open-Drain Physical Layer ---
reg scl_en = 0;
reg sda_en = 0;
assign i2c_scl = scl_en ? 1'b0 : 1'bz;
assign i2c_sda = sda_en ? 1'b0 : 1'bz;

// --- Clock Divider (27MHz to ~50kHz I2C Phases) ---
reg [7:0] clk_div = 0;
reg i2c_tick = 0;
always @(posedge clk) begin
    if (clk_div == 8'd134) begin
        clk_div <= 0;
        i2c_tick <= 1; 
    end else begin
        clk_div <= clk_div + 1'b1;
        i2c_tick <= 0;
    end
end

// --- Phase Generator (4 Phases per I2C bit) ---
reg [1:0] phase = 0;
always @(posedge clk) begin
    if (i2c_tick) phase <= phase + 1'b1;
end

// =========================================================
// CONTROL PATH (The Brain)
// =========================================================

// State Encodings
localparam IDLE     = 5'd0,  START_1  = 5'd1,  ADDR_W   = 5'd2,  ACK_1    = 5'd3,
           REG_PWR  = 5'd4,  ACK_2    = 5'd5,  DATA_PWR = 5'd6,  ACK_3    = 5'd7,
           STOP_1   = 5'd8,  START_2  = 5'd9,  ADDR_W2  = 5'd10, ACK_4    = 5'd11,
           REG_X    = 5'd12, ACK_5    = 5'd13, START_3  = 5'd14, ADDR_R   = 5'd15,
           ACK_6    = 5'd16, READ_H   = 5'd17, ACK_7    = 5'd18, READ_L   = 5'd19,
           NACK     = 5'd20, STOP_2   = 5'd21;

reg [4:0] state = IDLE;
reg [4:0] next_state;
reg [7:0] bit_cnt = 0;

// BLOCK 1: State Register Update (Sequential)
always @(posedge clk) begin
    if (i2c_tick && phase == 3) begin
        state <= next_state;
        
        // Handle bit counter sequentially
        if (state == ADDR_W || state == REG_PWR || state == DATA_PWR || 
            state == ADDR_W2 || state == REG_X || state == ADDR_R || 
            state == READ_H || state == READ_L) begin
            if (bit_cnt == 7) bit_cnt <= 0;
            else bit_cnt <= bit_cnt + 1'b1;
        end else begin
            bit_cnt <= 0;
        end
    end
end

// BLOCK 2: Next State Logic (Combinational)
always @(*) begin
    next_state = state; // Default hold
    case (state)
        IDLE:     next_state = START_1;
        START_1:  next_state = ADDR_W;
        ADDR_W:   if (bit_cnt == 7) next_state = ACK_1;
        ACK_1:    next_state = REG_PWR;
        REG_PWR:  if (bit_cnt == 7) next_state = ACK_2;
        ACK_2:    next_state = DATA_PWR;
        DATA_PWR: if (bit_cnt == 7) next_state = ACK_3;
        ACK_3:    next_state = STOP_1;
        STOP_1:   next_state = START_2;
        
        START_2:  next_state = ADDR_W2;
        ADDR_W2:  if (bit_cnt == 7) next_state = ACK_4;
        ACK_4:    next_state = REG_X;
        REG_X:    if (bit_cnt == 7) next_state = ACK_5;
        ACK_5:    next_state = START_3;
        START_3:  next_state = ADDR_R;
        ADDR_R:   if (bit_cnt == 7) next_state = ACK_6;
        ACK_6:    next_state = READ_H;
        READ_H:   if (bit_cnt == 7) next_state = ACK_7;
        ACK_7:    next_state = READ_L;
        READ_L:   if (bit_cnt == 7) next_state = NACK;
        NACK:     next_state = STOP_2;
        STOP_2:   next_state = START_2; // Loop continuous read
        default:  next_state = IDLE;
    endcase
end

// =========================================================
// DATAPATH (The Muscle)
// =========================================================

localparam MPU_ADDR_W = 8'hD0;
localparam MPU_ADDR_R = 8'hD1;

reg [7:0] data_to_send = 0;
reg [7:0] high_byte = 0;
reg [7:0] low_byte = 0;

// BLOCK 3: Pin Driving and Data Shifting (Sequential)
always @(posedge clk) begin
    if (i2c_tick) begin
        
        // 1. Data Shifting & Capture
        if (phase == 2) begin
            if (state == READ_H) high_byte[7 - bit_cnt] <= i2c_sda;
            if (state == READ_L) low_byte[7 - bit_cnt] <= i2c_sda;
        end
        if (phase == 3 && state == STOP_2) begin
            accel_x <= {high_byte, low_byte}; // Commit final data
        end

        // 2. Data Multiplexer
        case (state)
            ADDR_W, ADDR_W2: data_to_send <= MPU_ADDR_W;
            REG_PWR:         data_to_send <= 8'h6B;
            DATA_PWR:        data_to_send <= 8'h00;
            REG_X:           data_to_send <= 8'h3B;
            ADDR_R:          data_to_send <= MPU_ADDR_R;
            default:         data_to_send <= 8'h00;
        endcase

        // 3. I2C Pin State Machine
        case (state)
            IDLE: begin sda_en <= 0; scl_en <= 0; end
            
            START_1, START_2, START_3: begin
                if (phase == 0) sda_en <= 1; 
                if (phase == 1) scl_en <= 1;
            end
            
            ADDR_W, REG_PWR, DATA_PWR, ADDR_W2, REG_X, ADDR_R: begin
                if (phase == 0) sda_en <= ~data_to_send[7 - bit_cnt];
                if (phase == 1) scl_en <= 0;
                if (phase == 3) scl_en <= 1;
            end
            
            ACK_1, ACK_2, ACK_3, ACK_4, ACK_5, ACK_6: begin
                if (phase == 0) sda_en <= 0; // Release SDA to read Slave ACK
                if (phase == 1) scl_en <= 0;
                if (phase == 3) scl_en <= 1;
            end
            
            READ_H, READ_L: begin
                if (phase == 0) sda_en <= 0; // Release SDA to read Data
                if (phase == 1) scl_en <= 0;
                if (phase == 3) scl_en <= 1;
            end
            
            ACK_7: begin // Master sends ACK
                if (phase == 0) sda_en <= 1; 
                if (phase == 1) scl_en <= 0;
                if (phase == 3) scl_en <= 1;
            end
            
            NACK: begin // Master sends NACK
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0;
                if (phase == 3) scl_en <= 1;
            end
            
            STOP_1, STOP_2: begin
                if (phase == 0) sda_en <= 1; 
                if (phase == 1) scl_en <= 0;
                if (phase == 2) sda_en <= 0; 
            end
        endcase
    end
end

endmodule