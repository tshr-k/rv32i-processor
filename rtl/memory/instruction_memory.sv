module instruction_memory
    import rv32i_pkg::*;
    import math_pkg::*;
#(
    parameter int unsigned DEPTH = 256
) (
    input  word_t addr,

    output word_t instruction
);
    word_t instructions [DEPTH-1:0];

    initial begin
        assert (DEPTH > 0)
            else $fatal(1, "DEPTH must be positive.");

        $readmemh("hex/instruction_memory.hex", instructions);
    end

    localparam int unsigned INSTR_ADDR_WIDTH = min1_clog2(DEPTH);

    always_comb begin
        assert (addr < DEPTH)
            else $error("Instruction address out of bounds");

        instruction = instructions[addr[(INSTR_ADDR_WIDTH+2) - 1 : 2]];
    end
endmodule
