import rv32i_pkg::*;

// Read-only, direct-mapped instruction cache with one word per line
module pipeline_icache #(
    parameter int unsigned NUM_LINES = 16
) (
    input  logic       clk,
    input  logic       reset,  // Invalidates every line

    // Asynchronous lookup
    input  word_addr_t lookup_word_addr,
    output logic       hit,
    output word_t      lookup_data,  // Only meaningful on a hit

    // Synchronous fill
    input  logic       fill_en,
    input  word_addr_t fill_word_addr,  // This is separate from lookup_word_addr (even though both are never needed simultaneously) to avoid adding a MUX to the critical path
    input  word_t      fill_data
);
    initial begin
        assert (NUM_LINES >= 2 && (NUM_LINES & (NUM_LINES - 1)) == 0)
            else $fatal(1, "NUM_LINES must be a power of 2 and at least 2.");
    end

    localparam int unsigned INDEX_WIDTH = $clog2(NUM_LINES);
    localparam int unsigned TAG_WIDTH   = 30 - INDEX_WIDTH;  // Exclude the 2 LSBs of the word address since they're always 0

    logic [NUM_LINES-1:0] valid;
    logic [TAG_WIDTH-1:0] tags [NUM_LINES-1:0];
    word_t                data [NUM_LINES-1:0];

    // Word address = {tag, index}
    logic [INDEX_WIDTH-1:0] lookup_index;
    logic [TAG_WIDTH-1:0]   lookup_tag;
    logic [INDEX_WIDTH-1:0] fill_index;
    logic [TAG_WIDTH-1:0]   fill_tag;

    assign lookup_index = lookup_word_addr[(INDEX_WIDTH+2) - 1 : 2];
    assign lookup_tag   = lookup_word_addr[31 : INDEX_WIDTH+2];
    assign fill_index   = fill_word_addr[(INDEX_WIDTH+2) - 1 : 2];
    assign fill_tag     = fill_word_addr[31 : INDEX_WIDTH+2];

    assign hit         = valid[lookup_index] && (tags[lookup_index] == lookup_tag);
    assign lookup_data = data[lookup_index];

    // Only the valid bits need to be reset
    always_ff @(posedge clk) begin
        if (reset)
            valid <= '0;
        else if (fill_en)
            valid[fill_index] <= 1'b1;
    end

    always_ff @(posedge clk) begin
        if (fill_en) begin
            tags[fill_index] <= fill_tag;
            data[fill_index] <= fill_data;
        end
    end
endmodule
