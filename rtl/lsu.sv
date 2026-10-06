module lsu
    import rv32i_pkg::*;
    import lsu_pkg::*;
(
    input  word_t            addr,
    input  word_t            read_data,
    input  word_t            write_data,
    input  load_store_mode_t load_store_mode,

    output logic [31:2]      word_addr,
    output logic             write_en,
    output word_t            write_data_out,
    output logic [3:0]       write_strobe,
    output word_t            read_data_strobed,
    output logic             misaligned_load,
    output logic             misaligned_store
);
    logic [1:0] byte_offset;
    byte_t      read_byte;
    half_word_t read_half_word;

    assign word_addr   = addr[31:2];
    assign byte_offset = addr[1:0];
    
    assign read_byte      = read_data[8*int'(byte_offset)     +: 8];
    assign read_half_word = read_data[16*int'(byte_offset[1]) +: 16];    

    assign write_en = (load_store_mode inside {
        LSU_SB,
        LSU_SH,
        LSU_SW
    }) && !misaligned_store;

    assign misaligned_load = (load_store_mode inside {LSU_LH, LSU_LHU} && addr[0])
                          || (load_store_mode == LSU_LW && |addr[1:0]);

    assign misaligned_store = (load_store_mode == LSU_SH && addr[0])
                           || (load_store_mode == LSU_SW && |addr[1:0]);

    always_comb begin
        write_data_out = write_data;
        write_strobe      = 4'b0000;
        read_data_strobed = read_data;

        unique case (load_store_mode)
            LSU_LB:
                read_data_strobed = {{24{read_byte[7]}}, read_byte};
            LSU_LBU:
                read_data_strobed = word_t'(read_byte);
            LSU_LH:
                read_data_strobed = {{16{read_half_word[15]}}, read_half_word};
            LSU_LHU:
                read_data_strobed = word_t'(read_half_word);
            LSU_LW:
                read_data_strobed = read_data;
            LSU_SB: begin
                write_data_out = write_data << 8*int'(byte_offset);
                write_strobe = 1'b1 << byte_offset;
            end
            LSU_SH: begin
                write_data_out = write_data << 16*int'(byte_offset[1]);
                write_strobe = 2'b11 << 2*int'(byte_offset[1]);
            end
            LSU_SW:
                write_strobe = 4'b1111;
        endcase
    end
endmodule
