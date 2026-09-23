//#include "FAT.h"
#include "minfat.h"
#include "main.h"
#include "host.h"
#include "swap.h"
#include "keyboard.h"
#include <stdbool.h>

static int romindex=0;
static int selectpos=0;
static int oldselectpos=0;
static int filefilter=0;
static int numfiles=0;
/*static int romcount;

static void listroms();
static void selectrom(int row);
static void scrollroms(int row);
int (*loadfunction)(const char *filename); // Callback function
*/

int strlen(char * s) {
      int i = 0, sum = 0;
      char c = s[0];

      while(c != '\0') {
            sum++;
            c = s[++i];
      }
      return sum;
}




// A utility function to reverse a string
/*void strrev(char *str)
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
*/

char strbuf[12];


void itoaFixedWidth(unsigned long zahl) {
   static uint32_t subtractors[] = {1000000000, 100000000, 10000000, 1000000,
                                    100000, 10000, 1000, 100, 10, 1};
   //static char string[12];
   char n, *str = strbuf;	
   uint32_t *sub = subtractors;
   uint32_t u = (uint32_t) zahl;    
   uint8_t  i = 10;	
   *str++ = ' ';
   while (i > 1 && u < *sub) {
       i--;
       sub++;
       *str++ = ' ';
   }
   //*(str-1) = sign;
   while (i--) {
       n = '0';
       while (u >= *sub) {
           u -= *sub;
           n++;
       }
       *str++ = n;
       sub++;
   }
   *str = 0;
   //return string;
}

/*static void copyname(char *dst,const unsigned char *src,int l,int tl)
{
	int i;
	for(i=0;i<l;++i)
		*dst++=*src++;
	//*dst++=0;
	for (;i<tl;++i)
		*dst++=' ';
}

*/
static DIRENTRY *nthfile(int n)
{
	int i,j=0;
	DIRENTRY *p;
	for(i=0;(j<=n) && (i<dir_entries);++i)
	{
		p=NextDirEntry(i);
		if(p)
			++j;
	}
	return(p);
}


//file filter (0 = disks, 1=prg,crt,tap, 2=rom, 3=flt, 4=crt only
int check_filter(const char * ext) {
	if ((strcmp(ext,"D64")==0) && (filefilter==0)) return 1;
	if ((strcmp(ext,"G64")==0) && (filefilter==0)) return 1;
	if ((strcmp(ext,"T64")==0) && (filefilter==0)) return 1;
	if ((strcmp(ext,"D81")==0) && (filefilter==0)) return 1;
	if ((strcmp(ext,"PRG")==0) && (filefilter==1)) return 1;
	if ((strcmp(ext,"CRT")==0) && ((filefilter==1) || (filefilter==4))) return 1;
	if ((strcmp(ext,"TAP")==0) && (filefilter==1)) return 1;
	if ((strcmp(ext,"FLT")==0) && (filefilter==3)) return 1;
	return 0;
}

char ext[4];

FileSelector_CountFiles (void){
	int i;
	numfiles=0;
	for(i=0;i<dir_entries;++i)		
	{
		DIRENTRY *p=NextDirEntry(i);
		if(p) {			
			//copyname(ext,p->Extension,3);
			//if ((p->Attributes&ATTR_DIRECTORY) || (check_filter(ext))) numfiles++;
			numfiles++;
		}
		
	}
}




static void selectrom(int row)
{
	DIRENTRY *p=nthfile(romindex+row);
	if(p)
	{
		
		copyname(ext,p->Extension,3);
		copyname(longfilename,p->Name,11);	// Make use of the long filename buffer to store a temporary copy of the filename,		
											// since loading it by name will overwrite the sector buffer which currently contains it!
		LoadROM(longfilename,ext);
	}
}



static void selectdir(int row)
{
	DIRENTRY *p=nthfile(romindex+row);
	if(p)
	{
		ChangeDirectory(p);
		romindex=0;
		selectpos=0;
		oldselectpos=0;
		clear_osd_inner(0xe1);
		FileSelector_CountFiles();
		FileSelector_ListFiles();
	}
}


void update_select()
{
	unsigned int char_value;
	unsigned int base_addr;
	int i;
	if (oldselectpos!=selectpos) {
		base_addr=(oldselectpos+3)*40;		
		for (i=1;i<39;i++)
		{	
			HW_OSDCHAR(0x100)=base_addr+i;		//set OSD address		
			char_value=HW_OSDCHAR(0);				//read out value		
			HW_OSDCHAR(0)=((base_addr+i)<<16)+((char_value & 0xf00)<<4)+((char_value & 0xf000)>>4)+(char_value & 0xff);		//write new value	
		}
	
		base_addr=(selectpos+3)*40;	
		for (i=1;i<39;i++)
		{	
			HW_OSDCHAR(0x100)=base_addr+i;		//set OSD address		
			char_value=HW_OSDCHAR(0);				//read out value		
			HW_OSDCHAR(0)=((base_addr+i)<<16)+((char_value & 0xf00)<<4)+((char_value & 0xf000)>>4)+(char_value & 0xff);		//write new value	
		}		
		oldselectpos=selectpos;
	}
}
/*
static void scrollroms(int row)
{
	switch(row)
	{
		case ROW_LINEUP:
			if(romindex)
				--romindex;
			break;
		case ROW_PAGEUP:
			romindex-=16;
			if(romindex<0)
				romindex=0;
			break;
		case ROW_LINEDOWN:
			++romindex;
			break;
		case ROW_PAGEDOWN:
			romindex+=16;
			break;
	}
	listroms();
	Menu_Draw();
}*/

/*const char *get_filename_ext(const char *filename) {
    const char *dot = strrchr(filename, '.');
    if(!dot || dot == filename) return "";
    return dot + 1;
}*/


/*static void listroms()
{
	int i,j;
	j=0;
	for(i=0;(j<romindex) && (i<dir_entries);++i)
	{
		DIRENTRY *p=NextDirEntry(i);
		if(p)
			++j;
	}

	for(j=0;(j<19) && (i<dir_entries);++i)	
	{
		DIRENTRY *p=NextDirEntry(i);
		if(p)
		{
			// FIXME declare a global long file name buffer.
			if(p->Attributes&ATTR_DIRECTORY)
			{
				rommenu[j].action=MENU_ACTION(&selectdir);
				//romfilenames[j][0]=62; // Right arrow
				//romfilenames[j][1]=' ';
				if(longfilename[0])
					copyname(romfilenames[j],longfilename,27,27);					
				else
					copyname(romfilenames[j],p->Name,11,27);					
				
				romfilenames[j][27]=' ';
				copyname(romfilenames[j]+28,"DIR       ",10,10);				
				romfilenames[j++][38]=0;
			}
			else
			{
				rommenu[j].action=MENU_ACTION(&selectrom);
				if(longfilename[0])
					copyname(romfilenames[j],longfilename,27,27);					
				else
					copyname(romfilenames[j],p->Name,11,27);					
				
				char str[12];
				romfilenames[j][27]=' ';
				copyname(romfilenames[j]+27,"           ",11,11);
				
				//str=get_filename_ext(p->Name);
				//if (strlen(str) <4){
					//copyname(romfilenames[j]+28,str,strlen(str),3);
				//}
				copyname(romfilenames[j]+28,p->Extension,3,3);					
		*/		
								
				
				/*citoa((int)(p->FileSize>>10), str,10);
				//citoa(320, str, 10);
				if ((strlen(str) >0) && (strlen(str) <=4)){
					copyname(romfilenames[j]+32+(4-strlen(str)),str,strlen(str),4);
					romfilenames[j] [36]='K';					
				}*/							
	/*							
				romfilenames[j++][38]=0;
				
			}
		}
		else
			romfilenames[j][0]=0;		
	}
	for(;j<19;++j)
		romfilenames[j][0]=0;		
}*/




FileSelector_ListFiles (void){
	int i,j;
	int bc,fc;
	j=0;
	for(i=0;(j<romindex) && (i<dir_entries);++i)		//discard entries before current position
	{
		DIRENTRY *p=NextDirEntry(i);
		if(p)
			++j;
	}
	for(j=0;(j<20) && (i<dir_entries);++i)	
	{
		DIRENTRY *p=NextDirEntry(i);
		if(p)
		{
			// FIXME declare a global long file name buffer.
			if(p->Attributes&ATTR_DIRECTORY)
			{
				//rommenu[j].action=MENU_ACTION(&selectdir);
				//romfilenames[j][0]=62; // Right arrow
				//romfilenames[j][1]=' ';
				if (j==selectpos){
					bc=0x1;
					fc=0xe;
				} else {
					bc=0xe;
					fc=0x1;
				}
				if(longfilename[0])
					draw_text(1,j+3,longfilename,bc,fc,27);					
				else {
					draw_text(1,j+3,p->Name,bc,fc,8);						
					draw_text(9,j+3,"                   ",bc,fc,19);				
				}
				
				if (j==selectpos){
					bc=0x3;
					fc=0xe;
				} else {
					bc=0xe;
					fc=0x3;
				}
				draw_text(28,j+3,"           ",bc,fc,11);
				draw_text(29,j+3,"DIR",bc,fc,3);								
				j++;
			}
			else {
				copyname(ext,p->Extension,3);
				if (1)//(check_filter(ext))
			{	
				if (j==selectpos){
					bc=0x1;
					fc=0xe;
				} else {
					bc=0xe;
					fc=0x1;
				}		
				if(longfilename[0])
					draw_text(1,j+3,longfilename,bc,fc,27);					
				else {
					draw_text(1,j+3,p->Name,bc,fc,8);	
					draw_text(9,j+3,".",bc,fc,1);								
					draw_text(10,j+3,p->Extension,bc,fc,3);					
					draw_text(13,j+3,"               ",bc,fc,15);								
				}
				
				
				if (j==selectpos){
					bc=0x7;
					fc=0xe;
				} else {
					bc=0xe;
					fc=0x7;
				}
				draw_text(28,j+3,"           ",bc,fc,11);
				draw_text(29,j+3,ext,bc,fc,3);								
				
				
				
				draw_text(37,j+3," ",bc,fc,1);				
				unsigned int fs=SwapBBBB(p->FileSize);
				if (fs>=1048576) {
					fs>>=20;
					draw_text(37,j+3,"M",bc,fc,1);
				}
				else if (fs>=1024) {
					fs>>=10;
					draw_text(37,j+3,"K",bc,fc,1);
				}
				itoaFixedWidth(fs);

								
				draw_text(33,j+3,&strbuf[7],bc,fc,4);				
											
				j++;
												
				
			}
		}
		}		
		
	}
}

process_files(int raw_code,int joy_code){
		if ((raw_code==KEY_UPARROW) || ((joy_code & 1))) {
			if (selectpos>0) {
				selectpos--;
				update_select();
			} else {
				if (romindex>0) {
					romindex--;
					clear_osd_inner(0xe1);
					FileSelector_ListFiles();
				}
			}
			
		}
		
		if ((raw_code==KEY_PAGEUP)  || ((joy_code & 4))) {
			if (romindex>0) {
				romindex-=19;
				if (romindex<0) romindex=0;
				clear_osd_inner(0xe1);
				FileSelector_ListFiles();
			}
		}
					
		if ((raw_code==KEY_DOWNARROW)  || ((joy_code & 2))) {
			if (selectpos<19) {
				if (selectpos<numfiles-1) {
					selectpos++;
					update_select();
				}
			} else {
				if (romindex<numfiles-20) {
					romindex++;
					clear_osd_inner(0xe1);
					FileSelector_ListFiles();
				}
			}
			
		}
		
		if ((raw_code==KEY_PAGEDOWN)  || ((joy_code & 8))) {
			if (romindex<numfiles-20) {
				romindex+=19;
				if (romindex>numfiles-20) romindex=numfiles-20;
				clear_osd_inner(0xe1);
				FileSelector_ListFiles();
			}
		}
		
		if ((raw_code==KEY_ENTER)  || ((joy_code & 16))) {
			DIRENTRY *p=nthfile(romindex+selectpos);
			if(p)
			{
				if(p->Attributes&ATTR_DIRECTORY)
						selectdir(selectpos);
				else
						selectrom(selectpos);
				
			}		
		}
		
		if (raw_code==KEY_ESC) {
				close_file_browser();
		}
}

FileSelector_Init (int filter){
	filefilter=filter;
	clear_osd_inner(0xe1);
	romindex=0;
	selectpos=0;
	oldselectpos=0;
	FileSelector_CountFiles();
	FileSelector_ListFiles();
}
	

/*void FileSelector_Show(int row)
{
	romindex=0;
	listroms();
	rommenu[19].action=MENU_ACTION(Menu_Get()); // Set parent menu entry
	Menu_Set(rommenu);
}


void FileSelector_SetLoadFunction(int (*func)(const char *filename))
{
	loadfunction=func;
}*/

