# RV32I Processor

A RISC-V processor in SystemVerilog, supporting the entire RV32I instruction set and basic exception handling. Contains implementations for two microarchitectures: a single-cycle core, and a 5-stage pipelined core (IF, ID, EX, MEM, WB) with full hazard handling via forwarding, flushes and stalls, and an instruction cache in front of a slow instruction memory.

The design is verified by self-checking testbenches using Python and cocotb. There are unit tests that verify each module against a Python reference model and integration tests which run hex programs on each core and check the final architectural state.

## Features

- Full RV32I base integer instruction set with basic exception handling
- Single-cycle core and 5-stage pipelined core built from the same shared modules (ALU, comparator, controller, immediate decoder, register file, LSU, data memory and machine CSRs).
- Pipeline hazard handling:
  - Forwarding from the MEM and WB stages to EX, with the newer result taking priority, and no forwarding from writes to `x0`.
  - Load-use hazard detection with a one-cycle stall.
  - Branches and jumps resolved in EX, flushing the wrongly fetched instructions.
  - Exceptions are taken in MEM (to allow easy addition of e.g. memory faults in the future), flushing the wrongly fetched instructions.
  - Instruction cache misses stall IF and send bubbles into ID, while the older instructions carry on.
- Pipeline instruction cache:
  - Read-only and direct-mapped, with one word per line and a configurable number of lines.
  - A cache controller looks up each fetch and, on a miss, refills the line from an instruction memory with a configurable latency and a valid/ready interface.
  - Memory responses only ever fill the cache, and the fetch is then retried as a lookup, so a PC redirect during a refill needs no special handling.
- Machine-mode exceptions: illegal instruction, misaligned instruction
  address, misaligned load and store addresses, `ECALL` and `EBREAK`. On a trap, `mepc` and `mcause` are recorded and execution jumps to `mtvec` (direct mode only); `MRET` returns to `mepc`.
- Byte, half-word and word loads and stores, with sign or zero extension.
- Instruction and data memories initialised from hex files, with a configurable depth. The single-cycle core reads its instruction memory asynchronously, while the pipelined core's responds after a configurable latency.
- FST waveform traces for every simulation run.

Software CSR access (i.e., the Zicsr extension) is not yet implemented, so the
machine CSRs are written only on trap entry. `FENCE` is treated as a no-op since the data memory module guarantees that queries are fulfilled in order.

## Repository organisation

- `rtl/pkg/`: shared SystemVerilog packages (types, exception codes, ALU, LSU
  and controller encodings).
- `rtl/common/`: synthesisable modules shared by both cores.
- `rtl/single_cycle/`: single-cycle datapath, core, exception unit and top
  level.
- `rtl/pipeline/`: pipelined datapath, core, hazard unit, exception unit and
  top level.
- `tb/models/`: Python reference models used by the unit tests.
- `tb/common/`, `tb/single_cycle/`, `tb/pipeline/`: cocotb testbenches. The
  pipeline integration tests run under several instruction memory latencies and
  cache sizes.
- `tb/programs.py`: test programs and the architectural state each one must
  leave behind.
- `hex/instr/`, `hex/data/`: instruction and data memory images.
- `scripts/`: commands for running the unit, single-cycle, pipeline or all
  tests.
- `Makefile`: cocotb build and test targets.
- `build/`: generated simulation builds and waveform traces.

## Dependencies

The project requires:

- Python 3 with [cocotb](https://www.cocotb.org/) 2.x
- Verilator 5.036+
- GNU Make and Bash

Run every test with `./scripts/run_all_tests.sh`, or a single module or core
with, for example, `make TEST=alu` or `make ARCH=pipeline`. Top-level parameters
can be overridden for either, for example
`make ARCH=pipeline PARAMS="INSTR_MEM_LATENCY=1 ICACHE_NUM_LINES=2"`.

## Repository history note

The original Git metadata for this project was accidentally lost during development
(October 2026). The commit history in this repository was reconstructed from surviving
shell history (the original `git add`/`git commit` commands and messages) and editor-local
file snapshots.

- The sequence of commits and their messages follow the original command history.
- File contents at each commit were taken from historical snapshots. Where a snapshot did
  not exist, a later surviving version was used. Each such case is documented in the
  recovery notes.
- The original objects could not be recovered byte for byte. The commits therefore have
  new hashes, and their dates are the reconstruction time, not the original commit times.
