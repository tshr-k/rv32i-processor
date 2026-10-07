import cocotb
from cocotb.triggers import Timer
from models.comparator_model import ComparatorModel

from tb.bits_32 import Bits32


async def check_comparison(dut, model: ComparatorModel, a: int, b: int) -> None:
    dut.a.value = a
    dut.b.value = b
    await Timer(1, unit="ns")

    expected = model(a, b)

    assert dut.eq.value == expected.eq, f"EQ failed: {a:#010x}, {b:#010x} != {dut.eq.value}"

    assert dut.lt.value == expected.lt, f"LT failed: {a:#010x}, {b:#010x} != {dut.lt.value}"

    assert dut.ltu.value == expected.ltu, f"LTU failed: {a:#010x}, {b:#010x} != {dut.ltu.value}"


@cocotb.test
async def test_comparator_random(dut):
    model = ComparatorModel()
    for _ in range(100):
        await check_comparison(dut, model, Bits32.random().u, Bits32.random().u)


@cocotb.test
async def test_comparator_equal(dut):
    model = ComparatorModel()
    for _ in range(100):
        a = Bits32.random().u
        await check_comparison(dut, model, a, a)


@cocotb.test
async def test_comparator_edge_cases(dut):
    model = ComparatorModel()
    # Signed and unsigned orderings disagree whenever exactly one sign bit is set
    values = [0x00000000, 0x00000001, 0x7FFFFFFF, 0x80000000, 0x80000001, 0xFFFFFFFF]
    for a in values:
        for b in values:
            await check_comparison(dut, model, a, b)
