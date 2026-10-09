package rv32i_pkg;
    typedef logic [7:0]  byte_t;
    typedef logic [15:0] half_word_t;
    typedef logic [31:0] word_t;
    typedef logic [4:0]  register_addr_t;
    typedef logic [11:0] csr_addr_t;

    typedef enum logic [2:0] {
        INSTR_FMT_R,
        INSTR_FMT_I,
        INSTR_FMT_S,
        INSTR_FMT_B,
        INSTR_FMT_J,
        INSTR_FMT_U
    } instruction_fmt_t;

    // Exception codes as per RISC-V spec
    typedef enum logic [3:0] {
        EXCEPT_INSTR_ADDR_MISALIGNED = 0,
        EXCEPT_ILLEGAL_INSTR         = 2,
        EXCEPT_LOAD_ADDR_MISALIGNED  = 4,
        EXCEPT_STORE_ADDR_MISALIGNED = 6,
        EXCEPT_ECALL                 = 11,  // Environment call from M-mode
        EXCEPT_EBREAK                = 3,
        EXCEPT_NONE                  = 7  // Value is irrelevant
    } exception_t;

    localparam word_t INSTR_ADDR_RESET    = 32'h0000_0000;
    localparam word_t MTVEC_RESET         = 32'h0000_0004;
endpackage
