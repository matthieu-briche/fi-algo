/ ===== Feed obligataire simulé : courbes OU -> prix et rendements de 12 govies -> STP =====
system "l ",getenv[`KDBAPPCODE],"/common/fi.q";

/ --- paramètres ---
tenors:0.5 1 2 5 10 30f
theta:`USD`EUR!(3.70 3.60 3.50 3.65 4.05 4.60;1.95 1.95 2.00 2.25 2.65 3.10)  / niveaux d'équilibre (%)
crv:theta                                  / courbes courantes
kappa:0.001                              / force de rappel par tick
siglvl:0.3                              / vol du choc commun (pb/tick)
sigidio:0.1                           / vol idiosyncratique par point (pb/tick)
issuerspr:`UST`DBR`FRTR!0 0 0.70         / spread émetteur (%)
venues:`USD`EUR!(`BTEC`TW`BBG;`MTS`TW`BBG)
ptrade:0.3                               / probabilité d'un trade par tick
nt:0

/ --- référentiel et flux (calculés pour la journée) ---
bonds:("SSSSFDDJS";enlist",") 0: hsym `$getenv[`KDBAPPCONFIG],"/refdata/bonds.csv"
bonds:update yrs:(maturity-.z.d)%365.25 from bonds
bonds:update hs:0.004*yrs xexp 0.75, spr:issuerspr issuer from bonds   / demi-fourchette en prix, spread
cfs:bonds[`sym]!.fi.cashflows[.z.d] each bonds

/ --- outils ---
nrand:{(cos 2*acos[-1]*x?1f)*sqrt neg 2*log 1-x?1f}   / Box-Muller
rnd:{0.001*floor 0.5+1000*x}                           / prix au millième
mid:{[s] i:bonds[`sym]?s; .fi.pxzero[cfs s;tenors;bonds[i;`spr]+crv bonds[i;`curve]]}

/ --- dynamique des courbes ---
evolve:{
  c:first nrand 1;
  crv::{[c;th;zz] zz+(kappa*th-zz)+0.01*(siglvl*c)+sigidio*nrand count zz}[c]'[theta;crv];}

/ --- publications ---
pubquotes:{
  s:neg[1+rand 4]?bonds`sym;
  i:bonds[`sym]?s;
  m:mid each s;
  bid:rnd m-bonds[i;`hs]; ask:rnd m+bonds[i;`hs];
  f:bonds[i;`freq];
  byl:.fi.yld'[cfs s;f;bid]; ayl:.fi.yld'[cfs s;f;ask];
  n:count s;
  src:{rand venues x} each bonds[i;`curve];
  neg[tph](".u.upd";`quote;(s;bid;ask;byl;ayl;5f*1+n?10;5f*1+n?10;src));}

pubtrade:{
  if[ptrade<rand 1f; :()];
  i:rand count bonds; s:bonds[i;`sym];
  side:rand `buy`sell;
  px:rnd $[side=`buy; mid[s]+bonds[i;`hs]; mid[s]-bonds[i;`hs]];
  yl:.fi.yld[cfs s;bonds[i;`freq];px];
  neg[tph](".u.upd";`trade;(enlist s;enlist px;enlist yl;enlist 1f*1+rand 25;enlist side;enlist rand venues bonds[i;`curve]));}

pubcurve:{
  c:key crv;
  neg[tph](".u.upd";`curve;(raze (count tenors)#'c; raze (count c)#enlist tenors; raze value crv));}

fitick:{evolve[]; pubquotes[]; pubtrade[]; nt::nt+1; if[0=nt mod 5; pubcurve[]];}

/ --- connexion au tickerplant via le service de découverte, puis un tick toutes les 200 ms ---
.servers.startupdepcycles[`segmentedtickerplant;10;0W];
tph:.servers.gethandlebytype[`segmentedtickerplant;`any]
.timer.repeat[.proc.cp[];0Wp;0D00:00:00.200;(`fitick;`);"Publish FI feed"];