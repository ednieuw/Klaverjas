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
#include "kjas.h"
#include "kjr.h"
#include "kj0.h"
#include "kj2.h"


#define TRUE	1			/* Define some handy constants	*/
#define FALSE	0			/* Define some handy constants	*/
#define ON	1			/* Define some handy constants	*/
#define OFF	0			/* Define some handy constants	*/

#define L32 for(n=0;n<32;n++) 
#define L16 for(n=0;n<16;n++) 
#define L8  for(n=0;n<8 ;n++) 
#define L4  for(n=0;n<4 ;n++) 

#define SLAGKANSLEVEL 60

void  main(int argc);
void  einde(void);
void  Initialize(void);
void  Delen(void);
void  Vulhanden(void);
int   bepaal_slagkans(char karte, int kleur);
double guillermie(int a,int h,int z,int x,int s);
double kans_hoger(int kaartenhoger,int kleur,int specifiek,int vrager);
double kans_kaart(int kleur,int specifiek,int vrager);
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
int   check_valid(void);
int   hogere(char kv,char *ks,char *volgorde);
void  evalueerspel(void);
int   wie_slag(void);
char  hoogsteroem(int);
char  laagsteroem(int);
int   bepaal_hoogsteroem(int Kkleur,char Skaart);
int   bepaal_laagsteroem(int Kkleur,char Skaart);
void  humaan(void);
void  troef_vragen(void);
int   bepaalroempunten(char *s,int kolor);
void  punten(void);
void  print_laatsteslag(void);
void  intro_text(void);
void  init_mouse(void);
void  error_legkaart(void);

void  kaarten();
void  kaartvorm(int x,int y);
void  aas();
void  heer();
void  vrouw();
void  boer();
void  Klaver(int x,int y);
void  Schoppen(int x,int y);
void  Ruiten(int x,int y);
void  Harten(int x,int y);
void  Tien(void);
void  Negen(void);
void  Acht(void);
void  Zeven(void);
void  achterkant();
void  kleuren(void);

int    GraphDriver;		/* The Graphics device driver		*/
int    GraphMode;		/* The Graphics mode value		*/
int    MaxX, MaxY;		/* The maximum resolution of the screen */
int    MaxColors;		/* The maximum # of colors available	*/
int    ErrorCode;		/* Reports any graphics errors		*/
struct palettetype palette;     /* for palette info			*/

struct krts { 
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
              int dpos;
	    } kaart[32];


struct deck {
	      int slagkans;
	      int slagkans0;
	      char naam;
	      int kleur;         /* 1=K 2=S 3=R 4=H */
	      int waarde;  
	      int troef;
	      int gegarandeerd;  /* 0=ja 1=nee */
	    } hand[2][8];

struct deck tafel[2][8];

struct slach { int kleur;
	       char naam;
	       int troef;  /* 0 = geen troef */
	       int speler;
	       int kans;
	       int waarde;
	       int tactiek;
	    } slag[9][4];

int deeltabel[32];
int verzaakt[2][4]={{0,0,0,0},{0,0,0,0}};
int tnoord[4]={0,0,0,0};
int tzuid[4]={0,0,0,0};
#define NKRT 35
void *krt[NKRT];
void *veld;
char rangtroef[9] = { "B9ATHV87\0"};
char rangnorm[9]  = { "ATHVB987\0"};
char rangroem[9]  = { "AHVBT987\0"};
int  roem[2];
char KLEUR[5][9]     = { "Klaver\0","Schoppen\0","Ruiten\0","Harten\0"};
char kaartdicht[17];
int  iKrt_gespeeld,iKrt[4][2],iKrt_tafel[4][2];
char Krt_weg[4][9],Krt_vrij[4][9],Krt_dicht[4][9];
char Krt_totweg[36],Krt_totvrij[36],Krt_totdicht[36];
int  VRAGER,VRAGERHAND,startvrager;
int  TROEF,SPELER,Speler;
char khand[2][4][9],ktafel[2][4][9];
int  DICHT=0,COMP=0,DEMO=0;
int  SLAG,SLAGKRTNO;
int  gewonnen[2]={0,0};
char Lkaart,LKAART3,Skrt41;
int  Lkleur,LKLEUR3;
char key=' ';
int  HOOGSTE;
int  ZW=FALSE; /*zwartwit demo*/
unsigned int puntenspel[2]={0,0};
unsigned long puntentotaalspel[2]={0,0}; /* Nul = Zuid, een = Noord */

double fact[19]={1.0,1.0,2.0,6.0,24.0,120.0,720.0,5040.0,40320.0,362880.0,
		 3628800.0,39916800.0,479001600.0,6227020800.0,87178291200.0,
		 1307674368000.0,20922789888000.0};
int  TACTIEK=0,TACTIEK41=FALSE,TACTIEKLAAG=FALSE,TACTIEKTT=FALSE;
char text[80];
char klaver[15][15];
char schoppen[15][15];
char ruiten[15][15];
char harten[15][15];
char inputline[50][55];
unsigned long tac[76];
char memory_model=2; /*large*/
unsigned short Mpresent=FALSE;
long Kaartpnt[2]={0,0};
long     Tpnt[2]={0,0};
long Troefpnt[2]={0,0};
long Gewonnen[2]={0,0};
long  Roempnt[2]={0,0};
long Troefkrt[2]={0,0};
long      Pit[2]={0,0};
long     Tpit[2]={0,0};
long      Nat[2]={0,0};
int     vierk[2]={0,0};

unsigned short video_buffer=0xB000;
char snow_protect=0;
char video_page=0;
char error_code=0;
char beep_on=1;
char time_out=10;
struct kljas kj;
char reg[81];
char kjnivo;
char rljas;			 /* 0=human
				    1=single step
				    2=test */

struct dek *s;
struct hand *i;
struct hand *h;

extern int SDEMO;

/************************** MAIN *****************************/

void main(int argc)
{
 int n;
 unsigned int size;
 float a[15];

 getpalette(&palette);
 if(argc==2) ZW=TRUE; else ZW=FALSE;
if(!SDEMO) Initialize();
 kjstart();
 size=imagesize(0,0,130,230);
 veld=farmalloc(size);
 size=imagesize(0,0,52,82);
  for(n=0;n<NKRT;n++)
    {
     krt[n]=farmalloc(size);
     if(krt[n]==NULL)  {closegraph(); printf("No room, no: %d\n",n); exit(1); }  
     }
if(!SDEMO) getimage(0,0,52,82,krt[33]);  /* leeg veld*/

 intro_text();
 if(SDEMO) clrscr();
 Speler=random(2)+1;
 if(Mpresent) Mpresent=mouse_present();
 if(Mpresent) {init_mouse(); set_mouse_cursor(1,1); mouse_cursor_off();}

while(TRUE)
{
if(!SDEMO){ cleardevice();
            setbkcolor(BLACK);
          }
 TROEF=999;
 SLAG=0;
 SLAGKRTNO=0;
 Delen();
 kjdelen();
 Speler=1-(Speler-1)+1;
 VRAGER=startvrager=Speler;
 kj.w=VRAGER-1;
 kj.n=kj.w;

L4 { tnoord[n] = 1;   /* gedraaide kaarten al gedraaid ? */ 
      tzuid[n] = 1;
   }
 punten();
 kaarten_vrij();
 leg_tafel();
 Vulhanden();

 SLAG=0;
 if(COMP==9) troef_bepalen();
  else {
	  if(startvrager==2){
           troef_bepalen();
           kj.t=kjtroef();
       }
	  else
	  {
	   if(Mpresent)  set_mouse_cursor(1,1);
           kj.t=kjtroef();
           TROEF=(int)kj.t;
           troef_vragen();
       }  }


 L32{ switch(kaart[n].DichtIkHy){
       case  1:
       case  3:
       case 33:Kaartpnt[0]+=kaart[n].actwaarde;
	       if(kaart[n].kleur==TROEF) {Troefkrt[0]++; 
					  Troefpnt[0]+=kaart[n].actwaarde;
					  }
	       break;
       case  2:
       case  4:
       case 44:Kaartpnt[1]+=kaart[n].actwaarde;
	       if(kaart[n].kleur==TROEF) {Troefkrt[1]++; 
					  Troefpnt[1]+=kaart[n].actwaarde;
					  }
       break;
     }}



 for(SLAG=1;SLAG<9;SLAG++)
  {
 memset(kj.s,0,4*sizeof(struct kaart));
   TACTIEK=0;
   speler1();
   if(!legkaart(Lkaart,Lkleur,VRAGER) ){error_legkaart(); break;}
   if(!check_valid() ){error_legkaart(); break;}
   startvrager=VRAGER;
   if(TACTIEK==41) TACTIEK41=TRUE;
   tac[TACTIEK]++;

   TACTIEK=0;
   tegenspeler1();
   if(!legkaart(Lkaart,Lkleur,VRAGER) ) {error_legkaart(); break;}
   if(!check_valid() ){error_legkaart(); break;}
   tac[TACTIEK]++;


   TACTIEK=0;
   speler2();
   if(!legkaart(Lkaart,Lkleur,VRAGER) ) {error_legkaart(); break;}
   if(!check_valid() ){error_legkaart(); break;}
   tac[TACTIEK]++;

   TACTIEK=0;
   tegenspeler2();
   if(!legkaart(Lkaart,Lkleur,VRAGER) ) {error_legkaart(); break;}
   if(!check_valid() ){error_legkaart(); break;}
   tac[TACTIEK]++;

   evalueer();
   punten();
   kjmaakslag(SLAG-1);
   if (SLAG==8)  evalueerspel();

   if(key!='c')
    { if (Mpresent)
	 {setcolor(WHITE);
	  outtextxy(1,10*10,"Klik muis of druk toets");
	  while(TRUE)
	   {
	    while(!number_presses_down(0))
		if(bioskey(1))
		 {n=getch();  if(n==27) einde();  break;}
	    if(n) break;
	    while(!number_presses_up(0));
	   }
	}
      else {setcolor(WHITE);
	    outtextxy(1,10*10,"Druk toets");
	    getch();
	   }
    }
   if(SLAG<8)
   {
if(!SDEMO){
   setcolor(BLACK);
   setviewport(1,100,245,120,0);
   clearviewport();
   setviewport(0,0,MaxX,MaxY,0);
   strset(text,219);
           }
   updatetafel();
   updatetafelkaarten();
   print_laatsteslag();
if(!SDEMO){
   setviewport(625,45,MaxX,315,0);
   clearviewport();
   setviewport(0,0,MaxX,MaxY,0);
          }
   if(bioskey(1)) {n=getch(); if(n==27) {SLAG =99; }}
   }

  }
  if(SLAG>15) break;
if(SDEMO){
  gotoxy(1,1);
  a[0]=100*(float)gewonnen[0]/((float)gewonnen[1]+(float)gewonnen[0]+0.000001);
  a[1]=100*(float)Gewonnen[0]/((float)Gewonnen[1]+(float)Gewonnen[0]);
  a[2]=100*(float)Tpnt[0]/((float)Tpnt[1]+(float)Tpnt[0]);
  a[3]=100*(float)Kaartpnt[0]/((float)Kaartpnt[1]+(float)Kaartpnt[0]);
  a[4]=100*(float)Troefpnt[0]/((float)Troefpnt[1]+(float)Troefpnt[0]);
  a[5]=100*(float)Troefkrt[0]/((float)Troefkrt[1]+(float)Troefkrt[0]);
  a[6]=100*(float)Roempnt[0]/((float)Roempnt[1]+(float)Roempnt[0]);

  cputs("           Noord  |    Zuid\r\n");
  cprintf("Spel 1500%8d | %8d   %4.1f   %4.1f \r\n",gewonnen[1],gewonnen[0],100-a[0],a[0]);
  cprintf("Spel pnt %8ld | %8ld \r\n",puntentotaalspel[1],puntentotaalspel[0]);
  cprintf("Gewonnen %8ld | %8ld   %4.1f   %4.1f \r\n",Gewonnen[1],Gewonnen[0],100-a[1],a[1]);
  cprintf("Pnttot   %8ld | %8ld   %4.1f   %4.1f \r\n",Tpnt[1],Tpnt[0],100-a[2],a[2]);
  cprintf("Kaartpnt %8ld | %8ld   %4.1f   %4.1f \r\n",Kaartpnt[1],Kaartpnt[0],100-a[3],a[3]);
  cprintf("Troefpnt %8ld | %8ld   %4.1f   %4.1f \r\n",Troefpnt[1],Troefpnt[0],100-a[4],a[4]);
  cprintf("Troefkrt %8ld | %8ld   %4.1f   %4.1f \r\n",Troefkrt[1],Troefkrt[0],100-a[5],a[5]);
  cprintf("Roempnt  %8ld | %8ld   %4.1f   %4.1f \r\n",Roempnt[1],Roempnt[0],100-a[6],a[6]);
  cprintf("Pit      %8ld | %8ld\r\n",Pit[1],Pit[0]);
  cprintf("Tegenpit %8ld | %8ld\r\n",Tpit[1],Tpit[0]);
  cprintf("Nat      %8ld | %8ld\r\n",Nat[1],Nat[0]);
  cprintf("Vierkaart%8d | %8d\r\n",vierk[1],vierk[0]);
  cprintf("Tac72 %8d \r\n",tac[72]);
         }
 }
 einde();
}

/******************************************************/
 void einde(void)
 {
 int n;
 closegraph();
 setallpalette(&palette);
/* for(n=NKRT-1;n>=0;n--)  free(krt[n]);*/

 for(n=0;n<76;n++)
  {printf(" (%4d,%6ld) ",n,tac[n]);
  if((n/5)*5==n) printf("\n");
  }

    puts("           Noord  |    Zuid");
  printf("Gewonnen %8ld | %8ld\n",Gewonnen[1],Gewonnen[0]);
  printf("Kaartpnt %8ld | %8ld\n",Kaartpnt[1],Kaartpnt[0]);
  printf("Troefpnt %8ld | %8ld\n",Troefpnt[1],Troefpnt[0]);
  printf("Troefkrt %8ld | %8ld\n",Troefkrt[1],Troefkrt[0]);
  printf("Roempnt  %8ld | %8ld\n",Roempnt[1],Roempnt[0]);
  printf("Pit      %8ld | %8ld\n",Pit[1],Pit[0]);
  printf("Tegenpit %8ld | %8ld\n",Tpit[1],Tpit[0]);
  printf("Nat      %8ld | %8ld  ",Nat[1],Nat[0]);
  getch();
 exit(1);
 }

/******************* bepaal slagkans ************************/
int bepaal_slagkans(char karte, int kleur)
{
int d,i,j,n,ts,tss;
char nop[40],nop1[40];
int vrager =99;
int pos_kaartvrager,aantal_hoger;

double kans_hogerr,kans_kaartt,kans_troefkaartt;

vrager=wie_vrager(karte,kleur);
if (vrager > 10) vrager /=10;
if(vrager>2) vrager=vrager-2;
ts=1;
if(vrager==1) tss=2; else tss=1;
if(karte==0) return(-100);

if(kleur==TROEF) strcpy(nop,rangtroef);
	 else    strcpy(nop,rangnorm);

pos_kaartvrager=hogere(karte,Krt_vrij[kleur],nop)+1;
if(pos_kaartvrager==1) kans_hogerr=1;

i=j=0; /* kijk of hogere kaart al gespeeld */
if(SLAGKRTNO)
 {
 for(n=0;n<=SLAGKRTNO;n++)
  if(slag[SLAG][n].troef && kleur!=TROEF)          return(0);

  if(slag[SLAG][0].kleur !=kleur && kleur!=TROEF)  return(0);
  
for(n=0;n<=SLAGKRTNO;n++) /*kijk of hogere al in slag op tafel*/
 if(slag[SLAG][n].kleur==kleur)   nop1[j++]=slag[SLAG][n].naam;
 nop1[j]=0;
 i=hogere(karte,nop1,nop);
 if(i>0)                                           return(0);
 }

 L8 {
    if(nop[n]!=karte) nop1[n]=nop[n];
     else {nop1[n]=0; break;}
   }
 nop1[n]=0;
 d=j=1;
 if(SLAGKRTNO)
   { 
    for(n=0;n<=SLAGKRTNO;n++)
     if(slag[SLAG][n].speler ==tss+2) j=0;
     if(slag[SLAG][n].speler ==tss)   d=0;
   }			     /*als tafel al gespeeld doen ze niet meer mee*/
 if(j && pos_kaartvrager>1 && strlen(ktafel[ts][kleur])>0)
  {
   i=0;			/* Bereken aantal hogere in ts tafelkaarten */
   i=hogere(karte,ktafel[ts][kleur],nop);
   if(i>0)                                          return(0);
  }
 
 if(j && TROEF!=999 && kleur !=TROEF)
  {                 /* Als geen kleur en wel troef op tafel bij ts kans =0 */
   if( !iKrt_tafel[kleur][ts] && iKrt_tafel[TROEF][ts])
     return(0);
  }

  if(i==0 && d==0 && SLAGKRTNO)/* Als dichte kaart gespeeld en geen hogere*/
  { for(n=0;n<=SLAGKRTNO;n++)
     if(slag[SLAG][n].speler ==tss ) return(100);
  }
			/* Bereken aantal hogere in dichte kaarten */
 aantal_hoger=hogere(karte,Krt_dicht[kleur],nop);
 if(SLAG==8 && hogere(karte,Krt_vrij[kleur],nop))         return(0);

 if(aantal_hoger>0)
 kans_hogerr=1-kans_hoger(aantal_hoger,kleur,0,vrager);
   else{ kans_hogerr=1;
	 if(strlen(Krt_dicht[TROEF])==0) return((int)(kans_hogerr*100));
	 if(verzaakt[tss-1][TROEF])      return((int)(kans_hogerr*100));
       }
if(kleur!=TROEF && TROEF!=999 ) 
       {
	if(SLAGKRTNO==8) if( strlen(Krt_dicht[TROEF])) return(0);
	if(strlen(Krt_dicht[kleur])==0) kans_kaartt=0;
	else
	kans_kaartt = kans_kaart(kleur,0,vrager);   /*kans tp een kaart */
/*	gotoxy(20,11);
	printf("%3.3f",kans_kaartt);
	gotoxy(20,12);
	printf("%s",KLEUR[kleur]);
	gotoxy(20,13);
	printf("%d",VRAGER);*/
	if(kans_kaartt < 0.4 && strlen(Krt_dicht[TROEF]))
	  {
	  kans_troefkaartt = kans_kaart(TROEF,0,vrager);/* kans op troef */
	  kans_kaartt = 1-kans_troefkaartt;
	  }
	kans_hogerr *= kans_kaartt;
       }

return((int)(kans_hogerr*100));
}
/****************** speler1, computer,  speelt*****************/
void speler1(void)
{
 int m,n,i,j;
 int Skleur,Skl,tss;
 char Skaart,Ska;
 int  kans_troefkaarttp;

 if(startvrager>2) startvrager-=2;
 VRAGER=startvrager;
 if(VRAGER==1) tss=2; else tss=1;
 SLAGKRTNO=0;
/* if(strlen(Krt_totdicht)<2) eindspel();*/


 Vulhanden();

 Skleur=5;
 Skaart=0;
 if(iKrt_tafel[TROEF][1]) kans_troefkaarttp=100;
 else kans_troefkaarttp = 100 * (kans_kaart(TROEF,0,VRAGER)); /* kans op troef */
 if(verzaakt[tss-1][TROEF] && ! iKrt_tafel[TROEF][1]) kans_troefkaarttp=0;
 if(Krt_dicht[TROEF]==0)  kans_troefkaarttp=0;
/* gotoxy(20,10);
 printf("%3d  ",kans_troefkaarttp);*/
if(!COMP && (VRAGER==1 || VRAGER==3) ) {humaan(); return;}


 if(!Skaart) {  /* Roem van tafel halen */
 m=0; Ska=0;
 L4 { 
    if(tafel[0][n].gegarandeerd==1)
	{
	 Skaart = tafel[0][n].naam;
	 Skleur = tafel[0][n].kleur;
	 i=bepaal_hoogsteroem(Skleur,Skaart);
	 if(m<i)
	  {Ska=Skaart; Skl=Skleur; m=i;}
	 }}
  L8 {
      if(hand[0][n].gegarandeerd==1)
       { Skaart = hand[0][n].naam;
	 Skleur = hand[0][n].kleur;
	 i=bepaal_hoogsteroem(Skleur,Skaart);
	 if(m<i)
	  {Ska=Skaart;Skl=Skleur; m=i;}
	 }}
	 if(Ska) {Skaart=Ska; Skleur=Skl; TACTIEK=7;} else Skaart=0;
     }

/* Als kale tien of troef negen kaal op tafel*/
 L4 {if(Skaart) break;
    if(tafel[0][n].gegarandeerd)
	{Skleur = tafel[0][n].kleur;
	 if(iKrt_tafel[Skleur][1]==1)
	  {if(ktafel[1][Skleur][0]=='T')
		    Skaart = tafel[0][n].naam;
	   if(ktafel[1][Skleur][0]=='9' && Skleur==TROEF) 
		    Skaart = tafel[0][n].naam;
	TACTIEK=1;
	  }}}

 if(!Skaart) {
  L8 {if(Skaart) break;
      if(hand[0][n].gegarandeerd)
       { Skleur = hand[0][n].kleur;
	 if(iKrt_tafel[Skleur][1]==1)
	  {if(ktafel[1][Skleur][0]=='T')
		    Skaart = hand[0][n].naam; 
	   if(ktafel[1][Skleur][0]=='9' && Skleur==TROEF)
		    Skaart = hand[0][n].naam; 
	 TACTIEK=2;
	 }}}}


/* Als ik A en hij kale tien van kleur op tafel*/
 if(!Skaart )
   {
 Skleur=5;
  L4 {
     if(Skaart)  break;
     if(tafel[1][n].naam=='T' && iKrt[tafel[1][n].kleur][1]==1
	    && tafel[1][n].kleur!=TROEF)
       {
       Skleur=tafel[1][n].kleur;
       L8  {if(hand[0][n].naam=='A' && hand[0][n].kleur==Skleur 
		  && hand[0][n].slagkans>SLAGKANSLEVEL)
	     {Skaart = hand[0][n].naam; break; }
	   }
	if(!Skaart)
	 {
	L4 {if(tafel[0][n].naam=='A' && tafel[0][n].kleur==Skleur 
		  && tafel[0][n].slagkans>SLAGKANSLEVEL)
	     {Skaart = tafel[0][n].naam; break;}
	 } }
    } }  
    if(Skaart)
     TACTIEK=50;
  }

 if(!Skaart) {      /* Zoek roemkans & slagkans>0.75*/
 Skleur=5;
  m=j=0;
  i=1;
  L4 {if(tafel[0][n].slagkans>80 ) /* 75 -->50*/
       {
       if(m<=tafel[0][n].slagkans)
	{
	i=bepaal_hoogsteroem(tafel[0][n].kleur,tafel[0][n].naam);
	if(i>j)
	{
	 j=i;
	 m=tafel[0][n].slagkans;
	 Skaart = tafel[0][n].naam;
	 Skleur = tafel[0][n].kleur;
	 TACTIEK=10;
	}} } }
  L8 {if(hand[0][n].slagkans> 80)
       {
      if(m<=hand[0][n].slagkans)
       {
	i=bepaal_hoogsteroem(hand[0][n].kleur,hand[0][n].naam);
	if(i>j)
	{j=i;
	m=hand[0][n].slagkans;
	Skaart = hand[0][n].naam;
	Skleur = hand[0][n].kleur;
	TACTIEK=62;
    }}}}}

/* Als ik troef op tafel en hij kale A of tien van kleur ik niet
   en geen gegarandeerde troefkaart wordt weggegeven */
 if(!Skaart && iKrt_tafel[TROEF][0] )
   {Skleur=5;
  L4{if(tafel[0][n].troef && !tafel[0][n].gegarandeerd)
      {  Skleur=6; Skrt41=tafel[0][n].naam;}}
  if(Skleur==6) /* Als een niet gegarandeerde troefkaart op tafel*/
  {
  L4 {if((tafel[1][n].naam=='A' && tafel[1][n].kleur!=TROEF) || 
	 (tafel[1][n].naam=='T' && tafel[1][n].kleur!=TROEF) )
    {if(iKrt_tafel[tafel[1][n].kleur][1]==1 &&
	iKrt_tafel[tafel[1][n].kleur][0]==0)	Skleur = tafel[1][n].kleur;
     }}
  if(Skleur<4)
  {L8   {if(hand[0][n].kleur==Skleur && hand[0][n].waarde<5)
      { Skaart = hand[0][n].naam;}}
  if(!Skaart)  {L8 
   {if(hand[0][n].kleur==Skleur)   { Skaart = hand[0][n].naam; break; }}
	       }    
  if(Skaart)  TACTIEK=41; }
   } }

if(Skaart&&TACTIEK!=41  &&
   !(Skleur==TROEF && Skaart=='V')
   && !(TACTIEK==7 && Skleur!=TROEF) )
/* laag uitkomen */
 {
 VRAGER=wie_vrager(Skaart,Skleur);
 Lkaart=Skaart;
 Lkleur=Skleur;
 i=j=0;
 if(VRAGER<3 && iKrt_tafel[Skleur][0])
  {
   for(m=0;m<iKrt_tafel[Skleur][0];m++)
    {if(Skleur==TROEF &&    /* Als niet overtroeft*/
     strpos(rangtroef,ktafel[0][Skleur][m])<strpos(rangtroef,Lkaart))
     continue;

     i=bepaal_hoogsteroem(Skleur,ktafel[0][Skleur][m]);
     if(i>=j) {j=i; Skaart=ktafel[0][Skleur][m];
     TACTIEKLAAG=TRUE;LKAART3=Lkaart;LKLEUR3=Lkleur; }
   } }
 if(VRAGER>2 && iKrt[Skleur][0])
  {
  for(m=0;m<iKrt[Skleur][0];m++)
   {if(Skleur==TROEF &&    /* Als niet overtroeft*/
    strpos(rangtroef,khand[0][Skleur][m])<strpos(rangtroef,Lkaart))
    continue; 

    i=bepaal_hoogsteroem(Skleur,khand[0][Skleur][m]);
    if(i>=j) {j=i; Skaart=khand[0][Skleur][m];
    TACTIEKLAAG=TRUE;LKAART3=Lkaart;LKLEUR3=Lkleur;}
   } }
 VRAGER=wie_vrager(Skaart,Skleur);
 Lkaart=Skaart;
 Lkleur=Skleur;
 return; }
  
 if(!Skaart) {/* gegarandeerde slagen niet troefslagen uitspelen*/
 L4 { if(tafel[0][n].gegarandeerd==1 ) 
     { if(tafel[0][n].kleur==TROEF   ) continue;
	 Skaart = tafel[0][n].naam;
	 Skleur = tafel[0][n].kleur;
	 TACTIEK=9;
	 break;
	}}}
 if(!Skaart) {
  L8 {if(hand[0][n].gegarandeerd==1)
       {if(hand[0][n].kleur==TROEF  ) continue;
	 Skaart = hand[0][n].naam;
	 Skleur = hand[0][n].kleur;
	 TACTIEK=8;
	 break;
       }}}

/* gegarandeerde slagen en troef trekken als ts nog misschien troef */
 if(!Skaart) {
 L4 { if(tafel[0][n].gegarandeerd==1 ) 
     { if(tafel[0][n].kleur==TROEF  &&  kans_troefkaarttp<30 ) continue;
	 Skaart = tafel[0][n].naam;
	 Skleur = tafel[0][n].kleur;
	 TACTIEK=57;
	 break;
	}}}
 if(!Skaart) {
  L8 {if(hand[0][n].gegarandeerd==1)
       {if(hand[0][n].kleur==TROEF  &&  kans_troefkaarttp<30 ) continue;
	 Skaart = hand[0][n].naam;
	 Skleur = hand[0][n].kleur;
	 TACTIEK=58;
	 break;
       }}}
/*
  /* Als ik troef op tafel en hij A T of H van kleur ik niet*/
 if(!Skaart && iKrt_tafel[TROEF][0]  )
   {
 Skleur=5;
  L4 {if((tafel[1][n].naam=='A' || tafel[1][n].naam=='T'
	||tafel[1][n].naam=='H') && tafel[1][n].kleur!=TROEF)
	if(iKrt_tafel[tafel[1][n].kleur][1]==1 &&
	   iKrt_tafel[tafel[1][n].kleur][0]==0) Skleur = tafel[1][n].kleur;
     }
  if(Skleur<4)
  {L8 
   {if(hand[0][n].kleur==Skleur && hand[0][n].waarde<5)
     { Skaart = hand[0][n].naam;}
   }
  if(!Skaart)  
  {L8 
   {if(hand[0][n].kleur==Skleur)
     { Skaart = hand[0][n].naam; break; }
   }   }    
  if(Skaart)  TACTIEK=47; 
  }  }
*/
  /* Als ik troef op tafel gebruiken om slagen te halen*/
 if(!Skaart && iKrt_tafel[TROEF][0]  )
   { Skleur=5;
  L4 {if(iKrt_tafel[tafel[1][n].kleur][0]==0 &&
	 iKrt_tafel[tafel[1][n].kleur][1]) Skleur = tafel[1][n].kleur;
     }
  if(Skleur<5)
  {L8 
   {if(hand[0][n].kleur==Skleur && hand[0][n].waarde<10)
     { Skaart = hand[0][n].naam; break; }
   }
  if(!Skaart)  
  {L8 
   {if(hand[0][n].kleur==Skleur)
     { Skaart = hand[0][n].naam; break; }
   }
   } }
  if(Skaart){  TACTIEK=54;   TACTIEKTT=TRUE;}

    }

 if(Skaart)
 {
 VRAGER=wie_vrager(Skaart,Skleur);
 Lkaart=Skaart;
 Lkleur=Skleur;
 return;
 }

 if(!Skaart) {      /* Zoek grootste slagkans >.75 */
  m=0;
  L4 {if(tafel[0][n].kleur==TROEF  &&  kans_troefkaarttp<20 ) continue;
       {if(tafel[0][n].slagkans>50)  /* 75 -->50*/
	{
	if(m<tafel[0][n].slagkans)
	 {
	  {m=tafel[0][n].slagkans;
	   Skaart = tafel[0][n].naam;
	   Skleur = tafel[0][n].kleur;
	   TACTIEK=11;
	} } } }}
  L8 { if(hand[0][n].kleur==TROEF  &&  kans_troefkaarttp<20 ) continue;
       {if(hand[0][n].slagkans> 50)
	{
	 if(m<hand[0][n].slagkans)
	  {
	   m=hand[0][n].slagkans;
	   Skaart = hand[0][n].naam;
	   Skleur = hand[0][n].kleur;
	   TACTIEK=63;
      }}}}}

 if(!Skaart && iKrt_tafel[TROEF][1]){/*troef van tstafel trekken, waarde <5*/
  m=0;
  L4 {
   if(!iKrt_tafel[tafel[0][n].kleur][1] && tafel[0][n].waarde<5)
      {if(   iKrt[tafel[0][n].kleur][0]==1   && /*Als ik A of T dan niet*/
       ( khand[0][tafel[0][n].kleur][0]=='A' || 
	 khand[0][tafel[0][n].kleur][0]=='T' ) ) Skaart=0;
       else {Skaart=tafel[0][n].naam; Skleur=tafel[0][n].kleur;}
     }}

 if(!Skaart) { 
  L8 {
   if(!iKrt[hand[0][n].kleur][1] && hand[0][n].waarde<5)
      {if(    iKrt[hand[0][n].kleur][0]==1   && 
       ( ktafel[0][hand[0][n].kleur][0]=='A' || 
	 ktafel[0][hand[0][n].kleur][0]=='T' ) ) Skaart=0;
       else {Skaart=hand[0][n].naam; Skleur=hand[0][n].kleur;}
     }}}
    if(Skaart) TACTIEK=5;
    }

 if(!Skaart) {   /* gegarandeerde slagen uitspelen*/
 L4 { if(tafel[0][n].gegarandeerd==1) /*&& kaart[n].kleur !=TROEF)*/
     {
	 Skaart = tafel[0][n].naam;
	 Skleur = tafel[0][n].kleur;
	 TACTIEK=55;
	 break;
	}}}
 if(!Skaart) {
  L8 {if(hand[0][n].gegarandeerd==1) /* && kaart[n].kleur !=TROEF)*/
       {
	 Skaart = hand[0][n].naam;
	 Skleur = hand[0][n].kleur;
	 TACTIEK=56;
	 break;
       }}}

 if(!Skaart){ /*kom uit met lage met weinig roemkans ,geen troef*/
  m=990;
  L32 {
   if(kaart[n].DichtIkHy==VRAGER+2 && m>=kaart[n].actwaarde
       && kaart[n].kleur !=TROEF)
       {
	   Skaart=0;
	if(bepaal_hoogsteroem(kaart[n].kleur,kaart[n].naam)==0);
	  {m=kaart[n].actwaarde;
	   Skaart = kaart[n].naam;
	   Skleur = kaart[n].kleur;
	  }
	 TACTIEK=13;
	}}}



 if(!Skaart){ /* kom uit met lage kaart , geen troef*/
  m=990;
  L32 {
   if(kaart[n].DichtIkHy==VRAGER && m>=kaart[n].actwaarde 
       && kaart[n].kleur !=TROEF)
	{
	 m=kaart[n].actwaarde;
	 Skaart = kaart[n].naam;
	 Skleur = kaart[n].kleur;
	 TACTIEK=14;
	}}}
 if(!Skaart){ /* kom uit met lage kaart */
  m=990;
  L32 {
   if(kaart[n].DichtIkHy==VRAGER && m>=kaart[n].actwaarde)
	{
	 m=kaart[n].actwaarde;
	 Skaart = kaart[n].naam;
	 Skleur = kaart[n].kleur;
	 TACTIEK=15;
	}}}

 VRAGER=wie_vrager(Skaart,Skleur);
 Lkaart=Skaart;
 Lkleur=Skleur;

}

/*********************** tegenspeler van tafel ***********/
void  tegenspeler1(void)  
{
char slagvolgorde[10],nop[10],nop1[10];
int Skleur,m,n,i,j,s,aantalhoger;
int ss[9];
char Skaart;

 if(startvrager==1 || startvrager==3) VRAGER=4;

 else VRAGER=3;


 Vulhanden();
 Lkaart=0;
 Skleur=slag[SLAG][0].kleur;
 Skaart=slag[SLAG][0].naam;
 Lkleur=Skleur;

if(slag[SLAG][0].troef) strcpy(slagvolgorde,rangtroef);
	       else     strcpy(slagvolgorde,rangnorm);

 if(!COMP && VRAGER==3) {humaan(); return;}

   if(iKrt_tafel[Skleur][0]==1)
     { Lkaart=ktafel[0][Skleur][0]; TACTIEK=40;    return;    }
   if(iKrt_tafel[Skleur][0] >1 && Skleur==TROEF)
      {
      L8 { if(slagvolgorde[n]!=Skaart) nop1[n]=slagvolgorde[n];
	     else {nop1[n]=0; break;}
	   }
	       nop1[n]=0;
	  i=0;			/* Bereken aantal hogere op tafel */
	  for(m=0;m<iKrt_tafel[Skleur][0];m++)
	   {
	    if(strpos(nop1,ktafel[0][Skleur][m])==0) continue;
	    nop[i++]=ktafel[0][Skleur][m];
	   }
	  nop[i]=0;  /* string met hogere kaarten */
	  aantalhoger=i;
	  s=-110;
	  for(n=0;n<aantalhoger;n++)
	   {
	    i=bepaal_slagkans(nop[n],Skleur);
	    if(i>=s) {s=i; j=n;}
	   }
       if(aantalhoger==1) {Lkaart=nop[j]; TACTIEK=18; return;}
       if(i>40)      {Lkaart=nop[j];TACTIEK=19;}
	 else {
i=0;
for(n=Skleur*8;n<(Skleur+1)*8;n++) ss[i++]=kaart[n].DichtIkHy;

for(n=Skleur*8;n<(Skleur+1)*8;n++)
  if(kaart[n].DichtIkHy==VRAGER) kaart[n].DichtIkHy=5;

for(m=0;m<strlen(nop);m++)
  {for(n=Skleur*8;n<(Skleur+1)*8;n++)
     {if(kaart[n].naam==nop[m]) kaart[n].DichtIkHy=VRAGER;}
  }
 Lkaart=laagsteroem(Skleur); TACTIEK=42;
 i=0;
for(n=Skleur*8;n<(Skleur+1)*8;n++) kaart[n].DichtIkHy=ss[i++];
	  }
  }
if(!Lkaart) bekijk_beste_slag(slag[SLAG][0].kleur); 

}

/*********************** tegenspeler 2 *********************/
void  tegenspeler2(void)
{
char slagvolgorde[10],nop[10],nop1[10],khoger[10];
int Skleur,Skleur1,Skleur2,m,n,i,j,s,t,aantalhoger;
char Skaart,Skaart1,Skaart2;
char kname[20];
int ikarte;

 if(startvrager==1 || startvrager==3) VRAGER=2;
 else VRAGER=1;
 
 Vulhanden();
 Lkaart=0;
 Skleur=slag[SLAG][0].kleur;
 Skaart=slag[SLAG][0].naam;
 Skleur1=slag[SLAG][1].kleur;
 Skaart1=slag[SLAG][1].naam;
 Skleur2=slag[SLAG][2].kleur;
 Skaart2=slag[SLAG][2].naam;
 Lkleur=Skleur;

 strcpy(kname,khand[0][Skleur]);
 ikarte=iKrt[Skleur][0];
    

if(slag[SLAG][0].troef) strcpy(slagvolgorde,rangtroef);
	       else     strcpy(slagvolgorde,rangnorm);

if(!COMP && VRAGER==1) {humaan(); return;}


if(ikarte==1)    { Lkaart=kname[0];  TACTIEK=38;     return;     }

if(ikarte >1 && Skleur==TROEF)
    {
     i=0; 
     for(n=0;n<SLAGKRTNO;n++)
	 if(slag[SLAG][n].troef) nop[i++]=slag[SLAG][n].naam;
	 nop[i]=0; /* str met troefkaarten */
     if(strpos(rangtroef,Skaart)>strpos(rangtroef,Skaart1) && Skleur1==TROEF)
	     { Skaart=Skaart1; }
     if(strpos(rangtroef,Skaart)>strpos(rangtroef,Skaart2) && Skleur2==TROEF)
	     { Skaart=Skaart2; }
     L8 { if(slagvolgorde[n]!=Skaart) nop1[n]=slagvolgorde[n];
	     else {nop1[n]=0; break;} /* str met hogere troefkaarten */
	}
     i=0;			/* Bereken aantal hogere  */
     for(m=0;m<ikarte;m++)
	{
	 if(strpos(nop1,kname[m])==0) continue;
	 khoger[i++]=kname[m];
	}
     khoger[i]=0;
     aantalhoger=i;
     s=-110;
     j=wie_slag();
     t=strlen(nop);
     nop[t+1]=0;
			    /*Als slag aan vrager en geen hogere */
     if(j==VRAGER+2 && !aantalhoger)
	       { Lkaart=hoogsteroem(TROEF); TACTIEK=17;}
     if(aantalhoger>1) 
	  {
	  for(n=0;n<aantalhoger;n++)
	    {
	     nop[t]=khoger[n];
	     i=bepaalroempunten(nop,TROEF);
	     if(i>=s)  { s=i; j=n;}
	    }
	  Lkaart=khoger[j]; TACTIEK=20; /* Als roem of laagst hogere kaart*/
	  } 
     if(j!=VRAGER+2 &&  !aantalhoger)
	       { Lkaart=laagsteroem(TROEF); TACTIEK=39;}
     Lkleur=TROEF;
     if(aantalhoger==1) {Lkaart=khoger[0]; TACTIEK=30;}
     if(!aantalhoger && Lkaart)/*als geen roem valt geen troef weggooien*/
      { nop[t]=Lkaart;
	if(bepaalroempunten(nop,TROEF)==0) Lkaart=0;
      }
     }
if(!Lkaart) bekijk_beste_slag(slag[SLAG][0].kleur);
}

/*********************** speler 2 *********************/
void  speler2(void)
{
char slagvolgorde[10],nop[10],nop1[10],khoger[10];
int Skleur,Skleur1,m,n,i,j,s,t,aantalhoger;
char Skaart,Skaart1;
char kname[20];
int ikarte;

 if(startvrager==1) VRAGER=3;
 if(startvrager==2) VRAGER=4;
 if(startvrager==3) VRAGER=1;
 if(startvrager==4) VRAGER=2;

 Vulhanden();
 Lkaart=0;
 Skleur=slag[SLAG][0].kleur;
 Skaart=slag[SLAG][0].naam;
 Skleur1=slag[SLAG][1].kleur;
 Skaart1=slag[SLAG][1].naam;
 Lkleur=Skleur;
 if(startvrager>2) {
      strcpy(kname,khand[0][Skleur]);
      ikarte=iKrt[Skleur][0];
    }
 else {
      strcpy(kname,ktafel[0][Skleur]);
      ikarte=iKrt_tafel[Skleur][0];
    }

if(slag[SLAG][0].troef) strcpy(slagvolgorde,rangtroef);
	       else     strcpy(slagvolgorde,rangnorm);

if(!COMP && (VRAGER==1 || VRAGER==3) ) {humaan(); return;}

if(TACTIEKLAAG){
	      Lkaart=LKAART3;
	      Lkleur=LKLEUR3;
	      TACTIEK=6; 
	      TACTIEKLAAG=FALSE; return;}

if(TACTIEK41) /* troef kwijtraken van tafel trekken A of T ts*/
  {
  TACTIEK41=FALSE;
/*   i=999;
    L4 { 
      if(tafel[0][n].kleur==TROEF && i>tafel[0][n].waarde)
	      { i=tafel[0][n].waarde; Lkaart=tafel[0][n].naam; Lkleur=TROEF;}
      }*/
   Lkaart=Skrt41; Lkleur=TROEF;
   TACTIEK=45;
   if(Lkaart) return;
   }

if(TACTIEKTT) /* troef kwijtraken van tafel */
  {
  TACTIEKTT=FALSE;
   i=0;
    L4 { 
      if(tafel[0][n].kleur==TROEF && i<=tafel[0][n].waarde)
	      { i=tafel[0][n].waarde; Lkaart=tafel[0][n].naam; Lkleur=TROEF;}
      }
   TACTIEK=12;
   if(Lkaart) return;
   }

 if(ikarte==1)     { Lkaart=kname[0]; TACTIEK=36;  return;     }
else if(ikarte >1 && Skleur==TROEF)
      {
     if(Skleur==Skleur1)
	 {
	   if(strpos(rangtroef,Skaart)>strpos(rangtroef,Skaart1))
	     { Skaart=Skaart1; }
	  }
	L8 { if(slagvolgorde[n]!=Skaart) nop1[n]=slagvolgorde[n];
	     else {nop1[n]=0; break;}
	   }
	  i=0;			/* Bereken aantal hogere  */
	  for(m=0;m<ikarte;m++)
	   {
	    if(strpos(nop1,kname[m])==0) continue;
	    nop[i++]=kname[m];
	   }
	  nop[i]=0;  /* string met hogere kaarten */
	  strcpy(khoger,nop);
	  aantalhoger=i;
	  s=-110;
	  i=0;
	  for(n=0;n<aantalhoger;n++)
	   {
	    i=bepaal_slagkans(nop[n],TROEF);
	    if(i>=s) {s=i; j=n;}
	   }
       if(aantalhoger==1) {Lkaart=nop[j];TACTIEK=66; return;}
       if(i>50)           {Lkaart=nop[j]; TACTIEK=67; return;}
       s=-100;
     if(aantalhoger) 
	  {
	  i=0; 
	  for(n=0;n<SLAGKRTNO;n++)
	    if(slag[SLAG][n].troef) nop[i++]=slag[SLAG][n].naam;
	    nop[i]=0; /* str met troefkaarten */
	    t=strlen(nop);
	    nop[t+1]=0;
	    i=999;
	    for(n=0;n<aantalhoger;n++)
	     {
	      nop[t]=khoger[n];
	      i=bepaalroempunten(nop,TROEF);
	      if(i>=s)  { s=i; j=n;}
	     }
	  Lkaart=khoger[j]; TACTIEK=37; /* Als roem of laagst hogere kaart*/
	  } 
 }
if(!Lkaart) bekijk_beste_slag(slag[SLAG][0].kleur);

}

/*************************** eindspel *********************/
 void eindspel(void)
 {
/* printf("Eindspel");*/
/* getch();*/

 }

/************************ evalueer *************************/
void  evalueer(void)
{
 int n,i;
/* char st[5],slagvolgorde[9];*/
 int punten=0,Rkleur;
 char sp[5];
 L4 punten+=slag[SLAG][n].waarde;

 startvrager=wie_slag();
 if(startvrager>2) startvrager-=2;
 puntenspel[startvrager-1]+=punten;

 for(Rkleur=0;Rkleur<4;Rkleur++)
  {
  i=0;
   { L4 if(slag[SLAG][n].kleur==Rkleur) sp[i++]=slag[SLAG][n].naam;
     sp[i]=0;
     if(strlen(sp)>1) roem[startvrager-1]+=bepaalroempunten(sp,Rkleur);
   }
  }
  for(n=1;n<4;n++) if(slag[SLAG][0].naam !=slag[SLAG][n].naam) break;
  if(n==4) {vierk[startvrager-1]++; roem[startvrager-1]+=100;}
  if(SLAG==8) roem[startvrager-1]+=10; /*laatste slag*/
if(slag[SLAG][0].kleur != slag[SLAG][3].kleur)
  verzaakt[slag[SLAG][3].speler-1][slag[SLAG][0].kleur]=TRUE;
     /* Als verzaakt */
}


/**************** bekijk_en leg beste_slag(int Skaart,Skleur) ************/
void  bekijk_beste_slag(int Skleur)
{
 int w,m,n,i,j,ii,jj;
 int Rkleur;
 int Kt,Kh,troeff;
 char Skaart=FALSE;
 char slagstring[5],slagvolgorde[9],troefstring[5];
 char Roem[5]={0,0,0,0,0};
 troeff=0; /* niet ingetroeft*/

if(slag[SLAG][0].troef) strcpy(slagvolgorde,rangtroef);
	       else     strcpy(slagvolgorde,rangnorm);
i=0;
for(n=0;n<=SLAGKRTNO;n++)
   if(slag[SLAG][n].troef)       troefstring[i++]=slag[SLAG][n].naam;
   troefstring[i]=0;

i=0;
if(!slag[SLAG][0].troef)
for(n=1;n<=SLAGKRTNO;n++)
     { if(slag[SLAG][n].troef) troeff=TRUE;} /*ingetroeft*/
 Kh=Kt=0;

 i=0;     
 L4 { if (slag[SLAG][n].kleur==Skleur) slagstring[i++]=slag[SLAG][n].naam;}
   slagstring[i]=0;

 if(SLAGKRTNO==1) /* tweede kaart */
   {
    i=-50;
    ii=-50;
    
    if(iKrt_tafel[Skleur][0])
     {
      L4 { if(tafel[0][n].kleur==Skleur && ii<tafel[0][n].slagkans)
		 { ii=tafel[0][n].slagkans; Kt=n; }
     }   }
     if(ii > SLAGKANSLEVEL)  {Skaart=tafel[0][Kt].naam; TACTIEK=16;}
    }

 if(SLAGKRTNO==2 )   /* derde kaart */
   {
    i=-50;
    ii=-50;
    if(VRAGER>2 && iKrt_tafel[Skleur][0])
      {
      L4{ if(tafel[0][n].kleur==Skleur)
	  {
	   if(ii<tafel[0][n].slagkans)
	      { ii=tafel[0][n].slagkans; Kt=n; }
	  }
	}    
       if(ii > 1 * slag[SLAG][0].kans && ii > SLAGKANSLEVEL)
				 {TACTIEK=21;
				  Skaart=tafel[0][Kt].naam;}
   if(!Skaart) 
	  {
	   if(wie_slag()==VRAGER-2 && slag[SLAG][0].kans >SLAGKANSLEVEL )
	      {  TACTIEK=22;   Skaart=hoogsteroem(Skleur);}
	  }
      }
    if(VRAGER<3 && iKrt[Skleur][0])
      {
     L8 {if(hand[0][n].kleur==Skleur)
	   { 
	     if(i<hand[0][n].slagkans)
	       { i=hand[0][n].slagkans; Kh=n; }
	   }
	 }
       if(i > 1 * slag[SLAG][0].kans && i > SLAGKANSLEVEL) {
	       Skaart=hand[0][Kh].naam; TACTIEK=49;}
     if(!Skaart){ 
	     if(wie_slag()==VRAGER+2 && slag[SLAG][0].kans >SLAGKANSLEVEL)
	      {  TACTIEK=4;  Skaart=hoogsteroem(Skleur);}
     if(!Skaart)   {  TACTIEK=23;
		      Skaart=laagsteroem(Skleur);
		      if(Skaart=='T') Skaart=0;}
	}  
      }
   }

 if(SLAGKRTNO==3 )   /* laatste kaart */
   {  /* Als vrager de slag kan halen dan met hoogste roem*/
    i=0;
    ii=-50;
    for(n=0;n<5;n++) Roem[n]=0;
    if(wie_slag()==VRAGER+2) /* als slag aan speler */
      {
     for(n=0;n<SLAGKRTNO;n++) /* kijk of er roem valt te halen */
      {
      if(slag[SLAG][n].kleur==Skleur)
      Roem[strlen(Roem)]=slag[SLAG][n].naam;/*plak die in gespeelde krtstring*/
      }
      j=strlen(Roem);
      L8 {if(hand[0][n].kleur==Skleur)
	   {Roem[j]=hand[0][n].naam;
	    ii=bepaalroempunten(Roem,Skleur);
	    if(ii >i )
	      {i=ii;
	       TACTIEK=24;
	       Skaart=hand[0][n].naam;
	 }    } }
       
   if(!Skaart )
     {
    i=ii=0;
    for(n=0;n<5;n++) Roem[n]=0;
    for(n=0;n<SLAGKRTNO;n++) /* kijk of er roem valt te halen met hogere*/
      {
      if(slag[SLAG][n].kleur==Skleur)
      Roem[strlen(Roem)]=slag[SLAG][n].naam;/*plak die in gespeelde krtstring*/
      }
      j=strlen(Roem);
      L8 {if(hand[0][n].kleur==Skleur && 
		  hogere(hand[0][n].naam,slagstring,slagvolgorde)==0)
	   {Roem[j]=hand[0][n].naam;
	    ii=bepaalroempunten(Roem,Skleur);
	    if(ii >i )
	      {i=ii;
	       TACTIEK=48;
	       Skaart=hand[0][n].naam;
	 }    } }
      }
       }
  if(!Skaart && !troeff) {  /* kijk of er een hogere kaart is */
     L8 {if(hand[0][n].kleur==Skleur && Skleur!=TROEF)
	  {if(hogere(hand[0][n].naam,slagstring,slagvolgorde)==0)
	   {Skaart=hand[0][n].naam;
	    TACTIEK=46;
	}}}}

      if(!Skaart) {Skaart=laagsteroem(Skleur); TACTIEK=3;}

   }
if(!Skaart)
{
if(VRAGER<3) i=iKrt[Skleur][0]; else i=iKrt_tafel[Skleur][0];
if(!i)  /* Als niet kan bekennen */
{

/* als slag aan vrager en met zwakke getroeft hoger troeven */
if(!Skaart && SLAGKRTNO>1) 
    {if (VRAGER>2) j=VRAGER-2; else j=VRAGER;
     m=wie_slag(); 
     if(m>2) m-=2;
      if(j==m)     /* Als slag aan vrager */
      { if(slag[SLAG][SLAGKRTNO-2].kans< SLAGKANSLEVEL)
/*      && slag[SLAG][SLAGKRTNO-2].waarde>8) als een vrij kleine kans op winst*/
   {if(VRAGER>2 && iKrt_tafel[TROEF][0]) /*als geen kleur en wel troef */
      {
      i=1000;
      L4{ if(tafel[0][n].kleur==TROEF)
	{if(troeff)
	  {if(hogere(tafel[0][n].naam,troefstring,rangtroef)==0)
	    {if(tafel[0][n].slagkans<i)
	      { i=tafel[0][n].slagkans;
		Skaart=tafel[0][n].naam;
		Skleur=TROEF;
		TACTIEK=26;
	      }}}}}}
   if(VRAGER<3 && iKrt[TROEF][0]) /*als geen kleur en wel troef */
      {
      i=1000;
      L8{ if(hand[0][n].kleur==TROEF)
	{if(troeff)
	  {if(hogere(hand[0][n].naam,troefstring,rangtroef)==0)
	  { if(hand[0][n].slagkans<i)
	      { i=hand[0][n].slagkans;
		Skaart=hand[0][n].naam;
		Skleur=TROEF;
		TACTIEK=27;
	      }}}}}}
   }/* als slagkans SLAGKANSLEVEL */
  } /* if j==m */

else       /* als slag aan tegenpartij hoger overtroeven als mogelijk */
   {if(VRAGER>2 && iKrt_tafel[TROEF][0]) 
      {
      i=1000;
      L4{ if(tafel[0][n].kleur==TROEF)
	{  /*if(troeff)*/
	  {if(hogere(tafel[0][n].naam,troefstring,rangtroef)==0)
	    {if(tafel[0][n].slagkans && tafel[0][n].waarde<i)
	      { i=tafel[0][n].waarde;
		Skaart=tafel[0][n].naam;
		Skleur=TROEF;
		TACTIEK=28;
	      }}}}}}
   if(VRAGER<3 && iKrt[TROEF][0]) /*als geen kleur en wel troef */
      {
      i=1000;
      L8{ if(hand[0][n].kleur==TROEF)
	{  /*if(troeff)*/
	  {if(hogere(hand[0][n].naam,troefstring,rangtroef)==0)
	  { if(hand[0][n].slagkans && hand[0][n].waarde<i )
	      { i=hand[0][n].waarde;
		Skaart=hand[0][n].naam;
		TACTIEK=29;
		Skleur=TROEF;
	      }}}}}}
   }                         /*einde else */  
  }                          /* einde skaart slagkrtno>2 */

if(!Skaart && SLAGKRTNO<2)
 {
   {if(VRAGER>2 && iKrt_tafel[TROEF][0]) /*als geen kleur en wel troef */
      {
      i=1000;
      L4{ if(tafel[0][n].kleur==TROEF)
	  {m=tafel[0][n].slagkans;
	   if(i<m && i)
	      { i=tafel[0][n].slagkans;
		Skaart=tafel[0][n].naam;
		Skleur=TROEF;
	       TACTIEK=30;
	      }}}}
   if(VRAGER<3 && iKrt[TROEF][0]) /*als geen kleur en wel troef */
      {      /* overbodig ?*/
      i=1000;
      L8{ if(hand[0][n].kleur==TROEF)
	  { m=hand[0][n].slagkans;
	    if(i<m &&i)
	      { i=hand[0][n].slagkans;
		Skaart=hand[0][n].naam;
		Skleur=TROEF;
	       TACTIEK=31;
	      }}}}
    }}} /* einde als niet kan bekennen */
  } /* einde !Skaart*/

if(Skaart && !slag[SLAG][0].troef)
 {
 for(n=1;n<SLAGKRTNO;n++)
   { if (slag[SLAG][n].troef)
       {
	if(strpos(rangtroef,slag[SLAG][n].naam) < strpos(rangtroef,Skaart))
	{  Skaart=0; tac[59]++; TACTIEK=59;}
	}}  /* controle als ingetroeft en niet kan overtroeven*/
 }


if(!Skaart)   {
    L32	{ if(kaart[n].DichtIkHy==VRAGER && kaart[n].kleur==Skleur &&!Skaart)
	    {
	     ii=i=wie_slag();
	     if(ii>2) ii-=2;
	     j=VRAGER;
	     if(j>2) j-=2;
	     if(ii==j) /* Als speler slag heeft */
	       {
	      for(m=0;m<SLAGKRTNO;m++) /* als slagkans >0.5*/
	       if(slag[SLAG][m].speler==i && slag[SLAG][m].kans>50)
		           {TACTIEK=43;    Skaart=hoogsteroem(Skleur);}
	       if(!Skaart) {TACTIEK=32;    Skaart=laagsteroem(Skleur);}
            }}}}

if(!Skaart) { /* Als niet kan bekennen */

 ii=i=wie_slag();
 if(ii>2) ii-=2;
 j=VRAGER;
 if(j>2) j-=2;
 if(ii==j) /* Als speler slag heeft */
   {
    for(m=0;m<SLAGKRTNO;m++) /* als slagkans >0.75*/
      if(slag[SLAG][m].speler==i && slag[SLAG][m].kans>50)
	 {
	  if(VRAGER<3)  /* Als hand*/
	   {for(jj=0;jj<8;jj++)
	    if(hand[0][jj].naam=='T' && iKrt[hand[0][jj].kleur][0]==1) 
	      {if(strpos(ktafel[0][hand[0][jj].kleur],'A')==0) 
		{                                /* geen aas op tafel*/
		 if(hogere('T',Krt_vrij[hand[0][jj].kleur],slagvolgorde))
		    {                           /*Als nog hogere in spel*/
		       Skaart=hand[0][jj].naam;
		       Skleur=hand[0][jj].kleur;
		       TACTIEK=51;
	     }} } 
	if(!Skaart)/*slag aan vrager, gooi hoogste rommel bij*/
	  {w=-1;
	   for(jj=0;jj<8;jj++)
	    if(hand[0][jj].waarde>w &&
	       hand[0][jj].slagkans0<SLAGKANSLEVEL+10 &&
	       hand[0][jj].kleur!=TROEF &&
	       hand[0][jj].naam!='A') 
	       {w=hand[0][jj].waarde;
		Skaart=hand[0][jj].naam;      /*INBOUWEN SLAGKANS0 <30*/
		Skleur=hand[0][jj].kleur;
		TACTIEK=68;
	       }}

	} /*einde als hand & tafelslagkans >75*/
	    else
	     {for(jj=0;jj<4;jj++)
		if(tafel[0][jj].naam=='T' && iKrt[tafel[0][jj].kleur][0]==1) 
	      {if(strpos(khand[0][tafel[0][jj].kleur],'A')==0) 
		{                               /* geen aas in de hand */
		 if(hogere('T',Krt_vrij[tafel[0][jj].kleur],slagvolgorde))
		    {                           /*Als nog hogere in spel*/
		      Skaart=tafel[0][jj].naam;
		      Skleur=tafel[0][jj].kleur;
		      TACTIEK=52;
	     }}}
	if(!Skaart)/*slag aan vrager, gooi hoogste rommel bij*/
	  {w=-1;
	   for(jj=0;jj<4;jj++)
	    if(tafel[0][jj].waarde>w &&
	       tafel[0][jj].slagkans0<SLAGKANSLEVEL+10 &&
	       tafel[0][jj].kleur!=TROEF&&
	       tafel[0][jj].naam!='A') 
	       {w=tafel[0][jj].waarde;
		Skaart=tafel[0][jj].naam;
		Skleur=tafel[0][jj].kleur;
		TACTIEK=69;
	       }}

	     }/*einde else*/
	  }/* einde slagkans >75*/

     if(!Skaart)
	{if(VRAGER<3 && iKrt[TROEF][0] && SLAGKRTNO==2)  /* Als hand*/
	  {m=999;
	   L8 {if(hand[0][n].troef && hand[0][n].slagkans>20)
		 {if(m>hand[0][n].slagkans) {m=hand[0][n].slagkans;
	/* als troefslagkans*/             Skaart=hand[0][n].naam;
					   Rkleur=TROEF;
					  }
	      }  }
	  if(Skaart)
          {
	  m=0;
	  strcpy(Roem,slagstring);
	  Roem[strlen(slagstring)+1]=0;
	  if(kans_kaart(Rkleur,1,VRAGER)>0.3)
	    {for(n=0;n<strlen(Krt_dicht[Skleur]);n++)
				    /* bepaal roemkans in dichte*/
		{Roem[strlen(slagstring)]=Krt_dicht[Skleur][n];
		 i=bepaalroempunten(Roem,Skleur);
		 if(i>m)  m=i; 
	    }	}  }
       if(m==0) Skaart=0;    /* Als geen roem valt niet troeven */
       else {TACTIEK=60; Skleur=TROEF;}
	    }
	} /* einde !Skaart */

     if(!Skaart)
	{if(VRAGER>2 && iKrt[TROEF][0] && SLAGKRTNO==2)  /* Als tafel*/
	  {m=999;
	   L8 {if(tafel[0][n].troef && tafel[0][n].slagkans>20)
		 {if(m>tafel[0][n].slagkans) {m=tafel[0][n].slagkans;
	/* als troefslagkans*/             Skaart=tafel[0][n].naam;
					   Rkleur=TROEF;
					  }
	      }  }
	  if(Skaart)
	  {m=0;
	  strcpy(Roem,slagstring);
	  Roem[strlen(slagstring)+1]=0;
	  if(kans_kaart(Rkleur,1,VRAGER)>0.30)
	    {for(n=0;n<strlen(Krt_dicht[Skleur]);n++) /* bepaal roemkans in dichte*/
		{Roem[strlen(slagstring)]=Krt_dicht[Skleur][n];
		 i=bepaalroempunten(Roem,Skleur);
		 if(i>m)  m=i; 
	    }	} }
       if(m==0) Skaart=0;         /* Als geen roem valt niet troeven */
       else {TACTIEK=25; Skleur=TROEF;}
	    }	}     } 	
  }/* einde !Skaart */

if(!Skaart) 
  {     /* laagste roem van die kleur bijgooien*/
   for(n=8*Skleur;n<8*(Skleur+1);n++)
	 if(kaart[n].DichtIkHy==VRAGER ) 
		    { Skaart=laagsteroem(Skleur);  TACTIEK=34;}
   }

if(!Skaart && Skleur !=TROEF)   { /* laagste van die kleur geen troef */
    m=99;            /*overbodig?*/
   for(n=8*Skleur;n<8*(Skleur+1);n++)
	{ if(kaart[n].DichtIkHy==VRAGER)
	    {i=kaart[n].actwaarde;    
	     if(i<m) {m=i; Skaart=kaart[n].naam;  TACTIEK=33;}
	    }}}
  
if(!Skaart && troeff){ /*bijgooien hogere troef als ingetroeft*/
 if((VRAGER<3 && !iKrt[Skleur][0]) || (VRAGER>2 && !iKrt_tafel[Skleur][0]))
  {  ii=i=wie_slag();
    if(ii>2) ii-=2;
    j=VRAGER;
    if(j>2) j-=2;
    if(ii!=j) /* Als speler niet de slag heeft */
   { i=9;             
    for(m=0;m<strlen(troefstring);m++)
    if(strpos(rangtroef,troefstring[m])<i)
	       i=strpos(rangtroef,troefstring[m]); /*hoogste*/
    m=99; j=99;
   for(n=8*(TROEF+1)-1;n>=8*TROEF;n--)
	if(kaart[n].DichtIkHy==VRAGER && strpos(rangtroef,kaart[n].naam)<i)
	   j=n;
	
    if(j<33){  Skaart=kaart[j].naam;
	       Skleur=kaart[j].kleur; TACTIEK=64; }
   } }}

if(!Skaart && !troeff){ /*bijgooien laagste troef als geen kleur*/
 if((VRAGER<3 && !iKrt[Skleur][0]) || (VRAGER>2 && !iKrt_tafel[Skleur][0]))
  { ii=i=wie_slag();
    if(ii>2) ii-=2;
    j=VRAGER;
    if(j>2) j-=2;
    if(ii!=j) /* Als speler niet de slag heeft */
    {m=99;
    for(n=8*TROEF;n<8*(TROEF+1);n++)
	{ if(kaart[n].DichtIkHy==VRAGER) 
	    {i=kaart[n].actwaarde;
	     if(i<=m) {m=i; Skaart=kaart[n].naam;
			    Skleur=TROEF; TACTIEK=65; }
     }	    }}}}

if(!Skaart)   {
   ii=i=wie_slag();
    if(ii>2) ii-=2;
    j=VRAGER;
    if(j>2) j-=2;
    if(ii<10) /* Als speler de slag heeft */
    { m=0;
      j=SLAGKRTNO;
      SLAGKRTNO=0;
      SLAG++;
      Vulhanden();
      L32 { if(kaart[n].DichtIkHy==VRAGER && kaart[n].kleur!=TROEF )
	    {
	     i=bepaal_laagsteroem(kaart[n].kleur,kaart[n].naam);
	     if(i>m && kaart[n].actwaarde<5 &&
                bepaal_slagkans(kaart[n].naam,kaart[n].kleur)<10)
              {
            w=FALSE;
	   for(jj=0;jj<8;jj++) { if(w) break;
	     if(hand[0][jj].slagkans0>SLAGKANSLEVEL &&
	        hand[0][jj].kleur==kaart[n].kleur)      w=TRUE;}

	   for(jj=0;jj<4;jj++) {if(w) break;
	     if(tafel[0][jj].slagkans0>SLAGKANSLEVEL &&
	        tafel[0][jj].kleur==kaart[n].kleur)     w=TRUE;}
             if(w) {
              m=i; Skaart=kaart[n].naam;
	           Skleur=kaart[n].kleur; TACTIEK=72;}
	    }}}
      SLAGKRTNO=j;
      SLAG--;
      Vulhanden();
    }
 }

/*
if(!Skaart)   {
    m=99;
    j=SLAGKRTNO;
    SLAGKRTNO=0;
    Vulhanden();
    L32	{ if(kaart[n].DichtIkHy==VRAGER && kaart[n].kleur!=TROEF )
	    {
	     i=kaart[n].actwaarde;
	     if(i<=m && kaart[n].actwaarde>0 && kaart[n].actwaarde<5 )
              {m=i; Skaart=kaart[n].naam;
	       Skleur=kaart[n].kleur; TACTIEK=71;}
	    }}
    SLAGKRTNO=j;
    Vulhanden();
          }
*/
if(!Skaart)   {
    m=99;
    L32	{ if(kaart[n].DichtIkHy==VRAGER && kaart[n].kleur!=TROEF ) 
	    {
	     i=kaart[n].actwaarde;
	     if(i<=m) {m=i; Skaart=kaart[n].naam;
	     Skleur=kaart[n].kleur; TACTIEK=53;}
	    }}}



if(!Skaart)   { /* Gooi maar wat */
    m=99;
    L32	{ if(kaart[n].DichtIkHy==VRAGER) 
	    {
	     i=kaart[n].actwaarde;
	     if(i<=m) {m=i; Skaart=kaart[n].naam;
	     Skleur=kaart[n].kleur; TACTIEK=35;}
	    }}}
  
Lkaart=Skaart;
Lkleur=Skleur;
VRAGER=wie_vrager(Lkaart,Lkleur);
 }
