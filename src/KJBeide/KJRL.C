#include "kjrljas.h"
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

void kjbeken(void);
void kjbekenjn(struct hand *d);
int  kjlegaal(char h,char w,char *l,struct hand *d);
void kjlegkaart(char h,int n,int w,int e,struct hand *d);
void kjlegkaarttest(char h,int n,int w,int e);
void kjmaakslag(int slag);
int  kjmaakslagtest(char wie);
void kjmaaktroef(char troef,struct kaart k[4][8],struct kaart h[4][8]);
void kjpuntslag(int *p,int *r);
void kjsort(void);
void kjstatus(struct hand *d);
char kjtroef(void);
char kjuitkom0(char h,struct hand *d);
void kjuitkom1(char h,struct hand *d);
void kjuitkom2(char h,struct hand *d);
void kjuitkom3(char h,struct hand *d);
void kjvulhand(char w,struct hand *d);
int  kjwelke(int w,int max,int *p,char *l,struct hand *d);
char kjwieslag(void);
void kjdelen(void);
void kjstart(void);

extern struct kljas kj;
extern int VRAGER;

extern struct  dek *s;
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
extern int TROEF;
extern int VRAGER;
extern int SLAGKRTNO;
extern int Lkaart;
extern int Lkleur;


void kjbeken()
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

void kjbekenjn(struct hand *d)
{
   char k[4];
   char kh,khmax;
   char x,y;

   for(y=0;y<8;y++)
      if(d->h[0][y].wi == 0) break;
   kh=y;
   for(y=0,khmax=0;y<4;y++) {
      if(d->b[y] == 2) d->b[y]=0;
      k[y]=0;
      for(x=0;x<8;x++)
	 if(d->k[y][x].wi == 0) ++k[y];
      if(k[y] == 0) d->b[y]=1;
      if(d->b[y] != 1) khmax+=k[y];
   }
   for(y=0;y<4;y++)
      if(khmax-k[y] < kh && d->b[y] != 1) d->b[y]=2;
}

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


void kjlegkaarttest(char h,int n,int w,int e)
{
   if(w == 0) {
      if(h == 0) memcpy(&kj.s[n],&s->h[0][e],sizeof(struct kaart));
      else memcpy(&kj.s[n],&s->h[2][e],sizeof(struct kaart));
   } else {
      if(h == 0) memcpy(&kj.s[n],&s->h[1][e+4],sizeof(struct kaart));
      else memcpy(&kj.s[n],&s->h[3][e+4],sizeof(struct kaart));
   }
}

void kjmaakslag()
{
   int k,n;
   int x;

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
   kjbeken();
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

void kjsort()
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

void kjstatus(struct hand *d)
{
   char st,x,y,z,zz;

   for(y=0;y<8;y++) {
      d->h[0][y].s=0;
      d->h[1][y].s=0;
   }
   for(y=0;y<4;y++) {
      for(x=0;x<8;x++) {
	 for(z=0,zz=0;z<4;z++)
	    if(kj.s[z].k == y && kj.s[z].n == s->d[y][x].n) zz=1;
	 if(d->k[y][x].wi == 0 && zz == 0) break;
	 if(d->k[y][x].wi == 1 || d->k[y][x].wi == 2) {
	    if(y == kj.t) st='Z';
	    else if(d->b[kj.t] == 1) st='Z';
	    else if(kj.n == 1) st='B';
	    else break;
	    if(d->k[y][x].wi == 1) {
	       for(z=0;z<8;z++) {
		  if(d->h[0][z].k == y && d->k[y][x].n == d->h[0][z].n) {
		     d->h[0][z].s=st;
		     break;
		  }
	       }
	    } else {
	       for(z=0;z<4;z++) {
		  if(d->h[1][z].k == y && d->k[y][x].n == d->h[1][z].n) {
		     d->h[1][z].s=st;
		     break;
		  }
	       }
	    }
	 } else if(d->k[y][x].wi == 3 && zz == 0) break;
      }
   }
}

char kjtroef()
{
   int t[4];
   int trh,trt,p1,p2,x,y,z;
   char troef;
   if(kj.w==0)
   {
   for(x=0;x<4;x++) t[x]=0;
   for(y=0;y<4;y++) {
      memset(i,0,sizeof(struct hand));
      kjvulhand(kj.w,i);
      kjmaaktroef((char)y,i->k,i->h);
      for(x=0;x<8;x++) {
	 switch(i->k[y][x].wi) {
	    case 1:
	       t[y]+=i->k[y][x].p;
	       break;
	    case 2:
	       t[y]+=i->k[y][x].p;
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
      for(x=0;x<4;x++) {
	 trh=trt=0;
	 p1=p2=0;
	 for(z=0;z<8;z++) {
	    switch(i->k[x][z].wi) {
	       case 1:
		  if(x == y) ++trh;
		  else if(z == 0) p1+=200;
		  else if(z == 1) p1+=100;
		  else if(z == 2) p1+=20;
		  else p1+=i->k[x][z].r;
		  break;
	       case 2:
		  if(x == y) ++trt;
		  else if(z == 0) p2+=200;
		  else if(z == 1) p2+=100;
		  else if(z == 2) p2+=20;
		  else p2+=i->k[x][z].r;
		  break;
	    }
	 }
	 if(x == y) t[y]+=trh*trh+trt*trt;
	 if(p1 >= 320) t[y]+=6;
	 else if(p1 >= 300) t[y]+=5;
	 else if(p1 >= 220) t[y]+=4;
	 else if(p1 >= 200) t[y]+=3;
	 else if(p1 > 100) t[y]+=1;
	 if(p2 >= 320) t[y]+=6;
	 else if(p2 >= 300) t[y]+=5;
	 else if(p2 >= 220) t[y]+=4;
	 else if(p2 >= 200) t[y]+=3;
	 else if(p2 > 100) t[y]+=1;
      }
   }
   troef=0;
   for(x=1;x<4;x++)
      if(t[x] > t[troef]) troef=(char)x;
   }
   else troef=(char)TROEF;

   memset(i,0,sizeof(struct hand));
   kjmaaktroef(troef,s->d,s->h);
   kjsort();
   kjvulhand(0,i);
   kjvulhand(1,h);
   for(x=0;x<4;x++) {
      i->h[1][x].wi=1;
      i->h[2][x].wi=2;
      h->h[1][x].wi=2;
      h->h[2][x].wi=1;
   }
   return(troef);
}

char kjuitkom0(char h,struct hand *d)
{
   char l1[8],l2[8];
   char wie,w,i;
   int p[12],p1[8],p2[4];
   int max1,max2,t2,k,x,y,kk,z;

   kjbekenjn(d);
   kjstatus(d);
   for(k=0,i=0,w=0;k<12;k++,i++) {
      p[k]=0;
      if(i == 8) {
	 i=0;
	 w=1;
      }
      if(w == 1 && i == 4) break;
      if(d->h[w][i].wi < 1) {
	 p[k]=-999;
	 continue;
      }
      kjlegkaarttest(h,0,w,i);
      if(h == 0) max1=kjlegaal(2,1,l1,d);
      else max1=kjlegaal(2,0,l1,d);
      for(y=0;y<max1;y++) {
	 p2[y]=0;
	 if(h == 0) kjlegkaarttest(1,1,1,l1[y]);
	 else kjlegkaarttest(0,1,1,l1[y]);
	 if(w == 0) {
	    if(h == 0) max2=kjlegaal(1,0,l2,d);
	    else max2=kjlegaal(1,1,l2,d);
	 } else {
	    if(h == 0) max2=kjlegaal(0,0,l2,d);
	    else max2=kjlegaal(0,1,l2,d);
	 }
	 for(x=0;x<max2;x++) {
	    p1[x]=0;
	    t2=0;
	    if(w == 0) {
	       if(h == 0) kjlegkaarttest(0,2,1,l2[x]);
	       else kjlegkaarttest(1,2,1,l2[x]);
	    } else {
	       if(h == 0) kjlegkaarttest(0,2,0,l2[x]);
	       else kjlegkaarttest(1,2,0,l2[x]);
	    }
	    if(d->b[kj.s[0].k] != 1) {
	       for(z=0;z<8;z++) {
		  if(d->k[kj.s[0].k][z].wi == 0) {
		     memcpy(&kj.s[3],&s->d[kj.s[0].k][z],sizeof(struct kaart));
		     kj.s[3].wi=kj.s[1].wi;
		     p1[x]+=kjmaakslagtest(h);
		     ++t2;
		  }
	       }
	    }
	    if(d->b[kj.t] != 1 && kj.s[0].k != kj.t && d->b[kj.s[0].k] != 2) {
	       for(z=0;z<8;z++) {
		  if(d->k[kj.t][z].wi == 0) {
		     memcpy(&kj.s[3],&s->d[kj.t][z],sizeof(struct kaart));
		     kj.s[3].wi=kj.s[1].wi;
		     p1[x]+=kjmaakslagtest(h);
		     ++t2;
		  }
	       }
	    }
	    memset(&kj.s[3],0,sizeof(struct kaart));
	    if(t2 > 0) p1[x]=p1[x]*10/t2;
	    else p1[x]=kjmaakslagtest(h)*10;
	 }
	 memset(&kj.s[2],0,sizeof(struct kaart));
	 for(x=1,kk=0;x<max2;x++)
	    if(p1[x] > p1[kk]) kk=x;
	 p2[y]=p1[kk];
      }
      for(x=1,kk=0;x<max1;x++)
	 if(p2[x] < p2[kk]) kk=x;
      p[k]=p2[kk];
      memset(&kj.s[1],0,sizeof(struct kaart));
   }
   if(d->b[kj.t] == 1) {
      for(x=11,z=0,w=1,k=0,kk=3;x>=0;x--,kk--) {
	 if(x == 7) {
	    w=0;
	    kk=7;
	 }
	 if(d->h[w][kk].k != kj.t) {
	    if(p[x] > p[k] || z == 0) {
	       k=x;
	       z=1;
	    }
	 }
      }
   } else z=0;
   if(z == 0 || p[k] <= 0) {
      for(x=10,k=11;x>=0;x--)
	 if(p[x] > p[k]) k=x;
   }
   if(k < 8) {
      if(h == 0) wie=0;
      else wie=2;
      w=0;
   } else {
      if(h == 0) wie=1;
      else wie=3;
      w=1;
      k-=8;
   }
   kjlegkaart(h,0,w,k,d);
   if(wie==0) VRAGER=1; else VRAGER=3;

   return(wie);
}

void kjuitkom1(char h,struct hand *d)
{
   char l[8],l1[8],lh[8];
   int p[8],p1[8];
   int w,k,max,max1,maxh,tot,x,xx,y,yy,z,zz;

   kjbekenjn(d);
   kjstatus(d);
   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 p[x]=0;
	 kjlegkaarttest(h,1,w,(int)l[x]);
	 z=tot=0;
	 if(kj.s[0].wa == 1) {
	    for(;;) {
	       zz=0;
	       if(d->b[kj.s[0].k] != 1) {
		  for(y=0;y<8;y++) {
		     if(d->k[kj.s[0].k][y].wi == 0) {
			zz++;
			memcpy(&kj.s[2],&s->d[kj.s[0].k][y],sizeof(struct kaart));
			if(zz > z) break;
		     }
		  }
	       }
	       if(d->b[kj.t] != 1 && kj.s[0].k != kj.t && zz <= z && d->b[kj.s[0].k] != 2) {
		  for(y=0;y<8;y++) {
		     if(d->k[kj.t][y].wi == 0) {
			zz++;
			memcpy(&kj.s[2],&s->d[kj.t][y],sizeof(struct kaart));
			if(zz > z) break;
		     }
		  }
	       }
	       if(z > 0 && zz <= z) break;
	       if(zz == 0) {
		  for(y=7;y>=0;y--) {
		     if(d->b[0] != 1 && d->k[0][y].wi == 0) {
			memcpy(&kj.s[2],&s->d[0][y],sizeof(struct kaart));
			break;
		     }
		     if(d->b[1] != 1 && d->k[1][y].wi == 0) {
			memcpy(&kj.s[2],&s->d[1][y],sizeof(struct kaart));
			break;
		     }
		     if(d->b[2] != 1 && d->k[2][y].wi == 0) {
			memcpy(&kj.s[2],&s->d[2][y],sizeof(struct kaart));
			break;
		     }
		     if(d->b[3] != 1 && d->k[3][y].wi == 0) {
			memcpy(&kj.s[2],&s->d[3][y],sizeof(struct kaart));
			break;
		     }
		  }
	       }
	       kj.s[2].wi=kj.s[0].wi;
	       max1=kjlegaal(0,h,l1,d);
	       for(xx=0;xx<max1;xx++) {
		  p1[xx]=0;
		  memcpy(&kj.s[3],&d->h[0][l1[xx]],sizeof(struct kaart));
		  kj.s[3].wi=kj.s[1].wi;
		  p1[xx]=kjmaakslagtest(h);
	       }
	       memset(&kj.s[3],0,sizeof(struct kaart));
	       for(xx=1,k=0;xx<max1;xx++)
		  if(p1[xx] > p1[k]) k=xx;
	       tot++;
	       p[x]+=p1[k];
	       if(z == zz) break;
	       else z=zz;
	    }
	 } else {
	    maxh=kjlegaal(2,kj.s[0].wi,lh,d);
	    for(yy=0;yy<maxh;yy++) {
	       memcpy(&kj.s[2],&d->h[2][lh[yy]],sizeof(struct kaart));
	       kj.s[2].wi=kj.s[0].wi;
	       max1=kjlegaal(0,h,l1,d);
	       for(xx=0;xx<max1;xx++) {
		  p1[xx]=0;
		  memcpy(&kj.s[3],&d->h[0][l1[xx]],sizeof(struct kaart));
		  kj.s[3].wi=kj.s[1].wi;
		  p1[xx]=kjmaakslagtest(h);
	       }
	       for(xx=1,k=0;xx<max1;xx++)
		  if(p1[xx] > p1[k]) k=xx;
	       tot++;
	       p[x]+=p1[k];
	       memset(&kj.s[3],0,sizeof(struct kaart));
	    }
	 }
	 p[x]=p[x]*10/tot;
	 memset(&kj.s[2],0,sizeof(struct kaart));
	 memset(&kj.s[3],0,sizeof(struct kaart));
      }
      k=kjwelke(w,max,p,l,d);
   } else k=0;
   k=l[k];
   kjlegkaart(h,1,w,k,d);
}

void kjuitkom2(char h,struct hand *d)
{
   char l[8];
   int	p[8];
   int w,k,max,tot,x,y;

   kjstatus(d);
   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 p[x]=0;
	 tot=0;
	 kjlegkaarttest(h,2,w,(int)l[x]);
	 if(d->b[kj.s[0].k] != 1) {
	    for(y=0;y<8;y++) {
	       if(d->k[kj.s[0].k][y].wi == 0) {
		  memcpy(&kj.s[3],&s->d[kj.s[0].k][y],sizeof(struct kaart));
		  kj.s[3].wi=kj.s[1].wi;
		  p[x]+=kjmaakslagtest(h);
		  ++tot;
	       }
	    }
	 }
	 if(d->b[kj.t] != 1 && kj.s[0].k != kj.t && d->b[kj.s[0].k] != 2) {
	    for(y=0;y<8;y++) {
	       if(d->k[kj.t][y].wi == 0) {
		  memcpy(&kj.s[3],&s->d[kj.t][y],sizeof(struct kaart));
		  kj.s[3].wi=kj.s[1].wi;
		  p[x]+=kjmaakslagtest(h);
		  ++tot;
	       }
	    }
	 }
	 memset(&kj.s[3],0,sizeof(struct kaart));
	 if(tot > 0) p[x]=p[x]*10/tot;
	 else p[x]=kjmaakslagtest(h)*10;
      }
      k=kjwelke(w,max,p,l,d);
   } else k=0;
   k=l[k];
   kjlegkaart(h,2,w,k,d);
}

void kjuitkom3(char h,struct hand *d)
{
   char l[8];
   int	p[8];
   int w,k,max,x;

   kjstatus(d);
   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 kjlegkaarttest(h,3,w,(int)l[x]);
	 p[x]=kjmaakslagtest(h)*10;
      }
      k=kjwelke(w,max,p,l,d);
   } else k=0;
   k=l[k];
   kjlegkaart(h,3,w,k,d);
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

int kjwelke(int w,int max,int *p,char *l,struct hand *d)
{
   int g,k=-1,x;

   if(kj.s[0].k == kj.t) {
      for(x=0,g=0,k=0;x<max;x++) {
	 if(d->h[w][l[x]].s == 0 && kj.n == 1) {
	    if(p[x] > p[k] || x == 0 || g == 0) {
	       k=x;
	       g=1;
	    }
	 }
      }
      if(g == 0 || p[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(d->h[w][l[x]].s != 'Z') {
	       if(p[x] > p[k] || x == 0 || g == 0) {
		  k=x;
		  g=1;
	       }
	       if(p[x] == p[k] && d->h[w][l[k]].r > d->h[w][l[x]].r) {
		  k=x;
		  g=1;
	       }
	    }
	 }
      }
      if(g == 0 || p[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(p[x] > p[k] || x == 0 || g == 0) {
		k=x;
		g=1;
	    }
	    if(p[x] == p[k] && d->h[w][l[k]].r < d->h[w][l[x]].r) {
	       k=x;
	       g=1;
	    }
	 }
      }
   } else {
      for(x=0,g=0,k=0;x<max;x++) {
	 if(d->h[w][l[x]].s == 0 && d->h[w][l[x]].k != kj.t && kj.n == 1) {
	    if(p[x] > p[k] || x == 0 || g == 0) {
	       k=x;
	       g=1;
	    }
	 }
      }
      if(g == 0 || p[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(d->h[w][l[x]].s != 'Z' && d->h[w][l[x]].k != kj.t) {
	       if(p[x] > p[k] || x == 0 || g == 0) {
		  k=x;
		  g=1;
	       }
	       if(p[x] == p[k] && d->h[w][l[k]].r > d->h[w][l[x]].r) {
		  k=x;
		  g=1;
	       }
	    }
	 }
      }
      if(g == 0 || p[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(d->h[w][l[x]].s != 'Z') {
	       if(p[x] > p[k] || x == 0 || g == 0) {
		  k=x;
		  g=1;
	       }
	       if(p[x] == p[k] && d->h[w][l[k]].r > d->h[w][l[x]].r) {
		  k=x;
		  g=1;
	       }
	    }
	 }
      }
      if(g == 0 || p[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(p[x] > p[k] || x == 0 || g == 0) {
		k=x;
		g=1;
	    }
	    if(p[x] == p[k] && d->h[w][l[k]].r < d->h[w][l[x]].r) {
	       k=x;
	       g=1;
	    }
	 }
      }
   }
   return(k);
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

void kjdelen(void)
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



void kjstart(void)
{

   s=calloc(1,sizeof(struct dek));
   i=calloc(1,sizeof(struct hand));
   h=calloc(1,sizeof(struct hand));
   memset(&kj,0,sizeof(kj));
}
