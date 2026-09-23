#define TEST_LOC 0x00003000
#define TEST_ADDR(x) *(volatile unsigned int *)(TEST_LOC+x)

#define GPIOBASE 0xFFFFFFF0
#define HW_GPIO(x) *(volatile unsigned int *)(GPIOBASE+x)
#define GPIO_OUT 0x00
#define GPIO_IN 0x04

#define EMU_CTRL_BASE 0xFFFFFE00
#define EMU_CONTROL(x) *(volatile unsigned int *)(EMU_CTRL_BASE+x)

#define SSPI_STROBE  (1<<17)
#define SSPI_FPGA_EN (1<<18)
#define SSPI_OSD_EN  (1<<19)
#define SSPI_IO_EN   (1<<20)
#define SSPI_ACK     SSPI_STROBE

#define OSD_HDMI 1
#define OSD_VGA  2
#define OSD_ALL  (OSD_VGA|OSD_HDMI)

#define OSDLINELEN       256       // single line length in bytes
#define OSD_CMD_WRITE    0x20      // OSD write video data command
#define OSD_CMD_ENABLE   0x41      // OSD enable command
#define OSD_CMD_DISABLE  0x40      // OSD disable command

typedef unsigned short uint16_t;
typedef unsigned long uint32_t;
typedef unsigned char uint8_t;

//#define fpga_gpo_writeN(value) writel((value), (void*)(SOCFPGA_MGR_ADDRESS + 0x10))
#define fpga_gpo_read() gpo_copy //readl((void*)(SOCFPGA_MGR_ADDRESS + 0x10))
#define fpga_gpi_read() HW_GPIO(GPIO_IN)

static uint32_t gpo_copy;// = 0;
void inline fpga_gpo_write(uint32_t value)
{
	gpo_copy = value;	
	HW_GPIO(GPIO_OUT)=value;
}

void fpga_spi_en(uint32_t mask, uint32_t en)
{
	uint32_t gpo = fpga_gpo_read() | 0x80000000;
	fpga_gpo_write(en ? gpo | mask : gpo & ~mask);
}

uint16_t fpga_spi(uint16_t word)
{
	uint32_t gpo = (fpga_gpo_read() & ~(0xFFFF | SSPI_STROBE)) | word;

	fpga_gpo_write(gpo);
	fpga_gpo_write(gpo | SSPI_STROBE);
	
	//HW_GPIO(GPIO_OUT)=0;
	//SuperDelay();

	int gpi;
/*	do
	{
		gpi = fpga_gpi_read();
		if (gpi < 0)
		{
			//printf("GPI[31]==1. FPGA is uninitialized?\n");
			//fpga_wait_to_reset();
			return 0;
		}
	} while (!(gpi & SSPI_ACK));
*/
	fpga_gpo_write(gpo);

/*	do
	{
		gpi = fpga_gpi_read();
		if (gpi < 0)
		{
			//printf("GPI[31]==1. FPGA is uninitialized?\n");
			//fpga_wait_to_reset();
			return 0;
		}
	} while (gpi & SSPI_ACK);
	*/
	//HW_GPIO(GPIO_OUT)=value;
	//SuperDelay();

	return (uint16_t)gpi;
}



static int osd_target;// = OSD_ALL;

void EnableOsd()
{
	if (!(osd_target & OSD_ALL)) osd_target = OSD_ALL;

	uint32_t mask = SSPI_OSD_EN | SSPI_IO_EN | SSPI_FPGA_EN;
	if (osd_target & OSD_HDMI) mask &= ~SSPI_FPGA_EN;
	if (osd_target & OSD_VGA) mask &= ~SSPI_IO_EN;

	fpga_spi_en(mask, 1);
}

void DisableOsd()
{
	fpga_spi_en(SSPI_OSD_EN | SSPI_IO_EN | SSPI_FPGA_EN, 0);
}


// base functions
uint8_t  inline spi_b(uint8_t parm)
{
	return (uint8_t)fpga_spi(parm);
}

/* OSD related SPI functions */
void spi_osd_cmd_cont(uint8_t cmd)
{
	EnableOsd();
	spi_b(cmd);
}

void spi_osd_cmd(uint8_t cmd)
{
	spi_osd_cmd_cont(cmd);
	DisableOsd();
}


int main(int argc,char **argv)
{
	spi_osd_cmd(OSD_CMD_ENABLE);
	
	while(1)
	{	

	}
	return(0);
}
