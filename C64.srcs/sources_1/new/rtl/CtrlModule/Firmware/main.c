#include "main.h"
#include "host.h"
#include "osdframe.h"
//#include "menu.h"
//#include "FAT.h"
#include "minfat.h"
#include "spi.h"
#include "fileselector.h"
#include "keyboard.h"
#include "swap.h"

#define INT_DIGITS 19*4		// enough for 64 bit integer 

fileTYPE file;
int drive_avail;

uint32_t status_bits[96];
uint32_t status0;
uint32_t status1;
uint32_t status2;
int currmenu=0;
int numitems=0;
int cursorpos=0;
int file_sel_active;
int oldpos;


void copyname(char *dst,const unsigned char *src,int l)
{
	int i;
	for(i=0;i<l;++i)
		*dst++=*src++;
	*dst++=0;
}

void *mmemset (void *dest, register int val, register int len)
{
  register unsigned char *ptr = (unsigned char*)dest;
  while (len-- > 0)
    *ptr++ = val;
  return dest;
}

int strcmp(const char *s1, const char *s2)
{
	while (*s1 == *s2++)
		if (*s1++ == '\0')
			return (0);
	return (*(const unsigned char *)s1 - *(const unsigned char *)(s2 - 1));
}

int mstrncmp(const char *s1, const char *s2, int n)
{
  unsigned char u1, u2;

  while (n-- > 0)
    {
      u1 = (unsigned char) *s1++;
      u2 = (unsigned char) *s2++;
      if (u1 != u2)
	return u1 - u2;
      if (u1 == '\0')
	return 0;
    }
  return 0;
}


char * strcpyr(char *s1, const char *s2)
{
    char *s = s1;    /* s1 assign address to s */
    while ((*s++ = *s2++) != 0)   /* s++ only the address of s plus one */
    ;
    return (s1);
}

void strrev(char *str)
{
	int i;
	int j;
	unsigned char a;
	unsigned len = strlen((const char *)str);
	for (i = 0, j = len - 1; i < j; i++, j--)
	{
		a = str[i];
		str[i] = str[j];
		str[j] = a;
	}
}



char itoabuf[INT_DIGITS + 2];


void itoa(int si)       //currently hacked just for hex values
{
  // Room for INT_DIGITS digits, - and '\0' 
  unsigned int i=(unsigned int)si;
  int p=0;    
  if (i==0)	{  //deal with 0 specifically
	itoabuf[0]='0';
	itoabuf[1]=0;
	return;
  }
  //if (i > 0) {
    do {
      if ((i & 0xf) < 0xa) itoabuf[p] = '0' + (i & 0xf); else itoabuf[p] = 'A' + ((i & 0xf)-10);
	  p++;
      i >>= 4;
    } while (i != 0);
	itoabuf[p] = 0;
	strrev(itoabuf);
  //  return;
  
  /*else {			// i < 0 
	i=-i;
    do {
      if ((i & 0xf) < 0xa) itoabuf[p] = '0' + (i & 0xf); else itoabuf[p] = 'A' + ((i & 0xf)-10);
	  p++;
      i >>= 4;
    } while (i != 0);
    itoabuf[p] = '-';
	p++;
	itoabuf[p] = 0;
	strrev(itoabuf);
  }*/
  return;
}

void clear_osd(int colour)
{
	int i;
	for (i=0;i<1024;i++)
	{
		HW_OSDCHAR(0)=(i << 16)+((colour & 0xff)<<8) + 0x20;
	}
}

void clear_osd_inner(int colour)
{
	int x,y,addr;
	for (y=3;y<23;y++)
	{
		addr=y*40;
		for (x=1;x<39;x++)
		{
			HW_OSDCHAR(0)=((addr+x) << 16)+((colour & 0xff)<<8) + 0x20;		
		}
	}
}

void draw_osd_frame()
{
	int i;
	for (i=0;i<200;i++)
	{
		HW_OSDCHAR(0)=osdframe[i];
	}
}

unsigned char ascii2cbm(unsigned char c)
{
	char cbm_c=' ';
	if (c>='@' && c<='Z') {
		cbm_c=c-'@';		
	}
	if (c>='a' && c<='z') {
		cbm_c=(c-96) | 0x80;		
	}	
	if (c>=' ' && c<='?') {//space to ? map the same
		cbm_c=c;		
	}
	if (c=='_') {
		cbm_c=111;		
	}
	return cbm_c;			//unsupported chars return space
	
}

void draw_text(int x, int y,unsigned char * s,int bcol,int fcol,int t)
{
	int addr=y*40+x;
	int i=0;
	unsigned char c;
	int j;
	if (t==0) j=99; else j=t;
	while ((s[i]!=0) && (j>0)){
		c=ascii2cbm(s[i]);
		HW_OSDCHAR(0)=(addr << 16)+((bcol & 0xf) << 12)+((fcol & 0xf) << 8)+c;
		addr=addr+1;
		i=i+1;
		if (t>0) t=t-1;
		if (j>0) j=j-1;
		/*if ((x+i==28) && (y<24))
		{
			if ((s[i+1]=='D') && (s[i+2]=='I') && (s[i+3]=='R'))
				fcol=3; //change colour to cyan
			else
				fcol=7; //change colour to yellow
		}*/
	}
	while (t>0)		//if minimum length was specified pad out with spaces
	{
		HW_OSDCHAR(0)=(addr << 16)+((bcol & 0xf) << 12)+((fcol & 0xf) << 8)+0x20;
		addr=addr+1;
		t=t-1;
	}
}




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
	for (i=1;i<=255;i++)
	{
		Delay();
	}
}

void ResetLoader()
{
	
//	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_LOADER_RESET;
	SuperDelay();
}

int ioctl_download = 0; // signal indicating an active download
int ioctl_index;        // menu index used to upload the file [15:0]
int ioctl_wr;
int ioctl_addr;         // in WIDE mode address will be incremented by 2 [26:0]
int ioctl_dout; 
int ioctl_upload = 0;   // signal indicating an active upload
int ioctl_upload_req;
int ioctl_din;
int ioctl_rd;
char ioctl_file_ext[4];
int ioctl_wait;

int LoadROM(const char *filename,const char *ext)
{
	int result=0;
	int opened;

	//ResetLoader();
//	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_RESET;

	ioctl_index=0;
	if (strcmp(ext,"CRT")==0) ioctl_index=0x5;							//set index to CART
	if (strcmp(ext,"PRG")==0) ioctl_index=0x1;							//set index to PRG
	if (strcmp(ext,"TAP")==0) ioctl_index=0xc1;							//set index to Tape
	if (strcmp(ext,"ROM")==0) ioctl_index=0x8;							//set index to ROM
	if (strcmp(ext,"FLT")==0) ioctl_index=0x7;							//set index to Filter
	
	if (ioctl_index>0) {
	

	if((opened=FileOpen(&file,(char*)filename)))
	{
		
		//HW_IOCTL(IOCTL_WR)=0;		//make sure data valid is not set
		
		ioctl_addr=0;
		HW_IOCTL(IOCTL_INDEX)=ioctl_index;		//send index
		HW_IOCTL(IOCTL_ADDR)=ioctl_addr;	//set initial address 
		HW_IOCTL(IOCTL_DOWNLOAD)=1;		//turn off download
		
		
		
		int filesize=file.size;
		//unsigned int c=0;
		int bits;

	//	HW_HOST(REG_HOST_ROMSIZE) = file.size;
		
	/*	bits=0;
		c=filesize-1;
		while(c)
		{
			++bits;
			c>>=1;
		}
		bits-=9;*/

		result=1;

		while(filesize>0)
		{
			//OSD_ProgressBar(c,bits);
			if(FileRead(&file,sector_buffer))
			{
				int i;
				int w;
				unsigned char *p=(unsigned char *)&sector_buffer;
				for(i=0;i<512;i+=1)
				{
					unsigned char t=*p++;	
					if (filesize>0) {
						w=HW_IOCTL(IOCTL_WAIT) & 1;
						while (w) {
							w=HW_IOCTL(IOCTL_WAIT) & 1;
						}
						HW_IOCTL(IOCTL_ADDR)=ioctl_addr;	//set address
						HW_IOCTL(IOCTL_DOUT)=t;		//send index
						HW_IOCTL(IOCTL_WR)=1;		//pulse data valid
						//HW_IOCTL(IOCTL_WR)=0;		//pulse data valid - removed - CtrlModule will zero every cycle
						
						ioctl_addr+=1;
					}
					filesize--;
				}
			}
			else
			{
				result=0;
				filesize=0;
			}
			FileNextSector(&file);
			//filesize-=512;
			//++c;
		}
	}
	
//	Reset(0);
//	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_DIVERT_SDCARD;
	HW_IOCTL(IOCTL_DOWNLOAD)=0;		//turn off download
	
	/*if(result) {
		
		//Menu_Set(topmenu);
		//Menu_Hide();
	}
	else
		//Menu_Set(loadfailed);
	}*/
		HW_OSD(0)=1;
		HW_OSD(0)=0;			//turn off osd (we toggle on first to make sure change is registered)
		file_sel_active=0;
		clear_osd_inner(0xe1);
		numitems=writeMenu();
	}
	else result=0;
	

	
	return(result);
}

void close_file_browser() {
	file_sel_active=0;
	clear_osd_inner(0xe1);
	numitems=writeMenu();
}


//************* MENU CODE ********************
char menuItems [MAXMENU] [MAXMENUITEM+1] [MAXMENUITEMLEN+1];
char menuLists [MAXLISTIDS] [MAXLISTITEMS] [MAXLISTLEN+1];
uint32_t menuListVals [MAXLISTIDS];
uint32_t menuType[MAXMENU] [MAXMENUITEM+1];


void updateCursor()
{
	unsigned int char_value;
	unsigned int base_addr;
	int i;
	if (oldpos!=cursorpos) {
		base_addr=(oldpos+2)*40;		
		for (i=1;i<39;i++)
		{	
			HW_OSDCHAR(0x100)=base_addr+i;		//set OSD address		
			char_value=HW_OSDCHAR(0);				//read out value		
			HW_OSDCHAR(0)=((base_addr+i)<<16)+((char_value & 0xf00)<<4)+((char_value & 0xf000)>>4)+(char_value & 0xff);		//write new value	
		}
	
		base_addr=(cursorpos+2)*40;	
		for (i=1;i<39;i++)
		{	
			HW_OSDCHAR(0x100)=base_addr+i;		//set OSD address		
			char_value=HW_OSDCHAR(0);				//read out value		
			HW_OSDCHAR(0)=((base_addr+i)<<16)+((char_value & 0xf00)<<4)+((char_value & 0xf000)>>4)+(char_value & 0xff);		//write new value	
		}		
		oldpos=cursorpos;
	}
}

int writeMenu()
{
	//writeTitle(&menuItems [currmenu] [0] [0]);	
	int y=3;	//starting row
	int i=0;
	int l;
	int v;
	int f;
	int bc;
	int fc;
	while ((strcmp(&menuItems [currmenu] [i+1] [0],"END") != 0) && (i<MAXMENUITEM+1))
	{
		if (y-2==cursorpos) {
			bc=0x1;
			fc=0xe;
		}else {
			bc=0xe;
			fc=0x1;
		}
		draw_text(1,y,&menuItems [currmenu] [i+1] [0],bc,fc,38);
		if (((menuType[currmenu] [i+1] >> 8) & 0xff) == 2) { //list			
			v=(menuType[currmenu] [i+1] >> 24) & 0xff; //get list id
			l=strlen(&menuLists [v] [menuListVals[v]] [0]); //get length of text
			//writeString(&menuLists [v] [menuListVals[v]] [0],osd_width-(l*8)-8,y);
			draw_text(27,y,&menuLists [v] [menuListVals[v]] [0],bc,fc,0);
		}
		if (((menuType[currmenu] [i+1] >> 8) & 0xff) == 3) { //list			
			v=(menuType[currmenu] [i+1] >> 24) & 0xff; //get list id
			f=(menuType[currmenu] [i+1] >> 16) & 0xff; //get swap flag
			if (f)
				if (v) draw_text(35,y,"Yes",bc,fc,0); else draw_text(35,y," No",bc,fc,0);
			else				
				if (v) draw_text(35,y," No",bc,fc,0); else draw_text(35,y,"Yes",bc,fc,0);
			
		}
		if (((menuType[currmenu] [i+1] >> 8) & 0xff) == 4) { //list			
			v=(menuType[currmenu] [i+1] >> 24) & 0xff; //get list id
			f=(menuType[currmenu] [i+1] >> 16) & 0xff; //get swap flag
			if (f)
				if (v) draw_text(35,y,"Off",bc,fc,0); else draw_text(35,y," On",bc,fc,0);
			else
				if (v) draw_text(35,y," On",bc,fc,0); else draw_text(35,y,"Off",bc,fc,0);
		}
		i++;
		y++;
	}	
	return i;
}

void encode_status() {
	
/* status bits (as per MiSTer)
[0]		Reset
[1]		Release Keys on Reset,On,Off					[2] [5] [0],"Release Keys on Reset:");
[2]		Video Standard PAL,NTSC						[1] [1] [0],"Video Standard:") 03
[3]		Swap Joysticks, No, Yes						[0] [8] [0],"Swap Joysticks:");					
[5:4]	Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",			[1] [4] [0],"Aspect Ratio:") 06
[6]		Reset Disk Drives						[3] [7] [0],"Reset Disk Drives");
[7]		Tape Play/Pause
[10:8]	Scandoubler Fx,None,HQ2x-320,HQ2x-160,CRT 25%,CRT 50%,CRT 75%;
[11]	Tape Sound,Off,On							
[12]	Sound Expander,Disabled,OPL2;						[1] [14] [0],"Sound Expander:"); 0e
[13]	Left SID,6581,8580;							[1] [5] [0],"Left SID:"); 07
[15:14]	System ROM,Loadable C64,Standard C64,C64GS,Japanese;			[2] [14] [0],"System ROM:");  15
[16]	Right SID,6581,8580;							[1] [6] [0],"Right SID:"); 08
[17]	Reset & Detach Cartridge;						[0] [12] [0],"Reset & Detach Cartridge");
[19:18]	Stereo Mix,None,25%,50%,100%;						[1] [16] [0],"Stereo Mix"); 10
[22:20]	Right SID Port,Same,DE00,D420,D500,DF00;				[1] [11] [0],"Right SID Port:"); 0d			
[23]	Tape Unload;
[24]	Clear RAM on Reset,Yes,No;						[2] [6] [0],"Clear RAM on Reset::");
[25]	External IEC,Disabled,Enabled;
[27:26]	Pot 1/2,Joy 1 Fire 2/3,Mouse,Paddles 1/2;",				[2] [3] [0],"Pot 1/2:"); 13				
[29:28]	Pot 3/4,Joy 2 Fire 2/3,Mouse,Paddles 3/4;				[2] [4] [0],"Pot 3/4:"); 14
[31:30] Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;
[32]	Vertical Crop,No,Yes;
[33]	RS232 connection,Internal,External;
[35:34] VIC-II,656x,856x,Early 856x;						[1] [2] [0],"VIC-II:");  04
[36]	Real-Time Clock,Auto,Disabled;						[2] [1] [0],"Real-Time Clock:"); 11
[37]	8580 Digifix,On,Off;							[1] [12] [0],"8580 Digifix:");
[38]	Boot EasyFlash,Yes,No;							[2] [10] [0],"Boot EasyFlash:");
[39]	Tape Auto Play,Yes,No;							[2] [9] [0],"Tape Autoplay:");
[41:40]	DigiMax,Disabled,DE00,DF00;						[1] [15] [0],"Digimax:"); 0f
[42]	Pause When OSD is Open,No,Yes;						[2] [8] [0],"Pause When OSD is Open:")
[43]	Expansion,Joysticks,RS232;
[44]	Parallel port,Enabled,Disabled;						[3] [3] [0],"Parallel port:") 18
[45]	CIA,6526,8521;								[2] [2] [0],"CIA:"); 12
[47:46] Turbo mode,Off,C128,Smart;						[0] [9] [0],"Turbo Mode:"); 01
[49:48]	Turbo speed,2x,3x,4x;							[0] [10] [0],"Turbo Speed:") 02
[50]	Reset & Run PRG,Yes,No;							[2] [7] [0],"Reset & Run PRG:"
[51]	RS232 mode,UP9600,VIC-1011;						
[52]	GeoRAM,Disabled,4MB;",					
[54:53]	REU,Disabled,512KB,2MB,16MB;",
[56:55]	Enable Drive #9,If Mounted,Always,Never;				[3] [1] [0],"Enable Drive #8:"); 16
[58:57]	Enable Drive #8,If Mounted,Always,Never;				[3] [2] [0],"Enable Drive #9:"); 17
[60:59],Key modifier,L+R Shift,L Shift,R Shift;
[61]	Save cartridge;
[62]	Autosave,Off,On;
[63]	REU wrap,512KB,None;
[66:64]	Left Filter,Default,Custom 1,Custom 2,Custom 3,Adjustable;",		[1] [7] [0],"Left Filter:"); 09
[69:67]	Right Filter,Default,Custom 1,Custom 2,Custom 3,Adjustable;",		[1] [8] [0],"Right Filter:"); 0a
[72:70]	Left Fc Offset,0,1,2,3,4,5;",						[1] [9] [0],"Left Fc Offset:"); 0b
[75:73]	Right Fc Offset,0,1,2,3,4,5;						[1] [10] [0],"Right Fc Offset:"); 0c
[77:76]	Mount Write Protected,Off,#8,#9,#8 & #9;",				[0] [3] [0],"Mount Write Protected:"); 00
[80:78]	Drive RPM    (G64),300.0,300.1,300.5,301.0,302.0,299.0,299.5,299.9;",	[3] [5] [0],"Drives RPM    (G64):"); 1a
[81]	Drive Wobble (G64),Off,On;",						[3] [6] [0],"Drives Wobble (G64):");	
[84:82]	Palette,Colodore,Ultimate,Pepto-PAL,Vice,Vice6569R1,Vice6569R5,Vice8565R2,Lemon64;	[1] [3] [0],"Palette:"); 05
[86:85]	Drives OSD,Activity Only,If Mounted,Debug,Off;				[3] [4] [0],"Drives OSD:"); 19
[88:87]	SNAC Joystick,Disabled,Joy 1,Joy 2;

[90]	Tape Auto Unload,Yes,No;"
[91]	Tape Counter Reset;",
[92]	Tape Counter,Off,On;",
[93]	Tape Rewind;",
[94]	Tape Fast Forward;",
[95]	Tape Stop;",



*/
	status_bits[0]=0;		//assume no reset
	status_bits[1]=(menuType[2] [5]>>24) & 0x01;	//release keys
	status_bits[2]=menuListVals[0x03] & 0x01;		//video standard		
	status_bits[3]=(menuType[0] [5]>>24) & 0x01;	//swap joysticks
	status_bits[4]=menuListVals[0x06] & 0x01;		//aspect ratio [5:4]
	status_bits[5]=(menuListVals[0x06] >>1) & 0x01;
	status_bits[6]=0;								//reset disk drives
	status_bits[7]=0;								//tape play pause
	status_bits[8]=menuListVals[0x17] & 0x01;		//scan doubler [10:8]
	status_bits[9]=(menuListVals[0x17] >>1) & 0x01;
	status_bits[10]=(menuListVals[0x17] >>2) & 0x01;
	status_bits[11]=(menuType[3] [7]>>24) & 0x01;	//Tape sound [11]
	status_bits[12]=menuListVals[0x0e] & 0x01;		//sound expander			
	status_bits[13]=menuListVals[0x07] & 0x01;		//left SID
	status_bits[14]=0;//menuListVals[0x15] & 0x01;		//system rom [15:14]
	status_bits[15]=0;//(menuListVals[0x15] >>1) & 0x01;
	status_bits[16]=menuListVals[0x08] & 0x01;		//right SID
	status_bits[17]=0;								//reset and detach cartridge
	status_bits[18]=menuListVals[0x10] & 0x01;		//stereo mix [19:18]
	status_bits[19]=(menuListVals[0x10] >>1) & 0x01;
	status_bits[20]=menuListVals[0x0d] & 0x01;		//right SID port [22:20]
	status_bits[21]=(menuListVals[0x0d] >>1) & 0x01;
	status_bits[22]=(menuListVals[0x0d] >>2) & 0x01;
	//status_bits[23]=0;								//tape unload
	status_bits[24]=(menuType[2] [6]>>24) & 0x01;	//clear RAM on reset
	status_bits[25]=0;								//external IEC
	status_bits[26]=menuListVals[0x13] & 0x01;		//pot 1/2 [27:26]
	status_bits[27]=(menuListVals[0x13] >>1) & 0x01;
	status_bits[28]=menuListVals[0x14] & 0x01;		//pot 1/2 [29:28]
	status_bits[29]=(menuListVals[0x14] >>1) & 0x01;
	status_bits[30]=0;								//scale [31:30]
	status_bits[31]=0;								
	status_bits[32]=0;								//vertical crop
	status_bits[33]=0;								//rs232 connection
	status_bits[34]=menuListVals[0x04] & 0x01;		//VIC-II [35:34]
	status_bits[35]=(menuListVals[0x04] >>1) & 0x01;
	status_bits[36]=menuListVals[0x11] & 0x01;		//realtine clock
	status_bits[37]=(menuType[1] [14]>>24) & 0x01;	//Digifix
	status_bits[38]=(menuType[2] [11]>>24) & 0x01;	//boot easyflash
	status_bits[39]=(menuType[2] [9]>>24) & 0x01;	//Tape autoplay
	status_bits[40]=0;//menuListVals[0x0f] & 0x01;		//Digimax [41:40]
	status_bits[41]=(menuListVals[0x0f] >>1) & 0x01;
	status_bits[42]=(menuType[2] [8]>>24) & 0x01;	//pause on osd
	status_bits[43]=0;								//expansion
	status_bits[44]=0;//(menuType[3] [3]>>24) & 0x01;	//Parallel port
	status_bits[45]=menuListVals[0x12] & 0x01;		//CIA 
	status_bits[46]=menuListVals[0x01] & 0x01;		//Turbo mode [47:46]
	status_bits[47]=(menuListVals[0x01] >>1) & 0x01;
	status_bits[48]=menuListVals[0x02] & 0x01;		//Turbo speed [49:48]
	status_bits[49]=(menuListVals[0x02] >>1) & 0x01;
	status_bits[50]=(menuType[2] [7]>>24) & 0x01;	//Rest and run prg
	status_bits[51]=0;								//rs232 mode
	status_bits[52]=0;								//georam
	status_bits[53]=0;								//reu [54:53]
	status_bits[54]=0;								
	status_bits[55]=0;//menuListVals[0x16] & 0x01;		//Enable drive 8Turbo speed [56:55]
	status_bits[56]=0;//(menuListVals[0x16] >>1) & 0x01;
	status_bits[57]=0;//menuListVals[0x17] & 0x01;		//Enable drive 8Turbo speed [58:57]
	status_bits[58]=0;//(menuListVals[0x17] >>1) & 0x01;
	status_bits[59]=0;								//key modifier [60:59]
	status_bits[60]=0;								
	status_bits[61]=0;								//save cartridge
	status_bits[62]=0;								//auto save
	status_bits[63]=0;								//reu wrap
	status_bits[64]=menuListVals[0x09] & 0x01;		//left SID filter [66:64]
	status_bits[65]=(menuListVals[0x09] >>1) & 0x01;
	status_bits[66]=(menuListVals[0x09] >>2) & 0x01;
	status_bits[67]=menuListVals[0x0a] & 0x01;		//right SID filter [69:67]
	status_bits[68]=(menuListVals[0x0a] >>1) & 0x01;
	status_bits[69]=(menuListVals[0x0a] >>2) & 0x01;
	status_bits[70]=menuListVals[0x0b] & 0x01;		//left SID fc offset [72:70]
	status_bits[71]=(menuListVals[0x0b] >>1) & 0x01;
	status_bits[72]=(menuListVals[0x0b] >>2) & 0x01;
	status_bits[73]=menuListVals[0x0c] & 0x01;		//right SID fc offset [75:73]
	status_bits[74]=(menuListVals[0x0c] >>1) & 0x01;
	status_bits[75]=(menuListVals[0x0c] >>2) & 0x01;
	status_bits[76]=0;//menuListVals[0x00] & 0x01;		//mount write protected [77:76]
	status_bits[77]=0;//(menuListVals[0x00] >>1) & 0x01;
	status_bits[78]=0;//menuListVals[0x1a] & 0x01;		//drive rpm [80:78]
	status_bits[79]=0;//(menuListVals[0x1a] >>1) & 0x01;
	status_bits[80]=0;//(menuListVals[0x1a] >>2) & 0x01;
	status_bits[81]=0;//(menuType[3] [6]>>24) & 0x01;	//drive wobble
	status_bits[82]=menuListVals[0x05] & 0x01;		//palette [84:82]
	status_bits[83]=(menuListVals[0x05] >>1) & 0x01;
	status_bits[84]=(menuListVals[0x05] >>2) & 0x01;
	status_bits[85]=0;//menuListVals[0x19] & 0x01;		//drives osd [86:85]
	status_bits[86]=0;//(menuListVals[0x19] >>1) & 0x01;
	status_bits[87]=0;								//SNAC joysticks [88:87]
	status_bits[88]=0;								
	
	status_bits[89]=menuListVals[0x16] & 0x01;		//video output
	
	//status_bits[91]=0;								//tape counter reset
	status_bits[92]=0;								//tape counter off/on
	//status_bits[93]=0;								//tape rewind
	//status_bits[94]=0;								//tape fast forward
	//status_bits[95]=0;								//tape stop
	status_bits[90]=(menuType[2] [10]>>24) & 0x01;		//tape auto unload
	
	uint32_t i;
	
	/*for (i=43;i<64;i++) { //zero unused bits
		status_bits[i]=0;
	}*/
	
	status0=0;
	status1=0;
	status2=0;
	for (i=0;i<32;i++) {		//shift bits into position
		status0 |= (status_bits[i] << i);
		status1 |= (status_bits[i+32] << i);
		status2 |= (status_bits[i+64] << i);		
	}
	

}

uint32_t updateMenuType(uint32_t old, uint8_t value) {
	old &= 0x00ffffff;		//clear old type byte
	old |= (value <<24);	//or in new value
	return old;
}

void decode_status() {

	uint32_t i;
		

	for (i=0;i<32;i++) {		//shift bits into position		
		status_bits[i]=(status0 >> i) & 1;
		status_bits[i+32]=(status1 >> i) & 1;
		status_bits[i+64]=(status2 >> i) & 1;
	}	
	
	
	menuType[2] [5]=updateMenuType(menuType[2] [5],status_bits[1]);	//release keys
	menuListVals[0x03]=status_bits[2];		//video standard		
	menuType[0] [5]=updateMenuType(menuType[0] [5],status_bits[3]);	//swap joysticks
	menuListVals[0x06]=status_bits[4] | (status_bits[5] <<1);	//aspect ratio [5:4]
	
	menuListVals[0x17]=status_bits[8] | (status_bits[9] <<1)| (status_bits[10] <<2);	//scan doubler [10:8]
	
	menuType[3] [7]=updateMenuType(menuType[3] [7],status_bits[11]);	//Tape sound [11]
	//menuListVals[0x0e]=status_bits[12];		//sound expander			
	menuListVals[0x07]=status_bits[13];		//left SID
	//menuListVals[0x15]=status_bits[14] | (status_bits[15] <<1);	//system rom [15:14]
	menuListVals[0x08]=status_bits[16];		//right SID
		
	//menuListVals[0x10]=status_bits[18] | (status_bits[19] <<1);	//stereo mix [19:18]
	menuListVals[0x0d]=status_bits[20] | (status_bits[21] <<1)| (status_bits[22] <<2);	//right SID port [22:20]
	
	menuType[2] [6]=updateMenuType(menuType[2] [6],status_bits[24]);	//clear RAM on reset
		
	menuListVals[0x13]=status_bits[26] | (status_bits[27] <<1);	//pot 1/2 [27:26]	
	menuListVals[0x14]=status_bits[28] | (status_bits[29] <<1);	//pot 3/4 [29:28]
	
	menuListVals[0x04]=status_bits[34] | (status_bits[35] <<1);	//VIC-II [35:34]
	menuListVals[0x11]=status_bits[36];		//realtine clock
	menuType[1] [14]=updateMenuType(menuType[1] [14],status_bits[37]);	//Digifix
	menuType[2] [11]=updateMenuType(menuType[2] [11],status_bits[38]);	//boot easyflash
	menuType[2] [9]=updateMenuType(menuType[2] [9],status_bits[39]);	//Tape autoplay
	
	//menuListVals[0x0f]=status_bits[40] | (status_bits[41] <<1);	//Digimax [41:40]
	
	menuType[2] [8]=updateMenuType(menuType[2] [8],status_bits[42]);	//pause on osd
	
	menuType[3] [3]=updateMenuType(menuType[3] [3],status_bits[44]);	//Parallel port
	menuListVals[0x12]=status_bits[45];		//CIA 
	
	menuListVals[0x01]=status_bits[46] | (status_bits[47] <<1);//Turbo mode [47:46]
	menuListVals[0x02]=status_bits[48] | (status_bits[49] <<1);	//Turbo speed [49:48]
	
	menuType[2] [7]=updateMenuType(menuType[2] [7],status_bits[50]);	//Rest and run prg
	
	
	//menuListVals[0x16]=status_bits[55] | (status_bits[56] <<1);	//Enable drive 8 [56:55]
	//menuListVals[0x17]=status_bits[57] | (status_bits[58] <<1);	//Enable drive 9 [58:57]
	
	
	menuListVals[0x09]=status_bits[64] | (status_bits[65] <<1)| (status_bits[66] <<2);	//left SID filter [66:64]
	menuListVals[0x0a]=status_bits[67] | (status_bits[68] <<1)| (status_bits[69] <<2);	//right SID filter [69:67]
	menuListVals[0x0b]=status_bits[70] | (status_bits[71] <<1)| (status_bits[72] <<2);	//left SID fc offset [72:70]
	menuListVals[0x0c]=status_bits[73] | (status_bits[74] <<1)| (status_bits[75] <<2);	//right SID fc offset [75:73]
	
	//menuListVals[0x00]=status_bits[76] | (status_bits[77] <<1);	//mount write protected [77:76]
	
	//menuListVals[0x1a]=status_bits[78] | (status_bits[79] <<1)| (status_bits[80] <<2);	//drive rpm [80:78]
	//menuType[3] [6]=updateMenuType(menuType[3] [6],status_bits[81]);	//drive wobble
	menuListVals[0x05]=status_bits[82] | (status_bits[83] <<1)| (status_bits[84] <<2);	//palette [84:82]
	//menuListVals[0x19]=status_bits[85] | (status_bits[86] <<1);	//drives osd [86:85]
	
	menuListVals[0x16]=status_bits[89];		//VGA/RGB 
	
	menuType[2] [10]=updateMenuType(menuType[2] [10],status_bits[90]);	//Tape auto unload
	

	//if (osd_on) writeMenu();
	writeMenu();

}


/*
bits 7-0
id

bits 15-8
0 = HEADER
1 = Sub Menu
2 = List 
3 = No/Yes
4 = On/Off
5 = File Browser
6 = Tape Controls
7 = Reset Disk Drives
8 = Back
9 = Reset
10 = save cfg
bits 23 - 16
num items in list

bits 31 - 24
list id or menu id or file filter (0 = disks, 1=prg,crt,tap, 2=rom, 3=flt, 4=crt only



*/
void initMenus() {
	strcpyr(&menuItems[0] [0] [0],"MAIN MENU");
	/*strcpyr(&menuItems[0] [1] [0],"Mount #8 *.D64,G64,T64,D81");
	strcpyr(&menuItems[0] [2] [0],"Mount #9 *.D64,G64,T64,D81");
	strcpyr(&menuItems[0] [3] [0],"Mount Write Protected:");*/
	strcpyr(&menuItems[0] [1] [0],"Load *.PRG,CRT,TAP");
	strcpyr(&menuItems[0] [2] [0],"Audio & Video");
	strcpyr(&menuItems[0] [3] [0],"Hardware");
	strcpyr(&menuItems[0] [4] [0],"Tapes");
	strcpyr(&menuItems[0] [5] [0],"Swap Joysticks:");
	strcpyr(&menuItems[0] [6] [0],"Turbo Mode:");
	strcpyr(&menuItems[0] [7] [0],"Turbo Speed:");
	strcpyr(&menuItems[0] [8] [0],"Save Config");
	strcpyr(&menuItems[0] [9] [0],"Reset");
	strcpyr(&menuItems[0] [10] [0],"Reset & Detach Cartridge");
	strcpyr(&menuItems[0] [11] [0],"END");
	
	menuType[0] [0] = 0x00000001;
	//menuType[0] [1] = 0x00000502;
	//menuType[0] [2] = 0x00000503;
	
	/*menuType[0] [3] = 0x00040204;	
	strcpyr(&menuLists[0x00] [0] [0],"        Off");
	strcpyr(&menuLists[0x00] [1] [0],"         #8");
	strcpyr(&menuLists[0x00] [2] [0],"         #9");
	strcpyr(&menuLists[0x00] [3] [0],"    #8 & #9");
	menuListVals[0x00]=0;	*/
	
	menuType[0] [1] = 0x01000505;
	menuType[0] [2] = 0x01000106;
	menuType[0] [3] = 0x02000107;
	menuType[0] [4] = 0x03000108;
	menuType[0] [5] = 0x00010309;
	
	menuType[0] [6] = 0x0103020a;
	strcpyr(&menuLists[0x01] [0] [0],"        Off");
	strcpyr(&menuLists[0x01] [1] [0],"       C128");
	strcpyr(&menuLists[0x01] [2] [0],"      Smart");
	menuListVals[0x01]=0;
	
	menuType[0] [7] = 0x0203020b;
	strcpyr(&menuLists[0x02] [0] [0],"         2x");
	strcpyr(&menuLists[0x02] [1] [0],"         3x");
	strcpyr(&menuLists[0x02] [2] [0],"         4x");	
	menuListVals[0x02]=0;
			
	menuType[0] [8] = 0x00000a39;
	menuType[0] [9] = 0x0000090c;
	menuType[0] [10] = 0x0100090d;
	
	
	strcpyr(&menuItems[1] [0] [0],"AUDIO & VIDEO");
	strcpyr(&menuItems[1] [1] [0],"Video Standard:");	
	strcpyr(&menuItems[1] [2] [0],"Video Output:");
	strcpyr(&menuItems[1] [3] [0],"Scan Doubler:");
	strcpyr(&menuItems[1] [4] [0],"VIC-II:");
	strcpyr(&menuItems[1] [5] [0],"Palette:");
	strcpyr(&menuItems[1] [6] [0],"Aspect Ratio:");
	strcpyr(&menuItems[1] [7] [0],"Left SID:");
	strcpyr(&menuItems[1] [8] [0],"Right SID:");
	strcpyr(&menuItems[1] [9] [0],"Left Filter:");
	strcpyr(&menuItems[1] [10] [0],"Right Filter:");
	strcpyr(&menuItems[1] [11] [0],"Left Fc Offset:");
	strcpyr(&menuItems[1] [12] [0],"Right Fc Offset:");
	strcpyr(&menuItems[1] [13] [0],"Right SID Port:");
	strcpyr(&menuItems[1] [14] [0],"8580 Digifix:");
	strcpyr(&menuItems[1] [15] [0],"Load Custom Filters *.FLT");
	/*strcpyr(&menuItems[1] [14] [0],"Sound Expander:");
	strcpyr(&menuItems[1] [15] [0],"Digimax:");
	strcpyr(&menuItems[1] [16] [0],"Stereo Mix");*/
	strcpyr(&menuItems[1] [16] [0],"Back");
	strcpyr(&menuItems[1] [17] [0],"END");
	
	menuType[1] [0] = 0x0000000e;
	
	menuType[1] [1] = 0x0302020f;
	strcpyr(&menuLists[0x03] [0] [0],"        PAL");
	strcpyr(&menuLists[0x03] [1] [0],"       NTSC");
	menuListVals[0x03]=0;
	
	menuType[1] [2] = 0x16020237;
	strcpyr(&menuLists[0x16] [0] [0],"        VGA");
	strcpyr(&menuLists[0x16] [1] [0],"        RGB");
	menuListVals[0x16]=0;
	
	menuType[1] [3] = 0x17050238;
	strcpyr(&menuLists[0x17] [0] [0],"       None");
	strcpyr(&menuLists[0x17] [1] [0],"    CRT 25%");
	strcpyr(&menuLists[0x17] [2] [0],"    CRT 50%");
	strcpyr(&menuLists[0x17] [3] [0],"    CRT 75%");
	strcpyr(&menuLists[0x17] [4] [0],"       Full");
	menuListVals[0x17]=0;
	
	menuType[1] [4] = 0x04030210;
	strcpyr(&menuLists[0x04] [0] [0],"       656x");
	strcpyr(&menuLists[0x04] [1] [0],"       856x");
	strcpyr(&menuLists[0x04] [2] [0]," Early 856x");
	menuListVals[0x04]=0;
	
	menuType[1] [5] = 0x05080211;
	strcpyr(&menuLists[0x05] [0] [0],"   Colodore");
	strcpyr(&menuLists[0x05] [1] [0],"   Ultimate");
	strcpyr(&menuLists[0x05] [2] [0],"  Pepto-PAL");
	strcpyr(&menuLists[0x05] [3] [0],"       Vice");
	strcpyr(&menuLists[0x05] [4] [0]," Vice6569R1");
	strcpyr(&menuLists[0x05] [5] [0]," Vice6569R5");
	strcpyr(&menuLists[0x05] [6] [0]," Vice8565R2");
	strcpyr(&menuLists[0x05] [7] [0],"   Lemon 64");
	menuListVals[0x05]=0;
	
	menuType[1] [6] = 0x06020212;
	strcpyr(&menuLists[0x06] [0] [0],"   Original");
	strcpyr(&menuLists[0x06] [1] [0],"Full Screen");
	menuListVals[0x06]=0;
	
	menuType[1] [7] = 0x07020213;
	strcpyr(&menuLists[0x07] [0] [0],"       6581");
	strcpyr(&menuLists[0x07] [1] [0],"       8580");
	menuListVals[0x07]=0;
	
	menuType[1] [8] = 0x08020214;
	strcpyr(&menuLists[0x08] [0] [0],"       6581");
	strcpyr(&menuLists[0x08] [1] [0],"       8580");
	menuListVals[0x08]=0;
	
	menuType[1] [9] = 0x09050215;
	strcpyr(&menuLists[0x09] [0] [0],"    Default");
	strcpyr(&menuLists[0x09] [1] [0],"   Custom 1");
	strcpyr(&menuLists[0x09] [2] [0],"   Custom 2");
	strcpyr(&menuLists[0x09] [3] [0],"   Custom 3");
	strcpyr(&menuLists[0x09] [4] [0]," Adjustable");
	menuListVals[0x09]=0;
	
	menuType[1] [10] = 0x0a050216;
	strcpyr(&menuLists[0x0a] [0] [0],"    Default");
	strcpyr(&menuLists[0x0a] [1] [0],"   Custom 1");
	strcpyr(&menuLists[0x0a] [2] [0],"   Custom 2");
	strcpyr(&menuLists[0x0a] [3] [0],"   Custom 3");
	strcpyr(&menuLists[0x0a] [4] [0]," Adjustable");
	menuListVals[0x0a]=0;
	
	menuType[1] [11] = 0x0b060217;
	strcpyr(&menuLists[0x0b] [0] [0],"          0");
	strcpyr(&menuLists[0x0b] [1] [0],"          1");
	strcpyr(&menuLists[0x0b] [2] [0],"          2");
	strcpyr(&menuLists[0x0b] [3] [0],"          3");
	strcpyr(&menuLists[0x0b] [4] [0],"          4");
	strcpyr(&menuLists[0x0b] [5] [0],"          5");
	menuListVals[0x0b]=0;
	
	menuType[1] [12] = 0x0c060218;
	strcpyr(&menuLists[0x0c] [0] [0],"          0");
	strcpyr(&menuLists[0x0c] [1] [0],"          1");
	strcpyr(&menuLists[0x0c] [2] [0],"          2");
	strcpyr(&menuLists[0x0c] [3] [0],"          3");
	strcpyr(&menuLists[0x0c] [4] [0],"          4");
	strcpyr(&menuLists[0x0c] [5] [0],"          5");
	menuListVals[0x0c]=0;
	
	menuType[1] [13] = 0x0d050219;
	strcpyr(&menuLists[0x0d] [0] [0],"       Same");
	strcpyr(&menuLists[0x0d] [1] [0],"       DE00");
	strcpyr(&menuLists[0x0d] [2] [0],"       D420");
	strcpyr(&menuLists[0x0d] [3] [0],"       D500");
	strcpyr(&menuLists[0x0d] [4] [0],"       DF00");	
	menuListVals[0x0d]=0;
	
	menuType[1] [14] = 0x0000041a;
	
	menuType[1] [15] = 0x0300051b;
	
	/*menuType[1] [14] = 0x0e02021c;
	strcpyr(&menuLists[0x0e] [0] [0],"   Disabled");
	strcpyr(&menuLists[0x0e] [1] [0],"       OPL2");	
	menuListVals[0x0e]=0;
	
	menuType[1] [15] = 0x0f03021d;
	strcpyr(&menuLists[0x0f] [0] [0],"   Disabled");
	strcpyr(&menuLists[0x0f] [1] [0],"       DE00");	
	strcpyr(&menuLists[0x0f] [2] [0],"       DF00");	
	menuListVals[0x0f]=0;
	
	menuType[1] [16] = 0x1004021e;
	strcpyr(&menuLists[0x10] [0] [0],"       None");
	strcpyr(&menuLists[0x10] [1] [0],"        25%");	
	strcpyr(&menuLists[0x10] [2] [0],"        50%");	
	strcpyr(&menuLists[0x10] [3] [0],"       100%");	
	menuListVals[0x10]=0;*/
	
	menuType[1] [16] = 0x0000081f;
	
	
	strcpyr(&menuItems[2] [0] [0],"HARDWARE");
	strcpyr(&menuItems[2] [1] [0],"Real-Time Clock:");
	strcpyr(&menuItems[2] [2] [0],"CIA:");
	strcpyr(&menuItems[2] [3] [0],"Pot 1/2:");
	strcpyr(&menuItems[2] [4] [0],"Pot 3/4:");
	strcpyr(&menuItems[2] [5] [0],"Release Keys on Reset:");
	strcpyr(&menuItems[2] [6] [0],"Clear RAM on Reset::");
	strcpyr(&menuItems[2] [7] [0],"Reset & Run PRG:");
	strcpyr(&menuItems[2] [8] [0],"Pause When OSD is Open:");	
	strcpyr(&menuItems[2] [9] [0],"Tape Auto Play:");	
	strcpyr(&menuItems[2] [10] [0],"Tape Auto Unload:");	
	strcpyr(&menuItems[2] [11] [0],"Boot EasyFlash:");	
	//strcpyr(&menuItems[2] [11] [0],"System ROM C64+C1541            *.ROM");	
	strcpyr(&menuItems[2] [12] [0],"System ROM C64                  *.ROM");	
	//strcpyr(&menuItems[2] [12] [0],"System ROM C1581                *.ROM");
	strcpyr(&menuItems[2] [13] [0],"Boot Cartridge                  *.CRT");
	//strcpyr(&menuItems[2] [14] [0],"System ROM:");	
	strcpyr(&menuItems[2] [14] [0],"Back");
	strcpyr(&menuItems[2] [15] [0],"END");
	
	menuType[2] [0] = 0x00000020;
	

	menuType[2] [1] = 0x11020221;
	strcpyr(&menuLists[0x11] [0] [0],"       Auto");
	strcpyr(&menuLists[0x11] [1] [0],"   Disabled");
	menuListVals[0x11]=1;
	
	menuType[2] [3] = 0x12020222;
	strcpyr(&menuLists[0x12] [0] [0],"       6526");
	strcpyr(&menuLists[0x12] [1] [0],"       8521");
	menuListVals[0x12]=0;
	
	menuType[2] [4] = 0x13030223;
	strcpyr(&menuLists[0x13] [0] [0],"Joy1 fire 2");
	strcpyr(&menuLists[0x13] [1] [0],"      Mouse");
	strcpyr(&menuLists[0x13] [2] [0],"Paddles 1/2");
	menuListVals[0x13]=0;
	
	menuType[2] [5] = 0x14030223;
	strcpyr(&menuLists[0x14] [0] [0],"Joy2 fire 2");
	strcpyr(&menuLists[0x14] [1] [0],"      Mouse");
	strcpyr(&menuLists[0x14] [2] [0],"Paddles 1/2");
	menuListVals[0x14]=0;
	
	menuType[2] [6] = 0x00000324;
	menuType[2] [7] = 0x00000325;
	menuType[2] [8] = 0x00010326;
	menuType[2] [9] = 0x00000327;
	menuType[2] [10] = 0x00000328;
	menuType[2] [11] = 0x00000328;
	
	menuType[2] [12] = 0x02000529;
	//menuType[2] [12] = 0x0200052a;
	menuType[2] [13] = 0x0400052b;
	
	/*menuType[2] [14] = 0x15030223;
	strcpyr(&menuLists[0x15] [0] [0],"   Loadable");
	strcpyr(&menuLists[0x15] [1] [0],"   Standard");
	strcpyr(&menuLists[0x15] [2] [0],"      C64GS");
	strcpyr(&menuLists[0x15] [3] [0],"   Japanese");
	menuListVals[0x15]=0;*/
	
	menuType[2] [14] = 0x0000082c;

	
	strcpyr(&menuItems[3] [0] [0],"TAPE OPTIONS");
	strcpyr(&menuItems[3] [1] [0],"Tape Play/Pause");
	strcpyr(&menuItems[3] [2] [0],"Tape Stop");
	strcpyr(&menuItems[3] [3] [0],"Tape Rewind");
	strcpyr(&menuItems[3] [4] [0],"Tape Fast Forward");
	strcpyr(&menuItems[3] [5] [0],"Tape Counter Reset");
	strcpyr(&menuItems[3] [6] [0],"Tape Counter:");
	strcpyr(&menuItems[3] [7] [0],"Tape Sound:");	
	strcpyr(&menuItems[3] [8] [0],"Tape Unload");	
	strcpyr(&menuItems[3] [9] [0],"Back");	
	strcpyr(&menuItems[3] [10] [0],"END");
	
	menuType[3] [0] = 0x0000002d;
	

	menuType[3] [1] = 0x0100062e;
	menuType[3] [2] = 0x0200062f;
	menuType[3] [3] = 0x03000630;
	menuType[3] [4] = 0x04000631;
	menuType[3] [5] = 0x05000632;
	
	menuType[3] [6] = 0x00010333;
	menuType[3] [7] = 0x00010334;
	
	menuType[3] [8] = 0x06000635;
	
	menuType[3] [9] = 0x00000836;
	
	
	/*strcpyr(&menuItems[3] [0] [0],"DRIVES OPTIONS");
	strcpyr(&menuItems[3] [1] [0],"Enable Drive #8:");
	strcpyr(&menuItems[3] [2] [0],"Enable Drive #9:");
	strcpyr(&menuItems[3] [3] [0],"Parallel port:");
	strcpyr(&menuItems[3] [4] [0],"Drives OSD:");
	strcpyr(&menuItems[3] [5] [0],"Drives RPM    (G64):");
	strcpyr(&menuItems[3] [6] [0],"Drives Wobble (G64):");
	strcpyr(&menuItems[3] [7] [0],"Reset Disk Drives");	
	strcpyr(&menuItems[3] [8] [0],"Back");	
	strcpyr(&menuItems[3] [9] [0],"END");
	
	menuType[3] [0] = 0x0000002d;
	

	menuType[3] [1] = 0x1603022e;
	strcpyr(&menuLists[0x16] [0] [0]," If Mounted");
	strcpyr(&menuLists[0x16] [1] [0],"     Always");
	strcpyr(&menuLists[0x16] [2] [0],"      Never");
	menuListVals[0x16]=0;
	
	menuType[3] [2] = 0x1703022f;
	strcpyr(&menuLists[0x17] [0] [0]," If Mounted");
	strcpyr(&menuLists[0x17] [1] [0],"     Always");
	strcpyr(&menuLists[0x17] [2] [0],"      Never");
	menuListVals[0x17]=0;
	
	menuType[3] [3] = 0x18020230;
	strcpyr(&menuLists[0x18] [0] [0],"    Enabled");
	strcpyr(&menuLists[0x18] [1] [0],"   Disabled");	
	menuListVals[0x18]=0;
	
	menuType[3] [4] = 0x19080231;
	strcpyr(&menuLists[0x19] [0] [0],"   Activity");
	strcpyr(&menuLists[0x19] [1] [0]," If Mounted");	
	strcpyr(&menuLists[0x19] [2] [0],"      Debug");
	strcpyr(&menuLists[0x19] [3] [0],"        Off");
	
	menuType[3] [5] = 0x1a080232;
	strcpyr(&menuLists[0x1a] [0] [0],"      300.0");
	strcpyr(&menuLists[0x1a] [1] [0],"      300.1");	
	strcpyr(&menuLists[0x1a] [2] [0],"      300.5");
	strcpyr(&menuLists[0x1a] [3] [0],"      301.0");
	strcpyr(&menuLists[0x1a] [4] [0],"      302.0");
	strcpyr(&menuLists[0x1a] [5] [0],"      299.0");
	strcpyr(&menuLists[0x1a] [6] [0],"      299.5");
	strcpyr(&menuLists[0x1a] [7] [0],"      299.9");
	menuListVals[0x1a]=0;
	
	menuType[3] [6] = 0x01000433;
	
	menuType[3] [7] = 0x00000734;
	menuType[3] [8] = 0x00000835;*/
	
	
	
	
	
}


void process_menu(uint32_t mask,int joy_code) {
//	if (joyclear==0) return; //hacky - to stop continuous pressing
	
	if ((mask == KEY_UPARROW)  || ((joy_code & 1))) {
		if (cursorpos>1) {cursorpos--;} else {cursorpos=numitems;};
		updateCursor();			
		//joyclear=0;	
	}
	
	if ((mask == KEY_DOWNARROW)  || ((joy_code & 2))) {
		if (cursorpos<numitems) {cursorpos++;} else {cursorpos=1;}
		updateCursor();			
		//joyclear=0;	
	}
	
	int v;
	int mt;
	int m;
	int e;
	status_bits[7]=0;	//tape play/pause
	status_bits[95]=0;	//tape stop
	status_bits[93]=0;	//tape rewind
	status_bits[94]=0;	//tape fast forward
	status_bits[91]=0;	//tape counter reset
	status_bits[23]=0;	//tape unload
	if ((mask == KEY_ENTER) || ((joy_code & 16))) {
		//joyclear=0;	
		mt=((menuType[currmenu] [cursorpos] >> 8) & 0xff);		//get menutype
		switch (mt) {
			case 1:		//sub menu
				v=(menuType[currmenu] [cursorpos] >> 24) & 0xff; //get menu id
				//clear_osd;
				//draw_osd_frame();
				clear_osd_inner(0xe1);
				cursorpos=1;
				oldpos=1;
				currmenu=v;
				numitems=writeMenu();				
				updateCursor();
			break;
			case 2:		//list				
				v=(menuType[currmenu] [cursorpos] >> 24) & 0xff; //get list id
				e=(menuType[currmenu] [cursorpos] >> 16) & 0xff; //get num lid entries
				m=menuListVals[v];
				m++;
				if (m==e) m=0;
				menuListVals[v]=m;
				writeMenu();
			break;
			case 3:		//yes no
				v=(menuType[currmenu] [cursorpos] >> 24) & 0xff; //get list id
				v=1-v;
				menuType[currmenu] [cursorpos]&=0x00ffffff;
				menuType[currmenu] [cursorpos]|=(v<<24);
				writeMenu();
			break;
			case 4:		//on off
				v=(menuType[currmenu] [cursorpos] >> 24) & 0xff; //get list id
				v=1-v;
				menuType[currmenu] [cursorpos]&=0x00ffffff;
				menuType[currmenu] [cursorpos]|=(v<<24);
				writeMenu();
			break;
			case 5:		//File selector
				v=(menuType[currmenu] [cursorpos] >> 24) & 0xff;	//get filter type
				FileSelector_Init(v);
				file_sel_active=1;
			break;			
			case 6:		//tape controls				
				v=(menuType[currmenu] [cursorpos] >> 24) & 0xff;	//get command
				if (v==1) status_bits[7]=1;	//tape play/pause
				if (v==2) status_bits[95]=1;	//tape stop
				if (v==3) status_bits[93]=1;	//tape rewind
				if (v==4) status_bits[94]=1;	//tape fast forward
				if (v==5) status_bits[91]=1;	//tape counter reset
				if (v==6) status_bits[23]=1;	//tape unload
			break;
			case 7:		//reset disk drives				
				status0 |= 64;	//set disk reset flag
				IO_RW(IO_STATUS0)=status0;
				status0 &= 0xffffffbf;	//clear disk reset flag
			break;
			case 8:	//menu back
				if (currmenu>0) {				
				clear_osd_inner(0xe1);
				currmenu=0;
				cursorpos=1;
				oldpos=1;
				numitems=writeMenu();			
				updateCursor();
			break;
		}
			case 9:		//reset (and detach cart if id set)				
				status0 |= 1;	//set reset flag
				if ((menuType[currmenu] [cursorpos] >> 24) & 0x1) status0 |= 0x20000;; //detach cart flag
				IO_RW(IO_STATUS0)=status0;
				status0 &= 0xffffdffe;	//clear reset and cart detach flag
				HW_OSD(0)=1;
				HW_OSD(0)=0;			//turn off osd (we toggle on first to make sure change is registered)
			break;
			case 10:
				if(FileOpen(&file,"C64     CFG"))
				{									
					FileRead(&file,sector_buffer);
					sector_buffer[0]=status0 & 0xff;
					sector_buffer[1]=(status0 >> 8) & 0xff;
					sector_buffer[2]=(status0 >> 16) & 0xff;
					sector_buffer[3]=(status0 >> 24) & 0xff;
					sector_buffer[4]=status1 & 0xff;
					sector_buffer[5]=(status1 >> 8) & 0xff;
					sector_buffer[6]=(status1 >> 16) & 0xff;
					sector_buffer[7]=(status1 >> 24) & 0xff;
					sector_buffer[8]=status2 & 0xff;
					sector_buffer[9]=(status2 >> 8) & 0xff;
					sector_buffer[10]=(status2 >> 16) & 0xff;
					sector_buffer[11]=(status2 >> 24) & 0xff;
					FileWrite(&file,sector_buffer);
				}		
			break;
			
		}		
		encode_status();
		IO_RW(IO_STATUS2)=status2;
		IO_RW(IO_STATUS1)=status1;
		IO_RW(IO_STATUS0)=status0;
	}
		
		
		
		
		
	//if (mask==KEY_ESC) {		
	if ((mask == KEY_ESC)  || ((joy_code & 32))) {
		if (currmenu>0) {			
			clear_osd_inner(0xe1);
			currmenu=0;
			cursorpos=1;
			oldpos=1;
			numitems=writeMenu();			
			updateCursor();
		}
	}
	
	
}



int old_key_state=0;
int old_joy_state=0xffff;



void processInput()
{
	//uint32_t mask;
	int key_state=HW_PS2(0);
	int joy_state=key_state;//(key_state & 0x1ff800) >> 11;
	//itoa(joy_state);
	//draw_text(0,0,itoabuf,0xe,0x1,0);
	int raw_code;	
	int joy_code=0;	
	if (((key_state & 0x400) !=(old_key_state & 0x400))  || (joy_state != old_joy_state))	//key state changed
	{
		if (key_state & 0x200) 	//key pressed
		{
			raw_code=((key_state & 0x100)>>1)+(key_state & 0x7f);
		}
		if (joy_state != old_joy_state) joy_code=(((joy_state >> 11) & 0x1f) | ((joy_state >>16) & 0x1f) | (joy_state & 0x3f)); else joy_code=0x0;
		//itoa(joy_code);
		//draw_text(36,0,itoabuf,0xe,0x1,0);
		old_key_state=key_state;
		old_joy_state=joy_state;
		if (file_sel_active) process_files(raw_code,joy_code); else process_menu(raw_code,joy_code);					
	}
	
	
	
}



int main(int argc,char **argv)
{
	
	
	clear_osd(0xe1);		//light blue background and white text
	draw_osd_frame();
	draw_text(1,24,"CURSORS=MOVE  ENTER=SELECT  BREAK=BACK",0xe,0x1,0);
	//draw_text(1,24,"CURSOR=MOVE  ENTER=SELECT  ESCAPE=BACK",0xe,0x1,0);
	
	
	int osd_ctrl;
	int osd_on=0;
	file_sel_active=0;
		
	//draw_text(1,14,"About to Find Drive",0xe,0x1,0);
	drive_avail=FindDrive();		//flag whether SD Card is available
	//if (drive_avail) FileSelector_SetLoadFunction(LoadROM);
	//draw_text(1,15,"After Find Drive",0xe,0x1,0);
	initMenus();	
	
	currmenu=0;
	cursorpos=1;
	oldpos=1;
	numitems=writeMenu();
	
	
	int i;
	//updateCursor();
	if (drive_avail){
		
		if(FileOpen(&file,"C64     CFG"))
		{
			if(FileRead(&file,sector_buffer)) {
				status0=(sector_buffer[3]<<24) | (sector_buffer[2]<<16) | (sector_buffer[1]<<8) | sector_buffer[0];
				status1=(sector_buffer[7]<<24) | (sector_buffer[6]<<16) | (sector_buffer[5]<<8) | sector_buffer[4];
				status2=(sector_buffer[11]<<24) | (sector_buffer[10]<<16) | (sector_buffer[9]<<8) | sector_buffer[8];
				
			decode_status();
			
			/*draw_text(1,21,"Config Loaded from SD Card",0xe,0x1,0);
			itoa(status0);
			draw_text(1,22,itoabuf,0xe,0x1,0);
			itoa(status1);
			draw_text(10,22,itoabuf,0xe,0x1,0);
			itoa(status2);
			draw_text(19,22,itoabuf,0xe,0x1,0);*/
			}
		}
		else		//no config file so create one
		{
			fileTYPE cfg_file;
			copyname(cfg_file.name,"C64     CFG",11);
			cfg_file.attributes=0;
			cfg_file.size=SwapBBBB(12);
			i=FileCreate(0, &cfg_file); //0 translates to root directory
			if (i) {				
				mmemset(sector_buffer,0,512);
				sector_buffer[0]=status0 & 0xff;
				sector_buffer[1]=(status0 >> 8) & 0xff;
				sector_buffer[2]=(status0 >> 16) & 0xff;
				sector_buffer[3]=(status0 >> 24) & 0xff;
				sector_buffer[4]=status1 & 0xff;
				sector_buffer[5]=(status1 >> 8) & 0xff;
				sector_buffer[6]=(status1 >> 16) & 0xff;
				sector_buffer[7]=(status1 >> 24) & 0xff;
				sector_buffer[8]=status2 & 0xff;
				sector_buffer[9]=(status2 >> 8) & 0xff;
				sector_buffer[10]=(status2 >> 16) & 0xff;
				sector_buffer[11]=(status2 >> 24) & 0xff;
				FileWrite(&cfg_file,sector_buffer);
		//		draw_text(1,22,"New Config Created",0xe,0x1,0);
			}	
			encode_status();
		}		
				
		
		IO_RW(IO_STATUS2)=status2;
		IO_RW(IO_STATUS1)=status1;
		IO_RW(IO_STATUS0)=status0;			
		
		
		
		/*clear_osd(0xe1);		//light blue background and white text
		int x=0;
		int y=0;
		int i=0;
		for (y=0;y<25;y++)
			for (x=0;x<4;x++)
			{
				itoa(fat_buffer.fat32[i]);
				i++;
				draw_text(x*9,y,itoabuf,0xe,0x1,0);			
			}*/
	}
	
	
	
	
		
	
	while(1)
	{
		osd_ctrl=HW_OSD(0);
		osd_on=(osd_ctrl & 1);
		if (osd_on) {
			//Menu_Run();
			processInput();
			SuperDelay();
			/*if (drive_avail==1) draw_text(1,17,"DRIVE FOUND",0xe,0x1,0); else {
				draw_text(1,17,"DRIVE NOT FOUND",0xe,0x1,0);
				itoa((unsigned int)drive_avail);
				draw_text(30,17,itoabuf,0xe,0x1,0);
			}*/
		
			/*unsigned int v;
			v=HW_DEBUG(CLKFBOUT_MULT);
			itoa(v & 0xffff);
			draw_text(0,0,itoabuf,0xe,0x1,0);
			itoa((v >> 16) & 0xffff);
			draw_text(34,0,itoabuf,0xe,0x1,0);*/
			
		}
	}
	return(0);
}
