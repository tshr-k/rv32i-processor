# An ecall, which must trap to the handler at mtvec = 0x04 while older instructions complete
# and younger ones are squashed
.section .text
.globl _start

_start:
    jal  x0, main
handler:
    jal  x0, handler     # Halt
main:
    addi x1, x0, 1       # x1 = 1
    addi x2, x0, 2       # x2 = 2
    ecall
    sw   x1, 0(x0)       # Squashed
    addi x3, x0, 3       # Squashed
    addi x4, x0, 4       # Squashed
1:
    jal  x0, 1b          # Halt
