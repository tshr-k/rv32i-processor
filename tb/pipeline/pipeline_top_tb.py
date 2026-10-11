import cocotb
from programs import PROGRAMS, Program, run_program


@cocotb.test
@cocotb.parametrize(program=[cocotb.Param(program, program.image_path.stem) for program in PROGRAMS])
async def test_program(top, program: Program):
    await run_program(top, program)
