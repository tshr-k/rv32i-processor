module controller
    import rv32i_pkg::*;
    import alu_pkg::*;
    import controller_pkg::*;
    import lsu_pkg::*;
(
    input  word_t              instruction,

    output logic               rf_write_en,
    output rf_write_data_sel_t rf_write_data_sel,

    output alu_op_t            alu_op,
    output alu_a_sel_t         alu_a_sel,
    output alu_b_sel_t         alu_b_sel,

    output memory_op_t         memory_op,

    output instruction_fmt_t   instruction_fmt,

    output branch_condition_t  branch_condition,
    output pc_next_sel_t       pc_next_sel,

    output exception_t         controller_exception
);
    localparam OPCODE_R       = 7'b0110011;
    localparam OPCODE_I_JALR  = 7'b1100111;
    localparam OPCODE_I_LOAD  = 7'b0000011;
    localparam OPCODE_I_ALU   = 7'b0010011;
    localparam OPCODE_I_FENCE = 7'b0001111;
    localparam OPCODE_I_ENV   = 7'b1110011;
    localparam OPCODE_S       = 7'b0100011;
    localparam OPCODE_B       = 7'b1100011;
    localparam OPCODE_J       = 7'b1101111;
    localparam OPCODE_U_AUIPC = 7'b0010111;
    localparam OPCODE_U_LUI   = 7'b0110111;

    logic [6:0] opcode;
    logic [2:0] funct_3;
    logic [6:0] funct_7;

    assign opcode  = instruction[6:0];
    assign funct_3 = instruction[14:12];
    assign funct_7 = instruction[31:25];

    always_comb begin
        instruction_fmt      = INSTR_FMT_R;
        
        rf_write_en          = 1'b0;
        rf_write_data_sel    = RF_WRITE_ALU_RES;

        alu_op               = ALU_ADD;
        alu_a_sel            = ALU_A_RS1;
        alu_b_sel            = ALU_B_RS2;

        memory_op            = MEM_NOP;

        branch_condition     = BRANCH_IF_EQ;
        pc_next_sel          = PC_NEXT_PLUS_4;

        controller_exception = EXCEPT_NONE;

        unique0 case (opcode)
            OPCODE_R: begin
                instruction_fmt   = INSTR_FMT_R;
                rf_write_en       = 1'b1;
                rf_write_data_sel = RF_WRITE_ALU_RES;
                alu_a_sel         = ALU_A_RS1;
                alu_b_sel         = ALU_B_RS2;

                unique0 case (funct_3)
                    3'b000: begin  // ADD or SUB
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_ADD;  // ADD
                            7'b0100000: alu_op               = ALU_SUB;  // SUB
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    3'b111: begin  // AND
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_AND;
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    3'b110: begin  // OR
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_OR;
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    3'b100: begin  // XOR
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_XOR;
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    3'b001: begin  // SLL
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_SLL;
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    3'b101: begin  // SRL or SRA
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_SRL;  // SRL
                            7'b0100000: alu_op               = ALU_SRA;  // SRA
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    3'b010: begin  // SLT
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_SLT;
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    3'b011: begin  // SLTU
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_SLTU;
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    default: controller_exception = EXCEPT_ILLEGAL_INSTR;
                endcase
            end

            OPCODE_I_JALR: begin  // JALR
                instruction_fmt      = INSTR_FMT_I;
                rf_write_en          = 1'b1;
                rf_write_data_sel    = RF_WRITE_PC_PLUS_4;
                alu_op               = ALU_ADD;
                alu_a_sel            = ALU_A_RS1;
                alu_b_sel            = ALU_B_IMM;
                pc_next_sel          = PC_NEXT_JUMP;
                if (funct_3 != 3'b000)
                    controller_exception = EXCEPT_ILLEGAL_INSTR;
            end

            OPCODE_I_LOAD: begin
                instruction_fmt   = INSTR_FMT_I;
                rf_write_en       = 1'b1;
                rf_write_data_sel = RF_WRITE_MEM_RES;
                alu_op            = ALU_ADD;
                alu_a_sel         = ALU_A_RS1;
                alu_b_sel         = ALU_B_IMM;

                unique0 case (funct_3)
                    3'b000:  memory_op            = MEM_LB;   // LB
                    3'b100:  memory_op            = MEM_LBU;  // LBU
                    3'b001:  memory_op            = MEM_LH;   // LH
                    3'b101:  memory_op            = MEM_LHU;  // LHU
                    3'b010:  memory_op            = MEM_LW;   // LW
                    default: controller_exception = EXCEPT_ILLEGAL_INSTR;
                endcase
            end

            OPCODE_I_ALU: begin
                instruction_fmt   = INSTR_FMT_I;
                rf_write_en       = 1'b1;
                rf_write_data_sel = RF_WRITE_ALU_RES;
                alu_a_sel         = ALU_A_RS1;
                alu_b_sel         = ALU_B_IMM;

                unique0 case (funct_3)
                    3'b000: alu_op = ALU_ADD;   // ADDI
                    3'b111: alu_op = ALU_AND;   // ANDI
                    3'b110: alu_op = ALU_OR;    // ORI
                    3'b100: alu_op = ALU_XOR;   // XORI
                    3'b010: alu_op = ALU_SLT;   // SLTI
                    3'b011: alu_op = ALU_SLTU;  // SLTIU
                    3'b001: begin  // SLLI
                        alu_op = ALU_SLL;
                        if (funct_7 != 7'b0000000)
                            controller_exception = EXCEPT_ILLEGAL_INSTR;
                    end
                    3'b101: begin  // SRLI or SRAI
                        unique0 case (funct_7)
                            7'b0000000: alu_op               = ALU_SRL;  // SRLI
                            7'b0100000: alu_op               = ALU_SRA;  // SRAI
                            default:    controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end
                    default: controller_exception = EXCEPT_ILLEGAL_INSTR;
                endcase
            end

            OPCODE_I_FENCE: begin
                instruction_fmt = INSTR_FMT_I;

                if (funct_3 != 3'b000)
                    controller_exception = EXCEPT_ILLEGAL_INSTR;
            end

            OPCODE_I_ENV: begin
                instruction_fmt = INSTR_FMT_I;

                unique0 case (funct_3)
                    3'b000: begin
                        unique0 case (instruction[31:20])
                            12'b000000000000: controller_exception = EXCEPT_ECALL;  // ECALL
                            12'b000000000001: controller_exception = EXCEPT_EBREAK; // EBREAK
                            default:          controller_exception = EXCEPT_ILLEGAL_INSTR;
                        endcase
                    end

                    default: controller_exception = EXCEPT_ILLEGAL_INSTR;
                endcase
            end
            
            OPCODE_S: begin
                instruction_fmt = INSTR_FMT_S;
                alu_op          = ALU_ADD;
                alu_a_sel       = ALU_A_RS1;
                alu_b_sel       = ALU_B_IMM;

                unique0 case (funct_3)
                    3'b000:  memory_op            = MEM_SB;   // SB
                    3'b001:  memory_op            = MEM_SH;   // SH
                    3'b010:  memory_op            = MEM_SW;   // SW
                    default: controller_exception = EXCEPT_ILLEGAL_INSTR;
                endcase
            end
            
            OPCODE_B: begin
                instruction_fmt = INSTR_FMT_B;
                alu_op          = ALU_ADD;
                alu_a_sel       = ALU_A_PC;
                alu_b_sel       = ALU_B_IMM;
                pc_next_sel     = PC_NEXT_BRANCH;

                unique0 case (funct_3)
                    3'b000:  branch_condition     = BRANCH_IF_EQ;   // BEQ
                    3'b001:  branch_condition     = BRANCH_IF_NE;   // BNE
                    3'b100:  branch_condition     = BRANCH_IF_LT;   // BLT
                    3'b110:  branch_condition     = BRANCH_IF_LTU;  // BLTU
                    3'b101:  branch_condition     = BRANCH_IF_GE;   // BGE
                    3'b111:  branch_condition     = BRANCH_IF_GEU;  // BGEU
                    default: controller_exception = EXCEPT_ILLEGAL_INSTR;
                endcase
            end
            
            OPCODE_J: begin  // JAL
                instruction_fmt   = INSTR_FMT_J;
                rf_write_en       = 1'b1;
                rf_write_data_sel = RF_WRITE_PC_PLUS_4;
                alu_op            = ALU_ADD;
                alu_a_sel         = ALU_A_PC;
                alu_b_sel         = ALU_B_IMM;
                pc_next_sel       = PC_NEXT_JUMP;
            end

            OPCODE_U_AUIPC: begin  // AUIPC
                instruction_fmt   = INSTR_FMT_U;
                rf_write_en       = 1'b1;
                rf_write_data_sel = RF_WRITE_ALU_RES;
                alu_op            = ALU_ADD;
                alu_a_sel         = ALU_A_PC;
                alu_b_sel         = ALU_B_IMM;
            end
            
            OPCODE_U_LUI: begin  // LUI
                instruction_fmt   = INSTR_FMT_U;
                rf_write_en       = 1'b1;
                rf_write_data_sel = RF_WRITE_IMM;
            end

            default: controller_exception = EXCEPT_ILLEGAL_INSTR;
        endcase
    end
endmodule
