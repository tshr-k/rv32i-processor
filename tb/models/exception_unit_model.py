from dataclasses import dataclass

from models.controller_model import (
    AluASel,
    AluBSel,
    AluOp,
    BranchCondition,
    Exception,
    PcNextSel,
    RfWriteDataSel,
)
from models.immediate_decoder_model import InstructionFormat

from tb.bits_32 import Bits32


@dataclass(frozen=True)
class ExceptionUnitInputs:
    controller_exception: Exception
    datapath_exception: Exception
    rf_write_en: bool
    rf_write_data_sel: RfWriteDataSel
    alu_op: AluOp
    alu_a_sel: AluASel
    alu_b_sel: AluBSel
    instruction_fmt: InstructionFormat
    branch_condition: BranchCondition
    pc_next_sel: PcNextSel
    machine_trap_vector: int


@dataclass(frozen=True)
class ExceptionUnitOutputs:
    rf_write_en: bool
    rf_write_data_sel: RfWriteDataSel
    alu_op: AluOp
    alu_a_sel: AluASel
    alu_b_sel: AluBSel
    instruction_fmt: InstructionFormat
    branch_condition: BranchCondition
    pc_next_sel: PcNextSel
    exception: bool
    machine_trap_cause: Exception
    pc_next_override: int


class ExceptionUnitModel:
    def __call__(self, inputs: ExceptionUnitInputs) -> ExceptionUnitOutputs:
        exception = (
            inputs.controller_exception != Exception.EXCEPT_NONE
            or inputs.datapath_exception != Exception.EXCEPT_NONE
        )

        # Controller exceptions take precedence over datapath exceptions
        if inputs.controller_exception != Exception.EXCEPT_NONE:
            machine_trap_cause = inputs.controller_exception
        else:
            machine_trap_cause = inputs.datapath_exception

        return ExceptionUnitOutputs(
            rf_write_en=inputs.rf_write_en and not exception,
            rf_write_data_sel=inputs.rf_write_data_sel,
            alu_op=inputs.alu_op,
            alu_a_sel=inputs.alu_a_sel,
            alu_b_sel=inputs.alu_b_sel,
            instruction_fmt=inputs.instruction_fmt,
            branch_condition=inputs.branch_condition,
            pc_next_sel=inputs.pc_next_sel,
            exception=exception,
            machine_trap_cause=machine_trap_cause,
            pc_next_override=Bits32(inputs.machine_trap_vector).u,
        )
