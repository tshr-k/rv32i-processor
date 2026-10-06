package alu_pkg;
    typedef enum logic [2:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA
    } alu_op_t;
endpackage
