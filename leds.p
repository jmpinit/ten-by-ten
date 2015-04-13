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
#define ADDR_DDR_RAM_L  0x0000
#define ADDR_DDR_RAM_H  0xc000

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
#define COLOR_DEPTH 1

#define RET_REG     r28.w0

#define rRowCount   r8
#define rColCount   r9
#define rPixelCount r10
#define rPixel      r11
#define rSlicesLeft r12
#define rAddrTiming r26 // needs to be >24 to survive image copy

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

    mov     rAddrTiming, ADDR_DDR_RAM
    mov     r0, NUM_ROWS * NUM_COLUMNS * 4
    add     rAddrTiming, rAddrTiming, r0

copy_image:
    mov     r0, ADDR_DDR_RAM
    mov     r1, rAddrTiming

    mov     r2, NUM_ROWS * NUM_COLUMNS * 4 / (16 * 4)
copy_image_loop: 
    // copy some bytes to shared RAM
    lbbo    r8, r0, 0, 16 * 4
    sbbo    r8, r1, 0, 16 * 4

    // move to next chunk
    add     r0, r0, 16 * 4
    add     r1, r1, 16 * 4

    // count down by one
    dec     r2
    qbne    copy_image_loop, r2, 0

display_frame:
    mov     rSlicesLeft, 1 << COLOR_DEPTH
    set     r30, 10 // debug - indicate start
next_slice:
    mov     rPixelCount, 0
    mov     rColCount, 0
    
next_column:
    // drive column
    mov     r0, rColCount
    call    col_enable

    OutputDisableR
    OutputDisableG
    OutputDisableB

    LatchDisableR
    LatchDisableG
    LatchDisableB

    mov     rRowCount, 0
next_pixel:
    // load the pixel data

    // calculate byte offset
    lsl     r0, rPixelCount, 2 // multiply by 4
    add     r0, r0, rAddrTiming

    // load it
    lbbo    rPixel, r0, 0, 4
    
pixel_red:
    qbeq    pixel_red_off, rPixel.b2, 0 // finished being on?
    clr     r30, rRowCount // LED on
    dec     rPixel.b2 // one less time slice of being on
    jmp     pixel_green
pixel_red_off:
    set     r30, rRowCount // LED off

pixel_green:
    LatchEnableR
    OutputEnableR

    qbeq    pixel_green_off, rPixel.b1, 0 // finished being on?
    clr     r30, rRowCount // LED on
    dec     rPixel.b1 // one less time slice of being on
    jmp     pixel_blue
pixel_green_off:
    set     r30, rRowCount // LED off

pixel_blue:
    LatchEnableG
    //OutputEnableG

    qbne    pixel_blue_off, rPixel.b0, 0 // finished being on?
    clr     r30, rRowCount // LED on
    dec     rPixel.b0 // one less time slice of being on
    jmp     pixel_done
pixel_blue_off:
    set     r30, rRowCount // LED off

pixel_done:
    LatchEnableB
    OutputEnableB

    // save the decremented counts
    sbbo    rPixel, r0, 0, 4

    // move to the next
    inc     rRowCount
    inc     rPixelCount

    qbne    next_pixel, rRowCount, NUM_ROWS

column_done:
    // check for kill signal
    lbco    r0, CONST_DDR, 0, 4
    qbne    die, r0.b3, 0

    // check for end of slice
    inc     rColCount
    qbne    next_column, rColCount, NUM_COLUMNS

    // FIXME
    Delay   LONG_TIME / 1024

    dec     rSlicesLeft
    qbne    next_slice, rSlicesLeft, 0

    clr     r30, 10 // debug - indicate end

    // FIXME
    //Delay   LONG_TIME / 256

    jmp     copy_image

die:
    // leds off
    ColumnReset

    // FIXME
    // save return val
    mov     r0, ADDR_DDR_RAM
    mov     r5, r0

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
