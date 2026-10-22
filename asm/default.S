# Default program loaded into the instruction memory
.equ DATA_BASE, 0x80000200  # mem[] offsets in the comments below are relative to DATA_BASE

.section .text
.globl _start

_start:
    li   x31, DATA_BASE  # Data base address, clear of the code
    addi x1, x0, 1
    addi x2, x0, 2
    add  x3, x1, x2
    sw   x3, 0(x31)
    lw   x2, 0(x31)
1:
    jal  x0, 1b
