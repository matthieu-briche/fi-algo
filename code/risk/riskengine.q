/ ===== Risk engine: pure logic, no connections at all (testable outside TorQ) =====
/ Keeps the latest risk per bond (mid, yield, modified duration, convexity, DV01, position DV01)
/ from incoming quotes, and exposes views by currency and maturity bucket.
/ Everything below is defined in the .risk namespace.
\d .risk

/ init[cfg;vd]: load static data; cfg: configuration folder (string), vd: valuation date
init:{[cfg;vd]
  b:("SSSSFDDJS";enlist",") 0: hsym `$cfg,"/refdata/bonds.csv";   / bond reference table (CSV with header)
  p:("SF";enlist",") 0: hsym `$cfg,"/refdata/positions.csv";      / positions table: sym, nominal
  `.risk.bonds set b;                                            / store the reference table globally
  `.risk.cfs set b[`sym]!.fi.cashflows[vd] each b;             / sym -> future cashflows of each bond
  `.risk.freq set b[`sym]!b`freq;                               / sym -> coupon frequency
  `.risk.nominal set (b[`sym]!count[b]#0f),p[`sym]!p`nominal;   / sym -> nominal in millions: default 0, overridden by positions.csv
  `.risk.ccy set b[`sym]!b`ccy;                                 / sym -> currency
  `.risk.bucket set b[`sym]!`$2_'string b`sym;                  / sym -> maturity bucket, drops the 2-char prefix: US10Y -> 10Y
  reset[];                                                      / start with an empty book
  }

/ reset[]: clear the state: an empty table keyed on sym, one row per bond holding its latest known risk
reset:{[] `.risk.book set ([sym:`symbol$()] time:`timestamp$(); mid:`float$(); yld:`float$(); moddur:`float$(); convex:`float$(); dv01:`float$(); nominal:`float$(); posdv01:`float$());}

/ upd1[q]: recompute the risk of the bonds present in a batch of quotes and upsert it into the book
upd1:{[q]
  q:0!select by sym from q;                                     / last quote of each bond (select by with no columns keeps the last row), then unkeyed with 0!
  s:q`sym; m:0.5*q[`bid]+q`ask;                                 / mid price = (bid+ask)/2
  c:cfs s; f:freq s;                                            / cashflows and coupon frequencies of these bonds
  yl:.fi.yld'[c;f;m];                                           / mid yield, one per bond
  dur:.fi.moddur'[c;f;yl]; cv:.fi.convex'[c;f;yl]; dv:.fi.dv01'[c;f;yl];  / modified duration, convexity, DV01 per bond
  n:nominal s;                                                  / position nominal (0 if no position)
  `.risk.book upsert flip `sym`time`mid`yld`moddur`convex`dv01`nominal`posdv01!(s;q`time;m;yl;dur;cv;dv;n;dv*n);  / build a table from the columns and upsert on sym; posdv01 = dv01 * nominal
  }

/ upd[t;d]: called by the tickerplant for each data batch; only quote batches are processed
upd:{[t;d] if[t~`quote; upd1 d];}

/ trader views (position DV01: loss in currency if rates rise by 1 bp)
/ bybucket[]: position DV01 summed by currency and maturity bucket
bybucket:{[] select dv01:sum posdv01 by ccy:.risk.ccy sym, bucket:.risk.bucket sym from .risk.book}
/ total[]: position DV01 and nominal summed by currency
total:{[] select dv01:sum posdv01, nominal:sum nominal by ccy:.risk.ccy sym from .risk.book}

/ snapshot[]: risk snapshot as a list of columns in the risk table layout (no time column: the tickerplant adds it)
snapshot:{[] b:0!.risk.book; (b`sym; .risk.ccy b`sym; .risk.bucket b`sym; b`mid; b`yld; b`moddur; b`convex; b`dv01; b`nominal; b`posdv01)}

/ back to the root namespace
\d .
