from pathlib import Path

import cocotb
from cocotb.triggers import Timer
from models.single_cycle_instruction_memory_model import (
    SingleCycleInstructionMemoryInputs,
    SingleCycleInstructionMemoryModel,
)


@cocotb.test
async def test_single_cycle_instruction_memory_reads(dut):
    image_path = Path("hex/instr/default.hex")
    model = SingleCycleInstructionMemoryModel(image_path=image_path)

    depth = len(model.memory)
    wrapped_word_addrs = [depth, depth + 1, 2 * depth - 1, (1 << 30) - 1]
    for word_addr in [*range(depth), *wrapped_word_addrs]:
        inputs = SingleCycleInstructionMemoryInputs(word_addr=word_addr)

        dut.word_addr.value = inputs.word_addr
        await Timer(1, unit="ns")

        expected = model.read(inputs)
        if expected.instruction is None:
            # assert not dut.instruction.value.is_resolvable
            assert dut.instruction.value == 0  # Verilator is a two-state simulator
        else:
            assert dut.instruction.value == expected.instruction
