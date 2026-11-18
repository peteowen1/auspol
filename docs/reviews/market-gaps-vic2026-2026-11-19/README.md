# Where we disagree with TAB and Sportsbet (vic2026, 19 Nov 2026)

Our forecast (published 19 Nov 8:12am AEDT, `forecast-vic2026.json` built 2026-11-18T21:12Z) against
the bookmaker odds captured 18 Nov midday (`docs/benchmarks/vic2026/2026-11-18/`). Our favourite
differs from both TAB's and Sportsbet's in 21 of 88 seats. One Sonnet agent per seat, read-only,
no R (brief: `_brief.md`); each seat's report is in this folder. Agent claims are claims: the ones
checked by hand are marked below.

Expected seats, sum of win chances out of 88 (ours / TAB / Sportsbet / AE Forecasts / The Swing Is On):
ONP 15.8 / 12.9 / 13.6 / 8.3 / 17.9; LNP 39.1 / 44.3 / 44.8 / 49.5 / 39.3; GRN 7.5 / 5.3 / 5.2 / 5.1 / 5.6.

## Possible defects (a trace decides; none fixed yet)

| Seat | Ours vs books | Suspected cause | Checked by hand? |
|---|---|---|---|
| Essendon | IND 65% vs 7-12% | the independent class total (22.4) carries +3.7 from "three candidates" and +2.3 from Ava Adams's council vote, and the split hands most of it to Yildiz | no (from the 18 Nov trace numbers) |
| Narracan | ONP 75% vs 13-14% | Ben Lucas's search interest is 100 (the maximum), fetched 2026-09-10, a week after news reports of his guilty plea: worth ~+4 points, the gap between a coin flip and 75%. Baseline is the Labor-less Jan 2023 supplementary; Labor 7.7 | search value yes (`output/vic2026-live-salience.csv`); news dates web-only; Labor re-entry fill NOT confirmed in the run log |
| Benambra | LNP 30% vs 78-80% | search interest alone moves the Liberal 75% to 30% (McKeeman jump 0.676, Martin -5.0 in `output/salience-v6.csv`) | from the 12 Nov walk |
| Werribee | LNP 61% vs 22% | the Feb 2025 by-election is half-blended into the baseline, then the full 2022-26 statewide Labor fall is applied on top: likely counts the same mood twice | no |
| Mill Park | ONP 54% vs 28-32% | Labor's Elizabeth Nealy has `council_any` FALSE; the web says she was mayor in 2024-25 (UNCONFIRMED). Small effect; the rest is the One Nation pattern | file yes, mayoralty no |

## The model-wide pattern (one question, not 21)

Ten of the 21 are One Nation ahead of the Liberals or Labor where the books are not (Narracan, Benambra,
Hastings, Bendigo East, Macedon, Mill Park, Frankston, Carrum, Wendouree, Narre Warren South). In almost
all of them the agents found no local evidence for One Nation (no seat poll, Senate vote average or
below): the seat number is the statewide 21.5 allocated by Senate rank. Backtests point both ways: the
sa2026 surge was under-called (25.3 forecast vs 28.4 actual over 26 high-ONP rows), federal and qld2020
over-called. So whether we are right on One Nation is a statewide-level question.

## Views we can defend (fragile: no seat poll, decided by preference flows)

Box Hill, Footscray, Albert Park, Pascoe Vale, Eltham, Bentleigh, Mordialloc (Labor or Greens ahead
on flows; The Swing Is On agrees on Box Hill, Eltham, Bentleigh, Mordialloc), Melton and Cranbourne
(the books are HIGHER on One Nation than us), Hastings, Frankston, Macedon, Wendouree, Carrum, Narre
Warren South (the One Nation pattern), Bendigo East (the Nationals' 2025 federal swing deliberately
not carried: Port 3C, 28 Oct, Pete's call).

## Trace: the same forecast with search interest off (19 Nov, 8:59-9:09am)

Worktree `C:\dev\auspol-wt-sal` at fee0174d, own copy of `output/`. Two `fit_seats_full.R` runs at the published
configuration, seed 42: `AUSPOL_OUT_SUFFIX=salon` (today's `salience-v6.csv`, prints `XG5 salience corpus found for
vic2026: 546 of 616`) and `saloff` (the same file minus its 685 vic2026 rows, prints `XG5! no salience corpus yet`).
The `salon` run reproduces the published forecast (Narracan ONP 0.75, Essendon IND 0.65; the same 21 seats differ
from the books). Win probability 0-1.

| Seat | On | Off | Books (TAB / Sportsbet) |
|---|---|---|---|
| Essendon | IND 0.65, LNP 0.15, ALP 0.11 | IND 0.02, LNP 0.39, ALP 0.40 | LNP 0.47, ALP 0.34 |
| Benambra | ONP 0.38, IND 0.32, LNP 0.30 | LNP 0.75, ONP 0.25 | LNP 0.80 / 0.78 |
| Narracan | ONP 0.75, LNP 0.25 | ONP 0.52, LNP 0.48 | LNP 0.83 / 0.86 |
| Hawthorn | LNP 0.61, IND 0.39 | LNP 0.98 | LNP |
| Kew | LNP 0.80, IND 0.19 | LNP 0.97 | LNP |

Expected seats on / off: ALP 23.4 / 25.1, LNP 39.1 / 40.5, GRN 7.5 / 7.1, ONP 15.8 / 14.9, IND 1.9 / 0.2.
52 of 88 seats move more than 0.02; favourites differing from the books 21 -> 19; mean largest gap 18.2 -> 15.9 points.

So the independents' chances are almost entirely search interest (Essendon's 65% is not the class split: off, it
is 2%), as are Benambra, Hawthorn and Kew, and about half of Narracan. The One Nation pattern mostly survives.

Two corrections to the agents: Ben Lucas's value in the file the model reads is small (jump 0.077); Narracan moves on
Wayne Farnham's -2.94. Negative jumps like Farnham's and Steve Martin's (-5.0) are ordinary: -2.94 recurs as a floor
in almost every training election. What is unusual is vic2026's POSITIVE tail: p99 5.92 and 20 rows above 1, against
p99 at most 0.5 in every earlier Victorian election except vic2014. The 12 Nov rank-mapping maps vic2026 onto the
POOLED corpus, whose positive tail is mostly WA (p99 up to 19). Whether that is the intended scale is the open question.
