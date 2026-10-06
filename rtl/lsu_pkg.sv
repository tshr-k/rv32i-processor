package lsu_pkg;
    typedef enum logic [2:0] {
        LSU_LB,
        LSU_LBU,
        LSU_LH,
        LSU_LHU,
        LSU_LW,
        LSU_SB,
        LSU_SH,
        LSU_SW
    } load_store_mode_t;
endpackage
