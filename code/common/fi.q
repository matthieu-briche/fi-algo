/ ===== Bibliothèque Fixed Income =====
/ Conventions : taux et rendements en %, prix en % du nominal, temps en années (ACT/365.25 simplifié)
\d .fi

/ interpolation linéaire, extrapolation plate aux extrémités
interp:{[x;y;t] i:0|(count[x]-2)&x bin t; w:0f|1f&(t-x i)%(x i+1)-x i; (y i)+w*(y i+1)-y i}

/ dates de coupon : à rebours depuis la maturité, tous les 12/f mois
sched:{[vd;mat;f]
  n:2+floor f*(mat-vd)%365.25;
  d:asc .Q.addmonths[mat;neg (12 div f)*til n];
  `next`prev!(d where d>vd; last d where d<=vd)}

/ flux futurs d'un titre (b : ligne du référentiel) : temps, montants, coupon couru
cashflows:{[vd;b]
  s:sched[vd;b`maturity;b`freq];
  c:b[`coupon]%b`freq;
  t:(s[`next]-vd)%365.25;
  a:c*(vd-s`prev)%first[s`next]-s`prev;
  `t`cf`accr!(t;@[count[t]#c;count[t]-1;+;100f];a)}

/ prix clean à partir d'une courbe zéro (composition continue)
pxzero:{[cfs;tenors;zeros] t:cfs`t; df:exp neg 0.01*t*interp[tenors;zeros;t]; (sum cfs[`cf]*df)-cfs`accr}

/ prix clean à partir d'un rendement actuariel (composition f fois par an)
pxyld:{[cfs;f;y] (sum cfs[`cf]*(1+0.01*y%f) xexp neg f*cfs`t)-cfs`accr}

/ dérivée du prix par rapport au rendement (par point de %)
dpdy:{[cfs;f;y] sum neg 0.01*cfs[`cf]*cfs[`t]*(1+0.01*y%f) xexp neg 1+f*cfs`t}

/ rendement à partir du prix clean : Newton, 8 itérations depuis 4 %
step:{[cfs;f;px;y] y-(pxyld[cfs;f;y]-px)%dpdy[cfs;f;y]}
yld:{[cfs;f;px] 8 step[cfs;f;px]/ 4f}

\d .

/ ===== Mesures de risque (étape 11) =====
\d .fi

/ prix dirty = prix clean + coupon couru
pxdirty:{[cfs;f;y] pxyld[cfs;f;y]+cfs`accr}

/ dérivée seconde du prix par rapport au rendement (par point de % au carré)
d2pdy2:{[cfs;f;y] sum 0.0001*cfs[`cf]*cfs[`t]*(cfs[`t]+1%f)*(1+0.01*y%f) xexp neg 2+f*cfs`t}

/ duration modifiée (années)
moddur:{[cfs;f;y] neg 100*dpdy[cfs;f;y]%pxdirty[cfs;f;y]}

/ convexité (années au carré)
convex:{[cfs;f;y] 10000*d2pdy2[cfs;f;y]%pxdirty[cfs;f;y]}

/ DV01 : perte en devise pour 1 million de nominal si le rendement monte de 1 pb
dv01:{[cfs;f;y] neg 100*dpdy[cfs;f;y]}

\d .