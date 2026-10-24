import rv32i_pkg::*;
import alu_pkg::*;
import controller_pkg::*;
import lsu_pkg::*;

module pipeline_core (
    input  logic       clk,
    input  logic       reset,

    // Data memory interface
    input  word_t      memory_read_data_raw,
    output word_addr_t memory_word_addr,
    output logic       memory_write_en,
    output word_t      memory_write_data,
    output logic [3:0] memory_write_strobe,

    // Instruction memory interface
    output word_t      instruction_addr,
    input  word_t      instruction,
    input  logic       instruction_valid  // Deasserted while the fetch is stalled
);
    // Exceptions are taken in MEM
    exception_t         controller_exception_MEM;
    exception_t         datapath_exception_MEM;
    logic               exception_MEM;
    word_t              instruction_addr_MEM;
    logic               pc_next_override_en;
    word_t              pc_next_override;

    word_t              trap_pc;
    word_t              trap_cause;
    word_t              mtvec;
    word_t              mepc;

    // Hazard control
    logic               stall_IF;
    logic               stall_ID;
    logic               flush_ID;
    logic               flush_EX;
    logic               flush_MEM;
    logic               flush_WB;
    logic               mret_en_EX_hazard;  // mret_en_EX, passed on by the exception unit

    // Hazard detection
    rs1_forward_sel_t   rs1_forward_sel_ID;
    rs2_forward_sel_t   rs2_forward_sel_ID;
    register_addr_t     rf_read_addr_1_ID;
    register_addr_t     rf_read_addr_2_ID;
    register_addr_t     rf_write_addr_EX;
    logic               rf_write_en_EX;
    register_addr_t     rf_write_addr_MEM;
    logic               rf_write_en_MEM;
    logic               is_load_EX;
    logic               pc_redirect_en_EX;  // Asserted on a jump or taken-branch instruction


    // Control signals straight from the controller, for the instruction being decoded
    word_t              instruction_ID;

    logic               rf_write_en_ID;
    rf_write_data_sel_t rf_write_data_sel_ID;

    alu_op_t            alu_op_ID;
    alu_a_sel_t         alu_a_sel_ID;
    alu_b_sel_t         alu_b_sel_ID;

    memory_op_t         memory_op_ID;

    instruction_fmt_t   instruction_fmt_ID;
    branch_condition_t  branch_condition_ID;
    pc_next_sel_t       pc_next_sel_ID;

    logic               mret_en_ID;
    logic               mret_en_EX;
    exception_t         controller_exception_ID;

    // Straight from the datapath
    logic               memory_write_en_raw;

    // Effective write-enable signal after any suppression due to exceptions
    logic               memory_write_en_eff;

    assign memory_write_en = memory_write_en_eff;

    controller u_controller (
        .instruction         (instruction_ID),
        .rf_write_en         (rf_write_en_ID),
        .rf_write_data_sel   (rf_write_data_sel_ID),
        .alu_op              (alu_op_ID),
        .alu_a_sel           (alu_a_sel_ID),
        .alu_b_sel           (alu_b_sel_ID),
        .memory_op           (memory_op_ID),
        .instruction_fmt     (instruction_fmt_ID),
        .branch_condition    (branch_condition_ID),
        .pc_next_sel         (pc_next_sel_ID),
        .mret_en             (mret_en_ID),
        .controller_exception(controller_exception_ID)
    );

    pipeline_exception_unit u_exception_unit (
        .controller_exception(controller_exception_MEM),
        .datapath_exception  (datapath_exception_MEM),
        .memory_write_en_in  (memory_write_en_raw),
        .memory_write_en_out (memory_write_en_eff),
        .exception           (exception_MEM),
        .pc                  (instruction_addr_MEM),
        .trap_pc             (trap_pc),
        .trap_cause          (trap_cause),
        .mret_en_in          (mret_en_EX),
        .mret_en_out         (mret_en_EX_hazard),
        .mtvec               (mtvec),
        .mepc                (mepc),
        .pc_next_override_en (pc_next_override_en),
        .pc_next_override    (pc_next_override)
    );

    // No Zicsr instructions yet, so the CSRs are only written on trap entry
    machine_csr u_machine_csr (
        .clk           (clk),
        .reset         (reset),
        .trap_enter    (exception_MEM),
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

    pipeline_hazard_unit u_hazard_unit (
        .rf_read_addr_1_ID   (rf_read_addr_1_ID),
        .rf_read_addr_2_ID   (rf_read_addr_2_ID),
        .rf_write_addr_EX    (rf_write_addr_EX),
        .rf_write_en_EX      (rf_write_en_EX),
        .rf_write_addr_MEM   (rf_write_addr_MEM),
        .rf_write_en_MEM     (rf_write_en_MEM),
        .is_load_EX          (is_load_EX),
        .pc_redirect_en_EX   (pc_redirect_en_EX),
        .instruction_valid_IF(instruction_valid),
        .exception_MEM       (exception_MEM),
        .mret_en_EX          (mret_en_EX_hazard),
        .stall_IF            (stall_IF),
        .stall_ID            (stall_ID),
        .flush_ID            (flush_ID),
        .flush_EX            (flush_EX),
        .flush_MEM           (flush_MEM),
        .flush_WB            (flush_WB),
        .rs1_forward_sel_ID  (rs1_forward_sel_ID),
        .rs2_forward_sel_ID  (rs2_forward_sel_ID)
    );


    pipeline_datapath u_datapath (
        .clk                     (clk),
        .reset                   (reset),
        .instruction_addr_IF     (instruction_addr),
        .instruction_IF          (instruction),
        .instruction_ID          (instruction_ID),
        .rf_write_en_ID          (rf_write_en_ID),
        .rf_write_data_sel_ID    (rf_write_data_sel_ID),
        .alu_op_ID               (alu_op_ID),
        .alu_a_sel_ID            (alu_a_sel_ID),
        .alu_b_sel_ID            (alu_b_sel_ID),
        .memory_op_ID            (memory_op_ID),
        .instruction_fmt_ID      (instruction_fmt_ID),
        .branch_condition_ID     (branch_condition_ID),
        .pc_next_sel_ID          (pc_next_sel_ID),
        .controller_exception_ID (controller_exception_ID),
        .stall_IF                (stall_IF),
        .stall_ID                (stall_ID),
        .flush_ID                (flush_ID),
        .flush_EX                (flush_EX),
        .flush_MEM               (flush_MEM),
        .flush_WB                (flush_WB),
        .rs1_forward_sel_ID      (rs1_forward_sel_ID),
        .rs2_forward_sel_ID      (rs2_forward_sel_ID),
        .rf_read_addr_1_ID       (rf_read_addr_1_ID),
        .rf_read_addr_2_ID       (rf_read_addr_2_ID),
        .rf_write_addr_EX        (rf_write_addr_EX),
        .rf_write_en_EX          (rf_write_en_EX),
        .rf_write_addr_MEM       (rf_write_addr_MEM),
        .rf_write_en_MEM         (rf_write_en_MEM),
        .is_load_EX              (is_load_EX),
        .pc_redirect_en_EX       (pc_redirect_en_EX),
        .memory_read_data_raw_MEM(memory_read_data_raw),
        .memory_word_addr_MEM    (memory_word_addr),
        .memory_write_en_MEM     (memory_write_en_raw),
        .memory_write_data_MEM   (memory_write_data),
        .memory_write_strobe_MEM (memory_write_strobe),
        .pc_next_override_en_IF  (pc_next_override_en),
        .pc_next_override_IF     (pc_next_override),
        .controller_exception_MEM(controller_exception_MEM),
        .datapath_exception_MEM  (datapath_exception_MEM),
        .instruction_addr_MEM    (instruction_addr_MEM),
        .mret_en_ID              (mret_en_ID),
        .mret_en_EX              (mret_en_EX)
    );
endmodule
