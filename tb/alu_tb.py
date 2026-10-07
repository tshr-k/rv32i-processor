import cocotb
from cocotb.triggers import Timer
from models.alu_model import AluModel, AluOp

from tb.bits_32 import Bits32


async def test_alu_op(dut, op: AluOp) -> None:
    model = AluModel()
    for _ in range(100):
        a = Bits32.random().u
        b = Bits32.random().u

        dut.a.value = a
        dut.b.value = b
        dut.op.value = op.value
        await Timer(1, unit="ns")

        expected_result = model(a, b, op).result
        assert dut.result.value.to_unsigned() == expected_result, (
            f"{op.name} failed: {a:#010x}, {b:#010x} != {dut.result.value.to_unsigned():#010x}"
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
