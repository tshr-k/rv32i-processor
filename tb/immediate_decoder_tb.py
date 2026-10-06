import cocotb
from cocotb.triggers import Timer
from models.immediate_decoder_model import (
    ImmediateDecoderModel,
    InstructionFormat,
)
from tb_utils import Bits32


async def test_immediate_format(dut, instruction_fmt: InstructionFormat):
    model = ImmediateDecoderModel()
    for _ in range(100):
        instruction = Bits32.random().u

        dut.instruction.value = instruction
        dut.instruction_fmt.value = instruction_fmt.value
        await Timer(1, unit="ns")

        expected_immediate = model(instruction, instruction_fmt)
        assert dut.immediate.value.to_unsigned() == expected_immediate, (
            f"{instruction_fmt.name} failed: {instruction:#010x}, "
            f"{expected_immediate:#010x} != {dut.immediate.value.to_unsigned():#010x}"
        )


@cocotb.test
async def test_immediate_r(dut):
    await test_immediate_format(dut, InstructionFormat.INSTR_FMT_R)


@cocotb.test
async def test_immediate_i(dut):
    await test_immediate_format(dut, InstructionFormat.INSTR_FMT_I)


@cocotb.test
async def test_immediate_s(dut):
    await test_immediate_format(dut, InstructionFormat.INSTR_FMT_S)


@cocotb.test
async def test_immediate_b(dut):
    await test_immediate_format(dut, InstructionFormat.INSTR_FMT_B)


@cocotb.test
async def test_immediate_j(dut):
    await test_immediate_format(dut, InstructionFormat.INSTR_FMT_J)


@cocotb.test
async def test_immediate_u(dut):
    await test_immediate_format(dut, InstructionFormat.INSTR_FMT_U)
