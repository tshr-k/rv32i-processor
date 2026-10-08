module comparator
    import rv32i_pkg::*;
(
    input  word_t a,
    input  word_t b,

    output logic  eq,
    output logic  lt,
    output logic  ltu
);
    assign eq  = a == b;
    assign lt  = $signed(a) < $signed(b);
    assign ltu = a < b;
endmodule
