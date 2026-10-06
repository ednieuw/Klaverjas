/* ************************************************************************ */
/*                                                                          */
/*  Programma : KLAVERJAS	Versie : RL 1.0				    */
/*  Modulenaam: KJ0.C							    */
/*  Door      : R. Loggen                                                   */
/*                                                                          */
/*  Deze module bevat main functie voor het programma KJ		    */
/*                                                                          */
/* ************************************************************************ */

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
#include <keyboard.h>
#include <strings.h>
#include "kjas.h"
#include "kj0.h"
#include "kjr.h"
#include "kj2.h"
#include <graphic.h>

int  kjlegaal(char h,char w,char *l,struct hand *d);
void kjlegkaart(char h,int n,int w,int e,struct hand *d);
void kjlegkaarttest(char h,int n,int w,int e,struct hand *d);
void kjmaakslag(int slag);
int  kjmaakslagtest(char wie);
void kjmaaktroef(char troef,struct kaart k[4][8],struct kaart h[4][8]);
char kjtroef(void);
void kjtafel(char f);
int  kjtoets(void);
void kjtroefstat(void);


extern struct dek *s;
extern struct hand *i;
extern struct hand *h;
extern int TROEF;
extern int VRAGER;
extern int SLAGKRTNO;
extern int Lkaart;
extern int Lkleur;

extern struct kljas kj;
extern char reg[81];
extern char rljas;		 /* 0=human
				    1=single step
				    2=test */
extern char kjnivo;

int kjlegaal(char h,char w,char *l,struct hand *d)
{
   char max,x,z;
   char r,wie,s,k;

   if(h == 0) z=8;
   else z=4;
   for(x=0;x<8;x++) l[x]=-1;
   wie=s=r=0;
   k=kj.s[0].k;
   r=kj.s[0].r;
   wie=kj.s[0].wi;
   for(x=1;x<4;x++) {
      if(kj.s[x].wi > 0) {
	 if(kj.s[x].r > r) {
	    if(kj.s[x].k == kj.t || kj.s[x].k == k) {
	       s=x;
	       wie=kj.s[x].wi;
	       r=kj.s[x].r;
	    }
	 }
      }
   }
   --wie;
   max=0;
   if(k == kj.t) {
      for(x=0;x<z;x++) {
	 if(d->h[h][x].wi > 0)
	    if(d->h[h][x].r > r) l[max++]=x;
      }
      if(max == 0) {
	 for(x=0;x<z;x++) {
	    if(d->h[h][x].wi > 0)
	       if(d->h[h][x].k == k) l[max++]=x;
	 }
      }
      if(max == 0) {
	 for(x=0;x<z;x++) {
	    if(d->h[h][x].wi > 0) l[max++]=x;
	 }
      }
   } else {
      for(x=0;x<z;x++) {
	 if(d->h[h][x].wi > 0)
	    if(d->h[h][x].k == k) l[max++]=x;
      }
      if(max == 0) {
	 if(wie == w) {
	    for(x=0;x<z;x++) {
	       if(d->h[h][x].wi > 0) {
		  if(kj.s[s].k == kj.t) {
		     if(d->h[h][x].k == kj.t) {
			if(d->h[h][x].r > r) l[max++]=x;
		     } else l[max++]=x;
		  } else l[max++]=x;
	       }
	    }
	    if(max == 0) {
	       for(x=0;x<z;x++) {
		  if(d->h[h][x].wi > 0) l[max++]=x;
	       }
	    }
	 } else {
	    for(x=0;x<z;x++) {
	       if(d->h[h][x].wi > 0)
		  if(d->h[h][x].k == kj.t)
		     if(d->h[h][x].r > r) l[max++]=x;
	    }
	    if(max == 0) {
	       for(x=0;x<z;x++) {
		  if(d->h[h][x].wi > 0) l[max++]=x;
	       }
	    }
	 }
      }
   }
   return(max);
}

void kjlegkaart(char h,int n,int w,int e,struct hand *d)
{
 int x;
 int vragert;

   vragert=VRAGER;
   if(vragert>2) vragert-=2;
   h=vragert-1;
   n=SLAGKRTNO;
   if(h==1) {   if(VRAGER>2) w=1; else w=0;       }
   if(h==1) {
             if(w==0){
                 for(x=0;x<8;x++)
                  {
                   if(s->h[2][x].k==Lkleur &&
                      s->h[2][x].n==Lkaart)  {  e=x;   break;}
                   }
                     }
              else {
                 for(x=4;x<8;x++)
                  {
                   if(s->h[3][x].k==Lkleur &&
                      s->h[3][x].n==Lkaart)  {  e=x-4;   break;}
                   }
                    }

              }
    if(e==-1)
       getch();

   if(w == 0) {
      if(h == 0) {
	 memcpy(&kj.s[n],&s->h[0][e],sizeof(struct kaart));
	 for(x=e;x<7;x++) {
	    memcpy(&s->h[0][x],&s->h[0][x+1],sizeof(struct kaart));
	    memcpy(&d->h[0][x],&d->h[0][x+1],sizeof(struct kaart));
	 }
	 memset(&s->h[0][7],0,sizeof(struct kaart));
	 memset(&d->h[0][7],0,sizeof(struct kaart));
      } else {
	 memcpy(&kj.s[n],&s->h[2][e],sizeof(struct kaart));
	 for(x=e;x<7;x++) {
	    memcpy(&s->h[2][x],&s->h[2][x+1],sizeof(struct kaart));
	    memcpy(&d->h[0][x],&d->h[0][x+1],sizeof(struct kaart));
	 }
	 memset(&s->h[2][7],0,sizeof(struct kaart));
	 memset(&d->h[0][7],0,sizeof(struct kaart));
      }
   } else {
      if(h == 0) {
	 memcpy(&kj.s[n],&s->h[1][e+4],sizeof(struct kaart));
	 s->h[1][e+4].wi=-1;
	 d->h[1][e].wi=-1;
      } else {
	 memcpy(&kj.s[n],&s->h[3][e+4],sizeof(struct kaart));
	 s->h[3][e+4].wi=-1;
	 d->h[1][e].wi=-1;
      }
   }
}

void kjlegkaarttest(char h,int n,int w,int e,struct hand *d)
{
   if(w == 0) {
      if(h == 0) memcpy(&kj.s[n],&s->h[0][e],sizeof(struct kaart));
      else memcpy(&kj.s[n],&s->h[2][e],sizeof(struct kaart));
   } else {
      if(h == 0) memcpy(&kj.s[n],&s->h[1][e+4],sizeof(struct kaart));
      else memcpy(&kj.s[n],&s->h[3][e+4],sizeof(struct kaart));
   }
}

void kjmaakslag(int slag)
{
   int k,n;
   int p,r,x;

   for(x=0;x<4;x++) {
      k=kj.s[x].k;
      if(k == (int)kj.t) n=abs((int)(kj.s[x].r-16));
      else n=abs((int)(kj.s[x].r-8));
      s->d[k][n].wi=-1;
      i->k[k][n].wi=-1;
      h->k[k][n].wi=-1;
      if(s->h[1][x+4].wi == -1 && s->h[1][x].wi > 0) {
	 s->h[1][x].wa=1;
	 k=s->h[1][x].k;
	 if(k == (int)kj.t) n=abs((int)(s->h[1][x].r-16));
	 else n=abs((int)(s->h[1][x].r-8));
	 s->d[k][n].wa=1;
	 memcpy(&s->h[1][x+4],&s->h[1][x],sizeof(struct kaart));
	 memcpy(&i->h[1][x],&s->h[1][x],sizeof(struct kaart));
	 i->h[1][x].wi=1;
	 memcpy(&h->h[2][x],&s->h[1][x],sizeof(struct kaart));
	 h->h[2][x].wi=2;
	 memcpy(&i->k[k][n],&i->h[1][x],sizeof(struct kaart));
	 memcpy(&h->k[k][n],&h->h[2][x],sizeof(struct kaart));
	 i->k[k][n].wi=2;
	 h->k[k][n].wi=3;
	 s->h[1][x].wi=-1;
      }
      if(s->h[3][x+4].wi == -1 && s->h[3][x].wi > 0) {
	 s->h[3][x].wa=1;
	 k=s->h[3][x].k;
	 if(k == (int)kj.t) n=abs((int)(s->h[3][x].r-16));
	 else n=abs((int)(s->h[3][x].r-8));
	 s->d[k][n].wa=1;
	 memcpy(&s->h[3][x+4],&s->h[3][x],sizeof(struct kaart));
	 memcpy(&h->h[1][x],&s->h[3][x],sizeof(struct kaart));
	 h->h[1][x].wi=1;
	 memcpy(&i->h[2][x],&s->h[3][x],sizeof(struct kaart));
	 i->h[2][x].wi=2;
	 memcpy(&h->k[k][n],&h->h[1][x],sizeof(struct kaart));
	 memcpy(&i->k[k][n],&i->h[2][x],sizeof(struct kaart));
	 h->k[k][n].wi=2;
	 i->k[k][n].wi=3;
	 s->h[3][x].wi=-1;
      }
   }
   for(x=0;x<4;x++) {
      if(i->h[1][x].wi == -1) h->h[2][x].wi=-1;
      if(h->h[1][x].wi == -1) i->h[2][x].wi=-1;
   }
   kjbekenjn();
   kj.w=kjwieslag();
   if(kj.w >=0) {
      ++kj.h[2][kj.w];
      kjpuntslag(&p,&r);
      kj.h[5][kj.w]+=p+r;
      kj.h[6][kj.w]+=p;
      kj.h[7][kj.w]+=r;
      if(slag == 7) {
	 kj.h[5][kj.w]+=10;
	 kj.h[7][kj.w]+=10;
      }
   }
}

int kjmaakslagtest(char wie)
{
   int p,r,ret;
   char w;

   ret=0;
   w=kjwieslag();
   if(w >=0) {
      kjpuntslag(&p,&r);
      if(w == wie) ret=p+r;
      else ret=0-p-r;
   }
   return(ret);
}


void kjmaaktroef(char troef,struct kaart k[4][8],struct kaart h[4][8])
{
   int x,y;

   k[troef][7].r=9;
   k[troef][6].r=10;
   memcpy(&kj.s[0],&k[troef][5],sizeof(struct kaart));
   memcpy(&kj.s[1],&k[troef][4],sizeof(struct kaart));
   memcpy(&k[troef][5],&k[troef][3],sizeof(struct kaart));
   k[troef][5].r=11;
   memcpy(&k[troef][4],&k[troef][2],sizeof(struct kaart));
   k[troef][4].r=12;
   memcpy(&k[troef][3],&k[troef][1],sizeof(struct kaart));
   k[troef][3].r=13;
   memcpy(&k[troef][2],&k[troef][0],sizeof(struct kaart));
   k[troef][2].r=14;
   memcpy(&k[troef][1],&kj.s[0],sizeof(struct kaart));
   k[troef][1].r=15;
   k[troef][1].p=14;
   memcpy(&k[troef][0],&kj.s[1],sizeof(struct kaart));
   k[troef][0].r=16;
   k[troef][0].p=20;
   for(y=0;y<8;y++) {
      if(h[1][y].k == troef) {
	 for(x=0;x<8;x++) {
	    if(h[1][y].n == k[troef][x].n) {
	       memcpy(&h[1][y],&k[troef][x],sizeof(struct kaart));
	       break;
	    }
	 }
      }
      if(h[3][y].k == troef) {
	 for(x=0;x<8;x++) {
	    if(h[3][y].n == k[troef][x].n) {
	       memcpy(&h[3][y],&k[troef][x],sizeof(struct kaart));
	       break;
	    }
	 }
      }
   }
   memset(kj.s,0,4*sizeof(struct kaart));
}


void kjtroefstat(void)
{
   int x,y;

   for(y=0;y<4;y++) {
      for(x=0;x<8;x++) {
	 kj.h[8][s->d[y][x].wi-1]+=s->d[y][x].p;
	 if(s->d[y][x].k == kj.t) {
	    kj.h[10][s->d[y][x].wi-1]+=s->d[y][x].p;
	    ++kj.h[11][s->d[y][x].wi-1];
	 } else kj.h[9][s->d[y][x].wi-1]+=s->d[y][x].p;
      }
   }
}

char kjtroef(void)
{
   int t[4];
   int x,y,z;
   char troef;

   if(kj.w == 0 ) {
      for(x=0;x<4;x++) t[x]=0;
      for(y=0;y<4;y++) {
	 memset(i,0,sizeof(struct hand));
	 kjvulhand(kj.w,i);
	 kjmaaktroef((char)y,i->k,i->h);
	 for(x=0;x<8;x++) {
	    switch(i->k[y][x].wi) {
	       case 1:
		  t[y]+=i->k[y][x].p;
		  t[y]+=3;
		  break;
	       case 2:
		  t[y]+=i->k[y][x].p;
		  t[y]+=3;
		  break;
	       case 3:
		  t[y]-=i->k[y][x].p;
		  break;
	    }
	 }
	 for(x=7,z=0;x>0;x--) {
	    if(i->k[y][x].wi == 3) {
	       if(i->k[y][z].wi == 1 || i->k[y][z].wi == 2) {
		  t[y]+=i->k[y][x].p*2;
		  z++;
	       } else break;
	    }
	 }
      }
      troef=0;
      for(x=1;x<4;x++)
	 if(t[x] > t[troef]) troef=(char)x;
      troef=kj2troef(i);
     }
   else    troef=(char)TROEF;
   memset(i,0,sizeof(struct hand));
   kjmaaktroef(troef,s->d,s->h);
   kjsort();
   kjvulhand(0,i);
   kjvulhand(1,h);
   for(x=0;x<4;x++) {
   i->h[1][x].wi=1;
   i->h[2][x].wi=2;
   h->h[1][x].wi=2;
   h->h[2][x].wi=1; }
   return(troef);
}

