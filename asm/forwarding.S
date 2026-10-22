# Data hazards between ALU-type instructions, resolved by forwarding to EX (no stalls needed)
# In the pipeline, the instruction n places earlier is in MEM (n = 1) or WB (n = 2) when this one is in EX,
# and the register file writes through from WB to ID for n = 3
.equ DATA_BASE, 0x80000200  # mem[] offsets in the comments below are relative to DATA_BASE

.section .text
.globl _start

_start:
    li   x31, DATA_BASE  # Data base address, clear of the code
    addi x1, x0, 10      # x1 = 10
    addi x2, x1, 5       # rs1 from MEM: x2 = 15
    add  x3, x1, x2      # rs1 from WB, rs2 from MEM: x3 = 25
    sub  x4, x3, x1      # rs1 from MEM, rs2 through the register file: x4 = 15
    addi x5, x0, 1       # x5 = 1
    addi x5, x5, 2       # x5 = 3
    addi x5, x5, 4       # Newer x5 in MEM beats older x5 in WB: x5 = 7
    add  x6, x5, x5      # Both operands from MEM: x6 = 14
    lui  x7, 0x12345     # Result is the immediate
    addi x7, x7, 0x678   # Immediate forwarded from MEM: x7 = 0x12345678
    auipc x8, 0          # x8 = 0x80000030
    addi x8, x8, 4       # x8 = 0x80000034
    addi x9, x0, 0x55
    sw   x9, 8(x31)      # Store data from MEM: mem[0x08] = 0x55
    addi x10, x31, 0x20  # x10 = DATA_BASE + 0x20
    addi x11, x0, 0x66
    sw   x11, 0(x10)     # Address base from WB, store data from MEM: mem[0x20] = 0x66
    lw   x12, 8(x31)     # x12 = 0x55
    lw   x13, 0(x10)     # x13 = 0x66
    addi x14, x0, 3
    addi x15, x0, 3
    beq  x14, x15, b1    # rs1 from WB, rs2 from MEM: taken
    addi x16, x16, 1     # Skipped
b1:
    addi x17, x0, 7
    bne  x17, x0, b2     # rs1 from MEM: taken
    addi x16, x16, 1     # Skipped
b2:
    addi x18, x0, 1
    beq  x18, x0, b3     # rs1 from MEM: not taken
    addi x19, x0, 9      # x19 = 9
b3:
    auipc x20, 0         # x20 = 0x8000007c
    addi x20, x20, 16    # x20 = 0x8000008c
    jalr x21, 0(x20)     # Base from MEM: x21 = 0x80000088
    addi x16, x16, 1     # Skipped
    addi x22, x21, 0     # Link register through the register file: x22 = 0x80000088
    jal  x23, j1         # x23 = 0x80000094
    addi x16, x16, 1     # Skipped
j1:
    addi x24, x23, 4     # x24 = 0x80000098
1:
    jal  x0, 1b          # Halt
