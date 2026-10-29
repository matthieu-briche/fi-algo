/ ===== Moteur de risque temps réel : rendement mid, duration, convexité, DV01, risque du portefeuille =====
system "l ",getenv[`KDBAPPCODE],"/common/fi.q";

\d .risk

/ --- 1. connexions : le tickerplant, trouvé par l'annuaire ---
tptypes:@[value;`tptypes;`segmentedtickerplant];
.servers.CONNECTIONS:tptypes;

/ --- 2. données statiques, chargées au démarrage ---
bonds:("SSSSFDDJS";enlist",") 0: hsym `$getenv[`KDBAPPCONFIG],"/refdata/bonds.csv";
pos:("SF";enlist",") 0: hsym `$getenv[`KDBAPPCONFIG],"/refdata/positions.csv";
cfs:bonds[`sym]!.fi.cashflows[.z.d] each bonds;                / flux de chaque titre
freq:bonds[`sym]!bonds`freq;                                    / fréquence des coupons
nominal:(bonds[`sym]!count[bonds]#0f),pos[`sym]!pos`nominal;    / nominal en millions (0 si absent)
ccy:bonds[`sym]!bonds`ccy;                                      / devise
bucket:bonds[`sym]!`$2_'string bonds`sym;                       / maturité : US10Y -> 10Y

/ --- 3. état : le dernier risque connu de chaque titre ---
book:([sym:`symbol$()] time:`timestamp$(); mid:`float$(); yld:`float$(); moddur:`float$(); convex:`float$(); dv01:`float$(); nominal:`float$(); posdv01:`float$());

/ recalcule le risque des titres présents dans un lot de quotes
upd1:{[q]
  q:0!select by sym from q;                                     / dernière quote de chaque titre
  s:q`sym; m:0.5*q[`bid]+q`ask;                                 / prix mid
  c:cfs s; f:freq s;
  yl:.fi.yld'[c;f;m];                                           / rendement mid
  dur:.fi.moddur'[c;f;yl]; cv:.fi.convex'[c;f;yl]; dv:.fi.dv01'[c;f;yl];
  n:nominal s;
  `.risk.book upsert flip `sym`time`mid`yld`moddur`convex`dv01`nominal`posdv01!(s;q`time;m;yl;dur;cv;dv;n;dv*n);
  }

/ appelée par le tickerplant à chaque lot de données
upd:{[t;d] if[t~`quote; upd1 d];}

/ --- 4. vues pour le trader (DV01 de position : perte en devise si les taux montent de 1 pb) ---
bybucket:{[] select dv01:sum posdv01 by ccy:.risk.ccy sym, bucket:.risk.bucket sym from .risk.book}
total:{[] select dv01:sum posdv01, nominal:sum nominal by ccy:.risk.ccy sym from .risk.book}

/ --- 5. abonnement aux quotes ---
subscribe:{[]
  .servers.startupdepcycles[tptypes;10;0W];
  if[count s:.sub.getsubscriptionhandles[tptypes;();()!()];
    .lg.o[`subscribe;"tickerplant trouvé, abonnement aux quotes"];
    .sub.subscribe[`quote;`;0b;0b;first s];
    ];
  }

\d .

upd:.risk.upd;
.servers.startup[];
.risk.subscribe[];