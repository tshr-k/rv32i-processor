import random

import cocotb
from bits_32 import Bits32
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from models.pipeline_icache_model import (
    PipelineIcacheFillInputs,
    PipelineIcacheLookupInputs,
    PipelineIcacheModel,
)

WORD_ADDR_LIMIT = 1 << 30


async def fill_cache(dut, model: PipelineIcacheModel, inputs: PipelineIcacheFillInputs) -> None:
    dut.reset.value = inputs.reset
    dut.fill_en.value = inputs.fill_en
    dut.fill_word_addr.value = inputs.fill_word_addr
    dut.fill_data.value = inputs.fill_data
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    model.fill(inputs)

    # Return to idle so nothing is written on later clock edges
    dut.reset.value = 0
    dut.fill_en.value = 0


async def assert_lookup(
    dut, model: PipelineIcacheModel, inputs: PipelineIcacheLookupInputs
) -> bool:
    """Returns whether the lookup hit."""
    dut.lookup_word_addr.value = inputs.lookup_word_addr
    await Timer(1, unit="ns")

    expected = model.lookup(inputs)
    assert dut.hit.value == expected.hit, f"{inputs}"
    if expected.hit:
        assert dut.lookup_data.value == expected.lookup_data, f"{inputs}"
    return expected.hit


async def start(dut) -> PipelineIcacheModel:
    """Start the clock and reset the DUT, returning a model in the reset state."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start(start_high=False))
    dut.lookup_word_addr.value = 0

    model = PipelineIcacheModel(num_lines=len(dut.data))
    await fill_cache(dut, model, PipelineIcacheFillInputs(reset=True))
    return model


def random_fill(word_addr: int) -> PipelineIcacheFillInputs:
    return PipelineIcacheFillInputs(
        fill_en=True, fill_word_addr=word_addr, fill_data=Bits32.random().u
    )


@cocotb.test
async def test_pipeline_icache_reset_invalidates(dut):
    model = await start(dut)
    num_lines = len(model.lines)

    for word_addr in range(num_lines):
        assert not await assert_lookup(dut, model, PipelineIcacheLookupInputs(word_addr))
        await fill_cache(dut, model, random_fill(word_addr))
        assert await assert_lookup(dut, model, PipelineIcacheLookupInputs(word_addr))

    await fill_cache(dut, model, PipelineIcacheFillInputs(reset=True))
    for word_addr in range(num_lines):
        assert not await assert_lookup(dut, model, PipelineIcacheLookupInputs(word_addr))


@cocotb.test
async def test_pipeline_icache_conflict_eviction(dut):
    model = await start(dut)
    num_lines = len(model.lines)

    # Same index, different tags, including the highest tag
    for index in [0, num_lines - 1]:
        word_addrs = [index, index + num_lines, WORD_ADDR_LIMIT - num_lines + index]
        for filled_addr in word_addrs:
            await fill_cache(dut, model, random_fill(filled_addr))
            for word_addr in word_addrs:
                hit = await assert_lookup(dut, model, PipelineIcacheLookupInputs(word_addr))
                assert hit == (word_addr == filled_addr)


@cocotb.test
async def test_pipeline_icache_fill_enable(dut):
    model = await start(dut)

    await fill_cache(
        dut, model, PipelineIcacheFillInputs(fill_en=False, fill_word_addr=5, fill_data=1)
    )
    assert not await assert_lookup(dut, model, PipelineIcacheLookupInputs(5))


@cocotb.test
async def test_pipeline_icache_random(dut):
    model = await start(dut)
    num_lines = len(model.lines)

    # A few tags per index, so that lookups hit, miss and evict often
    word_addrs = [
        tag * num_lines + index
        for tag in random.sample(range(WORD_ADDR_LIMIT // num_lines), 3)
        for index in range(num_lines)
    ]

    for _ in range(1000):
        if random.random() < 0.4:
            await fill_cache(dut, model, random_fill(random.choice(word_addrs)))
        await assert_lookup(dut, model, PipelineIcacheLookupInputs(random.choice(word_addrs)))
