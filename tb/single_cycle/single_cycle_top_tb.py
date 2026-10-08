from enum import Enum, auto
from pathlib import Path

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
                formatted_value = f"{int(value)}"

        cocotb.log.info(f"x{i}:\t{formatted_value}")


def load_instruction_memory(u_instruction_memory, image_path: Path = Path("hex/instr/default.hex")):
    current_index = 0
    with open(image_path) as image:
        for line in image:
            line = line.split("//")[0].strip()
            if not line:
                continue

            u_instruction_memory.instructions[current_index].value = int(line, 16)
            current_index += 1


@cocotb.test
async def test_execution(top):
    cocotb.start_soon(Clock(top.clk, 10, unit="ns").start())

    load_instruction_memory(top.u_instruction_memory, Path("hex/instr/other.hex"))

    await reset(top)

    for _ in range(40):
        await RisingEdge(top.clk)

    register_file = top.u_core.u_datapath.u_register_file
    log_register_file(register_file)

    registers = register_file.registers
    assert registers[0].value == 0
    assert registers[1].value == 0  # Loop counter ran down to zero
    assert registers[2].value == 15  # 5 + 4 + 3 + 2 + 1
    assert registers[3].value == 0x12345678  # lui + ori
    assert registers[4].value == 0xFFFFFFF1  # -15
    assert registers[5].value == 0xFFFFFFFC  # -15 >>> 2 = -4
    assert registers[6].value == 240  # 15 << 4
    assert registers[7].value == 0x78  # Low byte of 0x12345678
    assert registers[8].value == 0x1234  # Upper half of 0x12345678
    assert registers[9].value == 0x38  # Return address of jal
    assert registers[10].value == 0  # Skipped by jal

    for i in range(11, 32):
        assert registers[i].value == 0  # Uninitialized, but Verilator is a two-state simulator

    assert top.u_data_memory.data[1].value == 0x12345678
