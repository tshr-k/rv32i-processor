package lsu_pkg;
    typedef enum logic [2:0] {
        MEM_LB,
        MEM_LBU,
        MEM_LH,
        MEM_LHU,
        MEM_LW,
        MEM_SB,
        MEM_SH,
        MEM_SW
    } memory_op_t;
endpackage
