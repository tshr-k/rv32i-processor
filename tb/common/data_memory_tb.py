import random

import cocotb
from bits_32 import Bits32
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from models.data_memory_model import (
    DataMemoryModel,
    DataMemoryReadInputs,
    DataMemoryWriteInputs,
)


async def write_memory(dut, inputs: DataMemoryWriteInputs) -> None:
    dut.word_addr.value = inputs.word_addr
    dut.write_data.value = inputs.write_data
    dut.write_strobe.value = inputs.write_strobe
    dut.write_en.value = inputs.write_en
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def assert_read_value(dut, model: DataMemoryModel, inputs: DataMemoryReadInputs) -> None:
    dut.word_addr.value = inputs.word_addr
    await Timer(1, unit="ns")

    expected = model.read(inputs)
    if expected.read_data is None:
        # assert not dut.read_data.value.is_resolvable
        assert dut.read_data.value == 0  # Verilator is a two-state simulator
    else:
        assert dut.read_data.value == expected.read_data


@cocotb.test
async def test_data_memory_byte_writes(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start(start_high=False))
    model = DataMemoryModel()

    for word_addr in range(32):
        inputs = DataMemoryWriteInputs(
            word_addr=word_addr, write_data=Bits32.random().u, write_strobe=0xF
        )
        await write_memory(dut, inputs)
        model.write(inputs)

    for _ in range(100):
        inputs = DataMemoryWriteInputs(
            word_addr=random.randrange(32),
            write_data=Bits32.random().u,
            write_strobe=random.randint(1, 0xF),
        )

        await write_memory(dut, inputs)
        model.write(inputs)
        await assert_read_value(dut, model, DataMemoryReadInputs(word_addr=inputs.word_addr))


@cocotb.test
async def test_data_memory_write_enable(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start(start_high=False))
    model = DataMemoryModel()
    word_addr = 0

    for inputs in [
        DataMemoryWriteInputs(word_addr=word_addr, write_data=0x12345678, write_strobe=0xF),
        DataMemoryWriteInputs(
            word_addr=word_addr, write_data=0xDEADBEEF, write_strobe=0xF, write_en=False
        ),
    ]:
        await write_memory(dut, inputs)
        model.write(inputs)

    await assert_read_value(dut, model, DataMemoryReadInputs(word_addr=word_addr))


@cocotb.test
async def test_data_memory_address_wrap(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start(start_high=False))
    model = DataMemoryModel()
    depth = len(model.memory)

    for word_addr in [0, 1, depth - 1]:
        for alias in [word_addr + depth, word_addr + 2 * depth, (1 << 30) - depth + word_addr]:
            # Write through the aliased address, then read back through the in-range one
            inputs = DataMemoryWriteInputs(
                word_addr=alias, write_data=Bits32.random().u, write_strobe=0xF
            )
            await write_memory(dut, inputs)
            model.write(inputs)
            await assert_read_value(dut, model, DataMemoryReadInputs(word_addr=word_addr))
            await assert_read_value(dut, model, DataMemoryReadInputs(word_addr=alias))
