from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from tb.bits_32 import Bits32


@dataclass(frozen=True)
class DataMemoryReadInputs:
    word_addr: int


@dataclass(frozen=True)
class DataMemoryWriteInputs:
    word_addr: int
    write_data: int
    write_strobe: int
    write_en: bool = True


@dataclass(frozen=True)
class DataMemoryReadOutputs:
    read_data: int | None


class DataMemoryModel:
    def __init__(self, depth: int = 256, image_path: str | Path | None = None):
        self.memory: list[list[int | None]] = [[None] * 4 for _ in range(depth)]
        if image_path is not None:
            self._load_image(image_path)

    def _wrap_address(self, word_addr: int) -> int:
        if not 0 <= word_addr < (1 << 30):
            raise ValueError("Word address must be a 30-bit value.")
        # Upper address bits are ignored, so out-of-range addresses wrap around
        return word_addr % len(self.memory)

    def _load_image(self, image_path: str | Path) -> None:
        word_addr = 0
        for line in Path(image_path).read_text().splitlines():
            contents = line.split("//", 1)[0].strip()
            if not contents:
                continue
            if word_addr >= len(self.memory):
                break
            value = Bits32(int(contents, 16)).u
            self.memory[word_addr] = [(value >> (8 * byte_index)) & 0xFF for byte_index in range(4)]
            word_addr += 1

    def read(self, inputs: DataMemoryReadInputs) -> DataMemoryReadOutputs:
        word = self.memory[self._wrap_address(inputs.word_addr)]
        if any(byte is None for byte in word):
            return DataMemoryReadOutputs(read_data=None)
        return DataMemoryReadOutputs(
            read_data=sum(
                byte << (8 * byte_index) for byte_index, byte in enumerate(word) if byte is not None
            )
        )

    def write(self, inputs: DataMemoryWriteInputs) -> None:
        word_addr = self._wrap_address(inputs.word_addr)
        if not 0 <= inputs.write_strobe <= 0xF:
            raise ValueError("Write strobe must be a 4-bit value.")
        if not inputs.write_en:
            return

        write_data = Bits32.truncate(inputs.write_data).u
        for byte_index in range(4):
            if inputs.write_strobe & (1 << byte_index):
                self.memory[word_addr][byte_index] = (write_data >> (8 * byte_index)) & 0xFF
