package rv32i_pkg;
    typedef logic [7:0]  byte_t;
    typedef logic [15:0] half_word_t;
    typedef logic [31:0] word_t;
    typedef logic [4:0]  register_addr_t;

    typedef enum logic [2:0] {
        INSTR_FMT_R,
        INSTR_FMT_I,
        INSTR_FMT_S,
        INSTR_FMT_B,
        INSTR_FMT_J,
        INSTR_FMT_U
    } instruction_fmt_t;
endpackage
