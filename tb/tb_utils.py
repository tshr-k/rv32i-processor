from __future__ import annotations

import random
from dataclasses import dataclass

MASK_32 = 0xFFFFFFFF
SIGN_BIT_32 = 0x80000000


@dataclass(frozen=True, slots=True)
class Bits32:
    """
    A 32-bit bit pattern.

    The stored value is always in the range [0, 0xFFFFFFFF].
    """

    bits: int

    def __post_init__(self) -> None:
        if not (0 <= self.bits <= MASK_32):
            raise ValueError(f"{self.bits:#x} is not a 32-bit value")

    @property
    def u(self) -> int:
        """Unsigned interpretation."""
        return self.bits

    @property
    def s(self) -> int:
        """Signed two's-complement interpretation."""
        if self.bits & SIGN_BIT_32:
            return self.bits - (MASK_32 + 1)
        return self.bits

    @classmethod
    def truncate(cls, value: int) -> Bits32:
        """Truncate any integer to its least significant 32 bits."""
        return cls(value & MASK_32)

    @classmethod
    def from_signed(cls, value: int) -> Bits32:
        """Construct from a signed 32-bit integer. Raises ValueError if the value is out of range."""
        if not (-0x80000000 <= value <= 0x7FFFFFFF):
            raise ValueError(f"{value} is not a signed 32-bit integer")

        return cls(value & MASK_32)

    @classmethod
    def random(cls, *, allow_zero: bool = True) -> Bits32:
        """Generate a random 32-bit pattern."""
        if allow_zero:
            return cls(random.getrandbits(32))

        return cls(random.randint(1, MASK_32))

    def __int__(self) -> int:
        return self.bits

    def __index__(self) -> int:
        return self.bits

    def __hex__(self) -> str:
        return f"0x{self.bits:08X}"

    def __str__(self) -> str:
        return f"0x{self.bits:08X}"

    def __repr__(self) -> str:
        return f"Bits32(0x{self.bits:08X})"
