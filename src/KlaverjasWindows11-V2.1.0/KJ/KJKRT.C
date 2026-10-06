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
#include "keyboard.h"

#define TRUE	1			/* Define some handy constants	*/
#define FALSE	0			/* Define some handy constants	*/
#define ON	1			/* Define some handy constants	*/
#define OFF	0			/* Define some handy constants	*/

#define L32 for(n=0;n<32;n++) 
#define L16 for(n=0;n<16;n++) 
#define L8  for(n=0;n<8 ;n++) 
#define L4  for(n=0;n<4 ;n++) 

void  Sputimage(int,int,void far *,int);
void  main(int argc);
void  einde(void);
void  Initialize(void);
void  Delen(void);
void  Vulhanden(void);
int   bepaal_slagkans(char karte, int kleur);
float guillermie(int a,int h,int z,int x,int s);
float kans_hoger(int kaartenhoger,int kleur,int specifiek,int vrager);
float kans_kaart(int kleur,int specifiek,int vrager);
void  kaarten_vrij(void);
int   strpos(const char *s, char x);
int   wie_vrager(char karte,int kleur);
void  leg_tafel(void);
void  troef_bepalen(void);
int   legkaart(char Skaart,int Skleur,int vragert);
void  updatetafelkaarten(void);
void  eindspel(void);
void  speler1(void);
void  tegenspeler1(void);
void  tegenspeler2(void);
void  speler2(void);
void  updatetafel(void);
void  bekijk_beste_slag(int Skleur);
void  evalueer(void);
int   hogere(char kv,char *ks,char *volgorde);
void  evalueerspel(void);
int   wie_slag(void);
char  hoogsteroem(int);
char  laagsteroem(int);
int   bepaal_hoogsteroem(int Kkleur,char Skaart);
int   bepaal_laagsteroem(int Kkleur,char Skaart);
void  vraagkaart(void);
void  humaan(void);
void  troef_vragen(void);
int   bepaalroempunten(char *s,int kolor);
void  punten(void);
void  print_laatsteslag(void);
void  init_mouse(void);
void  error_legkaart(void);

void  intro_text(void);
void kaarten(void);
void kaartvorm(int x,int y);
void aas(void);
void heer(void);
void vrouw(void);
void boer(void);
void Klaver(int x,int y);
void Schoppen(int x,int y);
void Ruiten(int x,int y);
void Harten(int x,int y);
void Tien(void);
void Negen(void);
void Acht(void);
void Zeven(void);
void achterkant(void);
void kleuren(void);

extern int    GraphDriver;		/* The Graphics device driver		*/
extern int    GraphMode;		/* The Graphics mode value		*/
extern int    MaxX, MaxY;		/* The maximum resolution of the screen */
extern int    MaxColors;		/* The maximum # of colors available	*/
extern int    ErrorCode;		/* Reports any graphics errors		*/
extern struct palettetype palette;     /* for palette info			*/

extern struct krts { 
	      char naam;
	      int puntwaarde;    /* Dicht    = 0  */
	      int troefwaarde;   /* Ik       = 1  */
	      int actwaarde;     /* Hij      = 2  */
	      int DichtIkHy;     /* Iktafel  = 3   Dicht = 33 */
	      int troef;         /* hijtafel = 4   Dicht = 44 */
	      int kleur;         /* gespeeld = 5  */
	      int posx;
	      int posy;          /*positie kaart op scherm */
	      int postafel;
	    } kaart[32];

extern struct deck {
	      int slagkans;
	      int slagkans0;
	      char naam;
	      int kleur;         /* 1=K 2=S 3=R 4=H */
	      int waarde;  
	      int troef;
	      int gegarandeerd;  /* 0=ja 1=nee */
	    } hand[2][8];

extern struct deck tafel[2][8];

extern struct slach { int kleur;
	       char naam;
	       int troef;  /* 0 = geen troef */
	       int speler;
	       int kans;
	       int waarde;
	       int tactiek;
	    } slag[9][4];

extern int deeltabel[32];
extern int verzaakt[2][4];
extern int tnoord[4];
extern int tzuid[4];
#define NKRT 35
extern void *krt[NKRT];
extern void *veld;

extern char rangtroef[9];
extern char rangnorm[9];
extern char rangroem[9];
extern int roem[2];
extern char KLEUR[5][9];
extern char kaartdicht[17];
extern int  iKrt_gespeeld,iKrt[4][2],iKrt_tafel[4][2];
extern char Krt_weg[4][9],Krt_vrij[4][9],Krt_dicht[4][9];
extern char Krt_totweg[36],Krt_totvrij[36],Krt_totdicht[36];
extern int  VRAGER,VRAGERHAND,startvrager;
extern int  TROEF,SPELER,Speler;
extern char khand[2][4][9],ktafel[2][4][9];
extern int  DICHT,COMP,DEMO;
extern int  SLAG,SLAGKRTNO;
extern unsigned int puntenspel[2];
extern unsigned long puntentotaalspel[2]; /* Nul = Zuid, een = Noord */
extern int gewonnen[2];
extern char Lkaart,LKAART3;
extern int  Lkleur,LKLEUR3;
extern char key;
extern int HOOGSTE;
extern int ZW;
extern float fact[19];
extern int TACTIEK,TACTIEK41,TACTIEKLAAG;


extern char text[80];
extern char klaver[15][15];
extern char schoppen[15][15];
extern char ruiten[15][15];
extern char harten[15][15];
extern char inputline[50][55];
/*extern unsigned int tac[76];*/

extern unsigned short Mpresent;
extern long Kaartpnt[2];
extern long Troefpnt[2];
extern long Gewonnen[2];
extern long Roempnt[2];
extern long Troefkrt[2];
extern long Pit[2];
extern long Tpit[2];
extern long  Nat[2];

extern int SDEMO;

/****************** void  intro_text(void); ********************/
void  intro_text(void)
{
 int t;

/* size=imagesize(0,0,52,82);*/
 cleardevice();
 kaarten();
 closegraph();
 textcolor(LIGHTRED);
 cputs("Klaverjassen door Ed Nieuwenhuys,Jan van Gentstraat7,1171Gh Badhoevedorp\r\n");
 textcolor(YELLOW);
 cputs("Dit programma mag vrijelijk gecopieerd en gedistribueerd worden.\r\n");
 textcolor(WHITE);
 cputs("De spelregels zijn als volgt.\r\n");
 cputs("Kleur bekennen en overtroeven indien mogelijk.\r\n");
 cputs("De eerste kaart mag uit de hand of van tafel gespeeld worden.\r\n");
 cputs("De laatste kaart is altijd uit de hand van de tegenspeler.\r\n");
 cputs("Alle slagen behaalt levert 100 punten extra op. Als de tegenstander\r\n");
 cputs("die vraagt geen slag haalt 200 punten extra.\r\n");
 cputs("Een driekaart levert 20 punten roem op, een vierkaart 50,\r\n");
 cputs("vier dezelfde kaarten 100 en stuk (vrouw + heer van troef) 20 punten.\r\n");
 cputs("De laatste slag levert 10 punten op.\r\n");
 cputs("Je moet verplicht troef maken.\r\n");
 cputs("Bij gebruik van een muis op de betreffende kaart klikken, ook bij troef\r\n");
 cputs("kiezen op een willekeurige kaart van die kleur klikken.\r\n");
 cputs("Als er geen muis aanwezig is type dan de kleur en de naam van de kaart\r\n");
 cputs("Bijv. Ruiten Tien = RT, Schoppen 8 = S8 enz.(ODCXde)\n\r\n");

       cputs("         Demo ? (yj/n) \r\n");
 t=getch();
 if(t>96) t-=32;
 if(t==27) einde();
 DEMO=FALSE;         /* ALS DEMO=TRUE dan wordt slagkans geprint */
 COMP=FALSE;         /* Als COMP=TRUE dan geen humane interferentie */
 DICHT=1;            /* Als DICHT=1 dan wordt slagkans + alle kaarten etc geprint */
 key=' ';            /* als key=c dan vraag tekst Klik muis of druk toets KJ.c regel 286 */

 if(t=='Y')      {COMP=TRUE; DICHT=0; key='c'; }              /*Demo mode langzaam     */
 if(t=='J')      {COMP=TRUE; DICHT=0; key='c'; }              /*Demo mode langzaam     */
 if(t=='O') 	  {COMP=TRUE; DICHT=0; key=' '; DEMO=TRUE; }   /*Demo mode+stat langzaam*/
 if(t=='D') 	  {COMP=FALSE;DICHT=0; key=' '; DEMO=TRUE; }   /*Spelen met statistiek */
 if(t=='C') 	  {COMP=TRUE; DICHT=0; key='c'; SDEMO=TRUE; }  /*Zeer snelle demo zonder kaarten SDEMO=TRUE   */
 if(t=='X') 	  {COMP=TRUE; DICHT=0; key='c'; SDEMO=FALSE; DEMO=TRUE; }   /* Snelle demo alle kaarten+stat */

 Mpresent=FALSE;
 if(COMP) Mpresent=FALSE;          /* als demo-mode dan geen muis aanwezig */
 else if(mouse_present()){
       mouse_cursor_off();
       puts("Muis aanwezig ? (yj/n) \r\n");
       t=getch();
       if(t>96) t-=32;
       if(t=='Y' ||t=='J') Mpresent=TRUE; else Mpresent=FALSE; 
      }
 Initialize();
}       


void kaarten()
{
 int m,n,x,y,i,posx,posy;
 setfillstyle(SOLID_FILL,GREEN);
 floodfill(0,0,WHITE);

 achterkant();
 getimage(10+8*70,10,10+52+8*70,10+82,krt[32]);
 getimage(0,0,125,230,veld);
 kleuren();
 Zeven();
 Acht();
 Negen();
 Tien();
 boer();
 vrouw();
 heer();
 aas();

 i=0;
 for(n=0;n<4;n++)
  for(m=0;m<8;m++)
    getimage(10+m*70,10+n*85,62+m*70,92+n*85,krt[i++]);

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
   posy+=y;
   if(posx > MaxX-55) {if(x<2) x=6;   x=(-x*2)/3;      posx+=x/2; }
   if(posx <1)
     {if(posy>200 && posy<250) break;
      else {if(x>-2) x=-3;            x=(-x*3)/4;   posx+=x/2; }}
   if(posy > MaxY-85) {if(y<3) y=4;   x=(x*2)/3; y=(-y*2)/3; x=-x; posy+=y; }
   if(posy <1)        {if(y>-3) y=-4; x=(x*2)/3; y=(-y*2)/3; x=-x; posy+=y; }
   Sputimage(posx,posy,krt[(m*8)+n],COPY_PUT);
   delay(5);
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
 int m,n,i,x,y,color;
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
	if(MaxColors<3)
	 {if(color==MAGENTA) color=BLACK;
	  if(color==BLUE)    color=BLACK;
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
 int m,n,i,x,y,color;
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
strcpy(inputline[34],"xxxxxxBbbbbbbbbbbbbbGzzpppzEeeEbbbbbbbbbbBxxxxxxxx");
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
	if(MaxColors<3)
	 {if(color==MAGENTA) color=BLACK;
	  if(color==BLUE)    color=BLACK;
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
 int m,n,i,x,y,color;
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
strcpy(inputline[13],"aaaaaaaaaaaaaaaaaZwzzwwzzwwwrrPppPcaaaaaaaaaaaaaaa");
strcpy(inputline[14],"aaaaaaaaaaaaaaaaaZwzzwzwwwwwwrPPPccaaaaaaaaaaaaaaa");
strcpy(inputline[15],"aaaaaaaaaaaaaaaaaaZwwwzwwwwwwwZcccccaaaaaaaaaaaaaa");
strcpy(inputline[16],"aaaaaaaaaaaaaaaaaaZwwwzzwwwwwwZcccccaaaaaaaaaaaaaa");
strcpy(inputline[17],"aaaaaaaaaaaaaaaaaaaZwwwwwzwwwZccccccaaaaaaaaaaaaaa");
strcpy(inputline[18],"aaaaaaaaaaaaaaaaaaaaZwzzzwwwzZcccccccaaaaaaaaaaaaa");
strcpy(inputline[19],"aaaaaaaaaaaaaaaaaaaaaZwwwwwzwZcccccccaaaaaaaaaaaaa");
strcpy(inputline[20],"aaaaaaaaaaaaaaaaaaaaaZzzzzwwwwZcccccccaaaaaaaaaaaa");
strcpy(inputline[21],"aaaaaaaaaaaaaaaaaaaaaZwwwwwwwwZcccccccaaaaaaaaaaaa");
strcpy(inputline[22],"aaaaaaaaaaaaaaaaaaaaaZwwwwwwwwwZccccccaaaaaaaaaaaa");
strcpy(inputline[23],"aaaaaaaaaaaaaaaaaaaaaZwwwwwwwwwZcccccccaaaaaaaaaaa");
strcpy(inputline[24],"aaaaaaaaaaaaaaaaaaBZZZwwwwwwwwwwZccccccaaaaaaaaaaa");
strcpy(inputline[25],"aaaaaaaaaaaaaaaaaBbBwwwwwwwwwwwBbBccccccaaaaaaaaaa");
strcpy(inputline[26],"aaaaaaaaaaaIZZZZZZBbbbBwwwwwwBbbbbEEccccaaaaaaaaaa");
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
	if(MaxColors<3)
	 {if(color==MAGENTA) color=BLACK;
	  if(color==BLUE)    color=BLACK;
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
 int m,n,i,x,y,color;
 x=220;

/*boer */
strcpy(inputline[0], "ccccccccccccccccccccccccccccJJJJJccccccccccccccccc");
strcpy(inputline[1], "ccccccccccccccccccccccccccJJjjjjJccccccccccccccccc");
strcpy(inputline[2], "cccccccccccccccccccccccccJjjjjjJcccccccccccccccccc");
strcpy(inputline[3], "ccccccccccccccccccccccccJjjjjjJccccccccccccccccccc");
strcpy(inputline[4], "cccccccccccccccccccccccJjjjjjJcccccccccccccccccccc");
strcpy(inputline[5], "cccccwwwwwwwwwwwwwccccJjjjjJJccccccccccccccccccccc");
strcpy(inputline[6], "ccccwwwwwwwwwwwwwwwwpJjjjJJcccccccccwwwwwccccccccc");
strcpy(inputline[7], "ccccccwwwwwwwwwwwwpPJjjJJPPccccccccwwwwwwwcccccccc");
strcpy(inputline[8], "ccccwwwwwwwwwwwwwwwPJjJppppPPccccccccccccccccccccc");
strcpy(inputline[9], "ccwwwwwwwwwwwwwwcccPJJpppppppPPPcccccccccccccccccc");
strcpy(inputline[10],"cwwwwwwwwwwwwwcccPPpppppppppppppPPPcccccgggggggccc");
strcpy(inputline[11],"cwwwwwwwwwwwwwcccPppppppppppppppppPccgggggggjjgggc");
strcpy(inputline[12],"cyyyyyyyyyyyyyccccPPPPPPPPPPpppppPPccgggjjggjjggjj");
strcpy(inputline[13],"cyyyyyyyyyyyyycccccRrrrWwwwPPPPPPcccggggjjggggggjj");
strcpy(inputline[14],"cccccccYcccccccccccRrrWwwwwwwwrrRcccggggggjjggjjgg");
strcpy(inputline[15],"cccccccYYcccccccccRrrWwZZwwZZwWrRccggjjgggjjggjjgg");
strcpy(inputline[16],"cccccccYyYccccccccRrWwwwwZwwwwWrRcccgjjggjjggggggg");
strcpy(inputline[17],"cccccccYyyYYccccccRrWwwwwZwwwwWrRcccgggggjjggggjjg");
strcpy(inputline[18],"cccccccYyyYyYcccccRrWwwwwZwwwwWrRcccccgggggjjggjjg");
strcpy(inputline[19],"ccccccccYyYYyYccccRrrWwWrrrrwwWrRcccccccgggjjggggg");
strcpy(inputline[20],"ccccccccYyYUYyYcccRrrrWWrrrrwwWrRccccccccccuuuuccc");
strcpy(inputline[21],"ccccccccYyYUUYyYccRRRRwwZZZZWWRRRccccccccccuuuuccc");
strcpy(inputline[22],"ccccccccYyYUuUYyYccccccZrrrrwzwRcccccccccccuuuuccc");
strcpy(inputline[23],"ccccccccYyYcUuUYYYccccZWrrrrzwwZcccccccccccuuuuccc");
strcpy(inputline[24],"cccccccccYYcUuUccYYcccZwrrrrwwwwZccccccccccuuuuccc");
strcpy(inputline[25],"cccccccccYcccUuUcccYcZWwwwwwwwwwZccccccccccuuuuccc");
strcpy(inputline[26],"cccccccccYcccUuUcccccZWWWWWWWWWWWZEEEccccccuuuuccc");
strcpy(inputline[27],"ccccccccccccccUuUccjjjjwwwjeeeeeeeeeeEcccccuuuuccc");
strcpy(inputline[28],"cccccccccccccccUuUjjjjjjjjEeeeeeeeeeeeEccccuuuuccc");
strcpy(inputline[29],"ccccccccccGGGGGUuUbbbjjjjEeeeeeeeeeeeeeEcccuuuuccc");
strcpy(inputline[30],"ccccccccGGggggggUuUbbbbbbEeeeeeeeeeeeeeEcccuuuuccc");
strcpy(inputline[31],"cccccccGgggggggugUuUbbbbEeeeeeeeeeeeeeeEEccuuuuccc");
strcpy(inputline[32],"cccccccGgggggggggUuUbbbEeeeeeeeeeeeeEEEggGcuuuuccc");
strcpy(inputline[33],"ccccccGggggggggBbBUuUbEeeeeeeeeeeeeEgggggGcuuuuccc");
strcpy(inputline[34],"ccccccGgggggggBbbbUuUeEeeeeeeeeeeEgggggggGcuuuuccc");
strcpy(inputline[35],"cccccGgggggggBbbbbbUuUeeeeeeeeeeEgggggggggGuuuuccc");
strcpy(inputline[36],"cccccGgggggggBbbbbgUuUeeeeeeeeeEggggggggggGuuuuccc");
strcpy(inputline[37],"cccccGgggggggBbbbbbbUuUeeeeeeeeEgggggggggggGuuuccc");
strcpy(inputline[38],"cccccGgggggggBbbbbbbUuUeeeeeeeEbbbGgggggggggGuuccc");
strcpy(inputline[39],"iiiiiGgggggggBbbbbbEeUuUeeeeeEbbbbBGgggggggggGuiii");
strcpy(inputline[40],"iiiiiGgggggggBbbbbEeeUuUeeeeeEbbbbBGggggggggggGiii");
strcpy(inputline[41],"iiiiiGgggggggBbbbEeeeeUuUeeeeEbbbbBiGgggggggggGiii");
strcpy(inputline[42],"iiiiGgggggggBbbbbEeeeeUuUeeeEbbbbbBiiGggggggggGiii");
strcpy(inputline[43],"iiiiGgggggggBbbbEeeeeeeUuUeeEbbbbBiiiGgggggggGiiii");
strcpy(inputline[44],"iiiiGgggggggBbbbEeeeeeeUuUeebbbbbBiiGggggggggGiiii");
strcpy(inputline[45],"iiiiGgggggggBbbEeeeeeeeeUuUeebbbbBiiGgggggggGiiiii");
strcpy(inputline[46],"iiiiGgggggggBbbEeeeeeeeeeUuUebbbbBiiGggggggGiiiiii");
strcpy(inputline[47],"iiiiGgggggggBbbEeeeeeeeeEUuUebbbbBiGggggggGiiiiiii");
strcpy(inputline[48],"iiiiGgggggggBBeeeeeeeeeeEbUuUbbbbBGgggggggGiiiiiii");

for(i=0;i<4;i++)
 {
  y=i*85+10;

    kaartvorm(x,y);
/*if(MaxColors<3)
 {
 for(n=0;n<50;n++)
    {
     for(m=0;m<48;m++)
       {
	if(inputline[n][m] <97) color=BLACK;
	 else color=WHITE;
	putpixel(x+m+2,y+n+17,color);
       }
    }
  }
 else {
*/
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
	if(MaxColors<3)
	 {if(color==MAGENTA) color=BLACK;
	  if(color==BLUE)    color=BLACK;
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
    if(MaxColors<3) setcolor(BLACK);
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
    if(MaxColors<3) setcolor(BLACK);
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
    if(MaxColors<3) setcolor(BLACK);
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
    if(MaxColors<3) setcolor(BLACK);
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
/* setcolor(BROWN);
 setfillstyle(SOLID_FILL,BROWN);
*/ floodfill(x+10,y+10,BLACK);
 setcolor(YELLOW);
 setfillstyle(INTERLEAVE_FILL,YELLOW);
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
 strcpy(harten[2] ,"RRRRRRwRRRRRRw");
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
