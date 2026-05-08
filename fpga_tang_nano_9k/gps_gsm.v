module gsm_gps_hardware_hack (
    input  wire clk,           // 27MHz
    input  wire trigger,       // Goes HIGH on crash/fire/smoke
    input  wire seat_occupied, // High if limit switch is pressed
    input  wire gps_rx_pin,    // Raw GPS data coming in
    output wire gsm_tx_pin     // Data going out to GSM
);

    parameter CLK_FREQ  = 27_000_000;
    parameter BAUD_RATE = 9600;
    parameter CLK_DIV   = CLK_FREQ / BAUD_RATE;
    
    // States
    localparam IDLE         = 0;
    localparam SEND_WAKE    = 1;
    localparam WAIT_1       = 2;
    localparam SEND_CMGF    = 3; // Text Mode
    localparam WAIT_2       = 4;
    localparam SEND_PHONE   = 5; // Phone number
    localparam WAIT_3       = 6;
    localparam SEND_ALERT   = 7; // "ALERT! SEAT: Y/N \n GPS:"
    localparam PASSTHROUGH  = 8; // Let GPS type its coordinates
    localparam SEND_CTRLZ   = 9; // Send SMS
    localparam DONE         = 10;

    reg [3:0] state = IDLE;
    reg [27:0] timer = 0; 
    
    // UART TX Registers
    reg [7:0]  tx_data;
    reg        tx_start = 0;
    reg [11:0] baud_cnt = 0;
    reg [3:0]  bit_idx  = 0;
    reg [9:0]  shift_reg = 10'b1111111111;
    reg        tx_busy  = 0;
    reg        uart_tx_out = 1;
    
    // MUX for GSM TX Pin (Either FPGA UART or Direct GPS Passthrough)
    reg passthrough_en = 0;
    assign gsm_tx_pin = passthrough_en ? gps_rx_pin : uart_tx_out;

    reg [5:0] char_idx = 0;

    always @(posedge clk) begin
        // --- 1. MASTER STATE MACHINE ---
        tx_start <= 0; 
        
        case(state)
            IDLE: begin
                if (trigger) state <= SEND_WAKE;
                char_idx <= 0;
                passthrough_en <= 0;
            end
            
            SEND_WAKE: begin // Send "AT\r\n"
                if (!tx_busy && !tx_start) begin
                    if (char_idx == 0) tx_data <= "A";
                    else if (char_idx == 1) tx_data <= "T";
                    else if (char_idx == 2) tx_data <= 8'h0D;
                    else if (char_idx == 3) tx_data <= 8'h0A;
                    
                    if (char_idx < 4) begin tx_start <= 1; char_idx <= char_idx + 1; end 
                    else begin char_idx <= 0; state <= WAIT_1; end
                end
            end
            
            WAIT_1: begin // Wait 1 second
                if (timer < 27_000_000) timer <= timer + 1;
                else begin timer <= 0; state <= SEND_CMGF; end
            end
            
            SEND_CMGF: begin // Send "AT+CMGF=1\r\n"
                if (!tx_busy && !tx_start) begin
                    if (char_idx == 0) tx_data <= "A";
                    else if (char_idx == 1) tx_data <= "T";
                    else if (char_idx == 2) tx_data <= "+";
                    else if (char_idx == 3) tx_data <= "C";
                    else if (char_idx == 4) tx_data <= "M";
                    else if (char_idx == 5) tx_data <= "G";
                    else if (char_idx == 6) tx_data <= "F";
                    else if (char_idx == 7) tx_data <= "=";
                    else if (char_idx == 8) tx_data <= "1";
                    else if (char_idx == 9) tx_data <= 8'h0D;
                    else if (char_idx == 10) tx_data <= 8'h0A;
                    
                    if (char_idx < 11) begin tx_start <= 1; char_idx <= char_idx + 1; end 
                    else begin char_idx <= 0; state <= WAIT_2; end
                end
            end
            
            WAIT_2: begin // Wait 1 sec
                if (timer < 27_000_000) timer <= timer + 1;
                else begin timer <= 0; state <= SEND_PHONE; end
            end

            SEND_PHONE: begin // AT+CMGS="+919876543210"\r\n (REPLACE WITH YOUR EMERGENCY NUMBER!)
                if (!tx_busy && !tx_start) begin
                    if (char_idx == 0) tx_data <= "A";
                    else if (char_idx == 1) tx_data <= "T";
                    else if (char_idx == 2) tx_data <= "+";
                    else if (char_idx == 3) tx_data <= "C";
                    else if (char_idx == 4) tx_data <= "M";
                    else if (char_idx == 5) tx_data <= "G";
                    else if (char_idx == 6) tx_data <= "S";
                    else if (char_idx == 7) tx_data <= "=";
                    else if (char_idx == 8) tx_data <= "\"";
                    // Phone number digits
                    else if (char_idx == 9) tx_data <= "+";
                    else if (char_idx == 10) tx_data <= "9";
                    else if (char_idx == 11) tx_data <= "1";
                    else if (char_idx == 12) tx_data <= "9";
                    else if (char_idx == 13) tx_data <= "8";
                    else if (char_idx == 14) tx_data <= "7";
                    else if (char_idx == 15) tx_data <= "6";
                    else if (char_idx == 16) tx_data <= "5";
                    else if (char_idx == 17) tx_data <= "4";
                    else if (char_idx == 18) tx_data <= "3";
                    else if (char_idx == 19) tx_data <= "2";
                    else if (char_idx == 20) tx_data <= "1";
                    else if (char_idx == 21) tx_data <= "0";
                    else if (char_idx == 22) tx_data <= "\"";
                    else if (char_idx == 23) tx_data <= 8'h0D;
                    else if (char_idx == 24) tx_data <= 8'h0A;
                    
                    if (char_idx < 25) begin tx_start <= 1; char_idx <= char_idx + 1; end 
                    else begin char_idx <= 0; state <= WAIT_3; end
                end
            end
            
            WAIT_3: begin // Wait 1 sec for ">" prompt
                if (timer < 27_000_000) timer <= timer + 1;
                else begin timer <= 0; state <= SEND_ALERT; end
            end
            
            SEND_ALERT: begin // Send "EMERGENCY! SEAT: Y/N \n GPS:"
                if (!tx_busy && !tx_start) begin
                    if (char_idx == 0) tx_data <= "E";
                    else if (char_idx == 1) tx_data <= "M";
                    else if (char_idx == 2) tx_data <= "E";
                    else if (char_idx == 3) tx_data <= "R";
                    else if (char_idx == 4) tx_data <= "G";
                    else if (char_idx == 5) tx_data <= "E";
                    else if (char_idx == 6) tx_data <= "N";
                    else if (char_idx == 7) tx_data <= "C";
                    else if (char_idx == 8) tx_data <= "Y";
                    else if (char_idx == 9) tx_data <= "!";
                    else if (char_idx == 10) tx_data <= " ";
                    else if (char_idx == 11) tx_data <= "S";
                    else if (char_idx == 12) tx_data <= "E";
                    else if (char_idx == 13) tx_data <= "A";
                    else if (char_idx == 14) tx_data <= "T";
                    else if (char_idx == 15) tx_data <= ":";
                    // Inject Limit Switch Status Dynamically!
                    else if (char_idx == 16) tx_data <= seat_occupied ? "Y" : "N";
                    else if (char_idx == 17) tx_data <= 8'h0A; // Newline
                    else if (char_idx == 18) tx_data <= "G";
                    else if (char_idx == 19) tx_data <= "P";
                    else if (char_idx == 20) tx_data <= "S";
                    else if (char_idx == 21) tx_data <= ":";
                    
                    if (char_idx < 22) begin tx_start <= 1; char_idx <= char_idx + 1; end 
                    else begin char_idx <= 0; state <= PASSTHROUGH; end
                end
            end
            
            PASSTHROUGH: begin
                passthrough_en <= 1; // Open the floodgates! GPS talks directly to GSM.
                // Wait 2 seconds
                if (timer < 54_000_000) timer <= timer + 1;
                else begin 
                    timer <= 0; 
                    passthrough_en <= 0; // Cut the connection
                    state <= SEND_CTRLZ; 
                end
            end
            
            SEND_CTRLZ: begin
                if (!tx_busy && !tx_start) begin
                    if (char_idx == 0) tx_data <= 8'h1A; // CTRL+Z (Send SMS command)
                    
                    if (char_idx < 1) begin tx_start <= 1; char_idx <= char_idx + 1; end 
                    else begin char_idx <= 0; state <= DONE; end
                end
            end
            
            DONE: begin
                // System is locked down after sending the emergency text.
                // Press the physical Reset button on the FPGA to restart the system.
            end
        endcase

        // --- 2. INTERNAL UART TRANSMITTER ---
        if (!tx_busy) begin
            if (tx_start) begin
                tx_busy  <= 1;
                bit_idx  <= 0;
                baud_cnt <= 0;
                shift_reg <= {1'b1, tx_data, 1'b0}; // Stop, Data, Start
            end
            uart_tx_out <= 1;
        end else begin
            if (baud_cnt < CLK_DIV - 1) begin
                baud_cnt <= baud_cnt + 1'b1;
            end else begin
                baud_cnt <= 0;
                uart_tx_out <= shift_reg[0];
                shift_reg <= {1'b1, shift_reg[9:1]};
                
                if (bit_idx < 9) bit_idx <= bit_idx + 1;
                else tx_busy <= 0;
            end
        end
    end
endmodule