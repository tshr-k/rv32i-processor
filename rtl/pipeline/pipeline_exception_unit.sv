module pipeline_exception_unit
    import rv32i_pkg::*;
(
    input exception_t controller_exception,
    input exception_t datapath_exception,

    // For suppressing in case of an exception
    // rf_write_en is suppressed by flushing the WB stage
    input  logic      memory_write_en_in,
    output logic      memory_write_en_out,

    // Trap entry, to the machine CSRs
    output logic      exception,  // This also tells the hazard unit to flush the pipeline
    input  word_t     pc,
    output word_t     trap_pc,
    output word_t     trap_cause,

    // Trap return
    input  logic      mret_en_in,
    output logic      mret_en_out,  // Passed on to the hazard unit to flush the ID and EX stages

    // Program counter override on trap entry or return
    input  word_t     mepc,
    input  word_t     mtvec,
    output logic      pc_next_override_en,
    output word_t     pc_next_override
);
    assign memory_write_en_out = memory_write_en_in && !exception;

    assign exception = (controller_exception != EXCEPT_NONE)
                    || (datapath_exception   != EXCEPT_NONE);

    assign trap_pc = pc;

    // Exceptions only (interrupt bit clear), give controller exceptions precedence
    assign trap_cause = (controller_exception != EXCEPT_NONE)
        ? word_t'(controller_exception)
        : word_t'(datapath_exception);

    assign mret_en_out = mret_en_in;

    assign pc_next_override_en = exception || mret_en_in;
    assign pc_next_override    = exception ? mtvec : mepc;  // Exception takes precedence over MRET
endmodule
