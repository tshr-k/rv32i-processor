import cocotb
from cocotb.triggers import Timer
from models.comparator_model import ComparatorInputs, ComparatorModel

from tb.bits_32 import Bits32


async def check_comparison(dut, model: ComparatorModel, inputs: ComparatorInputs) -> None:
    dut.a.value = inputs.a
    dut.b.value = inputs.b
    await Timer(1, unit="ns")

    expected = model(inputs)

    assert dut.eq.value == expected.eq, (
        f"EQ failed: {inputs.a:#010x}, {inputs.b:#010x} != {dut.eq.value}"
    )

    assert dut.lt.value == expected.lt, (
        f"LT failed: {inputs.a:#010x}, {inputs.b:#010x} != {dut.lt.value}"
    )

    assert dut.ltu.value == expected.ltu, (
        f"LTU failed: {inputs.a:#010x}, {inputs.b:#010x} != {dut.ltu.value}"
    )


@cocotb.test
async def test_comparator_random(dut):
    model = ComparatorModel()
    for _ in range(100):
        inputs = ComparatorInputs(a=Bits32.random().u, b=Bits32.random().u)
        await check_comparison(dut, model, inputs)


@cocotb.test
async def test_comparator_equal(dut):
    model = ComparatorModel()
    for _ in range(100):
        a = Bits32.random().u
        await check_comparison(dut, model, ComparatorInputs(a=a, b=a))


@cocotb.test
async def test_comparator_edge_cases(dut):
    model = ComparatorModel()
    # Signed and unsigned orderings disagree whenever exactly one sign bit is set
    values = [0x00000000, 0x00000001, 0x7FFFFFFF, 0x80000000, 0x80000001, 0xFFFFFFFF]
    for a in values:
        for b in values:
            await check_comparison(dut, model, ComparatorInputs(a=a, b=b))
