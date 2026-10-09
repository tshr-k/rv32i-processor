from dataclasses import dataclass

from models.controller_model import Exception

from tb.bits_32 import Bits32


@dataclass(frozen=True)
class ExceptionUnitInputs:
    controller_exception: Exception
    datapath_exception: Exception
    rf_write_en: bool
    pc: int
    mret_en: bool
    mtvec: int
    mepc: int


@dataclass(frozen=True)
class ExceptionUnitOutputs:
    rf_write_en: bool
    exception: bool
    trap_pc: int
    trap_cause: Exception
    pc_next_override_en: bool
    pc_next_override: int


class ExceptionUnitModel:
    def __call__(self, inputs: ExceptionUnitInputs) -> ExceptionUnitOutputs:
        exception = (
            inputs.controller_exception != Exception.EXCEPT_NONE
            or inputs.datapath_exception != Exception.EXCEPT_NONE
        )

        # Controller exceptions take precedence over datapath exceptions
        if inputs.controller_exception != Exception.EXCEPT_NONE:
            trap_cause = inputs.controller_exception
        else:
            trap_cause = inputs.datapath_exception

        # Trap entry takes precedence over trap return
        if exception:
            pc_next_override = Bits32(inputs.mtvec).u
        else:
            pc_next_override = Bits32(inputs.mepc).u

        return ExceptionUnitOutputs(
            rf_write_en=inputs.rf_write_en and not exception,
            exception=exception,
            trap_pc=Bits32(inputs.pc).u,
            trap_cause=trap_cause,
            pc_next_override_en=exception or inputs.mret_en,
            pc_next_override=pc_next_override,
        )
