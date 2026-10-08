import cocotb
from cocotb.triggers import Timer
from models.alu_model import AluInputs, AluModel, AluOp

from tb.bits_32 import Bits32


async def test_alu_op(dut, op: AluOp) -> None:
    model = AluModel()
    for _ in range(100):
        inputs = AluInputs(a=Bits32.random().u, b=Bits32.random().u, op=op)

        dut.a.value = inputs.a
        dut.b.value = inputs.b
        dut.op.value = inputs.op.value
        await Timer(1, unit="ns")

        expected = model(inputs)
        actual = dut.result.value.to_unsigned()
        assert actual == expected.result, (
            f"{op.name} failed: {inputs.a:#010x}, {inputs.b:#010x} != {actual:#010x}"
        )


@cocotb.test
async def test_alu_add(dut):
    await test_alu_op(dut, AluOp.ALU_ADD)


@cocotb.test
async def test_alu_sub(dut):
    await test_alu_op(dut, AluOp.ALU_SUB)


@cocotb.test
async def test_alu_and(dut):
    await test_alu_op(dut, AluOp.ALU_AND)


@cocotb.test
async def test_alu_or(dut):
    await test_alu_op(dut, AluOp.ALU_OR)


@cocotb.test
async def test_alu_xor(dut):
    await test_alu_op(dut, AluOp.ALU_XOR)


@cocotb.test
async def test_alu_sll(dut):
    await test_alu_op(dut, AluOp.ALU_SLL)


@cocotb.test
async def test_alu_srl(dut):
    await test_alu_op(dut, AluOp.ALU_SRL)


@cocotb.test
async def test_alu_sra(dut):
    await test_alu_op(dut, AluOp.ALU_SRA)


@cocotb.test
async def test_alu_slt(dut):
    await test_alu_op(dut, AluOp.ALU_SLT)


@cocotb.test
async def test_alu_sltu(dut):
    await test_alu_op(dut, AluOp.ALU_SLTU)
