from dataclasses import dataclass
from enum import IntEnum

from models.immediate_decoder_model import InstructionFormat

from tb.bits_32 import Bits32


class RfWriteDataSel(IntEnum):
    RF_WRITE_ALU_RES = 0
    RF_WRITE_MEM_RES = 1
    RF_WRITE_PC_PLUS_4 = 2
    RF_WRITE_IMM = 3


class AluOp(IntEnum):
    ALU_ADD = 0
    ALU_SUB = 1
    ALU_AND = 2
    ALU_OR = 3
    ALU_XOR = 4
    ALU_SLL = 5
    ALU_SRL = 6
    ALU_SRA = 7
    ALU_SLT = 8
    ALU_SLTU = 9


class AluASel(IntEnum):
    ALU_A_RS1 = 0
    ALU_A_PC = 1


class AluBSel(IntEnum):
    ALU_B_RS2 = 0
    ALU_B_IMM = 1
    ALU_B_4 = 2


class MemoryOp(IntEnum):
    MEM_LB = 0
    MEM_LBU = 1
    MEM_LH = 2
    MEM_LHU = 3
    MEM_LW = 4
    MEM_SB = 5
    MEM_SH = 6
    MEM_SW = 7
    MEM_NOP = 8


class BranchCondition(IntEnum):
    BRANCH_IF_EQ = 0
    BRANCH_IF_NE = 1
    BRANCH_IF_LT = 2
    BRANCH_IF_LTU = 3
    BRANCH_IF_GE = 4
    BRANCH_IF_GEU = 5


class PcNextSel(IntEnum):
    PC_NEXT_PLUS_4 = 0
    PC_NEXT_BRANCH = 1
    PC_NEXT_JUMP = 2


class Exception(IntEnum):
    EXCEPT_INSTR_ADDR_MISALIGNED = 0
    EXCEPT_ILLEGAL_INSTR = 2
    EXCEPT_LOAD_ADDR_MISALIGNED = 4
    EXCEPT_STORE_ADDR_MISALIGNED = 6
    EXCEPT_ECALL = 11  # Environment call from M-mode
    EXCEPT_EBREAK = 3
    EXCEPT_NONE = 7  # Value is irrelevant


@dataclass(frozen=True)
class ControllerInputs:
    instruction: int


@dataclass(frozen=True)
class ControllerOutputs:
    rf_write_en: bool
    rf_write_data_sel: RfWriteDataSel
    alu_op: AluOp
    alu_a_sel: AluASel
    alu_b_sel: AluBSel
    memory_op: MemoryOp
    instruction_fmt: InstructionFormat
    branch_condition: BranchCondition
    pc_next_sel: PcNextSel
    controller_exception: Exception


class ControllerModel:
    def __call__(self, inputs: ControllerInputs) -> ControllerOutputs:
        instruction = Bits32(inputs.instruction).u
        opcode = instruction & 0x7F
        funct_3 = (instruction >> 12) & 0x7
        funct_7 = (instruction >> 25) & 0x7F

        rf_write_en = False
        rf_write_data_sel = RfWriteDataSel.RF_WRITE_ALU_RES
        alu_op = AluOp.ALU_ADD
        alu_a_sel = AluASel.ALU_A_RS1
        alu_b_sel = AluBSel.ALU_B_RS2
        memory_op = MemoryOp.MEM_NOP
        instruction_fmt = InstructionFormat.INSTR_FMT_R
        branch_condition = BranchCondition.BRANCH_IF_EQ
        pc_next_sel = PcNextSel.PC_NEXT_PLUS_4
        controller_exception = Exception.EXCEPT_NONE

        match opcode:
            case 0b0110011:
                instruction_fmt = InstructionFormat.INSTR_FMT_R
                rf_write_en = True

                r_ops = {
                    (0b000, 0b0000000): AluOp.ALU_ADD,
                    (0b000, 0b0100000): AluOp.ALU_SUB,
                    (0b111, 0b0000000): AluOp.ALU_AND,
                    (0b110, 0b0000000): AluOp.ALU_OR,
                    (0b100, 0b0000000): AluOp.ALU_XOR,
                    (0b001, 0b0000000): AluOp.ALU_SLL,
                    (0b101, 0b0000000): AluOp.ALU_SRL,
                    (0b101, 0b0100000): AluOp.ALU_SRA,
                    (0b010, 0b0000000): AluOp.ALU_SLT,
                    (0b011, 0b0000000): AluOp.ALU_SLTU,
                }
                alu_op = r_ops.get((funct_3, funct_7), alu_op)
                if (funct_3, funct_7) not in r_ops:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

            case 0b1100111:
                instruction_fmt = InstructionFormat.INSTR_FMT_I
                rf_write_en = True
                rf_write_data_sel = RfWriteDataSel.RF_WRITE_PC_PLUS_4
                alu_a_sel = AluASel.ALU_A_RS1
                alu_b_sel = AluBSel.ALU_B_IMM
                pc_next_sel = PcNextSel.PC_NEXT_JUMP
                if funct_3 != 0:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

            case 0b0000011:
                instruction_fmt = InstructionFormat.INSTR_FMT_I
                rf_write_en = True
                rf_write_data_sel = RfWriteDataSel.RF_WRITE_MEM_RES
                alu_a_sel = AluASel.ALU_A_RS1
                alu_b_sel = AluBSel.ALU_B_IMM
                load_ops = {
                    0b000: MemoryOp.MEM_LB,
                    0b100: MemoryOp.MEM_LBU,
                    0b001: MemoryOp.MEM_LH,
                    0b101: MemoryOp.MEM_LHU,
                    0b010: MemoryOp.MEM_LW,
                }
                memory_op = load_ops.get(funct_3, memory_op)
                if funct_3 not in load_ops:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

            case 0b0010011:
                instruction_fmt = InstructionFormat.INSTR_FMT_I
                rf_write_en = True
                rf_write_data_sel = RfWriteDataSel.RF_WRITE_ALU_RES
                alu_a_sel = AluASel.ALU_A_RS1
                alu_b_sel = AluBSel.ALU_B_IMM
                i_ops = {
                    0b000: AluOp.ALU_ADD,
                    0b111: AluOp.ALU_AND,
                    0b110: AluOp.ALU_OR,
                    0b100: AluOp.ALU_XOR,
                    0b010: AluOp.ALU_SLT,
                    0b011: AluOp.ALU_SLTU,
                }
                alu_op = i_ops.get(funct_3, alu_op)
                if funct_3 in (0b001, 0b101):
                    if funct_3 == 0b001:
                        alu_op = AluOp.ALU_SLL
                        if funct_7 != 0:
                            controller_exception = Exception.EXCEPT_ILLEGAL_INSTR
                    elif funct_7 == 0:
                        alu_op = AluOp.ALU_SRL
                    elif funct_7 == 0b0100000:
                        alu_op = AluOp.ALU_SRA
                    else:
                        controller_exception = Exception.EXCEPT_ILLEGAL_INSTR
                elif funct_3 not in i_ops:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

            case 0b0001111:
                instruction_fmt = InstructionFormat.INSTR_FMT_I
                if funct_3 != 0:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

            case 0b1110011:
                instruction_fmt = InstructionFormat.INSTR_FMT_I
                if funct_3 != 0:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR
                elif ((instruction >> 20) & 0xFFF) == 0:
                    controller_exception = Exception.EXCEPT_ECALL
                elif ((instruction >> 20) & 0xFFF) == 1:
                    controller_exception = Exception.EXCEPT_EBREAK
                else:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

            case 0b0100011:
                instruction_fmt = InstructionFormat.INSTR_FMT_S
                alu_a_sel = AluASel.ALU_A_RS1
                alu_b_sel = AluBSel.ALU_B_IMM
                store_ops = {
                    0b000: MemoryOp.MEM_SB,
                    0b001: MemoryOp.MEM_SH,
                    0b010: MemoryOp.MEM_SW,
                }
                memory_op = store_ops.get(funct_3, memory_op)
                if funct_3 not in store_ops:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

            case 0b1100011:
                instruction_fmt = InstructionFormat.INSTR_FMT_B
                alu_a_sel = AluASel.ALU_A_PC
                alu_b_sel = AluBSel.ALU_B_IMM
                pc_next_sel = PcNextSel.PC_NEXT_BRANCH
                branch_ops = {
                    0b000: BranchCondition.BRANCH_IF_EQ,
                    0b001: BranchCondition.BRANCH_IF_NE,
                    0b100: BranchCondition.BRANCH_IF_LT,
                    0b110: BranchCondition.BRANCH_IF_LTU,
                    0b101: BranchCondition.BRANCH_IF_GE,
                    0b111: BranchCondition.BRANCH_IF_GEU,
                }
                branch_condition = branch_ops.get(funct_3, branch_condition)
                if funct_3 not in branch_ops:
                    controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

            case 0b1101111:
                instruction_fmt = InstructionFormat.INSTR_FMT_J
                rf_write_en = True
                rf_write_data_sel = RfWriteDataSel.RF_WRITE_PC_PLUS_4
                alu_a_sel = AluASel.ALU_A_PC
                alu_b_sel = AluBSel.ALU_B_IMM
                pc_next_sel = PcNextSel.PC_NEXT_JUMP

            case 0b0010111:
                instruction_fmt = InstructionFormat.INSTR_FMT_U
                rf_write_en = True
                alu_a_sel = AluASel.ALU_A_PC
                alu_b_sel = AluBSel.ALU_B_IMM

            case 0b0110111:
                instruction_fmt = InstructionFormat.INSTR_FMT_U
                rf_write_en = True
                rf_write_data_sel = RfWriteDataSel.RF_WRITE_IMM

            case _:
                controller_exception = Exception.EXCEPT_ILLEGAL_INSTR

        return ControllerOutputs(
            rf_write_en=rf_write_en,
            rf_write_data_sel=rf_write_data_sel,
            alu_op=alu_op,
            alu_a_sel=alu_a_sel,
            alu_b_sel=alu_b_sel,
            memory_op=memory_op,
            instruction_fmt=instruction_fmt,
            branch_condition=branch_condition,
            pc_next_sel=pc_next_sel,
            controller_exception=controller_exception,
        )
