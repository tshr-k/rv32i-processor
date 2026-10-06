module comparator
    import rv32i_pkg::*;
    import comparator_pkg::*;
(
    input  word_t          a,
    input  word_t          b,
    input  comparator_op_t op,

    output logic           result
);
    always_comb begin        
        unique case (op)
            COMP_EQ:
                result = a == b;
            COMP_NE:
                result = a != b;
            COMP_LT:
                result = $signed(a) < $signed(b);
            COMP_LTU:
                result = a < b;
            COMP_GE:
                result = $signed(a) >= $signed(b);
            COMP_GEU:
                result = a >= b;
        endcase
    end
endmodule
