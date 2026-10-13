import rv32i_pkg::*;
import alu_pkg::*;

module alu (
    input  word_t   a,
    input  word_t   b,
    input  alu_op_t op,

    output word_t   result
);
    logic [4:0] shift_amount;
    logic       lt;
    logic       ltu;

    assign shift_amount = b[4:0];

    // The comparisons for SLT and SLTU are done in the ALU to simplify control
    // and to allow the comparator to be moved around for earlier branch resolution
    assign lt  = $signed(a) < $signed(b);
    assign ltu = a < b;

    always_comb begin
        result = 'x;

        unique case (op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << shift_amount;
            ALU_SRL:  result = a >> shift_amount;
            ALU_SRA:  result = $unsigned($signed(a) >>> shift_amount);
            ALU_SLT:  result = word_t'(lt);
            ALU_SLTU: result = word_t'(ltu);
        endcase
    end
endmodule
