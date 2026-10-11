module pipeline_hazard_unit
    import rv32i_pkg::*;
    import controller_pkg::*;
(
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
    // TODO: handle actual (control/datapath/load-use) hazards, not just flushing for exceptions

    // Stalls haven't been implemented yet
    assign stall_IF = 1'b0;
    assign stall_ID = 1'b0;

    // Forwarding hasn't been implemented yet
    assign rs1_forward_sel_EX = RS1_FWD_NONE;
    assign rs2_forward_sel_EX = RS2_FWD_NONE;

    always_comb begin
        flush_ID  = 1'b0;
        flush_EX  = 1'b0;
        flush_MEM = 1'b0;
        flush_WB  = 1'b0;

        if (exception_MEM) begin  // Exception takes precedence over MRET
            flush_ID  = 1'b1;
            flush_EX  = 1'b1;
            flush_MEM = 1'b1;
            flush_WB  = 1'b1;
        end else if (mret_en_EX) begin
            flush_ID  = 1'b1;
            flush_EX  = 1'b1;
        end
    end
endmodule
