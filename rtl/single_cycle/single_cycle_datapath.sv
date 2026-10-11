module single_cycle_datapath
    import rv32i_pkg::*;
    import alu_pkg::*;
    import controller_pkg::*;
    import lsu_pkg::*;
(
    input  logic               clk,
    input  logic               reset,

    input  logic               rf_write_en,
    input  rf_write_data_sel_t rf_write_data_sel,

    input  alu_op_t            alu_op,
    input  alu_a_sel_t         alu_a_sel,
    input  alu_b_sel_t         alu_b_sel,

    input  memory_op_t         memory_op,
    input  word_t              memory_read_data_raw,
    output logic [31:2]        memory_word_addr,
    output logic               memory_write_en,
    output word_t              memory_write_data,
    output logic [3:0]         memory_write_strobe,

    output word_t              instruction_addr,
    input  word_t              instruction,  // Only for decoding the immediate
    input  instruction_fmt_t   instruction_fmt,

    input  branch_condition_t  branch_condition,
    input  pc_next_sel_t       pc_next_sel,
    input  logic               pc_next_override_en,  // For passing control to the exception handler
    input  word_t              pc_next_override,

    output exception_t         datapath_exception
);
    // Register file
    register_addr_t rf_read_addr_1;
    register_addr_t rf_read_addr_2;
    word_t          rf_read_data_1;
    word_t          rf_read_data_2;
    register_addr_t rf_write_addr;
    word_t          rf_write_data;

    assign rf_read_addr_1 = instruction[19:15];
    assign rf_read_addr_2 = instruction[24:20];

    assign rf_write_addr  = instruction[11:7];

    // Forward declarations
    word_t alu_result;
    word_t load_data;
    word_t pc;
    word_t pc_plus_4;
    word_t immediate;

    always_comb begin
        rf_write_data = 'x;

        unique case (rf_write_data_sel)
            RF_WRITE_ALU_RES:   rf_write_data = alu_result;
            RF_WRITE_MEM_RES:   rf_write_data = load_data;
            RF_WRITE_PC_PLUS_4: rf_write_data = pc_plus_4;

            // To simplify control, the immediate is not routed through
            // the ALU (add zero) for the LUI instruction
            RF_WRITE_IMM:       rf_write_data = immediate;
        endcase
    end

    register_file u_register_file (
        .clk        (clk),
        .read_addr_1(rf_read_addr_1),
        .read_addr_2(rf_read_addr_2),
        .read_data_1(rf_read_data_1),
        .read_data_2(rf_read_data_2),
        .write_addr (rf_write_addr),
        .write_en   (rf_write_en),
        .write_data (rf_write_data)
    );


    // Immediate decoder
    immediate_decoder u_immediate_decoder (
        .instruction    (instruction),
        .instruction_fmt(instruction_fmt),
        .immediate      (immediate)
    );


    // ALU
    word_t alu_a;
    word_t alu_b;

    always_comb begin
        alu_a = 'x;
        alu_b = 'x;

        unique case (alu_a_sel)
            ALU_A_RS1: alu_a = rf_read_data_1;
            ALU_A_PC:  alu_a = pc;
        endcase

        unique case (alu_b_sel)
            ALU_B_RS2: alu_b = rf_read_data_2;
            ALU_B_IMM: alu_b = immediate;
            ALU_B_4:   alu_b = 4;
        endcase
    end

    alu u_alu (
        .a     (alu_a),
        .b     (alu_b),
        .op    (alu_op),
        .result(alu_result)
    );


    // Comparator
    logic comparator_eq;
    logic comparator_lt;
    logic comparator_ltu;

    comparator u_comparator (
        .a  (rf_read_data_1),
        .b  (rf_read_data_2),
        .eq (comparator_eq),
        .lt (comparator_lt),
        .ltu(comparator_ltu)
    );


    // Program counter
    word_t pc_next;
    logic  take_branch;

    assign instruction_addr = pc;
    assign pc_plus_4        = pc + 4;

    always_comb begin
        take_branch = 'x;

        unique case (branch_condition)
            BRANCH_IF_EQ:  take_branch = comparator_eq;
            BRANCH_IF_NE:  take_branch = !comparator_eq;
            BRANCH_IF_LT:  take_branch = comparator_lt;
            BRANCH_IF_LTU: take_branch = comparator_ltu;
            BRANCH_IF_GE:  take_branch = !comparator_lt;
            BRANCH_IF_GEU: take_branch = !comparator_ltu;
        endcase
    end

    always_comb begin
        pc_next = 'x;

        unique case (pc_next_sel)
            PC_NEXT_PLUS_4:
                pc_next = pc_plus_4;
            PC_NEXT_BRANCH:
                pc_next = take_branch ? alu_result : pc_plus_4;
            PC_NEXT_JUMP: begin
                pc_next    = alu_result;
                pc_next[0] = 1'b0;  // Jump offset is forced to be a multiple of 2 bytes
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset)
            pc <= INSTR_ADDR_RESET;
        else
            pc <= pc_next_override_en ? pc_next_override : pc_next;
    end


    // Data memory
    word_t memory_addr;
    word_t store_data;
    logic  load_addr_misaligned;
    logic  store_addr_misaligned;

    assign memory_addr = alu_result;
    assign store_data  = rf_read_data_2;

    lsu u_lsu (
        .addr                 (memory_addr),
        .memory_op            (memory_op),
        .word_addr            (memory_word_addr),
        .read_data_raw        (memory_read_data_raw),
        .read_data_aligned    (load_data),
        .write_data_in        (store_data),
        .write_data_out       (memory_write_data),
        .write_en             (memory_write_en),
        .write_strobe         (memory_write_strobe),
        .load_addr_misaligned (load_addr_misaligned),
        .store_addr_misaligned(store_addr_misaligned)
    );


    // Exceptions
    always_comb begin
        datapath_exception = EXCEPT_NONE;

        if (|pc_next[1:0])
            datapath_exception = EXCEPT_INSTR_ADDR_MISALIGNED;
        else if (load_addr_misaligned)  // LSU must only ever assert if load operation
            datapath_exception = EXCEPT_LOAD_ADDR_MISALIGNED;
        else if (store_addr_misaligned)  // LSU must only ever assert if store operation
            datapath_exception = EXCEPT_STORE_ADDR_MISALIGNED;
    end
endmodule
