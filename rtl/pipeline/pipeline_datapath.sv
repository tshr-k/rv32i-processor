module pipeline_datapath
    import rv32i_pkg::*;
    import alu_pkg::*;
    import controller_pkg::*;
    import lsu_pkg::*;
(
    input  logic               clk,
    input  logic               reset,

    output word_t              instruction_addr_IF,
    input  word_t              instruction_IF,  // Only for obtaining the immediate and/or register addresses

    // Control signals for newly issued instruction
    input  logic               rf_write_en_IF,
    input  rf_write_data_sel_t rf_write_data_sel_IF,
    input  alu_op_t            alu_op_IF,
    input  alu_a_sel_t         alu_a_sel_IF,
    input  alu_b_sel_t         alu_b_sel_IF,
    input  memory_op_t         memory_op_IF,
    input  instruction_fmt_t   instruction_fmt_IF,
    input  branch_condition_t  branch_condition_IF,
    input  pc_next_sel_t       pc_next_sel_IF,
    input  exception_t         controller_exception_IF,

    // Stall and flush signals for handling hazards
    input logic                stall_IF,
    input logic                stall_ID,
    input logic                flush_EX,

    // LSU <-> data memory
    input  word_t              memory_read_data_raw_MEM,
    output logic [31:2]        memory_word_addr_MEM,
    output logic               memory_write_en_MEM,
    output word_t              memory_write_data_MEM,
    output logic [3:0]         memory_write_strobe_MEM,

    // For passing control to the exception handler
    input  logic               pc_next_override_en_IF,
    input  word_t              pc_next_override_IF,

    // Exception of the instruction in the MEM stage, from where all exceptions is taken
    output exception_t         exception_MEM,  // Control or datapath exception
    output word_t              instruction_addr_MEM,  // Trap PC

    // To tell the exception unit to return from the exception handler by overriding the PC
    input  logic               mret_en_IF,
    output logic               mret_en_EX  // We must wait until the previous instruction's exceptions and branch decisions have been taken in MEM
);
    // =========================================================================
    // IF: Instruction fetch
    // =========================================================================

    // Control signals for newly issued instruction
    control_t control_IF;

    assign control_IF = control_t'{
        rf_write_en          : rf_write_en_IF,
        rf_write_data_sel    : rf_write_data_sel_IF,
        alu_op               : alu_op_IF,
        alu_a_sel            : alu_a_sel_IF,
        alu_b_sel            : alu_b_sel_IF,
        memory_op            : memory_op_IF,
        instruction_fmt      : instruction_fmt_IF,
        branch_condition     : branch_condition_IF,
        pc_next_sel          : pc_next_sel_IF,
        controller_exception : controller_exception_IF,
        mret_en              : mret_en_IF
    };

    // Forward declarations
    logic  pc_redirect_en_EX;  // Asserted on a jump or taken-branch instruction
    word_t pc_redirect_target_EX;

    // Program counter register
    word_t pc_IF;
    word_t pc_next_IF;
    word_t pc_plus_4_IF;

    assign instruction_addr_IF = pc_IF;
    assign pc_next_IF          = pc_redirect_en_EX ? pc_redirect_target_EX : pc_plus_4_IF;
    assign pc_plus_4_IF        = pc_IF + 4;

    always_ff @(posedge clk) begin
        if (reset)
            pc_IF <= INSTR_ADDR_RESET;
        else if (!stall_IF)
            pc_IF <= pc_next_override_en_IF ? pc_next_override_IF : pc_next_IF;
    end


    // =========================================================================
    // ID: Instruction decode
    // =========================================================================

    // IF->ID pipeline register
    control_t control_ID;
    word_t    instruction_ID;  // For decoding the immediate and register addresses

    word_t    pc_plus_4_ID;  // For eventually writing PC+4 to the register file in WB
    word_t    instruction_addr_ID;  // For computing the branch/jump target address in EX

    always_ff @(posedge clk) begin
        if (reset) begin
            control_ID <= CONTROL_NOP;
        end else if (!stall_ID) begin
            control_ID          <= control_IF;
            instruction_ID      <= instruction_IF;
            pc_plus_4_ID        <= pc_plus_4_IF;
            instruction_addr_ID <= instruction_addr_IF;
        end
    end

    // Forward declarations
    register_addr_t rf_write_addr_WB;
    logic           rf_write_en_WB;
    word_t          rf_write_data_WB;

    // Register file
    register_addr_t rf_read_addr_1_ID;
    register_addr_t rf_read_addr_2_ID;
    word_t          rf_read_data_1_ID;
    word_t          rf_read_data_2_ID;

    register_addr_t rf_write_addr_ID;  // For eventually writing to the register file in WB

    assign rf_read_addr_1_ID = instruction_ID[19:15];
    assign rf_read_addr_2_ID = instruction_ID[24:20];

    assign rf_write_addr_ID  = instruction_ID[11:7];

    register_file #(
        .WRITE_THROUGH(1'b1)  // WB writes and ID reads in the same cycle
    ) u_register_file (
        .clk        (clk),
        .read_addr_1(rf_read_addr_1_ID),
        .read_addr_2(rf_read_addr_2_ID),
        .read_data_1(rf_read_data_1_ID),
        .read_data_2(rf_read_data_2_ID),
        .write_addr (rf_write_addr_WB),
        .write_en   (rf_write_en_WB),
        .write_data (rf_write_data_WB)
    );

    // Immediate decoder
    word_t immediate_ID;

    immediate_decoder u_immediate_decoder (
        .instruction    (instruction_ID),
        .instruction_fmt(control_ID.instruction_fmt),
        .immediate      (immediate_ID)
    );


    // =========================================================================
    // EX: Execute
    // =========================================================================

    // ID->EX pipeline register
    control_t       control_EX;
    word_t          rf_read_data_1_EX;
    word_t          rf_read_data_2_EX;
    word_t          instruction_addr_EX;
    word_t          immediate_EX;

    word_t          pc_plus_4_EX;  // For eventually writing to the register file in WB
    register_addr_t rf_write_addr_EX;  // For eventually writing to the register file in WB

    always_ff @(posedge clk) begin
        if (reset || flush_EX) begin
            control_EX          <= CONTROL_NOP;
        end else begin
            control_EX          <= control_ID;
            rf_read_data_1_EX   <= rf_read_data_1_ID;
            rf_read_data_2_EX   <= rf_read_data_2_ID;
            instruction_addr_EX <= instruction_addr_ID;
            immediate_EX        <= immediate_ID;
            pc_plus_4_EX        <= pc_plus_4_ID;
            rf_write_addr_EX    <= rf_write_addr_ID;
        end
    end

    // ALU
    word_t alu_a_EX;
    word_t alu_b_EX;
    word_t alu_result_EX;

    always_comb begin
        alu_a_EX = 'x;
        alu_b_EX = 'x;

        unique case (control_EX.alu_a_sel)
            ALU_A_RS1: alu_a_EX = rf_read_data_1_EX;
            ALU_A_PC:  alu_a_EX = instruction_addr_EX;
        endcase

        unique case (control_EX.alu_b_sel)
            ALU_B_RS2: alu_b_EX = rf_read_data_2_EX;
            ALU_B_IMM: alu_b_EX = immediate_EX;
            ALU_B_4:   alu_b_EX = 4;
        endcase
    end

    alu u_alu (
        .a     (alu_a_EX),
        .b     (alu_b_EX),
        .op    (control_EX.alu_op),
        .result(alu_result_EX)
    );

    // Comparator
    logic comparator_eq_EX;
    logic comparator_lt_EX;
    logic comparator_ltu_EX;

    comparator u_comparator (
        .a  (rf_read_data_1_EX),
        .b  (rf_read_data_2_EX),
        .eq (comparator_eq_EX),
        .lt (comparator_lt_EX),
        .ltu(comparator_ltu_EX)
    );

    // Branch resolution
    logic take_branch_EX;

    always_comb begin
        take_branch_EX = 'x;

        unique case (control_EX.branch_condition)
            BRANCH_IF_EQ:  take_branch_EX = comparator_eq_EX;
            BRANCH_IF_NE:  take_branch_EX = !comparator_eq_EX;
            BRANCH_IF_LT:  take_branch_EX = comparator_lt_EX;
            BRANCH_IF_LTU: take_branch_EX = comparator_ltu_EX;
            BRANCH_IF_GE:  take_branch_EX = !comparator_lt_EX;
            BRANCH_IF_GEU: take_branch_EX = !comparator_ltu_EX;
        endcase
    end

    // Control flow redirection
    always_comb begin
        pc_redirect_en_EX     = 1'b0;
        pc_redirect_target_EX = alu_result_EX;

        unique case (control_EX.pc_next_sel)
            PC_NEXT_PLUS_4:
                pc_redirect_en_EX = 1'b0;
            PC_NEXT_BRANCH:
                pc_redirect_en_EX = take_branch_EX;
            PC_NEXT_JUMP: begin
                pc_redirect_en_EX        = 1'b1;
                pc_redirect_target_EX[0] = 1'b0;  // Jump offset is forced to be a multiple of 2 bytes
            end
        endcase
    end

    // Can only be thrown on a jump or taken branch
    logic instr_addr_misaligned_EX;

    assign instr_addr_misaligned_EX = pc_redirect_en_EX && |pc_redirect_target_EX[1:0];

    // Tell the exception unit to return from the exception handler by overriding the PC
    assign mret_en_EX = control_EX.mret_en;


    // =========================================================================
    // MEM: Memory access
    // =========================================================================

    // EX->MEM pipeline register
    control_t       control_MEM;
    word_t          rf_read_data_2_MEM;
    register_addr_t rf_write_addr_MEM;
    word_t          alu_result_MEM;
    word_t          immediate_MEM;
    logic           instr_addr_misaligned_MEM;

    word_t          pc_plus_4_MEM;  // For eventually writing to the register file in WB

    always_ff @(posedge clk) begin
        if (reset) begin
            control_MEM               <= CONTROL_NOP;
            instr_addr_misaligned_MEM <= 1'b0;
        end else begin
            control_MEM               <= control_EX;
            instr_addr_misaligned_MEM <= instr_addr_misaligned_EX;
            instruction_addr_MEM      <= instruction_addr_EX;
            rf_read_data_2_MEM        <= rf_read_data_2_EX;
            rf_write_addr_MEM         <= rf_write_addr_EX;
            alu_result_MEM            <= alu_result_EX;
            immediate_MEM             <= immediate_EX;
            pc_plus_4_MEM             <= pc_plus_4_EX;
        end
    end

    // Data memory LSU
    word_t memory_addr_MEM;
    word_t store_data_MEM;
    word_t load_data_MEM;
    logic  load_addr_misaligned_MEM;
    logic  store_addr_misaligned_MEM;

    assign memory_addr_MEM = alu_result_MEM;
    assign store_data_MEM  = rf_read_data_2_MEM;

    lsu u_lsu (
        .addr                 (memory_addr_MEM),
        .memory_op            (control_MEM.memory_op),
        .word_addr            (memory_word_addr_MEM),
        .read_data_raw        (memory_read_data_raw_MEM),
        .read_data_aligned    (load_data_MEM),
        .write_data_in        (store_data_MEM),
        .write_data_out       (memory_write_data_MEM),
        .write_en             (memory_write_en_MEM),
        .write_strobe         (memory_write_strobe_MEM),
        .load_addr_misaligned (load_addr_misaligned_MEM),
        .store_addr_misaligned(store_addr_misaligned_MEM)
    );


    // =========================================================================
    // Exceptions
    // =========================================================================

    // Exceptions are carried down the pipeline with their instruction and only taken in MEM
    always_comb begin
        exception_MEM = EXCEPT_NONE;

        if (control_MEM.controller_exception != EXCEPT_NONE)  // Controller exceptions take precedence
            exception_MEM = control_MEM.controller_exception;
        else if (instr_addr_misaligned_MEM)
            exception_MEM = EXCEPT_INSTR_ADDR_MISALIGNED;
        else if (load_addr_misaligned_MEM)  // LSU must only ever assert if load operation
            exception_MEM = EXCEPT_LOAD_ADDR_MISALIGNED;
        else if (store_addr_misaligned_MEM)  // LSU must only ever assert if store operation
            exception_MEM = EXCEPT_STORE_ADDR_MISALIGNED;
    end


    // =========================================================================
    // WB: Write back
    // =========================================================================

    // MEM->WB pipeline register
    control_t control_WB;
    word_t    alu_result_WB;
    word_t    load_data_WB;
    word_t    immediate_WB;

    word_t    pc_plus_4_WB;

    always_ff @(posedge clk) begin
        if (reset) begin
            control_WB       <= CONTROL_NOP;
        end else begin
            control_WB       <= control_MEM;
            rf_write_addr_WB <= rf_write_addr_MEM;
            load_data_WB     <= load_data_MEM;
            immediate_WB     <= immediate_MEM;
            alu_result_WB    <= alu_result_MEM;
            pc_plus_4_WB     <= pc_plus_4_MEM;
        end
    end

    assign rf_write_en_WB = control_WB.rf_write_en;

    // Register file write data
    always_comb begin
        rf_write_data_WB = 'x;

        unique case (control_WB.rf_write_data_sel)
            RF_WRITE_ALU_RES:   rf_write_data_WB = alu_result_WB;
            RF_WRITE_MEM_RES:   rf_write_data_WB = load_data_WB;
            RF_WRITE_PC_PLUS_4: rf_write_data_WB = pc_plus_4_WB;
            RF_WRITE_IMM:       rf_write_data_WB = immediate_WB;
        endcase
    end
endmodule
