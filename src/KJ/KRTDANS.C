#include "stdio.h"
#include "ctype.h"
#include "string.h"
#include "conio.h"
#include "dos.h"
#include "graphics.h"
#include "io.h"
#include "alloc.h"
#include "bios.h"
#include "stdlib.h"
#include "time.h"

#define TRUE	1			/* Define some handy constants	*/
#define FALSE	0			/* Define some handy constants	*/
#define ON	1			/* Define some handy constants	*/
#define OFF	0			/* Define some handy constants	*/

#define L32 for(n=0;n<32;n++)
#define L16 for(n=0;n<16;n++)
#define L8  for(n=0;n<8 ;n++)
#define L4  for(n=0;n<4 ;n++)


void main(void);
void  einde(void);
extern void  Initialize(void);
void kaarten();
void kaartvorm(int x,int y);
void aas();
void heer();
void vrouw();
void boer();
void Klaver(int x,int y);
void Schoppen(int x,int y);
void Ruiten(int x,int y);
void Harten(int x,int y);
void Tien(void);
void Negen(void);
void Acht(void);
void Zeven(void);
void achterkant();
void kleuren(void);

int    GraphDriver;		/* The Graphics device driver		*/
int    GraphMode;		/* The Graphics mode value		*/
int    MaxX, MaxY;		/* The maximum resolution of the screen */
int    MaxColors;		/* The maximum # of colors available	*/
int    ErrorCode;		/* Reports any graphics errors		*/
struct palettetype palette;     /* for palette info			*/


 #define NKRT 35
 void *krt[NKRT];
 char text[80];
 char klaver[15][15];
 char schoppen[15][15];
char ruiten[15][15];
char harten[15][15];
char inputline[60][55];
/************************************************************************/
/******************************************************************/
void main(void)
{
 int m,n,x,y;
 unsigned int size;
 Initialize();
 size=imagesize(0,0,52,82);
  for(n=0;n<NKRT;n++)
    {
     krt[n]=farmalloc(size);
     if(krt[n]==NULL)  {closegraph(); printf("No room, no: %d\n",n); exit(1); }
     }
 getimage(0,0,52,82,krt[33]);  /* leeg veld*/

 kaarten();
 einde();
}

/******************************************************/
 void einde(void)
 {
 int n;
 closegraph();
 for(n=NKRT-1;n>=0;n--)  free(krt[n]);
 while(kbhit());
 return;
 }
/********************* Initialize *********************/
void Initialize(void)
{
  if (registerbgidriver(Herc_driver)   < 0) exit(-1);
  if (registerbgidriver(EGAVGA_driver) < 0) exit(-1);
  if (registerbgidriver(CGA_driver   ) < 0) exit(-1);
  GraphDriver = DETECT;			/* Request auto-detection	*/
/*GraphDriver=EGA;
GraphMode=EGAHI;
*/
  initgraph( &GraphDriver, &GraphMode, "");
  ErrorCode = graphresult();		/* Read result of initialization*/
  if( ErrorCode != grOk ){		/* Error occured during init	*/
    printf(" Graphics System Error: %s\n", grapherrormsg( ErrorCode ) );
    exit( 1 );
  }
  getpalette( &palette );		/* Read the palette from board	*/
  MaxColors = getmaxcolor() + 1;	/* Read maximum number of colors*/
  MaxX = getmaxx();
  MaxY = getmaxy(); /* Read size of screen		*/
}



/********************************************************************/

void kaarten()
{
 int m,n,x,y,i,j,posx,posy;
 float(yy);
 unsigned int size;
 setfillstyle(SOLID_FILL,GREEN);
 floodfill(10,10,WHITE);
 setcolor(BLACK);
 outtextxy(150,1,"Jan van Gentstraat 7,1171GH Badhoevedorp,Ed Nieuwenhuys");
 kleuren();
 if(kbhit()) {getch(); return;}
 Zeven();
 if(kbhit()) {getch(); return;}
 Acht();
 if(kbhit()) {getch(); return;}
 Negen();
 if(kbhit()) {getch(); return;}
 Tien();
 if(kbhit()) {getch(); return;}
 boer();
 if(kbhit()) {getch(); return;}
 vrouw();
 if(kbhit()) {getch(); return;}
 heer();
 if(kbhit()) {getch(); return;}
 aas();
 if(kbhit()) {getch(); return;}

     i=0;
     for(n=0;n<4;n++)
      {
      for(m=0;m<8;m++)
       {
       getimage(10+m*70,10+n*85,62+m*70,92+n*85,krt[i++]);
       }
      }

if(!kbhit()) randomize();
while(!kbhit())
 {
  n=random(8);
  m=random(4);
  posx=10+n*70;
  posy=10+m*85;
  x=random(25)+30-2*n;
  y=random(7)+1;
  while(!kbhit())
   {
   posx+=(x--/2);
   if(abs(x)<4 && abs(posx)<5) break;
   posy+=y;
   if(posx > MaxX-55) {if(x<2) x=6;   x=(-x*2)/3;      posx+=x/2; }
   if(posx <1)
     {posx=0;
      /*if(posy>200 && posy<250) break;
      else */
      {
      if(x>-2) x=-3;            x=(-x*7)/10;   posx+=x/2; }}
   if(posy > MaxY-85) {if(y<3) y=4;   x=(x*2)/3; y=(-y*2)/3; x=-x; posy+=y; }
   if(posy <1)        {if(y>-3) y=-4; x=(x*2)/3; y=(-y*2)/3; x=-x; posy+=y; }
   putimage(posx,posy,krt[(m*8)+n],COPY_PUT);
   delay(1);
  }
 }
while(bioskey(1)) getch();
}

void kaartvorm(int x,int y)
{
 setcolor(BLACK);

 rectangle(x,y,x+52,y+82);
 setcolor(WHITE);
 setfillstyle(SOLID_FILL,WHITE);
 floodfill(x+10,y+10,BLACK);
}

void aas()
{
 int m,n,i,j,x,y,color;
 x=10;

/*aas*/
strcpy(inputline[0],"cccccccccccccccccccccccccccccccccccccccccccccccccc");
strcpy(inputline[1],"cccccccccccccccccccccccccccccccccccccccccccccccccc");
strcpy(inputline[2],"cccccccccccccccccccccccccccccccccccccccccccccccccc");
strcpy(inputline[3],"cccccccccccccccccccccccccccccccccccccccccccccccccc");
strcpy(inputline[4],"cccccccccccccccccccccaaaaaaacccccccccccccccccccccc");
strcpy(inputline[5],"cccccccccccccccccccccaaaaaaaaaaccccccccccccccccccc");
strcpy(inputline[6],"ccccccccccccccccccccaaaaaaaaaaaaaccccccccccccccccc");
strcpy(inputline[7],"cccccccccccccccccccaaaaaaaaaaacccccccccccccccccccc");
strcpy(inputline[8],"cccccccccccccccccccyyyyyyyyyyycccccccccccccccccccc");
strcpy(inputline[9],"cccccccaaaaacccccccyyyyyyyyyyccccaaaaaaccccccccccc");
strcpy(inputline[10],"ccccccaaaaaaaccccccccccccccccccaaaaaaaaaaaaacccccc");
strcpy(inputline[11],"ccccccaaaaaaaaccccccccccRccccccaaaaaaaaaaaaccccccc");
strcpy(inputline[12],"cccccyyyyyyyyyccccccccccRRcccccyyyyyyyyyaccccccccc");
strcpy(inputline[13],"ccccccyyyyyyyccccccccccRrRcccccyyyyyyyyccccccccccc");
strcpy(inputline[14],"ccccccyyyyyycccccccccccRrRcccccyyyyyyycccccccccccc");
strcpy(inputline[15],"cccccccccccccccccccccccRrrRccccccccccccccccccccccc");
strcpy(inputline[16],"ccccccccccccccccccccccRrrrRccccccccccccccccccccccc");
strcpy(inputline[17],"ccccccccccccccccccccccRrrrRccccccccccccccccccccccc");
strcpy(inputline[18],"ccccccRccccccccccccccRrrrrrRcccccccccccccccccccccc");
strcpy(inputline[19],"ccccccRRcRccccccccccRrruuurrRccccccccccccccccccccc");
strcpy(inputline[20],"cccccRrrzrRccccccccczYYyyyYYzccccccccccccccccccccc");
strcpy(inputline[21],"ccccRrrrzrRccccccccczyzuuuzuzccccccRcccccccccccccc");
strcpy(inputline[22],"cccczzzzzzzRRRRRcccczuuuuuuuzcccccRzRcccRccccccccc");
strcpy(inputline[23],"cccczeuuzuzrrrzRRRRRzeuzzzuuzccccRrzrRcRRccccccccc");
strcpy(inputline[24],"cccczeuuzezrrrrzrrrrzzzeuuzzzcccRrrzrRRrrRcccccccc");
strcpy(inputline[25],"cccczeuuzuzrrrrzrrrrzeeeuuuuzccRrrzzzRRrrrRccccccc");
strcpy(inputline[26],"cccczeeuzezrrrrrzrrrzeeeuuuuzcczzzuuzzzzzrRccccccc");
strcpy(inputline[27],"cccczeuuzuzrrrrrzrrrzeeeuuuuzcczeeuuzuzeezzccccccc");
strcpy(inputline[28],"cccczeuuzuzrrrrrrzrrzeeuuuuuzzczeeuuzuzuuuzccccccc");
strcpy(inputline[29],"cccczezzzzzzzzzzzzzzzeeuuuuuzuzzeeuuzuzuuuzccccccc");
strcpy(inputline[30],"cggczuzuzuzuzuzuzuzuzeuuuuuuzuuuzeuuzuzuuuzccccccc");
strcpy(inputline[31],"ggggzuzeuuuuuzzzzzzzzeuuuuuuzuuuzuuuzuzuuuzccccccc");
strcpy(inputline[32],"ggggzuzzzzzzzzuuuuuuzeuuuuuuzuuuzuuuzuzuuuzccccccc");
strcpy(inputline[33],"ggggzuzeeuguuguuuuuuzeuuuuuuzuuuzuuuzuzuuuziiiiiii");
strcpy(inputline[34],"gzgizuzeeuguuguuuuuuzuuuuuuuzuuuzuuuzuzuuuziiiiiii");
strcpy(inputline[35],"iziizuzeuugzggguuuuuzeeuuuuuzuuuzuuuzuzuuuzzzzzzzz");
strcpy(inputline[36],"iziizuzeuuuzuuuuuuuuzeuuuuuuzuuuzuuuzuzuubbuuuubbz");
strcpy(inputline[37],"iziizuzeguuzuuguuuugzeeuuuuuzuuuzUUUzbzUUbbuuuubbz");
strcpy(inputline[38],"iziizuzeguuzuggguuggzuuuuuuuzuuggbbbbbbbbbbbbbbbbb");
strcpy(inputline[39],"bbbbbbbbbbbbggggggggzuuuuuuuzggbbbbbbbbbbbbbbbbbbb");
strcpy(inputline[40],"wwwwwwwbbbbbbbbbbbbbzUUUUUUUzbbbbbbbbbbbbbbbbbbbbb");
strcpy(inputline[41],"bbbbbbbbbbbbwwwwwgbbbbbbbbbbbbwwwggbbbbbbbbbbbbbbb");
strcpy(inputline[42],"bbbbbbggwbbbbbbbbbbwwwwwwggbbbbbbbbbbbbbbbbbbbbbbb");
strcpy(inputline[43],"bbbbbbggbbbbbbbbbbbbbbbbbggbbbwwwwwwggbbbbbbbbbbbb");
strcpy(inputline[44],"bbbbbbbbbbbbbggbwwwwwwwbbbbbbbbbbbbbggbbbbbbbbbbbb");
strcpy(inputline[45],"bbbbbbbbbbbbbggbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
strcpy(inputline[46],"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbgbbbbbbbbbbbbbbbbbbbb");
strcpy(inputline[47],"bbbbbbbbbbbbbbbbbbbbgiiiiiiiiiiiiiiiibbbbbbbbbiiii");
strcpy(inputline[48],"bbbbiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii");

for(i=0;i<4;i++)
 {
  y=i*85+10;

    kaartvorm(x,y);


 for(n=0;n<50;n++)
    {
     for(m=0;m<48;m++)
       {
	switch(tolower(inputline[n][m]))
	{
		case 'z': color = BLACK;	break;
		case 'b': color = BLUE;		break;
		case 'g': color = GREEN;	break;
		case 'o': color = CYAN;		break;
		case 'r': color = GREEN+i;	break;
		case 'p': color = MAGENTA;	break;
		case 'u': color = BROWN;	break;
		case 'a': color = LIGHTGRAY;	break;
		case 'y': color = DARKGRAY;	break;
		case 'c': color = LIGHTBLUE;	break;
		case 'i': color = LIGHTGREEN;	break;
		case 'n': color = LIGHTCYAN;	break;
		case 'j': color = LIGHTRED;	break;
		case 't': color = LIGHTMAGENTA;	break;
		case 'e': color = YELLOW;	break;
		case 'w': color = WHITE;	
	}
	putpixel(x+m+2,y+n+17,color);
       }
    }
    setcolor(BLACK);
    settextjustify(CENTER_TEXT,CENTER_TEXT);
    settextstyle(DEFAULT_FONT,HORIZ_DIR,2);
    setusercharsize(3,2,1,1);
    outtextxy(x+19,y+2,"A");
    outtextxy(x+19,y+67,"A");

 
  switch(i) {
   case 0: Klaver(x+2,y+2);
	   Klaver(x+37,y+2);
	   Klaver(x+37,y+67);
	   Klaver(x+2,y+67);
	   break;
   case 1: Schoppen(x+2,y+2);
	   Schoppen(x+37,y+2);
	   Schoppen(x+37,y+67);
	   Schoppen(x+2,y+67);
	   break;
   case 2: Ruiten(x+2,y+2);
	   Ruiten(x+37,y+2);
	   Ruiten(x+37,y+67);
	   Ruiten(x+2,y+67);
	   break;
   case 3: Harten(x+2,y+2);
	   Harten(x+37,y+2);
	   Harten(x+37,y+67);
	   Harten(x+2,y+67);
	   break;
	   }
  }
   

}

void heer()
{
 int m,n,i,j,x,y,color;
 x=80;

/*heer*/
strcpy(inputline[0],"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
strcpy(inputline[1],"xxxxxxxxxxxxxxxxxxEeJjEeJjEeJjxxxxxxxxxxxxxxxxxxxx");
strcpy(inputline[2],"xxxxxxxxxxxxxxxxxxEeJjEeJjEeJjxxxxxxxxxxxxxxxxxxxx");
strcpy(inputline[3],"xxxxxxxxxxxxxxxxxxEeJjEeJjEeJjxxxxxxxxxxxxxxxxxxxx");
strcpy(inputline[4],"xxxxxxxxxxxxxxxxxxzzzzzzzzzzzzxxxxxxxxxxjxxxxxxxxx");
strcpy(inputline[5],"xxxxxxxxxxxxxxxxxxEegeegeegeeExxxxxxxxxjjjjxxxxxxx");
strcpy(inputline[6],"xxxxxxxxxxxxxxxxxxEEEEEEEEEEEExxxxxxxxjjjjjjxxxxxx");
strcpy(inputline[7],"xxxxxxxxxxxxxxxxxxrrrwwwwwwwwwxxxxxxxxxjjjjxxxxxxx");
strcpy(inputline[8],"xxxxxxxxxxxxxxxxxxrrrwwwwwwwwwrxxxxxxxxxjjxxxxxxxx");
strcpy(inputline[9],"xxxxxxxxxxxxxxxxxrrrrrwzzwwzzrrxxxxxxxxEEEExxxxxxx");
strcpy(inputline[10],"xxxxxxxxxxxxxxxxrrrrrwwwwzwwwrrxxxxxxxEeeExxxxxxxx");
strcpy(inputline[11],"xxxxxxxxxxxxxxxxrrrrwwwwwwzwwrrxxxxxxxEbeExxxxxxxx");
strcpy(inputline[12],"xxxxxxxxxxxxxxxrrrrrwwwwwwzwwrrxxxxxxEeeExxxxxxxxx");
strcpy(inputline[13],"xxxxxxxxxxxxxxxrrrrrwwwwwzzwwrrxxxxxxEjjExxxxxxxxx");
strcpy(inputline[14],"xxxxxxxxxxxxxxrrrrrrwwwwwwwwwrrxxxxxEjjExxxxxxxxxx");
strcpy(inputline[15],"xxxxxxxxxxxxxxrrrrrrrrrzrrrzrrrxxxxxEeeExxxxxxxxxx");
strcpy(inputline[16],"xxxxxxxxxxxxxxrrrrrrrrrrrzzrrrrxxxxxEeeExxxxxxxxxx");
strcpy(inputline[17],"xxxxxxxxxxxxxxrrrrrrrrrrrrrrrwrxxxxEegExxxxxxxxxxx");
strcpy(inputline[18],"xxxxxxxxxxxxxxrrrrrrrrrrrrrrrwrxxxxEeeExxxxxxxxxxx");
strcpy(inputline[19],"xxxxxxxxxxxxxxrErrPrrrrrrrrrrPrxxxxEbeExxxxxxxxxxx");
strcpy(inputline[20],"xxxxxxxxxxxxxxEeePppppprrrrrrpppPxEeeExxxxxxxxxxxx");
strcpy(inputline[21],"xxxxxxxxxxxxxEeeePppppppprrrpppPeEppExxxxxxxxxxxxx");
strcpy(inputline[22],"xxxxxxxxxxxBbEeeeePpppppppppppPeeEppExxxxxxxxxxxxx");
strcpy(inputline[23],"xxxxxxxxxxBbbbbEeeeePPPPppppEEeeEeeExxxxxxxxxxxxxx");
strcpy(inputline[24],"xxxxxxxxxBbbbbbEEeeeeeeeEEEEeeeeEeeExxxxxxxxxxxxxx");
strcpy(inputline[25],"xxxxxxxxBbbbbbbbbEeeeeeeeeeeeeeeEeeExxxxxxxxxxxxxx");
strcpy(inputline[26],"xxxxxxxxBbbbbbbbbbEEeeeeeeeeeeeEeeEBxxxxxxxxxxxxxx");
strcpy(inputline[27],"xxxxxxxxBbbbbbbbbbbbbEEEEEEEEbEeeEbbBxxxxxxxxxxxxx");
strcpy(inputline[28],"xxxxxxxBbbbbbbbbbbbbbbbbbbbbbbEeeEbbbbBxxxxxxxxxxx");
strcpy(inputline[29],"xxxxxxxBbbbbbbbbbbbbbbbbGbbbbbErrEbbbbbBxxxxxxxxxx");
strcpy(inputline[30],"xxxxxxxBbbbbbbbbbbbbbbbGgGGbbErrEbbbbbbBxxxxxxxxxx");
strcpy(inputline[31],"xxxxxxBbbbbbbbbbbbbbbbGggggGbEeeEbbbbbbbBxxxxxxxxx");
strcpy(inputline[32],"xxxxxxBbbbbbbbbbbbbbbbGgggggEttEbbbbbbbbBxxxxxxxxx");
strcpy(inputline[33],"xxxxxxBbbbbbbbbbbbbbbGgpppggEetEbbbbbbbbbBxxxxxxxx");
strcpy(inputline[34],"xxxxxxBbbbbbbbbbbbbbGzzpppzEeeEbbbbbbbbbBxxxxxxxxx");
strcpy(inputline[35],"xxxxxBbbbbbbbbbbbbbbGggpppgEeeEgBbbbbbbbbbBxxxxxxx");
strcpy(inputline[36],"xxxxxBbbbbbbbbbbbbbGgggggggEezEgBbbbbbbbbbBxxxxxxx");
strcpy(inputline[37],"xxxxxBbbbbbbbbbbbbbGggggggEieEgggBbbbbbbbbbBxxxxxx");
strcpy(inputline[38],"xxxxxBbbbbbbbbbbbbbGggggggEiiEgggBbbbbbbbbbBxxxxxx");
strcpy(inputline[39],"xxxxxBbbbbbbbbbbbbGggggggEeeEggggBbbbbbbbbbBxxxxxx");
strcpy(inputline[40],"xxxxxBbbbbbbbbbbbbGggggggEooEggggBbbbbbbbbbBxxxxxx");
strcpy(inputline[41],"xxxxxBbbbbbbbbbbbGgggggggEooEgggggBbbbbbbbbbBxxxxx");
strcpy(inputline[42],"xxxxxBbbbbbbbbbbbGggggggEeeEggggggBbbbbbbbbbBxxxxx");
strcpy(inputline[43],"xxxxxBbbbbbbbbbbGgtttgggEeeEggggttBbbbbbbbbbBxxxxx");
strcpy(inputline[44],"xxxxBbbbbbbbbbbGgttgttgEeuEggggttgtBbbbbbbbbbBxxxx");
strcpy(inputline[45],"xxxxBbbbbbbbbbGgttgggttEuuEgggttgggBbbbbbbbbbBxxxx");
strcpy(inputline[46],"xxxxBbbbbbbbbbGttgggggEeeEgggttggggBbbbbbbbbbBxxxx");
strcpy(inputline[47],"xxxxBbbbbbbbbGttggggggEeeEggttgggggBbbbbbbbbbBxxxx");
strcpy(inputline[48],"xxxxBbbbbbbbbGtgggggggEeetgttggggggBbbbbbbbbbBxxxx");


for(i=0;i<4;i++)
 {
  y=i*85+10;

    kaartvorm(x,y);
 for(n=0;n<50;n++)
  {   for(m=0;m<48;m++)
       {
	switch(tolower(inputline[n][m]))
	{
		case 'z': color = BLACK;	break;
		case 'b': color = BLUE;		break;
		case 'g': color = GREEN;	break;
		case 'o': color = CYAN;		break;
		case 'r': color = GREEN+i;	break;
		case 'p': color = MAGENTA;	break;
		case 'u': color = BROWN;	break;
		case 'a': color = LIGHTGRAY;	break;
		case 'y': color = DARKGRAY;	break;
		case 'c': color = LIGHTBLUE;	break;
		case 'i': color = LIGHTGREEN;	break;
		case 't': color = LIGHTCYAN;	break;
		case 'j': color = LIGHTRED;	break;
		case 'x': color = LIGHTMAGENTA;	break;
		case 'e': color = YELLOW;	break;
		case 'w': color = WHITE;	
	}
	putpixel(x+m+2,y+n+17,color);
       }
    }
    setcolor(BLACK);
    settextjustify(CENTER_TEXT,CENTER_TEXT);
    settextstyle(DEFAULT_FONT,HORIZ_DIR,2);
    setusercharsize(3,2,1,1);
    outtextxy(x+19,y+2,"H");
    outtextxy(x+19,y+67,"H");

 
  switch(i) {
   case 0: Klaver(x+2,y+2);
	   Klaver(x+37,y+2);
	   Klaver(x+37,y+67);
	   Klaver(x+2,y+67);
	   break;
   case 1: Schoppen(x+2,y+2);
	   Schoppen(x+37,y+2);
	   Schoppen(x+37,y+67);
	   Schoppen(x+2,y+67);
	   break;
   case 2: Ruiten(x+2,y+2);
	   Ruiten(x+37,y+2);
	   Ruiten(x+37,y+67);
	   Ruiten(x+2,y+67);
	   break;
   case 3: Harten(x+2,y+2);
	   Harten(x+37,y+2);
	   Harten(x+37,y+67);
	   Harten(x+2,y+67);
	   break;
	   }
  }

}

void vrouw()
{
 int m,n,i,j,x,y,color;
 x=150;

/*vrouw*/

strcpy(inputline[0],"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[1],"aaaaaaaaaaaaaaaaaaiijjiijjiijaaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[2],"aaaaaaaaaaaaaaaaaaiijjiijjiijaaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[3],"aaaaaaaaaaaaaaaaaaEEEEEEEEEEEaaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[4],"aaaaaaaaaaaaaaaaaaEeeettteeeEaaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[5],"aaaaaaaaaaaaaaaaaaEeettttteeEaaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[6],"aaaaaaaaaaaaaaaaaazzzzzzzzzzzaaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[7],"aaaaaaaaaaaaaaaaRrrrrrrrrrrrRaaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[8],"aaaaaaaaaaaaaaaRrrzrrrrrrrrrrRaaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[9],"aaaaaaaaaaaaaaaRrrzrrrrrrrrrrrRaaaaaaaaaaaaaaaaaaa");
strcpy(inputline[10],"aaaaaaaaaaaaaaaRrrzwwwwwwwwrrrPPPaaaaaaaaaaaaaaaaa");
strcpy(inputline[11],"aaaaaaaaaaaaaaaRrrwwwwwwwwwrrrPppPaaaaaaaaaaaaaaaa");
strcpy(inputline[12],"aaaaaaaaaaaaaaaaRrwwwwwzzwwwrPppppPaaaaaaaaaaaaaaa");
strcpy(inputline[13],"aaaaaaaaaaaaaaaaaWwzzwwzzwwwrrPppPcaaaaaaaaaaaaaaa");
strcpy(inputline[14],"aaaaaaaaaaaaaaaaaWwzzwzwwwwwwrPPPccaaaaaaaaaaaaaaa");
strcpy(inputline[15],"aaaaaaaaaaaaaaaaaaWwwwzwwwwwwwWcccccaaaaaaaaaaaaaa");
strcpy(inputline[16],"aaaaaaaaaaaaaaaaaaWwwwzzwwwwwwWcccccaaaaaaaaaaaaaa");
strcpy(inputline[17],"aaaaaaaaaaaaaaaaaaaWwwwwwzwwwzccccccaaaaaaaaaaaaaa");
strcpy(inputline[18],"aaaaaaaaaaaaaaaaaaaaWwzzzwwwzWcccccccaaaaaaaaaaaaa");
strcpy(inputline[19],"aaaaaaaaaaaaaaaaaaaaaWwwwwwzwWcccccccaaaaaaaaaaaaa");
strcpy(inputline[20],"aaaaaaaaaaaaaaaaaaaaaWzzzzwwwwWcccccccaaaaaaaaaaaa");
strcpy(inputline[21],"aaaaaaaaaaaaaaaaaaaaaWwwwwwwwwWcccccccaaaaaaaaaaaa");
strcpy(inputline[22],"aaaaaaaaaaaaaaaaaaaaaWwwwwwwwwwWccccccaaaaaaaaaaaa");
strcpy(inputline[23],"aaaaaaaaaaaaaaaaaaaaaWwwwwwwwwwWcccccccaaaaaaaaaaa");
strcpy(inputline[24],"aaaaaaaaaaaaaaaaaaBWWWwwwwwwwwwWWccccccaaaaaaaaaaa");
strcpy(inputline[25],"aaaaaaaaaaaaaaaaaBbBwwwwwwwwwwwBbBccccccaaaaaaaaaa");
strcpy(inputline[26],"aaaaaaaaaaaIWwwwwwBbbbBwwwwwwBbbbbEEccccaaaaaaaaaa");
strcpy(inputline[27],"aaaaaaaaaIiiiIaWWWwwBbbBBBBBBbbbbEeeeEccaaaaaaaaaa");
strcpy(inputline[28],"aaaaaaaaIIiiIwwwwwwwBbbbbbbbbbbbEeeeeeEcaaaaaaaaaa");
strcpy(inputline[29],"aaaaaaaaIiiiiIwwwwwwwwwBBBBBwwwEeeeeeeEaaaaaaaaaaa");
strcpy(inputline[30],"aaaaaaaaIiiiiiIwwwwwwwwwwwwwwwEEeeeeeeeEaaaaaaaaaa");
strcpy(inputline[31],"aaaaaaaIiiiiiiIwwwwwwzwwwwwwwwEeeeeeeeeEEaaaaaaaaa");
strcpy(inputline[32],"aaaaaaaIiiiiiiiIwwwwzwwwwwwwIEeeeeeeeeeeEaaaaaaaaa");
strcpy(inputline[33],"aaaaaaIiiiiiiiiIwwwzwwwwwwIiEeeeeeeeeeeeIaaaaaaaaa");
strcpy(inputline[34],"aaaaaaIiiiiiiiiiIwwzwwwwIiiEeeeeeeeeeeIiIaaaaaaaaa");
strcpy(inputline[35],"aaaaaaIiiiiiiiiiIwzwwwIiiiiEeeeeeeeeIiiiIaaaaaaaaa");
strcpy(inputline[36],"aaaaaIiiiiiiiiiiiIzwIiiiiiiEeeeeeeeIiiiiIaaaaaaaaa");
strcpy(inputline[37],"aaaaaIiiiiiiiiiiiiIIiiiiiiEeeeeeeeIiiiiiIaaaaaaaaa");
strcpy(inputline[38],"aaaaaIiiiiiiiiiiiiiiiiiiiieeeeeeeeIiiiiiIaaaaaaaaa");
strcpy(inputline[39],"aaaaaIiiiiiiiiiiiiiiiiiiiEeeeeeeeeIiiiiiIaaaaaaaaa");
strcpy(inputline[40],"aaaaaIiiiiiiiiiiiiiiiiiiEeeeeeeeEiiiiiiiIaaaaaaaaa");
strcpy(inputline[41],"aaaaaIiiiiiiiiiiiiiiiiiiEeeeeeeeEiiiiiiiIaaaaaaaaa");
strcpy(inputline[42],"aaaaUuiiiiiiiiiiiiiiiiiEeeeeeeeEiiiiiiiiUaaaaaaaaa");
strcpy(inputline[43],"aaaaUuuiiiiiiiiiiiiiiiEeeeeeeeEiiiiiiiUuUaaaaaaaaa");
strcpy(inputline[44],"aaaaUuuuiiiiiiiiiiiiiEeeeeeeeEiiiijjjUuuUaaaaaaaaa");
strcpy(inputline[45],"aaaaUuuujjjjjjjiiiiiiEeeeeeeeEjjjjjjjUuuUaaaaaaaaa");
strcpy(inputline[46],"aaaaUuuujjjjjjjjjjjjEeeeeeeeEjjjjjjjUuuuUaaaaaaaaa");
strcpy(inputline[47],"aaaaUuuujjjjjjjjjjjjEeeeeeeeEjjjjjiUuuuuUaaaaaaaaa");
strcpy(inputline[48],"aaaUuuuuiiiiijjjjjjEeeeeeeeEiiiiiiUuuuuuUaaaaaaaaa");

for(i=0;i<4;i++)
 {
  y=i*85+10;

    kaartvorm(x,y);


 for(n=0;n<50;n++)
    {
     for(m=0;m<48;m++)
       {
	switch(tolower(inputline[n][m]))
	{
		case 'z': color = BLACK;	break;
		case 'b': color = BLUE;		break;
		case 'g': color = GREEN;	break;
		case 'o': color = CYAN;		break;
		case 'r': color = GREEN+i;	break;
		case 'p': color = MAGENTA;	break;
		case 'u': color = BROWN;	break;
		case 'a': color = LIGHTGRAY;	break;
		case 'y': color = DARKGRAY;	break;
		case 'c': color = LIGHTBLUE;	break;
		case 'i': color = LIGHTGREEN;	break;
		case 't': color = LIGHTCYAN;	break;
		case 'j': color = LIGHTRED;	break;
		case 'x': color = LIGHTMAGENTA;	break;
		case 'e': color = YELLOW;	break;
		case 'w': color = WHITE;	
	}
	putpixel(x+m+2,y+n+17,color);
       }
    }
    setcolor(BLACK);
    settextjustify(CENTER_TEXT,CENTER_TEXT);
    settextstyle(DEFAULT_FONT,HORIZ_DIR,2);
    setusercharsize(3,2,1,1);
    outtextxy(x+19,y+2,"V");
    outtextxy(x+19,y+67,"V");

 
  switch(i) {
   case 0: Klaver(x+2,y+2);
	   Klaver(x+37,y+2);
	   Klaver(x+37,y+67);
	   Klaver(x+2,y+67);
	   break;
   case 1: Schoppen(x+2,y+2);
	   Schoppen(x+37,y+2);
	   Schoppen(x+37,y+67);
	   Schoppen(x+2,y+67);
	   break;
   case 2: Ruiten(x+2,y+2);
	   Ruiten(x+37,y+2);
	   Ruiten(x+37,y+67);
	   Ruiten(x+2,y+67);
	   break;
   case 3: Harten(x+2,y+2);
	   Harten(x+37,y+2);
	   Harten(x+37,y+67);
	   Harten(x+2,y+67);
	   break;
	   }
  }

}

void boer()
{
 int m,n,i,j,x,y,color;
 x=220;

/*boer */
strcpy(inputline[0],"ccccccccccccccccccccccccccccjjjjjccccccccccccccccc");
strcpy(inputline[1],"ccccccccccccccccccccccccccjjjjjjjccccccccccccccccc");
strcpy(inputline[2],"cccccccccccccccccccccccccjjjjjjjcccccccccccccccccc");
strcpy(inputline[3],"ccccccccccccccccccccccccjjjjjjjccccccccccccccccccc");
strcpy(inputline[4],"cccccccccccccccccccccccjjjjjjjcccccccccccccccccccc");
strcpy(inputline[5],"cccccwwwwwwwwwwwwwccccjjjjjjjccccccccccccccccccccc");
strcpy(inputline[6],"ccccwwwwwwwwwwwwwwwwpjjjjjjcccccccccwwwwwccccccccc");
strcpy(inputline[7],"ccccccwwwwwwwwwwwwppjjjjjppccccccccwwwwwwwcccccccc");
strcpy(inputline[8],"ccccwwwwwwwwwwwwwwwpjjjppppppccccccccccccccccccccc");
strcpy(inputline[9],"ccwwwwwwwwwwwwwwcccpjjppppppppppcccccccccccccccccc");
strcpy(inputline[10],"cwwwwwwwwwwwwwcccppppppppppppppppppcccccgggggggccc");
strcpy(inputline[11],"cwwwwwwwwwwwwwcccppppppppppppppppppccgggggggjjgggc");
strcpy(inputline[12],"cyyyyyyyyyyyyyccccpppppppppppppppppccgggjjggjjggjj");
strcpy(inputline[13],"cyyyyyyyyyyyyycccccrrrrwwwwppppppcccggggjjggggggjj");
strcpy(inputline[14],"cccccccycccccccccccrrrwwwwwwwwrrrcccggggggjjggjjgg");
strcpy(inputline[15],"cccccccyycccccccccrrrwwzzwwzzwwrrccggjjgggjjggjjgg");
strcpy(inputline[16],"cccccccyyyccccccccrrwwwwwzwwwwwrrcccgjjggjjggggggg");
strcpy(inputline[17],"cccccccyyyyyccccccrrwwwwwzwwwwwrrcccgggggjjggggjjg");
strcpy(inputline[18],"cccccccyyyyyycccccrrwwwwwzwwwwwrrcccccgggggjjggjjg");
strcpy(inputline[19],"ccccccccyyyyyyccccrrrwwwrrrrwwwrrcccccccgggjjggggg");
strcpy(inputline[20],"ccccccccyyyuyyycccrrrrwwrrrrwwwrrccccccccccuuuuccc");
strcpy(inputline[21],"ccccccccyyyuuyyyccrrrrwwzzzzwwrrrccccccccccuuuuccc");
strcpy(inputline[22],"ccccccccyyyuuuyyycccccczrrrrwzwrcccccccccccuuuuccc");
strcpy(inputline[23],"ccccccccyyycuuuyyyccccwwrrrrzwwwcccccccccccuuuuccc");
strcpy(inputline[24],"cccccccccyycuuuccyycccwwrrrrwwwwwccccccccccuuuuccc");
strcpy(inputline[25],"cccccccccycccuuucccycwwwwwwwwwwwwccccccccccuuuuccc");
strcpy(inputline[26],"cccccccccycccuuucccccwwwwwwwwwwwwwEEEccccccuuuuccc");
strcpy(inputline[27],"ccccccccccccccuuuccjjjjwwwjeeeeeeeeeeEcccccuuuuccc");
strcpy(inputline[28],"cccccccccccccccuuujjjjjjjjEeeeeeeeeeeeEccccuuuuccc");
strcpy(inputline[29],"ccccccccccGgggguuubbbjjjjEeeeeeeeeeeeeeEcccuuuuccc");
strcpy(inputline[30],"ccccccccGggggggguuubbbbbbEeeeeeeeeeeeeeEcccuuuuccc");
strcpy(inputline[31],"cccccccGggggggguguuubbbbEeeeeeeeeeeeeeeeEccuuuuccc");
strcpy(inputline[32],"cccccccGggggggggguuubbbEeeeeeeeeeeeeeeEggGcuuuuccc");
strcpy(inputline[33],"ccccccGggggggggBbBuuubEeeeeeeeeeeeeEgggggGcuuuuccc");
strcpy(inputline[34],"ccccccGgggggggBbbbuuueEeeeeeeeeeeEgggggggGcuuuuccc");
strcpy(inputline[35],"cccccGgggggggBbbbbbuuueeeeeeeeeeEgggggggggGuuuuccc");
strcpy(inputline[36],"cccccGgggggggBbbbbguuueeeeeeeeeEggggggggggGuuuuccc");
strcpy(inputline[37],"cccccGgggggggBbbbbbbuuueeeeeeeeEgggggggggggGuuuccc");
strcpy(inputline[38],"cccccGgggggggBbbbbbbuuueeeeeeeEbbbGgggggggggGuuccc");
strcpy(inputline[39],"iiiiiGgggggggBbbbbbEeuuueeeeeEbbbbBGgggggggggGuiii");
strcpy(inputline[40],"iiiiiGgggggggBbbbbEeeeuuueeeeEbbbbBGggggggggggGiii");
strcpy(inputline[41],"iiiiiGgggggggBbbbEeeeeeuuueeeEbbbbBiGgggggggggGiii");
strcpy(inputline[42],"iiiiGgggggggBbbbbEeeeeeuuueeEbbbbbBiiGggggggggGiii");
strcpy(inputline[43],"iiiiGgggggggBbbbEeeeeeeeuuueEbbbbBiiiGgggggggGiiii");
strcpy(inputline[44],"iiiiGgggggggBbbbEeeeeeeeeuuubbbbbBiiGggggggggGiiii");
strcpy(inputline[45],"iiiiGgggggggBbbEeeeeeeeeeeuuubbbbBiiGgggggggGiiiii");
strcpy(inputline[46],"iiiiGgggggggBbbEeeeeeeeeeEbuuubbbBiiGggggggGiiiiii");
strcpy(inputline[47],"iiiiGgggggggBbbEeeeeeeeeEbbbuuubbBiGggggggGiiiiiii");
strcpy(inputline[48],"iiiiGgggggggBBeeeeeeeeeeEbbbuuubbBGgggggggGiiiiiii");

for(i=0;i<4;i++)
 {
  y=i*85+10;

    kaartvorm(x,y);

 for(n=0;n<50;n++)
    {
     for(m=0;m<48;m++)
       {
	switch(tolower(inputline[n][m]))
	{
		case 'z': color = BLACK;	break;
		case 'b': color = BLUE;		break;
		case 'g': color = GREEN;	break;
		case 'o': color = CYAN;		break;
		case 'r': color = GREEN+i;	break;
		case 'p': color = MAGENTA;	break;
		case 'u': color = BROWN;	break;
		case 'a': color = LIGHTGRAY;	break;
		case 'y': color = DARKGRAY;	break;
		case 'c': color = LIGHTBLUE;	break;
		case 'i': color = LIGHTGREEN;	break;
		case 't': color = LIGHTCYAN;	break;
		case 'j': color = LIGHTRED;	break;
		case 'x': color = LIGHTMAGENTA;	break;
		case 'e': color = YELLOW;	break;
		case 'w': color = WHITE;	
	}
	putpixel(x+m+2,y+n+17,color);
       }
    }
    setcolor(BLACK);
    settextjustify(CENTER_TEXT,CENTER_TEXT);
    settextstyle(DEFAULT_FONT,HORIZ_DIR,2);
    setusercharsize(3,2,1,1);
    outtextxy(x+19,y+2,"B");
    outtextxy(x+19,y+67,"B");

 
  switch(i) {
   case 0: Klaver(x+2,y+2);
	   Klaver(x+37,y+2);
	   Klaver(x+37,y+67);
	   Klaver(x+2,y+67);
	   break;
   case 1: Schoppen(x+2,y+2);
	   Schoppen(x+37,y+2);
	   Schoppen(x+37,y+67);
	   Schoppen(x+2,y+67);
	   break;
   case 2: Ruiten(x+2,y+2);
	   Ruiten(x+37,y+2);
	   Ruiten(x+37,y+67);
	   Ruiten(x+2,y+67);
	   break;
   case 3: Harten(x+2,y+2);
	   Harten(x+37,y+2);
	   Harten(x+37,y+67);
	   Harten(x+2,y+67);
	   break;
	   }
  }

}



void Zeven(void)
{
int x,y,i,j;

int posx[7] = {18,11,26,11,26,11,26};
int posy[7] = {24,9,9,38,38,52,52};

 x=500;

for(i=0;i<4;i++)
 {
  y=i*85+10;

  kaartvorm(x,y);
 
  switch(i) {
   case 0:
	 for (j=0;j<7;j++)     Klaver(x+posx[j]+1,y+posy[j]+2);

	   break;
   case 1:
	 for (j=0;j<7;j++)     Schoppen(x+posx[j]+1,y+posy[j]+2);
	   break;
   case 2:
	 for (j=0;j<7;j++)     Ruiten(x+posx[j]+1,y+posy[j]+2);
	   break;
   case 3:
	 for (j=0;j<7;j++)     Harten(x+posx[j]+1,y+posy[j]+2);
	   break;
	   }
    settextjustify(CENTER_TEXT,CENTER_TEXT);
    settextstyle(DEFAULT_FONT,HORIZ_DIR,1);
    setusercharsize(3,2,1,1);
    outtextxy(x+4,y+4,"7");
    outtextxy(x+4,y+72,"7");
    outtextxy(x+40,y+4,"7");
    outtextxy(x+40,y+72,"7");
  }

}

void Acht(void)
{
int x,y,i,j;
int posx[10]= {11,26,11,26,11,26,11,26};
int posy[10]= {10,10,24,24,38,38,52,52};


 x=430;

for(i=0;i<4;i++)
 {
  y=i*85+10;

  kaartvorm(x,y);
 
  switch(i) {
   case 0:
	 for (j=0;j<8;j++)     Klaver(x+posx[j]+1,y+posy[j]+2);

	   break;
   case 1:
	 for (j=0;j<8;j++)     Schoppen(x+posx[j]+1,y+posy[j]+2);
	   break;
   case 2:
	 for (j=0;j<8;j++)     Ruiten(x+posx[j]+1,y+posy[j]+2);
	   break;
   case 3:
	 for (j=0;j<8;j++)     Harten(x+posx[j]+1,y+posy[j]+2);
	   break;
	   }
    settextjustify(CENTER_TEXT,CENTER_TEXT);
    settextstyle(DEFAULT_FONT,HORIZ_DIR,1);
    setusercharsize(3,2,1,1);
    outtextxy(x+4,y+4,"8");
    outtextxy(x+4,y+72,"8");
    outtextxy(x+40,y+4,"8");
    outtextxy(x+40,y+72,"8");
  }
}

void Negen(void)
{
int x,y,i,j;

int posx[10]= {11,26,3,18,34,11,26,3,34};
int posy[10]= {10,10,24,24,24,38,38,52,52};

 x=360;

for(i=0;i<4;i++)
 {
  y=i*85+10;

  kaartvorm(x,y);
 
  switch(i) {
   case 0:
	 for (j=0;j<9;j++)     Klaver(x+posx[j]+1,y+posy[j]+2);

	   break;
   case 1:
	 for (j=0;j<9;j++)     Schoppen(x+posx[j]+1,y+posy[j]+2);
	   break;
   case 2:
	 for (j=0;j<9;j++)     Ruiten(x+posx[j]+1,y+posy[j]+2);
	   break;
   case 3:
	 for (j=0;j<9;j++)     Harten(x+posx[j]+1,y+posy[j]+2);
	   break;
	   }
    settextjustify(CENTER_TEXT,CENTER_TEXT);
    settextstyle(DEFAULT_FONT,HORIZ_DIR,1);
    setusercharsize(3,2,1,1);
    outtextxy(x+4,y+4,"9");
    outtextxy(x+4,y+72,"9");
    outtextxy(x+40,y+4,"9");
    outtextxy(x+40,y+72,"9");
  }
}


void Tien(void)
{
int x,y,i,j;

int posx[10]= {11,26,3,18,34,11,26,3,18,34};
int posy[10]= {10,10,24,24,24,38,38,52,52,52};

 x=290;

for(i=0;i<4;i++)
 {
  y=i*85+10;

  kaartvorm(x,y);
 
  switch(i) {
   case 0:
	 for (j=0;j<10;j++)     Klaver(x+posx[j]+1,y+posy[j]+2);

	   break;
   case 1:
	 for (j=0;j<10;j++)     Schoppen(x+posx[j]+1,y+posy[j]+2);
	   break;
   case 2:
	 for (j=0;j<10;j++)     Ruiten(x+posx[j]+1,y+posy[j]+2);
	   break;
   case 3:
	 for (j=0;j<10;j++)     Harten(x+posx[j]+1,y+posy[j]+2);
	   break;
	   }
    settextjustify(CENTER_TEXT,CENTER_TEXT);
    settextstyle(DEFAULT_FONT,HORIZ_DIR,1);
    setusercharsize(3,2,1,1);
    outtextxy(x+1,y+4,"1");
    outtextxy(x+1,y+72,"1");
    outtextxy(x+37,y+4,"1");
    outtextxy(x+37,y+72,"1");
    outtextxy(x+7,y+4,"0");
    outtextxy(x+7,y+72,"0");
    outtextxy(x+43,y+4,"0");
    outtextxy(x+43,y+72,"0");
  }
}
void achterkant(void)
{
 int x,y;

 x=10+8*70;
 y=10;

 kaartvorm(x,y);
 setcolor(BROWN);
 setfillstyle(SOLID_FILL,BROWN);
 floodfill(x+10,y+10,BLACK);
 setcolor(YELLOW);
 setfillstyle(INTERLEAVE_FILL,GREEN);
 floodfill(x+10,y+10,BLACK);

}

void Klaver(int x,int y)
{
int i,j,color;

 for(j=0;j<14;j++)
  {
  for(i=0;i<14;i++)
    {
     if(klaver[i][j]=='w')   color=WHITE; else color=BLACK;
     if(color!=WHITE) putpixel(x+j,y+i,color);
    }
  }
     setcolor(BLACK);
}

void Schoppen(int x,int y)
{
int i,j,color;

 for(j=0;j<14;j++)
  {
  for(i=0;i<14;i++)
    {
     if(schoppen[i][j]=='w')   color=WHITE; else color=DARKGRAY;
     if(color!=WHITE) putpixel(x+j,y+i,color);
    }
  }
     setcolor(DARKGRAY);
}

void Ruiten(int x,int y)
{
int i,j,color;

 for(j=0;j<14;j++)
  {
  for(i=0;i<14;i++)
    {
     if(ruiten[i][j]=='w')   color=WHITE; else color=RED;
     if(color!=WHITE) putpixel(x+j,y+i,color);
    }
  }
     setcolor(RED);
}

void Harten(int x,int y)
{
int i,j,color;

 for(j=0;j<14;j++)
  {
  for(i=0;i<14;i++)
    {
     if(harten[i][j]=='w')   color=WHITE; else color=LIGHTRED;
     if(color!=WHITE) putpixel(x+j,y+i,color);
    }
  }

     setcolor(LIGHTRED);
}


void kleuren(void)
{
 int i,j,color;
 strcpy(klaver[0] ,"wwwwwzzzwwwwww");
 strcpy(klaver[1] ,"wwwwzzzzzwwwww");
 strcpy(klaver[2] ,"wwwwzzzzzwwwww");
 strcpy(klaver[3] ,"wwwwwzzzwwwwww");
 strcpy(klaver[4] ,"wzzwwwzwwwzzww");
 strcpy(klaver[5] ,"zzzzzwzwzzzzzw");
 strcpy(klaver[6] ,"zzzzzzzzzzzzzw");
 strcpy(klaver[7] ,"zzzzzwzwzzzzzw");
 strcpy(klaver[8] ,"wzzwwwzwwwzzww");
 strcpy(klaver[9] ,"wwwwwwzwwwwwww");
 strcpy(klaver[10],"wwwwwzzzwwwwww");
 strcpy(klaver[11],"wwwwwzzzwwwwww");
 strcpy(klaver[12],"wwwwzzzzzwwwww");
 strcpy(klaver[13],"wwwwwwwwwwwwww");


 strcpy(schoppen[0] ,"wwwwwwZwwwwwww");
 strcpy(schoppen[1] ,"wwwwwZZZwwwwww");
 strcpy(schoppen[2] ,"wwwwZZZZZwwwww");
 strcpy(schoppen[3] ,"wwZZZZZZZZZwww");
 strcpy(schoppen[4] ,"wZZZZZZZZZZZww");
 strcpy(schoppen[5] ,"ZZZZZZZZZZZZZw");
 strcpy(schoppen[6] ,"ZZZZZZZZZZZZZw");
 strcpy(schoppen[7] ,"ZZZZZZZZZZZZZw");
 strcpy(schoppen[8] ,"wZZZZwZwZZZZww");
 strcpy(schoppen[9] ,"wwZZwZZZwZZwww");
 strcpy(schoppen[10],"wwwwwwZwwwwwww");
 strcpy(schoppen[11],"wwwwwZZZwwwwww");
 strcpy(schoppen[12],"wwwwZZZZZwwwww");
 strcpy(schoppen[13],"wwwZZZZZZZwwww");


 strcpy(ruiten[0], "wwwwwwrwwwwwww");
 strcpy(ruiten[1], "wwwwwrrrwwwwww");
 strcpy(ruiten[2], "wwwwwrrrwwwwww");
 strcpy(ruiten[3], "wwwwrrrrrwwwww");
 strcpy(ruiten[4], "wwwrrrrrrrwwww");
 strcpy(ruiten[5], "wrrrrrrrrrrrww");
 strcpy(ruiten[6], "rrrrrrrrrrrrrw");
 strcpy(ruiten[7], "wrrrrrrrrrrrww");
 strcpy(ruiten[8], "wwwrrrrrrrwwww");
 strcpy(ruiten[9], "wwwwrrrrrwwwww");
 strcpy(ruiten[10],"wwwwwrrrwwwwww");
 strcpy(ruiten[11],"wwwwwrrrwwwwww");
 strcpy(ruiten[12],"wwwwwwrwwwwwww");
 strcpy(ruiten[13],"wwwwwwwwwwwwww");
 

 strcpy(harten[0] ,"wwRRRwwwRRRwww");
 strcpy(harten[1] ,"wRRRRRwRRRRRww");
 strcpy(harten[2] ,"wRRRRRwRRRRRww");
 strcpy(harten[3] ,"RRRRRRRRRRRRRw");
 strcpy(harten[4] ,"wRRRRRRRRRRRww");
 strcpy(harten[5] ,"wRRRRRRRRRRRww");
 strcpy(harten[6] ,"wwRRRRRRRRRwww");
 strcpy(harten[7] ,"wwwRRRRRRRwwww");
 strcpy(harten[8] ,"wwwwRRRRRwwwww");
 strcpy(harten[9] ,"wwwwRRRRRwwwww");
 strcpy(harten[10],"wwwwwRRRwwwwww");
 strcpy(harten[11],"wwwwwRRRwwwwww");
 strcpy(harten[12],"wwwwwwRwwwwwww");
 strcpy(harten[13],"wwwwwwwwwwwwww");
}
