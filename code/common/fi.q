/ ===== Fixed Income library =====
/ Conventions: rates and yields in %, prices in % of nominal, time in years (simplified ACT/365.25)
/ Everything below is defined in the .fi namespace.
\d .fi

/ interp[x;y;t]: linear interpolation of y over the grid x at points t, flat extrapolation at both ends
/ (bin finds the left grid point, clamped to a valid segment; the weight w is clamped to [0,1])
interp:{[x;y;t] i:0|(count[x]-2)&x bin t; w:0f|1f&(t-x i)%(x i+1)-x i; (y i)+w*(y i+1)-y i}

/ sched[vd;mat;f]: coupon dates, built backwards from maturity every 12/f months
/ returns next (future coupon dates after vd) and prev (last coupon date on or before vd)
sched:{[vd;mat;f]
  n:2+floor f*(mat-vd)%365.25;                    / number of dates to generate (with a safety margin)
  d:asc .Q.addmonths[mat;neg (12 div f)*til n];   / maturity, maturity-12/f months, ... sorted ascending
  `next`prev!(d where d>vd; last d where d<=vd)}

/ cashflows[vd;b]: future cashflows of a bond (b: one row of the reference data): times, amounts, accrued coupon
cashflows:{[vd;b]
  s:sched[vd;b`maturity;b`freq];
  c:b[`coupon]%b`freq;                            / coupon amount per period
  t:(s[`next]-vd)%365.25;                         / time to each future cashflow, in years
  a:c*(vd-s`prev)%first[s`next]-s`prev;           / accrued coupon, pro rata of the current period
  `t`cf`accr!(t;@[count[t]#c;count[t]-1;+;100f];a)}  / amounts: a coupon on each date, plus 100 of principal on the last one

/ pxzero[cfs;tenors;zeros]: clean price from a zero curve (continuous compounding)
/ discount factor exp(-r*t), with r interpolated on the curve; dirty sum minus accrued
pxzero:{[cfs;tenors;zeros] t:cfs`t; df:exp neg 0.01*t*interp[tenors;zeros;t]; (sum cfs[`cf]*df)-cfs`accr}

/ pxyld[cfs;f;y]: clean price from a yield to maturity (compounded f times a year)
pxyld:{[cfs;f;y] (sum cfs[`cf]*(1+0.01*y%f) xexp neg f*cfs`t)-cfs`accr}

/ dpdy[cfs;f;y]: derivative of the price with respect to the yield (per percentage point)
dpdy:{[cfs;f;y] sum neg 0.01*cfs[`cf]*cfs[`t]*(1+0.01*y%f) xexp neg 1+f*cfs`t}

/ yield from the clean price: Newton's method, 8 iterations starting from 4%
/ step: one Newton step y - (P(y)-px)/P'(y)
step:{[cfs;f;px;y] y-(pxyld[cfs;f;y]-px)%dpdy[cfs;f;y]}
/ yld: apply step 8 times (n f/ x) starting from 4f
yld:{[cfs;f;px] 8 step[cfs;f;px]/ 4f}

/ back to the root namespace
\d .

/ ===== Risk measures (step 11) =====
\d .fi

/ pxdirty[cfs;f;y]: dirty price = clean price + accrued coupon
pxdirty:{[cfs;f;y] pxyld[cfs;f;y]+cfs`accr}

/ d2pdy2[cfs;f;y]: second derivative of the price with respect to the yield (per percentage point squared)
d2pdy2:{[cfs;f;y] sum 0.0001*cfs[`cf]*cfs[`t]*(cfs[`t]+1%f)*(1+0.01*y%f) xexp neg 2+f*cfs`t}

/ moddur[cfs;f;y]: modified duration (years)
moddur:{[cfs;f;y] neg 100*dpdy[cfs;f;y]%pxdirty[cfs;f;y]}

/ convex[cfs;f;y]: convexity (years squared)
convex:{[cfs;f;y] 10000*d2pdy2[cfs;f;y]%pxdirty[cfs;f;y]}

/ dv01[cfs;f;y]: DV01: loss in currency per 1 million of nominal if the yield rises by 1 bp
dv01:{[cfs;f;y] neg 100*dpdy[cfs;f;y]}

/ back to the root namespace
\d .
