#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>

#include "prussdrv.h"
#include <pruss_intc_mapping.h>

#define PRU_NUM 	 1

#define PRUSS_SHARED_DATARAM    4
#define DDR_BASEADDR    0x80000000

#define PPM_READ_BUF_LEN    1024

static int mem_fd;
static void *ddrMem, *sharedMem;

static unsigned int *sharedMem_int;

uint8_t* leds_from_ppm(FILE *pf) {
    unsigned int w, h;
    unsigned int d;
    int r;
    char buf[PPM_READ_BUF_LEN], *t;
    
    if (pf == NULL) {
        printf("invalid file pointer");
        return NULL;
    }

    t = fgets(buf, PPM_READ_BUF_LEN, pf);

    if ((t == NULL) || (strncmp(buf, "P6\n", 3) != 0)) {
        printf("could not read file or file not valid P6 type PPM.");
        return NULL;
    }

    do {
        t = fgets(buf, PPM_READ_BUF_LEN, pf);

        if (t == NULL)
            return NULL;
    } while (strncmp(buf, "#", 1) == 0);

    r = sscanf(buf, "%u %u", &w, &h);
    if (r < 2) {
        printf("failed in reading dimensions.");
        return NULL;
    }

    r = fscanf(pf, "%u", &d);

    if ((r < 1) || (d != 255)) {
        printf("bad d value: %d", d);
        return NULL;
    }

    fseek(pf, 1, SEEK_CUR); // skip 1 whitespace
    
    uint8_t* image = calloc(1, w*h*3);
    if (image == NULL) {
        printf("image allocation failed.");
        return NULL;
    }

    size_t rd = fread(image, 3, w*h, pf);

    if (rd < w*h) {
        printf("size of binary data does not match image dimensions.");
        free(image);
        return NULL;
    }

    printf("have (%d, %d) image.\n", w, h);

    return image;
}
    
int main (int argc, char* argv[]) {
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

    // load an image
    
    if (argc != 2) {
        printf("usage: leds.exe <10x10 RGB ppm image>");
        exit(1);
    }

    FILE* fp = fopen(argv[1], "r");

    uint8_t* image = leds_from_ppm(fp);
    if (image == NULL) {
        printf("image loading failed.");
        exit(1);
    }

    memcpy(ddrMem, image, 300);

    // load and execute PRU program
    prussdrv_exec_program(PRU_NUM, "./leds.bin");

    printf("waiting on PRU...\n");
    prussdrv_pru_wait_event(PRU_EVTOUT_0);
    prussdrv_pru_clear_event(PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);

    // disable pru
    prussdrv_pru_disable(PRU_NUM);
    prussdrv_exit ();

    // undo memory mapping
    munmap(ddrMem, 0x0FFFFFFF);
    close(mem_fd);

    printf("done\n");

    return(0);
}
