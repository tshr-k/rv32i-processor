import rv32i_pkg::*;

module immediate_decoder (
    input  word_t            instruction,
    input  instruction_fmt_t instruction_fmt,

    output word_t            immediate
);
    logic sign;

    assign sign = instruction[31];

    always_comb begin
        immediate = 'x;

        unique case (instruction_fmt)
            INSTR_FMT_R:
                immediate = '0;
            INSTR_FMT_I:
                immediate = {
                    {20{sign}},
                    instruction[31:20]
                };
            INSTR_FMT_S:
                immediate = {
                    {20{sign}},
                    instruction[31:25],
                    instruction[11:7]
                };
            INSTR_FMT_B:
                immediate = {
                    {19{sign}},
                    instruction[31],
                    instruction[7],
                    instruction[30:25],
                    instruction[11:8],
                    1'b0  // Branch targets are always 2-byte aligned
                };
            INSTR_FMT_J:
                immediate = {
                    {11{sign}},
                    instruction[31],
                    instruction[19:12],
                    instruction[20],
                    instruction[30:21],
                    1'b0  // Jump targets are always 2-byte aligned
                };
            INSTR_FMT_U:
                immediate = {
                    instruction[31:12],
                    12'b0
                };
        endcase
    end
endmodule
