import random

import cocotb
from bits_32 import Bits32
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from models.data_memory_model import DataMemoryModel


async def write_memory(dut, word_addr: int, write_data: int, write_strobe: int) -> None:
    dut.word_addr.value = word_addr
    dut.write_data.value = write_data
    dut.write_strobe.value = write_strobe
    dut.write_en.value = True
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def assert_read_value(dut, model: DataMemoryModel, word_addr: int) -> None:
    dut.word_addr.value = word_addr
    await Timer(1, unit="ns")

    expected = model.read(word_addr)
    if expected is None:
        # assert not dut.read_data.value.is_resolvable
        assert dut.read_data.value == 0  # Verilator is a two-state simulator
    else:
        assert dut.read_data.value.to_unsigned() == expected


@cocotb.test
async def test_data_memory_byte_writes(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    model = DataMemoryModel()

    for word_addr in range(32):
        write_data = Bits32.random().u
        await write_memory(dut, word_addr, write_data, 0xF)
        model.write(word_addr, write_data, 0xF)

    for _ in range(100):
        word_addr = random.randrange(32)
        write_data = Bits32.random().u
        write_strobe = random.randint(1, 0xF)

        await write_memory(dut, word_addr, write_data, write_strobe)
        model.write(word_addr, write_data, write_strobe)
        await assert_read_value(dut, model, word_addr)


@cocotb.test
async def test_data_memory_write_enable(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    model = DataMemoryModel()
    word_addr = 0
    initial_value = 0x12345678

    await write_memory(dut, word_addr, initial_value, 0xF)
    model.write(word_addr, initial_value, 0xF)

    dut.word_addr.value = word_addr
    dut.write_data.value = 0xDEADBEEF
    dut.write_strobe.value = 0xF
    dut.write_en.value = False
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    await assert_read_value(dut, model, word_addr)
