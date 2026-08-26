# Plan: move the seat model from party classes to candidates

Opened 2026-08-27. Working checklist — tick items here as they land, and record
outcomes in `docs/reviews/`, not in this file.

## The problem in one line

`mat22` is a seat × party-class matrix, so **"IND" is a residual bucket rather
than a party**, and the model cannot tell a returning independent from a
stranger. Measured: that single fact moves a 30% seat to **30.3%** or to
**12.1%**.

Everything below follows from that, and the tickets are ordered so each one is
shippable on its own.

| | ticket | depends on | status |
|---|---|---|---|
| **A1** | ~~Conditional variance by continuity~~ REFUTED; replaced by level-dependent variance | — | pre-registered |
| **A2** | Joint slope + spread retune, stage 1 | — | pre-registered |
| **A3** | Joint retune, stage 2 (spread) | A2 passes | blocked |
| **B1** | Candidate-level rows through the projection | — | open |
| **B2** | Compositional (softmax) shares within a seat | B1 | open |
| **B3** | Open-seat / retirement effect | B1 | open |
| **C1** | Salience gate, precision criterion re-specified | — | open |
| **C2** | Salience C3 on held-out emergences | C1 | open |
| **D1** | `vic2022` winners file | — | open |
| **D2** | WA given names | — | open |
| **E1** | Candidate profile data for the website | — | ready |

---

## A — calibration, without restructuring anything

### A1. ~~Conditional variance by candidate continuity~~ → level-dependent variance

**REFUTED as first written**, before it was pre-registered. See
`reviews/conditional-variance-2026-08-27.md`. The claim was that a new candidate
is far more uncertain, from R² 0.79 against 0.09. Measured, the multiplier is
**0.87** — a new candidate has *lower* residual spread. R² is explained over
total variance, and a new candidate's prior vote is mostly zeros, so there was
almost nothing to explain. The ALP/LNP control reads 7.87 against 7.80, a
multiplier of 1, which is what it must be.

**The replacement, which the same data does support.** Residual spread scales
with the LEVEL of the share, and the model uses one number for every level:

```
sd(share) = 2.01 + 7.04 * sqrt(p(1-p))        (9,015 obs, 17 pairs, b SE 0.15)
```

Today's flat 3.81 is too wide below ~7% and too narrow above ~15%. Too narrow at
the top is overconfidence about who wins, which is what federal calibration
slopes of 0.18–0.38 look like — the first measured mechanism for that symptom.

**Pre-registered** in `prereg-level-dependent-variance.md`. Calibration is the
primary criterion; this moves uncertainty, not point estimates.

**Expected cost, accepted in advance:** it makes emergence seats *worse*, since
a narrower band at 1.8% puts Dai Le's 29.5% further out of reach. Salience is
the intended fix for those and is unshipped, so the cost is current.

### A2. Joint retune, stage 1 — slopes

Pre-registered in `prereg-joint-slope-spread-retune.md` (`5acaff1`). Three arms
(uniform / pooled / conditional-on-candidate) × five harnesses, spread fixed.

**Accept.** Arm C beats uniform on calibration by ≥ 0.419 and does not lose more
than 0.0089 on Brier. Otherwise the whole thing is refused and A3 does not run.

**Watch.** Run one arm per launch — ten arms exceed the 10-minute background cap
and a killed run loses every arm behind it. Use `AUSPOL_FED_PAIRS` to take
federal a pair at a time.

### A3. Joint retune, stage 2 — spread

Five settings on the winning slope arm. Bar is **today's published model**, not
the stage-1 winner.

---

## B — the structural change

### B1. Candidate-level rows through the projection

**Why.** Two independents in a seat are currently summed; a new independent
inherits a stranger's vote; a "uniform IND swing" is close to meaningless.

**Do.** Replace the seat × class matrix with seat × candidate, party as an
attribute. `output/candidate-contests.csv` already carries the history.
`simulate_seat_contests()` runs a candidate-level count already, so the change
is upstream of it.

**Accept.** Byte-identical output when every seat has one candidate per class —
the no-op proof — then measured on all five harnesses.

**Cost.** The largest ticket here. Everything in B depends on it.

### B2. Compositional shares within a seat

**Why.** Shares are forced to 100 by renormalising, which spreads a new
candidate's gain evenly across everyone else. That is wrong: **a teal takes from
the Liberal, not equally from Labor and the Greens.** The current approach gets
the arithmetic right and the substitution wrong.

**Do.** A softmax / multinomial-logit over the candidates in a seat, so
substitution is explicit and estimable.

**Accept.** Correct party loses vote where a strong non-major enters —
checkable directly on the 2022 teal seats.

### B3. Open-seat / retirement effect

**Why.** A personal vote leaves with the person. Currently invisible.

**Do.** Flag seats where the sitting member is not recontesting, from
`candidate-ids.csv`. Note `inc_retiring` was tested as a salience feature and
added nothing — but that was against a class-based baseline.

---

## C — salience

### C1. Re-specify the precision criterion

**Why.** C2 of `prereg-salience-emergence-gate.md` scored win/lose for a
vote-share model and counted 14 candidates who polled 15–26% as false positives.
The gate passed everything else and is unshipped on a criterion now known to be
wrong.

**Do.** New pre-registration, phrased in vote-share error, dry-run on known
cases before committing. State plainly that the 5-point bar was chosen knowing
where the old one passed.

### C2. C3 on held-out emergences

Amended in `prereg-salience-c3-amended.md`. **Recount first**: the corrected
person-based definition leaves **5** held-out emergences, not 9, and 4 of the 5
are One Nation in one state — which trips that document's own refusal clause.
Decide whether to widen to earlier federal elections before running.

---

## D — data gaps

### D1. `vic2022` winners file

731 rows with `elected` still NA, and **Victoria is the live target**. Every
other commission's winners file is on disk; the VEC's 2022 one is not.

### D2. WA given names

2,803 rows (19% of the corpus) carry a bare surname. The cached WAEC JSON has
four fields and no given name, so identities there are scoped to a seat and a WA
candidate who changes seat becomes two people. Check whether a richer WAEC
endpoint exists.

---

## E — website

### E1. Candidate profile data

**Ready now.** `output/candidate-contests.csv` gives every contest a person has
fought. Add the model's projection per row for "performance vs expected".

---

## Which tickets are TARGETED and which are GENERAL

Added 2026-08-27 on Pete's rule: the metric and the window follow the question.
A targeted fix is validated on its named targets with the election-wide number
as a do-no-harm guard; a general change is validated election-wide. Getting this
backwards is why the salience gate's 18.29-point fix on six seats read as a
0.85-point aggregate move and its precision criterion had to be thrown away.

| ticket | kind | primary metric |
|---|---|---|
| A1 level-dependent variance | **general** | election-wide calibration |
| A2/A3 slope + spread retune | **general** | election-wide Brier and calibration |
| B1 candidate-level rows | **general** (structural) | no-op proof, then election-wide |
| B2 compositional shares | **targeted** | the 2022 teal seats — does the LIBERAL lose the vote, not Labor and the Greens equally |
| B3 open-seat effect | **targeted** | seats where the sitting member retired, named in advance |
| C1/C2 salience | **targeted** | the named emergences; election-wide is the guard |

**Name the cases before proposing the fix.** For B2 that is Kooyong, Goldstein,
Wentworth, Mackellar, North Sydney and Curtin in 2022, and the check is which
party's vote falls — a question no aggregate RMSE can answer.

## Standing rules for this plan

- **Every change goes through all five harnesses**, in the same session, with
  before-and-after for each. A parameter present in some and absent from others
  produces numbers that look like findings.
- **Print what was applied** before any result is read.
- **Prove the no-op first** where a change should be neutral by construction.
- **Dry-run every criterion** on cases whose verdict is already known, before
  the pre-registration is committed.
