# Defector carry: no overall bias; federal leans over, from the xgb layer (2026-10-14, measured)

**Status: OPEN, small. The first version of this review (+3.0 pts over-call, 13 of 18) was WRONG: it came from
`output/defector-cases-all.csv`, a one-off file from 2026-09-09 with no committed builder, which predates the 13 new
elections and matched only 18 of its 29 cases by name. Retracted the same morning.**

## How it was measured

`scripts/diag_defector_overcarry.R` rebuilds the cases with `fit_defector_discount()`'s own definition
(R/candidate_returns.R): a Labor/Liberal/National candidate with at least 10% at the previous election who stands
under a non-major label in the same seat (or its renamed successor) at the next. Losing candidates count; `was_mp`
marks sitting members. Each case is joined to `output/forecasts.csv` (published as-at path, run 4e03af5) on
election, seat and the defector's class; a class with two candidates in the seat is dropped. Writes
`output/defector-overcarry.csv`.

59 cases over 27 elections; 52 scored. Dropped: fed2007 Corio and Lyons, wa2001 Pilbara, wa2005 Vasse, wa2008
Nedlands (no as-at prediction), nt2020 Fong Lim and Johnston (two candidates in the class).

## Result

Over-call = final predicted primary minus actual, percentage points; positive means we gave the defector too much.
SE is across cases.

| slice | n | mean over-call (SE) | median | over-called | base_pred mean | old party mean |
|---|---|---|---|---|---|---|
| all | 52 | -0.35 (1.49) | +0.27 | 27 | -2.03 | -1.36 |
| sitting members | 34 | +0.36 (1.86) | +1.26 | 18 | -1.84 | -1.79 |
| losing candidates | 18 | -1.69 (2.53) | -0.03 | 9 | -2.41 | -0.53 |
| federal | 6 | **+6.81 (3.72)** | +5.93 | 5 | +0.76 | -7.32 |
| state | 46 | -1.28 (1.58) | -0.27 | 22 | -2.40 | -0.58 |

## Reading

- **No overall bias.** The misses are large in BOTH directions: over-called fed2010 Ryan +23.6, nt2016 Arnhem
  +17.9, qld2017 Pumicestone +14.9, wa2017 Hillarys +7.3; under-called nt2020 Arnhem -30.3, qld2012 Dalrymple
  (Knuth) -25.2, vic2018 Melton -21.6, nt2024 Blain -18.7, nsw2023 Kiama -12.4. The problem is spread, which the
  carry rate cannot fix; which defectors hold up is the open question.
- **Federal leans over, and the xgb layer adds it**: base_pred +0.76, final +6.81 over 6 cases (1.8 SE, thin).
  xgb lifts Dobell 10.0 -> 18.2 (actual 12.2), Tangney 12.0 -> 17.7 (11.9), Monash 18.7 -> 24.9 (27.3), Calare
  28.7 -> 39.6 (39.5). Right on two, wrong on two; not a fix candidate at n=6.
- wa2017 Hillarys is a tail case, not a pattern. Its SEAT-REGISTRY note about WA's higher own-carry (0.693) still
  stands: raising it would make Hillarys worse.

## Part 2: who holds their vote (2026-10-14, `scripts/diag_defector_holders.R`, `output/defector-holders.csv`)

Retention = actual share / previous share. Over-call as above. Pre-election facts only.

| electorate size (formal votes, previous election) | n | median retention | mean over-call (SE) |
|---|---|---|---|
| under 10k (all NT) | 8 | 0.65 | -8.3 (5.0) |
| 10-30k | 25 | 0.44 | -0.4 (1.9) |
| 30-60k | 13 | 0.42 | +1.2 (2.7) |
| 60k+ (all federal) | 6 | 0.24 | +6.8 (3.7) |

- **Electorate size is the one fact that moves the over-call**: Spearman over-call vs log formal votes +0.37
  (p 0.007, n=52). The model gives a big-seat defector too much and a small-seat one too little. But size is almost
  the same thing as jurisdiction here (NT at one end, federal at the other); within the non-NT state seats the
  slope keeps its sign but is not distinguishable from zero (rho +0.22, p 0.19, n=38).
- **Not separating**: times previously elected (Spearman with retention -0.08; counted from the corpus, 6 SA
  members unmatched), previous share (+0.06), sitting member vs losing candidate (over-call +0.4 vs -1.7).
- **Unmeasured and probably the real driver**: WHY they left. Holders include members who left on a local or
  principled issue (Gee, Broadbent, Purick, Turner, Knuth, Bell, Cregan); collapsers include several who left under
  a scandal or charge (Thomson, Ryan's Johnson, Speirs, McBride, Judge, Lee). Ward (Kiama, charged, held 0.72) breaks
  it. This would need hand-coding from pre-election sources (memory: fixed pre-election sources).

Candidate change, NOT built: let the sitting-member carry fall with electorate size (a slope on log formal votes,
shrunk toward the current flat rate), which would address the federal +6.8 and the NT -8.3 together. Needs Pete to
walk the rows first.

## Part 3: the AUSPOL_DEFECT_SIZE arm, screened and REFUSED (2026-10-14)

Built behind `AUSPOL_DEFECT_SIZE` (off; R/candidate_returns.R `.defect_size_slope()`, applied in
`personal_prior_vote()`, so base_pred in every harness). Screened with `scripts/quick_arm.R` at 1,000 sims on the 19
elections that have a sitting-member defector (1,719 seats).

| run | pooled seat log loss (lower is better) | share sq. error on changed cells |
|---|---|---|
| as built, 19 elections | 0.3284 -> 0.3299 (+0.0015, SE 0.0056) | +54% |
| clamped to the fitted size range, 4 moved elections | 0.5075 -> 0.5065 (-0.0010, SE 0.0324) | +89% |

fed2010 improves (Ryan, -0.037 both times); nt2016 is the damage (+0.30, clamped +0.19). Every nt2016 seat (2.5-4.4k
votes) is smaller than any earlier case, so it takes the edge rate, 0.80 against the flat 0.42; actual retention
there was 0.20-0.88 (median 0.60). The arm then makes the defector favourite in all five seats, and because the
carried vote is taken out of the old party, the CLP falls to 3-5% where it actually polled 20-36%.

**Refused.** What it was given: the full 52-case outcome table, the shipped carry machinery, a shrunk and clamped
slope. What it was not given: any NT case before nt2016 (none exist), and a model of the old party keeping part of a
defector's vote. That second point is the more promising lead: in nt2016 the defector and the old party together
polled MORE than the old party's previous share in four of five seats, so a "carry" taken out of the old party is the
wrong shape there. Switch stays in the code, off.

## Part 4: does the old party keep more? Mostly no: the miss is the SPLIT (2026-10-14, `scripts/diag_defector_oldparty.R`)

Combined = (defector now + old party now) / defector's previous share; above 1 means the pair grew.

| slice | n | actual combined (median) | predicted combined (median) | old-party over-call mean (SE) |
|---|---|---|---|---|
| all | 52 | 1.18 (above 1 in 43) | 1.16 | -1.4 (1.3) |
| sitting members | 34 | 1.12 | 1.08 | -1.8 (1.6) |
| federal | 6 | 1.08 | 1.08 | -7.3 (4.6) |
| NT | 8 | 1.16 | 1.02 | +4.5 (2.7) |
| SA | 9 | 1.33 | 1.05 | -0.9 (2.3) |

- **The model already gets the pair's TOTAL right** (median 1.16 predicted vs 1.18 actual). The NT 2016 pattern
  (pair grew, old party kept far more) does not generalise beyond NT and SA.
- **The error is who gets the vote, not how much there is.** Defector and old-party over-calls correlate -0.75
  (n=52); each has sd ~10 points, their sum sd 7.2. When we over-call a defector we under-call their old party by
  nearly the same amount (Ryan +23.6 / -28.6, Hillarys +7.3 / -17.1, Kiama -12.4 / +14.7).
- So a "don't subtract the carry" switch would fix the total where it is already right. **Not built.** The split is
  person-level, and the one candidate explanation left is why the member left (part 2), which needs hand-coding
  from pre-election sources. That is Pete's call.

## Part 5: exit reason (PRE-REGISTERED 2026-10-14, before any coded row was seen)

Pete chose to code why each of the 52 left (scandal / preselection / principled / other / unclear), from Wikipedia
revisions or archive captures dated BEFORE polling day only; coders get no results. Four Sonnet agents, 13 cases each.

Test (`scripts/diag_defector_reason.R`): over-call (final predicted share minus actual) and retention by reason.
- **Primary:** mean over-call, scandal minus principled. A real effect is a difference of at least 2 SE (Welch, per
  case), in the direction scandal over-called. Expected from the part-2 reading: scandal over, principled under.
- **Decision:** passes -> build a reason-conditioned carry (rate per reason, shrunk toward the pooled rate) behind a
  switch and screen it as in part 3; fails -> the defector line closes, recorded here.
- **Unacceptable win:** any coded row whose source is dated on/after polling day, or more than 10 unclear: then the
  result is not reportable until fixed. Spot-check 5 random rows' sources by hand before reading the test.
