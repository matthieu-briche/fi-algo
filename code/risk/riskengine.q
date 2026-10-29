/ ===== Moteur de risque : logique pure, sans aucune connexion (testable hors de TorQ) =====
\d .risk

/ charge les données statiques ; cfg : dossier de configuration (texte), vd : date de valorisation
init:{[cfg;vd]
  b:("SSSSFDDJS";enlist",") 0: hsym `$cfg,"/refdata/bonds.csv";
  p:("SF";enlist",") 0: hsym `$cfg,"/refdata/positions.csv";
  `.risk.bonds set b;
  `.risk.cfs set b[`sym]!.fi.cashflows[vd] each b;             / flux de chaque titre
  `.risk.freq set b[`sym]!b`freq;                               / fréquence des coupons
  `.risk.nominal set (b[`sym]!count[b]#0f),p[`sym]!p`nominal;   / nominal en millions (0 si absent)
  `.risk.ccy set b[`sym]!b`ccy;                                 / devise
  `.risk.bucket set b[`sym]!`$2_'string b`sym;                  / maturité : US10Y -> 10Y
  reset[];
  }

/ vide l'état : une ligne par titre, son dernier risque connu
reset:{[] `.risk.book set ([sym:`symbol$()] time:`timestamp$(); mid:`float$(); yld:`float$(); moddur:`float$(); convex:`float$(); dv01:`float$(); nominal:`float$(); posdv01:`float$());}

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

/ vues pour le trader (DV01 de position : perte en devise si les taux montent de 1 pb)
bybucket:{[] select dv01:sum posdv01 by ccy:.risk.ccy sym, bucket:.risk.bucket sym from .risk.book}
total:{[] select dv01:sum posdv01, nominal:sum nominal by ccy:.risk.ccy sym from .risk.book}

/ photo du risque au format de la table risk (sans la colonne time, ajoutée par le tickerplant)
snapshot:{[] b:0!.risk.book; (b`sym; .risk.ccy b`sym; .risk.bucket b`sym; b`mid; b`yld; b`moddur; b`convex; b`dv01; b`nominal; b`posdv01)}

\d .