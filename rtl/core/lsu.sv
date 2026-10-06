module lsu
    import rv32i_pkg::*;
    import lsu_pkg::*;
(
    input  word_t       addr,
    input  memory_op_t  memory_op,

    output logic [31:2] word_addr,

    input  word_t       read_data_raw,
    output word_t       read_data_strobed,
    
    input  word_t       write_data_in,
    output word_t       write_data_out,
    output logic        write_en,
    output logic [3:0]  write_strobe,

    output logic        load_addr_misaligned,
    output logic        store_addr_misaligned
);
    logic [1:0] byte_offset;
    byte_t      read_byte;
    half_word_t read_half_word;

    assign word_addr   = addr[31:2];
    assign byte_offset = addr[1:0];
    
    assign read_byte      = read_data_raw[8*int'(byte_offset)     +: 8];
    assign read_half_word = read_data_raw[16*int'(byte_offset[1]) +: 16];    

    assign write_en = (memory_op inside {
        MEM_SB,
        MEM_SH,
        MEM_SW
    }) && !store_addr_misaligned;

    assign load_addr_misaligned = (memory_op inside {MEM_LH, MEM_LHU} && addr[0])
                               || (memory_op == MEM_LW && |addr[1:0]);

    assign store_addr_misaligned = (memory_op == MEM_SH && addr[0])
                                || (memory_op == MEM_SW && |addr[1:0]);

    always_comb begin
        write_data_out    = write_data_in;
        write_strobe      = 4'b0000;
        read_data_strobed = read_data_raw;

        unique case (memory_op)
            MEM_LB:
                read_data_strobed = {{24{read_byte[7]}}, read_byte};
            MEM_LBU:
                read_data_strobed = word_t'(read_byte);
            MEM_LH:
                read_data_strobed = {{16{read_half_word[15]}}, read_half_word};
            MEM_LHU:
                read_data_strobed = word_t'(read_half_word);
            MEM_LW:
                read_data_strobed = read_data_raw;
            MEM_SB: begin
                write_data_out = write_data_in << 8*int'(byte_offset);
                write_strobe   = 1'b1 << byte_offset;
            end
            MEM_SH: begin
                write_data_out = write_data_in << 16*int'(byte_offset[1]);
                write_strobe   = 2'b11 << 2*int'(byte_offset[1]);
            end
            MEM_SW:
                write_strobe = 4'b1111;
            MEM_NOP:
                ;
        endcase
    end
endmodule
