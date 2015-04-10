#include <pru.h>

#define PRU0_CTRL   0x22000
#define PRU1_CTRL   0x24000

#define CTPPR0      0x28
#define CTPPR1      0x2C

#define OWN_RAM     0x000
#define OTHER_RAM   0x020
#define SHARED_RAM  0x100
#define DDR_OFFSET  0

#define GPIO0_CLOCK 0x44e00408
#define GPIO1_CLOCK 0x44e000ac
#define GPIO2_CLOCK 0x44e000b0

#define BIT_A       0
#define BIT_A_RST   1
#define BIT_B       2
#define BIT_B_RST   3

#define BIT_CLK     25

#include "led_macros.p"

.origin 0

start:
    // enable OCP master port
    lbco    r0, CONST_PRUCFG, 4, 4
    clr     r0, r0, 4
    sbco    r0, CONST_PRUCFG, 4, 4

    // map shared RAM
    mov     r0, SHARED_RAM
    mov     r1, PRU1_CTRL + CTPPR0
    sbbo    r0, r1, 0, 4

    // map ddr
    mov     r0, DDR_OFFSET << 8
    mov     r1, PRU1_CTRL + CTPPR1
    sbbo    r0, r1, 0, 4

    // unsuspend the GPIO clocks
    StartClocks

draw:
    // rows

    OutputEnableB
    Delay   LONG_TIME
    OutputDisableB
    Delay   LONG_TIME
    
    // column

    jal     r25, col_reset

    LBCO    r0, CONST_DDR, 0, 12
    lbco    r0, CONST_DDR, 0, 4
    jal     r25, col_write

    // notify host program of finish
    mov     r31.b0, PRU0_ARM_INTERRUPT + 16
    halt

col_reset:
    mov     r1, GPIO1 | GPIO_CLEARDATAOUT
    mov     r0, 1 << BIT_A_RST
    sbbo    r0, r1, 0, 4
    mov     r0, 1 << BIT_B_RST
    sbbo    r0, r1, 0, 4

    mov     r1, GPIO1 | GPIO_SETDATAOUT
    mov     r0, 1 << BIT_A_RST
    sbbo    r0, r1, 0, 4
    mov     r0, 1 << BIT_B_RST
    sbbo    r0, r1, 0, 4

    jmp     r25

col_write:
    mov     r2, r0
    mov     r3, 0

col_write_next:
    qbbs    col_write_1, r2, 0
    
col_write_0:
    mov     r1, GPIO1 | GPIO_CLEARDATAOUT
    qba     col_write_done
col_write_1:
    mov     r1, GPIO1 | GPIO_SETDATAOUT
col_write_done:
    // clock out bit
    mov     r0, 1<<BIT_A
    sbbo    r0, r1, 0, 4
    clockOut

    lsr     r2, r2, 1   // next bit
    add     r3, r3, 1   // count bits

    qbne    col_write_next, r3, 8

    jmp     r25
