module pipeline_core
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
    // Control signals straight from the controller, for the instruction being fetched
    logic               rf_write_en_IF;
    rf_write_data_sel_t rf_write_data_sel_IF;

    alu_op_t            alu_op_IF;
    alu_a_sel_t         alu_a_sel_IF;
    alu_b_sel_t         alu_b_sel_IF;

    memory_op_t         memory_op_IF;

    instruction_fmt_t   instruction_fmt_IF;
    branch_condition_t  branch_condition_IF;
    pc_next_sel_t       pc_next_sel_IF;

    logic               mret_en_IF;
    exception_t         controller_exception_IF;

    // Exceptions are taken in MEM
    exception_t         exception_MEM;
    logic               exception;
    word_t              instruction_addr_MEM;
    logic               pc_next_override_en;
    word_t              pc_next_override;

    word_t              mtvec;
    word_t              mepc;

    // Hazard control
    logic               stall_IF;
    logic               stall_ID;
    logic               flush_EX;

    logic               memory_write_en_raw;

    controller u_controller (
        .instruction         (instruction),
        .rf_write_en         (rf_write_en_IF),
        .rf_write_data_sel   (rf_write_data_sel_IF),
        .alu_op              (alu_op_IF),
        .alu_a_sel           (alu_a_sel_IF),
        .alu_b_sel           (alu_b_sel_IF),
        .memory_op           (memory_op_IF),
        .instruction_fmt     (instruction_fmt_IF),
        .branch_condition    (branch_condition_IF),
        .pc_next_sel         (pc_next_sel_IF),
        .mret_en             (mret_en_IF),
        .controller_exception(controller_exception_IF)
    );

    // TODO: Younger instructions in IF/ID/EX are not yet squashed on an exception,
    // nor is the register file write of the excepting instruction suppressed in WB
    assign exception           = exception_MEM != EXCEPT_NONE;
    assign pc_next_override_en = exception || mret_en_IF;
    assign pc_next_override    = exception ? mtvec : mepc;

    // No Zicsr instructions yet, so the CSRs are only written on trap entry
    machine_csr u_machine_csr (
        .clk           (clk),
        .reset         (reset),
        .trap_enter    (exception),
        .trap_pc       (instruction_addr_MEM),
        .trap_cause    (word_t'(exception_MEM)),  // Exceptions only (interrupt bit clear)
        .csr_addr      ('0),
        .csr_read_data (),
        .csr_write_en  (1'b0),
        .csr_write_data('0),
        .mepc          (mepc),
        .mcause        (),
        .mtvec         (mtvec)
    );

    // TODO: No hazard unit yet, so programs must be free of hazards
    // (like hex/instr/sum_loop_mixed_ops_nop_padded.hex)
    assign stall_IF = 1'b0;
    assign stall_ID = 1'b0;
    assign flush_EX = 1'b0;

    pipeline_datapath u_datapath (
        .clk                     (clk),
        .reset                   (reset),
        .instruction_addr_IF     (instruction_addr),
        .instruction_IF          (instruction),
        .rf_write_en_IF          (rf_write_en_IF),
        .rf_write_data_sel_IF    (rf_write_data_sel_IF),
        .alu_op_IF               (alu_op_IF),
        .alu_a_sel_IF            (alu_a_sel_IF),
        .alu_b_sel_IF            (alu_b_sel_IF),
        .memory_op_IF            (memory_op_IF),
        .instruction_fmt_IF      (instruction_fmt_IF),
        .branch_condition_IF     (branch_condition_IF),
        .pc_next_sel_IF          (pc_next_sel_IF),
        .controller_exception_IF (controller_exception_IF),
        .stall_IF                (stall_IF),
        .stall_ID                (stall_ID),
        .flush_EX                (flush_EX),
        .memory_read_data_raw_MEM(memory_read_data_raw),
        .memory_word_addr_MEM    (memory_word_addr),
        .memory_write_en_MEM     (memory_write_en_raw),
        .memory_write_data_MEM   (memory_write_data),
        .memory_write_strobe_MEM (memory_write_strobe),
        .pc_next_override_en_IF  (pc_next_override_en),
        .pc_next_override_IF     (pc_next_override),
        .exception_MEM           (exception_MEM),
        .instruction_addr_MEM    (instruction_addr_MEM)
    );

    // Suppress memory writes if an exception occurs
    assign memory_write_en = memory_write_en_raw && !exception;
endmodule
