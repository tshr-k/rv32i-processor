from __future__ import annotations

from pathlib import Path

from tb.bits_32 import Bits32


class InstructionMemoryModel:
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

    def read(self, addr: int) -> int | None:
        if not (0 <= addr < len(self.memory)):
            raise IndexError("Instruction memory address out of range.")
        return self.memory[addr >> 2]
