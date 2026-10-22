# Taken and not-taken branches for every condition, a loop, and a call and return
# Wrong-path instructions increment x31, which must remain zero
.section .text
.globl _start

_start:
    addi x1, x0, -1      # x1 = 0xffffffff
    addi x2, x0, 1       # x2 = 1
    beq  x1, x1, t1      # Taken
    addi x31, x31, 1
    addi x31, x31, 1
t1:
    bne  x1, x2, t2      # Taken
    addi x31, x31, 1
    addi x31, x31, 1
t2:
    blt  x1, x2, t3      # Taken (-1 < 1)
    addi x31, x31, 1
    addi x31, x31, 1
t3:
    bltu x2, x1, t4      # Taken (1 < 0xffffffff)
    addi x31, x31, 1
    addi x31, x31, 1
t4:
    bge  x2, x1, t5      # Taken (1 >= -1)
    addi x31, x31, 1
    addi x31, x31, 1
t5:
    bgeu x1, x2, t6      # Taken (0xffffffff >= 1)
    addi x31, x31, 1
    addi x31, x31, 1
t6:
    beq  x1, x2, fail    # Not taken
    addi x30, x30, 1
    bne  x1, x1, fail    # Not taken
    addi x30, x30, 1
    blt  x2, x1, fail    # Not taken
    addi x30, x30, 1
    bltu x1, x2, fail    # Not taken
    addi x30, x30, 1
    bge  x1, x2, fail    # Not taken
    addi x30, x30, 1
    bgeu x2, x1, fail    # Not taken
    addi x30, x30, 1     # x30 = 6
    addi x3, x0, 4
loop:
    addi x4, x4, 3
    addi x3, x3, -1
    bne  x3, x0, loop    # x4 = 12
    jal  x5, func        # x5 = 0x80000094
    addi x6, x6, 1       # Runs once, after the return: x6 = 1
    jal  x0, done
    addi x31, x31, 1
    addi x31, x31, 1
func:
    addi x7, x0, 0x77    # x7 = 0x77
    jalr x0, 0(x5)       # Return
    addi x31, x31, 1
    addi x31, x31, 1
done:
    jal  x0, done        # Halt
fail:
    addi x29, x0, 1
1:
    jal  x0, 1b          # Halt
