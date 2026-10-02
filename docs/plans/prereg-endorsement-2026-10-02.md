# Pre-registration: Climate 200 / Voices endorsement (`AUSPOL_XGB_ENDORSE = "1"`)

Registered 2026-10-02 before any rebuild with it on. Pete chose it ("Climate 200
/ Voices flag") for the largest block of primary misses.

## Evidence (v58 remaining error; not a test)
Minor/IND candidates at elections with a list (fed2022, fed2025, nsw2023,
vic2022): Climate 200-backed +6.73 points under-predicted (n 70, SE 0.93);
all others -0.01 (n 2,249). Largest: Pittwater, Mackellar, Goldstein, Curtin,
Cowper, Manly.

## Data and its limits
external/reference/climate200/endorsements.csv (113 rows, sourced; Wikipedia
tables, Community Independents Project register, news). 106 matched to
candidacies (7 unmatched: 4 Senate, a 2016 "none" row, 2 Vic 2026 candidates
not yet in the corpus). LIMIT: almost no row carries an announcement date, so
"known before polling day" is assumed, not proven (Climate 200 announces backing
during campaigns). No lists found for SA 2026, WA 2025, Qld 2024 (absence of
evidence). Before 2019 the feature is a true zero.

## Change
`c200`, `voices` per (pair, seat, party), every row; rebuild from stage 3
against v58 (backtests `output/snapshots/20261002-1435-0a481f6-from3`).

## Criteria
1. PRIMARY: primary RMSE on Climate 200-backed rows improves by more than 1 SE
   (seat-clustered).
2. GUARD: 22-election per-election log loss not worse by more than 0.0020.
3. GUARD: Victoria seat log loss not worse by more than 0.0018.
4. GUARD: primary RMSE, all rows, not worse by more than 0.01.
UNACCEPTABLE: the endorsed rows improve while the other classes in the same
seats get worse by more than the endorsed rows' gain.
Then: the live forecast run with and without, seat by seat (Kew, Hawthorn).

## RESULT, 2026-10-02 19:45: PASSES

`output/snapshots/20261002-1930-d7c53b7-from3` against v58.
1. Climate 200 rows (n 71): RMSE 10.58 -> 9.18, per-seat -27.7 (SE 9.1); mean
   signed error +6.98 -> +2.91 -- PASS.
2. 22-election log loss 0.3444 -> 0.3440 -- PASS.
3. Victoria 0.2696 -> 0.2654 (better) -- PASS.
4. Primary RMSE all rows 4.0946 -> 4.0438 (better) -- PASS.
Unacceptable clause: other classes in those seats 3.944 -> 3.917, does not fire.
Ledger 0.2686 -> 0.2712 (inside its seed range).
Behaviour: time-forward, it cannot see the 2022 wave (one backed candidate
before it: Mackellar 2022 10.6 -> 10.8); it lifts later first-time teals
(Pittwater 2023 7.7 -> 17.3, actual 35.9); it over-shoots teals once they are
incumbents (Mackellar 2025 42.5 -> 48.2, actual 40.7; overlap with incumbency).
LIVE (production model trained with the same 46 features): Hawthorn IND
17.8 -> 20.5, win 0.11 -> 0.24; Kew 16.2 -> 19.1, win 0.02 -> 0.04; Mornington
and Malvern unchanged until their candidates are nominated (corpus refresh
after 9 Nov).
