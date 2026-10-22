# Writes to x0, which must be discarded, so later reads of x0 must still see zero
# rather than a value forwarded from MEM or WB
.equ DATA_BASE, 0x80000200  # mem[] offsets in the comments below are relative to DATA_BASE

.section .text
.globl _start

_start:
    li   x31, DATA_BASE  # Data base address, clear of the code
    addi x0, x0, 5       # Discarded
    add  x1, x0, x0      # Both operands with x0 in MEM: x1 = 0
    addi x0, x0, 6       # Discarded
    addi x2, x0, 1       # x2 = 1
    add  x3, x0, x2      # rs1 with x0 in WB: x3 = 1
    lui  x0, 0x12345     # Discarded
    addi x4, x0, 2       # x4 = 2
    addi x5, x31, 0x40   # x5 = DATA_BASE + 0x40
    sw   x5, 0(x5)       # mem[0x40] = DATA_BASE + 0x40
    lw   x0, 0(x5)       # Discarded
    addi x6, x0, 3       # Load-use on x0: x6 = 3
    addi x0, x0, 9       # Discarded
    sw   x0, 4(x5)       # Store data with x0 in MEM: mem[0x44] = 0
    addi x0, x0, 1       # Discarded
    beq  x0, x7, b1      # Taken, as x7 = 0
    addi x8, x8, 1       # Skipped
b1:
    jal  x0, b1          # Halt
