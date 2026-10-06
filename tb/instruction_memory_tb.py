from pathlib import Path

import cocotb
from cocotb.triggers import Timer
from models.instruction_memory_model import InstructionMemoryModel


@cocotb.test
async def test_instruction_memory_reads(dut):
    image_path = Path("hex/instruction_memory.hex")
    model = InstructionMemoryModel(image_path=image_path)

    for addr in range(0, 256, 4):
        dut.addr.value = addr
        await Timer(1, unit="ns")

        expected = model.read(addr)
        if expected is None:
            assert not dut.instruction.value.is_resolvable
        else:
            assert dut.instruction.value.to_unsigned() == expected
