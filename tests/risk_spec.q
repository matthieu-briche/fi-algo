/ Specs for the risk engine (code/risk/riskengine.q), run without TorQ (qspec test framework)
/ Run from the fiapp root folder
system "l code/common/fi.q";                 / fixed-income library (.fi namespace)
system "l code/risk/riskengine.q";           / risk engine under test (.risk namespace)
.risk.init["appconfig";2026.10.28];          / load static data from the appconfig folder, valued as of a fixed date for reproducible tests

/ .rktest.qt[s;b;a]: build a batch of fake quotes (syms, bids, asks), all stamped at the same time
.rktest.qt:{[s;b;a] ([] time:count[s]#2026.10.28D10:00:00.000000000; sym:s; bid:b; ask:a)};

/ --- tests of .risk.upd1: per-bond risk computation and book updates ---
.tst.desc["Moteur de risque .risk.upd1"]{
  should["calculer le rendement mid, la duration et le DV01 d'un titre"]{
    .risk.reset[];                                                      / start from an empty book
    .risk.upd1 .rktest.qt[enlist`US10Y;enlist 99.98;enlist 100.02];     / one quote, mid = 100
    r:.risk.book`US10Y;                                                 / book row of the bond, as a dictionary
    r[`mid] musteq 100f;                                                / mid = (99.98+100.02)/2
    abs[.fi.pxyld[.risk.cfs`US10Y;2;r`yld]-100] mustlt 1e-6;            / repricing at the computed yield gives back the mid
    abs[r[`moddur]-.fi.moddur[.risk.cfs`US10Y;2;r`yld]] mustlt 1e-12;   / stored duration matches a direct computation
    abs[r[`posdv01]-r[`dv01]*-12] mustlt 1e-9;                          / position DV01 = DV01 * nominal (position of -12 million in positions.csv)
    };
  should["ne garder que la dernière quote d'un titre dans un lot"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[`US10Y`US10Y;99.0 99.98;99.04 100.02];        / two quotes for the same bond in one batch
    count[.risk.book] musteq 1;                                         / a single row in the book
    (.risk.book`US10Y)[`mid] musteq 100f;                               / built from the last quote, not the first (mid 99.02)
    };
  should["mettre à jour la ligne d'un titre sans en ajouter"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[enlist`US10Y;enlist 99.0;enlist 99.04];       / first batch
    .risk.upd1 .rktest.qt[enlist`US10Y;enlist 99.98;enlist 100.02];     / second batch on the same bond
    count[.risk.book] musteq 1;                                         / upsert on the sym key replaces the row instead of appending
    (.risk.book`US10Y)[`mid] musteq 100f;                               / and the row holds the latest values
    };
  should["donner un DV01 de position nul à un titre sans position"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[enlist`DE5Y;enlist 99.98;enlist 100.02];      / DE5Y has no line in positions.csv
    r:.risk.book`DE5Y;
    (r[`dv01]>0) musteq 1b;                                             / the bond's own DV01 is still computed
    r[`posdv01] musteq 0f;                                              / but its position DV01 is zero (default nominal 0)
    };
  };

/ --- tests of the .risk.upd entry point and the trader views ---
.tst.desc["Moteur de risque .risk.upd et vues du trader"]{
  should["ignorer les tables autres que quote"]{
    .risk.reset[];
    .risk.upd[`trade;.rktest.qt[enlist`US10Y;enlist 99.98;enlist 100.02]];  / data sent as a trade update
    count[.risk.book] musteq 0;                                         / is ignored: the book stays empty
    };
  should["agréger par devise sans jamais mélanger dollars et euros"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[`US10Y`DE10Y;99.98 99.70;100.02 99.74];       / one USD bond and one EUR bond
    tot:.risk.total[];                                                  / totals keyed by currency
    (exec ccy from 0!tot) mustmatch `EUR`USD;                           / exactly one row per currency (grouped keys come out sorted)
    abs[(tot`USD)[`dv01]-(.risk.book`US10Y)[`posdv01]] mustlt 1e-9;     / USD total = the USD bond only
    abs[(tot`EUR)[`dv01]-(.risk.book`DE10Y)[`posdv01]] mustlt 1e-9;     / EUR total = the EUR bond only
    };
  should["retrouver les nominaux du portefeuille : 31 millions par devise"]{
    .risk.reset[];
    s:.risk.bonds`sym;                                                  / every bond in the reference data
    .risk.upd1 .rktest.qt[s;count[s]#99.98;count[s]#100.02];            / quote all of them
    (.risk.total[]`USD)[`nominal] musteq 31f;                           / USD position nominals add up to 31 million
    (.risk.total[]`EUR)[`nominal] musteq 31f;                           / EUR position nominals add up to 31 million
    };
  };

  
/ the platform schema, to check that the snapshot matches it (defines the empty risk table)
system "l database.q";

/ --- tests of .risk.snapshot: the payload published to the tickerplant ---
.tst.desc["Publication du risque .risk.snapshot"]{
  should["préparer une photo conforme au schéma de la table risk : colonnes et types"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[`US10Y`DE10Y;99.98 99.70;100.02 99.74];
    sn:.risk.snapshot[];                                                / list of columns
    count[sn] musteq -1+count cols risk;                                / as many columns as the schema, minus time (added by the tickerplant)
    (type each sn) mustmatch type each 1_value flip risk;               / same column types as the schema, skipping its first (time) column
    };
  should["contenir chaque titre avec sa devise et sa maturité"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[`US10Y`DE10Y;99.98 99.70;100.02 99.74];
    sn:.risk.snapshot[];
    sn[0] mustmatch `DE10Y`US10Y;                                       / syms, in book order (select by sorts them)
    sn[1] mustmatch `EUR`USD;                                           / matching currencies
    sn[2] mustmatch `10Y`10Y;                                           / matching maturity buckets
    sn[9] mustmatch (0!.risk.book)`posdv01;                             / last column is the position DV01 from the book
    };
  };
