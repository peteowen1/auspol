# Pre-registration: replace flat `shrink` with insurgency-conditional uncertainty

Written 2026-08-25, **before any risk model was fitted**. Committed before
fitting.

## The defect this addresses

`shrink` is a per-draw coin toss between the final two candidates at a flat
rate `s`, applied identically to every seat. It caps the maximum achievable
probability at `1 - s/2`. Measured on the federal corpus at `s = 0.10`: the
highest probability the model can emit is **0.9598**, and **zero** seats sit
above 0.99 where the unshrunk model had 529.

That flat cap fixes the aggregate. It does so by destroying resolution at the
top, and it charges every safe seat a premium for a risk that only some seats
carry.

**The risk it is absorbing has one name.** Of the 9 misses at `pred_p > 0.9999`
in the federal backtest, **8 were a non-major winning a seat called safe for a
major**: Denison 2010 (Wilkie), Lyne 2010 (Oakeshott), Melbourne 2010 (Bandt),
Fairfax 2013 (Palmer), Indi 2013 (McGowan), Warringah 2019 (Steggall), Curtin
2022 (Chaney), Fowler 2022 (Dai Le). The ninth, New England 2013, is Joyce
taking back an independent-held seat — the same axis. **There is not one
major-versus-major upset among them.** Strip that failure mode and the hit rate
at `p > 0.9999` is **99.7%**.

This is the same error as the South Australian One Nation misses, inverted:
there the model gave 0% where a minor could win; here it gives 95% where a major
cannot lose.

## The risk is strongly predictable from pre-election data

From `output/fed-upset-features.csv`, 886 federal seat-elections, 49 won by a
non-major (5.53%). Every feature is computed from the `from` election only.

| best non-major share at `from` | seats | non-major wins | rate |
|---|---:|---:|---:|
| ≤ 5% | 25 | 0 | 0.0% |
| 5–10% | 320 | 3 | 0.9% |
| 10–15% | 327 | 5 | 1.5% |
| 15–20% | 109 | 3 | 2.8% |
| 20–30% | 69 | 10 | 14.5% |
| > 30% | 36 | 28 | 77.8% |

| non-major held the seat at `from` | seats | wins | rate |
|---|---:|---:|---:|
| no | 849 | 19 | 2.2% |
| yes | 37 | 30 | 81.1% |

Monotone, and the gradient spans two orders of magnitude.

## What will be built

A per-seat insurgency risk `r_i`, and a per-seat shrink `s_i = 2 * r_i`, clipped
to `[0, 0.20]`. The factor 2 is not tuned: a flat shrink `s` caps a seat at
`1 - s/2`, so `s_i = 2 r_i` caps seat `i` at `1 - r_i`, which is exactly the
statement "this seat's ceiling is its own upset risk". **The clip at 0.20 is
pre-registered here and will not be moved.**

`r_i` comes from a logistic fit on two features only — `nm_best` (best single
non-major share at `from`) and `nm_held` — because there are 49 events. A third
feature would be one per 16 events and is refused in advance.

**Fitted by leave-one-election-out cross-validation over the six federal
elections.** The fold being predicted never contributes to the fit. This is the
only defence against a calibration layer that looks excellent in-sample and does
nothing live.

## Criterion

Scored on the federal corpus, 5,000 sims, against flat `shrink = 0.10` as the
incumbent. All three must hold.

1. **Reliability preserved.** No probability bucket falls outside its own 95%
   binomial CI. Flat `shrink = 0.10` currently achieves 0 of 6 outside; the
   unshrunk baseline was 4 of 7 outside. **This is a guard, not the goal** —
   equalling the incumbent is a pass.
2. **Resolution restored — this is the point.** The top bucket must exceed
   **0.97** in mean predicted probability, against 0.953 for flat shrink, AND
   the seats it contains must win at a rate whose 95% CI includes what was said.
   At n ≈ 300 the binomial SE on a 97% rate is 0.99 points, so a 2-point
   movement is ~2 SE and detectable. A change that lifts the ceiling but misses
   on the outcome fails.
3. **Log score does not worsen.** Paired per-seat over 886 seats. The observed
   paired SE on this corpus is ~0.02–0.11 per election, so a worsening beyond
   0.05 pooled is detectable; **any pooled worsening greater than 0.02 fails.**

## Refusal — what disqualifies a winner

Named in advance, per CLAUDE.md, because two of the last four experiments here
were refused on grounds invented after the results, and one was wrongly refused
on a 0.43 SE movement.

- **If the gain comes only from the ~37 non-major-held seats**, the change is a
  special case for a handful of famous seats rather than a model of insurgency.
  Refuse unless the improvement survives excluding `nm_held == 1`.
- **If any seat's probability rises above 0.995**, the model is claiming a
  certainty the corpus cannot support at any risk level — the best observed
  bucket wins 97.2%. Refuse.
- **If the number of confidently-wrong seats (`pred_p > 0.95` and wrong) rises
  at all**, the change is buying resolution with exactly the errors that
  motivated `shrink`. Refuse.
- **If leave-one-election-out and in-sample fits disagree by more than 20% on
  mean `r_i`**, the risk model is fitting election-specific noise. Report and do
  not adopt.

## What the criterion cannot see

- **The teal wave is not stationary.** Non-major wins run 5 per election from
  2010 to 2019, then 16 in 2022 and 13 in 2025. A risk model fitted on the
  earlier elections will under-predict the later ones, and leave-one-election-out
  will make 2022 look worse than a live forecast would have been in 2025. The
  criterion cannot separate a bad model from a genuine regime change.
- **Victoria has no federal teal history to learn from**, and the live target is
  Victoria 2026. The federal fit is the only corpus with power, and its transfer
  to a state election is untested.
- **Nothing here uses the salience signal.** That signal is candidate-level and
  covers ~21 candidacies across 3 elections, so it cannot drive a per-seat term
  over 886 seats. It remains the right input **after** nominations close on
  9 November 2026, layered on top of this structural risk rather than instead of
  it.
- **`nm_best` is measured at `from`, so a first-time insurgent with no prior
  vote is invisible.** Wilkie in Denison 2010 is exactly that case. This model
  cannot catch the first occurrence in a seat, only the repeat.
