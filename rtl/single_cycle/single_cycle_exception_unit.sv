module single_cycle_exception_unit
    import rv32i_pkg::*;
(
    input exception_t controller_exception,
    input exception_t datapath_exception,

    // For suppressing in case of an exception
    input  logic      rf_write_en_in,
    output logic      rf_write_en_out,

    // Trap entry, to the machine CSRs
    output logic      exception,
    input  word_t     pc,
    output word_t     trap_pc,
    output word_t     trap_cause,

    // Trap return
    input  logic      mret_en,

    // Program counter redirection on trap entry or return
    input  word_t     mepc,
    input  word_t     mtvec,
    output logic      pc_next_override_en,
    output word_t     pc_next_override
);
    assign rf_write_en_out = rf_write_en_in && !exception;

    assign exception = (controller_exception != EXCEPT_NONE)
                    || (datapath_exception   != EXCEPT_NONE);

    assign trap_pc = pc;

    // Exceptions only (interrupt bit clear), give controller exceptions precedence
    assign trap_cause = (controller_exception != EXCEPT_NONE)
        ? word_t'(controller_exception)
        : word_t'(datapath_exception);

    assign pc_next_override_en = exception || mret_en;
    assign pc_next_override    = exception ? mtvec : mepc;
endmodule
