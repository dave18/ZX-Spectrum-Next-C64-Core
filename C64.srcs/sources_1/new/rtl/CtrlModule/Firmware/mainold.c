#include <limits.h>
#include "main.h"
#include "host.h"
#include "minfat.h"


fileTYPE file;

typedef unsigned short uint16_t;
typedef unsigned long uint32_t;
typedef unsigned char uint8_t;

#define NULL 0

#define OSDLINELEN       256       // single line length in bytes
#define OSD_CMD_WRITE    0x20      // OSD write video data command
#define OSD_CMD_ENABLE   0x41      // OSD enable command
#define OSD_CMD_DISABLE  0x40      // OSD disable command

#define UIO_GET_STRING  0x14

#define EMU_START  0x00
#define EMU_STOP  0x04
#define EMU_STATE  0x00

#define SSPI_STROBE  (1<<17)
#define SSPI_FPGA_EN (1<<18)
#define SSPI_OSD_EN  (1<<19)
#define SSPI_IO_EN   (1<<20)
#define SSPI_ACK     SSPI_STROBE

#define OSD_HDMI 1
#define OSD_VGA  2
#define OSD_ALL  (OSD_VGA|OSD_HDMI)

#define OSD_ARROW_LEFT   1
#define OSD_ARROW_RIGHT  2

#define CORENAMEMAX 32  //Need to keep this as low as possible due to limited memory

unsigned int gpio_value_read;//=0;
unsigned int gpio_value_write;//=0;


static uint8_t osdbuf[256];//={'a'};
static int  osdbufpos;// = 0;
static int  osdset;// = 0;

static int osd_size;// = 8;

//char framebuffer[16][256];
static unsigned char titlebuffer[256];//={'a'};
static char cfgstr[124];// = {'a'};
static char cur_status[16];// = {'a'};
static char buffer[(128*2) + 1];//= {'a'};  // max bytes per config item

static int arrow;//=0;

void Delay()
{
	int c=16384; // delay some cycles
	while(c)
	{
		c--;
	}
}
void SuperDelay()
{	int i=1;
	for (i=1;i<=576;i++)
	{
		Delay();
	}
}

static void memcpy1(char *dst,const unsigned char *src,int l)
{
	int i;
	for(i=0;i<l;++i)
		*dst++=*src++;
	*dst++=0;
}

char * strcpy(char * dest,const char * src)
{
	int l=strlen(src);
	memcpy1(dest,src,l);
	return dest;
}

char * strcat(char *s, const char *append)
{
	char *save = s;

	for (; *s; ++s);
	while ((*s++ = *append++));
	return (save);
}

char * strchr(const char *p,int ch)
{
	char c;
	c=ch;
	
	for (;; ++p) {
		if (*p == c)
			return ((char *)p);
		if (*p == '\0')
			return ((void*)0);
	}
}

static uint32_t strlen(const char *src)
{
	int i=0;
	while (src[i])
	{
		i=i+1;
	}
	return i;
}

int substrcpy(char *d, const char *s, char idx)
{
	char p = 0;
	char *b = d;

	while (*s)
	{
		if ((p == idx) && *s && (*s != ',')) *d++ = *s;

		if (*s == ',')
		{
			if (p == idx) break;
			p++;
		}

		s++;
	}

	*d = 0;
	return (int)(d - b);
}

int isspace(c)
	int c;
{
	return (c == '\t' || c == '\n' ||
	    c == '\v' || c == '\f' || c == '\r' || c == ' ' ? 1 : 0);
}

/*#define LONG_MAX __LONG_MAX__
#define ULONG_MAX LONG_MAX
*/
unsigned long
strtoul(nptr, endptr, base)
	const char * nptr;
	char ** endptr;
	int base;
{
	const char *s;
	unsigned long acc;
	char c;
	unsigned long cutoff;
	int neg, any, cutlim;
	
	int errno;

	/*
	 * See strtol for comments as to the logic used.
	 */
	s = nptr;
	do {
		c = *s++;
	} while (isspace((unsigned char)c));
	if (c == '-') {
		neg = 1;
		c = *s++;
	} else {
		neg = 0;
		if (c == '+')
			c = *s++;
	}
	if ((base == 0 || base == 16) &&
	    c == '0' && (*s == 'x' || *s == 'X')) {
		c = s[1];
		s += 2;
		base = 16;
	}
	if (base == 0)
		base = c == '0' ? 8 : 10;
	acc = any = 0;
	if (base < 2 || base > 36)
		goto noconv;

	cutoff = ULONG_MAX / base;
	cutlim = ULONG_MAX % base;
	
	for ( ; ; c = *s++) {
		if (c >= '0' && c <= '9')
			c -= '0';
		else if (c >= 'A' && c <= 'Z')
			c -= 'A' - 10;
		else if (c >= 'a' && c <= 'z')
			c -= 'a' - 10;
		else
			break;
		if (c >= base)
			break;
		if (any < 0 || acc > cutoff || (acc == cutoff && c > cutlim))
			any = -1;
		else {
			any = 1;
			acc *= base;
			acc += c;
		}
	}
	if (any < 0) {
		acc = ULONG_MAX;
		errno = 2;//ERANGE;
	} else if (!any) {
noconv:
		errno = 1;//EINVAL;
	} else if (neg)
		acc = -acc;
	if (endptr != NULL)
		*endptr = (char *)(any ? s - 1 : nptr);
	return (acc);
}

typedef	int word;		/* "word" used for optimal copy speed */

#undef	wsize
#define	wsize	sizeof(word)
#undef	wmask
#define	wmask	(wsize - 1)
typedef int size_t;

void * memmove(dst0, src0, length)
{
	register char *dst = (char *)dst0;
	register const char *src = (char *)src0;
	register size_t t;

	if (length == 0 || dst == src)		/* nothing to do */
		return;//goto done;

	/*
	 * Macros: loop-t-times; and loop-t-times, t>0
	 */
#undef	TLOOP
#define	TLOOP(s) if (t) TLOOP1(s)
#undef	TLOOP1
#define	TLOOP1(s) do { s; } while (--t)

	if ((unsigned long)dst < (unsigned long)src) {
		/*
		 * Copy forward.
		 */
		t = (size_t)src;	/* only need low bits */
		if ((t | (size_t)dst) & wmask) {
			/*
			 * Try to align operands.  This cannot be done
			 * unless the low bits match.
			 */
			if ((t ^ (size_t)dst) & wmask || length < wsize)
				t = length;
			else
				t = wsize - (t & wmask);
			length -= t;
			TLOOP1(*dst++ = *src++);
		}
		/*
		 * Copy whole words, then mop up any trailing bytes.
		 */
		t = length / wsize;
		TLOOP(*(word *)dst = *(word *)src; src += wsize; dst += wsize);
		t = length & wmask;
		TLOOP(*dst++ = *src++);
	} else {
		/*
		 * Copy backwards.  Otherwise essentially the same.
		 * Alignment works as before, except that it takes
		 * (t&wmask) bytes to align, not wsize-(t&wmask).
		 */
		src += length;
		dst += length;
		t = (size_t)src;
		if ((t | (size_t)dst) & wmask) {
			if ((t ^ (size_t)dst) & wmask || length <= wsize)
				t = length;
			else
				t &= wmask;
			length -= t;
			TLOOP1(*--dst = *--src);
		}
		t = length / wsize;
		TLOOP(src -= wsize; dst -= wsize; *(word *)dst = *(word *)src);
		t = length & wmask;
		TLOOP(*--dst = *--src);
	}
//done:
	//return (dst0);
}


void OsdSetSize(int n)
{
	osd_size = n;
}

int OsdGetSize()
{
	return osd_size;
}


static uint32_t gpo_copy;// = 0;
void inline fpga_gpo_write(uint32_t value)
{
	gpo_copy = value;	
	HW_GPIO(GPIO_OUT)=value;
}


//#define fpga_gpo_writeN(value) writel((value), (void*)(SOCFPGA_MGR_ADDRESS + 0x10))
#define fpga_gpo_read() gpo_copy //readl((void*)(SOCFPGA_MGR_ADDRESS + 0x10))
#define fpga_gpi_read() HW_GPIO(GPIO_IN)

int fpga_io_init()
{
//	map_base = (uint32_t*)shmem_map(FPGA_REG_BASE, FPGA_REG_SIZE);
//	if (!map_base) return -1;

	fpga_gpo_write(0);
	return 0;
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
	do
	{
		gpi = fpga_gpi_read();
		if (gpi < 0)
		{
			//printf("GPI[31]==1. FPGA is uninitialized?\n");
			//fpga_wait_to_reset();
			return 0;
		}
	} while (!(gpi & SSPI_ACK));

	fpga_gpo_write(gpo);

	do
	{
		gpi = fpga_gpi_read();
		if (gpi < 0)
		{
			//printf("GPI[31]==1. FPGA is uninitialized?\n");
			//fpga_wait_to_reset();
			return 0;
		}
	} while (gpi & SSPI_ACK);
	
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


void EnableIO()
{
	fpga_spi_en(SSPI_IO_EN, 1);
}

void DisableIO()
{
	fpga_spi_en(SSPI_IO_EN, 0);
}


// base functions
uint8_t  inline spi_b(uint8_t parm)
{
	return (uint8_t)fpga_spi(parm);
}

uint16_t inline spi_w(uint16_t word)
{
	return fpga_spi(word);
}


// input only helper
uint8_t inline spi_in()
{
	return (uint8_t)fpga_spi(0);
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

/* User_io related SPI functions */
uint16_t spi_uio_cmd_cont(uint16_t cmd)
{
	EnableIO();
	return spi_w(cmd);
}

uint16_t spi_uio_cmd(uint16_t cmd)
{
	uint16_t res = spi_uio_cmd_cont(cmd);
	DisableIO();
	return res;
}


void spi_write(const uint8_t *addr, uint32_t len, int wide)
{
	if (wide)
	{
		uint32_t len16 = len >> 1;
		uint16_t *a16 = (uint16_t*)addr;
		while (len16--) spi_w(*a16++);
		if(len & 1) spi_w(*((uint8_t*)a16));
	}
	else
	{
		while (len--) spi_b(*addr++);		
	}
}





void OsdUpdateLine(int i)  //Updated to operate on a single line buffer (rather than whole OSD buffer)
{
	//PROFILE_FUNCTION();
	//int n = is_menu() ? 19 : osd_size;
	int n = osd_size;
	
	//int i;
	//for (i = 0; i < n; i++)
	if ((i>=0) && (i<n))
	{
		if (osdset & (1 << i))
		{
			spi_osd_cmd_cont(OSD_CMD_WRITE | i);
		//	spi_write(osdbuf + i * 256, 256, 0);			
			spi_write(osdbuf , 256, 0);			
			DisableOsd();
		//	if (is_megacd()) mcd_poll();
		//	if (is_pce()) pcecd_poll();
		//	if (is_saturn()) saturn_poll();
		}
		
		
	}
	
	
	osdset = 0;
}

static void osd_start(int line)
{
	line = line & 0x07;//0x1F;
	osdset |= 1 << line;
	osdbufpos = line * 256;
}

static void draw_title(const unsigned char *p)
{
	// left white border
	osdbuf[osdbufpos++] = 0xff;
	osdbuf[osdbufpos++] = 0xff;
	osdbuf[osdbufpos++] = 0xff;
	int i;
	for (i = 0; i < 8; i++)
	{
		osdbuf[osdbufpos++] = 255 ^ *p;
		osdbuf[osdbufpos++] = 255 ^ *p++;
	}

	// right white border
	osdbuf[osdbufpos++] = 0xff;

	// blue gap
	osdbuf[osdbufpos++] = 0;
	osdbuf[osdbufpos++] = 0;
}

static void rotatechar(unsigned char *in, unsigned char *out)
{
	int a;
	int b;
	int c;
	for (b = 0; b<8; ++b)
	{
		a = 0;
		for (c = 0; c<8; ++c)
		{
			a <<= 1;
			a |= (in[c] >> b) & 1;
		}
		out[b] = a;
	}
}

#define OSDHEIGHT (unsigned int)(osd_size*8)

void OsdSetTitle(const char *s, int a)
{
	// Compose the title, condensing character gaps
	arrow = a;
	int zeros = 0;
	unsigned int i = 0, j = 0;
	unsigned int outp = 0;
	while (1)
	{
		int c = s[i++];
		if (c && (outp<OSDHEIGHT-8))
		{
			unsigned char *p = &charfont[c][0];
			for (j = 0; j<8; ++j)
			{
				unsigned char nc = *p++;
				if (nc)
				{
					zeros = 0;
					titlebuffer[outp++] = nc;
				}
				else if (zeros == 0 || (c == ' ' && zeros < 5))
				{
					titlebuffer[outp++] = 0;
					zeros++;
				}
				if (outp>sizeof(titlebuffer)) break;
			}
		}
		else break;
	}
	for (i = outp; i<OSDHEIGHT; i++)
	{
		titlebuffer[i] = 0;
	}

	// Now centre it:
	unsigned int c = (OSDHEIGHT - 1 - outp) / 2;
	memmove(titlebuffer + c, titlebuffer, outp);

	for (i = 0; i<c; ++i) titlebuffer[i] = 0;

	// Finally rotate it.
	for (i = 0; i<OSDHEIGHT; i += 8)
	{
		unsigned char tmp[8];
		rotatechar(&titlebuffer[i], tmp);
		for (c = 0; c<8; ++c)
		{
			titlebuffer[i + c] = tmp[c];
		}
	}
}

// write a null-terminated string <s> to the OSD buffer starting at line <n>
void OsdWriteOffset(unsigned char n, const char *s, unsigned char invert, unsigned char stipple, char offset, char leftchar, char usebg, int maxinv, int mininv)
{
	//printf("OsdWriteOffset(%d)\n", n);
	unsigned short i;
	unsigned char b;
	const unsigned char *p;
	unsigned char stipplemask = 0xff;
	int linelimit = OSDLINELEN;
	int arrowmask = arrow;
	if (n == (osd_size-1) && (arrow & OSD_ARROW_RIGHT))
		linelimit -= 22;

	if (n && n < OsdGetSize() - 1) leftchar = 0;

	if (stipple) {
		stipplemask = 0x55;
		stipple = 0xff;
	}
	else
		stipple = 0;

	//osd_start(n);
	osdbufpos=0;	//we don't have enough memory for a full buffer to adapt to draw 1 line at a time

	unsigned char xormask = 0;
	unsigned char xorchar = 0;

	i = 0;
	// send all characters in string to OSD
	while (1)
	{
		if (invert && i / 8 >= mininv) xormask = 255;
		if (invert && i / 8 >= maxinv) xormask = 0;

		if (i == 0 && (n < osd_size))
		{	// Render sidestripe
			unsigned char tmp[8];

			if (leftchar)
			{
				unsigned char tmp2[8];
				memcpy1(tmp2, charfont[(unsigned int)leftchar], 8);
				rotatechar(tmp2, tmp);
				p = tmp;
			}
			else
			{
				p = &titlebuffer[(osd_size - 1 - n) * 8];
			}

			draw_title(p);
			i += 22;
		}
		else if (n == (osd_size-1) && (arrowmask & OSD_ARROW_LEFT))
		{	// Draw initial arrow
			unsigned char b;

			osdbuf[osdbufpos++] = xormask;
			osdbuf[osdbufpos++] = xormask;
			osdbuf[osdbufpos++] = xormask;
			p = &charfont[0x10][0];
			for (b = 0; b<8; b++) osdbuf[osdbufpos++] = (*p++ << offset) ^ xormask;
			p = &charfont[0x14][0];
			for (b = 0; b<8; b++) osdbuf[osdbufpos++] = (*p++ << offset) ^ xormask;
			osdbuf[osdbufpos++] = xormask;
			osdbuf[osdbufpos++] = xormask;
			osdbuf[osdbufpos++] = xormask;
			osdbuf[osdbufpos++] = xormask;
			osdbuf[osdbufpos++] = xormask;

			i += 24;
			arrowmask &= ~OSD_ARROW_LEFT;
			if (*s++ == 0) break;	// Skip 3 characters, to keep alignent the same.
			if (*s++ == 0) break;
			if (*s++ == 0) break;
		}
		else
		{
			b = *s++;
			if (!b) break;

			if (b == 0xb)
			{
				stipplemask ^= 0xAA;
				stipple ^= 0xff;
			}
			else if (b == 0xc)
			{
				xorchar ^= 0xff;
			}
			else if (b == 0x0d || b == 0x0a)
			{  // cariage return / linefeed, go to next line
			   // increment line counter
				if (++n >= linelimit)
					n = 0;

				// send new line number to OSD
				//osd_start(n);
				osdbufpos=0;
			}
			else if (i<(linelimit - 8))
			{  // normal character
				unsigned char c;
				p = &charfont[b][0];
				for (c = 0; c<8; c++) {
					char bg = 0;//usebg ? framebuffer[n][i+c-22] : 0;
					osdbuf[osdbufpos++] = (((*p++ << offset)&stipplemask) ^ xormask ^ xorchar) | bg;
					stipplemask ^= stipple;
				}
				i += 8;
			}
		}
	}

	for (; i < linelimit; i++) // clear end of line
	{
		char bg = 0;//usebg ? framebuffer[n][i-22] : 0;
		osdbuf[osdbufpos++] = xormask | bg;
	}

	if (n == (osd_size-1) && (arrowmask & OSD_ARROW_RIGHT))
	{	// Draw final arrow if needed
		unsigned char c;
		osdbuf[osdbufpos++] = xormask;
		osdbuf[osdbufpos++] = xormask;
		osdbuf[osdbufpos++] = xormask;
		p = &charfont[0x15][0];
		for (c = 0; c<8; c++) osdbuf[osdbufpos++] = (*p++ << offset) ^ xormask;
		p = &charfont[0x11][0];
		for (c = 0; c<8; c++) osdbuf[osdbufpos++] = (*p++ << offset) ^ xormask;
		osdbuf[osdbufpos++] = xormask;
		osdbuf[osdbufpos++] = xormask;
		osdbuf[osdbufpos++] = xormask;
		i += 22;
	}
	
	
}

void OsdWrite(unsigned char n, const char *s, unsigned char invert, unsigned char stipple, char usebg, int maxinv, int mininv)
{
	OsdWriteOffset(n, s, invert, stipple, 0, 0, usebg, maxinv, mininv);
	osdset=-1;
	//osdset = (1 << n);
	OsdUpdateLine(n);
}

/* core currently loaded */
static char lastcorename[CORENAMEMAX];// = {'a'};
void OsdCoreNameSet(const char* str)
{
	//sprintf(lastcorename, "%s", str);
	strcpy(lastcorename,str);
}

char* OsdCoreNameGet()
{
	return lastcorename;
}



char *user_io_get_confstr(int index)
{
	int lidx = 0;
	//static char buffer[(1024*2) + 1];  // max bytes per config item
	

	char *start = cfgstr;
	while (lidx < index)
	{
		start = (char *)strchr(start, ';');
		if (!start) return (void*)NULL;
		start++;
		lidx++;
	}

	char *end = (char *)strchr(start, ';');
	int len = end ? end - start : strlen(start);
	if (!len) return (void*)NULL;

	if ((uint32_t)len > sizeof(buffer) - 1) len = sizeof(buffer) - 1;
	memcpy1(buffer, start, len);
	buffer[len] = 0;
	return buffer;
}

void user_io_read_confstr()
{
	spi_uio_cmd_cont(UIO_GET_STRING);

	uint32_t j = 0;
	while (j < sizeof(cfgstr) - 1)
	{
		char i = spi_in();
		if (!i) break;
		cfgstr[j++] = i;
	}

	cfgstr[j++] = 0;
	DisableIO();
}

int convertuu(uint32_t * result,const char * input)		//determine values in [xx:xx] string
{
	char *tptr;
	char *tptr2;
	char temp[4];
	tptr=(char*)input;
	tptr=strchr(input,':');
	if (!tptr) return 0;	//if not valid ':' separator return 0
	memcpy1(temp,input,tptr-input);
	temp[tptr-input]=0;
	
	result[0]=strtoul(temp,(void*)NULL,10);
	
	tptr++;
	tptr2=strchr(tptr,']');
	if (!tptr2) return 0;	//if not valid ']' end marker return 0
	
	memcpy1(temp,tptr,tptr2-tptr);
	temp[tptr2-tptr]=0;
	result[1]=strtoul(temp,(void*)NULL,10);
	
	return 2;
	
	
}

int convertu(uint32_t * result,const char * input)		//determine values in [xx:xx] string
{
	
	char *tptr;	
	char temp[4];
	tptr=(char*)input;
	
	tptr=strchr(tptr,']');
	if (!tptr) return 0;	//if not valid ']' end marker return 0
	
	memcpy1(temp,input,tptr-input);
	temp[tptr-input]=0;
	result[0]=strtoul(temp,(void*)NULL,10);
	
	return 1;
	
	
}


int user_io_status_bits(const char *opt, int *s, int *e, int ex, int single)
{
	int ret;
	uint32_t res[2];
	uint32_t start = 0, end = 0;
	if (opt[0] == '[')						//Removed parsing of [:] for now as strtoul function takes up too much space
	{		
	/*	if (!single && convertuu(res,opt+1) == 2)
		{
			start=res[0];
			end=res[1];
			if (start > 127 || end > 127 || end <= start) return 0;
		}
		else if (convertu(res,opt+1) == 1)
		{
			start=res[0];
			if (start > 127) return 0;
			end = start;
		}
		else*/ return 0;
	}
	else
	{
		if ((opt[0] >= '0') && (opt[0] <= '9')) start = opt[0] - '0';
		else if ((opt[0] >= 'A') && (opt[0] <= 'V')) start = opt[0] - 'A' + 10;
		else return 0;

		if (!single && (opt[1] >= '0') && (opt[1] <= '9')) end = opt[1] - '0';
		else if (!single && (opt[1] >= 'A') && (opt[1] <= 'V')) end = opt[1] - 'A' + 10;
		else
		{
			single = 1;
			end = start;
		}

		if (ex)
		{
			start += 32;
			end += 32;
		}

		if (start > 127 || end > 127 || (!single && end <= start)) return 0;
	}

	//max 8 bits per option
	if (end - start > 8) return 0;

	if (s) *s = (int)start;
	if (e) *e = (int)end;
	return 1 + end - start;
}

uint32_t user_io_status_get(const char *opt, int ex)
{
	int start, end;
	int size = user_io_status_bits(opt, &start, &end, ex,0);
	if (!size) return 0;

	uint32_t x = (cur_status[end / 8] << 8) | cur_status[start / 8];
	x >>= start % 8;
	return x & ~(0xffffffff << size);
}


static void parse_config()
{
	char mask[sizeof(cur_status) * 8];// = {};
	char overlap[sizeof(cur_status) * 8];// = {};
	int start, end, sz;

	int i = 0;
	char *p;
/*
	joy_force = 0;
	joy_bcount = 0;
*/
	do {
		p = user_io_get_confstr(i);
	//	printf("get cfgstring %d = %s\n", i, p ? p : "NULL");
		if (!i)
		{
			OsdCoreNameSet((p && p[0]) ? p : "CORE");
		}
		
			if (i == 1 && p)
		{
			while (p && *p)
			{
				/*if (!strncasecmp(p, "SS", 2))
				{
					char *end = 0;
					ss_base = strtoul(p+2, &end, 16);
					p = end;
					if (p && *p == ':')
					{
						p++;
						ss_size = strtoul(p, &end, 16);
					}

					printf("Got save state parameters: base=0x%X, size=0x%X\n", ss_base, ss_size);

					if (!ss_size || ss_size > (128 * 1024 * 1024))
					{
						ss_size = 0;
						ss_base = 0;
						printf("Invalid size!\n");
					}
					else if (ss_base < 0x20000000 || ss_base >= 0x40000000 || (ss_base + ss_size) >= 0x40000000)
					{
						ss_size = 0;
						ss_base = 0;
						printf("Invalid base!\n");
					}
				}*/

				/*if (!strncasecmp(p, "UART", 4))
				{
					p += 4;
					for (int i = 0; i < 10 && p && *p; i++)
					{
						char *end = 0;
						uart_speeds[i] = strtoul(p, &end, 10);
						p = end;
						if (p && *p == '(')
						{
							p++;
							int n = 0;
							while (*p != ';' && *p != ':' && *p != ')' && *p != ',')
							{
								if (n < 16) uart_speed_labels[i][n] = *p;
								p++;
								n++;
							}
							if (*p == ')') p++;
						}
						else
						{
							sprintf(uart_speed_labels[i], "%d", uart_speeds[i]);
						}
						if (p && *p == ':') p++;
					}

					printf("Got UART speeds:");
					for(int i=0; i<10; i++) printf(" %d", uart_speeds[i]);
					printf("\n");
				}*/

				/*if (!strncasecmp(p, "MIDI", 4))
				{
					p += 4;
					for (int i = 0; i < 10 && p && *p; i++)
					{
						char *end = 0;
						midi_speeds[i] = strtoul(p, &end, 10);
						p = end;
						if (p && *p == '(')
						{
							p++;
							int n = 0;
							while (*p != ';' && *p != ':' && *p != ')' && *p != ',')
							{
								if (n < 16) midi_speed_labels[i][n] = *p;
								p++;
								n++;
							}
							if (*p == ')') p++;
						}
						else
						{
							sprintf(midi_speed_labels[i], "%d", midi_speeds[i]);
						}
						if (p && *p == ':') p++;
					}

					if (!midi_speeds[0])
					{
						midi_speeds[0] = 31250;
						strcpy(midi_speed_labels[0], "31250");
					}

					printf("Got MIDI speeds:");
					for (int i = 0; i < 10; i++) printf(" %d", midi_speeds[i]);
					printf("\n");
				}*/

				p = strchr(p, ',');
				if (p) p++;
			}
		}
		
		if (i >= 2 && p && p[0])
		{
			/*if (!strncmp(p, "DEFMRA,", 7))
			{
				//snprintf(defmra, sizeof(defmra), (p[7] == '/') ? "%s%s" : "%s/_Arcades/%s", getRootDir(), p + 7);
			}
			else if (!strncmp(p, "DIP", 3))
			{

			}
			else
			{
				//skip Disable/Hide masks
				while ((p[0] == 'H' || p[0] == 'D' || p[0] == 'h' || p[0] == 'd') && strlen(p) >= 2) p += 2;
			}*/
			/*if (p[0] == 'P') p += 2;*/

			if (p[0] == 'R' || p[0] == 'T' || p[0] == 'r' || p[0] == 't')
			{
				sz = user_io_status_bits(p + 1, &start, &end, p[0] == 'r' || p[0] == 't',0);
				if (sz == 1)
				{
					overlap[start] |= mask[start];
					mask[start] |= 1;
				}
				else
				{
					//printf("Invalid OSD option: %s\n", p);
				}
			}
			else if (p[0] == 'O' || p[0] == 'o')
			{
				char *opt = (p[1] == 'X') ? (p + 2) : (p + 1);
				sz = user_io_status_bits(opt, &start, &end, p[0] == 'o',0);
				if (sz)
				{
					while (sz)
					{
						overlap[start] |= mask[start];
						mask[start] |= 1;
						sz--;
						start++;
					}
				}
				else
				{
					//printf("Invalid OSD option: %s\n", p);
				}
			}

			/*if (p[0] == 'J')
			{
				int n = 1;
				//if (p[1] == 'D') { joy_transl = 0; n++; }
				//if (p[1] == 'A') { joy_transl = 1; n++; }
				//if (p[1] == 'N') { joy_transl = 2; n++; }

				if (p[n] == '1')
				{
					//joy_force = 1;
					//set_emu_mode(EMU_JOY0);
				}
			}*/

			/*if (p[0] == 'O' && p[1] == 'X')
			{
				int x = user_io_status_get(p + 2,0);
				//printf("found OX option: %s: %d\n", p, x);*/

				/*if (is_x86())
				{
					if (p[2] == '2') x86_set_fdd_boot(!(x & 1));
				}*/
			//}

			/*if (p[0] == 'X')
			{
				disable_osd = 1;
			}*/

			if (p[0] == 'V')
			{
				// get version string
				char s[CORENAMEMAX];//128];
				strcpy(s, OsdCoreNameGet());
				strcat(s, " ");
				substrcpy(s + strlen(s), p, 1);
				OsdCoreNameSet(s);
			}

			/*if (p[0] == 'C')
			{
				use_cheats = 1;
			}*/

			/*if (p[0] == 'F')
			{*/
				/*int opensave = 0;
				int idx = 1;
				if (p[idx] == 'S')
				{
					opensave = 1;
					idx++;
				}

				if (p[idx] == 'C')
				{
					idx++;
					static char str[1024];
					uint32_t load_addr = 0;
					if (substrcpy(str, p, 3))
					{
						load_addr = strtoul(str, NULL, 16);
						if (load_addr < 0x20000000 || load_addr >= 0x40000000)
						{
							printf("Loading address 0x%X is outside the supported range! Using normal load.\n", load_addr);
							load_addr = 0;
						}
					}

					sprintf(str, "%s.f%c", user_io_get_core_name(), p[idx]);
					if (FileLoadConfig(str, str, sizeof(str)) && str[0])
					{

						idx = p[idx] - '0';
						StoreIdx_F(idx, str);
						user_io_file_tx(str, idx, opensave, 0, 0, load_addr);
					}
				}*/
			//}

			/*if (p[0] == 'S' && p[1] == 'C')
			{
				static char str[1024];
				sprintf(str, "%s.s%c", user_io_get_core_name(), p[2]);

				static char ext[256];
				substrcpy(ext, p, 1);
				while (strlen(ext) % 3) strcat(ext, " ");

				if (FileLoadConfig(str, str, sizeof(str)) && str[0])
				{
					int idx = p[2] - '0';
					StoreIdx_S(idx, str);
					if (is_x86())
					{
						x86_set_image(idx, str);
					}
					else if (is_megacd())
					{
						mcd_set_image(idx, str);
					}
					else if (is_pce())
					{
						pcecd_set_image(idx, str);
						cheats_init(str, 0);
					}
					else
					{
						user_io_set_index(user_io_ext_idx(str, ext) << 6 | idx);
						user_io_file_mount(str, idx);
					}
				}
			}*/
		}
	i++;
	} while (p || i<3);
	
	mask[0] = 1; // reset is always on bit 0
/*	printf("\n// Status Bit Map:\n");
	printf("//              Upper                          Lower\n");
	printf("// 0         1         2         3          4         5         6   \n");
	printf("// 01234567890123456789012345678901 23456789012345678901234567890123\n");
	printf("// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV\n");*/
/*	char str[128];
	strcpy(str, "// ");
	for (i = 0; i < 32; i++) strcat(str, mask[i] ? "X" : " ");
	strcat(str, " ");
	for (i = 32; i < 64; i++) strcat(str, mask[i] ? "X" : " ");
	strcat(str, "\n");
	//printf(str);

	int ovr = 0;
	for (i = 0; i < 64; i++) ovr |= overlap[i];

	if (ovr)
	{
		strcpy(str, "// ");
		for (i = 0; i < 32; i++) strcat(str, overlap[i] ? "^" : " ");
		strcat(str, " ");
		for (i = 32; i < 64; i++) strcat(str, overlap[i] ? "^" : " ");
		strcat(str, "\n");
		//printf(str);
		//printf("// *Overlapped bits!* (can be intentional)\n");
	}
	//printf("\n");

	ovr = 0;
	for (i = 64; i < 128; i++) ovr |= mask[i];

	if (ovr)
	{*/
		/*printf("// 0     0         0         0          1         1         1       \n");
		printf("// 6     7         8         9          0         1         2       \n");
		printf("// 45678901234567890123456789012345 67890123456789012345678901234567\n");*/
/*		strcpy(str, "// ");
		for (i = 64; i < 96; i++) strcat(str, mask[i] ? "X" : " ");
		strcat(str, " ");
		for (i = 96; i < 128; i++) strcat(str, mask[i] ? "X" : " ");
		strcat(str, "\n");
		//printf(str);

		ovr = 0;
		for (i = 64; i < 128; i++) ovr |= overlap[i];

		if (ovr)
		{
			strcpy(str, "// ");
			for (i = 64; i < 96; i++) strcat(str, overlap[i] ? "^" : " ");
			strcat(str, " ");
			for (i = 96; i < 128; i++) strcat(str, overlap[i] ? "^" : " ");
			strcat(str, "\n");
			//printf(str);
			//printf("// *Overlapped bits!* (can be intentional)\n");
		}
		//printf("\n");
	}*/

/*
	// legacy GBA versions
	if (is_gba() && !ss_base)
	{
		ss_base = 0x3E000000;
		ss_size = 0x100000;
	}*/
}


void HandleUI(void)
{
	
}

void user_io_init()
{
	EMU_CONTROL(EMU_STOP)=0;		//stop the core while we init the OSD
	while (EMU_CONTROL(EMU_STATE) & 1 == 0) //Wait until core confirmed paused
	{
	}
	OsdSetSize(8);
	
	user_io_read_confstr();
	//user_io_read_core_name();


	//cfg_parse();
	
	parse_config();
}



int main(int argc,char **argv)
{
	
	gpio_value_read=0;
	gpio_value_write=0;

	osdbufpos = 0;

	
	osdset = 0;

	osd_size = 8;

	arrow=0;
	
	osd_target = OSD_ALL;
	gpo_copy = 0;

	
	fpga_io_init();
	
	
	
	//spi_uio_cmd(UIO_EMU_STOP);
	
	OsdCoreNameSet("CORE");
	
	user_io_init();
	
	//OsdSetSize(16);
		
	spi_osd_cmd(OSD_CMD_ENABLE);
	
	/*int i;
	
	for (i=0;i<256;i++)
	{
		osdbuf[i]=i;
	}*/
	
	
	
	OsdSetTitle(lastcorename,0);
	
	OsdWrite((unsigned char)0, "TEST STRING", (unsigned char)0, (unsigned char)0,  (char)0, (int)32, (int)0);
	OsdWrite((unsigned char)1, "TEST STRING2", (unsigned char)0, (unsigned char)0, (char)0, (int)32, (int)0);
	OsdWrite((unsigned char)2, "BOOM!", (unsigned char)0, (unsigned char)0, (char)0,  (int)32, (int)0);
	OsdWrite((unsigned char)3, "This Is Row 4", (unsigned char)0, (unsigned char)0,  (char)0, (int)32, (int)0);
	OsdWrite((unsigned char)4, "Whackamole?>!", (unsigned char)0, (unsigned char)0,  (char)0, (int)32, (int)0);
	OsdWrite((unsigned char)5, "Hippy Hoppity", (unsigned char)0, (unsigned char)0,  (char)0, (int)32, (int)0);
	OsdWrite((unsigned char)6, "Arggggghhhhh..", (unsigned char)0, (unsigned char)0,  (char)0, (int)32, (int)0);
	OsdWrite((unsigned char)7, "The End", (unsigned char)0, (unsigned char)0, (char)0,  (int)32, (int)0);
	
	
	
	
	osdset=-1;
	//EMU_CONTROL(EMU_START)=0; //Start the Core
	while(1)
	{	
		
		
	}
	return(0);
}
