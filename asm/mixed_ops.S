# Sum 1..5 in a loop, then exercise lui/ori, sub, shifts, sw/lb/lh and jal
.equ DATA_BASE, 0x80000200  # mem[] offsets in the comments below are relative to DATA_BASE

.section .text
.globl _start

_start:
    li   x31, DATA_BASE  # Data base address, clear of the code
    addi x1, x0, 5
    addi x2, x0, 0
loop:
    add  x2, x2, x1
    addi x1, x1, -1
    bne  x1, x0, loop
    lui  x3, 0x12345
    ori  x3, x3, 0x678
    sub  x4, x0, x2
    srai x5, x4, 2
    slli x6, x2, 4
    sw   x3, 4(x31)
    lb   x7, 4(x31)
    lh   x8, 6(x31)
    jal  x9, skip
    addi x10, x0, 1      # Skipped
skip:
    jal  x0, skip        # Halt
