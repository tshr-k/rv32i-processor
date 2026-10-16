import rv32i_pkg::*;
import controller_pkg::*;

module pipeline_hazard_unit (
    // For data hazard detection
    input  register_addr_t rf_read_addr_1_EX,
    input  register_addr_t rf_read_addr_2_EX,
    input  register_addr_t rf_write_addr_MEM,
    input  logic           rf_write_en_MEM,
    input  register_addr_t rf_write_addr_WB,
    input  logic           rf_write_en_WB,

    // For load-use hazard detection
    input  register_addr_t rf_read_addr_1_ID,
    input  register_addr_t rf_read_addr_2_ID,
    input  register_addr_t rf_write_addr_EX,
    input  logic           is_load_EX,

    // For control hazard detection
    input  logic           pc_redirect_en_EX,  // Asserted on a jump or taken-branch instruction

    // For cache miss detection
    input  logic           instruction_valid_IF,  // Deasserted while the instruction cache services a miss

    // For exception handling
    input  logic           exception_MEM,
    input  logic           mret_en_EX,

    // Stall, flush and forwarding control signals
    output logic           stall_IF,
    output logic           stall_ID,

    output logic           flush_ID,
    output logic           flush_EX,
    output logic           flush_MEM,
    output logic           flush_WB,

    output rs1_forward_sel_t rs1_forward_sel_EX,
    output rs2_forward_sel_t rs2_forward_sel_EX
);
    logic control_hazard;
    logic load_use_hazard;

    assign control_hazard = pc_redirect_en_EX;

    assign load_use_hazard = is_load_EX  && (rf_write_addr_EX != 0) && (
        (rf_read_addr_1_ID == rf_write_addr_EX) ||
        (rf_read_addr_2_ID == rf_write_addr_EX)
    );

    always_comb begin
        stall_IF = 1'b0;
        stall_ID = 1'b0;
        flush_ID  = 1'b0;
        flush_EX  = 1'b0;
        flush_MEM = 1'b0;
        flush_WB  = 1'b0;

        // From top to bottom priority: exceptions, MRET, control hazards, load-use hazards, instruction fetch miss
        if (exception_MEM) begin
            flush_ID  = 1'b1;
            flush_EX  = 1'b1;
            flush_MEM = 1'b1;
            flush_WB  = 1'b1;
        end else if (mret_en_EX) begin
            flush_ID  = 1'b1;
            flush_EX  = 1'b1;
        end else if (control_hazard) begin  // A redirect must win over a cache miss, otherwise stall_IF would stop the PC from taking it
            flush_ID = 1'b1;
            flush_EX = 1'b1;
        end else if (load_use_hazard) begin
            stall_IF = 1'b1;
            stall_ID = 1'b1;
            flush_EX = 1'b1;
        end else if (!instruction_valid_IF) begin
            stall_IF = 1'b1;
            flush_ID = 1'b1;
        end
    end

    // Forwarding
    always_comb begin
        // The rf_write_data from the newer instruction in MEM has priority over the older one in WB
        // No forwarding happens if the MEM or WB instruction was trying to write to register x0
        rs1_forward_sel_EX = RS1_FWD_NONE;
        rs2_forward_sel_EX = RS2_FWD_NONE;

        if (rf_write_en_MEM && (rf_read_addr_1_EX == rf_write_addr_MEM) && (rf_write_addr_MEM != '0))
            rs1_forward_sel_EX = RS1_FWD_MEM;
        else if (rf_write_en_WB && (rf_read_addr_1_EX == rf_write_addr_WB) && (rf_write_addr_WB != '0))
            rs1_forward_sel_EX = RS1_FWD_WB;

        if (rf_write_en_MEM && (rf_read_addr_2_EX == rf_write_addr_MEM) && (rf_write_addr_MEM != '0))
            rs2_forward_sel_EX = RS2_FWD_MEM;
        else if (rf_write_en_WB && (rf_read_addr_2_EX == rf_write_addr_WB) && (rf_write_addr_WB != '0))
            rs2_forward_sel_EX = RS2_FWD_WB;
    end
endmodule
