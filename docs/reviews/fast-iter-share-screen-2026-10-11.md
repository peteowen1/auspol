# Fast-iteration plan item 4: a level screen that reports variance and a seat log loss proxy (2026-10-11)

`scripts/screen_level_share.R` replaces the 4-second share screen, which reported only the mean level error and so
missed that the 1-day decay lost badly on single elections. Runtime 11 s for four arms and three comparisons
(about 3 s per arm; `load_all` is most of it). Run: `powershell.exe -Command 'Rscript "scripts/screen_level_share.R"'`.

## What it does

- Baseline is `output/published-predictions.csv` (the 10-day decay 20k run on disk; its pooled seat log loss recomputes
  to 0.3183 over 2,120 seats and 22 elections against 0.3181 in the docs, the gap being the clamp). Every arm's
  ALP/LNP/GRN level comes from the REAL `level_recent_apply()` / `level_recent_decay_fit()` over
  `output/level-recent.csv` (that file is the unblended trend, the 28-day average and the actual per election; built by
  `scripts/build_level_recent_table.R`). The arm's change against the 10-day level is added to each seat's primary in
  that class (pass-through 1), the other classes absorb it pro rata.
- Seat-win probability moves by `log p' = log p + BETA x (primary change)`, renormalised over the seat. BETA = 0.137
  log-odds per primary point is read off the baseline (within-seat slope of log p_win on primary share, 5,592
  candidates in 2,120 seats, R2 0.83), and every comparison is repeated at 0.5x and 2x BETA. A class at p_win = 0 stays 0.
- Reported per pair of arms: paired per-election change in (a) day-before level error (ALP/LNP/GRN MAE), (b) seat
  primary squared error, (c) the seat log loss proxy; the pooled proxy change with an election-clustered SE; the worst
  and best election; the same on the 681 seats that carry an AEF figure (my stand-in for the AEF-7 ledger; I did not
  verify it is the same set as the ledger).
- Each arm prints what it applied before any result. Three controls print at the end: arm against itself is exactly 0,
  BETA = 0 is exactly 0, and a deliberately broken arm (LNP +3, ALP -3 everywhere) moves pooled loss +0.043.

## Agreement with the 2026-10-11 seat-level screens (negative = first arm better; lower log loss is better)

Seat log loss = average of -log(probability the model gave the class that won the seat); n = 22 elections, 2,120 seats.

| verdict recorded (source) | seat-level result | this screen | sign |
|---|---|---|---|
| 28-day window better than no blend (20k run) | 0.3239 -> 0.3172, -0.0067 (SE 0.0039), better in 14 of 22 | -0.0062 (SE 0.0034), better in 13 of 22 | agree |
| ... ledger | 0.2732 -> 0.2682, -0.0050 | -0.0116 (SE 0.0053) | agree, larger |
| ... wa2008 / qld2020 / vic2022 | -0.080 / -0.038 / -0.009 | -0.078 / -0.020 / -0.040 | agree |
| ... nsw2019 (the clause 5 failure) | +0.0453 at 20k, +0.0088 at the 1,000-sim screen | +0.0044 | agree in sign, misses the size |
| ... worst election | nsw2019 +0.0453 | wa2013 +0.0196 (nsw2019 +0.0044) | **misses which election** |
| 10-day decay ~ tie with the window (20k run) | 0.3172 -> 0.3181, +0.0009 (SE 0.0027) | -0.0007 (SE 0.0015) | **sign differs, both are zero within SE** |
| ... ledger | 0.2682 -> 0.2708, +0.0026 (screen +0.0024) | +0.0022 (SE 0.0016) | agree |
| ... fed2013 (+0.0251 at 20k, not shown by the screen) | +0.0251 | -0.0035 | **disagree** |
| ... wa2013 | +0.0199 at the 1,000-sim screen | +0.0171 | agree |
| 1-day decay REFUSED vs the window (1,000-sim screen) | -0.0056 (SE 0.0060): holds | -0.0066 (SE 0.0055) | agree |
| ... ledger | +0.0078 (SE 0.0059): fails | +0.0050 (SE 0.0035) | agree |
| ... worst election | wa2013 +0.061, qld2024 +0.043, vic2014 +0.028 | wa2013 +0.040, qld2024 +0.022, vic2014 +0.017 | agree, sizes about 0.6x |
| ... biggest wins | wa2005 -0.113, wa2017 -0.095, vic2018 -0.043, fed2007 -0.043 | wa2005 -0.180, wa2017 -0.061, vic2018 -0.026, fed2007 -0.032 | agree |

The old mean-only share screen is the contrast: it showed the 1-day arm as the best on level error. This screen shows
the same -0.39 points of mean level error for the free-fit arm AND the +0.040 wa2013, +0.022 qld2024 tail that refused it.

## Honest reading

- All three headline verdicts agree in sign, including the refusal: 1-day wins on pooled loss, loses on the ledger, and
  has a worst election far over the 0.02 limit (0.040 here; the screen's own 0.061, so about 0.6x). The 28-day window
  helps (-0.0062 vs -0.0067). The 10-day decay is a tie.
- The 10-day-vs-window pooled sign differs (-0.0007 against +0.0009) but both are inside one SE of zero, so this
  is the "tie" verdict agreeing, not a disagreement. It is NOT evidence the proxy can resolve a 0.001 difference.
- The proxy misses single-election 20k surprises that come from the simulation, not the level: fed2013 +0.0251 and
  nsw2019 +0.0453. Both were also missed by the 1,000-sim screen (nsw2019 +0.0088), so this is a shared limit: the level
  shift is not the whole mechanism (preference flows, candidate-level effects, tail seats). Treat "no election worse
  than 0.02" as a bar the proxy under-reads; a "worst election > ~0.015" here is a stop sign, a clean result is not a
  clearance.
- BETA matters for size, not sign here: window vs none pooled -0.0021 / -0.0062 / -0.0205 at 0.5x / 1x / 2x. The fitted
  BETA reproduces the seat-level size well for the window (-0.0062 vs -0.0067) and about 0.6x for the 1-day tail.
- Limits by construction: pass-through 1 (a level change moves every seat's primary one for one; the real model has
  slopes), exact-zero win probabilities cannot rise (the far tail is invisible, as with `quick_arm.R`), and it only acts
  where the idea changes the ALP/LNP/GRN level. It does not see ideas that change seat-level features.
- Only the three arms above were compared; it is validated for level-blend ideas only. wa2001 has no history so every
  arm reads the trend there (change 0 by construction).

Next use: screen a new level idea in ~10 s here, then `quick_arm.R` for survivors, then the 20k run to ship.
