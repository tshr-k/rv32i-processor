module single_cycle_core
    import rv32i_pkg::*;
    import alu_pkg::*;
    import controller_pkg::*;
    import lsu_pkg::*;
(
    input  logic        clk,
    input  logic        reset,

    input  word_t       memory_read_data_raw,
    output logic [31:2] memory_word_addr,
    output logic        memory_write_en,
    output word_t       memory_write_data,
    output logic [3:0]  memory_write_strobe,

    output word_t       instruction_addr,
    input  word_t       instruction
);
    // Control signals straight from the controller
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
    exception_t         datapath_exception;
    logic               exception;
    word_t              pc_next_override;

    word_t              machine_trap_cause;  // Unused for now

    // Effective control signals after any suppression due to exceptions
    logic               rf_write_en_eff;
    rf_write_data_sel_t rf_write_data_sel_eff;

    alu_op_t            alu_op_eff;
    alu_a_sel_t         alu_a_sel_eff;
    alu_b_sel_t         alu_b_sel_eff;

    instruction_fmt_t   instruction_fmt_eff;
    branch_condition_t  branch_condition_eff;
    pc_next_sel_t       pc_next_sel_eff;
    logic               memory_write_en_raw;

    single_cycle_controller u_controller (
        .instruction         (instruction),
        .rf_write_en         (rf_write_en),
        .rf_write_data_sel   (rf_write_data_sel),
        .alu_op              (alu_op),
        .alu_a_sel           (alu_a_sel),
        .alu_b_sel           (alu_b_sel),
        .memory_op           (memory_op),
        .instruction_fmt     (instruction_fmt),
        .branch_condition    (branch_condition),
        .pc_next_sel         (pc_next_sel),
        .controller_exception(controller_exception)
    );

    single_cycle_exception_unit u_exception_unit (
        .controller_exception (controller_exception),
        .datapath_exception   (datapath_exception),
        .rf_write_en_in       (rf_write_en),
        .rf_write_data_sel_in (rf_write_data_sel),
        .rf_write_en_out      (rf_write_en_eff),
        .rf_write_data_sel_out(rf_write_data_sel_eff),
        .alu_op_in            (alu_op),
        .alu_a_sel_in         (alu_a_sel),
        .alu_b_sel_in         (alu_b_sel),
        .alu_op_out           (alu_op_eff),
        .alu_a_sel_out        (alu_a_sel_eff),
        .alu_b_sel_out        (alu_b_sel_eff),
        .instruction_fmt_in   (instruction_fmt),
        .instruction_fmt_out  (instruction_fmt_eff),
        .branch_condition_in  (branch_condition),
        .pc_next_sel_in       (pc_next_sel),
        .branch_condition_out (branch_condition_eff),
        .pc_next_sel_out      (pc_next_sel_eff),
        .exception            (exception),
        .machine_trap_cause   (machine_trap_cause[3:0]),
        .machine_trap_vector  (MACHINE_TRAP_VECTOR),
        .pc_next_override     (pc_next_override)
    );

    single_cycle_datapath u_datapath (
        .clk                 (clk),
        .reset               (reset),
        .rf_write_en         (rf_write_en_eff),
        .rf_write_data_sel   (rf_write_data_sel_eff),
        .alu_op              (alu_op_eff),
        .alu_a_sel           (alu_a_sel_eff),
        .alu_b_sel           (alu_b_sel_eff),
        .memory_op           (memory_op),
        .memory_read_data_raw(memory_read_data_raw),
        .memory_word_addr    (memory_word_addr),
        .memory_write_en     (memory_write_en_raw),
        .memory_write_data   (memory_write_data),
        .memory_write_strobe (memory_write_strobe),
        .instruction_addr    (instruction_addr),
        .instruction         (instruction),
        .instruction_fmt     (instruction_fmt_eff),
        .branch_condition    (branch_condition_eff),
        .pc_next_sel         (pc_next_sel_eff),
        .pc_next_override_en (exception),
        .pc_next_override    (pc_next_override),
        .datapath_exception  (datapath_exception)
    );

    assign memory_write_en = memory_write_en_raw && !exception;
endmodule
