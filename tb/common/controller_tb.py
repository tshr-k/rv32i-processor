import random

import cocotb
from cocotb.triggers import Timer
from models.controller_model import ControllerInputs, ControllerModel

from tb.bits_32 import Bits32


async def test_controller_instruction(dut, instruction: int) -> None:
    model = ControllerModel()
    inputs = ControllerInputs(instruction=instruction)

    dut.instruction.value = inputs.instruction
    await Timer(1, unit="ns")

    expected = model(inputs)
    actual = {
        "rf_write_en": bool(int(dut.rf_write_en.value)),
        "rf_write_data_sel": int(dut.rf_write_data_sel.value),
        "alu_op": int(dut.alu_op.value),
        "alu_a_sel": int(dut.alu_a_sel.value),
        "alu_b_sel": int(dut.alu_b_sel.value),
        "memory_op": int(dut.memory_op.value),
        "instruction_fmt": int(dut.instruction_fmt.value),
        "branch_condition": int(dut.branch_condition.value),
        "pc_next_sel": int(dut.pc_next_sel.value),
        "mret_en": bool(int(dut.mret_en.value)),
        "controller_exception": int(dut.controller_exception.value),
    }

    assert actual == {
        "rf_write_en": expected.rf_write_en,
        "rf_write_data_sel": expected.rf_write_data_sel.value,
        "alu_op": expected.alu_op.value,
        "alu_a_sel": expected.alu_a_sel.value,
        "alu_b_sel": expected.alu_b_sel.value,
        "memory_op": expected.memory_op.value,
        "instruction_fmt": expected.instruction_fmt.value,
        "branch_condition": expected.branch_condition.value,
        "pc_next_sel": expected.pc_next_sel.value,
        "mret_en": expected.mret_en,
        "controller_exception": expected.controller_exception.value,
    }, f"{instruction:#010x}: {expected} != {actual}"


def form_instruction(opcode: int, funct_3: int = 0, funct_7: int = 0, immediate: int = 0) -> int:
    return (
        ((immediate & 0xFFF) << 20)
        | ((funct_7 & 0x7F) << 25)
        | ((funct_3 & 0x7) << 12)
        | (opcode & 0x7F)
    )


@cocotb.test
async def test_controller_valid_instructions(dut):
    instructions = [
        form_instruction(0b0110011, funct_3, funct_7)
        for funct_3, funct_7 in [
            (0b000, 0b0000000),
            (0b000, 0b0100000),
            (0b111, 0),
            (0b110, 0),
            (0b100, 0),
            (0b001, 0),
            (0b101, 0),
            (0b101, 0b0100000),
            (0b010, 0),
            (0b011, 0),
        ]
    ]
    instructions += [
        form_instruction(opcode, funct_3, funct_7, random.getrandbits(12))
        for opcode, funct_3, funct_7 in [
            (0b1100111, 0, 0),
            (0b0000011, 0, 0),
            (0b0000011, 1, 0),
            (0b0000011, 2, 0),
            (0b0000011, 4, 0),
            (0b0000011, 5, 0),
            (0b0010011, 0, 0),
            (0b0010011, 1, 0),
            (0b0010011, 2, 0),
            (0b0010011, 3, 0),
            (0b0010011, 4, 0),
            (0b0010011, 5, 0),
            (0b0010011, 5, 0b0100000),
            (0b0010011, 6, 0),
            (0b0010011, 7, 0),
            (0b0001111, 0, 0),
            (0b1110011, 0, 0),
            (0b1110011, 0, 1),
            (0b0100011, 0, 0),
            (0b0100011, 1, 0),
            (0b0100011, 2, 0),
            (0b1100011, 0, 0),
            (0b1100011, 1, 0),
            (0b1100011, 4, 0),
            (0b1100011, 5, 0),
            (0b1100011, 6, 0),
            (0b1100011, 7, 0),
            (0b1101111, 0, 0),
            (0b0010111, 0, 0),
            (0b0110111, 0, 0),
        ]
    ]

    instructions += [
        0x00000073,  # ECALL
        0x00100073,  # EBREAK
        0x30200073,  # MRET
    ]

    for instruction in instructions:
        await test_controller_instruction(dut, instruction)


@cocotb.test
async def test_controller_illegal_instructions(dut):
    instructions = [
        Bits32.random().u & ~0x7F | opcode
        for opcode in [0, 0b0110011, 0b0000011, 0b0010011, 0b0100011, 0b1100011]
    ]
    for instruction in instructions:
        await test_controller_instruction(dut, instruction)
