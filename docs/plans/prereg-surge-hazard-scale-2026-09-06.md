# Pre-registration: the scale of the surge-v2 hazard (P4)

Written and committed 2026-09-06 night BEFORE any arm runs. P4 of
`plan-miss-patterns-2026-09-06.md`. Baseline is the published configuration
with rule 2 of `prereg-vote-belongs-to-the-person-2026-09-06.md` shipped.

## The defect, sized

The salience signal ranks first-time independents well (AUC 0.82–0.96; on
fed2022 the shipped hazard puts Mackellar 6th, Kooyong 7th, Curtin 8th, North
Sydney 12th, Goldstein 19th of 147 seats). The hazard those ranks carry is
0.025–0.045: a 35% surge in one draw in thirty, a 1–3% win probability. AEF
gave the same seats 0.30–0.51. Under log loss a seat at 0.000 costs 13.8 and
the six teal-shaped seats cost 47 points of fed2022's 72; Wakehurst and Kiama
cost 19 of NSW's 27. The ranking is right and the scale is about ten times
too small, because `surge_hazard_for()` fits a ridge-penalised logistic
(lambda 20) on ~13 winners in ~900 seat-classes and shrinks to the base rate.

## The change

One switch, `AUSPOL_SURGE_SCALE` (published value 1 = today), applied to the
per-seat v2 hazard before the point-estimate blend and the draw:
`surge_h <- pmin(1, surge_h * SCALE)`, in all five harnesses and
`fit_seats_full.R`, and in `published_flags.R`. Nothing else changes: the
ranking, the surge size (`surge_mu`, `surge_sd`) and the screen are untouched.

## Grid and stages

Grid: 1 (baseline), 2, 4, 8. Two stages, because a full sweep of 17 elections
is an hour and four of them is four:

1. **Exploration at 5,000 draws** on the four elections that contain
   emergences and overlap AEF — fed2022, fed2025, nsw2023, sa2026 — at all
   four scales. Picks the scale by pooled seat-weighted log loss over those
   four, with RMSE reported. Exploration does not ship anything.
2. **Decision at 20,000 draws** on ALL 17 elections, baseline against the
   scale stage 1 picked (and the neighbour below it if stage 1 was not
   monotone). Pete's objective applies: **pooled seat-weighted log loss over
   all 17 elections, then pooled seat-share RMSE**, both must not worsen, and
   log loss must improve by more than one SE of the paired per-election
   differences.

## Targets (primary), fed2022 at the rule-2 baseline

Goldstein 0.000, Fowler 0.000, North Sydney 0.002, Curtin 0.005, Kooyong
0.007, Mackellar 0.033; Wakehurst 0.000 and Kiama 0.007 in NSW. A working
scale carries each above 0.05 and the top-ranked above 0.20.

Dry run on cases whose answer is known: Wentworth 2022 (already 0.70 from the
Phelps base) and Clark (0.996, a returning incumbent whose class is not a
surge candidate) must not fall; Cowper 2022 (hazard rank 2, lost) and Mallee
2022 (rank 4, lost) WILL rise, and that is the cost the guard below prices.

## Guards

- The false-independent list at the baseline (Kennedy 2013, Lyne 2013, New
  England 2013, Goldstein 2025) must not grow by more than the number of
  emergences newly called: a scale that buys each teal by adding a Cowper is
  a wash and is refused.
- Per-election table: a scale that wins the pool by fed2022 alone and loses
  three or more of the other 16 is reported as that and refused.
- Every returning-incumbent independent seat unchanged to 0.02.
- RMSE: the blend moves the point estimate toward 35% in proportion to the
  hazard, so RMSE will rise on seats with a high hazard that did not surge.
  Pooled RMSE must not rise by more than 0.1 point; if log loss and RMSE
  disagree, log loss decides (the repo's metric order) and the RMSE cost is
  reported in the review.

## Refusal, decided in advance

Refused if stage 2's pooled log loss does not beat the baseline by one SE,
or any guard fails, or the gain sits in the log-loss clamp alone (seats
moving 0.000 → 0.01 with nothing above 0.05). A scale that only hedges is
what surge-v2 already does.

## A second blocker, named before the run

`simulate_seat_contests()` only draws a surge for a candidate already at
`surge_floor = 2` percent of the seat. A first-time independent whose class
base is under 2% (Goldstein's was 1.3% in 2019) cannot surge at ANY scale. If
a seat on the target list stays at 0.000 through the grid, the floor is the
cause, and lowering it is a separate pre-registered change, not something
to fold into this one after seeing the result.

## What this cannot see

It cannot separate "the hazard is too small" from "the hazard is on the
wrong seats": a scale amplifies false positives equally. If the winning
scale's cost is concentrated in Cowper/Mallee-type seats (a departed
independent's residual base plus a salient newcomer), the next experiment is
the hazard's features (the seat's prior independent vote is one of them and
is what fires on New England 2013 at 0.73), not a bigger scale.

## Stage 1 result, 2026-09-06 23:30 — REFUSED as a scale; the finding is the recipient

5,000 draws, four elections, rule-2 baseline code (`82bf887`):

| election | n | x1 | x2 | x4 | x8 |
|---|--:|--:|--:|--:|--:|
| fed2022 | 150 | 0.5261 | 0.5087 | 0.4646 | 0.4732 |
| fed2025 | 150 | 0.3034 | 0.3114 | 0.3423 | 0.4130 |
| nsw2023 | 88 | 0.3137 | 0.3129 | 0.3245 | 0.3824 |
| sa2026 | 47 | 0.3402 | 0.3459 | 0.3608 | 0.3936 |
| pooled (435 seats) | | 0.3862 | 0.3835 | 0.3829 | 0.4238 |

(x1 at 5,000 draws sits above the 20,000-draw baseline by the clamp on
near-zero seats; the comparison is within the stage.) fed2022 improves at x4
and every other election worsens monotonically from x2. The target seats:

| fed2022, p(IND) | x1 | x2 | x4 | x8 |
|---|--:|--:|--:|--:|
| Goldstein | 0.000 | 0.000 | 0.000 | 0.001 |
| Fowler | 0.000 | 0.000 | 0.001 | 0.002 |
| North Sydney | 0.001 | 0.003 | 0.005 | 0.013 |
| Curtin | 0.003 | 0.010 | 0.020 | 0.039 |
| Kooyong | 0.007 | 0.009 | 0.013 | 0.021 |
| Mackellar | 0.035 | 0.068 | 0.113 | 0.196 |
| Cowper (lost) | 0.469 | 0.509 | 0.617 | 0.803 |
| Mallee (lost) | 0.201 | 0.247 | 0.334 | 0.498 |
| Wentworth (won) | 0.704 | 0.759 | 0.858 | 0.989 |

**The scale does not reach the emergences and does reach the false
positives.** Every guard fires: the false-independent list grows (Cowper and
Mallee become calls at x4) while five of six targets stay under 0.05, and
the pooled gain at x4 is fed2022 alone against three losses. Refused.

**Why, from the simulator (`R/seat_sim.R`, `surge_idx`):** with
`surge_parties = NULL` every non-major class is eligible and the surge is
awarded to `cand[which.max(v[cand])]`, the LARGEST non-major in the seat.
In Kooyong, Goldstein, North Sydney and Curtin that is the Greens at 10–20%,
not the independent at 1–10%. The hazard was fitted from a NAMED
independent's salience and pays out to whoever else is biggest; Cowper and
Mallee rise because there the independent IS the largest non-major. The
2% floor (`surge_floor`) is the second half: Goldstein's 1.3% base cannot
receive a surge at all.

**Next, its own pre-registration (P4b)**: the surge goes to the class the
hazard was computed for (the salient candidate's class, carried per seat from
`surge_hazard_for()`), and that class is exempt from the floor. Then the
scale grid again. The scale question is not answered; it was asked of the
wrong recipient.
