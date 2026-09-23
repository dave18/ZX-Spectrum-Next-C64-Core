#include "main.h"
#include "menu.h"
#include "host.h"
#include "keyboard.h"

static struct menu_entry *menu;
static int menu_visible=0;
int menu_toggle_bits=0;
static int menurows;
static int currentrow;
static int previousrow;

void Menu_Draw()
{
	struct menu_entry *m=menu;
	
	clear_osd_inner(0xe1);
	menurows=0;
	int x,y;
	
	while(m->type!=MENU_ENTRY_NULL)
	{
		int i;
		char **labels;				
		y=menurows+3;
		x=1;
		switch(m->type)
		{
			/*case MENU_ENTRY_CYCLE:
				i=MENU_CYCLE_VALUE(m);	// Access the first byte
				labels=(char**)m->label;
				OSD_Puts("\x16 ");
				OSD_Puts(labels[i]);
				break;
			case MENU_ENTRY_SLIDER:
				DrawSlider(m);
				OSD_Puts(m->label);
				break;
			case MENU_ENTRY_TOGGLE:
				if((menu_toggle_bits>>MENU_ACTION_TOGGLE(m->action))&1)
					OSD_Puts("\x14 ");
				else
					OSD_Puts("\x15 ");
				// Fall through*/
			default:
				//OSD_Puts(m->label);
				draw_text(x , y ,m->label,0xe ,0x1 ,38 );
				break;
		}
		++menurows;
		m++;
	}
}

struct menu_entry *Menu_Get()
{
	return(menu);
}

void Menu_Set(struct menu_entry *head)
{
	menu=head;
	currentrow=0;
	Menu_Draw();
//	currentrow=menurows-1;
	previousrow=-1;//currentrow;
}

void Menu_Hide()
{
	// Wait for key releases before hiding the menu, to avoid stray keyup messages reaching the host core.
//	while(TestKey(KEY_ESC) || TestKey(KEY_ENTER) || (( joy_pins & 0x40 ) > 0 )) //drive button
//		HandlePS2RawCodes();
//	OSD_Show(menu_visible=0);
}


void Update_Current() {
	unsigned int char_value;
	unsigned int base_addr;
	int i;
	if (previousrow!=currentrow) {
		base_addr=(previousrow+3)*40;
		int i;
		for (i=1;i<39;i++)
		{	
			HW_OSDCHAR(0x100)=base_addr+i;		//set OSD address		
			char_value=HW_OSDCHAR(0);				//read out value		
			HW_OSDCHAR(0)=((base_addr+i)<<16)+((char_value & 0xf00)<<4)+((char_value & 0xf000)>>4)+(char_value & 0xff);		//write new value	
		}
	
		base_addr=(currentrow+3)*40;	
		for (i=1;i<39;i++)
		{	
			HW_OSDCHAR(0x100)=base_addr+i;		//set OSD address		
			char_value=HW_OSDCHAR(0);				//read out value		
			HW_OSDCHAR(0)=((base_addr+i)<<16)+((char_value & 0xf00)<<4)+((char_value & 0xf000)>>4)+(char_value & 0xff);		//write new value	
		}		
		previousrow=currentrow;
	}
	else
	{
		if (previousrow==-1)
		{
			base_addr=(currentrow+3)*40;	
			for (i=1;i<39;i++)
			{	
				HW_OSDCHAR(0x100)=base_addr+i;		//set OSD address		
				char_value=HW_OSDCHAR(0);				//read out value		
				HW_OSDCHAR(0)=((base_addr+i)<<16)+((char_value & 0xf00)<<4)+((char_value & 0xf000)>>4)+(char_value & 0xff);		//write new value	
			}		
			previousrow=currentrow;
		}
	}
}

int Menu_Run()
{
	
	
	int i;
	
	//draw_text(1,18,"WAITING FOR KEY",0xe,0x1,0);
	struct menu_entry *m=menu;
	
	int key_state=HW_PS2(0);
	int old_key_state=key_state;
	int raw_code;
	
	Update_Current();
	
	while ((key_state & 0x400) ==(old_key_state & 0x400))	//key state changed
	{
		key_state=HW_PS2(0);
	//	draw_text(1,19,"KEY STATE CHANGED",0xe,0x1,0);
	}
	
	//draw_text(1,20,"KEY PRESSED",0xe,0x1,0);
	//if we get here a key has been pressed
	if (key_state & 0x200) {	//key pressed
		raw_code=((key_state & 0x100)>>1)+(key_state & 0x7f);
	
	
		if (raw_code == KEY_UPARROW )
		{
			//if (( joy_pins & 0x10 ) > 0 ) DelayJoystick(); //wait to release the joystick
		
		
			if(currentrow)
				--currentrow;
			else if(( m + menurows ) -> action )
			{
				MENU_ACTION_CALLBACK(( m + menurows ) -> action )( ROW_LINEUP );
				previousrow=-1;
			}
		}
	
		if ( raw_code==KEY_DOWNARROW )
		{
			//if (( joy_pins & 0x08 ) > 0) DelayJoystick(); //wait to release the joystick
		
			if ( currentrow < ( menurows - 1 ))
				++currentrow;
			else if (( m + menurows ) -> action )
			{
				MENU_ACTION_CALLBACK(( m + menurows ) -> action )( ROW_LINEDOWN );
				previousrow=-1;
			}
		}
		
		if(raw_code == KEY_PAGEUP)
		{
			if(currentrow)
				currentrow=0;
			else if((m+menurows)->action)
			{
				MENU_ACTION_CALLBACK((m+menurows)->action)(ROW_PAGEUP);
				previousrow=-1;
			}
		}

		if(raw_code == KEY_PAGEDOWN)
		{
			if(currentrow<(menurows-1))
				currentrow=menurows-1;
			else if((m+menurows)->action)
			{
				MENU_ACTION_CALLBACK((m+menurows)->action)(ROW_PAGEDOWN);
				previousrow=-1;
			}
		}
		
		
	
		if (raw_code==KEY_ENTER )
		{
			struct menu_entry *m=menu;
	
			//if (( joy_pins & 0x01 ) > 0 ) DelayJoystick(); //wait to release the joystick
	
			i = currentrow;
		
			while(i)
			{
				++m;
				--i;
			}
			switch(m->type)
			{
				case MENU_ENTRY_SUBMENU:
					//Menu_Set(MENU_ACTION_SUBMENU(m->action));
				break;
				case MENU_ENTRY_CALLBACK:
					MENU_ACTION_CALLBACK(m->action)(currentrow);
					break;
				case MENU_ENTRY_TOGGLE:
					//i=1<<MENU_ACTION_TOGGLE(m->action);
					//menu_toggle_bits^=i;
					//Menu_Draw();
					break;
				case MENU_ENTRY_CYCLE:
					//i=MENU_CYCLE_VALUE(m)+1;
					//if(i>=MENU_CYCLE_COUNT(m))
//					i=0;
					//MENU_CYCLE_VALUE(m)=i;
					//Menu_Draw();
					break;
				default:
					break;
			}

		}
	}

	
	

	
}

