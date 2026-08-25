# Pre-registration: can One Nation's seat concentration be transported into a new election?

Written 2026-08-25, **before** anything is fitted. Committed before running.

Follows [../reviews/sa-backtest-onp-zero-2026-08-25.md](../reviews/sa-backtest-onp-zero-2026-08-25.md):
on SA 2026, the only election One Nation has won seats at scale, the backtest
harness gives it **0.000 in all four seats it won** and calls MacKillop for the
Coalition at **1.000**. The harness allocates uniformly; the published model
has a concentration step that no backtest implements.

## What is already settled and is not re-tested here

- **The ordering works.** Transposed federal One Nation vote against actual SA
  2026 district vote: **Spearman +0.939**, with the four wins ranked 1, 6, 10,
  15 of 47. Not re-litigated.
- **The problem is concentration.** SA's One Nation vote had **SD 7.67 points**
  across districts (37.5% in Narungga against 22.88% statewide). A uniform
  allocation produces SD ≈ 0, which is why the party finishes second nearly
  everywhere and first nowhere.

## The circularity, and why the obvious test is forbidden

`sa_ratio` is fitted on SA 2026. The published target CV is **0.327**; SA
2026's actual CV is **0.334**. Applying that to SA 2026 and reporting success
would be fitting and testing on one election. **This plan does not do that**,
and any future run that does must not be reported as validation.

## Scoped before the criterion: neither standard transport rule is safe

One Nation's district concentration across the 12 elections where it contested
at least 10 seats:

| | correlation with statewide level |
|---|---:|
| SD in points | **+0.499** |
| CV | **−0.519** |

- observed CV: **0.334 to 2.756** (mean 1.046)
- observed SD: **0.96 to 7.67 points** (mean 3.72)

**SD rises with the level and CV falls with it**, so "hold SD constant" and
"hold CV constant" are wrong in opposite directions. `CLAUDE.md` already
records that these two disagree by a factor of 4.4 across the federal-to-
Victoria gap; this scoping says the truth is between them and that neither
endpoint should be assumed.

## The estimand

Parametrise concentration as a power of the level:

`SD(district vote) = a * statewide^k`

- `k = 0` is SD-constant, `k = 1` is CV-constant. The scoping above implies
  **0 < k < 1**, and `k` is one parameter estimable from the 12 elections.

## Design: leave-one-out, which is what makes it non-circular

1. Estimate `a` and `k` on the elections **excluding SA 2026**.
2. Predict SA 2026's concentration from its own statewide level (22.88%) using
   those coefficients only.
3. Allocate: order SA districts by transposed federal One Nation vote (the
   validated step), spread the statewide total to hit the **predicted** SD.
4. Run `simulate_seat_contests()` and score against ECSA's declared winners.

Nothing from SA 2026's own district spread enters steps 1–3.

## Criterion: an ANCHOR check, not a significance test

Stated plainly because the honest sample is four seats and a significance test
on four outcomes would be theatre. Two experiments today already aborted for
pretending otherwise.

`stats-discipline` is explicit that an anchor failing means the method is
wrong, regardless of aggregate metrics. **A probability of 0.000 on four seats
that were actually won is an anchor failure.** So:

**PRIMARY (anchor): the four seats One Nation won must receive a mean
probability of at least 0.20**, against 0.000 today. That is not "the model is
right"; it is the minimum for the model to be *able* to be right, and it is
the specific defect being fixed.

**SECONDARY (must not break anything):**
- Overall accuracy must not fall below **36/47** (today 38/47 — two seats of
  slack, because moving probability to One Nation must cost something
  somewhere and a fix that costs more than two seats is not a fix).
- Brier must not worsen by more than **0.02** (today 0.1531).
- Calibration slope must move **toward** 1.0, not away (today 0.299).

## Refusal: what would make an apparent WIN unacceptable

- **R1 — it must not simply hand One Nation everything.** If the model's
  expected One Nation seats exceed **8** (actual 4), refuse. A concentration
  large enough to elect four can elect twelve, and overshooting is a different
  failure, not a success.
- **R2 — `k` must not be implausible.** If the fitted `k` falls outside
  `[0, 1]`, the functional form is wrong and must not be used merely because it
  fits. Report it and stop.
- **R3 — it must not rest on SA being an outlier.** SA 2026 has the highest
  statewide level and the lowest CV in the corpus, so it sits at the edge of
  the range `k` is fitted over. **Report the extrapolation distance**: if
  predicting SA requires extrapolating beyond the fitted range of statewide
  levels, say so prominently and treat the result as provisional.
- **R4 — no adoption into the published model from this plan.** Even a clean
  pass establishes that a transported concentration elects the right SA seats.
  It does not establish the right value for Victoria, which is a different
  election with a different level. Adoption needs its own plan.
- **R5 — the ordering must not be quietly re-fitted.** It is validated at
  +0.939 and is used as-is. If any step tunes the ordering to improve the SA
  result, the whole run is void.

## What this cannot see

- **n = 4 seats, 1 election.** This can show the defect is fixable in
  principle; it cannot estimate how well the fix generalises.
- **SA has no Nationals**, so no three-cornered contests — exactly the
  Victorian seats (Lowan, Ovens Valley, Gippsland East) the original question
  was about.
- **It does not test the count.** If the flow matrix mishandles an
  ONP-versus-LNP final pair, this design will not reveal it.

## Prediction, written before running

Expect `k` around **0.4–0.7** and the anchor to **pass** — a predicted SD of
several points, concentrated by an ordering that ranks three of the four winners
in the top ten, should move those seats well off 0.000.

Expect **R1 to be the live risk**, not the anchor: the same concentration that
elects Narungga and MacKillop may also elect Chaffey, Flinders and Stuart,
which One Nation did not win. If expected seats land near 8, the concentration
is doing too much and the honest conclusion is that ordering-plus-spread is not
sufficient on its own.

---

## Result, 2026-08-25: the anchor FAILS, and it exonerates concentration

The prediction above was wrong in an informative way. R1 was never reached;
the **anchor** failed instead.

### The transport itself works well

Fitting `SD = a * statewide^k` on the **14 other elections**, holding SA out:

| | |
|---|---:|
| **k** | **0.380** (0 = SD-constant, 1 = CV-constant) |
| R² | 0.337 |
| **predicted SD for SA 2026** | **7.00** |
| **actual SA 2026 SD** | **7.67** |
| ratio | **0.91** |

A 9% under-prediction from data that never saw the election. **Concentration is
transportable**, and `k = 0.380` confirms the scoping: neither endpoint is
right. (R2 passes — `k` is inside [0,1]. R3 fires: SA's 22.88% is above the
fitted range's 9.58% maximum, so this is an extrapolation and provisional.)

**A bug was fixed to get there.** The first fit gave `k = 0.154`, R² **0.046**,
and a predicted SD of 3.79 — because `aec-fed-firstprefs.csv` pools seven
federal elections and treating a file as an election collapsed 2007–2025 into
one row with statewide 16.47 and SD 0.96, which is impossible for real
division-level data. Splitting by election took R² from 0.046 to 0.337.

### Applied to the model, it changes almost nothing

Arm run with SD 7.00. It applied correctly — delivered SD 6.98, One Nation
ranging **6.8% to 39.0%** across districts against an actual maximum of 37.5%.

| seat | our call | our P(ONP) before | after |
|---|---|---:|---:|
| MacKillop | LNP **1.000** | 0.000 | **0.000** |
| Narungga | IND 0.913 | 0.000 | **0.000** |
| Hammond | LNP 0.716 | 0.000 | **0.000** |
| Ngadjuri | LNP 0.717 | 0.000 | **0.007** |

**Mean probability 0.002 against a bar of 0.20. Anchor FAILED.** Expected One
Nation seats: still 0.0 against an actual 4.

### The diagnosis, and it moves the target

Giving One Nation a realistic 30–39% in the right seats **still does not elect
it**, because the Coalition is left far too high. MacKillop:

| | LNP share |
|---|---:|
| 2022 actual | 67.0 |
| **our uniform swing** (statewide −17.1) | **49.9** |
| a proportional swing (× 19.03/36.15) | 35.3 |
| **2026 actual** | **26.9** |

One Nation cannot beat 49.9 with 35. **The binding constraint is the
Coalition's swing in its own strongholds, not One Nation's concentration.**

This does **not** simply reinstate proportional swing, which was measured worse
overall (MAE 3.724 uniform against 3.970 proportional, 2,878 observations). But
that test pooled mostly *small* swings. Here the statewide move is −17 points
and uniform is out by 23 in a single seat while proportional is out by 8.

**The refined, testable question — and note it is NOT a fourth version of
"whose votes move where":** does the right swing shape depend on the *size* of
the statewide move? A rule that is uniform for small swings and proportional
for large ones is a different hypothesis from either, and the corpus that
answered the first question can answer this one.

### Housekeeping

`BS5` prints `wrote output/backtest-sa.csv` regardless of the actual tagged
filename. The write itself is correctly tagged (`backtest-sa-conc700.csv` was
created; the baseline was not touched) but the **message misreports what the
run did**, which is the class of diagnostic bug this repo records repeatedly.
Worth fixing before it misleads someone.
