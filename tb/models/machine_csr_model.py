from dataclasses import dataclass

from tb.bits_32 import Bits32

MTVEC_ADDR = 0x305
MEPC_ADDR = 0x341
MCAUSE_ADDR = 0x342

MTVEC_RESET = 0x0000_0004  # Must match MTVEC_RESET in rv32i_pkg.sv

ALIGN_4_BYTE_MASK = 0xFFFF_FFFC  # Clears the lowest two bits of an address


@dataclass(frozen=True)
class MachineCsrReadInputs:
    csr_addr: int


@dataclass(frozen=True)
class MachineCsrWriteInputs:
    reset: bool = False
    trap_enter: bool = False
    trap_pc: int = 0
    trap_cause: int = 0
    csr_addr: int = 0
    csr_write_en: bool = False
    csr_write_data: int = 0


@dataclass(frozen=True)
class MachineCsrReadOutputs:
    csr_read_data: int
    mepc: int
    mcause: int
    mtvec: int


class MachineCsrModel:
    def __init__(self):
        self.registers: dict[int, int] = {MTVEC_ADDR: MTVEC_RESET, MEPC_ADDR: 0, MCAUSE_ADDR: 0}

    def read(self, inputs: MachineCsrReadInputs) -> MachineCsrReadOutputs:
        return MachineCsrReadOutputs(
            csr_read_data=self.registers.get(inputs.csr_addr, 0),  # Unimplemented CSRs read as zero
            mepc=self.registers[MEPC_ADDR],
            mcause=self.registers[MCAUSE_ADDR],
            mtvec=self.registers[MTVEC_ADDR],
        )

    def write(self, inputs: MachineCsrWriteInputs) -> None:
        if not 0 <= inputs.csr_addr <= 0xFFF:
            raise ValueError("CSR address must be a 12-bit value.")

        # Reset, then trap entry, then software writes, in order of priority
        if inputs.reset:
            self.__init__()
        elif inputs.trap_enter:
            self.registers[MEPC_ADDR] = Bits32(inputs.trap_pc).u & ALIGN_4_BYTE_MASK
            self.registers[MCAUSE_ADDR] = Bits32(inputs.trap_cause).u
        elif inputs.csr_write_en and inputs.csr_addr in self.registers:  # Others are ignored
            write_data = Bits32(inputs.csr_write_data).u
            if inputs.csr_addr in (MTVEC_ADDR, MEPC_ADDR):
                write_data &= (
                    ALIGN_4_BYTE_MASK  # 4-byte aligned, which also forces mtvec into direct mode
                )
            self.registers[inputs.csr_addr] = write_data
