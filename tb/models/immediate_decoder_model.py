from enum import IntEnum

from tb.tb_utils import Bits32


class InstructionFormat(IntEnum):
    INSTR_FMT_R = 0
    INSTR_FMT_I = 1
    INSTR_FMT_S = 2
    INSTR_FMT_B = 3
    INSTR_FMT_J = 4
    INSTR_FMT_U = 5


class ImmediateDecoderModel:
    def __call__(self, instruction_bits: int, instruction_fmt: InstructionFormat) -> int:
        instruction = Bits32(instruction_bits).u
        sign = (instruction >> 31) & 1

        match instruction_fmt:
            case InstructionFormat.INSTR_FMT_R:
                immediate = 0
            case InstructionFormat.INSTR_FMT_I:
                immediate = (sign * 0xFFFFF000) | ((instruction >> 20) & 0xFFF)
            case InstructionFormat.INSTR_FMT_S:
                immediate = (
                    (sign * 0xFFFFF000)
                    | (((instruction >> 25) & 0x7F) << 5)
                    | ((instruction >> 7) & 0x1F)
                )
            case InstructionFormat.INSTR_FMT_B:
                immediate = (
                    (sign * 0xFFFFE000)
                    | (sign << 12)
                    | (((instruction >> 7) & 1) << 11)
                    | (((instruction >> 25) & 0x3F) << 5)
                    | (((instruction >> 8) & 0xF) << 1)
                )
            case InstructionFormat.INSTR_FMT_J:
                immediate = (
                    (sign * 0xFFE00000)
                    | (sign << 20)
                    | (((instruction >> 12) & 0xFF) << 12)
                    | (((instruction >> 20) & 1) << 11)
                    | (((instruction >> 21) & 0x3FF) << 1)
                )
            case InstructionFormat.INSTR_FMT_U:
                immediate = instruction & 0xFFFFF000
            case _:
                raise ValueError(f"Unsupported instruction format: {instruction_fmt}")

        return Bits32.truncate(immediate).u
