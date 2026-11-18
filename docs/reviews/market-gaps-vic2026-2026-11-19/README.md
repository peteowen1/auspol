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
