/ ===== Schéma FI Algo =====
/ Conventions : prix clean en % du nominal, rendements en %, tailles en millions de nominal, skew en points de base

/ --- Données de marché ---
quote:([] time:`timestamp$(); sym:`g#`symbol$(); bid:`float$(); ask:`float$(); bidyld:`float$(); askyld:`float$(); bsize:`float$(); asize:`float$(); src:`symbol$())
trade:([] time:`timestamp$(); sym:`g#`symbol$(); price:`float$(); yld:`float$(); size:`float$(); side:`symbol$(); venue:`symbol$())

/ --- Courbe zéro (sym = nom de courbe, tenor en années) ---
curve:([] time:`timestamp$(); sym:`g#`symbol$(); tenor:`float$(); zero:`float$())

/ --- RFQ et réponses de l'algo (une ligne par événement) ---
rfq:([] time:`timestamp$(); sym:`g#`symbol$(); rfqid:`guid$(); client:`symbol$(); side:`symbol$(); size:`float$(); venue:`symbol$(); ttl:`timespan$())
rfqresp:([] time:`timestamp$(); sym:`g#`symbol$(); rfqid:`guid$(); status:`symbol$(); price:`float$(); yld:`float$(); mid:`float$(); skew:`float$())
