#ifndef HOST_H
#define HOST_H

//#define HOSTBASE 0xFFFFFFE0
//#define HW_HOST(x) *(volatile unsigned int *)(HOSTBASE+x)


/* Host Boot Data register */
#define REG_HOST_BOOTDATA 0x08

/* Host control register */
#define OSDBASE 0xFFFFFB00
#define HW_OSD(x) *(volatile unsigned int *)(OSDBASE+x)

#define OSDCHARBASE 0xFFFFFC00
#define HW_OSDCHAR(x) *(volatile unsigned int *)(OSDCHARBASE+x)

#define PS2BASE 0xFFFFFE00
#define HW_PS2(x) *(volatile unsigned int *)(PS2BASE+x)

#define HWBASE 0xFFFFFFF0
#define IO_RW(x) *(volatile unsigned int *)(HWBASE+x)
#define IO_STATUS0 0x0
#define IO_STATUS1 0x4
#define IO_STATUS2 0x8

#define IOCTLBASE 0xFFFFFFD8
#define HW_IOCTL(x) *(volatile unsigned int *)(IOCTLBASE+x)
//IOCTL Writes
#define IOCTL_DOWNLOAD 0x0
#define IOCTL_ADDR 0x4
#define IOCTL_INDEX 0x8
#define IOCTL_WR 0xc
#define IOCTL_DOUT 0x10
//IOCTL Reads
#define IOCTL_UPLOAD_REQ 0x0
#define IOCTL_DIN 0x4
#define IOCTL_WAIT 0x8


#define DEBUGBASE 0xFFFFFFB0
#define HW_DEBUG(x) *(volatile unsigned int *)(DEBUGBASE+x)
#define CLKFBOUT_MULT 0x0

#define JOYBASE 0xFFFFFF90
#define HW_JOY(x) *(volatile unsigned int *)(JOYBASE+x)
#define READ_JOY 0x0

#endif

