module register_file
    import rv32i_pkg::*;
#(
    // Must stay disabled in the single-cycle core, where the bypass would form
    // a combinational loop (read data -> ALU -> write data -> read data)
    parameter bit WRITE_THROUGH = 1'b0
)
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

    // Synchronous write, with writes to x0 ignored
    always_ff @(posedge clk) begin
        if (write_en && write_addr != '0) begin
            registers[write_addr] <= write_data;
        end
    end

    // Combinational read, with optional write-through bypass
    always_comb begin
        read_data_1 = '0;
        read_data_2 = '0;

        if (read_addr_1 != '0) begin
            read_data_1 = (WRITE_THROUGH && write_en && (write_addr == read_addr_1))
                ? write_data
                : registers[read_addr_1];
        end

        if (read_addr_2 != '0) begin
            read_data_2 = (WRITE_THROUGH && write_en && (write_addr == read_addr_2))
                ? write_data
                : registers[read_addr_2];
        end
    end
endmodule
