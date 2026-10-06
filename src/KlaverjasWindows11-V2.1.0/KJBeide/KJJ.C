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
#include "kjrljas.h"

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
extern void kjlegkaart(char h,int n,int w,int e,struct hand *d);
extern char kjuitkom0(char h,struct hand *d);
extern void kjuitkom1(char h,struct hand *d);
extern void kjuitkom2(char h,struct hand *d);
extern void kjuitkom3(char h,struct hand *d);



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
              int dpos;
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
extern double fact[19];
extern int TACTIEK,TACTIEK41,TACTIEKLAAG;
extern char text[80];

/*extern char klaver[15][15];
extern char schoppen[15][15];
extern char ruiten[15][15];
extern char harten[15][15];
extern char inputline[50][55];
extern unsigned int tac[76];*/

extern unsigned short Mpresent;
extern long Kaartpnt[2];
extern long     Tpnt[2];
extern long Troefpnt[2];
extern long Gewonnen[2];
extern long Roempnt[2];
extern long Troefkrt[2];
extern long Pit[2];
extern long Tpit[2];
extern long  Nat[2];
extern int vierk[2];

extern struct dek *s;
extern struct hand *i;
extern struct hand *h;
extern struct kljas kj;
extern char reg[81];
extern char rljas;		 /* 0=human
				    1=single step
				    2=test */
extern char kjnivo;

int SDEMO;
/************************************************************************/
void  Sputimage(int x,int y,void far * nr,int c)
{if(!SDEMO) putimage(x,y,nr,c);
}

/***********************  Delen *********************/
void Delen()
{
 int n,card;
 int pntwaarde[8] = {11,4,3,2,10,0,0};
 int troevwaarde[8] = { 11,4,3,20,10,14,0,0};
 int wie=1;
 int m=32;
 int x1;
 x1=0;

 L32 deeltabel[n]=n;

  n=1;
 for(m=31;m>=0;m--)
  {
   card = random(m);
   kaart[deeltabel[card]].DichtIkHy=wie;
   deeltabel[card] = deeltabel[m];
   if(n==8)  {wie=2;   x1=0;}
   if(n==16) {wie=3;   x1=0;}
   if(n==20) {wie=4;   x1=0;}
   if(n==24) {wie=33;  x1=0;}
   if(n==28) {wie=44;  x1=0;}
   n++;
  }
 x1=0;
 L32 if(kaart[n].DichtIkHy==1) kaart[n].dpos=x1++;
 x1=0;
 L32 if(kaart[n].DichtIkHy==2) kaart[n].dpos=x1++;
 x1=0;
 L32 if(kaart[n].DichtIkHy==3) kaart[n].dpos=x1++;
 x1=0;
 L32 if(kaart[n].DichtIkHy==4) kaart[n].dpos=x1++;
 x1=0;
 L32 if(kaart[n].DichtIkHy==33) kaart[n].dpos=x1++;
 x1=0;
 L32 if(kaart[n].DichtIkHy==44) kaart[n].dpos=x1++;


 L32
   {
    kaart[n].naam=rangroem[n%8];
    kaart[n].puntwaarde=pntwaarde[n%8];
    kaart[n].troefwaarde=troevwaarde[n%8];
    kaart[n].kleur=n/8;
   }


  for(n=1;n<9;n++) {
       for(m=0;m<4;m++)
	 {
	  slag[n][m].kleur =9;
	  slag[n][m].naam  =0;
	  slag[n][m].troef =0;
	  slag[n][m].speler=998;
	  slag[n][m].kans  =-100;
	  slag[n][m].waarde=-100;
	  slag[n][m].tactiek=255;
	 }
       }
 }
/********************** vul handen ******************/
void Vulhanden(void)
{
 int i,n;
 int twie,wie,status,troefstatus;
 int mm[5];
 int vraagkant;
 kaarten_vrij();

 for(wie=0;wie<2;wie++)
   {
   L8 {
       hand[wie][n].naam       = 0;
       hand[wie][n].kleur      = 5;
       hand[wie][n].waarde     = 0;
       hand[wie][n].troef      = 0;
       hand[wie][n].slagkans   = -100;
if(SLAGKRTNO==0)       hand[wie][n].slagkans0  = -100;
       tafel[wie][n].naam      = 0;
       tafel[wie][n].kleur     = 5;
       tafel[wie][n].waarde    = 5;
       tafel[wie][n].troef     = 0;
       tafel[wie][n].slagkans  =-100;
if(SLAGKRTNO==0)       tafel[wie][n].slagkans0 =-100;
    }
   }

 mm[0]=mm[1]=mm[2]=mm[3]=mm[4]=0;

 if(VRAGER == 1 || VRAGER == 3) vraagkant=1; else vraagkant=2;

 L32
   {
    status=kaart[n].DichtIkHy;

    if(kaart[n].DichtIkHy==5) continue;
    if(kaart[n].DichtIkHy==0) continue;

    if(TROEF==n/8) troefstatus=1; else troefstatus=0;
    if(status>30)   continue;
    kaart[n].troef=troefstatus;
    if(status==vraagkant )   wie=1; else wie=2;
    if(status==vraagkant+2 && status >2) wie=3;
      else if (status>2) wie=4;

   if(wie<3)
      {
       hand[wie-1][mm[wie]].naam    = kaart[n].naam;
       hand[wie-1][mm[wie]].kleur   = kaart[n].kleur;
       hand[wie-1][mm[wie]].waarde  = kaart[n].actwaarde;
       hand[wie-1][mm[wie]++].troef = troefstatus;
      }
    else
      {
       if(wie>2 && wie<5)
	 {
	  twie =wie-2;
	 }
       tafel[twie-1][mm[wie]].naam    = kaart[n].naam;
       tafel[twie-1][mm[wie]].kleur   = kaart[n].kleur;
       tafel[twie-1][mm[wie]].waarde  = kaart[n].actwaarde;
       tafel[twie-1][mm[wie]++].troef = troefstatus;
      }
    }
if(!SDEMO){  if(MaxY<351)  setviewport(300,MaxY,450,MaxY,0);
             else          setviewport(300,360,450,MaxY,0);
             clearviewport();
             setviewport(0,0,MaxX,MaxY,0);
             setcolor(WHITE);
          }
i=0;
       L8
	{
	 hand[0][n].slagkans =
	   bepaal_slagkans(hand[0][n].naam,hand[0][n].kleur);
if(SLAGKRTNO==0)	 hand[0][n].slagkans0 = hand[0][n].slagkans;
if(!SDEMO){
if(DEMO && MaxY>350){
sprintf(text,"%8s %c %3d%",KLEUR[hand[0][n].kleur],hand[0][n].naam,hand[0][n].slagkans);
 outtextxy(300,360+ i++*10,text);}
          }
	 if(hand[0][n].slagkans > 95) hand[0][n].gegarandeerd =1;
	 else hand[0][n].gegarandeerd =0;
	}
       L4
	{
	 tafel[0][n].slagkans =
	  bepaal_slagkans(tafel[0][n].naam,tafel[0][n].kleur);
if(SLAGKRTNO==0)	 tafel[0][n].slagkans0 = tafel[0][n].slagkans;
if(!SDEMO){
if(DEMO && MaxY>350){
sprintf(text,"%8s %c %3d%",KLEUR[tafel[0][n].kleur],tafel[0][n].naam,tafel[0][n].slagkans);
 outtextxy(300,360+ i++*10,text);}
          }
	 if(tafel[0][n].slagkans > 95) tafel[0][n].gegarandeerd =1;
	 else tafel[0][n].gegarandeerd =0;
	 
	}
}


/*************** Guillermie *************************/

double guillermie(int a,int h,int z,int x,int s)
{
/*
 a = tot kaarten dicht
 h = tot kaarten in hand
 z = hoeveel kaarten van die kleur nog aanwezig
 x = hoeveel kaarten wil je weten van die kleur
 s = hoeveel specifieke kaarten (cq een AAS) wil je weten

 hPx * (a-h)P(a-h)*z * (h-x)! * (a-z)C(h-x) * (x-s+(z-x))C(x-s) / a!

 aPb = a!/(a-b)!   aCb = a!/(b!*(a-b)!

 hieruit volgt:

       (  (h!*(a-h)!*(a-z)!*(z-s)!         )  /
       {-----------------------------------}          
       (  (h-x)!*(a-z-h+x)!*(x-s)!*(z-x)!) )  /
   ---------------------------------------------------        
			a!
*/
double aa,bb,cc;
if(h-x<0) 
     return(1.0);
if(a-h<0) 
    return(1.0);
if(a-z<=0)         return(1.0);
if(z-s<0)     s=z;
if(x-s<0)     s=x;
if(z-x<0)          return(0.0);
if((a-z)-(h-x) <0) return(1.0);

aa=fact[h]*fact[a-h]/fact[h-x]*fact[a-z]*fact[z-s];
bb=fact[(a-z)-(h-x)]*fact[x-s]*fact[z-x];
cc=fact[a];

if(aa==0)   { return(0.0);} /*fout */
if(bb==0)   { return(1.0);} /*fout */
if(cc==0)   { return(1.0);} /*fout */

return((double)(aa/bb)/cc);

/*
return((double) (
	  (fact[h]*fact[a-h]/fact[h-x]*fact[a-z]*fact[z-s]) /
	  (fact[(a-z)-(h-x)]*fact[x-s]*fact[z-x])  
	)/fact[a]
      );
*/
}

/***************** kans hoger cq kaart ********************/
double kans_hoger(int kaartenhoger,int kleur,int specifiek,int vrager)
{
 int a,h,z,x,s,ts;
 double res;
 if(vrager>2) vrager-=2;
 if(verzaakt[vrager-1][kleur]) return(0);
 if(strlen(Krt_vrij[kleur])==0) return(0);
 ts = 1;
 a = (int)strlen(Krt_totdicht);
 h = (int)(iKrt[0][ts] + iKrt[1][ts]
   + iKrt[2][ts] + iKrt[3][ts]); /*aantal krten ts in hand*/
 x = kaartenhoger;
 s = specifiek;
 z = strlen(Krt_dicht[kleur]);
 if(!z) return(0);
 if(!x) return(0);
 res=guillermie(a,h,z,x,s)*fact[x];
 if(res>1.0) res =1.0;
 return(res);

/* return(guillermie(a,h,z,x,s));*/
}


double kans_kaart(int kleur,int specifiek,int vrager)
{
 int a,h,z,x,s,ts;
 double res;
 if(specifiek) specifiek=1;
 if(vrager>2) vrager-=2;
 if(verzaakt[vrager-1][kleur]) return(0);
 if(strlen(Krt_vrij[kleur])==0) return(0);
 ts = 1;
 a = strlen(Krt_totdicht);
 h = iKrt[0][ts] + iKrt[1][ts]
   + iKrt[2][ts] + iKrt[3][ts]; /*aantal krten ts in hand*/
 x = 1;
 s = 0;
 z = strlen(Krt_dicht[kleur]);

 if(!z) return(0);
/* res=(double)(((double)h/(double)a)*(double)z);*/
 res=guillermie(a,h,z,x,s)*fact[z];
 if(res>1.0) res =1.0;
 return(res);

/* return(guillermie(a,h,z,x,s));*/
}
/************** kaarten vrij **********************/
void kaarten_vrij()
{
 char nop[40],vrij[40],weg[40],dicht[40];
 int m,n,o,p,i,stat,wie,x,y,kolor;
 int q[5],vragert;

 L4
  {
   iKrt[n][0]=0;
   iKrt[n][1]=0;
   iKrt_tafel[n][0]=0;
   iKrt_tafel[n][1]=0;
   khand[0][n][0]=0;
   khand[1][n][0]=0;
   ktafel[0][n][0]=0;
   ktafel[1][n][0]=0;
  }
 vragert=VRAGER;
 if(vragert>2) vragert-=2;

 Krt_totvrij[0]= Krt_totdicht[0]= Krt_totweg[0]=iKrt_gespeeld=0;
 n=-1;
 for(x=0;x<4;x++)
  {
   m=o=p=0;
   q[1]=q[2]=q[3]=q[4]=0;  
   for(y=0;y<8;y++)
   {
    n++;
    stat = kaart[n].DichtIkHy;
    i    = kaart[n].kleur;
    wie = 1;
    if(stat   == vragert)  wie = 0;
    if(stat-2 == vragert)  wie = 0;

    if(stat == 1) { 
		   iKrt[i][wie]++;
		   khand[wie][i][q[1]++]=kaart[n].naam;
		   khand[wie][i][q[1]]=0;
		   if(stat !=vragert) Krt_dicht[i][p++] = kaart[n].naam;
		  }
    if(stat == 2) { 
		   iKrt[i][wie]++;
		   khand[wie][i][q[2]++]=kaart[n].naam;
		   khand[wie][i][q[2]]=0;
		   if(stat !=vragert) Krt_dicht[i][p++] = kaart[n].naam;
		  }


    if(stat == 3) {
		   iKrt_tafel[i][wie]++;
		   ktafel[wie][i][q[3]++]=kaart[n].naam;
		   ktafel[wie][i][q[3]]=0;
		  }

    if(stat == 4) {
		   iKrt_tafel[i][wie]++;
		   ktafel[wie][i][q[4]++]=kaart[n].naam;
		   ktafel[wie][i][q[4]]=0;
		  }

    if(stat != 5) Krt_vrij[i][m++] = kaart[n].naam;      /* 5 = gespeeld */
    if(stat == 5) {
		   Krt_weg[i][o++] = kaart[n].naam;      /* 5 = gespeeld */
		   iKrt_gespeeld++;
		  }
    if(stat == 0) Krt_dicht[i][p++] = kaart[n].naam;   /* 0 = dicht */

		  
   if(stat == 33) Krt_dicht[i][p++] = kaart[n].naam;
   if(stat == 44) Krt_dicht[i][p++] = kaart[n].naam;
   if(stat == 13) Krt_dicht[i][p++] = kaart[n].naam;
   if(stat == 14) Krt_dicht[i][p++] = kaart[n].naam;
   }
  Krt_vrij[i][m] = 0;
  Krt_weg[i][o]  = 0;
  Krt_dicht[i][p]= 0;		    
  } 

  for(kolor=0;kolor<4;kolor++)
   {
    if(kolor==TROEF)                      /* sorteer op troefvolgorde */
	  strcpy(nop,rangtroef);
    else  strcpy(nop,rangnorm);

    m=o=p=0;

    L8 {
	x=(int)nop[n];
	if(strpos(Krt_vrij[kolor] ,x))      vrij[m++] =nop[n];
	if(strpos(Krt_weg[kolor]  ,x))      weg[o++]  =nop[n];
	if(strpos(Krt_dicht[kolor],x))      dicht[p++]=nop[n];
       }
    vrij[m] = 0;
    weg[o]  = 0;
    dicht[p]= 0;
   
    strcpy(Krt_vrij[kolor],vrij);
    strcpy(Krt_weg[kolor],weg);
    strcpy(Krt_dicht[kolor],dicht);
    strcat(Krt_totvrij,vrij);
    strcat(Krt_totweg,weg);
    strcat(Krt_totdicht,dicht);

   }
}

/***************************** string compare ***********************/
int strpos(const char *s, char x)
{
 char *ptr;
 ptr=strchr(s,x);
 if(ptr) return((int)((char*)ptr-(char*)s)+1);
 else return(0);
}
/************************* wie vrager ?  ********************/
int wie_vrager(char karte,int kleur)
{
 int n;
 for(n=8*kleur;n<(1+kleur)*8;n++)
    if(kaart[n].naam==karte) return(kaart[n].DichtIkHy);
return(-1);
}       
/********************* Initialize *********************/
void Initialize(void)
{
  if (registerbgidriver(Herc_driver)   < 0) exit(-1);
  if (registerbgidriver(EGAVGA_driver) < 0) exit(-1);
  if (registerbgidriver(CGA_driver)    < 0) exit(-1);
  GraphDriver = DETECT;			/* Request auto-detection	*/
  if(ZW)
  {
  GraphDriver=MCGA;
  GraphMode=MCGAHI;
  }
  initgraph( &GraphDriver, &GraphMode,"");
  ErrorCode = graphresult();		/* Read result of initialization*/
  if( ErrorCode != grOk ){		/* Error occured during init	*/
    printf(" Graphics System Error: %s\n", grapherrormsg( ErrorCode ) );
    exit( 1 );
  }
  if(GraphDriver==HERCMONO && Mpresent) poke(0x0040,0x0049,6); 
  MaxColors = getmaxcolor() + 1;	/* Read maximum number of colors*/
  MaxX = getmaxx();
  MaxY = getmaxy(); /* Read size of screen		*/
}


/***************  legtafel ***********************/
void leg_tafel(void)
{
int arr[10];
int n,i,j;

 L8 arr[n]=n;
 i=0;    
 j=0;
 L32 { 
   if (kaart[n].DichtIkHy==1)
     {j++;
      kaart[n].posx=560-i*55;
      kaart[n].posy=275;
     Sputimage(560-i++*55,275,krt[n],COPY_PUT);
     }
 }
/* if(j!=8) error_legkaart();*/
 j=0;
 i=0;
 L32 { 
   if (kaart[n].DichtIkHy==2)
   {  j++;
      kaart[n].posx=560-i*40;
      kaart[n].posy=1;
    if(DICHT==1)       Sputimage(560-i++*40,1,krt[32],COPY_PUT);
    else               Sputimage(560-i++*40,1,krt[n],COPY_PUT);
   }
 } 
/* if(j!=8)  error_legkaart();*/
 j=0;

 i=0;
 L32 { 
   if (kaart[n].DichtIkHy==3)
     {j++;
      kaart[n].posx=560-i*60;
      kaart[n].posy=188;
      Sputimage(560-i*60,183,krt[32],COPY_PUT);
      Sputimage(560-i*60,188,krt[n],COPY_PUT);
      kaart[n].postafel=i++;
     }
    } 
/* if(j!=4) error_legkaart();*/
 j=0;
 i=0;
 L32 { 
   if (kaart[n].DichtIkHy==4)
      {j++;
       kaart[n].posx=560-i*60;
       kaart[n].posy=88;
       Sputimage(560-i*60,93,krt[32],COPY_PUT);
       Sputimage(560-i*60,88,krt[n],COPY_PUT);
       kaart[n].postafel=i++;
      }
     } 
/* if(j!=4) error_legkaart();*/
 j=0;

if(!ZW)  Sputimage(0,125,veld,COPY_PUT); /*LEG SPEELVELD*/

 if(DICHT==1) return;
 i=0;
 L32 { 
    if (kaart[n].DichtIkHy==33)
    {
     kaart[n].posx=320-i*20;
     kaart[n].posy=188;
     if(DICHT==1)    Sputimage(320-i++*20,188,krt[32],COPY_PUT);
     else            Sputimage(320-i++*20,188,krt[n],COPY_PUT);
    }
 } 
 i=0;


 L32 { 
   if (kaart[n].DichtIkHy==44)
   {
    kaart[n].posx=320-i*20;
    kaart[n].posy=88;
    if(DICHT==1)  Sputimage(320-i++*20,88,krt[32],COPY_PUT);
    else          Sputimage(320-i++*20,88,krt[n],COPY_PUT);
   }
 }


}

/***************************troef bepalen ***************************/
void troef_bepalen(void)
{
 int sompunten[4];
 int aantalkrt[4];
 int zekereslagen[4];
 int somtroefpunten[4];
 int m,n;
 int hijtroef[4],hijtroefpunten[4];
 int status;
 int Hijtafel;

 TROEF=999;
 if(startvrager==1) Hijtafel=4;

 L4  {
   sompunten[n]=0;
   aantalkrt[n]=0;
   zekereslagen[n]=0;
   somtroefpunten[n]=0;
   hijtroef[n]=0;
   hijtroefpunten[n]=0;
  }

  L32   {
    status=kaart[n].DichtIkHy;
    if (status==startvrager || status==startvrager+2)
     {
      sompunten[kaart[n].kleur]+=kaart[n].troefwaarde;
      somtroefpunten[kaart[n].kleur]+=kaart[n].troefwaarde;
      aantalkrt[kaart[n].kleur]++;
     }
    if (status==Hijtafel) somtroefpunten[kaart[n].kleur]-=kaart[n].troefwaarde;
   }

						/* Tel troeven ts*/
  L32   {
    status=kaart[n].DichtIkHy;
    if (status==Hijtafel) /*Hijtafel*/
     {
      hijtroef[kaart[n].kleur]++;
      hijtroefpunten[kaart[n].kleur]+=kaart[n].troefwaarde;
     }
    }
  L4    {
    status= kaart[n*8+3].DichtIkHy;  /* Heb ik B tel zijn laagste troef bij*/
    if (status==startvrager || status==startvrager+2)
     {
      for(m=8*(n+1);m>=n*8;m--)
       {
	
       if(kaart[m].DichtIkHy == Hijtafel)
	{
	 somtroefpunten[n] += 2 * kaart[n].troefwaarde;
	 m= -1; /*break*/
	}}}}

   L8
    if(tafel[VRAGER-1][n].gegarandeerd )
       zekereslagen[tafel[VRAGER-1][n].kleur]++;
    
   L8
    if (hand[VRAGER-1][n].gegarandeerd ) 
       zekereslagen[hand[VRAGER-1][n].kleur]++;
      
   L4 somtroefpunten[n] += 3 * zekereslagen[n]+ 2 * aantalkrt[n];
   
   m=0;
   L4 {
     if(somtroefpunten[n]>m)
      {
       m=somtroefpunten[n];
       TROEF=n;
      }
    }
/*   sprintf(text,"TROEF %s %d %d %d %d ",KLEUR[TROEF],somtroefpunten[0],somtroefpunten[1],somtroefpunten[2],somtroefpunten[3]);
   outtextxy(1,0,text);*/
 L32 { if(kaart[n].kleur==TROEF) kaart[n].actwaarde=kaart[n].troefwaarde;
       else                      kaart[n].actwaarde=kaart[n].puntwaarde;
     }
}
    
/********************* leg kaart **************************/
 
int legkaart(char Skaart,int Skleur,int vrager)
 {
 int vragert,krtno,bijlegger,speler;
 int n,i,j,x,y;
 int krtposx[4],krtposy[4];
 int posx,posy;
 int knum;

 krtposx[0]=10;
 krtposy[0]=260;
 krtposx[1]=65;
 krtposy[1]=135;
 krtposx[2]=65;
 krtposy[2]=220;
 krtposx[3]=10;
 krtposy[3]=175;

 vragert=wie_vrager(Skaart,Skleur);
 speler=vragert;
 if(vragert!=vrager)
  return(FALSE);                   /* verkeerde kaart */
 if(vragert==5)
  return(FALSE);                  /* als kaart al gespeeld */
 if(vragert>4) 
  return(FALSE);                  /* dichte kaart */
 if(vragert>2) vragert-=2;

 if(vragert==1) kj.w=1; else kj.w=0;

 krtno=strpos(rangroem,Skaart)+Skleur*8-1;
 slag[SLAG][SLAGKRTNO].kleur  = Skleur;
 slag[SLAG][SLAGKRTNO].naam   = Skaart;
 slag[SLAG][SLAGKRTNO].speler = VRAGER;
 slag[SLAG][SLAGKRTNO].waarde = kaart[krtno].actwaarde;
 slag[SLAG][SLAGKRTNO].kans   = bepaal_slagkans(Skaart,Skleur);
 slag[SLAG][SLAGKRTNO].tactiek= TACTIEK;
 kaart[krtno].DichtIkHy=5;           /* kaart gespeeld */
 if(vragert==2) kjlegkaart(0,0,0,0,h);


 if(Skleur==TROEF) slag[SLAG][SLAGKRTNO].troef = 1;
	     else  slag[SLAG][SLAGKRTNO].troef = 0;

 posx=krtposx[VRAGER-1];
 posy=krtposy[VRAGER-1];
 SLAGKRTNO++;
if(!SDEMO){
if(vragert==1)
 {setcolor(LIGHTGREEN);
if(!DICHT) sprintf(text,"%2d Z %8s %c %3d%",TACTIEK,KLEUR[Skleur],Skaart,slag[SLAG][SLAGKRTNO-1].kans);
else     sprintf(text," Zuid %8s %c",KLEUR[Skleur],Skaart);
 }
else
 {setcolor(YELLOW);
if(!DICHT) sprintf(text,"%2d N %8s %c %3d%",TACTIEK,KLEUR[Skleur],Skaart,slag[SLAG][SLAGKRTNO-1].kans);
else     sprintf(text,"Noord %8s %c",KLEUR[Skleur],Skaart);
 }
 if(MaxY>350) outtextxy(452,400+SLAGKRTNO*15,text);
           }

/* if(!COMP && vragert==2) delay(1000);*/

 if(speler!=2)
	 Sputimage(kaart[krtno].posx,kaart[krtno].posy,krt[33],COPY_PUT);
 if(speler==3 &&  tzuid[kaart[krtno].postafel])
	 Sputimage(kaart[krtno].posx,kaart[krtno].posy-5,krt[33],COPY_PUT);
 if(speler==4 && tnoord[kaart[krtno].postafel])
	 Sputimage(kaart[krtno].posx,kaart[krtno].posy+5,krt[33],COPY_PUT);
 if(VRAGER==1) n=3;
 if(VRAGER==2) n=0;
 if(VRAGER==3) n=2;
 if(VRAGER==4) n=1;

 knum=(kaart[krtno].posx-560)/40;
if(!SDEMO){
 x=625;
 y=45+(n)*90;
 setcolor(YELLOW);
 sprintf(text,"%d",SLAGKRTNO);
 outtextxy(x,y,text);

 Sputimage(posx,posy,krt[krtno],COPY_PUT);
			      /* leg evt. zwarte kaart en leg kaart */

 if(speler==2)
     {L8  Sputimage(560-n*40,1,krt[33],COPY_PUT);
     i=0;
     L32 {if(kaart[n].DichtIkHy==2)
	   {
    if(DICHT==1)    Sputimage(560-i++*40,1,krt[32],COPY_PUT);
    else            Sputimage(kaart[n].posx,kaart[n].posy,krt[n],COPY_PUT);
		}}}
         }
/* if(COMP && !DICHT &&!SDEMO) delay(3000);*/
 punten();
 if(speler>2)
 {
 if(speler==3 &&  !tzuid[kaart[krtno].postafel]) return(TRUE);
 if(speler==4 && !tnoord[kaart[krtno].postafel]) return(TRUE);
				 
 j=knum+1;     /* kies random een nieuwe dichte kaart voor lus */

 if(speler==3)  bijlegger=33;  
 if(speler==4)  bijlegger=44;  

 n=i=0;
 while(TRUE)  /* zoek bijlegkaart */
  {
   if(kaart[krtno].dpos==kaart[n].dpos &&kaart[n].DichtIkHy==bijlegger) break;
   if(++n>31) return(TRUE);
  }

    kaart[n].posx=kaart[krtno].posx;
    kaart[n].posy=kaart[krtno].posy;
    kaart[n].postafel=kaart[krtno].postafel;
    kaart[krtno].dpos=6;

 if(speler==3)  tzuid[kaart[krtno].postafel] =0;
 if(speler==4) tnoord[kaart[krtno].postafel] =0;
   
 /* dichte kaart op tafel krijgt nu no + 10 bij volgende slag laten zien */
    if(kaart[n].DichtIkHy>30)  kaart[n].DichtIkHy=kaart[n].DichtIkHy/10+10;
    Sputimage(kaart[krtno].posx,kaart[krtno].posy,krt[32],COPY_PUT);
  }
j=j;
return(TRUE);
}

/********************* updatetafelkaarten *************************/

void updatetafelkaarten(void)
{
 int n,i;
 if(DICHT) return;

 L4  Sputimage(320-n*20,188,krt[33],COPY_PUT);

 i=0;
 L32 { 
      if (kaart[n].DichtIkHy==33)
	 {
	  kaart[n].posx=320-i*20;
	  kaart[n].posy=188;
	  Sputimage(320-i++*20,188,krt[n],COPY_PUT);
	 }
     }

 L4  Sputimage(320-n*20,88,krt[33],COPY_PUT);
 i=0;
 L32 { 
      if (kaart[n].DichtIkHy==44)
	 {
	  kaart[n].posx=320-i*20;
	  kaart[n].posy=88;
	  Sputimage(320-i++*20,88,krt[n],COPY_PUT);
	 }
       }
}

/************************ update tafel ******************/
void updatetafel(void)
{
int n;
int krtposx[4],krtposy[4];

 krtposx[0]=10;
 krtposy[0]=260;
 krtposx[1]=65;
 krtposy[1]=135;
 krtposx[2]=65;
 krtposy[2]=220;
 krtposx[3]=10;
 krtposy[3]=175;

 if(ZW) L4 Sputimage(krtposx[n],krtposy[n],krt[33],COPY_PUT);
 else   Sputimage(0,125,veld,COPY_PUT); /* leg leeg veld neer */
			      /* leg dichte kaart */
 L32 {
   if(kaart[n].DichtIkHy==13)
      { kaart[n].DichtIkHy=3; 
	Sputimage(kaart[n].posx,kaart[n].posy,krt[n],COPY_PUT);
      }
   if(kaart[n].DichtIkHy==14)
      { kaart[n].DichtIkHy=4; 
	Sputimage(kaart[n].posx,kaart[n].posy,krt[n],COPY_PUT);
      }
     }
}

/*******************  aantal hogere ************************/
int hogere(char kv,char *ks,char *volgorde)
{                                /* kv kaart voor vergelijk*/
 char nop1[20];                  /* ks string nog aanwezige kaarten */
 int m,n,i;                    /* volgorde is str met slagvolgorde*/

 if(strlen(ks)==0) return(0);
 L8 {
    if(volgorde[n]!=kv) nop1[n]=volgorde[n];
     else {nop1[n]=0; break;}
    }

   i=0;		       
 for(m=0;m<strlen(ks);m++)
  {
   if(strpos(nop1,ks[m])!=0) i++;
  }
return(i);
}

/*************** bepaal wie slag heeft ********************/
int wie_slag(void)
{
 int m,n,i,j;
 char st[5],slagvolgorde[9];
 int troef=0,Kkleur=5;
 int sp[5];
 Kkleur=slag[SLAG][0].kleur;

 for(n=0;n<SLAGKRTNO;n++) if (slag[SLAG][n].troef) troef=TRUE;

if(troef) strcpy(slagvolgorde,rangtroef);
 else     strcpy(slagvolgorde,rangnorm);

 if(troef) Kkleur=TROEF;
  i=0;
 for(n=0;n<SLAGKRTNO;n++)
  {
   if(slag[SLAG][n].kleur==Kkleur)
     { st[i]=slag[SLAG][n].naam;
       sp[i++]=slag[SLAG][n].speler;
     }
   }
 st[i]=0;
 i=10;
 for(n=0;n<strlen(st);n++)
   { j=strpos(slagvolgorde,(int)st[n]);
     if(j<i) {i=j; m=sp[n];}
   }

return(m);
}

/******************* CHECK VALID KAART *************************/
int check_valid(void)
{
int m,n,i,j;
char hoogste;
char slagstring[10];
char KKrt[10],TrKrt[10];
int  IKrt,TKrt;
int kaartkleurnul,troefaanwezig=0;


kaartkleurnul=slag[SLAG][0].kleur;
if(!SDEMO){
setcolor(BLACK);
 strcpy(text,"                   ");
 strset(text,219);
 outtextxy(1,10*10,text);
          }
if(SLAGKRTNO>0)
 {
  if(VRAGER<3){ strcpy(KKrt,khand[0][Lkleur]);
		strcpy(TrKrt,khand[0][TROEF]);
		TKrt=iKrt[TROEF][0];
		IKrt=iKrt[kaartkleurnul][0];
	      }
  else        { strcpy(KKrt,ktafel[0][Lkleur]);
		strcpy(TrKrt,ktafel[0][TROEF]);
		TKrt=iKrt_tafel[TROEF][0];
		IKrt=iKrt_tafel[kaartkleurnul][0];
	      }
  for(n=0;n<SLAGKRTNO;n++)
     if(slag[SLAG][n].kleur==TROEF) troefaanwezig=1;

 if(troefaanwezig)
  {
  strcpy(slagstring,rangtroef);
     
  i=99;
  for(n=0;n<SLAGKRTNO;n++)
      {
       if(slag[SLAG][n].kleur!=TROEF) continue;
       j=strpos(slagstring,slag[SLAG][n].naam);
       if(i>j) {i=j; hoogste=slag[SLAG][n].naam;}
      }


if((kaartkleurnul==TROEF && TKrt)||(iKrt==0 && TKrt)
      ||(troefaanwezig && TKrt && iKrt==0))
    {
     i=strpos(rangtroef,hoogste);
     if(strpos(rangtroef,Lkaart) <i && Lkleur==TROEF) return(TRUE);
				    /* als hogere troef */
     if(Lkleur!=TROEF)
       {                        
if(!SDEMO){	setcolor(WHITE);
	        sprintf(text,"Geen troef bekend");
	        outtextxy(1,10*10,text);
          }
     else { gotoxy(1,19); cprintf("Geen troef bekend");}

	return(FALSE);            /* als geen troef bekend */

	}
     for(m=0;m<SLAGKRTNO;m++)
       {
	if(strpos(rangtroef,Lkaart) > i )
	  for(n=0;n<strlen(TrKrt);n++)
	     if(strpos(rangtroef,TrKrt[n]) <i )
	       {                              /* als geen hogere troef */
if(!SDEMO){	setcolor(WHITE);
		sprintf(text,"Niet overtroeft");
		outtextxy(1,10*10,text);
          }
else { gotoxy(1,19); cprintf("Niet overtroeft");}
		return(FALSE);
	       }
       }                                      
   }  
  }
  if(kaartkleurnul==TROEF) strcpy(slagstring,rangtroef);
  else strcpy(slagstring,rangnorm);

  if(IKrt>0 && Lkleur !=kaartkleurnul)
    {
if(!SDEMO){    setcolor(WHITE);
               sprintf(text,"Niet bekend");
               outtextxy(1,10*10,text);
          }
       else { gotoxy(1,19); cprintf("Niet bekend");}

    return(FALSE);
   }						 /* als niet bekend */
 
  if(IKrt==0 && TKrt>0 /*&& Lkleur !=TROEF*/)
    {
    i=wie_slag();
    if(i>2) i-=2;
    j=VRAGER;
    if(j>2) j-=2;
    if(i==j) return(TRUE);
    i=strpos(rangtroef,hoogste);
    if(strpos(rangtroef,Lkaart) <i && Lkleur==TROEF) return(TRUE);

    for(n=0;n<strlen(TrKrt);n++)
	  {   if(strpos(rangtroef,TrKrt[n]) <i )
	       {                              /* als geen hogere troef */
if(!SDEMO){	setcolor(WHITE);
		sprintf(text,"Niet Overtroeft");
		outtextxy(1,10*10,text);
          }
          else { gotoxy(1,19); cprintf("Niet Overtroeft");}
		return(FALSE);
	       }}
  if(IKrt==0 && TKrt>0 && Lkleur !=TROEF && !troefaanwezig)
    {
if(!SDEMO){
    setcolor(WHITE);
    sprintf(text,"Niet getroeft");
    outtextxy(1,10*10,text);
           }
    else { gotoxy(1,19); cprintf("Niet getroeft");}

    return(FALSE);
    }						 /* als niet getroeft */
 
   }}
return(TRUE);
}
/************************** troef_vragen ***********************/
void  troef_vragen(void)
{
int n;
/*
 while(bioskey(1)) getch();
 setcolor(WHITE);
 setviewport(0,110,250,120,0);
 sprintf(text,"Welke kleur is troef ? (KSRH) ");
 outtextxy(1,1,text);
if(!Mpresent)
 {
while(TRUE)
 {
 t=getch();
 if(t==27) einde();
 if(t>96) t-=32;
 if(strchr("KSRH",t) ) { TROEF=strpos("KSRH",t)-1; break;}
 sound(50);
 nosound();
 sound(50);
 delay(500);
 nosound();
  }
 }
 else { /* als een mouse aanwezig */
       set_mouse_cursor(1,1);
       mouse_cursor_on();
       i=number_presses_down(0);
   while(TRUE)
     { Lkleur=-1;
       while(!number_presses_down(0))
	 { if(bioskey(1))
	    {
	     t=getch();
	     if(t==27) einde();
	     if(t>96) t-=32;
	     if(strchr("KSRH",t) )
		{ TROEF=strpos("KSRH",t)-1; Lkleur=TROEF; break;}
	     sound(50); nosound(); sound(50); delay(500); nosound();
	     }
	 }
       if(Lkleur>=0) break;
       while(!number_presses_up(0));
       col=last_horz_down(0);
       row=last_vert_down(0);

   L32{  if(col>kaart[n].posx && col<kaart[n].posx+52)
	{ if(row>kaart[n].posy && row<kaart[n].posy+82)
	   {if(kaart[n].DichtIkHy>4) continue;
	    Lkleur=kaart[n].kleur;
	    }}}
    if(Lkleur<5 && Lkleur>=0) {mouse_cursor_off(); break;}
    }
 TROEF=Lkleur;

}
*/

 L32 { if(kaart[n].kleur==TROEF) kaart[n].actwaarde=kaart[n].troefwaarde;
       else                      kaart[n].actwaarde=kaart[n].puntwaarde;
     }
 punten();
}

/******************* bepaal roempunten ************************/
int bepaalroempunten(char *s,int kolor)
{
int n,i,j;
int stuk=0;

i=j=0;
L8 if(strpos(s,rangroem[n]))
   { i++;
     if(i>j) j=i;
   }
  else i=0;

if(strpos(s,'V') && strpos(s,'H') && (kolor==TROEF)) stuk=20;

if(j==3) return(stuk+20);
if(j==4) return(stuk+50);
return(stuk);
}


/***************  evalueerspel ***************************/
void  evalueerspel(void)
{
 int n,a,b;

 if(Speler>2) Speler-=2;
 SLAG--;
 n=wie_slag();
 if(n>2) n-=2;

 if(puntenspel[0]==152 &&roem[1]==0) {roem[0]+=100;Pit[0]++;}
 if(puntenspel[1]==152 &&roem[0]==0) {roem[1]+=100;Pit[1]++;}
 if(puntenspel[0]==152 &&roem[1]==0 && Speler==2) {roem[0]+=200;Tpit[0]++;}
 if(puntenspel[1]==152 &&roem[0]==0 && Speler==1) {roem[1]+=200;Tpit[1]++;}

 a=puntenspel[0]+roem[0];
 b=puntenspel[1]+roem[1];

 if(Speler==1 && a<=b) {b+=a; a=0; Nat[0]++;}
 if(Speler==2 && b<=a) {a+=b; b=0; Nat[1]++;}

 puntentotaalspel[0]+=a;
 puntentotaalspel[1]+=b;
 Tpnt[0]+=a;
 Tpnt[1]+=b;
 if(a<b) Gewonnen[1]++; else Gewonnen[0]++;
 Roempnt[0]+=roem[0];
 Roempnt[1]+=roem[1];
 puntenspel[0]=puntenspel[1]=0;
 roem[0]=roem[1]=0;
 SLAG++;
if(!SDEMO){
 setcolor(YELLOW);
 settextstyle(0,0,2);
 if(a>b) outtextxy(300,150,"Zuid gewonnen");
 else    outtextxy(300,150,"Noord gewonnen");
/*  if(COMP && !DICHT) delay(3000);*/
 settextstyle(0,0,1);
          }

L4 {verzaakt[0][n]=0; verzaakt[1][n]=0;}
 if(puntentotaalspel[0]>=1500 || puntentotaalspel[1]>=1500)
   {if(puntentotaalspel[0]>puntentotaalspel[1]) gewonnen[0]++;
    else                                        gewonnen[1]++;
   if(puntentotaalspel[0]==puntentotaalspel[1]) gewonnen[0]++;
    puntentotaalspel[0]=0;
    puntentotaalspel[1]=0;
   }
}
/********************* hoogste roem **************************/
char hoogsteroem(int Kkleur)
{
char Hkaart;
HOOGSTE=1;
Hkaart=laagsteroem(Kkleur);
HOOGSTE=0;
return(Hkaart);

}

/********************* laagste roem **************************/
char laagsteroem(int Kkleur)
{
int  m,n,i,j,a,b,c,d,e;
int  aa,bb,cc,dd;
char Roem[10],Skaart;
int  roempnt[24];
char RR[24][8];
char Kt[8][10];  /* str met kaarten van die Kkleur */
char ss[5];      /* str met kaarten van vrager van die kleur*/
int  iKt[5][10]; /* waarde van kaarten */
int  t[5];
int  vRAGER;

vRAGER=VRAGER;
if(vRAGER>2) vRAGER-=2;

L8 { roempnt[n]=0; roempnt[n+8]=0; roempnt[n+16]=0; Roem[n]=0; Roem[1]=0;
     for(m=0;m<8;m++) {RR[n][m]=0; RR[n+8][m]=0; RR[n+16][m]=0;}
    }

for(n=0;n<8;n++)
   { t[n]=0; 
     for(i=0;i<9;i++) Kt[n][i]=0; }

for(n=Kkleur*8;n<(Kkleur+1)*8;n++)
 { if(kaart[n].DichtIkHy<5 )
     {
     j=kaart[n].DichtIkHy;
     if(j>10) j=1-(vRAGER-1)+1; /*dichte kaart */
     if(--j<0) continue;      /* als 0 dan niet */
     Kt[j][t[j]]=kaart[n].naam;
    if(j+1==VRAGER)     ss[t[j]]=kaart[n].naam; /* vul vrager string */
     iKt[j][t[j]++]=kaart[n].actwaarde;
     }
  }

for(n=0;n<SLAGKRTNO;n++)
   {
   if(slag[SLAG][n].kleur==Kkleur)
     {
     Kt[slag[SLAG][n].speler-1][0]=0;
		   /* maak string van al gespeelde spelers leeg */
     Roem[strlen(Roem)]=slag[SLAG][n].naam;/*plak die in gespeelde krtstring*/
     }}


for(m=0;m<4;m++) /* sorteren op lengte */
  {
  L4 { if(strlen(Kt[n])<strlen(Kt[n+1]))
	{ strcpy(Kt[5],Kt[n]);
	  strcpy(Kt[n],Kt[n+1]);
	  strcpy(Kt[n+1],Kt[5]);
	  Kt[5][0]=0;
	}
     }
  }
aa=strlen(Kt[0]);
bb=strlen(Kt[1]);
cc=strlen(Kt[2]);
dd=strlen(Kt[3]);
if(!aa) aa++;
if(!bb) bb++;
if(!cc) cc++;
if(!dd) dd++;


i=0;
j=strlen(Roem);
for(a=0;a<strlen(Kt[0])*bb*cc*dd;a++)
    strcpy(RR[i++],Roem);                     /*zet gespeelde kaarten in RR */  

i=0; 
for(b=0;b<aa;b++)
 {for(c=0;c<bb;c++)
   {for(d=0;d<cc;d++)
     {for(e=0;e<dd;e++)
       {  RR[i][j+0]=Kt[0][b];
	  RR[i][j+1]=Kt[1][c];
	  RR[i][j+2]=Kt[2][d];
	  RR[i][j+3]=Kt[3][e];
	  i++;
       }}}}


i=aa*bb*cc*dd;
Skaart=0;
if(HOOGSTE)
{
m=0;   a=0;  
for(n=0;n<i+1;n++)     
  {
    roempnt[n]=bepaalroempunten(RR[n],Kkleur);
    if(m<=roempnt[n])
      {
      for(j=(Kkleur+1)*8-1;j>=Kkleur*8;j--) /* zo eindig je bij de hoogste*/
	{ if(kaart[j].DichtIkHy==VRAGER)
	   for(a=0;a<strlen(RR[n]);a++)
	     if(kaart[j].naam==RR[n][a])  { Skaart=RR[n][a];  m=roempnt[n];}

  }   } }
return(Skaart);
}
m=999; c=999;    
for(n=0;n<i;n++)     
  {
    roempnt[n]=bepaalroempunten(RR[n],Kkleur);
    if(m>=roempnt[n])
      {if(m>roempnt[n]) c=999;
      for(j=Kkleur*8;j<(Kkleur+1)*8;j++) /* zo eindig je bij de laagste*/
	{ if(kaart[j].DichtIkHy==VRAGER)
	   for(a=0;a<strlen(RR[n]);a++)
	     if(kaart[j].naam==RR[n][a])
	      {if(m>roempnt[n])
		{c=kaart[j].actwaarde;   Skaart=RR[n][a];  m=roempnt[n];}
	       if(m==roempnt[n] &&  c>=kaart[j].actwaarde)
		{c=kaart[j].actwaarde;   Skaart=RR[n][a]; }
	      }

  }   } }    
return(Skaart);
}


/********************* bepaal hoogste roem **************************/
int bepaal_hoogsteroem(int Kkleur,char Skaart)
{
int roem;
HOOGSTE=1;
roem=bepaal_laagsteroem(Kkleur,Skaart);
HOOGSTE=0;
return(roem);

}

/********************* bepaal laagste roem **************************/
int bepaal_laagsteroem(int Kkleur,char Skaart)
{
int  m,n,i,j,b,c,d,e;
int  aa,bb,cc,dd;
char Roem[10];
int  roempnt[24];
char RR[24][8];
char Kt[8][10];  /* str met kaarten van die Kkleur */
int  iKt[5][10]; /* waarde van kaarten */
int  t[5];
int  vRAGER;

vRAGER=wie_vrager(Kkleur,Skaart);
if(vRAGER>2) vRAGER-=2;

L8 { roempnt[n]=0; roempnt[n+8]=0; roempnt[n+16]=0; Roem[n]=0; Roem[1]=0;
     for(m=0;m<8;m++) {RR[n][m]=0; RR[n+8][m]=0; RR[n+16][m]=0;}
    }

for(n=0;n<8;n++)
   { t[n]=0; 
     for(i=0;i<9;i++) Kt[n][i]=0; }

for(n=Kkleur*8;n<(Kkleur+1)*8;n++)
 { if(kaart[n].DichtIkHy<5 )
     {
     j=kaart[n].DichtIkHy;
     if(j>10) j=1-(vRAGER-1)+1; /*dichte kaart */
     if(--j<0) continue;
     Kt[j][t[j]]=kaart[n].naam;
    if(j+1==VRAGER)     Kt[4][t[j]]=kaart[n].naam;
     iKt[j][t[j]++]=kaart[n].actwaarde;
     }
  }
Kt[4][0]=0;
L4 {  /*Stop in vraagstring Skaart */
    for(m=0;m<strlen(Kt[n]);m++)
     if(Kt[n][m]==Skaart){ Kt[n][0]=Skaart; Kt[n][1]=0; }
    }

for(m=0;m<4;m++) /* sorteren op lengte */
  {
  L4 { if(strlen(Kt[n])<strlen(Kt[n+1]))
	{ strcpy(Kt[5],Kt[n]);
	  strcpy(Kt[n],Kt[n+1]);
	  strcpy(Kt[n+1],Kt[5]);
	  Kt[5][0]=0;
	}
     }
  }


aa=strlen(Kt[0]);
bb=strlen(Kt[1]);
cc=strlen(Kt[2]);
dd=strlen(Kt[3]);
if(!aa) aa++;
if(!bb) bb++;
if(!cc) cc++;
if(!dd) dd++;


i=0;
j=0;
for(b=0;b<aa;b++)
 {for(c=0;c<bb;c++)
   {for(d=0;d<cc;d++)
     {for(e=0;e<dd;e++)
       {  RR[i][j+0]=Kt[0][b];
	  RR[i][j+1]=Kt[1][c];
	  RR[i][j+2]=Kt[2][d];
	  RR[i][j+3]=Kt[3][e];
	  i++;
       }}}}

i=aa*bb*cc*dd;

if(HOOGSTE)
{
m=0;     
for(n=0;n<i+1;n++)     
  {
    roempnt[n]+=bepaalroempunten(RR[n],Kkleur);
    if(m<=roempnt[n])
      {m=roempnt[n]; }
  }
return(m);
}
m=999;     
for(n=0;n<i;n++)     
  {
    roempnt[n]+=bepaalroempunten(RR[n],Kkleur);
    if(m>=roempnt[n])
      {m=roempnt[n]; }
  }
return(m);
}
 /**************** vraag kaart *****************************/
 void vraagkaart(void)
 {
 int i,m;
 while(TRUE)
 {
 setcolor(BLACK);
 text[0]=219; text[1]=219; text[2]=219; text[3]=0;
 outtextxy(24*8,9*10,text);
 i=getch();
 if(i==27) einde();
 if(i>96) i-=32;
 if(strpos("KSRH",i)) break;
 sound(550); nosound(); sound(1250); delay(250); nosound();
 }
 outtextxy(24*8,9*10,text);
 setviewport(1,100,265,120,0);
 clearviewport();
 setviewport(0,0,MaxX,MaxY,0);
/* strcpy(text,"                       ");
 strset(text,219);
 outtextxy(1,9*10,text);
*/
 if(i==27) einde();

 setcolor(YELLOW);
 sprintf(text,"%c",i);
 outtextxy(24*8,9*10,text);
 while(bioskey(1)) getch();
 Lkaart=(char)getche();
 if(Lkaart>96) Lkaart-=32;
 m=strpos("KSRH",i)-1;
 sprintf(text,"%c",Lkaart);
 outtextxy(25*8,9*10,text);
 Lkleur=m;
}

/*********************** humaan(void) *************************/
void  humaan(void)
{int g;

 if(startvrager==1) {g=1; }
 if(startvrager==2) {g=1; }
 if(startvrager==3) {g=0; }
 if(startvrager==4) {g=0; }


if(SLAGKRTNO==1)  kjuitkom1(1,i);
if(SLAGKRTNO==2)  kjuitkom2(g,i);
if(SLAGKRTNO==3)  kjuitkom3(0,i);
if(SLAGKRTNO==0)  kj.w=kjuitkom0(0,i); else kj.w=1;


Lkleur=kj.s[SLAGKRTNO].k;
Lkaart=kj.s[SLAGKRTNO].n;




}
/************************
/*
if(SLAGKRTNO>0)
 {
 if(VRAGER==1)
  {
   if(iKrt[slag[SLAG][0].kleur][0]==1)

    { Lkaart=khand[0][slag[SLAG][0].kleur][0];
      Lkleur=slag[SLAG][0].kleur;
      TACTIEK=46;
      return;
    }
  }

 if(VRAGER==3)
  {
   if(iKrt_tafel[slag[SLAG][0].kleur][0]==1)
    { Lkaart=ktafel[0][slag[SLAG][0].kleur][0];
      Lkleur=slag[SLAG][0].kleur;
      TACTIEK=43;
      return;
    }
  }
 }

 if(SLAG==8 && SLAGKRTNO>0 )
   {
    L32 { if(kaart[n].DichtIkHy==VRAGER)
	  {
	   Lkaart=kaart[n].naam;
	   Lkleur=kaart[n].kleur;
	   TACTIEK=48;
	   return;
	  }
	}
    }
*/
while(TRUE)
{
 found=FALSE;
 setcolor(WHITE);
 setviewport(0,0,MaxX,MaxY,0);
 sprintf(text,"Geef Kleur(KSRH) Kaart      ");
 outtextxy(1,9*10,text);
 while(bioskey(1)) getch();
if(!Mpresent)
 { vraagkaart();
   m=Lkleur;
 }
 else { /* als een mouse aanwezig */
       mouse_cursor_on();
       i=number_presses_down(0);
   while(TRUE)
   {   Lkaart=0;
       while(!number_presses_down(0))
	 { if(bioskey(1))
	  {mouse_cursor_off(); vraagkaart(); m=Lkleur; break; }
	 }
       if(Lkaart) break;
       while(!number_presses_up(0));
       col=last_horz_down(0);
       row=last_vert_down(0);

   L32{  if(col>kaart[n].posx && col<kaart[n].posx+52)
	{ if(row>kaart[n].posy && row<kaart[n].posy+82)
	   {if(kaart[n].DichtIkHy>4) continue;
	   m=Lkleur=kaart[n].kleur;
	    Lkaart=kaart[n].naam;
	    }}}
    if(Lkaart) {mouse_cursor_off(); break;}
    }}

 for(n=m*8;n<m*8+8;n++)
   {
    if(kaart[n].naam==Lkaart) i=kaart[n].DichtIkHy;
    if(SLAGKRTNO==0 && (VRAGER==1 || VRAGER==3))
      {
       if(i==1 || i==3){  found=TRUE; VRAGER=i;}
      }    
    else if(VRAGER==i) found=TRUE;
    }

 text[0]=0;
 if(found && check_valid()) break; 
 setcolor(BLACK);
 strcpy(text,"                   ");
 strset(text,219);
 outtextxy(1,11*10,text);

 setcolor(WHITE);
 sprintf(text,"Verkeerde kaart");
 if(VRAGER!=i && i==3)  sprintf(text,"Uit de hand spelen");
 if(VRAGER!=i && i==1)  sprintf(text,"Van tafel spelen");
 outtextxy(1,11*10,text);
 sound(50);
 nosound();
 sound(50);
 delay(100);
 nosound();
 }

 TACTIEK=19;
}

*/
/************************* einde *************************/
void punten(void)
{
 int i;
 char textw[30];

if(!SDEMO){
 setviewport(0,0,100,120,0);

 setcolor(BLACK);
 strcpy(textw,"              ");
 strset(textw,219);

 setcolor(YELLOW);
 sprintf(text,"TROEF is %s",KLEUR[TROEF]);
 if(TROEF < 5) outtextxy(1,1,text);
 setcolor(GREEN);
 sprintf(text,"      Noord    Zuid ");
 setviewport(0,20,150,30,0);
 outtextxy(1,1,text);

if(SLAGKRTNO==4 ||SLAG==0)
{
 sprintf(text,"Pnt  %5d   %5d",puntenspel[1],puntenspel[0]);
 setviewport(40,30,150,40,0);
 clearviewport();
 setcolor(GREEN);
 setviewport(0,30,150,40,0);
 outtextxy(1,1,text);

 sprintf(text,"Roem %5d   %5d",roem[1],roem[0]);
 setviewport(40,40,150,50,0);
/* setcolor(BLACK);
 outtextxy(1,1,textw);*/
 clearviewport();
 setcolor(GREEN);
 setviewport(0,40,150,50,0);
 outtextxy(1,1,text);
}
if(SLAG==0)
{
 sprintf(text,"Tot  %5ld   %5ld",puntentotaalspel[1],puntentotaalspel[0]);
 setviewport(40,50,150,60,0);
 clearviewport();
 setviewport(0,50,150,60,0);
 outtextxy(1,1,text);
}
 i=Speler;
 if(SLAGKRTNO >0 ) i=wie_slag();
 if(i>2) i-=2;
 setcolor(LIGHTMAGENTA);
 if(SLAG==0)
   {
    setviewport(0,60,MaxX,MaxY,0);
    if(Speler==1)    sprintf(text,"              Speler");
    else             sprintf(text,"      Speler");
    outtextxy(1,1,text);
   }
 setcolor(LIGHTBLUE);
 if(SLAG<9 && SLAG>0)
  {
   if(i==1)          sprintf(text,"               Slag");
   if(i==2)          sprintf(text,"       Slag");
   setviewport(40,70,160,80,0);
   clearviewport();
   setviewport(0,70,150,80,0);
   outtextxy(1,1,text);

  }
 setcolor(LIGHTGRAY);
 if(SLAG==0)
   {
    setviewport(0,10,160,20,0);
    sprintf(text,"Stand");
    outtextxy(1,1,text);
    sprintf(text,"  %3d     %3d",gewonnen[1],gewonnen[0]);
    setviewport(40,10,160,20,0);
    clearviewport();
    outtextxy(1,1,text);
   }

 setcolor(WHITE);
 setviewport(0,90,240,120,0);
 clearviewport();
 setviewport(0,0,MaxX,MaxY,0);
          } /* einde !SDEMO */

}
/************************** INIT MOUSE ***************************/
void init_mouse(void)
{
mouse_cursor_on();
set_x_max_min(630,180);
if(MaxY>350) set_y_max_min(188,365);
else         set_y_max_min(188,MaxY-10);
set_mouse_cursor(1,1);
}
/******************* void  error_legkaart ******************************/
void  error_legkaart(void)
{
int m,n; /*a,b,m,n;*/
gotoxy(1,14);
printf("Fout : Ik heb verzaakt (%d)\n",VRAGER);
printf("Dit spelletje wordt beeindigd\n");
printf("Alle punten zijn voor de tegenstander\n");
printf("Ik heb met tactiek no% d kaart %s %c willen leggen.\n",TACTIEK,KLEUR[Lkleur],Lkaart);
printf("Druk een toets.");
if(VRAGER>2) VRAGER-=2;
if(VRAGER==1) m=2; else m=1;
m=m;
sound(1000);
/*puntenspel[m-1]+=152+roem[VRAGER-1]+roem[m-1];
puntenspel[VRAGER-1]=0;
roem[VRAGER-1]=0;

a=puntenspel[0]+roem[0];
b=puntenspel[1]+roem[1];

 puntentotaalspel[0]+=a;
 puntentotaalspel[1]+=b;*/
 puntenspel[0]=puntenspel[1]=0;
 roem[0]=roem[1]=0;
 SLAG=10;
L4 {verzaakt[0][n]=0; verzaakt[1][n]=0;}
nosound();
printf("troef %d",kj.t);
if(!SDEMO) getch();
}

/*************** print laatste slag **************************/
void  print_laatsteslag(void)
{
int  krtno,m,n,posx,posy,x,y;
int  Skleur;
char Skaart;
if(MaxY<351 || SDEMO) return;
setviewport(0,370,MaxX,MaxY,0);
clearviewport();
setviewport(0,0,MaxX,MaxY,0);

 setcolor(BLACK);
 x=625;
 text[0]=219; text[1]=0;
 L4{ y=45+n*90; outtextxy(x,y,text);}


 L4 {
     Skleur= slag[SLAG][n].kleur;
     Skaart= slag[SLAG][n].naam;
     m     = slag[SLAG][n].speler;
     krtno = strpos(rangroem,Skaart)+Skleur*8-1;
     if(m==1 || m==3) posy=390; else posy=380;
     posx=(30+n*60);
     Sputimage(posx,posy,krt[krtno],COPY_PUT);
    }
 }
