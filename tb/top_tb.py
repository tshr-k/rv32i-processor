from enum import Enum, auto

import cocotb
from bits_32 import Bits32
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset(top) -> None:
    top.reset.value = 1
    for _ in range(3):
        await RisingEdge(top.clk)

    top.reset.value = 0
    await Timer(1, unit="ns")


class ValueFormat(Enum):
    BIN = auto()
    HEX = auto()
    INT = auto()


def log_register_file(u_register_file, value_format: ValueFormat = ValueFormat.HEX) -> None:
    registers = u_register_file.registers
    for i in range(32):
        value = registers[i].value

        match value_format:
            case ValueFormat.BIN:
                formatted_value = f"0b{value}"
            case ValueFormat.HEX:
                formatted_value = f"0x{value:X}"
            case ValueFormat.INT:
                formatted_value = f"{value.integer}"

        cocotb.log.info(f"x{i}:\t{formatted_value}")


@cocotb.test
async def test_execution(top):
    cocotb.start_soon(Clock(top.clk, 10, unit="ns").start())

    await reset(top)

    for _ in range(20):
        await RisingEdge(top.clk)

    register_file = top.u_core.u_datapath.u_register_file
    log_register_file(register_file)

    registers = register_file.registers
    assert registers[0].value == 0
    assert registers[1].value == 1
    assert registers[2].value == 3
    assert registers[3].value == 3

    for i in range(4, 32):
        assert registers[i].value == 0  # Uninitialized, but Verilator is a two-state simulator
