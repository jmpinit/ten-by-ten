#define BIT_R_OE        15      // gpio1[15]
#define BIT_G_OE_FAST   r30.t12 // gpio1[30] or r30.t12
#define BIT_B_OE_FAST   r30.t13 // gpio1[31] or r30.t13

#define BIT_R_LE        12 // gpio1[12]
#define BIT_G_LE        13 // gpio1[13]
#define BIT_B_LE        14 // gpio1[14]

#define LONG_TIME       0xf00000

.macro Delay
.mparam len
    mov     r0, len
delay_loop:
    sub     r0, r0, 1
    qbne    delay_loop, r0, 0
.endm

// value to set pin on gpio high into r0
.macro IOHigh
.mparam gpio, bit
    mov     r0, gpio | GPIO_SETDATAOUT
    mov     r1, 1 << bit
    sbbo    r1, r0, 0, 4
.endm

// value to set pin on gpio low into r0
.macro IOLow
.mparam gpio, bit
    mov     r0, gpio | GPIO_CLEARDATAOUT
    mov     r1, 1 << bit
    sbbo    r1, r0, 0, 4
.endm

// LEs

.macro LatchEnableR
    IOLow   GPIO1, BIT_R_LE
.endm

.macro LatchDisableR
    IOHigh  GPIO1, BIT_R_LE
.endm

.macro LatchEnableG
    IOLow   GPIO1, BIT_G_LE
.endm

.macro LatchDisableG
    IOHigh  GPIO1, BIT_G_LE
.endm

.macro LatchEnableB
    IOLow   GPIO1, BIT_B_LE
.endm

.macro LatchDisableB
    IOHigh  GPIO1, BIT_B_LE
.endm

// OEs (active low)

.macro OutputEnableR
    IOLow   GPIO1, BIT_R_OE
.endm

.macro OutputDisableR
    IOHigh  GPIO1, BIT_R_OE
.endm

.macro OutputEnableG
    clr     BIT_G_OE_FAST
.endm

.macro OutputDisableG
    set     BIT_G_OE_FAST
.endm

.macro OutputEnableB
    clr     BIT_B_OE_FAST
.endm

.macro OutputDisableB
    set     BIT_B_OE_FAST
.endm

.macro StartClocks
    mov     r0, 1 << 1 // set bit 1 in reg to enable clock
    mov     r1, GPIO0_CLOCK
    sbbo    r0, r1, 0, 4
    mov     r1, GPIO1_CLOCK
    sbbo    r0, r1, 0, 4
    mov     r1, GPIO2_CLOCK
    sbbo    r0, r1, 0, 4
.endm

.macro writeRow
.mparam row
    mov     r0.w0, r30.w0

    // clear the lower 10 bits
    ldi     r1.w0, 0xfc00
    and     r0.w0, r0.w0, r1.w0

    // set the lower 8
    mov     r0.b0, row & 0xFF
    // set 9 and 10
    or      r0.b1, r0.b1, 0x3//(row >> 8) & 0x3

    mov     r30.w0, r0.w0
.endm

.macro clockOut
    mov     r0, 1<<25
    mov     r1, GPIO2 | GPIO_CLEARDATAOUT
    sbbo    r0, r1, 0, 4
    mov     r1, GPIO2 | GPIO_SETDATAOUT
    sbbo    r0, r1, 0, 4
.endm
