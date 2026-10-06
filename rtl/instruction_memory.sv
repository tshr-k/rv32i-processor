module instruction_memory
    import rv32i_pkg::*;
#(
    parameter int unsigned DEPTH = 256
) (
    input  word_t addr,

    output word_t instruction
);
    word_t instructions [DEPTH-1:0];

    initial begin
        $readmemh("hex/instruction_memory.hex", instructions);
    end

    always_comb begin
        assert (addr < DEPTH) 
            else $error("Instruction address out of bounds");
        
        instruction = instructions[addr[31:2]];
    end
endmodule
