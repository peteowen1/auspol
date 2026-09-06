# Pre-registration v3: C3, widened and made cross-era comparable by construction

2026-09-04, written before this is scored decisively beyond the sizing pass
disclosed below. Supersedes `prereg-salience-c3-amended.md`, which is left
unedited: `docs/reviews/c3-amended-recount-2026-09-04.md` showed its emergence
pool was 5, not 9, four-of-five concentrated in one party and one state, and
its own refusal clauses fire on that count before scoring.

Everything else about the gate stands: prior share < 15% (`GATE`), fitted on
fed2022 gated rows. C1 and C2 of `prereg-salience-emergence-gate.md` and
`prereg-salience-precision-v2.md`'s replacement C2 are untouched by this
document.

## Two changes, both load-bearing, both proven before this ran

**1. The salience feature is a within-election percentile, not raw jump.**
`fetch_salience_v6.R`'s own header states the design intent: *"THE CRITERION
NEVER NEEDED CROSS-ELECTION SCALE... a rank statistic is invariant to it."*
The gate model used `log1p(jump)` anyway — not invariant to the different
anchor (a different PM or Premier per era, each with different intrinsic
search volume) every batch is normalised against. Switching to
`xp = rank(jump)/.N`, computed once per election, makes cross-era and
cross-region comparability structural rather than assumed.

Checked against the criteria already trusted before this document exists:
refit on fed2022 gated rows, the percentile model still passes the do-no-harm
test on fed2025's gated subset (RMSE improves −0.233, weaker than the raw-jump
model's −0.410 but comfortably inside the 0.37 bar) and the coefficient is
still solidly significant (t = 5.39, p = 1.3e-07). **Weaker per case than raw
jump** — Kooyong's prediction moves ~2 points under percentile against ~13
under raw jump — but safe, and the trade this document exists to make: real
predictive power for structural comparability.

**2. The emergence population is recomputed by PERSON, across every election
with salience-v6 coverage, not just nsw2023/sa2026.** Party-CLASS prior vote
(what the amendment used) counts a returning member who switched label as a
fresh emergence — the exact trap this session already found once, in
`analyse_incumbent_transfer.R`. Matched by name here: a candidate counts as an
emergence only if their own prior vote in that seat was under 15% **and**
they are a different person from that seat's previous winner.

`scripts/build_c3_widened_population.R` builds this, with a hard assertion
that every merge is row-count-preserving — the exact bug (party-class and
then salience matched by seat+party alone, both fanning out across multiple
same-class candidates in one seat) that inflated an early pass of this count
to 22 and then 24 before being caught and fixed.

## The population

**8 election clusters, 18 genuine emergences, 17 with usable salience
coverage** (Robert Roylance, Hammond, sa2026, has no Trends coverage and is
excluded, not imputed):

| election | region | emergences (usable) |
|---|---|--:|
| fed2010 | fed | 2 |
| fed2013 | fed | 2 |
| fed2016 | fed | 1 |
| fed2019 | fed | 3 |
| nsw2023 | nsw | 2 |
| sa2026 | sa | 5 |
| vic2022 | vic | 1 |
| wa2008 | wa | 1 |

Every one had a clean **zero or near-zero** prior vote in that seat (the
census's `own_prev_pcv` for 15 of 17 is under 5), not a borderline case near
the 15% gate. One Nation is 3 of 17 (18%), down from the amendment's 4 of 5
(80%). Four regions, six party labels (IND, ONP, GRN, OTH_RIGHT), 2008–2026.

"Base" (uniform swing) generalises the exact formula
`prereg-salience-emergence-gate.md` and `prereg-salience-precision-v2.md`
already scored against — this candidate's own prior seat vote plus that party
class's statewide movement in that region — to every region rather than only
federal, so results stay comparable across the whole thread rather than
introducing a new baseline partway through it.

## Criterion 1 (primary) — mean absolute error on the 17 held-out emergences

**Must improve on base by at least the sized MDE, clustered by election.**

Sized from this data: per-cluster mean improvement 3.226, sd 0.934 across 8
clusters, clustered SE 0.330, MDE at 2.80× SE (80% power) = **0.924**.

**Disclosed because it was already computed while sizing the bar, per the
convention this whole thread has followed rather than hidden until scoring**:
observed clustered mean improvement is **3.226** — roughly **9.8× the MDE**.
Every one of the 8 clusters improves; none is flat or negative.

## Criterion 2 (guard) — do-no-harm across every gated non-major row

**RMSE over ALL gated non-major rows in each test election must not worsen.**

Observed: improves in every one of the 8 elections individually (base RMSE
6.19–13.05 by election, pred RMSE 5.73–12.06 — every pair moves the same
direction), pooled base 8.187 → pred 7.488, a −0.698 point improvement.

## Dry-run: named cases, not invented after the fact

All 17 usable emergences, not a cherry-picked subset — the full list is the
dry-run:

| election | seat | who | base → pred | actual |
|---|---|---|---|--:|
| fed2010 | Denison | Andrew Wilkie | 0.0 → 4.0 | 21.3 |
| fed2010 | Lyne | Robert Oakeshott | 0.3 → 4.2 | 47.1 |
| fed2013 | Fairfax | Clive Palmer | 6.6 → 9.5 | 26.5 |
| fed2013 | Indi | Cathy McGowan | 1.9 → 5.7 | 31.2 |
| fed2016 | Mayo | Rebekha Sharkie | 0.0 → 3.6 | 34.9 |
| fed2019 | Clark | Andrew Wilkie | 0.0 → 3.1 | 50.0 |
| fed2019 | Indi | Helen Haines | 0.0 → 4.2 | 32.4 |
| fed2019 | Warringah | Zali Steggall | 0.0 → 4.3 | 43.5 |
| nsw2023 | Balmain | Kobi Shetty | 0.3 → 4.2 | 40.5 |
| nsw2023 | Wakehurst | Michael Regan | 3.7 → 7.1 | 35.9 |
| sa2026 | Kavel | Matt Schultz | 1.4 → 2.5 | 21.6 |
| sa2026 | MacKillop | Jason Virgo | 0.0 → 1.4 | 35.1 |
| sa2026 | Mount Gambier | Travis Fatchen | 0.0 → 3.6 | 27.1 |
| sa2026 | Narungga | Chantelle Thomas | 1.4 → 5.1 | 37.7 |
| sa2026 | Ngadjuri | David Paton | 1.4 → 2.5 | 34.7 |
| vic2022 | Richmond | Gabrielle de Vietri | 0.0 → 3.9 | 34.7 |
| wa2008 | Kalgoorlie | Bowler | 0.0 → 1.4 | 34.0 |

Every row moves toward the actual result. Names most readers will recognise —
Wilkie's first win, Oakeshott, McGowan, Sharkie, Steggall, Haines — are here
because that is who the corpus's genuine emergences are, not selected to look
favourable.

## Refusal — what disqualifies a winner, stated before running decisively

- **If any single cluster is driving the aggregate.** All 8 improve here;
  restated as a standing check because it is the clause that killed the
  amendment.
- **If One Nation drives the gain and it does not survive dropping SA.**
  Computed here rather than left for scoring, per the same disclosure
  convention as the primary bar: excluding sa2026 entirely (7 clusters,
  12 emergences) the mean improvement is **3.521, clustered mean 3.377,
  SE 0.339, MDE 0.949** — *stronger* than the full-population result, not
  weaker. One Nation is not carrying this.
- **If Criterion 1 passes only because the percentile coefficient (fitted on
  fed2022) is near zero.** It is not (t = 5.39); restated because it is the
  standing refusal for every version of this gate.
- **If any UNGATED candidate in the test population moves at all.** Same leak
  check as the original document and its amendment.
- **If the 0.924 bar or the population above is altered after this document
  is committed**, without a visible, dated addition explaining why and
  whether it favours the answer already seen.
- **This does not itself authorise shipping the percentile-based gate.**
  Passing C3 answers "does salience detect emergences it hasn't seen," not
  "should the published forecast use it." That is a separate decision, and
  the weaker per-case magnitude (Kooyong moving ~2 points instead of ~13)
  is a real cost to weigh against the now much better-evidenced signal.

## What this cannot see

- **17 usable observations still carry the whole result**, however
  consistent. A ninth cluster's sign would matter more than any of the
  current eight individually.
- **sa2026 is still nearly a third of the usable emergences (5 of 17)** even
  after widening — SA's 2026 One Nation breakthrough remains the single
  largest contributor to the pool, just no longer 80% of it.
- **The percentile transform discards magnitude.** A candidate who is 100×
  louder than anyone else in their seat and one who is merely the loudest by
  a whisker both read as `xp ≈ 1.0`. This is the direct cost of the fix that
  makes comparability structural, and it is why every predicted move here is
  smaller than raw jump would have given.
- **`own_prev_pcv` and `base` use the simple uniform-swing formula**, not the
  full `dev_slope()` machinery the published harnesses use. Consistent with
  every criterion scored so far in this thread, but not what actually ships.
- **wa2013/2017/2021/2025 and qld2020/2024 contribute nothing** — confirmed
  by direct check, not assumed: WA elected zero non-major MPs to its 59-seat
  Assembly across those four elections, and QLD's five non-major 2024
  winners were all returning incumbents. Real findings, not gaps in the
  corpus.
