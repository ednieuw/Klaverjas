/* ************************************************************************ */
/*                                                                          */
/*  Programma : KLAVERJAS	Versie : RL 1.0				    */
/*  Modulenaam: KJAS.H							    */
/*  Door      : R. Loggen                                                   */
/*                                                                          */
/*  Deze module bevat main functie voor het programma KJ		    */
/*                                                                          */
/* ************************************************************************ */

#define STAFEL	  177
#define KTAFEL	   32
#define SKAART	  177
#define KKAART	   64
#define KSCHOP	    7
#define KHART	   12
#define KKLAVER	   14
#define KRUIT	    9

#define getrandom( min, max ) ((rand() % (int)(((max)+1) - (min))) + (min))

struct kaart {
   char k;		/* 0 = schop 1 = hart 3 = klaver 4= ruit */
   char n;		/* A  T   H   V   B   9   8   7 */
   char p;		/* 11 10  4   3   2   0   0   0 */
   char r;		/* 8   7  6   5   4   3   2   1 */
   char wi;		/* -1 = gespeeld  0 = onbekend 1 = ik 2 = hij */
   char wa;		/* 0 = hand  1 = tafel 2 = bedekt */
   char s;		/* Z = zekere slag B = blokker */
};

struct kljas {
   char b;		/* 0 = ik begon robber 1 = hij begon robber */
   char w;		/* 0 = ik geef 1= hij geeft */
   char n;		/* 0 = ik geef 1= hij geeft */
   char t;		/* troef */
   struct kaart s[4];	/* slag */
   long h[12][2];	/* statestiek huidige spel */
   long p[12][10];	/* statestiek totaal
			   0-1 huidige robber
			   2-3 win
			   4-5 verlies
			   6-7 mars
			   8-9 nat */
};

struct dek {
   struct kaart d[4][8];
   struct kaart h[4][8];
};

struct hand {
   struct kaart k[4][8];
   struct kaart h[4][8];
   char b[4];
};
