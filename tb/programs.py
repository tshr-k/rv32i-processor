from dataclasses import dataclass, field
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from common.data_memory_tb import clear_data_memory
from common.instruction_memory_tb import load_instruction_memory
from common.register_file_tb import clear_register_file, log_register_file


@dataclass(frozen=True)
class Program:
    """
    A program in hex/instr/ and the architectural state it must leave behind.

    Registers and data memory words not listed must be zero. The machine CSRs keep their reset
    values (zero) unless the program traps.
    """

    image_path: Path
    cycles: int  # Enough for the slowest microarchitecture to reach the final halt
    registers: dict[int, int]  # Register index -> value
    memory: dict[int, int] = field(default_factory=dict)  # Word-aligned byte address -> word
    mepc: int = 0
    mcause: int = 0


def mixed_ops(image_path: Path, return_address: int) -> Program:
    """The variants of mixed_ops differ only in padding, which moves the return address of the jal."""
    return Program(
        image_path=image_path,
        cycles=100,
        registers={
            2: 15,  # 5 + 4 + 3 + 2 + 1, while the loop counter x1 runs down to zero
            3: 0x12345678,  # lui + ori
            4: 0xFFFFFFF1,  # -15
            5: 0xFFFFFFFC,  # -15 >>> 2 = -4
            6: 240,  # 15 << 4
            7: 0x78,  # Low byte of 0x12345678
            8: 0x1234,  # Upper half of 0x12345678
            9: return_address,  # Return address of jal, while x10 is skipped
        },
        memory={0x04: 0x12345678},
    )


MIXED_OPS = mixed_ops(Path("hex/instr/mixed_ops.hex"), return_address=0x38)
MIXED_OPS_NOP_PADDED = mixed_ops(Path("hex/instr/mixed_ops_nop_padded.hex"), return_address=0x60)

FORWARDING = Program(
    image_path=Path("hex/instr/forwarding.hex"),
    cycles=100,
    registers={
        1: 10,
        2: 15,
        3: 25,
        4: 15,
        5: 7,
        6: 14,
        7: 0x12345678,
        8: 0x2C,
        9: 0x55,
        10: 0x20,
        11: 0x66,
        12: 0x55,
        13: 0x66,
        14: 3,
        15: 3,
        17: 7,
        18: 1,
        19: 9,
        20: 0x84,
        21: 0x80,
        22: 0x80,
        23: 0x8C,
        24: 0x90,
    },
    memory={0x08: 0x55, 0x20: 0x66},
)

LOAD_USE = Program(
    image_path=Path("hex/instr/load_use.hex"),
    cycles=100,
    registers={
        1: 0xFFFFFFFE,
        2: 0x40,
        3: 0x7F,
        4: 0xFFFFFFFE,
        5: 1,
        6: 0x40,
        7: 0x7F,
        8: 0x7F,
        9: 0xFFFFFFFE,
        10: 0x40,
        11: 1,
        12: 0x41,
        13: 0xFFFFFFFE,
        15: 0xFE,
        16: 0xFFFE,
        17: 0xFFFFFFFF,
        18: 0xFF00,
        19: 0x74,
        20: 0x74,
        21: 0x70,
        22: 1,
    },
    memory={0x00: 0xFFFFFFFE, 0x04: 0x40, 0x08: 0xFFFFFFFE, 0x0C: 0x74, 0x40: 0x7F},
)

CONTROL_FLOW = Program(
    image_path=Path("hex/instr/control_flow.hex"),
    cycles=150,
    registers={
        1: 0xFFFFFFFF,
        2: 1,
        4: 12,
        5: 0x94,
        6: 1,
        7: 0x77,
        30: 6,  # Every not-taken branch fell through
    },
)

TRAP_MISALIGNED = Program(
    image_path=Path("hex/instr/trap_misaligned.hex"),
    cycles=200,
    registers={
        6: 0x58,
        7: 0x55,
        8: 0x56,
        9: 0x55,
        10: 0x55,
        11: 0x66,
        12: 0x54,
        14: 1,
        31: 5,  # One trap each for lw, lh, sw, sh and jalr
    },
    memory={0x20: 0x55, 0x24: 0x66, 0x28: 0x66},
    mepc=0x50,  # The jalr
    mcause=0,  # Instruction address misaligned
)

TRAP_ILLEGAL = Program(
    image_path=Path("hex/instr/trap_illegal.hex"),
    cycles=50,
    registers={1: 1, 2: 2, 8: 0x5A},
    mepc=0x14,
    mcause=2,  # Illegal instruction
)

TRAP_ECALL = Program(
    image_path=Path("hex/instr/trap_ecall.hex"),
    cycles=50,
    registers={1: 1, 2: 2},
    mepc=0x10,
    mcause=11,  # Environment call from M-mode
)

PROGRAMS = [
    MIXED_OPS,
    MIXED_OPS_NOP_PADDED,
    FORWARDING,
    LOAD_USE,
    CONTROL_FLOW,
    TRAP_MISALIGNED,
    TRAP_ILLEGAL,
    TRAP_ECALL,
]


async def reset(top) -> None:
    top.reset.value = 1
    for _ in range(3):
        await RisingEdge(top.clk)

    top.reset.value = 0
    await Timer(1, unit="ns")


async def run_program(top, program: Program) -> None:
    """Runs the program on a *_top and checks the architectural state it leaves behind."""
    cocotb.start_soon(Clock(top.clk, 10, unit="ns").start(start_high=False))

    register_file = top.u_core.u_datapath.u_register_file
    load_instruction_memory(top.u_instruction_memory, program.image_path)
    clear_register_file(register_file)
    clear_data_memory(top.u_data_memory)

    await reset(top)

    for _ in range(program.cycles):
        await RisingEdge(top.clk)

    log_register_file(register_file)

    # Verilator is a two-state simulator, so unwritten state reads as zero
    for i in range(32):
        assert register_file.registers[i].value == program.registers.get(i, 0), f"x{i}"

    data = top.u_data_memory.data
    for i in range(len(data)):
        assert data[i].value == program.memory.get(4 * i, 0), f"mem[{4 * i:#x}]"

    machine_csr = top.u_core.u_machine_csr
    assert machine_csr.mepc.value == program.mepc
    assert machine_csr.mcause.value == program.mcause
