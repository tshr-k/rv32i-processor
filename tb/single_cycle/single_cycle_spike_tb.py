import cocotb
from models.controller_model import MemoryOp
from spike import REPO_ROOT, Commit, SpikeProgram, Store, run_against_spike

# Trap-free programs only, as the core has no Zicsr instructions to point mtvec at a handler,
# and Spike's mtvec resets to zero, where it has no memory
PROGRAMS = [
    SpikeProgram(REPO_ROOT / "asm" / f"{name}.S")
    for name in [
        "default",
        "mixed_ops",
        "mixed_ops_nop_padded",
        "forwarding",
        "forwarding_x0",
        "load_use",
        "control_flow",
    ]
]

LOADS = {MemoryOp.MEM_LB, MemoryOp.MEM_LBU, MemoryOp.MEM_LH, MemoryOp.MEM_LHU, MemoryOp.MEM_LW}
STORE_SIZES = {MemoryOp.MEM_SB: 1, MemoryOp.MEM_SH: 2, MemoryOp.MEM_SW: 4}


def sample_commit(top) -> Commit:
    """Every instruction retires in the cycle it is fetched."""
    core = top.u_core
    datapath = core.u_datapath
    register_file = datapath.u_register_file

    pc = int(core.instruction_addr.value)
    assert not core.exception.value, f"RTL trapped at pc {pc:#010x}"

    rd_write = None
    if register_file.write_en.value and int(register_file.write_addr.value) != 0:
        rd_write = (int(register_file.write_addr.value), int(register_file.write_data.value))

    memory_op = MemoryOp(int(datapath.memory_op.value))
    memory_addr = int(datapath.memory_addr.value)

    store = None
    if memory_op in STORE_SIZES:
        assert core.memory_write_en.value
        size = STORE_SIZES[memory_op]
        data = int(datapath.store_data.value) & ((1 << (8 * size)) - 1)
        store = Store(addr=memory_addr, data=data, size=size)

    return Commit(
        pc=pc,
        instruction=int(core.instruction.value),
        rd_write=rd_write,
        load_addr=memory_addr if memory_op in LOADS else None,
        store=store,
    )


@cocotb.test
@cocotb.parametrize(program=[cocotb.Param(program, program.source.stem) for program in PROGRAMS])
async def test_program(top, program: SpikeProgram):
    await run_against_spike(top, program, sample_commit)
