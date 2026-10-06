from __future__ import annotations

from pathlib import Path

from tb.bits_32 import Bits32


class DataMemoryModel:
    def __init__(self, depth: int = 256, image_path: str | Path | None = None):
        self.memory: list[list[int | None]] = [[None] * 4 for _ in range(depth)]
        if image_path is not None:
            self._load_image(image_path)

    def _check_address(self, word_addr: int) -> None:
        if not (0 <= word_addr < len(self.memory)):
            raise IndexError("Data memory address out of range.")

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

    def read(self, word_addr: int) -> int | None:
        self._check_address(word_addr)
        if any(byte is None for byte in self.memory[word_addr]):
            return None
        return sum(
            byte << (8 * byte_index)
            for byte_index, byte in enumerate(self.memory[word_addr])
            if byte is not None
        )

    def write(self, word_addr: int, write_data: int, write_strobe: int) -> None:
        self._check_address(word_addr)
        if not 0 <= write_strobe <= 0xF:
            raise ValueError("Write strobe must be a 4-bit value.")

        write_data = Bits32.truncate(write_data).u
        for byte_index in range(4):
            if write_strobe & (1 << byte_index):
                self.memory[word_addr][byte_index] = (write_data >> (8 * byte_index)) & 0xFF
