# Pre-registration: proportional swing for strongholds of a FALLING party

Written 2026-08-25, **before any arm is scored**. Committed before running.

## The finding this rests on (diagnostic, already run)

Uniform swing beat proportional pooled (MAE 3.724 vs 3.970) and a
magnitude-conditioned version was refused. Neither cut on **base size
interacted with direction**, which is what a stronghold is.

Across 2,878 observations, 12 cycle-pairs, **restricted to a party falling
statewide by more than 2 points**:

| seat over-index (`p_a / sw_a`) | n | uniform MAE | proportional MAE | proportional better |
|---|---:|---:|---:|---:|
| <0.8× | 240 | 3.692 | 3.106 | +0.586 |
| 0.8–1.0× | 203 | 3.694 | 3.698 | −0.004 |
| 1.0–1.2× | 209 | 3.822 | 3.858 | −0.037 |
| 1.2–1.5× | 233 | 4.627 | 4.321 | +0.305 |
| **>1.5×** | **102** | **6.964** | **3.848** | **+3.117** |

For **all** parties regardless of direction, the same >1.5× band has **uniform
better by 1.155** — so the effect is genuinely conditional on falling, not a
general property of strongholds.

**Sanity anchor**: MacKillop is 1.85× over-index with the Coalition falling
17.1 statewide. Proportional predicts **35.3**; AEF forecast **35.0**; uniform
gives **49.9**; the actual was **26.9**.

## The change under test

Apply a **proportional** swing instead of a uniform one when **both** hold:

- the party is falling statewide by more than **2 points**, and
- the seat's share is more than **1.5×** the party's statewide share.

Otherwise uniform, unchanged. Both thresholds are taken from the bands above
and are **fixed now**; they are not tuned in the run.

## Criterion, fixed now

Primary: **seat-winner log score through the full count**, on the historical
corpus, not first-preference MAE — first preferences are not what the model
outputs.

Adopt only if all three hold:

1. Log score improves on **SA 2026** (the motivating election) **and** does not
   worsen on **Victoria 2018→2022** or **NSW 2019→2023**.
2. Pooled first-preference MAE across all 2,878 observations does **not
   worsen**. Uniform has survived six alternatives today; a seventh must not
   cost accuracy elsewhere to buy these seats.
3. Seat accuracy does not fall in any of the three elections.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — it must not be a One Nation special.** The rule is stated for any
  falling party. Report ALP and LNP separately; if it only helps where One
  Nation is the beneficiary, it is a One Nation patch and must be described as
  one.
- **R2 — n = 102 in the decisive cell.** Report the per-cycle breakdown. If the
  >1.5× advantage comes from one or two cycles, it is not established.
- **R3 — it must not make Narungga worse.** Narungga's Coalition is *under*
  -estimated (13.0 against an actual 22.4) and its over-index is **0.83×**, so
  the rule should not touch it. If it does, the condition is wrong.
- **R4 — the 1.5× and 2-point thresholds are FIXED.** If the result is
  sensitive to moving them, that is a finding about fragility, not licence to
  tune. Report sensitivity; do not optimise.
- **R5 — no adoption into the published Victorian forecast from this plan.**
  Victoria has its own stronghold structure and the Coalition there is
  projected to fall only 5.2 points statewide, so this rule may barely fire.
  Adoption is a separate decision.

## What this cannot see

- **It is a first-preference rule.** Whether the count then flips depends on
  flows, which were fixed separately today and are not re-tested here.
- **It does not explain MacKillop fully.** Proportional gives 35.3 against an
  actual 26.9 — still **8.4 points high**. This closes roughly two-thirds of a
  23-point error, not all of it.
- **Mean reversion is NOT this.** Tested separately today with an instrument:
  real but worth only −1.8 points on MacKillop. These are different mechanisms
  and this plan does not adopt that one.

## Prediction, written before running

Expect **criterion 1 to pass on SA** — the mechanism is measured and MacKillop
sits squarely in the winning cell — and **criterion 2 to be the binding
constraint**, because the rule fires on 102 of 2,878 observations and could
easily cost more elsewhere than it gains there.

Expect the seats to improve but **not to flip**: closing two-thirds of
MacKillop's primary error still leaves the Coalition 8 points high, and
Ngadjuri's error is only 8 points to begin with.
