module mpu6050_reader (
    input  wire clk,            // 27MHz
    output wire i2c_scl,        // Pin 26
    inout  wire i2c_sda,        // Pin 25
    output reg signed [15:0] accel_x
);

reg scl_en = 0;
reg sda_en = 0;
assign i2c_scl = scl_en ? 1'b0 : 1'bz;
assign i2c_sda = sda_en ? 1'b0 : 1'bz;

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

reg [5:0] state = 0;
reg [7:0] bit_cnt = 0;
reg [7:0] data_to_send;
reg [7:0] high_byte, low_byte;
reg [1:0] phase = 0;

localparam MPU_ADDR_W = 8'hD0;
localparam MPU_ADDR_R = 8'hD1;

always @(posedge clk) begin
    if (i2c_tick) begin
        phase <= phase + 1'b1;
        
        case (state)
            0: if (phase == 0) state <= 1;

            1: begin
                if (phase == 0) sda_en <= 1; 
                if (phase == 1) scl_en <= 1;
                if (phase == 2) begin state <= 2; bit_cnt <= 0; data_to_send <= MPU_ADDR_W; end
            end
            2: begin
                if (phase == 0) sda_en <= ~data_to_send[7 - bit_cnt]; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin
                    if (bit_cnt == 7) state <= 3;
                    else bit_cnt <= bit_cnt + 1'b1;
                end
            end
            3: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin state <= 4; bit_cnt <= 0; data_to_send <= 8'h6B; end 
            end
            4: begin
                if (phase == 0) sda_en <= ~data_to_send[7 - bit_cnt];
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin
                    if (bit_cnt == 7) state <= 5;
                    else bit_cnt <= bit_cnt + 1'b1;
                end
            end
            5: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin state <= 6; bit_cnt <= 0; data_to_send <= 8'h00; end 
            end
            6: begin
                if (phase == 0) sda_en <= ~data_to_send[7 - bit_cnt];
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin
                    if (bit_cnt == 7) state <= 7;
                    else bit_cnt <= bit_cnt + 1'b1;
                end
            end
            7: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) state <= 8; 
            end
            8: begin
                if (phase == 0) sda_en <= 1; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 2) sda_en <= 0; 
                if (phase == 3) state <= 9;  
            end

            9: begin
                if (phase == 0) sda_en <= 1; 
                if (phase == 1) scl_en <= 1;
                if (phase == 2) begin state <= 10; bit_cnt <= 0; data_to_send <= MPU_ADDR_W; end
            end
            10: begin
                if (phase == 0) sda_en <= ~data_to_send[7 - bit_cnt];
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin
                    if (bit_cnt == 7) state <= 11;
                    else bit_cnt <= bit_cnt + 1'b1;
                end
            end
            11: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin state <= 12; bit_cnt <= 0; data_to_send <= 8'h3B; end 
            end
            12: begin
                if (phase == 0) sda_en <= ~data_to_send[7 - bit_cnt];
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin
                    if (bit_cnt == 7) state <= 13;
                    else bit_cnt <= bit_cnt + 1'b1;
                end
            end
            13: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) state <= 14; 
            end
            14: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 2) sda_en <= 1; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin state <= 15; bit_cnt <= 0; data_to_send <= MPU_ADDR_R; end
            end
            15: begin
                if (phase == 0) sda_en <= ~data_to_send[7 - bit_cnt];
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin
                    if (bit_cnt == 7) state <= 16;
                    else bit_cnt <= bit_cnt + 1'b1;
                end
            end
            16: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin state <= 17; bit_cnt <= 0; end 
            end
            17: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 2) high_byte[7 - bit_cnt] <= i2c_sda; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin
                    if (bit_cnt == 7) state <= 18;
                    else bit_cnt <= bit_cnt + 1'b1;
                end
            end
            18: begin
                if (phase == 0) sda_en <= 1; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin state <= 19; bit_cnt <= 0; end
            end
            19: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 2) low_byte[7 - bit_cnt] <= i2c_sda; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) begin
                    if (bit_cnt == 7) state <= 20;
                    else bit_cnt <= bit_cnt + 1'b1;
                end
            end
            20: begin
                if (phase == 0) sda_en <= 0; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 3) scl_en <= 1; 
                if (phase == 3) state <= 21;
            end
            21: begin
                if (phase == 0) sda_en <= 1; 
                if (phase == 1) scl_en <= 0; 
                if (phase == 2) sda_en <= 0; 
                if (phase == 3) begin
                    accel_x <= {high_byte, low_byte}; 
                    state <= 9; 
                end
            end
        endcase
    end
end
endmodule