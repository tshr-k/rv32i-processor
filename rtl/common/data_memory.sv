module data_memory
    import rv32i_pkg::*;
#(
    parameter int unsigned DEPTH = 256
) (
    input  logic        clk,

    input  logic [31:2] word_addr,

    input  logic        write_en,
    input  word_t       write_data,
    input  logic [3:0]  write_strobe,  // One bit per byte of write_data

    output word_t       read_data
);
    word_t data [DEPTH-1:0];

    initial begin
        assert (DEPTH >= 2 && (DEPTH & (DEPTH - 1)) == 0)
            else $fatal(1, "DEPTH must be a power of 2 and at least 2.");

        $readmemh("hex/data/default.hex", data);
    end

    localparam int unsigned WORD_ADDR_WIDTH = $clog2(DEPTH);

    // Synchronous write
    always @(posedge clk) begin
        if (write_en) begin
            if (write_strobe[0])
                data[word_addr[(WORD_ADDR_WIDTH+2) - 1 : 2]][7:0] <= write_data[7:0];
            if (write_strobe[1])
                data[word_addr[(WORD_ADDR_WIDTH+2) - 1 : 2]][15:8] <= write_data[15:8];
            if (write_strobe[2])
                data[word_addr[(WORD_ADDR_WIDTH+2) - 1 : 2]][23:16] <= write_data[23:16];
            if (write_strobe[3])
                data[word_addr[(WORD_ADDR_WIDTH+2) - 1 : 2]][31:24] <= write_data[31:24];
        end
    end

    // Asynchronous read
    // Upper address bits are ignored, so out-of-range addresses wrap around
    assign read_data = data[word_addr[(WORD_ADDR_WIDTH+2) - 1 : 2]];

endmodule
