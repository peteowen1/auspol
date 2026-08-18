# Allocating One Nation across Victorian seats

Written 2026-08-18. **Part decision record, part pre-registration** — and the
split is stated because pretending otherwise would be the exact failure this
file exists to prevent.

## Why this is the weakest link

The seat simulation resolves each contest from first preferences. Every party's
seat-level vote comes from its own 2022 result plus a statewide swing — except
One Nation, which polled **0.28% in Victoria in 2022** and contested 5 of 88
seats. There is nothing to swing from. Its seat-level vote has to be
constructed, and the seat counts move with it.

Two separable questions:

- **ORDER** — which seats is One Nation strongest in?
- **MAGNITUDE** — how wide is the spread between its best and worst seats?

## What has already been run (decision record, not pre-registered)

**Ordering.** Fitted on **Victorian federal 2025 divisions**, the only
Victorian geography where One Nation actually contested — all 38 divisions,
including inner Melbourne. Five forms were named before running and compared by
leave-one-division-out MAE:

| form | LOO MAE |
|---|---:|
| A uniform | 2.328 |
| B linear on minor-right share | 2.264 |
| **C linear on Greens share** | **2.206** |
| D linear on both | 2.258 |
| E multiplicative on both | 2.396 |

C wins, and the fitted relationship is `index = 6.8344 − 0.0968 × GRN_share`.

**This was chosen after an earlier form failed, so it is not a clean test.** The
SA-fitted form it replaced had an intercept that could not put One Nation below
~15% in any seat and had it winning Richmond and Brunswick. Turning to Victorian
federal data was a response to that failure. The five candidate forms were fixed
before *this* run, but the decision to run it at all was reactive.

**Magnitude.** Not fitted. The federal relationship compresses badly — it
predicts a 2.6–6.3% range where actual federal One Nation ran 1.0–13.9%. So the
spread is taken from **SA 2026's observed relative distribution**, measured at a
22.97% statewide level close to Victoria's forecast 20.9%, and Victorian seats
are quantile-mapped onto it after ranking by the index above.

## What is honestly weak about it

1. **The ordering barely beats uniform** — 2.206 against 2.328, a gain of
   0.122 MAE. Real, and small. Individual seat probabilities rest on it;
   the *count* rests on it much less.
2. **Two datasets, two purposes, no joint validation.** Order comes from
   Victorian federal 2025, magnitude from SA 2026. Nothing tests the
   combination, because no Victorian state election has had a large One Nation
   vote — which is the entire problem.
3. **The magnitude transfer assumes Victoria's spread resembles SA's** at a
   similar statewide level. Untestable before 28 November 2026.
4. **Federal divisions are not state districts.** 38 against 88, different
   boundaries. The relationship is transferred, not the values.

## What IS pre-registered here, before running

Two checks that have **not** been run, with criteria fixed now.

**Check 1 — does the ordering survive on other states?**
Refit form C on each of NSW, Queensland and Western Australia's federal 2025
divisions separately, and test each fitted coefficient on Victoria's 38
divisions. Criterion: sign of the Greens coefficient. **Pass if all three are
negative**, i.e. every state agrees One Nation is weakest where the Greens are
strongest. A sign flip in any state means the relationship is local and the
Victorian fit is describing Victoria's own noise.

**Check 2 — does the magnitude transfer hold across elections?**
Take the relative spread of One Nation's seat-level vote in SA 2026
(0.396–1.632 of the mean) and compare it against the same statistic computed
for One Nation in the 2025 federal election *within Victoria*, rescaled to a
common statewide level. Criterion: the ratio of the two interquartile ranges.
**Pass if within 1.5×.** Wider than that and the SA spread is not a general
property of a party polling ~21% but a fact about South Australia.

**Decision rule, fixed now:**

- **Both pass** — keep the current construction and publish seat probabilities
  with the 0.122 MAE caveat stated.
- **Check 1 fails** — drop the ordering and allocate One Nation uniformly.
  A relationship that does not replicate across states is not a finding, and
  uniform is the honest default given the gain was 0.122 to begin with.
- **Check 2 fails** — keep the ordering but widen the magnitude: sample the
  spread parameter across the observed range rather than fixing it to SA's, so
  the uncertainty appears in the seat ranges instead of being asserted away.
- **Both fail** — One Nation's seat-level allocation is not supportable.
  Report a statewide vote share and an explicit refusal to allocate it, which
  is a worse product and a more honest one.

## Not in the package

None of this is exported. `simulate_seat_contests()` takes seat shares as an
argument and does not care where One Nation's came from, which keeps the weak
part visible at the call site rather than buried behind a function that looks
as solid as the rest.
