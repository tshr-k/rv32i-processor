import random

import cocotb
from cocotb.triggers import Timer
from models.controller_model import Exception
from models.exception_unit_model import ExceptionUnitInputs, ExceptionUnitModel
from models.machine_csr_model import ALIGN_4_BYTE_MASK

from tb.bits_32 import Bits32


async def test_exception_unit_inputs(dut, inputs: ExceptionUnitInputs) -> None:
    model = ExceptionUnitModel()

    dut.controller_exception.value = inputs.controller_exception.value
    dut.datapath_exception.value = inputs.datapath_exception.value
    dut.rf_write_en_in.value = inputs.rf_write_en
    dut.memory_write_en_in.value = inputs.memory_write_en
    dut.pc.value = inputs.pc
    dut.mret_en.value = inputs.mret_en
    dut.mtvec.value = inputs.mtvec
    dut.mepc.value = inputs.mepc
    await Timer(1, unit="ns")

    expected = model(inputs)
    actual = {
        "rf_write_en": bool(int(dut.rf_write_en_out.value)),
        "memory_write_en": bool(int(dut.memory_write_en_out.value)),
        "exception": bool(int(dut.exception.value)),
        "trap_pc": int(dut.trap_pc.value),
        "trap_cause": int(dut.trap_cause.value),
        "pc_next_override_en": bool(int(dut.pc_next_override_en.value)),
        "pc_next_override": int(dut.pc_next_override.value),
    }

    assert actual == {
        "rf_write_en": expected.rf_write_en,
        "memory_write_en": expected.memory_write_en,
        "exception": expected.exception,
        "trap_pc": expected.trap_pc,
        "trap_cause": expected.trap_cause.value,
        "pc_next_override_en": expected.pc_next_override_en,
        "pc_next_override": expected.pc_next_override,
    }, f"{inputs}: {expected} != {actual}"


def random_inputs(
    controller_exception: Exception | None = None,
    datapath_exception: Exception | None = None,
    rf_write_en: bool | None = None,
    memory_write_en: bool | None = None,
    mret_en: bool | None = None,
) -> ExceptionUnitInputs:
    return ExceptionUnitInputs(
        controller_exception=(
            random.choice(list(Exception)) if controller_exception is None else controller_exception
        ),
        datapath_exception=(
            random.choice(list(Exception)) if datapath_exception is None else datapath_exception
        ),
        rf_write_en=random.choice([True, False]) if rf_write_en is None else rf_write_en,
        memory_write_en=(
            random.choice([True, False]) if memory_write_en is None else memory_write_en
        ),
        pc=Bits32.random().u,
        mret_en=random.choice([True, False]) if mret_en is None else mret_en,
        mtvec=Bits32.random().u
        & ALIGN_4_BYTE_MASK,  # mtvec is always word-aligned (direct mode only)
        mepc=Bits32.random().u & ALIGN_4_BYTE_MASK,  # mepc is always word-aligned
    )


@cocotb.test
async def test_exception_unit_all_exception_pairs(dut):
    for controller_exception in Exception:
        for datapath_exception in Exception:
            for rf_write_en in [True, False]:
                for memory_write_en in [True, False]:
                    inputs = random_inputs(
                        controller_exception, datapath_exception, rf_write_en, memory_write_en
                    )
                    await test_exception_unit_inputs(dut, inputs)


@cocotb.test
async def test_exception_unit_no_exception(dut):
    for _ in range(100):
        inputs = random_inputs(Exception.EXCEPT_NONE, Exception.EXCEPT_NONE)
        await test_exception_unit_inputs(dut, inputs)


@cocotb.test
async def test_exception_unit_mret(dut):
    for _ in range(100):
        inputs = random_inputs(Exception.EXCEPT_NONE, Exception.EXCEPT_NONE, mret_en=True)
        await test_exception_unit_inputs(dut, inputs)


@cocotb.test
async def test_exception_unit_random(dut):
    for _ in range(200):
        await test_exception_unit_inputs(dut, random_inputs())
