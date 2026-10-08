from dataclasses import dataclass

from tb.bits_32 import Bits32


@dataclass(frozen=True)
class ComparatorInputs:
    a: int
    b: int


@dataclass(frozen=True)
class ComparatorOutputs:
    eq: bool
    lt: bool
    ltu: bool


class ComparatorModel:
    def __call__(self, inputs: ComparatorInputs) -> ComparatorOutputs:
        a = Bits32(inputs.a)
        b = Bits32(inputs.b)

        return ComparatorOutputs(eq=a.u == b.u, lt=a.s < b.s, ltu=a.u < b.u)
