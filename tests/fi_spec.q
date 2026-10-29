/ Specs de la bibliothèque Fixed Income (code/common/fi.q)
/ À lancer depuis la racine de fiapp
system "l code/common/fi.q";

/ --- données de test : date de valorisation figée pour la reproductibilité ---
.fitest.vd:2026.10.28;
.fitest.bonds:("SSSSFDDJS";enlist",") 0: `:appconfig/refdata/bonds.csv;
.fitest.b10:first select from .fitest.bonds where sym=`US10Y;
.fitest.c10:.fi.cashflows[.fitest.vd;.fitest.b10];
.fitest.tn:0.5 1 2 5 10 30f;

.tst.desc["Interpolation .fi.interp"]{
  should["retrouver les valeurs aux points de la grille"]{
    .fi.interp[.fitest.tn;1 2 3 4 5 6f;.fitest.tn] mustmatch 1 2 3 4 5 6f;
    };
  should["interpoler linéairement entre deux points"]{
    .fi.interp[.fitest.tn;1 2 3 4 5 6f;1.5 7f] mustmatch 2.5 4.4;
    };
  should["extrapoler à plat hors de la grille"]{
    .fi.interp[.fitest.tn;1 2 3 4 5 6f;0.1 40f] mustmatch 1 6f;
    };
  };

.tst.desc["Échéancier .fi.sched"]{
  should["finir à la maturité, avec des dates futures et croissantes"]{
    s:.fi.sched[.fitest.vd;2036.11.15;2];
    last[s`next] musteq 2036.11.15;
    (s[`next]~asc s`next) musteq 1b;
    all[s[`next]>.fitest.vd] musteq 1b;
    };
  should["placer le coupon précédent 6 mois avant le suivant (semestriel)"]{
    s:.fi.sched[.fitest.vd;2036.11.15;2];
    s[`prev] musteq .Q.addmonths[first s`next;-6];
    (s[`prev]<=.fitest.vd) musteq 1b;
    };
  };

.tst.desc["Flux .fi.cashflows"]{
  should["générer 21 flux pour un 10 ans semestriel"]{
    count[.fitest.c10`t] musteq 21;
    };
  should["verser les coupons puis le nominal à maturité"]{
    (-1_.fitest.c10`cf) mustmatch 20#2.125;
    last[.fitest.c10`cf] musteq 102.125;
    };
  should["avoir un coupon couru compris entre 0 et un coupon"]{
    .fitest.c10[`accr] mustwithin 0 2.125;
    };
  };

.tst.desc["Prix et rendement .fi.pxyld / .fi.yld"]{
  should["valoriser au pair un titre dont le rendement égale le coupon"]{
    .fi.pxyld[.fitest.c10;2;4.25] mustwithin 99.98 100.02;
    };
  should["faire baisser le prix quand le rendement monte"]{
    p:.fi.pxyld[.fitest.c10;2] each 1 3 5 7f;
    (p~desc p) musteq 1b;
    };
  should["avoir une dérivée analytique égale à la différence finie"]{
    yv:4.25; h:1e-4;
    fd:(.fi.pxyld[.fitest.c10;2;yv+h]-.fi.pxyld[.fitest.c10;2;yv-h])%2*h;
    abs[fd-.fi.dpdy[.fitest.c10;2;yv]] mustlt 1e-5;
    };
  should["retrouver le rendement à partir du prix (aller-retour Newton)"]{
    ys:0.5 2 4.25 8 12f;
    ps:.fi.pxyld[.fitest.c10;2] each ys;
    max[abs ys-.fi.yld[.fitest.c10;2] each ps] mustlt 1e-8;
    };
  should["converger pour les 12 titres du référentiel"]{
    cs:.fi.cashflows[.fitest.vd] each .fitest.bonds;
    f:.fitest.bonds`freq;
    ps:.fi.pxyld'[cs;f;3f];
    max[abs 3f-.fi.yld'[cs;f;ps]] mustlt 1e-8;
    };
  };

.tst.desc["Prix sur courbe zéro .fi.pxzero"]{
  should["égaler le prix au rendement semestriel équivalent sur une courbe plate"]{
    r:4.25;
    yeq:200*exp[0.005*r]-1;
    abs[.fi.pxzero[.fitest.c10;.fitest.tn;6#r]-.fi.pxyld[.fitest.c10;2;yeq]] mustlt 1e-9;
    };
  should["valoriser à la somme des flux moins le couru avec des taux nuls"]{
    .fi.pxzero[.fitest.c10;.fitest.tn;6#0f] mustwithin (sum[.fitest.c10`cf]-.fitest.c10`accr)+-1e-9 1e-9;
    };
  };
  
.tst.desc["Mesures de risque .fi.moddur / .fi.convex / .fi.dv01"]{
  should["donner la duration exacte d'un zéro-coupon : t/(1+y/(100f))"]{
    zc:`t`cf`accr!(enlist 5f;enlist 100f;0f);
    abs[.fi.moddur[zc;2;4f]-5%1.02] mustlt 1e-9;
    };
  should["donner la convexité exacte d'un zéro-coupon : t(t+1/f)/(1+y/(100f))²"]{
    zc:`t`cf`accr!(enlist 5f;enlist 100f;0f);
    abs[.fi.convex[zc;2;4f]-(5*5.5)%1.02*1.02] mustlt 1e-9;
    };
  should["avoir une dérivée seconde égale à la différence finie"]{
    yv:4.25; h:0.01; p:.fi.pxyld[.fitest.c10;2];
    fd:(p[yv+h]+p[yv-h]-2*p yv)%h*h;
    abs[fd-.fi.d2pdy2[.fitest.c10;2;yv]] mustlt 1e-5;
    };
  should["vérifier l'identité DV01 = duration × prix dirty"]{
    yv:4.25;
    abs[.fi.dv01[.fitest.c10;2;yv]-.fi.moddur[.fitest.c10;2;yv]*.fi.pxdirty[.fitest.c10;2;yv]] mustlt 1e-9;
    };
  should["approcher un choc de 50 pb par Taylor à l'ordre 2, bien mieux qu'à l'ordre 1"]{
    yv:4.25; dy:0.005; p:.fi.pxdirty[.fitest.c10;2];
    exact:(p[yv+100*dy]%p yv)-1;
    d:.fi.moddur[.fitest.c10;2;yv]; c:.fi.convex[.fitest.c10;2;yv];
    e1:abs exact+d*dy;
    e2:abs exact-(neg d*dy)+0.5*c*dy*dy;
    e2 mustlt 1e-4;
    (e2<e1%10) musteq 1b;
    };
  };