/* ************************************************************************ */
/*                                                                          */
/*  Programma : KLAVERJAS	Versie : RL 1.0				    */
/*  Modulenaam: KJ.C							    */
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
#include "kj1.h"
#include "kj2.h"

void kjbekenjn();
void kjdelen();
void kjprkaart(char k,char n,char h,unsigned char c,unsigned char r);
void kjprstat(int u,int max,char w,char h,char *l,int *p,int k,struct hand *d);
void kjpuntslag(int *p,int *r);
void kjsort(void);
void kjspel();
void kjspelen(void);
void kjstart(void);
void kjstatspel(void);
void kjvulhand(char w,struct hand *d);
char kjwieslag(void);

extern struct kljas kj;
extern int VRAGER;

extern struct dek *s;
extern struct hand *i;
extern struct hand *h;

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

void kjbekenjn()
{
   char wie,k,s,x;

   wie=0;
   if(kj.s[0].wi > 0) {
      s=0;
      k=kj.s[0].k;
      wie=kj.s[0].wi;
      for(x=1;x<4;x++) {
	 if(kj.s[x].k != k && kj.s[x].wa == 0) {
	    if(kj.s[x].wi == 1) h->b[k]=1;
	    else i->b[k]=1;
	 }
	 if(kj.s[x].r > kj.s[s].r) {
	    if(kj.s[x].k == kj.t || kj.s[x].k == k) {
	       s=x;
	       wie=kj.s[x].wi;
	    }
	 } else {
	    if(kj.s[x].k != k && kj.s[x].wa == 0) {
	       if(wie != kj.s[x].wi && kj.s[x].k != kj.t) {
		  if(kj.s[s].k != kj.t) {
		     if(kj.s[x].wi == 1) h->b[kj.t]=1;
		     else i->b[kj.t]=1;
		  }
	       }
	    }
	 }
      }
   }
}

void kjdelen()
{
   int m,n,x,y,x1,x2,x3,x4,x5,x6;

   kj.w=VRAGER-1;
   kj.n=kj.w;
   memset(kj.s,0,4*sizeof(struct kaart));
   for(y=0;y<4;y++) {
      i->b[y]=0;
      h->b[y]=0;
      for(x=0;x<8;x++) {
	 memset(&s->h[y][x],0,sizeof(struct kaart));
	 memset(&i->k[y][x],0,sizeof(struct kaart));
	 memset(&h->k[y][x],0,sizeof(struct kaart));
	 memset(&i->h[y][x],0,sizeof(struct kaart));
	 memset(&h->h[y][x],0,sizeof(struct kaart));
	 memset(&s->d[y][x],0,sizeof(struct kaart));
	 s->d[y][x].k=(char)y;
	 switch(x) {
	    case 0: s->d[y][x].n='A'; s->d[y][x].p=11; s->d[y][x].r=8; break;
	    case 1: s->d[y][x].n='T'; s->d[y][x].p=10; s->d[y][x].r=7; break;
	    case 2: s->d[y][x].n='H'; s->d[y][x].p=4; s->d[y][x].r=6; break;
	    case 3: s->d[y][x].n='V'; s->d[y][x].p=3; s->d[y][x].r=5; break;
	    case 4: s->d[y][x].n='B'; s->d[y][x].p=2; s->d[y][x].r=4; break;
	    case 5: s->d[y][x].n='9'; s->d[y][x].p=0; s->d[y][x].r=3; break;
	    case 6: s->d[y][x].n='8'; s->d[y][x].p=0; s->d[y][x].r=2; break;
	    case 7: s->d[y][x].n='7'; s->d[y][x].p=0; s->d[y][x].r=1; break;
	 }
      }
   }

   x1=x2=x5=x6=0;
   x3=x4=4;

    for(x=0;x<4;x++) {
        for(y=0;y<8;y++) {
                  switch (y) {
                  case 0: n=0; break;
                  case 1: n=2; break;
                  case 2: n=3; break;
                  case 3: n=4; break;
                  case 4: n=1; break;
                  case 5: n=5; break;
                  case 6: n=6; break;
                  case 7: n=7; break;
		 }
                  m=kaart[x*8+y].DichtIkHy;
                  switch(m) {
             case 1:
                  s->d[x][n].wi=1;
		  s->d[x][n].wa=0;
                  memcpy(&s->h[0][x1++],&s->d[x][n],sizeof(struct kaart));
                  break;
             case 2:
                  s->d[x][n].wi=2;
		  s->d[x][n].wa=0;
                  memcpy(&s->h[2][x2++],&s->d[x][n],sizeof(struct kaart));
                  break;
             case 3:
                  s->d[x][n].wi=1;
		  s->d[x][n].wa=1;
                  memcpy(&s->h[1][x3++],&s->d[x][n],sizeof(struct kaart));
                  break;
             case 4:
                  s->d[x][n].wi=2;
		  s->d[x][n].wa=1;
                  memcpy(&s->h[3][x4++],&s->d[x][n],sizeof(struct kaart));
                   break;
             case 33:
                  s->d[x][n].wi=1;
		  s->d[x][n].wa=2;
                  memcpy(&s->h[1][x5++],&s->d[x][n],sizeof(struct kaart));
                   break;
             case 44:
                  s->d[x][n].wi=2;
		  s->d[x][n].wa=2;
                  memcpy(&s->h[3][x6++],&s->d[x][n],sizeof(struct kaart));
                   break;

                  }

         }
      }

 kjsort();
}




/*
void kjprkaart(char k,char n,char h,unsigned char c,unsigned char r)
{
   unsigned char krt[3][5];
   unsigned char kl;

   if(h == 3 || h == 4) {
      if(h == 3) {
	 char_string(krt[0],1,SKAART);
	 char_string(krt[1],1,SKAART);
	 char_string(krt[2],4,SKAART);
	 kl=KKAART;
      } else {
	 char_string(krt[0],1,STAFEL);
	 char_string(krt[1],1,STAFEL);
	 char_string(krt[2],4,STAFEL);
	 kl=KTAFEL;
      }
      display(krt[0],(unsigned char)(c+4),(unsigned char)(r+1),kl);
      display(krt[1],(unsigned char)(c+4),(unsigned char)(r+2),kl);
      display(krt[2],(unsigned char)(c+1),(unsigned char)(r+3),kl);
      h=2;
   } else if(h == 5) {
      char_string(krt[0],4,STAFEL);
      char_string(krt[1],1,STAFEL);
      char_string(krt[2],1,STAFEL);
      kl=KTAFEL;
      display(krt[0],c,r,kl);
      display(krt[1],c,(unsigned char)(r+1),kl);
      display(krt[2],c,(unsigned char)(r+2),kl);
      h=1;
      r++;
      c++;
   }
   if(h == 0) {
      char_string(krt[0],4,STAFEL);
      char_string(krt[1],4,STAFEL);
      char_string(krt[2],4,STAFEL);
      kl=KTAFEL;
   } else if(h == 1) {
      char_string(krt[0],4,SKAART);
      char_string(krt[1],4,SKAART);
      char_string(krt[2],4,SKAART);
      kl=KKAART;
   } else if(h == 2) {
      char_string(krt[0],4,32);
      char_string(krt[2],4,32);
      if(n == 'A' || n == 'H' || n == 'V' || n == 'B') strcpy(krt[1]," ±± ");
      else char_string(krt[1],4,32);
      switch(k) {
	 case 0: krt[0][1]=6; kl=KSCHOP; break;
	 case 1: krt[0][1]=3; kl=KHART; break;
	 case 2: krt[0][1]=5; kl=KKLAVER; break;
	 case 3: krt[0][1]=4; kl=KRUIT; break;
      }
      krt[2][2]=n;
   }
   display(krt[0],c,r,kl);
   display(krt[1],c,(unsigned char)(r+1),kl);
   display(krt[2],c,(unsigned char)(r+2),kl);
}





void kjprstat(int u,int max,char w,char h,char *l,int *p,int k,struct hand *d)
{
   unsigned char row,col;
   int x,y;

   char_string(reg,55,STAFEL);
   display(reg,3,3,KTAFEL);
   display(reg,3,7,KTAFEL);
   display(reg,3,14,KTAFEL);
   display(reg,3,19,KTAFEL);
   if(max > 1) {
      if(u == 0) {
	 if(w == 1) row=3;
	 else row=19;
	 for(x=0,col=5;x<8;x++,col+=6) {
	    if(p[x] == -999) continue;
	    sprintf(reg,"%4d%c",p[x],d->h[0][x].s);
	    if(k == x) display(reg,col,row,KKAART);
	    else display(reg,col,row,KTAFEL);
	 }
	 if(w == 1) row=7;
	 else row=14;
	 for(x=8,col=14;x<12;x++,col+=8) {
	    if(p[x] == -999) continue;
	    sprintf(reg,"%4d%c",p[x],d->h[1][x-8].s);
	    if(k == x) display(reg,col,row,KKAART);
	    else display(reg,col,row,KTAFEL);
	 }
      } else {
	 if(h == 1) {
	    if(w == 0) row=14;
	    else row=7;
	    for(x=0;x<max;x++) {
	       sprintf(reg,"%4d%c",p[x],d->h[1][l[x]].s);
	       if(l[x] == l[k]) display(reg,(unsigned char)(14+l[x]*8),row,KKAART);
	       else display(reg,(unsigned char)(14+l[x]*8),row,KTAFEL);
	    }
	 } else {
	    if(w == 0) row=19;
	    else row=3;
	    for(x=0;x<max;x++) {
	       sprintf(reg,"%4d%c",p[x],d->h[0][l[x]].s);
	       if(l[x] == l[k]) display(reg,(unsigned char)(5+l[x]*6),row,KKAART);
	       else display(reg,(unsigned char)(5+l[x]*6),row,KTAFEL);
	    }
	 }
      }
      rlmenutoets();
   }
   char_string(reg,55,STAFEL);
   display(reg,3,3,KTAFEL);
   display(reg,3,7,KTAFEL);
   display(reg,3,14,KTAFEL);
   display(reg,3,19,KTAFEL);
}
*/

void kjpuntslag(int *pt,int *rm)
{
   char r[4][9];
   char g[] = "\x0\x1\x2\x4\x5\x6\x3\x7";
   char t[] = "\x0\x1\x5\x6\x3\x7\x2\x4";
   int x,y,z;

   for(y=0;y<4;y++) char_string(r[y],8,' ');
   for(x=0,*pt=0;x<4;x++) {
      if(kj.s[x].wi > 0) {
	 *pt+=kj.s[x].p;
	 if(kj.s[x].r > 8) r[kj.s[x].k][t[kj.s[x].r-9]]=1;
	 else r[kj.s[x].k][g[kj.s[x].r-1]]=1;
      }
   }
   for(y=0,*rm=0;y<4;y++) {
      for(x=0,z=0;x<8;x++) {
	 if(y == kj.t) {
	    if(r[y][x] == 32) z=0;
	    else {
	       z++;
	       if(z == 2 && x == 6) *rm+=20;
	       else if(z == 3) {
		  if(x == 6) *rm+=40;
		  else *rm+=20;
	       } else if(z == 4) {
		  if(x == 6) *rm+=50;
		  else *rm+=30;
	       }
	    }
	 } else {
	    if(r[y][x] == 32) z=0;
	    else {
	       z++;
	       if(z == 3) *rm+=20;
	       else if(z == 4) *rm+=30;
	    }
	 }
      }
   }
}

void kjsort(void)
{
    int x,y,ii,hh;

    for(y=0,ii=0,hh=0;y<4;y++) {
      for(x=0;x<8;x++) {
	 if(s->d[y][x].wi > 0 && s->d[y][x].wa == 0) {
	    if(s->d[y][x].wi == 1) memcpy(&s->h[0][ii++],&s->d[y][x],sizeof(struct kaart));
	    else memcpy(&s->h[2][hh++],&s->d[y][x],sizeof(struct kaart));
	 }
      }
   }
   for(y=0,ii=0,hh=0;y<4;y++) {
      for(x=0;x<8;x++) {
	 if(i->k[y][x].wi == 1) memcpy(&i->h[0][ii++],&i->k[y][x],sizeof(struct kaart));
	 if(h->k[y][x].wi == 1) memcpy(&h->h[0][hh++],&h->k[y][x],sizeof(struct kaart));
      }
   }
}
/*
void kjspel()
{
   char wie;
   int slag;

   wie=kj.w;
   for(slag=0;slag<8;slag++) {
      memset(kj.s,0,4*sizeof(struct kaart));
      kjtafel(1,s);
      if(kj.w == 0) {
	 if(rljas == 0) kj.w=kjuitkom0(0,s,i);
	 else kj.w=kj1uitkom0(0,s,i);
      } else {
	 if(kjnivo == 0) kj.w=kj1uitkom0(1,s,h);
	 else if(kjnivo == 1) kj.w=kj2uitkom0(1,s,h);
      }
      switch(kj.w) {
	 case 0:
	    kj.w=1;
	    kjtafel(1,s);
	    if(kjnivo == 0) kj1uitkom1(3,s,h);
	    else if(kjnivo == 1) kj2uitkom1(3,s,h);
	    kj.w=0;
	    kjtafel(1,s);
	    if(rljas == 0) kjuitkom2(1,s,i);
	    else kj1uitkom2(1,s,i);
	    kj.w=1;
	    kjtafel(1,s);
	    if(kjnivo == 0) kj1uitkom3(2,s,h);
	    else if(kjnivo == 1) kj2uitkom3(2,s,h);
	    break;
	 case 1:
	    kj.w=1;
	    kjtafel(1,s);
	    if(kjnivo == 0) kj1uitkom1(3,s,h);
	    else if(kjnivo == 1) kj2uitkom1(3,s,h);
	    kj.w=0;
	    kjtafel(1,s);
	    if(rljas == 0) kjuitkom2(0,s,i);
	    else kj1uitkom2(0,s,i);
	    kj.w=1;
	    kjtafel(1,s);
	    if(kjnivo == 0) kj1uitkom3(2,s,h);
	    else if(kjnivo == 1) kj2uitkom3(2,s,h);
	    break;
	 case 2:
	    kj.w=0;
	    kjtafel(1,s);
	    if(rljas == 0) kjuitkom1(1,s,i);
	    else kj1uitkom1(1,s,i);
	    kj.w=1;
	    kjtafel(1,s);
	    if(kjnivo == 0) kj1uitkom2(3,s,h);
	    else if(kjnivo == 1) kj2uitkom2(3,s,h);
	    kj.w=0;
	    kjtafel(1,s);
	    if(rljas == 0) kjuitkom3(0,s,i);
	    else kj1uitkom3(0,s,i);
	    break;
	 case 3:
	    kj.w=0;
	    kjtafel(1,s);
	    if(rljas == 0) kjuitkom1(1,s,i);
	    else kj1uitkom1(1,s,i);
	    kj.w=1;
	    kjtafel(1,s);
	    if(kjnivo == 0) kj1uitkom2(2,s,h);
	    else if(kjnivo == 1) kj2uitkom2(2,s,h);
	    kj.w=0;
	    kjtafel(1,s);
	    if(rljas == 0) kjuitkom3(0,s,i);
	    else kj1uitkom3(0,s,i);
	    break;
      }
      kjtafel(1,s);
      kjmaakslag(slag,s,i,h);
   }
   kj.w=wie;
}

void kjspelen()
{
   int t,sp;

   kj.b=1;
   kj.w;
   sp=0;
   for(;;) {
      if(kj.b == 0) kj.b=1;
      else kj.b=0;
      kj.w=kj.b;
      kj.n=kj.w;
      for(t=0;t<12;t++) kj.p[t][0]=kj.p[t][1]=0;
      for(;;) {
	 for(t=0;t<12;t++) kj.h[t][0]=kj.h[t][1]=0;
	 kj.t=-1;
	 memset(kj.s,0,4*sizeof(struct kaart));
	 kjtafel(3,s);
	 kjtafel(4,s);
	 kjdelen(s,i,h);
	 kj.t=kjtroef(s,i,h);
	 if(kj.t == 27) {
	    t=27;
	    break;
	 }
	 kjtroefstat(s);
	 kjtafel(3,s);
	 kjspel(s,i,h);
	 kjstatspel();
	 kjtafel(4,s);
	 if(rljas == 0 || rljas == 1) {
	    t=kjtoets();
	    if(t == 27) break;
	 }
	 if(kj.p[5][0] >= 1500 || kj.p[5][1] >= 1500) {
	    if(kj.p[5][0] != kj.p[5][1]) {
	       if(kj.p[5][0] > kj.p[5][1]) kj.p[0][2]++;
	       else kj.p[0][3]++;
	       kjtafel(4,s);
	       break;
	    }
	 }
	 if(kj.w == 0) kj.w=1;
	 else kj.w=0;
	 kj.n=kj.w;
      }
      if(t == 27) break;
      if(rljas != 2) {
	 clear_buffer();
	 t=rlmenutoets();
	 if(t == 27) break;
      }
      if(rljas == 2) {
	 ++sp;
	 if(kbhit()) {
	    t=kjtoets();
	    if(t == 27) break;
	 }
	 if(sp == 26) {
	    sp=0;
	    printf("\a");
	    t=kjtoets();
	    if(t == 27) break;
	 }
      }
   }
}
*/




void kjstart(void)
{

   s=calloc(1,sizeof(struct dek));
   i=calloc(1,sizeof(struct hand));
   h=calloc(1,sizeof(struct hand));
   memset(&kj,0,sizeof(kj));
}

void kjstatspel(void)
{
   int x;

   if(kj.w == 0) {
      if(kj.h[5][0] <= kj.h[5][1]) {
	 if(kj.h[5][0] == 0) {
	    kj.h[5][1]+=188;
	    kj.h[1][1]=1;
	    kj.h[3][1]=1;
	    kj.h[4][0]=1;
	 } else {
	    kj.h[5][1]+=kj.h[5][0];
	    kj.h[1][1]=1;
	    kj.h[4][0]=1;
	    kj.h[5][0]=0;
	 }
      } else if(kj.h[5][1] == 0) {
	 kj.h[5][0]+=88;
	 kj.h[1][0]=1;
	 kj.h[3][0]=1;
      } else kj.h[1][0]=1;
   } else {
      if(kj.h[5][1] <= kj.h[5][0]) {
	 if(kj.h[5][1] == 0) {
	    kj.h[5][0]+=188;
	    kj.h[1][0]=1;
	    kj.h[3][0]=1;
	    kj.h[4][1]=1;
	 } else {
	    kj.h[5][0]+=kj.h[5][1];
	    kj.h[1][0]=1;
	    kj.h[4][1]=1;
	    kj.h[5][1]=0;
	 }
      } else if(kj.h[5][0] == 0) {
	 kj.h[5][1]+=88;
	 kj.h[1][1]=1;
	 kj.h[3][1]=1;
      }	else kj.h[1][1]=1;
   }
   for(x=0;x<12;x++) {
      kj.p[x][0]+=kj.h[x][0];
      kj.p[x][1]+=kj.h[x][1];
      if(kj.h[1][0] == 1) {
	 kj.p[x][2]+=kj.h[x][0];
	 kj.p[x][5]+=kj.h[x][1];
      } else {
	 kj.p[x][4]+=kj.h[x][0];
	 kj.p[x][3]+=kj.h[x][1];
      }
      if(kj.h[3][0] == 1) kj.p[x][6]+=kj.h[x][0];
      if(kj.h[4][0] == 1) kj.p[x][8]+=kj.h[x][0];
      if(kj.h[3][1] == 1) kj.p[x][7]+=kj.h[x][1];
      if(kj.h[4][1] == 1) kj.p[x][9]+=kj.h[x][1];
   }
}

void kjvulhand(char w,struct hand *d)
{
   int ww,x,y,z;

   for(y=0,z=0;y<4;y++) {
      for(x=0;x<8;x++) {
	 if(s->d[y][x].wa == 2) continue;
	 if(s->d[y][x].wi != (char)(w+1) && s->d[y][x].wa != 1) continue;
	 if(s->d[y][x].wi != (char)(w+1)) ww=2;
	 else ww=s->d[y][x].wa;
	 memcpy(&d->k[y][x],&s->d[y][x],sizeof(struct kaart));
	 d->k[y][x].wi=(char)(ww+1);
	 if(ww == 0) memcpy(&d->h[0][z++],&d->k[y][x],sizeof(struct kaart));
      }
   }
   if(w == 0) {
      for(x=0;x<4;x++) {
	 memcpy(&d->h[1][x],&s->h[1][x+4],sizeof(struct kaart));
	 d->h[1][x].wi=2;
	 memcpy(&d->h[2][x],&s->h[3][x+4],sizeof(struct kaart));
	 d->h[2][x].wi=3;
      }
   } else {
      for(x=0;x<4;x++) {
	 memcpy(&d->h[2][x],&s->h[1][x+4],sizeof(struct kaart));
	 d->h[2][x].wi=3;
	 memcpy(&d->h[1][x],&s->h[3][x+4],sizeof(struct kaart));
	 d->h[1][x].wi=2;
      }
   }
}

char kjwieslag(void)
{
   char wie,k,s,x;

   wie=0;
   if(kj.s[0].wi > 0) {
      s=0;
      k=kj.s[0].k;
      wie=kj.s[0].wi;
      for(x=1;x<4;x++) {
	 if(kj.s[x].wi > 0) {
	    if(kj.s[x].r > kj.s[s].r) {
	       if(kj.s[x].k == kj.t || kj.s[x].k == k) {
		  s=x;
		  wie=kj.s[x].wi;
	       }
	    }
	 }
      }
   }
   return(--wie);
}
