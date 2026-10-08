import cocotb
from cocotb.triggers import Timer
from models.immediate_decoder_model import (
    ImmediateDecoderInputs,
    ImmediateDecoderModel,
    InstructionFormat,
)

from tb.bits_32 import Bits32


async def test_immediate_format(dut, instruction_fmt: InstructionFormat):
    model = ImmediateDecoderModel()
    for _ in range(100):
        inputs = ImmediateDecoderInputs(
            instruction=Bits32.random().u, instruction_fmt=instruction_fmt
        )

        dut.instruction.value = inputs.instruction
        dut.instruction_fmt.value = inputs.instruction_fmt.value
        await Timer(1, unit="ns")

        expected = model(inputs)
        actual = dut.immediate.value.to_unsigned()
        assert actual == expected.immediate, (
            f"{instruction_fmt.name} failed: {inputs.instruction:#010x}, "
            f"{expected.immediate:#010x} != {actual:#010x}"
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
