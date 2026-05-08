// UART Transmitter - 9600 baud, 8N1
// Designed for Tang Nano 9K (27 MHz clock)

module uart_tx #(
    parameter CLK_FREQ  = 27_000_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       start,   // pulse high to begin transmission
    input  wire [7:0] data,    // byte to transmit
    output reg        tx,      // UART TX line
    output wire       busy     // high while transmitting
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;
    
    reg [2:0]  state     = S_IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0]  bit_idx   = 0;
    reg [7:0]  tx_data   = 0;
    
    assign busy = (state != S_IDLE);
    
    always @(posedge clk) begin
        case (state)
            S_IDLE: begin
                tx <= 1'b1;          // idle high
                clk_count <= 0;
                bit_idx <= 0;
                if (start) begin
                    tx_data <= data;
                    state <= S_START;
                end
            end
            
            S_START: begin
                tx <= 1'b0;          // start bit = LOW
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    state <= S_DATA;
                end
            end
            
            S_DATA: begin
                tx <= tx_data[bit_idx]; // LSB first
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    if (bit_idx < 7) begin
                        bit_idx <= bit_idx + 1;
                    end else begin
                        bit_idx <= 0;
                        state <= S_STOP;
                    end
                end
            end
            
            S_STOP: begin
                tx <= 1'b1;          // stop bit = HIGH
                if (clk_count < CLKS_PER_BIT - 1) begin
                    clk_count <= clk_count + 1;
                end else begin
                    clk_count <= 0;
                    state <= S_IDLE;
                end
            end
            
            default: state <= S_IDLE;
        endcase
    end

endmodule
