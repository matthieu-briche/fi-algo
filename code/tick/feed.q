/ ===== Simulated bond feed: OU curves -> prices and yields of 12 govies -> STP =====
/ Every 200 ms, the USD and EUR yield curves evolve as a discretised Ornstein-Uhlenbeck
/ process. Bond prices and yields are derived from them, and quotes, trades and curve
/ snapshots are published to the segmented tickerplant (TorQ framework).
/ Reminder: q evaluates expressions right to left, with no operator precedence.

/ Load the fixed-income library (.fi namespace: cashflows, pxzero, yld)
system "l ",getenv[`KDBAPPCODE],"/common/fi.q";

/ --- parameters ---
tenors:0.5 1 2 5 10 30f                  / curve pillar maturities, in years (f forces float)
theta:`USD`EUR!(3.70 3.60 3.50 3.65 4.05 4.60;1.95 1.95 2.00 2.25 2.65 3.10)  / long-run equilibrium levels (%), one per tenor
crv:theta                                  / current curves, start at equilibrium and are updated every tick
kappa:0.001                              / mean-reversion speed per tick (0.1% of the gap to theta closed each tick)
siglvl:0.3                              / vol of the common (parallel) shock, in bp per tick
sigidio:0.1                           / vol of the idiosyncratic shock per tenor point, in bp per tick
issuerspr:`UST`DBR`FRTR!0 0 0.70         / issuer spread over the curve (%): Treasuries and Bunds 0, OATs +70bp
venues:`USD`EUR!(`BTEC`TW`BBG;`MTS`TW`BBG) / possible trading venues per currency
ptrade:0.3                               / probability of publishing a trade on a given tick
nt:0                                     / tick counter

/ --- reference data and cashflows (computed once for the day) ---
/ Read bonds.csv as a table: column types "SSSSFDDJS" (4 symbols, 1 float, 2 dates, 1 long, 1 symbol),
/ comma separated, first line holds the column names (enlist ",")
bonds:("SSSSFDDJS";enlist",") 0: hsym `$getenv[`KDBAPPCONFIG],"/refdata/bonds.csv"
/ Time to maturity in years (date difference gives days; % is division in q)
bonds:update yrs:(maturity-.z.d)%365.25 from bonds
/ hs: half bid/ask spread in price points, widening with maturity (0.004 * yrs^0.75)
/ spr: issuer spread looked up from the issuerspr dictionary
bonds:update hs:0.004*yrs xexp 0.75, spr:issuerspr issuer from bonds   / half-spread in price, issuer spread
/ Dictionary sym -> future cashflow schedule, built by applying .fi.cashflows (projected on today's date) to each row
cfs:bonds[`sym]!.fi.cashflows[.z.d] each bonds

/ --- helpers ---
/ nrand[n]: n standard normal draws via Box-Muller: cos(2*pi*U1) * sqrt(-2*ln(1-U2)); acos[-1] is pi
nrand:{(cos 2*acos[-1]*x?1f)*sqrt neg 2*log 1-x?1f}   / Box-Muller
/ rnd[x]: round to the nearest 0.001
rnd:{0.001*floor 0.5+1000*x}                           / price rounded to 3 decimals
/ mid[s]: theoretical mid price of bond s, discounting its cashflows on its currency curve
/ (interpolated over tenors) shifted by the issuer spread
mid:{[s] i:bonds[`sym]?s; .fi.pxzero[cfs s;tenors;bonds[i;`spr]+crv bonds[i;`curve]]}

/ --- curve dynamics ---
/ evolve[]: one OU step for each currency curve:
/   new = zz + kappa*(theta-zz) + 0.01*(siglvl*c + sigidio*eps)
/ c is a single common normal shock (shared by USD and EUR, so their level moves are fully correlated),
/ eps is an independent normal per tenor; 0.01 converts bp into %.
/ The lambda is projected on c, then applied each-both (') over theta and crv; :: assigns the global crv.
evolve:{
  c:first nrand 1;                        / one common standard normal shock
  crv::{[c;th;zz] zz+(kappa*th-zz)+0.01*(siglvl*c)+sigidio*nrand count zz}[c]'[theta;crv];}

/ --- publishers ---
/ pubquotes[]: quote 1 to 4 distinct random bonds and send them asynchronously to the quote table
pubquotes:{
  s:neg[1+rand 4]?bonds`sym;               / draw 1-4 distinct syms without replacement
  i:bonds[`sym]?s;                         / their row indices in bonds
  m:mid each s;                            / theoretical mid prices
  bid:rnd m-bonds[i;`hs]; ask:rnd m+bonds[i;`hs];  / bid/ask = mid -/+ half-spread, rounded
  f:bonds[i;`freq];                        / coupon frequencies
  byl:.fi.yld'[cfs s;f;bid]; ayl:.fi.yld'[cfs s;f;ask];  / bid and ask yields from prices
  n:count s;
  src:{rand venues x} each bonds[i;`curve]; / random venue matching each bond's currency
  neg[tph](".u.upd";`quote;(s;bid;ask;byl;ayl;5f*1+n?10;5f*1+n?10;src));}  / async publish; sizes 5-50 in steps of 5; time added by the TP

/ pubtrade[]: with probability ptrade, publish one trade on a random bond, executed across the spread
pubtrade:{
  if[ptrade<rand 1f; :()];                 / exit early unless a uniform draw is below ptrade
  i:rand count bonds; s:bonds[i;`sym];     / pick a random bond
  side:rand `buy`sell;                     / pick a random side
  px:rnd $[side=`buy; mid[s]+bonds[i;`hs]; mid[s]-bonds[i;`hs]];  / buy lifts the ask, sell hits the bid
  yl:.fi.yld[cfs s;bonds[i;`freq];px];     / yield of the traded price
  neg[tph](".u.upd";`trade;(enlist s;enlist px;enlist yl;enlist 1f*1+rand 25;enlist side;enlist rand venues bonds[i;`curve]));}  / one-row columnar update; size 1-25

/ pubcurve[]: publish both curves in long format, one row per (currency, tenor, rate) = 12 rows
pubcurve:{
  c:key crv;                               / `USD`EUR
  neg[tph](".u.upd";`curve;(raze (count tenors)#'c; raze (count c)#enlist tenors; raze value crv));}  / currencies repeated per tenor; tenors repeated per currency; all rates

/ fitick[]: one feed tick: move curves, publish quotes, maybe a trade, and the curves every 5th tick (once per second)
fitick:{evolve[]; pubquotes[]; pubtrade[]; nt::nt+1; if[0=nt mod 5; pubcurve[]];}

/ --- connect to the tickerplant via TorQ discovery, then run one tick every 200 ms ---
/ Wait for a segmentedtickerplant process, retrying every 10 seconds with no attempt limit (0W)
.servers.startupdepcycles[`segmentedtickerplant;10;0W];
/ Get a connection handle to any available segmented tickerplant
tph:.servers.gethandlebytype[`segmentedtickerplant;`any]
/ Register a repeating timer: start now, never end (0Wp), every 200 ms, calling fitick with a null argument
.timer.repeat[.proc.cp[];0Wp;0D00:00:00.200;(`fitick;`);"Publish FI feed"];
