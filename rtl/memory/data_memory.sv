module data_memory
    import rv32i_pkg::*;
#(
    parameter int unsigned DEPTH = 256
) (
    input  logic        clk,
    
    input  logic [31:2] word_addr,
    input  logic        write_en,
    input  word_t       write_data,
    input  logic [3:0]  write_strobe,

    output word_t       read_data
);
    word_t data [DEPTH-1:0];

    initial begin
        $readmemh("hex/data_memory.hex", data);
    end

    always @(posedge clk) begin
        if (write_en) begin

            if (write_strobe[0])
                data[word_addr][7:0] <= write_data[7:0];
            if (write_strobe[1])
                data[word_addr][15:8] <= write_data[15:8];
            if (write_strobe[2])
                data[word_addr][23:16] <= write_data[23:16];
            if (write_strobe[3])
                data[word_addr][31:24] <= write_data[31:24];
        end
    end

    always_comb begin
        assert (word_addr < DEPTH)
            else $error("Word address out of bounds");

        read_data = data[word_addr];
    end

endmodule
