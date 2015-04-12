#include <pru.h>

#define PRU0_CTRL   0x22000
#define PRU1_CTRL   0x24000

#define CTPPR0      0x28
#define CTPPR1      0x2C 

#define OWN_RAM     0x000
#define OTHER_RAM   0x020
#define SHARED_RAM  0x100
#define DDR_OFFSET  0

#define ADDR_SHARED_RAM 0x80000000
#define ADDR_DDR_RAM    0xc0000000

#define GPIO0_CLOCK 0x44e00408
#define GPIO1_CLOCK 0x44e000ac
#define GPIO2_CLOCK 0x44e000b0

#define BIT_A       0
#define BIT_A_RST   1
#define BIT_B       2
#define BIT_B_RST   3

#define BIT_CLK     25

#define NUM_COLUMNS 10
#define NUM_ROWS    10

#define RET_REG     r28.w0

#define rRowCount   r8
#define rColCount   r9
#define rPixelCount r10
#define rPixel      r11

#include "led_macros.p"

.macro ColumnReset
    IOLow   GPIO1, BIT_A_RST
    IOLow   GPIO1, BIT_B_RST

    IOHigh  GPIO1, BIT_A_RST
    IOHigh  GPIO1, BIT_B_RST
.endm

.setcallreg RET_REG

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

    // latch clock high
    ClockInit

    OutputDisableR
    OutputDisableG
    OutputDisableB

    LatchDisableR
    LatchDisableG
    LatchDisableB

    // FIXME
    mov     r5, 0
copy_frame:
    ldi     r0.w0, ADDR_DDR_RAM & 0xFFFF
    ldi     r0.w1, ADDR_DDR_RAM >> 16

    ldi     r1.w0, ADDR_SHARED_RAM & 0xFFFF
    ldi     r1.w1, ADDR_SHARED_RAM >> 16

    ldi     r2, NUM_ROWS * NUM_COLUMNS * 4 / (16 * 4)
copy_frame_loop: 
    // copy some bytes to shared RAM
    lbbo    r8, r0, 0, 16 * 4
    sbbo    r8, r1, 0, 16 * 4

    add     r0, r0, 16 * 4
    add     r1, r1, 16 * 4

    dec     r2
    qbne    copy_frame_loop, r2, 0

    // FIXME
    inc     r5

    // check for kill signal
    lbco    r0, CONST_DDR, 0, 4
    qbne    die, r0.b3, 0

    jmp     copy_frame

next_frame:
    mov     rPixelCount, 0
    mov     rColCount, 0
    
next_column:
    LatchDisableR
    LatchDisableG
    LatchDisableB

    mov     rRowCount, 0
pixel_write:
    // calculate byte offset
    lsl     r0, rPixelCount, 2 // multiply by 4

    mov     r1, ADDR_DDR_RAM
    add     r0, r0, r1
    lbbo    rPixel, r0, 0, 4
    
    qbbs    pixel_write_0, rPixel.b2, 7
pixel_write_1:
    set     r30, rRowCount
    jmp     pixel_write_done
pixel_write_0:
    clr     r30, rRowCount
pixel_write_done:
    inc     rRowCount
    inc     rPixelCount
    qbne    pixel_write, rRowCount, NUM_ROWS

column_done:
    // drive column
    mov     r0, rColCount
    call    col_enable

    // enable outputs
    LatchEnableR
    LatchEnableG
    LatchEnableB

    OutputEnableR
    OutputEnableG
    OutputEnableB

    // check for kill signal
    lbco    r0, CONST_DDR, 0, 4
    qbne    die, r0.b3, 0

    // FIXME
    Delay   LONG_TIME / 256
    
    // check for end of frame
    inc     rColCount
    qbne    next_column, rColCount, NUM_COLUMNS

    jmp     next_frame

die:
    // leds off
    ColumnReset

    // FIXME
    // save return val
    mov     r0, ADDR_DDR_RAM
    sbbo    r5, r0, 0, 4
    
    // notify host program of finish
    mov     r31.b0, PRU0_ARM_INTERRUPT + 16
    halt

// ********************
col_enable:
    // save column to enable
    mov     r7, r0
    
    IOLow   GPIO1, BIT_A
    IOLow   GPIO1, BIT_B

    ColumnReset

    qblt    col_enable_big, r7, 7

col_enable_small:
col_enable_write_small_1:
    IOHigh  GPIO1, BIT_A
    ClockOut
    qbeq    col_enable_write_small_done, r7, 0

    IOLow   GPIO1, BIT_A
col_enable_write_small_0:
    ClockOut
    dec     r7
    qbne    col_enable_write_small_0, r7, 0
col_enable_write_small_done:
    ret
    
col_enable_big:
    sub     r7, r7, 8
col_enable_write_big_1:
    IOHigh  GPIO1, BIT_B
    ClockOut
    qbeq    col_enable_write_big_done, r7, 0

    IOLow   GPIO1, BIT_B
col_enable_write_big_0:
    ClockOut
    dec     r7
    qbne    col_enable_write_big_0, r7, 0
col_enable_write_big_done:
    ret
