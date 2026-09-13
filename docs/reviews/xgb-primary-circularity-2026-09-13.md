# fit_xgb_primary_v6.R was training on its own recycled output

2026-09-13. Found while trying to measure two much smaller things (the ONP
seat-ranking problem in sa2026, and whether adding sa2022 to
`all_election_pairs()` helps). Neither of those questions could be answered
until this was found and fixed, because the measuring instrument itself was
broken.

## What was wrong

`AUSPOL_XGB_PRIMARY = "1"` is the shipped default in `published_flags.R`, and
`apply_published_flags()` materially `Sys.setenv()`s it into the process
environment for every ordinary harness run.

That flag makes `xgb_primary_override()` **replace** the shares matrix with
`v6`'s own prior predictions (`scripts/backtest_candidate_sa.R:796`,
`shares <- xgb_primary_override(shares, TGT)`) **before** the seat simulator
runs. The simulator then writes `pred_share` — per seat, per class — from
that already-overridden result (`R/seat_share_rmse.R:54`).

`pred_share` is exactly the column `fit_xgb_primary_v6.R` reads out of
`pooled-sharedetail.csv` and calls **"the shipped baseline"** in its own
console output, and the column its engineered features (`x`, `dev_prev`) are
built from.

So the ordinary cycle — run a harness, pool sharedetail, refit `v6`, run the
harness again — is not a measurement. It is an **iterative refitting loop**:
each pass feeds `v6`'s own output back into what the next fit treats as
ground truth. Nothing about this requires a code change between iterations;
running the identical committed pipeline twice in a row produces two
different numbers.

## How it was found

Investigating whether adding `sa2022` to `all_election_pairs()` helped
sa2026's One Nation ranking, the SA backtest's seat log loss moved:

```
0.5384  (established baseline, several times over)
0.5794  (PR #34's own stated "after the sa2022 fix" number)
0.6463  (an earlier same-night re-measurement)
0.7015  (after reverting the change under test -- regression persisted)
0.8126  (one more repool + refit cycle later)
```

The `all_election_pairs()` revert should have restored 0.5794. It did not,
and the number kept moving in one direction with no committed code change
between measurements. That ruled out the change under test, ruled out
`xgboost` non-determinism (two back-to-back runs of the identical script on a
*fixed* input were bit-identical), and ruled out stale sharedetail (the file's
mtime was hours old and unchanged across several of these measurements).
What was left was the file's own *content* drifting each time it was
regenerated — which only happens if regenerating it isn't idempotent.

## The fix, and how it was verified

1. Ran all six harnesses with `AUSPOL_XGB_PRIMARY=0` **explicitly** — the
   true, non-circular shipped-model `pred_share`.
2. Pooled with `pool_sharedetail.R`, confirmed the newest file per pair
   matched this run's timestamps.
3. Ran `fit_xgb_primary_v6.R` **once** against that clean pool.
   `BASELINE (shipped model)` printed **4.2351** — markedly *worse* than any
   of the contaminated numbers seen that session (3.9101–4.1626), because the
   contamination had been making the "baseline" look artificially good by
   creeping toward `v6`'s own better-fit predictions. `v6` trained on this
   clean baseline scored **3.8781** — a sane 8.4% improvement over an honest
   baseline, unlike the contaminated runs where `v6` scored *worse* than its
   own "baseline" (a relationship that should have been the first red flag).
4. Ran all six harnesses **once more**, default flags
   (`AUSPOL_XGB_PRIMARY=1`, the normal operational setting), using this
   cleanly-trained model. No further iteration.

## The corrected numbers

Pooled seat log loss, lower is better, 2,097 seat-elections across 23 pairs:

| | PR #34's claim | corrected |
|---|---|---|
| pooled | 0.3115 | **0.2926** |
| sa2026 | 0.5794 | **0.4597** |
| sa2022 | 0.6463 | **0.2934** |

The corrected model is **better** than anything reported that night, not
worse. The circularity had been dragging every number in the wrong direction;
breaking it recovered performance that was there all along.

Full per-pair table:

| pair | n | log loss |
|---|---|---|
| fed2007 | 149 | 0.3139 |
| fed2010 | 147 | 0.2667 |
| fed2013 | 150 | 0.2639 |
| fed2016 | 147 | 0.3428 |
| fed2019 | 143 | 0.1898 |
| fed2022 | 150 | 0.2961 |
| fed2025 | 150 | 0.2592 |
| vic2014 | 73 | 0.2505 |
| vic2018 | 88 | 0.1948 |
| vic2022 | 78 | 0.2399 |
| wa2001 | 57 | 0.6819 |
| wa2005 | 46 | 0.2235 |
| wa2008 | 38 | 0.6840 |
| wa2013 | 55 | 0.3699 |
| wa2017 | 54 | 0.3105 |
| wa2021 | 58 | 0.1008 |
| wa2025 | 53 | 0.1985 |
| nsw2023 | 88 | 0.2539 |
| nsw2019 | 93 | 0.3769 |
| qld2024 | 93 | 0.3071 |
| qld2020 | 93 | 0.2482 |
| sa2026 | 47 | 0.4597 |
| sa2022 | 47 | 0.2934 |

wa2001 and wa2008 are now the worst pairs in the corpus, not sa2026 — a
material change to where the next round of investigation should look.

## What this means for tonight's other findings

Everything measured earlier tonight by rebuilding the pipeline more than once
in a session — the SD-model arm comparison, the census demographics arms,
the ONP same-jurisdiction mechanism, the `all_election_pairs()` test — used
numbers from a `pooled-sharedetail.csv` that may have been one or more
iterations into this loop. The **relative** comparisons within a single
clean rebuild (e.g. "arm A vs arm B measured back to back without repooling
in between") are likely still valid, since the contamination is a property
of `pred_share`/the baseline, shared equally by both arms. The **absolute**
numbers, and any comparison that spanned a repool in between, are not to be
trusted without re-verification.

## Fixed tonight

- `scripts/pool_sharedetail.R` and `scripts/fit_xgb_primary_v6.R` carry loud,
  explicit warnings with the four-step correct procedure.
- PR #34 updated with the corrected numbers (this doc, plus a PR comment).

## Not fixed, and flagged as the top follow-up

There is no way, from a sharedetail file's name or content, to tell whether
`AUSPOL_XGB_PRIMARY` was on or off when it was generated — the arm
fingerprint hashes every set `AUSPOL_*` variable, but the hash is a one-way
sum, not decodable. The robust fix is to have each harness record the flag's
value as a column or sidecar file per sharedetail output, and have
`pool_sharedetail.R` refuse (not just warn) when it would pool a contaminated
file. That is real, careful work and was not attempted at 2am — a comment is
not a substitute for an enforced check, and the next session should build one
before this can be trusted to catch itself again.
