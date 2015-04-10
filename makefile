C_FILES := leds.c
P_FILES := leds.p
DTS_FILES := ten_by_ten-00A0.dts

CC := gcc
LD := gcc
STRIP := strip
PASM := pasm
DTC := dtc

C_FLAGS += -Wall -O2 -mtune=cortex-a8 -march=armv7-a -std=gnu99
#C_FLAGS += -I$(PRU_SDK_DIR)/include
#L_FLAGS += -L$(PRU_SDK_DIR)/lib
L_LIBS += -lprussdrv

BIN_FILES := $(P_FILES:.p=.bin)
O_FILES := $(C_FILES:.c=.o)
DTBO_FILES := $(DTS_FILES:.dts=.dtbo)

all:	leds.exe $(BIN_FILES) $(DTBO_FILES)

leds.exe:	$(O_FILES)
	$(LD) -static -o $@ $(O_FILES) $(L_FLAGS) $(L_LIBS)
	$(STRIP) $@

%.bin : %.p
	$(PASM) -V2 -I./ -b $<

%.o : %.c
	$(CC) $(C_FLAGS) -c -o $@ $<

%.dtbo : %.dts
	$(DTC) -@ -O dtb -o $@ $<

.PHONY	: clean all
clean	:
	-rm -f $(O_FILES)
	-rm -f $(BIN_FILES)
	-rm -f $(DTBO_FILES)
	-rm -f main
