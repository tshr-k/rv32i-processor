# An illegal instruction that would write a register, which must trap to the handler at mtvec = 0x04
# without writing back, while older instructions complete and younger ones are squashed
.section .text
.globl _start

_start:
    jal  x0, main
handler:
    jal  x0, handler     # Halt
main:
    addi x1, x0, 1       # x1 = 1
    addi x2, x0, 2       # x2 = 2
    addi x8, x0, 0x5a    # x8 = 0x5a
    .word 0x02208433     # mul x8, x1, x2 (illegal without the M extension)
    sw   x1, 0(x0)       # Squashed
    addi x3, x0, 3       # Squashed
    addi x4, x0, 4       # Squashed
1:
    jal  x0, 1b          # Halt
