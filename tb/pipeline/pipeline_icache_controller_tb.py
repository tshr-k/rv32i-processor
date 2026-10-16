import random
from dataclasses import fields

import cocotb
from bits_32 import Bits32
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from models.pipeline_icache_controller_model import (
    PipelineIcacheControllerInputs,
    PipelineIcacheControllerModel,
    PipelineIcacheControllerOutputs,
    PipelineIcacheControllerState,
)


def drive_inputs(dut, inputs: PipelineIcacheControllerInputs) -> None:
    dut.reset.value = inputs.reset
    dut.fetch_addr.value = inputs.fetch_addr
    dut.cache_hit.value = inputs.cache_hit
    dut.cache_lookup_data.value = inputs.cache_lookup_data
    dut.memory_request_ready.value = inputs.memory_request_ready
    dut.memory_response_valid.value = inputs.memory_response_valid
    dut.memory_response_data.value = inputs.memory_response_data


async def step(
    dut, model: PipelineIcacheControllerModel, inputs: PipelineIcacheControllerInputs
) -> PipelineIcacheControllerOutputs:
    """Drives the inputs for one cycle, checks the outputs against the model, then clocks both."""
    drive_inputs(dut, inputs)
    await Timer(1, unit="ns")

    expected = model.evaluate(inputs)
    for field in fields(expected):
        expected_value = getattr(expected, field.name)
        if expected_value is None:  # Don't care
            continue
        actual_value = int(getattr(dut, field.name).value)
        assert actual_value == expected_value, (
            f"{field.name} in {model.state.name}: {inputs}: {expected_value:#x} != {actual_value:#x}"
        )

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    model.clock(inputs)
    return expected


async def start(dut) -> PipelineIcacheControllerModel:
    """Start the clock and reset the DUT, returning a model in the reset state."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start(start_high=False))

    # The outputs are unknown before the reset, so they aren't checked
    drive_inputs(dut, PipelineIcacheControllerInputs(reset=True))
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    return PipelineIcacheControllerModel()


@cocotb.test
async def test_pipeline_icache_controller_hits(dut):
    model = await start(dut)

    for _ in range(20):
        outputs = await step(
            dut,
            model,
            PipelineIcacheControllerInputs(
                fetch_addr=Bits32.random().u,
                cache_hit=True,
                cache_lookup_data=Bits32.random().u,
                memory_request_ready=True,
            ),
        )
        assert outputs.instruction_valid and not outputs.memory_request_valid
        assert model.state == PipelineIcacheControllerState.IDLE


@cocotb.test
async def test_pipeline_icache_controller_miss_refill(dut):
    model = await start(dut)
    fetch_addr = 0x0000_0040
    instruction = 0x0010_0093

    # Miss, then the memory is busy for two cycles before accepting the request
    miss = PipelineIcacheControllerInputs(fetch_addr=fetch_addr)
    assert not (await step(dut, model, miss)).instruction_valid
    for _ in range(2):
        outputs = await step(dut, model, miss)
        assert outputs.memory_request_valid and outputs.memory_request_word_addr == fetch_addr >> 2
    await step(
        dut, model, PipelineIcacheControllerInputs(fetch_addr=fetch_addr, memory_request_ready=True)
    )

    # The memory responds after three cycles, and the response fills the cache
    for _ in range(3):
        outputs = await step(dut, model, miss)
        assert not outputs.instruction_valid and not outputs.cache_fill_en
    outputs = await step(
        dut,
        model,
        PipelineIcacheControllerInputs(
            fetch_addr=fetch_addr, memory_response_valid=True, memory_response_data=instruction
        ),
    )
    assert outputs.cache_fill_en and not outputs.instruction_valid
    assert (outputs.cache_fill_word_addr, outputs.cache_fill_data) == (fetch_addr >> 2, instruction)

    # The retried lookup now hits
    outputs = await step(
        dut,
        model,
        PipelineIcacheControllerInputs(
            fetch_addr=fetch_addr, cache_hit=True, cache_lookup_data=instruction
        ),
    )
    assert outputs.instruction_valid and outputs.instruction == instruction


@cocotb.test
async def test_pipeline_icache_controller_redirect_during_refill(dut):
    model = await start(dut)
    miss_addr = 0x0000_0010
    redirect_addr = 0x0000_0080

    await step(dut, model, PipelineIcacheControllerInputs(fetch_addr=miss_addr))

    # The PC is redirected while the refill is in progress, but the refill keeps the original address
    outputs = await step(
        dut,
        model,
        PipelineIcacheControllerInputs(fetch_addr=redirect_addr, memory_request_ready=True),
    )
    assert outputs.memory_request_word_addr == miss_addr >> 2
    outputs = await step(
        dut,
        model,
        PipelineIcacheControllerInputs(fetch_addr=redirect_addr, memory_response_valid=True),
    )
    assert outputs.cache_fill_en and outputs.cache_fill_word_addr == miss_addr >> 2

    # The redirect target is then looked up, and its own refill starts
    outputs = await step(dut, model, PipelineIcacheControllerInputs(fetch_addr=redirect_addr))
    assert not outputs.instruction_valid
    outputs = await step(dut, model, PipelineIcacheControllerInputs(fetch_addr=redirect_addr))
    assert outputs.memory_request_valid and outputs.memory_request_word_addr == redirect_addr >> 2


@cocotb.test
async def test_pipeline_icache_controller_random(dut):
    model = await start(dut)

    for _ in range(2000):
        await step(
            dut,
            model,
            PipelineIcacheControllerInputs(
                reset=random.random() < 0.02,
                fetch_addr=Bits32.random().u,
                cache_hit=random.random() < 0.5,
                cache_lookup_data=Bits32.random().u,
                memory_request_ready=random.random() < 0.5,
                memory_response_valid=random.random() < 0.3,
                memory_response_data=Bits32.random().u,
            ),
        )
