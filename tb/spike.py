"""
Differential testing against Spike, the RISC-V ISA reference simulator.

A program in asm/ is assembled for Spike's memory map and run on Spike with --log-commits, giving one
Commit per retired instruction. The same image is then run on a *_spike top, whose monitor builds the
same Commits from the RTL, and the two traces must match instruction by instruction.
"""

import os
import re
import subprocess
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge
from common.register_file_tb import clear_register_file
from programs import reset

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = REPO_ROOT / "build" / "spike"

MEM_BASE_ADDR = (
    0x8000_0000  # Must match INSTR_ADDR_RESET in rv32i_pkg.sv with SPIKE_MEMORY_MAP defined
)
MEM_DEPTH = 256  # Words, so must match MEM_DEPTH in the *_spike tops

SPIKE = os.environ.get("SPIKE_PATH", "spike")
RISCV_PREFIX = os.environ.get("RISCV_PREFIX", "riscv64-unknown-elf-")


@dataclass(frozen=True)
class SpikeProgram:
    """A trap-free program in asm/, which must reach its final halt loop within `instructions`."""

    source: Path
    instructions: int = 200  # For --instructions, which also counts Spike's boot ROM


@dataclass(frozen=True)
class Store:
    addr: int  # Byte address
    data: int  # Only the bytes stored, so not shifted into lane position
    size: int  # Bytes


@dataclass(frozen=True)
class Commit:
    """The architectural effects of one retired instruction, as Spike logs them."""

    pc: int
    instruction: int
    rd_write: tuple[int, int] | None = None  # (rd, value), never for x0
    load_addr: int | None = None
    store: Store | None = None

    def __str__(self) -> str:
        effects = []
        if self.rd_write is not None:
            effects.append(f"x{self.rd_write[0]} <- {self.rd_write[1]:#010x}")
        if self.load_addr is not None:
            effects.append(f"load {self.load_addr:#010x}")
        if self.store is not None:
            effects.append(
                f"store {self.store.addr:#010x} <- {self.store.data:#0{2 * self.store.size + 2}x}"
            )
        return f"pc {self.pc:#010x} ({self.instruction:08x}) {', '.join(effects)}".rstrip()


@dataclass(frozen=True)
class SpikeTrace:
    boot: list[Commit]  # Spike's boot ROM, before the jump to MEM_BASE_ADDR
    program: list[Commit]


def assemble(source: Path) -> tuple[Path, list[int]]:
    """Returns the ELF for Spike and the words of its memory image, starting at MEM_BASE_ADDR."""
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    elf = BUILD_DIR / f"{source.stem}.elf"
    binary = BUILD_DIR / f"{source.stem}.bin"

    # -N stops the linker from page-aligning the segment below MEM_BASE_ADDR, where Spike has no memory
    subprocess.run(
        [
            f"{RISCV_PREFIX}gcc",
            "-march=rv32i",
            "-mabi=ilp32",
            "-nostdlib",
            "-nostartfiles",
            "-mno-relax",
            "-Wl,-N",
            "-Wl,--no-warn-rwx-segments",
            f"-Wl,-Ttext={MEM_BASE_ADDR:#x}",
            "-o",
            str(elf),
            str(source),
        ],
        check=True,
    )
    subprocess.run([f"{RISCV_PREFIX}objcopy", "-O", "binary", str(elf), str(binary)], check=True)

    image = binary.read_bytes()
    image += bytes(-len(image) % 4)
    words = [int.from_bytes(image[i : i + 4], "little") for i in range(0, len(image), 4)]
    assert len(words) <= MEM_DEPTH, f"{source.name} does not fit in memory"
    return elf, words


_COMMIT_LINE = re.compile(r"core\s+\d+: \d+ 0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)")


def parse_commit(line: str) -> Commit | None:
    """
    Parses a --log-commits line, for example:
        core   0: 3 0x80000018 (0x001f8103) x2  0x00000066 mem 0x80000201
        core   0: 3 0x80000010 (0x001f9123) mem 0x80000202 0x0066
    """
    match = _COMMIT_LINE.fullmatch(line.strip())
    if match is None:
        return None

    pc, instruction, rest = int(match[1], 16), int(match[2], 16), match[3].split()
    rd_write = load_addr = store = None

    i = 0
    while i < len(rest):
        if re.fullmatch(r"x\d+", rest[i]):
            rd_write = (int(rest[i][1:]), int(rest[i + 1], 16))
            i += 2
        elif rest[i] == "mem":
            addr = int(rest[i + 1], 16)
            if i + 2 < len(rest) and rest[i + 2].startswith("0x"):  # Stores also log the data
                data = rest[i + 2]
                store = Store(addr=addr, data=int(data, 16), size=(len(data) - 2) // 2)
                i += 3
            else:
                load_addr = addr
                i += 2
        else:
            raise ValueError(f"Unexpected field {rest[i]!r} in Spike commit: {line!r}")

    return Commit(pc, instruction, rd_write, load_addr, store)


def run_spike(elf: Path, instructions: int) -> SpikeTrace:
    result = subprocess.run(
        [
            SPIKE,
            "--isa=rv32i",
            f"-m{MEM_BASE_ADDR:#x}:{4 * MEM_DEPTH:#x}",  # Size in bytes
            f"--instructions={instructions}",
            "--log-commits",
            str(elf),
        ],
        capture_output=True,
        text=True,
        check=True,
    )

    commits = [commit for line in result.stderr.splitlines() if (commit := parse_commit(line))]

    # Spike's mtvec resets to zero, where it has no memory, so after a trap every fetch faults and
    # nothing more retires
    assert len(commits) == instructions, (
        f"{elf.stem} trapped on Spike after {len(commits)} of {instructions} instructions, "
        f"last retired: {commits[-1] if commits else None}"
    )

    in_memory = [MEM_BASE_ADDR <= commit.pc < MEM_BASE_ADDR + 4 * MEM_DEPTH for commit in commits]
    first = in_memory.index(True)
    assert all(in_memory[first:]), f"{elf.stem} left memory on Spike"

    program = commits[first:]
    assert len(program) >= 2 and program[-1].pc == program[-2].pc, (
        f"{elf.stem} did not reach its halt loop within {instructions} instructions"
    )

    return SpikeTrace(boot=commits[:first], program=program)


def boot_registers(trace: SpikeTrace) -> dict[int, int]:
    """The registers Spike's boot ROM leaves behind, which the RTL must start from."""
    registers = {}
    for commit in trace.boot:
        if commit.rd_write is not None:
            registers[commit.rd_write[0]] = commit.rd_write[1]
    return registers


def load_memory(memory, image: list[int]) -> None:
    """Loads an instruction or data memory of a *_spike top, zeroing the rest as Spike does."""
    for i in range(len(memory)):
        memory[i].value = image[i] if i < len(image) else 0


async def run_against_spike(
    top,
    program: SpikeProgram,
    sample_commit: Callable[[object], Commit | None],
    cycles_per_instruction: int = 1,
) -> None:
    """
    Runs the program on Spike and on a *_spike top, and checks that the RTL retires the same
    instructions with the same effects, in order.

    sample_commit is called once per cycle, in the ReadOnly phase before the rising edge, and
    returns the instruction retiring at that edge, if any.
    """
    elf, image = assemble(program.source)
    trace = run_spike(elf, program.instructions)

    cocotb.start_soon(Clock(top.clk, 10, unit="ns").start(start_high=False))
    await reset(top)

    # The registers have no reset, so the RTL starts from the state Spike's boot ROM leaves behind.
    # The memories are loaded after reset, as the core already executes during it
    register_file = top.u_core.u_datapath.u_register_file
    clear_register_file(register_file)
    for i, value in boot_registers(trace).items():
        register_file.registers[i].value = value

    load_memory(top.u_instruction_memory.instructions, image)
    load_memory(top.u_data_memory.data, image)

    retired = 0
    for _ in range(len(trace.program) * cycles_per_instruction):
        await ReadOnly()
        commit = sample_commit(top)
        if commit is not None:
            expected = trace.program[retired]
            assert commit == expected, (
                f"Instruction {retired} differs from Spike\n  Spike: {expected}\n  RTL:   {commit}"
            )
            retired += 1
            if retired == len(trace.program):
                return

        await RisingEdge(top.clk)

    assert False, f"RTL retired only {retired} of {len(trace.program)} instructions"
