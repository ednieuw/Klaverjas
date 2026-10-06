/* ************************************************************************ */
/*                                                                          */
/*  Programma : KLAVERJAS	Versie : RL 1.0				    */
/*  Modulenaam: KJ1.C							    */
/*  Door      : R. Loggen                                                   */
/*                                                                          */
/*  Deze module bevat nivo 1 functie voor het programma KJ		    */
/*                                                                          */
/* ************************************************************************ */

#include <conio.h>
#include <ctype.h>
#include <graphic.h>
#include <keyboard.h>
#include <malloc.h>
#include <memory.h>
#include <screen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include "kjas.h"
#include "kj.h"
#include "kj0.h"
#include "rl00.h"

char kj1troef(struct deck *s,struct hand *i);
char kj1uitkom0(char h,struct deck *s,struct hand *d);
void kj1uitkom1(char h,struct deck *s,struct hand *d);
void kj1uitkom2(char h,struct deck *s,struct hand *d);
void kj1uitkom3(char h,struct deck *s,struct hand *d);

extern struct kljas kj;
extern char reg[81];
extern char rljas;		 /* 0=human
				    1=single step
				    2=test */


char kj1troef(struct deck *s,struct hand *i)
{
   int t[4];
   int x,y,z;
   char troef;

   for(x=0;x<4;x++) t[x]=0;
   for(y=0;y<4;y++) {
      memset(i,0,sizeof(struct hand));
      kjvulhand(kj.w,s,i);
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
   return(troef);
}

char kj1uitkom0(char h,struct deck *s,struct hand *d)
{
   char l1[8],l2[8];
   char wie,w,i;
   int p[12],p1[8];
   int max1,max2,t1,t2,k,x,y,kk,z;

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
      kjlegkaarttest(h,0,w,i,s,d);
      if(h == 0) max1=kjlegaal(2,1,l1,d);
      else max1=kjlegaal(2,0,l1,d);
      for(y=0,t1=0;y<max1;y++) {
	 if(h == 0) kjlegkaarttest(1,1,1,l1[y],s,d);
	 else kjlegkaarttest(0,1,1,l1[y],s,d);
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
	       if(h == 0) kjlegkaarttest(0,2,1,l2[x],s,d);
	       else kjlegkaarttest(1,2,1,l2[x],s,d);
	    } else {
	       if(h == 0) kjlegkaarttest(0,2,0,l2[x],s,d);
	       else kjlegkaarttest(1,2,0,l2[x],s,d);
	    }
	    if(d->b[kj.s[0].k] == 0) {
	       for(z=0;z<8;z++) {
		  if(d->k[kj.s[0].k][z].wi == 0) {
		     memcpy(&kj.s[3],&s->d[kj.s[0].k][z],sizeof(struct kaart));
		     kj.s[3].wi=kj.s[1].wi;
		     p1[x]+=kjmaakslagtest(h);
		     ++t2;
		  }
	       }
	    }
	    if(d->b[kj.t] == 0 && kj.s[0].k != kj.t) {
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
	    if(t2 > 0) p1[x]/=t2;
	    else p1[x]=kjmaakslagtest(h);
	 }
	 memset(&kj.s[2],0,sizeof(struct kaart));
	 for(x=1,kk=0;x<max2;x++)
	    if(p1[x] > p1[kk]) kk=x;
	 p[k]+=p1[kk];
	 ++t1;
      }
      p[k]/=t1;
      memset(&kj.s[1],0,sizeof(struct kaart));
   }
   for(x=10,k=11;x>=0;x--)
      if(p[x] > p[k]) k=x;
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
   kjlegkaart(h,0,w,k,s,d);
   return(wie);
}

void kj1uitkom1(char h,struct deck *s,struct hand *d)
{
   char l[8],l1[8],lh[8];
   int p[8],p1[8];
   int w,k,max,max1,maxh,tot,x,xx,y,yy,z,zz;

   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 p[x]=0;
	 kjlegkaarttest(h,1,w,(int)l[x],s,d);
	 z=tot=0;
	 if(kj.s[0].wa == 1) {
	    for(;;) {
	       zz=0;
	       if(d->b[kj.s[0].k] == 0) {
		  for(y=0;y<8;y++) {
		     if(d->k[kj.s[0].k][y].wi == 0) {
			zz++;
			memcpy(&kj.s[2],&s->d[kj.s[0].k][y],sizeof(struct kaart));
			if(zz > z) break;
		     }
		  }
	       }
	       if(d->b[kj.t] == 0 && kj.s[0].k != kj.t && zz <= z) {
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
		     if(d->b[0] == 0 && d->k[0][y].wi == 0) {
			memcpy(&kj.s[2],&s->d[0][y],sizeof(struct kaart));
			break;
		     }
		     if(d->b[1] == 0 && d->k[1][y].wi == 0) {
			memcpy(&kj.s[2],&s->d[1][y],sizeof(struct kaart));
			break;
		     }
		     if(d->b[2] == 0 && d->k[2][y].wi == 0) {
			memcpy(&kj.s[2],&s->d[2][y],sizeof(struct kaart));
			break;
		     }
		     if(d->b[3] == 0 && d->k[3][y].wi == 0) {
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
	 p[x]/=tot;
	 memset(&kj.s[2],0,sizeof(struct kaart));
	 memset(&kj.s[3],0,sizeof(struct kaart));
      }
      for(x=1,k=0;x<max;x++)
	 if(p[x] > p[k]) k=x;
   } else k=0;
   k=l[k];
   kjlegkaart(h,1,w,k,s,d);
}

void kj1uitkom2(char h,struct deck *s,struct hand *d)
{
   char l[8];
   int	p[8];
   int w,k,max,tot,x,y;

   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 p[x]=0;
	 tot=0;
	 kjlegkaarttest(h,2,w,(int)l[x],s,d);
	 if(d->b[kj.s[0].k] == 0) {
	    for(y=0;y<8;y++) {
	       if(d->k[kj.s[0].k][y].wi == 0) {
		  memcpy(&kj.s[3],&s->d[kj.s[0].k][y],sizeof(struct kaart));
		  kj.s[3].wi=kj.s[1].wi;
		  p[x]+=kjmaakslagtest(h);
		  ++tot;
	       }
	    }
	 }
	 if(d->b[kj.t] == 0 && kj.s[0].k != kj.t) {
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
	 if(tot > 0) p[x]/=tot;
	 else p[x]=kjmaakslagtest(h);
      }
      if(kj.s[0].k == kj.t) {
	 for(x=1,k=0;x<max;x++)
	    if(p[x] > p[k]) k=x;
      } else {
	 for(x=0,k=-1;x<max;x++) {
	    if(k == -1 && d->h[w][l[x]].k != kj.t) k=x;
	    if(k > -1 && p[x] > p[k]) k=x;
	 }
	 if(k == -1 || p[k] < 0) {
	    for(x=1,k=0;x<max;x++)
	       if(p[x] > p[k]) k=x;
	 }
      }
   } else k=0;
   k=l[k];
   kjlegkaart(h,2,w,k,s,d);
}

void kj1uitkom3(char h,struct deck *s,struct hand *d)
{
   char l[8];
   int	p[8];
   int w,k,max,x;

   if(h == 0 || h == 2) w=0;
   else w=1;
   if(h < 2) h=0;
   else h=1;
   max=kjlegaal((char)w,h,l,d);
   if(max > 1) {
      for(x=0;x<max;x++) {
	 kjlegkaarttest(h,3,w,(int)l[x],s,d);
	 p[x]=kjmaakslagtest(h);
      }
      if(kj.s[0].k == kj.t) {
	 for(x=1,k=0;x<max;x++)
	    if(p[x] > p[k]) k=x;
      } else {
	 for(x=0,k=-1;x<max;x++) {
	    if(k == -1 && d->h[w][l[x]].k != kj.t) k=x;
	    if(k > -1 && p[x] > p[k]) k=x;
	 }
	 if(k == -1 || p[k] < 0) {
	    for(x=1,k=0;x<max;x++)
	       if(p[x] > p[k]) k=x;
	 }
      }
   } else k=0;
   k=l[k];
   kjlegkaart(h,3,w,k,s,d);
}
