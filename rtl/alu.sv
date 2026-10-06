module alu
    import rv32i_pkg::*;
    import alu_pkg::*;
(
    input  word_t   a,
    input  word_t   b,
    input  alu_op_t op,

    output word_t   result
);
    logic [4:0] shift_amount;

    assign shift_amount = b[4:0];

    always_comb begin
        result = 'x;
        
        unique case (op)
            ALU_ADD:
                result = a + b;
            ALU_SUB:
                result = a - b;
            ALU_AND:
                result = a & b;
            ALU_OR:
                result = a | b;
            ALU_XOR:
                result = a ^ b;
            ALU_SLL:
                result = a << shift_amount;
            ALU_SRL:
                result = a >> shift_amount;
            ALU_SRA:
                result = $unsigned($signed(a) >>> shift_amount);
        endcase
    end
endmodule
