// ═══════════════════════════════════════════════════════════════════
//  DHT11 Temperature Sensor Reader
//  For Tang Nano 9K (27 MHz clock)
// ═══════════════════════════════════════════════════════════════════
//
//  DHT11 Protocol:
//  1. Host pulls LOW for ≥18ms (start signal)
//  2. Host releases, DHT responds with LOW 80µs + HIGH 80µs
//  3. Each data bit: LOW 50µs + HIGH (26-28µs = '0', 70µs = '1')
//  4. 40 bits total: 8-bit humidity int, 8-bit humidity dec,
//                    8-bit temp int, 8-bit temp dec, 8-bit checksum
//
//  We only need temperature integer (byte 3 of 5).
// ═══════════════════════════════════════════════════════════════════

module dht11_reader #(
    parameter CLK_FREQ = 27_000_000
)(
    input  wire       clk,
    inout  wire       dht_io,     // bidirectional data line
    output reg  [7:0] temperature, // temperature in °C
    output reg        valid        // pulse high when new reading is valid
);

    // Timing constants (in clock cycles)
    localparam US1     = CLK_FREQ / 1_000_000;   // clocks per 1µs = 27
    localparam MS1     = CLK_FREQ / 1_000;        // clocks per 1ms = 27000
    localparam MS20    = 20 * MS1;                // 20ms start pulse
    localparam US40    = 40 * US1;                // 40µs wait after release
    localparam US80    = 80 * US1;                // 80µs response timing
    localparam US50    = 50 * US1;                // 50µs bit start
    localparam US30    = 30 * US1;                // threshold: <30µs = 0
    localparam PERIOD  = CLK_FREQ * 2;            // read every 2 seconds
    
    // States
    localparam S_IDLE      = 4'd0;
    localparam S_START_LOW = 4'd1;
    localparam S_START_REL = 4'd2;
    localparam S_RESP_LOW  = 4'd3;
    localparam S_RESP_HIGH = 4'd4;
    localparam S_BIT_LOW   = 4'd5;
    localparam S_BIT_HIGH  = 4'd6;
    localparam S_DONE      = 4'd7;
    localparam S_ERROR     = 4'd8;
    
    reg [3:0]  state = S_IDLE;
    reg [31:0] cnt   = 0;         // general purpose counter
    reg [31:0] period_cnt = 0;    // period counter for 2-second reads
    
    // Data collection
    reg [39:0] data_bits = 0;     // 40 bits from DHT11
    reg [5:0]  bit_count = 0;     // current bit index (0-39)
    reg [31:0] high_cnt  = 0;     // duration of HIGH pulse
    
    // Bidirectional control
    reg        dht_out   = 1;     // output value
    reg        dht_oe    = 0;     // output enable (1 = drive, 0 = hi-Z)
    
    assign dht_io = dht_oe ? dht_out : 1'bz;
    
    // Sync input
    reg [1:0] dht_sync;
    wire dht_in = dht_sync[1];
    always @(posedge clk) dht_sync <= {dht_sync[0], dht_io};
    
    always @(posedge clk) begin
        valid <= 0;
        
        case (state)
            S_IDLE: begin
                dht_oe <= 0;
                dht_out <= 1;
                if (period_cnt >= PERIOD - 1) begin
                    period_cnt <= 0;
                    cnt <= 0;
                    state <= S_START_LOW;
                end else begin
                    period_cnt <= period_cnt + 1;
                end
            end
            
            // Pull LOW for 20ms
            S_START_LOW: begin
                dht_oe <= 1;
                dht_out <= 0;
                if (cnt >= MS20 - 1) begin
                    cnt <= 0;
                    state <= S_START_REL;
                    dht_oe <= 0;  // release line
                    dht_out <= 1;
                end else begin
                    cnt <= cnt + 1;
                end
            end
            
            // Wait for DHT to pull LOW (response)
            S_START_REL: begin
                dht_oe <= 0;
                if (cnt >= US40) begin
                    if (!dht_in) begin
                        cnt <= 0;
                        state <= S_RESP_LOW;
                    end else if (cnt >= MS1 * 5) begin  // 5ms timeout
                        state <= S_ERROR;
                    end
                end
                cnt <= cnt + 1;
            end
            
            // DHT holds LOW ~80µs
            S_RESP_LOW: begin
                if (dht_in) begin
                    cnt <= 0;
                    state <= S_RESP_HIGH;
                end else if (cnt >= US80 * 2) begin
                    state <= S_ERROR;
                end
                cnt <= cnt + 1;
            end
            
            // DHT holds HIGH ~80µs, then starts data
            S_RESP_HIGH: begin
                if (!dht_in) begin
                    cnt <= 0;
                    bit_count <= 0;
                    data_bits <= 0;
                    state <= S_BIT_LOW;
                end else if (cnt >= US80 * 2) begin
                    state <= S_ERROR;
                end
                cnt <= cnt + 1;
            end
            
            // Each bit starts with ~50µs LOW
            S_BIT_LOW: begin
                if (dht_in) begin
                    cnt <= 0;
                    high_cnt <= 0;
                    state <= S_BIT_HIGH;
                end else if (cnt >= US80 * 2) begin
                    state <= S_ERROR;
                end
                cnt <= cnt + 1;
            end
            
            // HIGH duration determines bit value
            // ~26-28µs = '0', ~70µs = '1'
            S_BIT_HIGH: begin
                if (!dht_in) begin
                    // Bit received — determine 0 or 1
                    if (high_cnt > US30) begin
                        data_bits[39 - bit_count] <= 1'b1;
                    end else begin
                        data_bits[39 - bit_count] <= 1'b0;
                    end
                    
                    bit_count <= bit_count + 1;
                    cnt <= 0;
                    
                    if (bit_count >= 39) begin
                        state <= S_DONE;
                    end else begin
                        state <= S_BIT_LOW;
                    end
                end else begin
                    high_cnt <= high_cnt + 1;
                    if (high_cnt >= US80 * 2) begin
                        state <= S_ERROR;
                    end
                end
            end
            
            // Validate checksum and output temperature
            S_DONE: begin
                // data_bits[39:32] = humidity integer
                // data_bits[31:24] = humidity decimal
                // data_bits[23:16] = temperature integer  ← we want this
                // data_bits[15:8]  = temperature decimal
                // data_bits[7:0]   = checksum
                
                if ((data_bits[39:32] + data_bits[31:24] + 
                     data_bits[23:16] + data_bits[15:8]) == data_bits[7:0]) begin
                    temperature <= data_bits[23:16];
                    valid <= 1;
                end
                
                state <= S_IDLE;
            end
            
            S_ERROR: begin
                // Failed read — keep last valid temperature
                dht_oe <= 0;
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
        endcase
    end

endmodule
