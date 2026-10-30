/ ===== risk1 process: plugging the risk engine into the TorQ platform =====
/ Loads the pure risk logic, subscribes to quotes from the segmented tickerplant,
/ and publishes a risk snapshot back to the tickerplant (risk table) every 5 seconds.

/ Load the fixed-income library (.fi namespace) and the risk engine (.risk namespace)
system "l ",getenv[`KDBAPPCODE],"/common/fi.q";
system "l ",getenv[`KDBAPPCODE],"/risk/riskengine.q";

/ Switch to the .risk namespace
\d .risk
/ Tickerplant process type(s) to use: the value of tptypes if already defined (e.g. by config), otherwise the default
/ (@[value;...;default] is a protected evaluation that returns the default if the lookup fails)
tptypes:@[value;`tptypes;`segmentedtickerplant];
/ Tell TorQ's discovery service which process types this process must connect to
.servers.CONNECTIONS:tptypes;

/ subscribe[]: subscribe to quotes once the tickerplant has been found through the discovery service
subscribe:{[]
  .servers.startupdepcycles[tptypes;10;0W];                    / wait for the tickerplant, retrying every 10 s, no attempt limit (0W)
  if[count s:.sub.getsubscriptionhandles[tptypes;();()!()];    / get handles of matching processes (any name, no attribute filter); proceed if at least one
    .lg.o[`subscribe;"tickerplant trouvé, abonnement aux quotes"];  / info log message
    .sub.subscribe[`quote;`;0b;0b;first s];                    / subscribe to the quote table, all syms (`), don't set schema (0b), don't replay the log (0b), on the first process found
    ];
  }
  
/ pub[]: publish a risk snapshot to the tickerplant (risk table), only if the book is not empty
pub:{[] if[count .risk.book; neg[.risk.tph](".u.upd";`risk;.risk.snapshot[])];}

/ Back to the root namespace
\d .

/ Load static data (bonds, cashflows, positions) from the config folder, valued as of today
.risk.init[getenv`KDBAPPCONFIG;.z.d];
/ The tickerplant calls the root-level upd function, so point it to the risk engine's handler
upd:.risk.upd;
/ Start TorQ connection management (connects to the process types listed in .servers.CONNECTIONS)
.servers.startup[];
/ Subscribe to quotes
.risk.subscribe[];

/ Handle to the tickerplant, used by .risk.pub to publish the risk table
.risk.tph:.servers.gethandlebytype[`segmentedtickerplant;`any];
/ Repeating timer: start now, never end (0Wp), every 5 seconds, calling .risk.pub with a null argument
.timer.repeat[.proc.cp[];0Wp;0D00:00:05;(`.risk.pub;`);"Publication du risque"];
