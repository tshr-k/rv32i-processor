# Misaligned loads, stores and jump targets, each of which traps to the handler at mtvec = 0x04
# The handler counts the trap in x31, aligns the base register x6 and returns to retry the instruction
.section .text
.globl _start

_start:
    jal  x0, main
handler:
    addi x31, x31, 1     # Trap count
    andi x6, x6, -4      # Align the base address
    mret
    addi x30, x30, 1     # Wrong path after mret
    addi x30, x30, 1     # Wrong path after mret
main:
    addi x10, x0, 0x55
    sw   x10, 0x20(x0)   # mem[0x20] = 0x55
    addi x6, x0, 0x21    # Older than the trapping load, so must still be written back
    lw   x7, 0(x6)       # Traps once, then x7 = 0x55
    addi x8, x7, 1       # Load-use stall before the trap, then runs once: x8 = 0x56
    addi x6, x0, 0x23
    lh   x9, 0(x6)       # Traps once, then x9 = 0x55
    addi x11, x0, 0x66
    addi x6, x0, 0x26
    sw   x11, 0(x6)      # Traps once, then mem[0x24] = 0x66
    addi x6, x0, 0x2b
    sh   x11, 0(x6)      # Traps once, then mem[0x28] = 0x66
    auipc x6, 0
    addi x6, x6, 18      # Target has bit 1 set
    jalr x12, 0(x6)      # Traps once, then jumps to the aligned target
    addi x13, x13, 1     # Skipped
    addi x14, x0, 1      # Aligned target: x14 = 1
1:
    jal  x0, 1b          # Halt
