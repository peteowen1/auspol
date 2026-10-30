# Does a returning independent hold up better than the majors when One Nation surges? (2026-10-30)

Read-only analysis of `output/candidacies.csv` (22,358 candidate rows). No model refit, nothing run through the harness, nothing committed. Scratch scripts: `C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\d9620856-015e-4f5d-8963-ed4e84fea399\scratchpad\agentB\` (a.R builds pairs; b.R, d.R, e.R analyse).

Live code under test: the ONP_FIX block in `scripts/fit_seats_full.R` (~line 1436) sets ONP = statewide x seat ratio, then multiplies every other class by `fill = (100 - onp_target) / sum(others)`. In Mildura that factor is 0.868 and Cupper (base 28.96) loses 3.83 points like everyone else.

## Verdict

**The corpus gives no evidence that a returning independent holds up better than the majors under a One Nation surge, and the little there is points the other way. Keep proportional fill; do not add a personal-vote hold weight on this evidence.**

- Seats where ONP rose by 10 points or more AND a same-person independent (prior share at least 5%) returned against a major with at least 5%: **7 seats in 3 elections** (qld2015->qld2017 1, sa2022->sa2026 5, wa1996->wa2001 1). That is the whole usable record.
- Returning-independent ratio (share now / share last time) averaged 0.68 against the majors' 0.76 in the same seats (proportional fill predicts 0.78 for both). Per-election difference (independent minus major): -0.13, SE 0.23 clustered on 3 elections. Not distinguishable from zero, and the sign is "independent lost slightly more".
- Control: in calm seats (ONP change under 2 points, 99 returning independents over 27 elections) the independent ratio is 1.02 against the majors' 0.99 (per-election difference +0.06, SE 0.06). So independents do not systematically fall or hold relative to majors absent a surge, and the surge-seat gap is not mean reversion.
- Mildura: nothing here says Cupper should lose less than 3.83 points. At n = 7 the evidence could move that by a few points either way.

## 1. What the corpus has: statewide One Nation share and change on the previous election

Statewide One Nation share of all votes (percent) and change on the previous election in the same jurisdiction; a bigger change is a bigger surge. Only elections with a change of 1 point or more shown (full list in `scratchpad\agentB\st.csv`). vic2026 and nsw2027 have no results yet. n = seats in the election.

| election | ONP share | change vs last | seats |
|---|---|---|---|
| fed2016 | 1.3 | +1.1 | 150 |
| fed2019 | 3.1 | +1.8 | 151 |
| fed2022 | 5.0 | +1.9 | 151 |
| fed2025 | 6.4 | +1.4 | 150 |
| nsw2019 | 1.1 | +1.1 | 93 |
| qld2017 | 13.7 | +12.8 | 93 |
| sa2022 | 2.6 | +2.6 | 47 |
| sa2026 | 22.5 | +19.9 | 47 |
| wa2001 | 9.6 | +9.6 | 57 |
| wa2017 | 4.9 | +4.9 | 59 |
| wa2025 | 4.0 | +2.7 | 59 |

The corpus does NOT contain qld1998 (qld starts 2009). Seats with ONP up 10 points or more, by pair: qld2015->2017 50, sa2022->2026 44, wa1996->2001 30, wa2013->2017 10, fed2013->2016 9, fed2016->2019 5, nsw2019->2023 5, nsw2015->2019 3, plus 1 to 2 each in five other pairs. Real surges are three elections (qld2017, sa2026, wa2001).

## 2. Matching and the surge-seat comparison

Method: consecutive elections within a jurisdiction, same seat name. A "returning independent" is class IND in both elections, same seat, matched on surname plus first initial parsed from `name` ("SURNAME, Given"; the `given` column is empty in qld/sa, and a first attempt that used it cross-joined and was discarded). Majors = ALP and LNP with at least 5% last time; major ratio = their summed share now over summed share last time. Proportional expectation = (100 - ONP now) / (100 - ONP last time).

Ratio of share now to share last time in surge seats (ONP up 10 points or more), returning independent with at least 5% last time. 1.00 = held; lower = lost more. Proportional fill predicts the independent ratio equals the "proportional" column.

| election pair | n seats | independent ratio | major ratio | proportional | ind minus major |
|---|---|---|---|---|---|
| qld2015->qld2017 | 1 (Gregory) | 1.13 | 0.91 | 0.76 | +0.22 |
| sa2022->sa2026 | 5 | 0.66 | 0.71 | 0.77 | -0.05 |
| wa1996->wa2001 | 1 (Mandurah) | 0.31 | 0.87 | 0.87 | -0.55 |
| mean over 3 elections | 7 seats | 0.70 | 0.83 | 0.80 | -0.13 (SE 0.23, k = 3) |

Seat-pooled (n = 7): independent 0.68, majors 0.76, proportional 0.78; independent seat ratios range 0.31 to 1.13. Dropping qld2017 moves the difference to -0.30, dropping sa2026 to -0.17, dropping wa2001 to +0.08: the sign is not stable.

The seven seats (ratio now / last time): Finniss L Nicholson 0.95, Stuart G Brock 0.83, Hammond A Keen 0.65, Narungga F Ellis 0.54, Davenport D Golding 0.35, Gregory B Currie 1.13, Mandurah S Smith 0.31. Brock held 0.83 where the majors fell to 0.59; Nicholson held 0.95 where they fell to 0.69.

Sensitivity to the ONP threshold: election-clustered difference (independent minus major, negative = independent lost more), k = elections.

| ONP rise at least | n seats | k | ind minus major | SE | independent ratio (seat-pooled) | major ratio (seat-pooled) |
|---|---|---|---|---|---|---|
| 10 points | 7 | 3 | -0.13 | 0.23 | 0.68 | 0.76 |
| 5 points | 11 | 7 | -0.06 | 0.24 | 0.78 | 0.84 |
| 2 points | 16 | 7 | -0.10 | 0.23 | 0.89 | 0.86 |

Share of the proportional loss each class bore, (1 - ratio) / (1 - proportional expectation), seat-pooled; 1.00 = exactly proportional, below 1 = held better than proportional.

| ONP rise at least | n seats | returning independent | majors |
|---|---|---|---|
| 10 points | 7 | 1.46 | 1.08 |
| 5 points | 11 | 1.30 | 0.95 |
| 2 points | 16 | 0.85 | 1.10 |

Control (calm seats, ONP change under 2 points, no surge): independent ratio mean 1.02 (median 0.99), major ratio 0.99, per-election difference +0.06 (SE 0.06), n = 99 returning independents, 27 elections.

## 3. All seats, majors only (context)

Mean ratio now / last time for ALP and LNP in all surge seats (ONP up 10 points or more, class share at least 5% last time), averaged over 13 elections each, so a one-seat election weighs as much as qld2017: ALP 1.06 (SE 0.08), LNP 0.83 (SE 0.05), proportional expectation 0.85. The majors together are about proportional on average but uneven: LNP lost more than proportional (sa2026 0.50, wa2017 0.64), ALP less. That split is a separate question from personal votes.

## 4. How thin, and what is unverified

- n = 7 seat-cases, 3 elections; sa2026 holds 5 of the 7 and shares one statewide shock, so effective information is nearer 3 than 7. The SE of 0.23 comes from 3 clusters and is itself badly estimated.
- Loosening the threshold to 5 or 2 points reaches 11 to 16 seats and 7 elections, but the estimate stays near -0.06 to -0.10 with the same SE: no direction emerges.
- Matching is by surname plus first initial and exact seat name, so independents who moved seat after a redistribution or changed ballot name are missed (qld2017: only 77 of 93 seats matched across the pair). Checked by hand only for the seven seats listed.
- Class IND comes from the corpus classification; I did not audit whether any of the seven was really a micro-party brand (unverified).
- The comparison treats ONP's gain as the only shock; seats where a major candidate also changed are not controlled for.
- Only returning, same-person independents were tested; I did not look at who ONP takes votes from at candidate level.

## Fix the data supports

Nothing built or shipped. A shrunk personal-vote hold weight, `w = tau^2 / (tau^2 + se^2)`, fed by the estimate above comes out indistinguishable from zero (difference -0.13, SE 0.23, between-election variance not estimable from 3 clusters), so it would cost nothing but change nothing. The point estimate runs the opposite way to a hold: independents bore about 1.5 times the proportional loss in the 10-point pool, one SE from 1.0. A sized hold (for example the independent bearing half its proportional share, Cupper about -1.9 instead of -3.8) would be a bet against the only evidence we have. Revisit when vic2026 results arrive, and if more independent-heavy history (pre-2009 qld, wa1996-2001 beyond Mandurah) is added to the corpus.
