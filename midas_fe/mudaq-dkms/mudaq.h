/*
 * mudaq ioctl definitions.
 */

#ifndef MUDAQ_H
#define MUDAQ_H

#include <linux/ioctl.h>
#include <linux/types.h>

// #define MUDAQ_DMABUF_DATA_LEN 4

#define MUDAQ_IOC_TYPE 102
#define MUDAQ_IOC_NR 4

/**
 * configuration
 */
static const int MAX_NUM_DEVICES = 8;

struct mesg {
    volatile void* address;
    size_t size;
};

/* Declare IOC functions */

/** Request current interrupt number from driver
 */
#define REQUEST_INTERRUPT_COUNTER _IOR(MUDAQ_IOC_TYPE, 1, int)

#endif  // MUDAQ_H
