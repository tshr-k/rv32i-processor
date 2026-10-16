from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from tb.bits_32 import Bits32


@dataclass(frozen=True)
class PipelineInstructionMemoryInputs:
    reset: bool = False
    request_valid: bool = False
    request_word_addr: int = 0


@dataclass(frozen=True)
class PipelineInstructionMemoryOutputs:
    request_ready: bool
    response_valid: bool
    # None when response_valid is deasserted (don't care), or the word was never written
    response_data: int | None


class PipelineInstructionMemoryModel:
    def __init__(self, depth: int = 256, latency: int = 4, image_path: str | Path | None = None):
        if latency < 1:
            raise ValueError("Latency must be at least 1.")

        self.memory: list[int | None] = [None] * depth
        self.latency = latency
        self.cycles_remaining = 0  # Zero when idle
        self.pending_word_addr = 0
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

    def evaluate(self) -> PipelineInstructionMemoryOutputs:
        """The outputs depend only on the state, not on the current inputs."""
        response_valid = self.cycles_remaining == 1
        return PipelineInstructionMemoryOutputs(
            request_ready=self.cycles_remaining == 0,
            response_valid=response_valid,
            response_data=(
                self.memory[self._wrap_address(self.pending_word_addr)] if response_valid else None
            ),
        )

    def clock(self, inputs: PipelineInstructionMemoryInputs) -> None:
        """Advances the state by one clock edge."""
        self._wrap_address(inputs.request_word_addr)  # Range check only

        if inputs.reset:
            self.cycles_remaining = 0
        elif inputs.request_valid and self.cycles_remaining == 0:  # Request accepted
            self.cycles_remaining = self.latency
            self.pending_word_addr = inputs.request_word_addr
        elif self.cycles_remaining != 0:
            self.cycles_remaining -= 1
