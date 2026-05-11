module master_safety_system (
    input  wire clk,         // Pin 52 (27MHz)
    input  wire flame_in,    // Pin 27
    input  wire mq2_in,      // Pin 28
    
    // --- 4-SEAT PASSENGER BUS ---
    input  wire [3:0] seat_bus, // Pins 29, 30, 41, 42
    
    output wire i2c_scl,     // Pin 26
    inout  wire i2c_sda,     // Pin 25
    output wire uart_tx,     // Pin 63
    
    // --- PINS FOR GPS & GSM ---
    input  wire gps_rx,      // Pin 31 (From GPS TX)
    output wire gsm_tx,      // Pin 32 (To GSM RX)
    input  wire gsm_rx       // Pin 33 (From GSM TX)
);

parameter CLK_FREQ  = 27_000_000;
parameter BAUD_RATE = 9600;
parameter CLK_DIV   = CLK_FREQ / BAUD_RATE;
parameter signed CRASH_THRESHOLD = 16'sd18000; 

// --- 1. MPU6050 I2C ENGINE ---
wire signed [15:0] real_accel_x;

mpu6050_reader i2c_engine (
    .clk(clk),
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda),
    .accel_x(real_accel_x)
);

// --- 2. SENSOR SYNCHRONIZATION ---
reg flame_sync = 0;
reg mq2_sync = 1;
reg [3:0] seat_sync = 4'b1111; 
reg is_crashing = 0;
reg [2:0] passenger_count = 0; 

// --- 3. UART TELEMETRY REGISTERS ---
reg [11:0] baud_cnt  = 0;
reg [3:0]  bit_idx   = 0;
reg [4:0]  char_idx  = 0;  
reg [7:0]  msg [0:28];     
parameter MSG_LEN = 29; 

reg [9:0]  shift_reg = 10'b1111111111;
reg        tx_active = 0;
reg        uart_tx_r = 1;

assign uart_tx = uart_tx_r;

// --- 4. MASTER SENSOR LOOP ---
reg send_trigger = 0;
reg [24:0] sample_timer = 0; 

always @(posedge clk) begin

    flame_sync <= flame_in;
    mq2_sync   <= mq2_in;
    seat_sync  <= seat_bus;

    send_trigger <= 0;

    // Crash detection logic
    if (real_accel_x > CRASH_THRESHOLD || 
        real_accel_x < -CRASH_THRESHOLD)
        is_crashing <= 1; 
    else 
        is_crashing <= 0; 

    // Aggregate 4-seat occupancy
    passenger_count <= 
        (~seat_sync[0]) + 
        (~seat_sync[1]) + 
        (~seat_sync[2]) + 
        (~seat_sync[3]);

    if (sample_timer < 25'd13_500_000) begin

        sample_timer <= sample_timer + 1'b1;

    end 
    else begin

        sample_timer <= 0;
        
        // Build Telemetry String
        if (!flame_sync) begin
            msg[0]<="F"; msg[1]<="L"; msg[2]<="A";
            msg[3]<="M"; msg[4]<="E"; msg[5]<="!";
        end 
        else begin
            msg[0]<="S"; msg[1]<="A"; msg[2]<="F";
            msg[3]<="E"; msg[4]<=" "; msg[5]<=" ";
        end

        msg[6] <= " "; 

        if (!mq2_sync) begin
            msg[7]<="S"; msg[8]<="M"; msg[9]<="O";
            msg[10]<="K"; msg[11]<="E"; msg[12]<="!";
        end 
        else begin
            msg[7]<="C"; msg[8]<="L"; msg[9]<="E";
            msg[10]<="A"; msg[11]<="N"; msg[12]<="!";
        end

        msg[13] <= " "; 

        if (is_crashing) begin
            msg[14]<="C"; msg[15]<="R"; msg[16]<="A";
            msg[17]<="S"; msg[18]<="H"; msg[19]<="!";
        end 
        else begin
            msg[14]<="S"; msg[15]<="A"; msg[16]<="F";
            msg[17]<="E"; msg[18]<=" "; msg[19]<=" ";
        end

        msg[20] <= " "; 

        msg[21]<="S";
        msg[22]<="E";
        msg[23]<="A";
        msg[24]<="T";
        msg[25]<="S";

        msg[26] <= 8'd48 + passenger_count;

        msg[27] <= 8'h0D;
        msg[28] <= 8'h0A;

        send_trigger <= 1; 
    end

    // UART TX FSM
    if (!tx_active) begin

        if (send_trigger) begin
            tx_active <= 1;
            char_idx <= 0;
            bit_idx <= 0;
            baud_cnt <= 0;
        end

        uart_tx_r <= 1;

    end 
    else begin

        if (baud_cnt < CLK_DIV - 1) begin

            baud_cnt <= baud_cnt + 1'b1;

        end 
        else begin

            baud_cnt <= 0;

            if (bit_idx == 0) begin

                shift_reg <= {1'b1, msg[char_idx], 1'b0};

                bit_idx <= 4'd1;
                uart_tx_r <= 0;

            end 
            else if (bit_idx < 4'd10) begin

                uart_tx_r <= shift_reg[1];

                shift_reg <= {1'b1, shift_reg[9:1]};

                bit_idx <= bit_idx + 1'b1;

            end 
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

// =====================================================
// 5. EMERGENCY GSM ALERT SYSTEM
// =====================================================

wire emergency_flag;

assign emergency_flag =
    is_crashing ||
    !flame_sync ||
    !mq2_sync;

reg emergency_latched = 0;

reg [3:0]  gsm_state = 0;
reg [63:0] gsm_timer = 0;

reg [7:0] gsm_char_idx = 0;
reg [7:0] gsm_msg_len = 0;

reg [7:0] gsm_msg [0:127];

reg gsm_send_trigger = 0;

// GSM UART
reg [11:0] gsm_baud_cnt = 0;
reg [3:0]  gsm_bit_idx = 0;

reg [9:0] gsm_shift_reg = 10'b1111111111;

reg gsm_tx_active = 0;
reg gsm_uart_tx_r = 1;

// FINAL FIXED GSM TX
assign gsm_tx = gsm_uart_tx_r;

always @(posedge clk) begin

    if (emergency_flag && !emergency_latched) begin
        emergency_latched <= 1;
        gsm_state <= 1;
        gsm_timer <= 0;
    end

    case (gsm_state)

    0: begin
    end

    // =====================================
    // CALL
    // =====================================

    1: begin

        gsm_msg[0]<="A";
        gsm_msg[1]<="T";
        gsm_msg[2]<="D";
        gsm_msg[3]<="1";
        gsm_msg[4]<="1";
        gsm_msg[5]<="2";
        gsm_msg[6]<=";";
        gsm_msg[7]<=8'h0D;
        gsm_msg[8]<=8'h0A;

        gsm_msg_len <= 9;

        gsm_send_trigger <= 1;

        gsm_state <= 2;
    end

    2: begin

        gsm_send_trigger <= 0;

        if (gsm_timer < 27_000_000 * 15)
            gsm_timer <= gsm_timer + 1;
        else begin
            gsm_state <= 3;
            gsm_timer <= 0;
        end
    end

    // =====================================
    // HANGUP
    // =====================================

    3: begin

        gsm_msg[0]<="A";
        gsm_msg[1]<="T";
        gsm_msg[2]<="H";
        gsm_msg[3]<=8'h0D;
        gsm_msg[4]<=8'h0A;

        gsm_msg_len <= 5;

        gsm_send_trigger <= 1;

        gsm_state <= 4;
    end

    4: begin

        gsm_send_trigger <= 0;

        if (gsm_timer < 27_000_000 * 2)
            gsm_timer <= gsm_timer + 1;
        else begin
            gsm_state <= 5;
            gsm_timer <= 0;
        end
    end

    // =====================================
    // SMS MODE
    // =====================================

    5: begin

        gsm_msg[0]<="A";
        gsm_msg[1]<="T";
        gsm_msg[2]<="+";
        gsm_msg[3]<="C";
        gsm_msg[4]<="M";
        gsm_msg[5]<="G";
        gsm_msg[6]<="F";
        gsm_msg[7]<="=";
        gsm_msg[8]<="1";
        gsm_msg[9]<=8'h0D;
        gsm_msg[10]<=8'h0A;

        gsm_msg_len <= 11;

        gsm_send_trigger <= 1;

        gsm_state <= 6;
    end

    6: begin

        gsm_send_trigger <= 0;

        if (gsm_timer < 27_000_000)
            gsm_timer <= gsm_timer + 1;
        else begin
            gsm_state <= 7;
            gsm_timer <= 0;
        end
    end

    // =====================================
    // PHONE NUMBER
    // =====================================

    7: begin

        gsm_msg[0]<="A";
        gsm_msg[1]<="T";
        gsm_msg[2]<="+";
        gsm_msg[3]<="C";
        gsm_msg[4]<="M";
        gsm_msg[5]<="G";
        gsm_msg[6]<="S";
        gsm_msg[7]<="=";
        gsm_msg[8]<="\"";

        gsm_msg[9]<="1";
        gsm_msg[10]<="1";
        gsm_msg[11]<="2";

        gsm_msg[12]<="\"";

        gsm_msg[13]<=8'h0D;
        gsm_msg[14]<=8'h0A;

        gsm_msg_len <= 15;

        gsm_send_trigger <= 1;

        gsm_state <= 8;
    end

    8: begin

        gsm_send_trigger <= 0;

        if (gsm_timer < 27_000_000)
            gsm_timer <= gsm_timer + 1;
        else begin
            gsm_state <= 9;
            gsm_timer <= 0;
        end
    end

    // =====================================
    // SMS BODY
    // =====================================

    9: begin

        gsm_msg[0]<="E";
        gsm_msg[1]<="M";
        gsm_msg[2]<="G";
        gsm_msg[3]<="!";
        gsm_msg[4]<=" ";
        gsm_msg[5]<="L";
        gsm_msg[6]<="o";
        gsm_msg[7]<="c";
        gsm_msg[8]<=":";
        gsm_msg[9]<=" ";

        gsm_msg[10]<="h";
        gsm_msg[11]<="t";
        gsm_msg[12]<="t";
        gsm_msg[13]<="p";
        gsm_msg[14]<="s";
        gsm_msg[15]<=":";
        gsm_msg[16]<="/";
        gsm_msg[17]<="/";

        gsm_msg[18]<="m";
        gsm_msg[19]<="a";
        gsm_msg[20]<="p";
        gsm_msg[21]<="s";
        gsm_msg[22]<=".";

        gsm_msg[23]<="g";
        gsm_msg[24]<="o";
        gsm_msg[25]<="o";
        gsm_msg[26]<="g";
        gsm_msg[27]<="l";
        gsm_msg[28]<="e";

        gsm_msg[29]<=".";
        gsm_msg[30]<="c";
        gsm_msg[31]<="o";
        gsm_msg[32]<="m";

        gsm_msg[33]<="/";
        gsm_msg[34]<="?";
        gsm_msg[35]<="q";
        gsm_msg[36]<="=";

        gsm_msg_len <= 37;

        gsm_send_trigger <= 1;

        gsm_state <= 10;
    end

    10: begin

        gsm_send_trigger <= 0;

        if (gsm_timer < 27_000_000/10)
            gsm_timer <= gsm_timer + 1;
        else begin
            gsm_state <= 11;
            gsm_timer <= 0;
        end
    end

    // =====================================
    // FIXED COORDINATES
    // =====================================

    11: begin

        // Latitude
        gsm_msg[37] <= "1";
        gsm_msg[38] <= "7";
        gsm_msg[39] <= ".";
        gsm_msg[40] <= "3";
        gsm_msg[41] <= "8";
        gsm_msg[42] <= "5";
        gsm_msg[43] <= "0";

        gsm_msg[44] <= ",";

        // Longitude
        gsm_msg[45] <= "7";
        gsm_msg[46] <= "8";
        gsm_msg[47] <= ".";
        gsm_msg[48] <= "4";
        gsm_msg[49] <= "8";
        gsm_msg[50] <= "6";
        gsm_msg[51] <= "7";

        gsm_msg[52] <= 8'h0D;
        gsm_msg[53] <= 8'h0A;

        gsm_msg_len <= 54;

        gsm_send_trigger <= 1;

        gsm_state <= 12;
    end

    // =====================================
    // CTRL+Z
    // =====================================

    12: begin

        gsm_send_trigger <= 0;

        gsm_msg[0] <= 8'h1A;

        gsm_msg_len <= 1;

        gsm_send_trigger <= 1;

        gsm_state <= 13;
    end

    13: begin
        gsm_send_trigger <= 0;
    end

    endcase

    // =====================================
    // GSM UART FSM
    // =====================================

    if (!gsm_tx_active) begin

        if (gsm_send_trigger) begin

            gsm_tx_active <= 1;

            gsm_char_idx <= 0;
            gsm_bit_idx <= 0;
            gsm_baud_cnt <= 0;
        end

        gsm_uart_tx_r <= 1;

    end 
    else begin

        if (gsm_baud_cnt < CLK_DIV - 1) begin

            gsm_baud_cnt <= gsm_baud_cnt + 1'b1;

        end 
        else begin

            gsm_baud_cnt <= 0;

            if (gsm_bit_idx == 0) begin

                gsm_shift_reg <= {
                    1'b1,
                    gsm_msg[gsm_char_idx],
                    1'b0
                };

                gsm_bit_idx <= 4'd1;

                gsm_uart_tx_r <= 0;

            end 
            else if (gsm_bit_idx < 4'd10) begin

                gsm_uart_tx_r <= gsm_shift_reg[1];

                gsm_shift_reg <= {
                    1'b1,
                    gsm_shift_reg[9:1]
                };

                gsm_bit_idx <= gsm_bit_idx + 1'b1;

            end 
            else begin

                gsm_bit_idx <= 0;

                if (gsm_char_idx + 1 < gsm_msg_len)
                    gsm_char_idx <= gsm_char_idx + 1'b1;
                else begin
                    gsm_tx_active <= 0;
                    gsm_uart_tx_r <= 1;
                end
            end
        end
    end
end

endmodule