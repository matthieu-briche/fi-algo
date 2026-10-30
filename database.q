/ ===== FI Algo schema =====
/ Conventions: clean prices in % of nominal, yields in %, sizes in millions of nominal, skew in basis points
/ Every table starts with a time column (filled by the tickerplant) and a sym column carrying the
/ grouped attribute (`g#), which speeds up lookups and selects by sym.

/ --- Market data ---
/ quote: bid/ask prices and yields, bid/ask sizes, and the source venue of each quote
quote:([] time:`timestamp$(); sym:`g#`symbol$(); bid:`float$(); ask:`float$(); bidyld:`float$(); askyld:`float$(); bsize:`float$(); asize:`float$(); src:`symbol$())
/ trade: traded price and yield, size, side (buy/sell) and venue
trade:([] time:`timestamp$(); sym:`g#`symbol$(); price:`float$(); yld:`float$(); size:`float$(); side:`symbol$(); venue:`symbol$())

/ --- Zero curve (sym = curve name, tenor in years) ---
/ curve: one row per curve point: zero rate (%) at each tenor
curve:([] time:`timestamp$(); sym:`g#`symbol$(); tenor:`float$(); zero:`float$())

/ --- RFQs and algo responses (one row per event) ---
/ rfq: incoming request for quote: unique id, client, side, size, venue and time to live
rfq:([] time:`timestamp$(); sym:`g#`symbol$(); rfqid:`guid$(); client:`symbol$(); side:`symbol$(); size:`float$(); venue:`symbol$(); ttl:`timespan$())
/ rfqresp: algo response to an RFQ (linked by rfqid): status, quoted price and yield, reference mid and skew applied
rfqresp:([] time:`timestamp$(); sym:`g#`symbol$(); rfqid:`guid$(); status:`symbol$(); price:`float$(); yld:`float$(); mid:`float$(); skew:`float$())


/ --- Risk published by the risk1 engine (one row per bond per snapshot) ---
/ risk: currency, maturity bucket, mid, yield, modified duration, convexity, DV01, position nominal and position DV01
risk:([] time:`timestamp$(); sym:`g#`symbol$(); ccy:`symbol$(); bucket:`symbol$(); mid:`float$(); yld:`float$(); moddur:`float$(); convex:`float$(); dv01:`float$(); nominal:`float$(); posdv01:`float$())
