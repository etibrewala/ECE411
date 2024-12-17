.section .text
.globl _start
_start:
    addi x1, x0, 4
    nop             # nops in between to prevent hazard
    nop
    nop

    addi x2, x0, 5
    nop
    nop
    nop
    nop
    nop

    addi x3, x1, 8
    nop
    nop
    nop
    nop
    nop

    xor x8, x1, x3
    nop
    nop

    sub x5,x3,x1
    nop
    nop
    nop
    srai x3, x6, 20
    nop
    nop
    nop
    nop
    nop

    slti x0, x0, -256 # this is the magic instruction to end the simulation
