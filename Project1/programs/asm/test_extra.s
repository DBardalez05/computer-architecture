.text
    addi x1, x0, -16
    addi x2, x0, 0x5A
    and x3, x1, x2
    or x4, x1, x2
    xor x5, x1, x2
    andi x6, x2, 0x0F
    slli x7, x2, 4
    srl x8, x1, x2
    sra x9, x1, x2
    slti x10, x1, -15
    sltiu x11, x2, -1
    fence 15, 15
    sw x4, 0x100(x0)
    sh x2, 0x104(x0)
    sh x7, 0x106(x0)
    lw x12, 0x100(x0)
    lw x13, 0x104(x0)
    bne x2, x2, bne_taken
    addi x14, x0, 1
bne_taken:
    bne x1, x2, bge_false
    addi x14, x0, 99
bge_false:
    bge x1, x2, bge_taken
    addi x15, x0, 2
bge_taken:
    bge x2, x1, bgeu_false
    addi x15, x0, 99
bgeu_false:
    bgeu x2, x1, bgeu_taken
    addi x16, x0, 3
bgeu_taken:
    bgeu x1, x2, jump_test
    addi x16, x0, 99
jump_test:
    jal x0, after_jump
    addi x17, x0, 99
after_jump:
    addi x17, x0, 4
    addi x0, x0, 5
    lui x18, 0xABCDE
    auipc x19, 0
    jalr x19, 13(x19)
    addi x20, x0, 99
    addi x20, x0, 5
