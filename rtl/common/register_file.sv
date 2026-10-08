module register_file
    import rv32i_pkg::*;
(
    input  logic           clk,

    input  register_addr_t read_addr_1,
    input  register_addr_t read_addr_2,
    output word_t          read_data_1,
    output word_t          read_data_2,

    input  register_addr_t write_addr,
    input  logic           write_en,
    input  word_t          write_data
);
    word_t registers [31:0];

    always_ff @(posedge clk) begin
        if (write_en && write_addr != '0) begin
            registers[write_addr] <= write_data;
        end
    end

    assign read_data_1 = (read_addr_1 == '0) ? '0 : registers[read_addr_1];
    assign read_data_2 = (read_addr_2 == '0) ? '0 : registers[read_addr_2];
endmodule
