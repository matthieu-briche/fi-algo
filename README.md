# fi-algo

[![CI](https://github.com/matthieu-briche/fi-algo/actions/workflows/ci.yml/badge.svg)](https://github.com/matthieu-briche/fi-algo/actions/workflows/ci.yml)

Real-time fixed income tick stack built on **kdb+/q** and the **[TorQ](https://github.com/DataIntellectTech/TorQ)** framework.

A simulated feed publishes quotes, trades and zero curves for 12 government bonds (US Treasuries, German Bunds, French OATs) every 200 ms. The prices are derived from yield curves that follow a mean-reverting process, and a dedicated q library (`.fi`) handles cash flows, accrued interest and the price/yield conversions. The standard TorQ pipeline (segmented tickerplant, RDB, WDB, HDB, gateway) captures, stores and serves the data, and the schema is ready for RFQ capture and algo responses.

---

## Features

- **Simulated government bond market**: 12 benchmarks (2Y, 5Y, 10Y, 30Y) across UST, DBR and FRTR, quoted on several venues (BrokerTec, MTS, Tradeweb, Bloomberg).
- **Mean-reverting yield curves**: USD and EUR zero curves on 6 tenors evolve as an Ornstein-Uhlenbeck process with a common shock plus idiosyncratic noise per tenor.
- **Fixed income library in q** (`code/common/fi.q`): coupon schedules, cash flows, accrued interest, clean price from a zero curve or from a yield, analytical price/yield derivative, and yield from price by Newton-Raphson.
- **Full TorQ tick pipeline**: discovery, segmented and chained tickerplants, RDB, WDB with sort workers, HDBs, gateway, housekeeping, monitoring and data quality processes.
- **Real-time analytics**: rolling VWAP/TWAP over configurable windows (`metrics`) and a VWAP subscriber with HDB data replay (`vwapsub`).
- **RFQ schema**: tables for incoming requests for quote and the algo's responses (price, yield, mid, skew).
- **Unit tests in CI**: qspec specs for the `.fi` library, run by GitHub Actions on every push to `main`, with a JUnit report.

## Architecture

```
                 ┌──────────────┐
                 │  feed (q)    │  OU curves → bond prices & yields
                 └──────┬───────┘
                        │ .u.upd  quote / trade / curve
                 ┌──────▼───────┐        ┌──────────────┐
                 │  STP (stp1)  ├───────►│ chained STP  │
                 └──┬────┬───┬──┘        └──────────────┘
                    │    │   │
          ┌─────────┘    │   └──────────┐
   ┌──────▼─────┐ ┌──────▼─────┐ ┌──────▼──────┐
   │    RDB     │ │    WDB     │ │  metrics /  │
   │ (intraday) │ │ + sorters  │ │   vwapsub   │
   └──────┬─────┘ └──────┬─────┘ └─────────────┘
          │              │ end of day
          │       ┌──────▼─────┐
          │       │  HDB ×2    │
          │       └──────┬─────┘
          └──────┬───────┘
          ┌──────▼─────┐
          │  gateway   │  single entry point for queries
          └────────────┘
```

All processes are declared in [`appconfig/process.csv`](appconfig/process.csv), with ports offset from `KDBBASEPORT` (6000 by default).

## Data model

Conventions: clean prices in % of par, yields in %, sizes in millions of notional, skew in basis points.

| Table     | Content |
|-----------|---------|
| `quote`   | `sym`, `bid`, `ask`, `bidyld`, `askyld`, `bsize`, `asize`, `src` |
| `trade`   | `sym`, `price`, `yld`, `size`, `side`, `venue` |
| `curve`   | `sym` (curve name), `tenor` (years), `zero` (%) |
| `rfq`     | `sym`, `rfqid`, `client`, `side`, `size`, `venue`, `ttl` |
| `rfqresp` | `sym`, `rfqid`, `status`, `price`, `yld`, `mid`, `skew` |

The schema lives in [`database.q`](database.q) and the bond reference data in [`appconfig/refdata/bonds.csv`](appconfig/refdata/bonds.csv).

## Fixed income library

`code/common/fi.q` defines the `.fi` namespace:

| Function | Description |
|----------|-------------|
| `.fi.interp[x;y;t]` | Linear interpolation, flat extrapolation at both ends |
| `.fi.sched[vd;mat;f]` | Next and previous coupon dates, rolled back from maturity |
| `.fi.cashflows[vd;b]` | Future times, cash flows and accrued interest for a bond |
| `.fi.pxzero[cfs;tenors;zeros]` | Clean price from a zero curve (continuous compounding) |
| `.fi.pxyld[cfs;f;y]` | Clean price from a yield (compounded `f` times a year) |
| `.fi.dpdy[cfs;f;y]` | Analytical derivative of price with respect to yield |
| `.fi.yld[cfs;f;px]` | Yield from clean price by Newton-Raphson |

Example:

```q
q)\l code/common/fi.q
q)bonds:("SSSSFDDJS";enlist",") 0: `:appconfig/refdata/bonds.csv
q)b:first select from bonds where sym=`US10Y
q)cfs:.fi.cashflows[.z.d;b]
q).fi.pxyld[cfs;2;4.25]      / roughly par
q).fi.yld[cfs;2;98.5]        / yield for a clean price of 98.5
```

Time is measured in years using a simplified ACT/365.25 convention.

## Getting started

### Prerequisites

- kdb+ (q) on your `PATH`
- [TorQ](https://github.com/DataIntellectTech/TorQ) checked out next to this repository
- `rlwrap` (optional)

The environment script expects this layout:

```
workspace/
├── TorQ/      # framework, unchanged
├── fi-algo/   # this repository
└── data/      # logs, tickerplant logs, HDB (outside Git)
```

### Run

```bash
git clone --recurse-submodules https://github.com/matthieu-briche/fi-algo.git
cd fi-algo
source ./setenv.sh

torq start all      # start every process flagged startwithall in process.csv
torq summary        # check process status
torq stop all
```

`metrics`, `reporter`, `filealerter`, the monitor and the data quality processes are not started by default; start them individually with `torq start <procname>`.

### Example queries

Through the RDB or HDB (see `code/rdb/examplequeries.q` and `code/hdb/examplequeries.q`):

```q
countbysym[.z.d;.z.d]                  / volume and trade count by bond
hloc[.z.d;.z.d;0D00:05]                / 5-minute OHLC and VWAP
select from quote where sym=`DE10Y     / latest Bund quotes
select from curve where sym=`EUR, time=max time
```

## Tests

The specs in [`tests/fi_spec.q`](tests/fi_spec.q) cover interpolation, coupon schedules, cash flows, price/yield round trips and zero-curve pricing. They use [qspec](https://github.com/nugend/qspec), included as a submodule.

```bash
./runtests.sh            # run all specs
./runtests.sh --junit    # JUnit XML output
```

The [CI workflow](.github/workflows/ci.yml) installs KDB-X on a GitHub-hosted runner and runs the same specs on every push to `main` and on pull requests, publishing a JUnit report.

## Project layout

```
code/
├── common/fi.q          # fixed income library
├── tick/feed.q          # simulated bond feed
├── processes/           # metrics (VWAP/TWAP), vwapsub
├── rdb/, hdb/           # example queries
└── filealerter/
appconfig/
├── process.csv          # process list and ports
├── refdata/bonds.csv    # bond reference data
└── settings/            # per-process configuration
database.q               # table schema
tests/                   # qspec specs
tools/                   # qspec, qutil (submodules) and runner
```

## Feed parameters

The main knobs are at the top of `code/tick/feed.q`:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `theta` | per tenor | Long-run curve levels (%) for USD and EUR |
| `kappa` | 0.001 | Mean-reversion speed per tick |
| `siglvl` | 0.3 bp | Volatility of the common shock per tick |
| `sigidio` | 0.1 bp | Idiosyncratic volatility per tenor per tick |
| `issuerspr` | UST 0, DBR 0, FRTR 0.70% | Issuer spread over the curve |
| `ptrade` | 0.3 | Probability of a trade on each tick |

## Acknowledgements

Built on the [TorQ Finance Starter Pack](https://github.com/DataIntellectTech/TorQ-Finance-Starter-Pack) by Data Intellect.

## License

This project is released under the [MIT License](LICENSE).
