# The ONP seat-type gap is not allocation — it is the swing shape

2026-08-25. **Nothing changed.** Follows
[onp-seat-type-asymmetry-2026-08-25.md](onp-seat-type-asymmetry-2026-08-25.md)
and the refused
[../plans/prereg-onp-vote-sourcing.md](../plans/prereg-onp-vote-sourcing.md).

Written after being asked to check we are asking the right question. We were
not. Two hypotheses were tested before this one; both were about *where One
Nation's votes come from*, and the diagnostic below shows the model's One
Nation allocation is not where the problem is at all.

## The question I should have asked first

**Is One Nation's failure in Coalition seats an ALLOCATION problem (we give it
a low primary there) or a CONTEST problem (decent primary, still loses)?**

One line of code answers it, and it is the second:

| 2022 lean | seats | mean ONP primary we project | mean gap to the leader |
|---|---:|---:|---:|
| ALP-leaning | 57 | **20.2** | 13.5 |
| LNP-leaning | 30 | **20.2** | **22.3** |

**The projected One Nation primary is identical by seat type** — 20.2 against
20.2, medians 20.1 against 20.1. The allocation does not favour Labor seats in
the slightest. The two previous hypotheses were aimed at a defect that is not
there.

What differs is who One Nation has to beat:

| seat | our ONP | our LNP | our ALP | P(ONP) |
|---|---:|---:|---:|---:|
| Lowan | **29.2** | 48.1 | 7.0 | 0.050 |
| Gippsland East | **31.0** | 50.4 | 4.3 | 0.048 |
| Sunbury | 29.6 | 23.6 | 28.4 | **0.639** |
| Melton | 26.0 | 19.2 | 26.4 | **0.561** |

Lowan gets a **larger** One Nation primary than Sunbury and loses, because we
project the Coalition at 48.1 there. So the live question is not "whose votes
does One Nation take" but **"is LNP 48.1% in Lowan right?"**

## How the swing is applied, and whether that is right

The candidate model applies a **uniform points swing**:

```r
shares[, p] <- pmax(0, mat22[, p] + (statewide_now - statewide_prev))
```

Every seat's Coalition vote falls by the same *number of points* regardless of
whether it started at 58.9% or 31.5%. The alternative is a **proportional**
swing, where a party loses a fraction of what it holds and strongholds fall
further in points — which is what SA 2026 looked like (MacKillop's Liberals
67.0 → 26.8).

Tested on **2,878 (district, party) observations across 12 cycle-pairs and 5
regions**, restricted to parties actually contesting both times (`p_a >= 3`,
statewide `>= 2`) so a party entering from zero is not scored as a "swing":

| prediction | MAE |
|---|---:|
| **uniform points swing** | **3.724** |
| proportional swing | 3.970 |

**Uniform wins.** The model's current assumption is the better of the two, and
this is the first time it has been checked here. The intuitive fix — make the
swing proportional so strongholds collapse — would make the forecast worse.

## What the data does show, with a caveat that may kill it

Regressing each seat's swing on its own baseline, within cycle and party
(41 party-cycles with n >= 30):

- **mean slope −0.193**
- sign agrees with the statewide direction in only **0.439** of party-cycles

A consistently *negative* slope means seats with a higher base move down
relative to seats with a lower base, **whichever way the party moved
statewide**. That is not proportional swing; it is **mean reversion**, and the
uniform model ignores it.

Sized on Lowan: a −0.19 slope against a base ~24 points above the Coalition's
mean implies roughly **4–5 points** more decline than uniform gives, so LNP
≈43.6 rather than 48.1. Against One Nation's 29.2 that narrows the gap from
19 points to about 14. **Real, and not close to sufficient** to produce
YouGov's Lowan call.

**The caveat is serious and may account for the whole effect.** Regressing a
change on its own baseline produces a negative slope from *measurement noise
alone* — the classic regression-to-the-mean artefact. Any transient component
in the 2022 baseline generates exactly this. Distinguishing genuine mean
reversion from the artefact needs an instrument or a multi-election baseline,
and **until that is done the −0.193 should not be treated as an effect**, let
alone built into the model.

## What we are actually modelling, restated

Worth writing down because two hypotheses were tested against the wrong target:

- The candidate model's output is **a win probability per seat per party**.
- It gets there from **per-seat first preferences** → simulated exclusion count
  with a preference-flow matrix → winner per draw.
- Per-seat first preferences = **2022 seat shares + uniform statewide swing**,
  with One Nation's share re-allocated by federal ONP ordering because it has
  no meaningful 2022 base.
- So a seat-level disagreement can come from the **level** (statewide trend),
  the **allocation** (which seats get the party's vote), the **swing shape**
  (how the statewide move distributes), or the **count** (preferences). The
  first three are separable with the diagnostics above; only the allocation had
  been examined before today, and it is the one that is fine.

## Where this leaves the ONP seat-type finding

Still unexplained, and now better bounded. It is **not** the allocation
(identical primaries), **not** district-level vote sourcing (refused, and the
sign reversed), and **not** fixed by proportional swing (measurably worse).

The remaining candidates, in the order they should be tried:

1. **The statewide Coalition level itself.** If the Coalition's true Victorian
   vote is lower than we project, every stronghold falls with it. This is a
   trend-model question, not a seat-model one, and it is cheap to check against
   the polls.
2. **Mean reversion, if it survives the artefact test above.** Needs a
   multi-election baseline before it can be believed.
3. **The count.** Whether our flow matrix handles an ONP-versus-LNP final pair
   correctly is untested; `CLAUDE.md` already records that `OTH_RIGHT` is a
   catch-all doing the work of six parties, and rural Victoria is where
   three-cornered contests live.
