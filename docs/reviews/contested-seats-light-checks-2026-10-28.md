# Contested seats Vic 2026: three light checks (2026-10-28)

Read-only checks on published files; no harness, fit or rebuild run. Background:
`contested-seats-vic2026-2026-10-28.md`. Scripts: scratchpad `light\a.py`, `b.py`, `c.py`.
Sources: `forecast-vic2026.json` (built 2026-10-27 05:52, 88 seats), `output/published-predictions.csv`.
Sign convention: miss = ours minus actual, so a negative miss means we under-called the party.

> **CORRECTION (2026-10-28, main session; original text below left unedited).** The line above is wrong for checks B
> and C. Their scripts read the `miss` column of `published-predictions.csv`, which is **actual minus ours**
> (fed2007 Adelaide ALP: ours 51.12, actual 48.26, miss −2.85). Check A does not use it and stands. So:
> - **Check B reverses.** sa2026 One Nation (ours − actual) on the previous other-right share: slope **−0.445**
>   (recomputed from `ours` and `actual` directly, n 47). Where the previous other-right vote was high, One Nation
>   beat our forecast: about 0.45 points per point. Cranbourne's 14.9 points of 2022 other-right is therefore a reason
>   to think we UNDER-call One Nation there, the bookmakers' direction. qld2017 is +0.064 on `miss` (SE 0.057),
>   i.e. a small, insignificant under-call: same direction, much weaker. Two elections; the sa2026 SE is not clustered.
> - **Check C reverses.** The other classes' "−2.9 (SE 0.84)" is actual − ours: they were OVER-called in seats where a
>   party re-entered, which is what inflated bases predict. The clean major-absent case, −5.4 (SE 3.1, n 8), is the
>   same direction and weak. This supports the Narracan Greens over-call reading but does not size it.
> Read every "over-called"/"under-called" in sections B and C below as its opposite.

## Check A: does the seat-level forecast imply a statewide Labor two-party vote consistent with the model's level?

**Verdict: consistent. In the 32 Labor v Liberal-National seats our median Labor two-candidate share averages 50.8, which is
about 2.9 above the all-seat 2022 level for those same seats (56.9 against 54.0). Remove that selection offset and it is 47.96,
against the model's own statewide 47.90.**

Numbers are Labor's share of the two-candidate vote in percent, equal weight per seat; 50 is a Labor win, higher is better for Labor.

| Quantity | Value | n seats |
|---|---|---|
| Mean of Labor median two-candidate share, seats whose likely final two is ALP v LNP | 50.80 (SE 1.00, median seat 52.63) | 32 |
| Same, weighted by probability that pair is the final two | 50.91 | 32 |
| Seats where Labor's median is above 50 | 19 | 32 |
| Seats excluded (final two includes One Nation, Greens or an independent) | n/a | 56 of 88 |
| Those same 32 seats at the 2022 election (`output/seat-tpp-estimates.csv`, vic2022) | 56.88 | 32 |
| All seats with a 2022 estimate, equal weight | 54.04 | 87 |
| Mean change in those 32 seats, 2022 to forecast | -6.08 | 32 |
| Model's statewide Labor two-party, projection (`deciding-runs/20261027-census-rebuild/after-fit.log:26`) | 47.90 (95% 43.16 to 52.65) | statewide |
| Model's statewide trend-implied two-party (same log, line 34) | 48.52 | statewide |

Where the statewide figure comes from: `output/statewide-level-vic-2026.csv` holds first preferences only (ALP 24.47, LNP 29.81,
GRN 14.27, ONP 21.34, OTH 10.11), no two-party. The two-party figures are printed in the fit log. The 25 Oct review's 55.0
is the 2022 statewide result and its 48.1 the projection of that day (`audit-f8-f19-status-2026-10-25.md:179` has 48.13);
today's log says 47.90, so the fall is about 7.1 points, not 6.9.

Bias from excluding non-ALP-v-LNP seats: the included seats are Labor-friendly. Their mean Labor first preference is 30.8
against 22.5 in the excluded seats (all-seat mean 25.5), and their 2022 two-party was 56.9 against 52.4 in the 55 excluded
seats that have a 2022 estimate. So the raw 50.8 sits above 47.9 because of selection, not because the seats are out of line.
Comparing changes instead: the 32 seats fall 6.1 points; all 87 seats at equal weight go from 54.04 to 47.90, also 6.1.

Limits: (1) 56 of 88 seats (64%) have a final two that is not Labor v Liberal-National, so a statewide two-party cannot be
rebuilt from seats; this is a consistency check on the 32 only. (2) Equal weight per seat ignores enrolment differences (not
checked). (3) The statewide fit log is the 27 Oct rebuild; the published JSON was built the same morning, and I did not confirm
they are the same run.

## Check B: Cranbourne's 2022 other-right vote and One Nation 2026

**Verdict: the seat's 2022 OTH_RIGHT share does not set One Nation's 2026 share in Victoria; OTH_RIGHT is scaled as its own class and
then squeezed by One Nation. In the two analog elections the relation points the other way (high previous other-right went with
over-calling One Nation), strongly in sa2026, weakly in qld2017. No support for raising Cranbourne's One Nation.**

How One Nation's live share is set (`scripts/fit_seats_full.R`):
- The total comes from the statewide level times a per-seat ratio (`:1386`, `onp_target <- ... state_mean[["ONP"]] * onp_ratio[...]`).
- The ratio is a rank-based allocation: seats are ordered by the 2025 federal Senate One Nation vote in the seat's booths
  (`:815-829`, `AUSPOL_ONP_ORDER=senate_rank`, shipped in `scripts/published_flags.R:321`), given the sorted values of a South Australian spread
  (`:835`, `onp_rank_ratio`), with the CV forced to 0.365 (`:877-887`). Spread and mean are fixed; only the order depends on seat data (`R/onp_order.R:61`).
- Cranbourne's Senate key is 5.52 (`output/onp-senate-vic2026.csv:62`). The 2022 state OTH_RIGHT share is not an input.
- OTH_RIGHT is a separate class: scaled with the OTH total plus a deviation slope (`:1317-1340`, loop over `unmodelled`),
  then, with the default `AUSPOL_ONP_FILL=prop`, multiplied by `(100 - onp_target)/rest` along with every other non-ONP class (`:1399-1412`). So a high-OTH_RIGHT seat has its
  OTH_RIGHT cell shrunk when One Nation is large; it does not feed One Nation's cell.
- Post-xgb layer: `output/xgb-primary-v6-final-cols.json` lists only the row's own-party features (`seat_prev_pcv`, `own_prev_pcv`, `dev_prev`, ...) plus party and region dummies;
  no other-class previous share appears by name. I did not trace how `seat_prev_pcv` is defined, so a small indirect path through the xgb layer is not ruled out.

Regression of One Nation's miss (ours minus actual, in points; zero is perfect, positive = we over-called One Nation) on the seat's previous-election OTH_RIGHT share (points). Slope is points of miss per point of previous OTH_RIGHT.

| Election | n seats | Slope | SE | t | Mean ONP miss |
|---|---|---|---|---|---|
| sa2026, all seats with a One Nation row | 47 | +0.445 | 0.129 | 3.5 | +3.20 |
| sa2026, only seats where One Nation had no 2022 vote | 29 | +0.428 | 0.104 | 4.1 | |
| qld2017, all seats | 93 | +0.064 | 0.057 | 1.1 | +3.60 |
| qld2017, only seats where One Nation had no previous vote | 84 | +0.063 | 0.063 | 1.0 | |

Read: in sa2026 each extra point of previous other-right went with about 0.4 points more One Nation over-call, so a Cranbourne-style seat (14.9)
would be over-called, not under-called. Caveat: the previous OTH_RIGHT class in SA holds parties that later consolidated (for example Family First), so the sign may
reflect that rather than a general rule. qld2017 is within noise. Two elections, seat-level OLS, SEs not clustered. Not checked: other elections where One Nation stood.

## Check C: re-entry inflated bases

**Verdict: not supported, and thin. Across 90 seat-elections where ALP, LNP or GRN stood with no previous share, the other classes were
under-called (mean miss difference -2.9, SE 0.84), the opposite of what inflated bases would give. The clean case (a major absent last time) has n = 8, mean -5.4 (SE 3.1).
Narracan vic2026 cannot be tested here (live seat, no outcome).**

Selection: any seat-election in `output/published-predictions.csv` with a row for ALP, LNP or GRN whose `prev_share` is 0 or blank, and at least two other classes with `prev_share` above 0 (so the seat existed). Each other class is compared with the same class in all other non-event seats of the same election that had a previous share above 0 (reference needs at least 10 seats). Difference = event-seat miss minus reference mean miss, in points; inflated bases would show positive, negative means we under-called more than elsewhere.

| Absent class | Other class | n events | Mean miss difference | SE |
|---|---|---|---|---|
| ALP or LNP absent (8 events) | ALP | 6 | -0.11 | 2.70 |
| | GRN | 5 | -2.44 | 1.56 |
| | IND | 7 | -10.64 | 5.53 |
| | LNP | 2 | -7.18 | 4.44 |
| | ONP | 2 | +0.03 | 0.36 |
| | OTH | 3 | +1.66 | 0.97 |
| | mean over the 8 seats | 8 | -5.44 | 3.09 |
| GRN absent before (82 events, 50 scored) | ALP | 49 | -3.75 | 1.50 |
| | LNP | 48 | -1.03 | 1.56 |
| | IND | 19 | -1.76 | 2.83 |
| | OTH | 27 | -0.58 | 0.66 |
| | mean over the 50 seats | 50 | -2.49 | 0.85 |
| All 90 events (58 scored) | mean | 58 | -2.89 | 0.84 |

The eight major-absent seat-elections: nt2024 Mulka (LNP), qld2012 Gladstone (LNP), vic2022 Richmond (LNP), wa2001 Churchlands (LNP), wa2001 Kimberley (ALP), wa2005 Alfred Cove (ALP), wa2005 Armadale (LNP), wa2013 Churchlands (LNP).
GRN events are mostly the Greens' first contests (wa2001 29, wa2008 21, nt2016/2020/2024 15 to 19), a party standing for the first time, not a re-entry that inflated others' bases, so a different mechanism.

Read: the independent figure (-10.6, n 7) probably reflects seats where an independent was the real contest (large personal votes the model under-calls), not base inflation. The sign is negative throughout; there is no evidence that carried-forward bases are too high.

What the code already does: `AUSPOL_REENTRY="majors"` (`scripts/published_flags.R:744`) fills the absent major's own share from its history (`R/reentry_prior.R:814`, `reentry_apply_harness`,
called at `scripts/fit_seats_full.R:1297`); for Narracan that lifts Labor from 4.4. It does not shrink the other classes' bases; they only move through normalisation. Narracan live (`seat-shares-vic-2026.csv`): ALP 10.11, GRN 10.11, LNP 34.47, ONP 34.43, OTH_RIGHT 5.76, IND 4.14.
Not checked: how the 2023 by-election Greens share enters the live base, and the 2018 and 2025 federal comparators quoted in the brief. n = 8 cannot confirm or refute a Narracan-specific effect; a direct test needs a purpose-built set of seats where a major skipped.

## Addendum (main session, 2026-10-28): the other-right lead across every election

Check B's sa2026 slope was one election. Same regression (One Nation ours − actual on the previous `OTH_RIGHT` share,
controlling for One Nation's own previous share where it varies) on every election in `published-predictions.csv` with
10+ One Nation seats. Negative = One Nation beat us where the previous other-right vote was high.

| scope | elections | pooled slope (inverse-variance) | SE | negative in |
|---|---:|---:|---:|---|
| all | 20 | −0.040 | 0.015 | 14 of 20 |
| states only | 13 | −0.029 | 0.021 | 8 of 13 |

sa2026 (−0.442, SE 0.131) is the outlier, with fed2016 (−0.371, prev other-right mean 18.0) and wa2005 (−0.263); qld2017,
the other One Nation surge, is +0.056. So the general effect is real but small: about 0.4 points of One Nation in
Cranbourne (14.9 against a typical ~5), not the 4+ that sa2026 alone implies. A shrunk term would mostly carry the
pooled value. sa2026's size may be Family First folding into One Nation, which is specific to that election. SEs are
ordinary, not clustered; seats within an election are not independent. Script: inline in the session (not saved).
