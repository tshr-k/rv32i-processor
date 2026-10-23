from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from tb.bits_32 import Bits32


@dataclass(frozen=True)
class SingleCycleInstructionMemoryInputs:
    word_addr: int


@dataclass(frozen=True)
class SingleCycleInstructionMemoryOutputs:
    instruction: int | None


class SingleCycleInstructionMemoryModel:
    def __init__(self, depth: int = 256, image_path: str | Path | None = None):
        self.memory: list[int | None] = [None] * depth
        if image_path is not None:
            self._load_image(image_path)

    def _load_image(self, image_path: str | Path) -> None:
        word_addr = 0
        for line in Path(image_path).read_text().splitlines():
            contents = line.split("//", 1)[0].strip()
            if not contents:
                continue
            if word_addr >= len(self.memory):
                break
            self.memory[word_addr] = Bits32(int(contents, 16)).u
            word_addr += 1

    def _wrap_address(self, word_addr: int) -> int:
        if not 0 <= word_addr < (1 << 30):
            raise ValueError("Word address must be a 30-bit value.")
        # Upper address bits are ignored, so out-of-range addresses wrap around
        return word_addr % len(self.memory)

    def read(
        self, inputs: SingleCycleInstructionMemoryInputs
    ) -> SingleCycleInstructionMemoryOutputs:
        return SingleCycleInstructionMemoryOutputs(
            instruction=self.memory[self._wrap_address(inputs.word_addr)]
        )
