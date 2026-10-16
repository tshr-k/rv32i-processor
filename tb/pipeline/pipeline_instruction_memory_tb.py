import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from models.pipeline_instruction_memory_model import (
    PipelineInstructionMemoryInputs,
    PipelineInstructionMemoryModel,
    PipelineInstructionMemoryOutputs,
)

IMAGE_PATH = Path("hex/instr/default.hex")
WORD_ADDR_LIMIT = 1 << 30


def drive_inputs(dut, inputs: PipelineInstructionMemoryInputs) -> None:
    dut.reset.value = inputs.reset
    dut.request_valid.value = inputs.request_valid
    dut.request_word_addr.value = inputs.request_word_addr


async def step(
    dut, model: PipelineInstructionMemoryModel, inputs: PipelineInstructionMemoryInputs
) -> PipelineInstructionMemoryOutputs:
    """Drives the inputs for one cycle, checks the outputs against the model, then clocks both."""
    drive_inputs(dut, inputs)
    await Timer(1, unit="ns")

    expected = model.evaluate()
    assert dut.request_ready.value == expected.request_ready
    assert dut.response_valid.value == expected.response_valid
    if expected.response_valid:
        if expected.response_data is None:
            # assert not dut.response_data.value.is_resolvable
            assert dut.response_data.value == 0  # Verilator is a two-state simulator
        else:
            assert dut.response_data.value == expected.response_data

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    model.clock(inputs)
    return expected


async def start(dut) -> PipelineInstructionMemoryModel:
    """Start the clock and reset the DUT, returning a model in the reset state."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start(start_high=False))

    model = PipelineInstructionMemoryModel(
        depth=len(dut.instructions), latency=int(dut.LATENCY.value), image_path=IMAGE_PATH
    )

    # The outputs are unknown before the reset, so they aren't checked
    drive_inputs(dut, PipelineInstructionMemoryInputs(reset=True))
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    model.clock(PipelineInstructionMemoryInputs(reset=True))
    return model


@cocotb.test
async def test_pipeline_instruction_memory_latency(dut):
    model = await start(dut)
    depth = len(model.memory)

    wrapped_word_addrs = [depth, depth + 1, 2 * depth - 1, WORD_ADDR_LIMIT - 1]
    for word_addr in [*range(depth), *wrapped_word_addrs]:
        outputs = await step(
            dut,
            model,
            PipelineInstructionMemoryInputs(request_valid=True, request_word_addr=word_addr),
        )
        assert outputs.request_ready

        # The response arrives exactly LATENCY cycles after the request was accepted
        for cycle in range(1, model.latency + 1):
            outputs = await step(dut, model, PipelineInstructionMemoryInputs())
            assert outputs.response_valid == (cycle == model.latency)
            assert not outputs.request_ready  # Busy until the cycle after the response


@cocotb.test
async def test_pipeline_instruction_memory_reset_cancels_request(dut):
    model = await start(dut)

    await step(dut, model, PipelineInstructionMemoryInputs(request_valid=True, request_word_addr=1))
    await step(dut, model, PipelineInstructionMemoryInputs(reset=True))
    for _ in range(model.latency + 1):
        outputs = await step(dut, model, PipelineInstructionMemoryInputs())
        assert outputs.request_ready and not outputs.response_valid


@cocotb.test
async def test_pipeline_instruction_memory_random(dut):
    model = await start(dut)
    depth = len(model.memory)

    for _ in range(2000):
        await step(
            dut,
            model,
            PipelineInstructionMemoryInputs(
                reset=random.random() < 0.02,
                request_valid=random.random() < 0.5,
                request_word_addr=random.choice(
                    [random.randrange(depth), random.randrange(WORD_ADDR_LIMIT)]
                ),
            ),
        )
