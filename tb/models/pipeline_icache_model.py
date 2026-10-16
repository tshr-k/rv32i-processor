from __future__ import annotations

from dataclasses import dataclass

from tb.bits_32 import Bits32


@dataclass(frozen=True)
class PipelineIcacheLookupInputs:
    lookup_word_addr: int


@dataclass(frozen=True)
class PipelineIcacheFillInputs:
    reset: bool = False
    fill_en: bool = False
    fill_word_addr: int = 0
    fill_data: int = 0


@dataclass(frozen=True)
class PipelineIcacheLookupOutputs:
    hit: bool
    lookup_data: int | None  # None on a miss (don't care)


@dataclass(frozen=True)
class PipelineIcacheLine:
    tag: int
    data: int


class PipelineIcacheModel:
    def __init__(self, num_lines: int = 16):
        if num_lines < 2 or num_lines & (num_lines - 1):
            raise ValueError("Number of lines must be a power of 2 and at least 2.")

        self.lines: list[PipelineIcacheLine | None] = [None] * num_lines  # None if invalid

    def _split_address(self, word_addr: int) -> tuple[int, int]:
        """Returns the (tag, index) of a word address."""
        if not 0 <= word_addr < (1 << 30):
            raise ValueError("Word address must be a 30-bit value.")
        return divmod(word_addr, len(self.lines))

    def lookup(self, inputs: PipelineIcacheLookupInputs) -> PipelineIcacheLookupOutputs:
        tag, index = self._split_address(inputs.lookup_word_addr)
        line = self.lines[index]
        if line is None or line.tag != tag:
            return PipelineIcacheLookupOutputs(hit=False, lookup_data=None)
        return PipelineIcacheLookupOutputs(hit=True, lookup_data=line.data)

    def fill(self, inputs: PipelineIcacheFillInputs) -> None:
        tag, index = self._split_address(inputs.fill_word_addr)

        # Reset has priority over a fill
        if inputs.reset:
            self.lines = [None] * len(self.lines)
        elif inputs.fill_en:
            self.lines[index] = PipelineIcacheLine(tag=tag, data=Bits32(inputs.fill_data).u)
