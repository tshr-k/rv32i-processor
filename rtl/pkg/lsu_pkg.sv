package lsu_pkg;
    typedef enum logic [3:0] {
        MEM_LB,
        MEM_LBU,
        MEM_LH,
        MEM_LHU,
        MEM_LW,
        MEM_SB,
        MEM_SH,
        MEM_SW,
        MEM_NOP
    } memory_op_t;
endpackage
