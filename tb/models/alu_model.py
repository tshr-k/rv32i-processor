from dataclasses import dataclass
from enum import IntEnum

from tb.tb_utils import Bits32


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


@dataclass(frozen=True)
class AluOutputs:
    result: int
    eq: bool
    lt: bool
    ltu: bool


class AluModel:
    def __call__(self, a_bits: int, b_bits: int, op: AluOp) -> AluOutputs:
        a = Bits32(a_bits)
        b = Bits32(b_bits)

        eq = a.s == b.s
        lt = a.s < b.s
        ltu = a.u < b.u

        shift_amount = b.u & 0x1F  # Only consider the lower 5 bits for shifts

        match op:
            case AluOp.ALU_ADD:
                result = Bits32.truncate(a.s + b.s)
            case AluOp.ALU_SUB:
                result = Bits32.truncate(a.s - b.s)
            case AluOp.ALU_AND:
                result = Bits32(a.u & b.u)
            case AluOp.ALU_OR:
                result = Bits32(a.u | b.u)
            case AluOp.ALU_XOR:
                result = Bits32(a.u ^ b.u)
            case AluOp.ALU_SLL:
                result = Bits32.truncate(a.u << shift_amount)
            case AluOp.ALU_SRL:
                result = Bits32(a.u >> shift_amount)
            case AluOp.ALU_SRA:
                result = Bits32.truncate(a.s >> shift_amount)
            case AluOp.ALU_SLT:
                result = Bits32(1) if a.s < b.s else Bits32(0)
            case AluOp.ALU_SLTU:
                result = Bits32(1) if a.u < b.u else Bits32(0)
            case _:
                raise ValueError(f"Unsupported ALU operation: {op}")

        return AluOutputs(result=result.u, eq=eq, lt=lt, ltu=ltu)
