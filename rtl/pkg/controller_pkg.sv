package controller_pkg;
    typedef enum logic [1:0] {
        RF_WRITE_ALU_RES,
        RF_WRITE_MEM_RES,
        RF_WRITE_PC_PLUS_4,
        RF_WRITE_IMM  // For the LUI instruction
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

    // This struct is not used in any module's port list
    // to keep the signals easy to access in the cocotb testbenches
    import alu_pkg::*;
    import lsu_pkg::*;
    import rv32i_pkg::*;
    typedef struct packed {
        logic               rf_write_en;
        rf_write_data_sel_t rf_write_data_sel;

        alu_op_t            alu_op;
        alu_a_sel_t         alu_a_sel;
        alu_b_sel_t         alu_b_sel;

        memory_op_t         memory_op;

        instruction_fmt_t   instruction_fmt;

        branch_condition_t  branch_condition;
        pc_next_sel_t       pc_next_sel;

        exception_t         controller_exception;

        logic               mret_en;
    } control_t;

    localparam control_t CONTROL_NOP = '{
        rf_write_en:          1'b0,
        rf_write_data_sel:    RF_WRITE_ALU_RES,
        alu_op:               ALU_ADD,
        alu_a_sel:            ALU_A_RS1,
        alu_b_sel:            ALU_B_RS2,
        memory_op:            MEM_NOP,
        instruction_fmt:      INSTR_FMT_R,
        branch_condition:     BRANCH_IF_EQ,
        pc_next_sel:          PC_NEXT_PLUS_4,
        controller_exception: EXCEPT_NONE,
        mret_en:              1'b0
    };

    typedef enum logic [1:0] {
        RS1_FWD_NONE,
        RS1_FWD_MEM,
        RS1_FWD_WB
    } rs1_forward_sel_t;

    typedef enum logic [1:0] {
        RS2_FWD_NONE,
        RS2_FWD_MEM,
        RS2_FWD_WB
    } rs2_forward_sel_t;
endpackage
