/ ===== Process risk1 : branchement du moteur de risque sur la plateforme TorQ =====
system "l ",getenv[`KDBAPPCODE],"/common/fi.q";
system "l ",getenv[`KDBAPPCODE],"/risk/riskengine.q";

\d .risk
tptypes:@[value;`tptypes;`segmentedtickerplant];
.servers.CONNECTIONS:tptypes;

/ abonnement aux quotes, une fois le tickerplant trouvé par l'annuaire
subscribe:{[]
  .servers.startupdepcycles[tptypes;10;0W];
  if[count s:.sub.getsubscriptionhandles[tptypes;();()!()];
    .lg.o[`subscribe;"tickerplant trouvé, abonnement aux quotes"];
    .sub.subscribe[`quote;`;0b;0b;first s];
    ];
  }
  
/ publie une photo du risque vers le tickerplant (table risk)
pub:{[] if[count .risk.book; neg[.risk.tph](".u.upd";`risk;.risk.snapshot[])];}

\d .

.risk.init[getenv`KDBAPPCONFIG;.z.d];
upd:.risk.upd;
.servers.startup[];
.risk.subscribe[];

.risk.tph:.servers.gethandlebytype[`segmentedtickerplant;`any];
.timer.repeat[.proc.cp[];0Wp;0D00:00:05;(`.risk.pub;`);"Publication du risque"];