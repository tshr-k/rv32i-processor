import random

import cocotb
from bits_32 import Bits32
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from models.machine_csr_model import (
    MCAUSE_ADDR,
    MEPC_ADDR,
    MTVEC_ADDR,
    MachineCsrModel,
    MachineCsrReadInputs,
    MachineCsrWriteInputs,
)

CSR_ADDRS = [MTVEC_ADDR, MEPC_ADDR, MCAUSE_ADDR]


async def write_csr(dut, model: MachineCsrModel, inputs: MachineCsrWriteInputs) -> None:
    dut.reset.value = inputs.reset
    dut.trap_enter.value = inputs.trap_enter
    dut.trap_pc.value = inputs.trap_pc
    dut.trap_cause.value = inputs.trap_cause
    dut.csr_addr.value = inputs.csr_addr
    dut.csr_write_en.value = inputs.csr_write_en
    dut.csr_write_data.value = inputs.csr_write_data
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    model.write(inputs)

    # Return to idle so nothing is written on later clock edges
    dut.reset.value = 0
    dut.trap_enter.value = 0
    dut.csr_write_en.value = 0


async def assert_read_values(dut, model: MachineCsrModel, inputs: MachineCsrReadInputs) -> None:
    dut.csr_addr.value = inputs.csr_addr
    await Timer(1, unit="ns")

    expected = model.read(inputs)
    actual = {
        "csr_read_data": int(dut.csr_read_data.value),
        "mepc": int(dut.mepc.value),
        "mcause": int(dut.mcause.value),
        "mtvec": int(dut.mtvec.value),
    }

    assert actual == {
        "csr_read_data": expected.csr_read_data,
        "mepc": expected.mepc,
        "mcause": expected.mcause,
        "mtvec": expected.mtvec,
    }, f"{inputs}: {expected} != {actual}"


async def assert_all_read_values(dut, model: MachineCsrModel) -> None:
    for csr_addr in CSR_ADDRS:
        await assert_read_values(dut, model, MachineCsrReadInputs(csr_addr=csr_addr))


async def start(dut) -> MachineCsrModel:
    """Start the clock and reset the DUT, returning a model in the reset state."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.trap_enter.value = 0
    dut.csr_write_en.value = 0

    model = MachineCsrModel()
    await write_csr(dut, model, MachineCsrWriteInputs(reset=True))
    return model


def random_unimplemented_addr() -> int:
    while (csr_addr := random.getrandbits(12)) in CSR_ADDRS:
        pass
    return csr_addr


@cocotb.test
async def test_machine_csr_reset_values(dut):
    model = await start(dut)
    await assert_all_read_values(dut, model)

    # Reset again after the CSRs have been written
    for csr_addr in CSR_ADDRS:
        inputs = MachineCsrWriteInputs(
            csr_addr=csr_addr, csr_write_en=True, csr_write_data=Bits32.random().u
        )
        await write_csr(dut, model, inputs)

    await write_csr(dut, model, MachineCsrWriteInputs(reset=True))
    await assert_all_read_values(dut, model)


@cocotb.test
async def test_machine_csr_software_writes(dut):
    model = await start(dut)

    for _ in range(100):
        inputs = MachineCsrWriteInputs(
            csr_addr=random.choice(CSR_ADDRS),
            csr_write_en=random.choice([True, False]),
            csr_write_data=Bits32.random().u,  # Includes misaligned mepc and mtvec values
        )
        await write_csr(dut, model, inputs)
        await assert_all_read_values(dut, model)


@cocotb.test
async def test_machine_csr_trap_entry(dut):
    model = await start(dut)

    for _ in range(100):
        inputs = MachineCsrWriteInputs(
            trap_enter=True,
            trap_pc=Bits32.random().u,
            trap_cause=Bits32.random().u,
        )
        await write_csr(dut, model, inputs)
        await assert_all_read_values(dut, model)


@cocotb.test
async def test_machine_csr_trap_entry_priority(dut):
    model = await start(dut)

    # Trap entry and a software write in the same cycle: only the trap is recorded
    for _ in range(100):
        inputs = MachineCsrWriteInputs(
            trap_enter=True,
            trap_pc=Bits32.random().u,
            trap_cause=Bits32.random().u,
            csr_addr=random.choice(CSR_ADDRS),
            csr_write_en=True,
            csr_write_data=Bits32.random().u,
        )
        await write_csr(dut, model, inputs)
        await assert_all_read_values(dut, model)


@cocotb.test
async def test_machine_csr_unimplemented(dut):
    model = await start(dut)

    for csr_addr in CSR_ADDRS:
        inputs = MachineCsrWriteInputs(
            csr_addr=csr_addr, csr_write_en=True, csr_write_data=Bits32.random().u
        )
        await write_csr(dut, model, inputs)

    # Unimplemented CSRs read as zero, and writes to them leave the real CSRs untouched
    for _ in range(100):
        csr_addr = random_unimplemented_addr()
        inputs = MachineCsrWriteInputs(
            csr_addr=csr_addr, csr_write_en=True, csr_write_data=Bits32.random().u
        )
        await write_csr(dut, model, inputs)
        await assert_read_values(dut, model, MachineCsrReadInputs(csr_addr=csr_addr))
        await assert_all_read_values(dut, model)


@cocotb.test
async def test_machine_csr_random(dut):
    model = await start(dut)

    for _ in range(500):
        inputs = MachineCsrWriteInputs(
            reset=random.random() < 0.02,
            trap_enter=random.random() < 0.2,
            trap_pc=Bits32.random().u,
            trap_cause=Bits32.random().u,
            csr_addr=random.choice(CSR_ADDRS + [random_unimplemented_addr()]),
            csr_write_en=random.choice([True, False]),
            csr_write_data=Bits32.random().u,
        )
        await write_csr(dut, model, inputs)
        await assert_read_values(
            dut,
            model,
            MachineCsrReadInputs(csr_addr=random.choice(CSR_ADDRS + [random_unimplemented_addr()])),
        )
