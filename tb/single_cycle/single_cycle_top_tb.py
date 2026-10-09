from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from top_tb_utils import (
    clear_data_memory,
    clear_register_file,
    load_instruction_memory,
    log_register_file,
    reset,
)


async def run_sum_loop_mixed_ops(top, image_path: Path, cycles: int, return_address: int) -> None:
    """
    Runs a variant of hex/instr/sum_loop_mixed_ops.hex and checks the architectural state.

    The variants differ only in padding, which moves the return address of the jal.
    """
    cocotb.start_soon(Clock(top.clk, 10, unit="ns").start())

    register_file = top.u_core.u_datapath.u_register_file
    load_instruction_memory(top.u_instruction_memory, image_path)
    clear_register_file(register_file)
    clear_data_memory(top.u_data_memory)

    await reset(top)

    for _ in range(cycles):
        await RisingEdge(top.clk)

    log_register_file(register_file)

    registers = register_file.registers
    assert registers[0].value == 0
    assert registers[1].value == 0  # Loop counter ran down to zero
    assert registers[2].value == 15  # 5 + 4 + 3 + 2 + 1
    assert registers[3].value == 0x12345678  # lui + ori
    assert registers[4].value == 0xFFFFFFF1  # -15
    assert registers[5].value == 0xFFFFFFFC  # -15 >>> 2 = -4
    assert registers[6].value == 240  # 15 << 4
    assert registers[7].value == 0x78  # Low byte of 0x12345678
    assert registers[8].value == 0x1234  # Upper half of 0x12345678
    assert registers[9].value == return_address  # Return address of jal
    assert registers[10].value == 0  # Skipped by jal

    for i in range(11, 32):
        assert registers[i].value == 0  # Uninitialized, but Verilator is a two-state simulator

    assert top.u_data_memory.data[1].value == 0x12345678


@cocotb.test
async def test_execution(top):
    await run_sum_loop_mixed_ops(
        top, Path("hex/instr/sum_loop_mixed_ops.hex"), cycles=40, return_address=0x38
    )


@cocotb.test
async def test_execution_nop_padded(top):
    # Checks the padded program itself, before it is used to test the pipelined core
    await run_sum_loop_mixed_ops(
        top, Path("hex/instr/sum_loop_mixed_ops_nop_padded.hex"), cycles=80, return_address=0x60
    )
