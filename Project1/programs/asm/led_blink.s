.text
main:
    addi x8, x0, 200
color_loop:
    lui x5, 0x00ff0
    sw x5, -4(x0)
    jal x1, delay
    addi x5, x0, -256
    sw x5, -4(x0)
    jal x1, delay
    lui x5, 0x00010
    addi x5, x5, -256
    sw x5, -4(x0)
    jal x1, delay
    lui x5, 0xff010
    addi x5, x5, -1
    sw x5, -4(x0)
    jal x1, delay
    addi x5, x0, 255
    sw x5, -4(x0)
    jal x1, delay
    lui x5, 0xffff0
    addi x5, x5, 255
    sw x5, -4(x0)
    jal x1, delay
    jal x0, color_loop
delay:
    lw x6, -8(x0)
delay_loop:
    lw x7, -8(x0)
    sub x7, x7, x6
    bltu x7, x8, delay_loop
    jalr x0, 0(x1)
