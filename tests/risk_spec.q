/ Specs du moteur de risque (code/risk/riskengine.q), exécutées sans TorQ
/ À lancer depuis la racine de fiapp
system "l code/common/fi.q";
system "l code/risk/riskengine.q";
.risk.init["appconfig";2026.10.28];

/ fabrique un lot de fausses quotes
.rktest.qt:{[s;b;a] ([] time:count[s]#2026.10.28D10:00:00.000000000; sym:s; bid:b; ask:a)};

.tst.desc["Moteur de risque .risk.upd1"]{
  should["calculer le rendement mid, la duration et le DV01 d'un titre"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[enlist`US10Y;enlist 99.98;enlist 100.02];
    r:.risk.book`US10Y;
    r[`mid] musteq 100f;
    abs[.fi.pxyld[.risk.cfs`US10Y;2;r`yld]-100] mustlt 1e-6;
    abs[r[`moddur]-.fi.moddur[.risk.cfs`US10Y;2;r`yld]] mustlt 1e-12;
    abs[r[`posdv01]-r[`dv01]*-12] mustlt 1e-9;
    };
  should["ne garder que la dernière quote d'un titre dans un lot"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[`US10Y`US10Y;99.0 99.98;99.04 100.02];
    count[.risk.book] musteq 1;
    (.risk.book`US10Y)[`mid] musteq 100f;
    };
  should["mettre à jour la ligne d'un titre sans en ajouter"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[enlist`US10Y;enlist 99.0;enlist 99.04];
    .risk.upd1 .rktest.qt[enlist`US10Y;enlist 99.98;enlist 100.02];
    count[.risk.book] musteq 1;
    (.risk.book`US10Y)[`mid] musteq 100f;
    };
  should["donner un DV01 de position nul à un titre sans position"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[enlist`DE5Y;enlist 99.98;enlist 100.02];
    r:.risk.book`DE5Y;
    (r[`dv01]>0) musteq 1b;
    r[`posdv01] musteq 0f;
    };
  };

.tst.desc["Moteur de risque .risk.upd et vues du trader"]{
  should["ignorer les tables autres que quote"]{
    .risk.reset[];
    .risk.upd[`trade;.rktest.qt[enlist`US10Y;enlist 99.98;enlist 100.02]];
    count[.risk.book] musteq 0;
    };
  should["agréger par devise sans jamais mélanger dollars et euros"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[`US10Y`DE10Y;99.98 99.70;100.02 99.74];
    tot:.risk.total[];
    (exec ccy from 0!tot) mustmatch `EUR`USD;
    abs[(tot`USD)[`dv01]-(.risk.book`US10Y)[`posdv01]] mustlt 1e-9;
    abs[(tot`EUR)[`dv01]-(.risk.book`DE10Y)[`posdv01]] mustlt 1e-9;
    };
  should["retrouver les nominaux du portefeuille : 31 millions par devise"]{
    .risk.reset[];
    s:.risk.bonds`sym;
    .risk.upd1 .rktest.qt[s;count[s]#99.98;count[s]#100.02];
    (.risk.total[]`USD)[`nominal] musteq 31f;
    (.risk.total[]`EUR)[`nominal] musteq 31f;
    };
  };

  
/ le schéma de la plateforme, pour vérifier que la photo lui correspond
system "l database.q";

.tst.desc["Publication du risque .risk.snapshot"]{
  should["préparer une photo conforme au schéma de la table risk : colonnes et types"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[`US10Y`DE10Y;99.98 99.70;100.02 99.74];
    sn:.risk.snapshot[];
    count[sn] musteq -1+count cols risk;
    (type each sn) mustmatch type each 1_value flip risk;
    };
  should["contenir chaque titre avec sa devise et sa maturité"]{
    .risk.reset[];
    .risk.upd1 .rktest.qt[`US10Y`DE10Y;99.98 99.70;100.02 99.74];
    sn:.risk.snapshot[];
    sn[0] mustmatch `DE10Y`US10Y;
    sn[1] mustmatch `EUR`USD;
    sn[2] mustmatch `10Y`10Y;
    sn[9] mustmatch (0!.risk.book)`posdv01;
    };
  };