import cocotb
from programs import PROGRAMS, Program, run_program


@cocotb.test
@cocotb.parametrize(
    program=[cocotb.Param(program, program.image_path.stem) for program in PROGRAMS]
)
async def test_program(top, program: Program):
    # Worst case, every fetch misses: a cycle to detect the miss, one for the memory to accept the
    # request, INSTR_MEM_LATENCY until it responds, and one for the retried lookup to hit
    cycles_per_fetch = int(top.INSTR_MEM_LATENCY.value) + 3
    await run_program(top, program, cycles_per_fetch)
