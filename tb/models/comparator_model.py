from dataclasses import dataclass

from tb.bits_32 import Bits32


@dataclass(frozen=True)
class ComparatorOutputs:
    eq: bool
    lt: bool
    ltu: bool


class ComparatorModel:
    def __call__(self, a_bits: int, b_bits: int) -> ComparatorOutputs:
        a = Bits32(a_bits)
        b = Bits32(b_bits)

        return ComparatorOutputs(eq=a.u == b.u, lt=a.s < b.s, ltu=a.u < b.u)
