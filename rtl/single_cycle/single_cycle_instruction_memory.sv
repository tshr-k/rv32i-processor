import rv32i_pkg::*;

module single_cycle_instruction_memory #(
    parameter int unsigned DEPTH      = 256,
    parameter              IMAGE_PATH = DEFAULT_INSTR_MEM_IMAGE_PATH
) (
    input  word_addr_t word_addr,
    output word_t      instruction
);
    word_t instructions [DEPTH-1:0];

    initial begin
        assert (DEPTH >= 2 && (DEPTH & (DEPTH - 1)) == 0)
            else $fatal(1, "DEPTH must be a power of 2 and at least 2.");

        $readmemh(IMAGE_PATH, instructions);
    end

    localparam int unsigned INSTR_ADDR_WIDTH = $clog2(DEPTH);

    // Asynchronous read
    // Upper address bits are ignored, so out-of-range addresses wrap around
    assign instruction = instructions[word_addr[(INSTR_ADDR_WIDTH+2) - 1 : 2]];
endmodule
