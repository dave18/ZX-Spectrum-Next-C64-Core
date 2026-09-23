#ifndef MAIN_H
#define MAIN_H

#define MAXMENU 5
#define MAXMENUITEM 19
#define MAXMENUITEMLEN 38

#define MAXLISTIDS 27
#define MAXLISTITEMS 8
#define MAXLISTLEN 20


#ifndef uint32_t
#define uint32_t unsigned int
#endif

#ifndef uint8_t
#define uint8_t unsigned char
#endif

void draw_text(int , int ,unsigned char * ,int ,int ,int );
void clear_osd_inner(int );
char * strcpyr(char *, const char *);
int mstrncmp(const char *s1, const char *s2, int n);
int LoadROM(const char *,const char *);
void close_file_browser(void);
void copyname(char *dst,const unsigned char *src,int l);
void *mmemset (void *dest, register int val, register int len);

extern int file_sel_active;

#endif
