from pathlib import Path

import cocotb
from cocotb.triggers import Timer
from models.instruction_memory_model import InstructionMemoryInputs, InstructionMemoryModel


def load_instruction_memory(u_instruction_memory, image_path: Path = Path("hex/instr/default.hex")):
    current_index = 0
    with open(image_path) as image:
        for line in image:
            line = line.split("//")[0].strip()
            if not line:
                continue

            u_instruction_memory.instructions[current_index].value = int(line, 16)
            current_index += 1


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
