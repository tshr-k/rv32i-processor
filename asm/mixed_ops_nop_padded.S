# Same program as mixed_ops.S, padded with NOPs so that a 5-stage pipeline
# without forwarding, stalling or flushing runs it correctly:
#   - Two NOPs between dependent instructions, as the register file writes through from WB to ID
#   - Two NOPs after branches and jumps, which resolve in EX, so the wrong-path fetches are harmless
.equ DATA_BASE, 0x80000200  # mem[] offsets in the comments below are relative to DATA_BASE

.section .text
.globl _start

_start:
    li   x31, DATA_BASE  # Data base address, clear of the code
    addi x1, x0, 5
    nop
    nop
    addi x2, x0, 0
loop:
    add  x2, x2, x1
    addi x1, x1, -1
    nop
    nop
    bne  x1, x0, loop
    nop
    nop
    lui  x3, 0x12345
    nop
    nop
    ori  x3, x3, 0x678
    sub  x4, x0, x2
    nop
    nop
    srai x5, x4, 2
    slli x6, x2, 4
    sw   x3, 4(x31)
    lb   x7, 4(x31)
    lh   x8, 6(x31)
    jal  x9, skip
    nop
    nop
    addi x10, x0, 1      # Skipped
skip:
    jal  x0, skip        # Halt
    nop
    nop
