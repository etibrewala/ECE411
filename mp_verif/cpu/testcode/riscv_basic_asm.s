# .section .data
# .data
#     jump_target1: .word 0x00000000
#     jump_target2: .word 0x00000000

.section .text
.globl _start

_start:

    auipc   x1 , 0
    lui     x2 , 0xAA55A
    addi    x3 , x1, 1
    add     x4 , x1, x2
    lw      x5, 4(x1)
    sw      x2, 0(x1)

    add     x5, x1, x1
    add     x6, x2, x1

    add x4, x1, x2       # Add
    sub x5, x4, x3       # Subtract

    and x6, x4, x5       # Bitwise AND
    or x7, x5, x6        # Bitwise OR

    xor x8, x7, x6       # Bitwise XOR
    sll x9, x8, x7       # Shift Left Logical
    srl x10, x9, x8      # Shift Right Logical

    andi x2, x3, 4
    andi x3,x3, 0

    andi x4,x5,0
    andi x6,x5,0

    addi x2, x4, 4 # x2 =x41 4m
    addi x3, x4, 4


    bge x3, x2, label1   # Branch if Equal
    add x4,x1,x2
    add x5,x4,x3
    bne x3, x4, label2   # Branch if Not Equal

label1:
    addi x12, x11, 0x000 # Add Immediate
    sw x12, 0(x1)        # Store Word (4-byte aligned)

label2:
    # lw x13, 0x4(x2)      # Load Word (4-byte aligned)
    addi x14, x13, -1    # Add Immediate (decrement)

    or x2,x2,x8
    ori x2,x2,1704

    sltu x6,x6,x30
    auipc x13, 315504
    sb x6, 1014(x0)
    sra x13,x13,x30
    srli x30,x30,10

    bne     x1, x2, end
    nop

end:
    slti x0, x0, -256
