import random

import cocotb
from bits_32 import Bits32
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from models.register_file_model import RegisterFileModel


async def write_register(dut, index: int, value: int, en: bool = True) -> None:
    dut.write_addr.value = index
    dut.write_data.value = value
    dut.write_en.value = en
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def assert_read_values(
    dut,
    model: RegisterFileModel,
    read_index_1: int,
    read_index_2: int,
) -> None:
    dut.read_addr_1.value = read_index_1
    dut.read_addr_2.value = read_index_2
    await Timer(1, unit="ns")
    expected_result = model.read(read_index_1, read_index_2)
    if expected_result.read_value_1 is None:
        # assert not dut.read_data_1.value.is_resolvable
        assert dut.read_data_1.value == 0  # Verilator is a two-state simulator
    else:
        assert dut.read_data_1.value == expected_result.read_value_1

    if expected_result.read_value_2 is None:
        # assert not dut.read_data_2.value.is_resolvable
        assert dut.read_data_2.value == 0  # Verilator is a two-state simulator

    else:
        assert dut.read_data_2.value == expected_result.read_value_2


@cocotb.test
async def test_rf_read_write(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    model = RegisterFileModel()

    for _ in range(100):
        read_index_1 = random.randint(0, 31)
        read_index_2 = random.randint(0, 31)

        await assert_read_values(dut, model, read_index_1, read_index_2)

        write_index = random.randint(0, 31)
        write_value = Bits32.random().u
        write_en = random.choice([True, False])
        await write_register(dut, write_index, write_value, write_en)
        model.write(write_index, write_value, write_en)

        await assert_read_values(dut, model, read_index_1, read_index_2)
