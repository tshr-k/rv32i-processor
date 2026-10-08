import random

import cocotb
from cocotb.triggers import Timer
from models.controller_model import (
    AluASel,
    AluBSel,
    AluOp,
    BranchCondition,
    Exception,
    PcNextSel,
    RfWriteDataSel,
)
from models.exception_unit_model import ExceptionUnitInputs, ExceptionUnitModel
from models.immediate_decoder_model import InstructionFormat

from tb.bits_32 import Bits32


async def test_exception_unit_inputs(dut, inputs: ExceptionUnitInputs) -> None:
    model = ExceptionUnitModel()

    dut.controller_exception.value = inputs.controller_exception.value
    dut.datapath_exception.value = inputs.datapath_exception.value
    dut.rf_write_en_in.value = inputs.rf_write_en
    dut.rf_write_data_sel_in.value = inputs.rf_write_data_sel.value
    dut.alu_op_in.value = inputs.alu_op.value
    dut.alu_a_sel_in.value = inputs.alu_a_sel.value
    dut.alu_b_sel_in.value = inputs.alu_b_sel.value
    dut.instruction_fmt_in.value = inputs.instruction_fmt.value
    dut.branch_condition_in.value = inputs.branch_condition.value
    dut.pc_next_sel_in.value = inputs.pc_next_sel.value
    dut.machine_trap_vector.value = inputs.machine_trap_vector
    await Timer(1, unit="ns")

    expected = model(inputs)
    actual = {
        "rf_write_en": bool(int(dut.rf_write_en_out.value)),
        "rf_write_data_sel": int(dut.rf_write_data_sel_out.value),
        "alu_op": int(dut.alu_op_out.value),
        "alu_a_sel": int(dut.alu_a_sel_out.value),
        "alu_b_sel": int(dut.alu_b_sel_out.value),
        "instruction_fmt": int(dut.instruction_fmt_out.value),
        "branch_condition": int(dut.branch_condition_out.value),
        "pc_next_sel": int(dut.pc_next_sel_out.value),
        "exception": bool(int(dut.exception.value)),
        "machine_trap_cause": int(dut.machine_trap_cause.value),
        "pc_next_override": int(dut.pc_next_override.value),
    }

    assert actual == {
        "rf_write_en": expected.rf_write_en,
        "rf_write_data_sel": expected.rf_write_data_sel.value,
        "alu_op": expected.alu_op.value,
        "alu_a_sel": expected.alu_a_sel.value,
        "alu_b_sel": expected.alu_b_sel.value,
        "instruction_fmt": expected.instruction_fmt.value,
        "branch_condition": expected.branch_condition.value,
        "pc_next_sel": expected.pc_next_sel.value,
        "exception": expected.exception,
        "machine_trap_cause": expected.machine_trap_cause.value,
        "pc_next_override": expected.pc_next_override,
    }, f"{inputs}: {expected} != {actual}"


def random_inputs(
    controller_exception: Exception | None = None,
    datapath_exception: Exception | None = None,
    rf_write_en: bool | None = None,
) -> ExceptionUnitInputs:
    return ExceptionUnitInputs(
        controller_exception=(
            random.choice(list(Exception)) if controller_exception is None else controller_exception
        ),
        datapath_exception=(
            random.choice(list(Exception)) if datapath_exception is None else datapath_exception
        ),
        rf_write_en=random.choice([True, False]) if rf_write_en is None else rf_write_en,
        rf_write_data_sel=random.choice(list(RfWriteDataSel)),
        alu_op=random.choice(list(AluOp)),
        alu_a_sel=random.choice(list(AluASel)),
        alu_b_sel=random.choice(list(AluBSel)),
        instruction_fmt=random.choice(list(InstructionFormat)),
        branch_condition=random.choice(list(BranchCondition)),
        pc_next_sel=random.choice(list(PcNextSel)),
        machine_trap_vector=Bits32.random().u,
    )


@cocotb.test
async def test_exception_unit_all_exception_pairs(dut):
    for controller_exception in Exception:
        for datapath_exception in Exception:
            for rf_write_en in [True, False]:
                inputs = random_inputs(controller_exception, datapath_exception, rf_write_en)
                await test_exception_unit_inputs(dut, inputs)


@cocotb.test
async def test_exception_unit_no_exception(dut):
    for _ in range(100):
        inputs = random_inputs(Exception.EXCEPT_NONE, Exception.EXCEPT_NONE)
        await test_exception_unit_inputs(dut, inputs)


@cocotb.test
async def test_exception_unit_random(dut):
    for _ in range(200):
        await test_exception_unit_inputs(dut, random_inputs())
