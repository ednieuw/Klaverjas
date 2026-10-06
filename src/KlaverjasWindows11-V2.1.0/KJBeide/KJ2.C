/* ************************************************************************ */
/*                                                                          */
/*  Programma : KLAVERJAS	Versie : RL 1.0				    */
/*  Modulenaam: KJ2.C							    */
/*  Door      : R. Loggen                                                   */
/*                                                                          */
/*  Deze module bevat nivo 2 functie voor het programma KJ		    */
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
#include <graphic.h>

void kj2bekenjn(struct hand *d);
void kj2status(struct hand *d);
char kj2troef(struct hand *i);
char kj2uitkom0(char h,struct hand *d);
void kj2uitkom1(char h,struct hand *d);
void kj2uitkom2(char h,struct hand *d);
void kj2uitkom3(char h,struct hand *d);
int  kj2welke(int w,int max,int *pp,char *l,struct hand *d);


extern struct dek *s;
extern struct hand *i;
extern struct hand *h;
extern int TROEF,VRAGER;

extern struct kljas kj;
extern char reg[81];
extern char rljas;		 /* 0=human
				    1=single step
				    2=test */

void kj2bekenjn(struct hand *d)
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

void kj2status(struct hand *d)
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

char kj2troef(struct hand *i)
{
   int t[4];
   int trh,trt,p1,p2,x,y,z;
   char troef;

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
   return(troef);
}

char kj2uitkom0(char h,struct hand *d)
{
   char l1[8],l2[8];
   char wie,w,i;
   int pp[12],p1[8],p2[4];
   int max1,max2,t2,k,x,y,kk,z;

   kj2bekenjn(d);
   kj2status(d);
   for(k=0,i=0,w=0;k<12;k++,i++) {
      pp[k]=0;
      if(i == 8) {
	 i=0;
	 w=1;
      }
      if(w == 1 && i == 4) break;
      if(d->h[w][i].wi < 1) {
	 pp[k]=-999;
	 continue;
      }
      kjlegkaarttest(h,0,w,i,d);
      if(h == 0) max1=kjlegaal(2,1,l1,d);
      else max1=kjlegaal(2,0,l1,d);
      for(y=0;y<max1;y++) {
	 p2[y]=0;
	 if(h == 0) kjlegkaarttest(1,1,1,l1[y],d);
	 else kjlegkaarttest(0,1,1,l1[y],d);
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
	       if(h == 0) kjlegkaarttest(0,2,1,l2[x],d);
	       else kjlegkaarttest(1,2,1,l2[x],d);
	    } else {
	       if(h == 0) kjlegkaarttest(0,2,0,l2[x],d);
	       else kjlegkaarttest(1,2,0,l2[x],d);
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
      pp[k]=p2[kk];
      memset(&kj.s[1],0,sizeof(struct kaart));
   }
   if(d->b[kj.t] == 1) {
      for(x=11,z=0,w=1,k=0,kk=3;x>=0;x--,kk--) {
	 if(x == 7) {
	    w=0;
	    kk=7;
	 }
	 if(d->h[w][kk].k != kj.t) {
	    if(pp[x] > pp[k] || z == 0) {
	       k=x;
	       z=1;
	    }
	 }
      }
   } else z=0;
   if(z == 0 || pp[k] <= 0) {
      for(x=10,k=11;x>=0;x--)
	 if(pp[x] > pp[k]) k=x;
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

void kj2uitkom1(char h,struct hand *d)
{
   char l[8],l1[8],lh[8];
   int pp[8],p1[8];
   int w,k,max,max1,maxh,tot,x,xx,y,yy,z,zz;

   kj2bekenjn(d);
   kj2status(d);
   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 pp[x]=0;
	 kjlegkaarttest(h,1,w,(int)l[x],d);
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
	       pp[x]+=p1[k];
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
	       pp[x]+=p1[k];
	       memset(&kj.s[3],0,sizeof(struct kaart));
	    }
	 }
	 pp[x]=pp[x]*10/tot;
	 memset(&kj.s[2],0,sizeof(struct kaart));
	 memset(&kj.s[3],0,sizeof(struct kaart));
      }
      k=kj2welke(w,max,pp,l,d);
   } else k=0;
   k=l[k];
   kjlegkaart(h,1,w,k,d);
}

void kj2uitkom2(char h,struct hand *d)
{
   char l[8];
   int	pp[8];
   int w,k,max,tot,x,y;

   kj2status(d);
   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 pp[x]=0;
	 tot=0;
	 kjlegkaarttest(h,2,w,(int)l[x],d);
	 if(d->b[kj.s[0].k] != 1) {
	    for(y=0;y<8;y++) {
	       if(d->k[kj.s[0].k][y].wi == 0) {
		  memcpy(&kj.s[3],&s->d[kj.s[0].k][y],sizeof(struct kaart));
		  kj.s[3].wi=kj.s[1].wi;
		  pp[x]+=kjmaakslagtest(h);
		  ++tot;
	       }
	    }
	 }
	 if(d->b[kj.t] != 1 && kj.s[0].k != kj.t && d->b[kj.s[0].k] != 2) {
	    for(y=0;y<8;y++) {
	       if(d->k[kj.t][y].wi == 0) {
		  memcpy(&kj.s[3],&s->d[kj.t][y],sizeof(struct kaart));
		  kj.s[3].wi=kj.s[1].wi;
		  pp[x]+=kjmaakslagtest(h);
		  ++tot;
	       }
	    }
	 }
	 memset(&kj.s[3],0,sizeof(struct kaart));
	 if(tot > 0) pp[x]=pp[x]*10/tot;
	 else pp[x]=kjmaakslagtest(h)*10;
      }
      k=kj2welke(w,max,pp,l,d);
   } else k=0;
   k=l[k];
   kjlegkaart(h,2,w,k,d);
}

void kj2uitkom3(char h,struct hand *d)
{
   char l[8];
   int	pp[8];
   int w,k,max,x;

   kj2status(d);
   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 kjlegkaarttest(h,3,w,(int)l[x],d);
	 pp[x]=kjmaakslagtest(h)*10;
      }
      k=kj2welke(w,max,pp,l,d);
   } else k=0;
   k=l[k];
   kjlegkaart(h,3,w,k,d);
}

int kj2welke(int w,int max,int *pp,char *l,struct hand *d)
{
   int g,k=-1,x;

   if(kj.s[0].k == kj.t) {
      for(x=0,g=0,k=0;x<max;x++) {
	 if(d->h[w][l[x]].s == 0) {
	    if(pp[x] > pp[k] || x == 0 || g == 0) {
	       k=x;
	       g=1;
	    }
	 }
      }
      if(g == 0 || pp[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(d->h[w][l[x]].s != 'Z') {
	       if(pp[x] > pp[k] || x == 0 || g == 0) {
		  k=x;
		  g=1;
	       }
	       if(pp[x] == pp[k] && d->h[w][l[k]].s != 0 && d->h[w][l[x]].s == 0) {
		  k=x;
		  g=1;
	       }
	    }
	 }
      }
      if(g == 0 || pp[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(pp[x] > pp[k] || x == 0 || g == 0) {
		k=x;
		g=1;
	    }
	    if(pp[x] == pp[k] && d->h[w][l[k]].s != 0 && d->h[w][l[x]].s == 0) {
	       k=x;
	       g=1;
	    }
	 }
      }
   } else {
      for(x=0,g=0,k=0;x<max;x++) {
	 if(d->h[w][l[x]].s == 0 && d->h[w][l[x]].k != kj.t) {
	    if(pp[x] > pp[k] || x == 0 || g == 0) {
	       k=x;
	       g=1;
	    }
	 }
      }
      if(g == 0 || pp[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(d->h[w][l[x]].s != 'Z' && d->h[w][l[x]].k != kj.t) {
	       if(pp[x] > pp[k] || x == 0 || g == 0) {
		  k=x;
		  g=1;
	       }
	       if(pp[x] == pp[k] && d->h[w][l[k]].s != 0 && d->h[w][l[x]].s == 0) {
		  k=x;
		  g=1;
	       }
	    }
	 }
      }
      if(g == 0 || pp[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(d->h[w][l[x]].s != 'Z') {
	       if(pp[x] > pp[k] || x == 0 || g == 0) {
		  k=x;
		  g=1;
	       }
	       if(pp[x] == pp[k] && d->h[w][l[k]].s != 0 && d->h[w][l[x]].s == 0) {
		  k=x;
		  g=1;
	       }
	    }
	 }
      }
      if(g == 0 || pp[k] <= 0) {
	 for(x=0,g=0,k=0;x<max;x++) {
	    if(pp[x] > pp[k] || x == 0 || g == 0) {
		k=x;
		g=1;
	    }
	    if(pp[x] == pp[k] && d->h[w][l[k]].s != 0 && d->h[w][l[x]].s == 0) {
	       k=x;
	       g=1;
	    }
	 }
      }
   }
   return(k);
}
