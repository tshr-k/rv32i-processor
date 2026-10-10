module pipeline_hazard_unit (
    // TODO: handle actual (control/datapath) hazards, not just flushing for exceptions
    input  logic exception_MEM,
    input  logic mret_en_EX,

    output logic stall_IF,
    output logic stall_ID,

    output logic flush_ID,
    output logic flush_EX,
    output logic flush_MEM,
    output logic flush_WB
);
    // Stalls haven't been implemented yet
    assign stall_IF = 1'b0;
    assign stall_ID = 1'b0;

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
