package controller_pkg;
    typedef enum logic [1:0] {
        RF_WRITE_ALU_RES,
        RF_WRITE_LOAD_DATA,
        RF_WRITE_PC_PLUS_4,
        RF_WRITE_IMM
    } rf_write_data_sel_t;

    typedef enum logic {
        ALU_A_RS1,
        ALU_A_PC
    } alu_a_sel_t;
    
    typedef enum logic [1:0] {
        ALU_B_RS2,
        ALU_B_IMM,
        ALU_B_4
    } alu_b_sel_t;

    typedef enum logic [1:0] {
        PC_NEXT_PLUS_4,
        PC_NEXT_BRANCH,  // Conditional
        PC_NEXT_JUMP  // Unconditional
    } pc_next_sel_t;

    typedef enum logic [2:0] {
        BRANCH_IF_EQ,
        BRANCH_IF_NE,
        BRANCH_IF_LT,
        BRANCH_IF_LTU,
        BRANCH_IF_GE,
        BRANCH_IF_GEU
    } branch_condition_t;
endpackage
