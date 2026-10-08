module single_cycle_exception_unit
    import rv32i_pkg::*;
    import alu_pkg::*;
    import controller_pkg::*;
(
    input exception_t          controller_exception,
    input exception_t          datapath_exception,

    input  logic               rf_write_en_in,
    input  rf_write_data_sel_t rf_write_data_sel_in,
    output logic               rf_write_en_out,
    output rf_write_data_sel_t rf_write_data_sel_out,

    input  alu_op_t            alu_op_in,
    input  alu_a_sel_t         alu_a_sel_in,
    input  alu_b_sel_t         alu_b_sel_in,
    output alu_op_t            alu_op_out,
    output alu_a_sel_t         alu_a_sel_out,
    output alu_b_sel_t         alu_b_sel_out,

    input  instruction_fmt_t   instruction_fmt_in,
    output instruction_fmt_t   instruction_fmt_out,

    input  branch_condition_t  branch_condition_in,
    input  pc_next_sel_t       pc_next_sel_in,
    output branch_condition_t  branch_condition_out,
    output pc_next_sel_t       pc_next_sel_out,

    output logic               exception,
    output exception_t         machine_trap_cause,
    input  word_t              machine_trap_vector,
    output word_t              pc_next_override
);
    assign rf_write_en_out = rf_write_en_in && !exception;
    assign rf_write_data_sel_out = rf_write_data_sel_in;

    assign alu_op_out    = alu_op_in;
    assign alu_a_sel_out = alu_a_sel_in;
    assign alu_b_sel_out = alu_b_sel_in;

    assign instruction_fmt_out  = instruction_fmt_in;

    assign branch_condition_out = branch_condition_in;
    assign pc_next_sel_out      = pc_next_sel_in;

    assign exception = (controller_exception != EXCEPT_NONE)
                    || (datapath_exception   != EXCEPT_NONE);
    assign machine_trap_cause  // Give controller exceptions precedence
        = (controller_exception != EXCEPT_NONE) ? controller_exception : datapath_exception;
    assign pc_next_override     = machine_trap_vector;
endmodule
