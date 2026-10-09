module pipeline_top
    import rv32i_pkg::*;
#(
    parameter int unsigned INSTR_MEM_DEPTH = 256,
    parameter int unsigned DATA_MEM_DEPTH  = 256
) (
    input logic clk,
    input logic reset
);
    word_t       memory_read_data_raw;
    logic [31:2] memory_word_addr;
    logic        memory_write_en;
    word_t       memory_write_data;
    logic [3:0]  memory_write_strobe;

    word_t       instruction_addr;
    word_t       instruction;

    pipeline_core u_core (
        .clk                 (clk),
        .reset               (reset),
        .memory_read_data_raw(memory_read_data_raw),
        .memory_word_addr    (memory_word_addr),
        .memory_write_en     (memory_write_en),
        .memory_write_data   (memory_write_data),
        .memory_write_strobe (memory_write_strobe),
        .instruction_addr    (instruction_addr),
        .instruction         (instruction)
    );

    instruction_memory #(
        .DEPTH(INSTR_MEM_DEPTH)
    ) u_instruction_memory (
        .addr       (instruction_addr),
        .instruction(instruction)
    );

    data_memory #(
        .DEPTH(DATA_MEM_DEPTH)
    ) u_data_memory (
        .clk         (clk),
        .word_addr   (memory_word_addr),
        .write_en    (memory_write_en),
        .write_data  (memory_write_data),
        .write_strobe(memory_write_strobe),
        .read_data   (memory_read_data_raw)
    );
endmodule
