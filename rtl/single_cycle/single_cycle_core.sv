module single_cycle_core
    import rv32i_pkg::*;
    import alu_pkg::*;
    import controller_pkg::*;
    import lsu_pkg::*;
(
    input  logic        clk,
    input  logic        reset,

    // Data memory interface
    input  word_t       memory_read_data_raw,
    output logic [31:2] memory_word_addr,
    output logic        memory_write_en,
    output word_t       memory_write_data,
    output logic [3:0]  memory_write_strobe,

    // Instruction memory interface
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

    logic               mret_en;
    exception_t         controller_exception;
    exception_t         datapath_exception;
    logic               exception;
    logic               pc_next_override_en;
    word_t              pc_next_override;

    word_t              trap_pc;
    word_t              trap_cause;
    word_t              mtvec;
    word_t              mepc;

    // Effective control signals after any suppression due to exceptions
    logic               rf_write_en_eff;
    logic               memory_write_en_raw;

    controller u_controller (
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
        .mret_en             (mret_en),
        .controller_exception(controller_exception)
    );

    single_cycle_exception_unit u_exception_unit (
        .controller_exception(controller_exception),
        .datapath_exception  (datapath_exception),
        .rf_write_en_in      (rf_write_en),
        .rf_write_en_out     (rf_write_en_eff),
        .exception           (exception),
        .pc                  (instruction_addr),
        .trap_pc             (trap_pc),
        .trap_cause          (trap_cause),
        .mret_en             (mret_en),
        .mtvec               (mtvec),
        .mepc                (mepc),
        .pc_next_override_en (pc_next_override_en),
        .pc_next_override    (pc_next_override)
    );

    // No Zicsr instructions yet, so the CSRs are only written on trap entry
    machine_csr u_machine_csr (
        .clk           (clk),
        .reset         (reset),
        .trap_enter    (exception),
        .trap_pc       (trap_pc),
        .trap_cause    (trap_cause),
        .csr_addr      ('0),
        .csr_read_data (),
        .csr_write_en  (1'b0),
        .csr_write_data('0),
        .mepc          (mepc),
        .mcause        (),
        .mtvec         (mtvec)
    );

    single_cycle_datapath u_datapath (
        .clk                 (clk),
        .reset               (reset),
        .rf_write_en         (rf_write_en_eff),
        .rf_write_data_sel   (rf_write_data_sel),
        .alu_op              (alu_op),
        .alu_a_sel           (alu_a_sel),
        .alu_b_sel           (alu_b_sel),
        .memory_op           (memory_op),
        .memory_read_data_raw(memory_read_data_raw),
        .memory_word_addr    (memory_word_addr),
        .memory_write_en     (memory_write_en_raw),
        .memory_write_data   (memory_write_data),
        .memory_write_strobe (memory_write_strobe),
        .instruction_addr    (instruction_addr),
        .instruction         (instruction),
        .instruction_fmt     (instruction_fmt),
        .branch_condition    (branch_condition),
        .pc_next_sel         (pc_next_sel),
        .pc_next_override_en (pc_next_override_en),
        .pc_next_override    (pc_next_override),
        .datapath_exception  (datapath_exception)
    );

    // Suppress memory writes if an exception occurs
    assign memory_write_en = memory_write_en_raw && !exception;
endmodule
