#include <stdio.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>

#include "prussdrv.h"
#include <pruss_intc_mapping.h>

#define PRU_NUM 	 1

#define DDR_BASEADDR    0x80000000

#define PRUSS_SHARED_DATARAM    4

static int mem_fd;
static void *ddrMem, *sharedMem;

static unsigned int *sharedMem_int;

int main (void) {
    tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

    // init pru driver
    prussdrv_init();

    // open PRU interrupt
    int ret = prussdrv_open(PRU_EVTOUT_0);
    if (ret) {
        printf("prussdrv_open open failed\n");
        return ret;
    }

    // init interrupt
    prussdrv_pruintc_init(&pruss_intc_initdata);

    // open memory device
    mem_fd = open("/dev/mem", O_RDWR);
    if (mem_fd < 0) {
        printf("Failed to open /dev/mem (%s)\n", strerror(errno));
        return -1;
    }

    // map the DDR memory
    ddrMem = mmap(0, 0x0FFFFFFF, PROT_WRITE | PROT_READ, MAP_SHARED, mem_fd, DDR_BASEADDR);

    if (ddrMem == NULL) {
        printf("Failed to map the device (%s)\n", strerror(errno));
        close(mem_fd);
        return -1;
    }

    for (int i = 0; i < 8; i++) {
        // argument to PRU program
        ((uint32_t*)ddrMem)[0] = 1 << i;

        // load and execute PRU program
        prussdrv_exec_program(PRU_NUM, "./leds.bin");

        printf("waiting on PRU...\n");
        prussdrv_pru_wait_event(PRU_EVTOUT_0);
        prussdrv_pru_clear_event(PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);

        sleep(1);
    }

    // disable pru
    prussdrv_pru_disable(PRU_NUM);
    prussdrv_exit ();

    // undo memory mapping
    munmap(ddrMem, 0x0FFFFFFF);
    close(mem_fd);

    return(0);
}

/*static unsigned short LOCAL_examplePassed ( unsigned short pruNum )
{
    unsigned int result_0, result_1, result_2;

    prussdrv_map_prumem(PRUSS0_SHARED_DATARAM, &sharedMem);
    sharedMem_int = (unsigned int*) sharedMem;

    result_0 = sharedMem_int[OFFSET_SHAREDRAM];
    result_1 = sharedMem_int[OFFSET_SHAREDRAM + 1];
    result_2 = sharedMem_int[OFFSET_SHAREDRAM + 2];

    printf("%x, %x, %x\n", result_0, result_1, result_2);

    int i;
    for(i = 0; i < 16; i++) {
        printf("%d\t%lx\n", i, *(unsigned long*)(ddrMem + OFFSET_DDR + i * 4));
    }

    return ((result_0 == ADDEND1) & (result_1 ==  ADDEND2) & (result_2 ==  ADDEND3)) ;

}*/
