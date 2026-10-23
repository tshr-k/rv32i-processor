import rv32i_pkg::*;

// Single-cycle top-level module with Spike's memory map (tb/spike.py)
// Must be built with SPIKE_MEMORY_MAP defined (make ARCH=single_cycle SPIKE=1), which moves
// INSTR_ADDR_RESET to the base of Spike's memory. Spike has one memory for code and data, which is
// modelled by an instruction memory and a data memory of the same size, both loaded with the
// program, so they hold the same contents until the first store.
module single_cycle_spike #(
    parameter int unsigned MEM_DEPTH            = 256,  // Words, so 1 KiB
    parameter              INSTR_MEM_IMAGE_PATH = DEFAULT_INSTR_MEM_IMAGE_PATH,
    parameter              DATA_MEM_IMAGE_PATH  = DEFAULT_DATA_MEM_IMAGE_PATH
) (
    input logic clk,
    input logic reset
);
    word_t      memory_read_data_raw;
    word_addr_t memory_word_addr;
    logic       memory_write_en;
    word_t      memory_write_data;
    logic [3:0] memory_write_strobe;

    word_t      instruction_addr;
    word_t      instruction;

    // Both memories ignore the upper address bits, so the memory base maps to word 0 as long as it
    // is aligned to the memory size
    single_cycle_core u_core (
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

    single_cycle_instruction_memory #(
        .DEPTH     (MEM_DEPTH),
        .IMAGE_PATH(INSTR_MEM_IMAGE_PATH)
    ) u_instruction_memory (
        .word_addr  (instruction_addr[31:2]),
        .instruction(instruction)
    );

    data_memory #(
        .DEPTH     (MEM_DEPTH),
        .IMAGE_PATH(DATA_MEM_IMAGE_PATH)
    ) u_data_memory (
        .clk         (clk),
        .word_addr   (memory_word_addr),
        .write_en    (memory_write_en),
        .write_data  (memory_write_data),
        .write_strobe(memory_write_strobe),
        .read_data   (memory_read_data_raw)
    );

    initial begin
        assert (INSTR_ADDR_RESET == 32'h8000_0000)
            else $fatal(1, "SPIKE_MEMORY_MAP must be defined, so that the core starts in Spike's memory.");
        assert (INSTR_ADDR_RESET % (4 * MEM_DEPTH) == 0)
            else $fatal(1, "The memory base must be aligned to the memory size.");
    end
endmodule
