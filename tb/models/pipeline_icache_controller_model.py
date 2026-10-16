from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, auto

from tb.bits_32 import Bits32


class PipelineIcacheControllerState(Enum):
    IDLE = auto()  # Looking up fetch_addr in the cache
    REQUEST = auto()  # Waiting for the memory to accept the refill request
    WAIT_RESPONSE = auto()  # Waiting for the memory to respond with the refill data


@dataclass(frozen=True)
class PipelineIcacheControllerInputs:
    reset: bool = False
    fetch_addr: int = 0
    cache_hit: bool = False
    cache_lookup_data: int = 0
    memory_request_ready: bool = False
    memory_response_valid: bool = False
    memory_response_data: int = 0


@dataclass(frozen=True)
class PipelineIcacheControllerOutputs:
    # None marks a don't-care value, when the corresponding valid/enable signal is deasserted
    instruction: int | None
    instruction_valid: bool
    cache_lookup_word_addr: int
    cache_fill_en: bool
    cache_fill_word_addr: int | None
    cache_fill_data: int | None
    memory_request_valid: bool
    memory_request_word_addr: int | None


class PipelineIcacheControllerModel:
    def __init__(self):
        self.state = PipelineIcacheControllerState.IDLE
        self.miss_word_addr = 0

    def evaluate(self, inputs: PipelineIcacheControllerInputs) -> PipelineIcacheControllerOutputs:
        """The outputs for the current state and inputs, before the next clock edge."""
        fetch_addr = Bits32(inputs.fetch_addr).u

        instruction_valid = self.state == PipelineIcacheControllerState.IDLE and inputs.cache_hit
        memory_request_valid = self.state == PipelineIcacheControllerState.REQUEST
        cache_fill_en = (
            self.state == PipelineIcacheControllerState.WAIT_RESPONSE
            and inputs.memory_response_valid
        )

        return PipelineIcacheControllerOutputs(
            instruction=Bits32(inputs.cache_lookup_data).u if instruction_valid else None,
            instruction_valid=instruction_valid,
            cache_lookup_word_addr=fetch_addr >> 2,
            cache_fill_en=cache_fill_en,
            cache_fill_word_addr=self.miss_word_addr if cache_fill_en else None,
            cache_fill_data=Bits32(inputs.memory_response_data).u if cache_fill_en else None,
            memory_request_valid=memory_request_valid,
            memory_request_word_addr=self.miss_word_addr if memory_request_valid else None,
        )

    def clock(self, inputs: PipelineIcacheControllerInputs) -> None:
        """Advances the state by one clock edge."""
        if inputs.reset:
            self.state = PipelineIcacheControllerState.IDLE
            return

        match self.state:
            case PipelineIcacheControllerState.IDLE:
                if not inputs.cache_hit:
                    self.state = PipelineIcacheControllerState.REQUEST
                    self.miss_word_addr = Bits32(inputs.fetch_addr).u >> 2
            case PipelineIcacheControllerState.REQUEST:
                if inputs.memory_request_ready:
                    self.state = PipelineIcacheControllerState.WAIT_RESPONSE
            case PipelineIcacheControllerState.WAIT_RESPONSE:
                if inputs.memory_response_valid:
                    self.state = PipelineIcacheControllerState.IDLE
