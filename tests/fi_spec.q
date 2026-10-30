/ Specs for the Fixed Income library (code/common/fi.q), qspec test framework
/ Run from the fiapp root folder
system "l code/common/fi.q";                 / library under test (.fi namespace)

/ --- test data: valuation date frozen for reproducibility ---
.fitest.vd:2026.10.28;                                                     / valuation date
.fitest.bonds:("SSSSFDDJS";enlist",") 0: `:appconfig/refdata/bonds.csv;    / bond reference table
.fitest.b10:first select from .fitest.bonds where sym=`US10Y;              / US 10-year row, as a dictionary
.fitest.c10:.fi.cashflows[.fitest.vd;.fitest.b10];                         / its cashflows
.fitest.tn:0.5 1 2 5 10 30f;                                               / curve tenors

/ --- linear interpolation ---
.tst.desc["Interpolation .fi.interp"]{
  should["retrouver les valeurs aux points de la grille"]{
    .fi.interp[.fitest.tn;1 2 3 4 5 6f;.fitest.tn] mustmatch 1 2 3 4 5 6f;     / grid points give back their own values
    };
  should["interpoler linéairement entre deux points"]{
    .fi.interp[.fitest.tn;1 2 3 4 5 6f;1.5 7f] mustmatch 2.5 4.4;            / 1.5y between 1y and 2y; 7y between 5y and 10y
    };
  should["extrapoler à plat hors de la grille"]{
    .fi.interp[.fitest.tn;1 2 3 4 5 6f;0.1 40f] mustmatch 1 6f;              / before the first / after the last point: end values
    };
  };

/ --- coupon schedule ---
.tst.desc["Échéancier .fi.sched"]{
  should["finir à la maturité, avec des dates futures et croissantes"]{
    s:.fi.sched[.fitest.vd;2036.11.15;2];                                    / semi-annual bond maturing 15 Nov 2036
    last[s`next] musteq 2036.11.15;                                          / last date is the maturity
    (s[`next]~asc s`next) musteq 1b;                                         / dates are in ascending order
    all[s[`next]>.fitest.vd] musteq 1b;                                      / and all after the valuation date
    };
  should["placer le coupon précédent 6 mois avant le suivant (semestriel)"]{
    s:.fi.sched[.fitest.vd;2036.11.15;2];
    s[`prev] musteq .Q.addmonths[first s`next;-6];                           / previous coupon = next coupon - 6 months
    (s[`prev]<=.fitest.vd) musteq 1b;                                        / and on or before the valuation date
    };
  };

/ --- cashflows ---
.tst.desc["Flux .fi.cashflows"]{
  should["générer 21 flux pour un 10 ans semestriel"]{
    count[.fitest.c10`t] musteq 21;                                          / 21 remaining semi-annual dates
    };
  should["verser les coupons puis le nominal à maturité"]{
    (-1_.fitest.c10`cf) mustmatch 20#2.125;                                  / 20 coupons of 4.25/2
    last[.fitest.c10`cf] musteq 102.125;                                     / last flow = coupon + 100 of principal
    };
  should["avoir un coupon couru compris entre 0 et un coupon"]{
    .fitest.c10[`accr] mustwithin 0 2.125;                                   / accrued is between 0 and one full coupon
    };
  };

/ --- price/yield conversions ---
.tst.desc["Prix et rendement .fi.pxyld / .fi.yld"]{
  should["valoriser au pair un titre dont le rendement égale le coupon"]{
    .fi.pxyld[.fitest.c10;2;4.25] mustwithin 99.98 100.02;                   / yield = coupon -> clean price at par
    };
  should["faire baisser le prix quand le rendement monte"]{
    p:.fi.pxyld[.fitest.c10;2] each 1 3 5 7f;                                / prices for increasing yields
    (p~desc p) musteq 1b;                                                    / are strictly decreasing
    };
  should["avoir une dérivée analytique égale à la différence finie"]{
    yv:4.25; h:1e-4;
    fd:(.fi.pxyld[.fitest.c10;2;yv+h]-.fi.pxyld[.fitest.c10;2;yv-h])%2*h;     / central finite difference
    abs[fd-.fi.dpdy[.fitest.c10;2;yv]] mustlt 1e-5;                          / matches the analytical derivative
    };
  should["retrouver le rendement à partir du prix (aller-retour Newton)"]{
    ys:0.5 2 4.25 8 12f;                                                     / a range of yields
    ps:.fi.pxyld[.fitest.c10;2] each ys;                                     / yield -> price
    max[abs ys-.fi.yld[.fitest.c10;2] each ps] mustlt 1e-8;                  / price -> yield gives back the start
    };
  should["converger pour les 12 titres du référentiel"]{
    cs:.fi.cashflows[.fitest.vd] each .fitest.bonds;                         / cashflows of every bond
    f:.fitest.bonds`freq;
    ps:.fi.pxyld'[cs;f;3f];                                                  / price of each bond at a 3% yield
    max[abs 3f-.fi.yld'[cs;f;ps]] mustlt 1e-8;                               / Newton recovers 3% for all of them
    };
  };

/ --- pricing on a zero curve ---
.tst.desc["Prix sur courbe zéro .fi.pxzero"]{
  should["égaler le prix au rendement semestriel équivalent sur une courbe plate"]{
    r:4.25;                                                                  / flat continuous zero rate
    yeq:200*exp[0.005*r]-1;                                                  / equivalent semi-annual yield: 2*(exp(r/2)-1), in %
    abs[.fi.pxzero[.fitest.c10;.fitest.tn;6#r]-.fi.pxyld[.fitest.c10;2;yeq]] mustlt 1e-9;  / both prices agree
    };
  should["valoriser à la somme des flux moins le couru avec des taux nuls"]{
    .fi.pxzero[.fitest.c10;.fitest.tn;6#0f] mustwithin (sum[.fitest.c10`cf]-.fitest.c10`accr)+-1e-9 1e-9;  / zero rates: no discounting
    };
  };

/ --- risk measures ---
.tst.desc["Mesures de risque .fi.moddur / .fi.convex / .fi.dv01"]{
  should["donner la duration exacte d'un zéro-coupon : t/(1+y/(100f))"]{
    zc:`t`cf`accr!(enlist 5f;enlist 100f;0f);                                / 5-year zero-coupon: a single flow of 100
    abs[.fi.moddur[zc;2;4f]-5%1.02] mustlt 1e-9;                             / closed form: 5/(1+0.04/2)
    };
  should["donner la convexité exacte d'un zéro-coupon : t(t+1/f)/(1+y/(100f))²"]{
    zc:`t`cf`accr!(enlist 5f;enlist 100f;0f);
    abs[.fi.convex[zc;2;4f]-(5*5.5)%1.02*1.02] mustlt 1e-9;                  / closed form: 5*5.5/1.02^2
    };
  should["avoir une dérivée seconde égale à la différence finie"]{
    yv:4.25; h:0.01; p:.fi.pxyld[.fitest.c10;2];                             / p: price as a function of the yield (projection)
    fd:(p[yv+h]+p[yv-h]-2*p yv)%h*h;                                         / central second difference
    abs[fd-.fi.d2pdy2[.fitest.c10;2;yv]] mustlt 1e-5;                        / matches the analytical second derivative
    };
  should["vérifier l'identité DV01 = duration × prix dirty"]{
    yv:4.25;
    abs[.fi.dv01[.fitest.c10;2;yv]-.fi.moddur[.fitest.c10;2;yv]*.fi.pxdirty[.fitest.c10;2;yv]] mustlt 1e-9;
    };
  should["approcher un choc de 50 pb par Taylor à l'ordre 2, bien mieux qu'à l'ordre 1"]{
    yv:4.25; dy:0.005; p:.fi.pxdirty[.fitest.c10;2];                         / 50 bp shock (dy as a decimal)
    exact:(p[yv+100*dy]%p yv)-1;                                             / exact relative price change
    d:.fi.moddur[.fitest.c10;2;yv]; c:.fi.convex[.fitest.c10;2;yv];
    e1:abs exact+d*dy;                                                       / error of the 1st-order approximation: -D*dy
    e2:abs exact-(neg d*dy)+0.5*c*dy*dy;                                     / error of the 2nd-order approximation: -D*dy + C*dy^2/2
    e2 mustlt 1e-4;                                                          / 2nd order is accurate
    (e2<e1%10) musteq 1b;                                                    / and at least 10 times better than 1st order
    };
  };
