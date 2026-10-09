from enum import Enum, auto
from pathlib import Path

import cocotb
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


def clear_register_file(u_register_file) -> None:
    """Keeps results from an earlier test in the same simulation from masking a failure."""
    for i in range(32):
        u_register_file.registers[i].value = 0

