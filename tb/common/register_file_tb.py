import random

import cocotb
from bits_32 import Bits32
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from models.register_file_model import (
    RegisterFileModel,
    RegisterFileReadInputs,
    RegisterFileWriteInputs,
)


def drive_write(dut, inputs: RegisterFileWriteInputs) -> None:
    dut.write_addr.value = inputs.write_addr
    dut.write_data.value = inputs.write_data
    dut.write_en.value = inputs.write_en


async def assert_read_values(
    dut,
    model: RegisterFileModel,
    inputs: RegisterFileReadInputs,
    pending_write: RegisterFileWriteInputs,
) -> None:
    dut.read_addr_1.value = inputs.read_addr_1
    dut.read_addr_2.value = inputs.read_addr_2
    await Timer(1, unit="ns")
    expected = model.read(inputs, pending_write)
    if expected.read_data_1 is None:
        # assert not dut.read_data_1.value.is_resolvable
        assert dut.read_data_1.value == 0  # Verilator is a two-state simulator
    else:
        assert dut.read_data_1.value == expected.read_data_1

    if expected.read_data_2 is None:
        # assert not dut.read_data_2.value.is_resolvable
        assert dut.read_data_2.value == 0  # Verilator is a two-state simulator

    else:
        assert dut.read_data_2.value == expected.read_data_2


@cocotb.test
async def test_rf_read_write(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    model = RegisterFileModel(write_through=bool(dut.WRITE_THROUGH.value))

    for _ in range(200):
        read_inputs = RegisterFileReadInputs(
            read_addr_1=random.randint(0, 31),
            read_addr_2=random.randint(0, 31),
        )

        # Bias the write address towards the read addresses to exercise the bypass
        write_inputs = RegisterFileWriteInputs(
            write_addr=random.choice(
                [read_inputs.read_addr_1, read_inputs.read_addr_2, random.randint(0, 31)]
            ),
            write_data=Bits32.random().u,
            write_en=random.choice([True, False]),
        )

        # Before clock edge, expect the old register value, or the write data if bypassing
        drive_write(dut, write_inputs)
        await assert_read_values(dut, model, read_inputs, write_inputs)

        # After clock edge, with the same write still being driven
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        model.write(write_inputs)
        await assert_read_values(dut, model, read_inputs, write_inputs)
