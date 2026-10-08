from pathlib import Path

import cocotb
from cocotb.triggers import Timer
from models.instruction_memory_model import InstructionMemoryInputs, InstructionMemoryModel


@cocotb.test
async def test_instruction_memory_reads(dut):
    image_path = Path("hex/instr/default.hex")
    model = InstructionMemoryModel(image_path=image_path)

    depth_bytes = len(model.memory) * 4
    wrapped_addrs = [depth_bytes, depth_bytes + 4, 2 * depth_bytes - 4, 0xFFFFFFFC]
    for addr in [*range(0, depth_bytes, 4), *wrapped_addrs]:
        inputs = InstructionMemoryInputs(addr=addr)

        dut.addr.value = inputs.addr
        await Timer(1, unit="ns")

        expected = model.read(inputs)
        if expected.instruction is None:
            # assert not dut.instruction.value.is_resolvable
            assert dut.instruction.value == 0  # Verilator is a two-state simulator
        else:
            assert dut.instruction.value == expected.instruction
