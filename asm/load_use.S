# Loads whose results are used by the next instruction, which must stall for a cycle before
# the load data can be forwarded from WB
.equ DATA_BASE, 0x80000200  # mem[] offsets in the comments below are relative to DATA_BASE

.section .text
.globl _start

_start:
    li   x31, DATA_BASE  # Data base address, clear of the code
    addi x1, x0, -2      # x1 = 0xfffffffe
    sw   x1, 0(x31)      # mem[0x00] = 0xfffffffe
    addi x2, x31, 0x40   # x2 = DATA_BASE + 0x40
    sw   x2, 4(x31)      # mem[0x04] = DATA_BASE + 0x40
    addi x3, x0, 0x7f
    sw   x3, 0x40(x31)   # mem[0x40] = 0x7f
    lw   x4, 0(x31)      # x4 = 0xfffffffe
    addi x5, x4, 3       # Load-use on rs1: x5 = 1
    lw   x6, 4(x31)      # x6 = DATA_BASE + 0x40
    lw   x7, 0(x6)       # Load-use on the address: x7 = 0x7f
    add  x8, x0, x7      # Load-use on rs2: x8 = 0x7f
    lw   x9, 0(x31)      # x9 = 0xfffffffe
    sw   x9, 8(x31)      # Load-use on the store data: mem[0x08] = 0xfffffffe
    lw   x10, 4(x31)     # x10 = DATA_BASE + 0x40
    addi x11, x0, 1      # Independent, so no stall
    add  x12, x10, x11   # Load data from WB: x12 = DATA_BASE + 0x41
    lb   x13, 0(x31)     # x13 = 0xfffffffe
    beq  x13, x4, l1     # Load-use on a branch: taken
    addi x14, x14, 1     # Skipped
l1:
    lbu  x15, 0(x31)     # x15 = 0xfe
    lhu  x16, 0(x31)     # x16 = 0xfffe
    lh   x17, 2(x31)     # x17 = 0xffffffff
    sub  x18, x16, x15   # x16 from WB, x15 through the register file: x18 = 0xff00
    auipc x19, 0         # x19 = 0x80000064
    addi x19, x19, 24    # x19 = 0x8000007c
    sw   x19, 12(x31)    # mem[0x0c] = 0x8000007c
    lw   x20, 12(x31)    # x20 = 0x8000007c
    jalr x21, 0(x20)     # Load-use on a jump target: x21 = 0x80000078
    addi x14, x14, 1     # Skipped
    addi x22, x0, 1      # x22 = 1
1:
    jal  x0, 1b          # Halt
