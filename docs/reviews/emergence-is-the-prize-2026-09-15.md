# Emergence is where the log loss is, and three harnesses could not see it

2026-09-15. Measured after seat-seat correlation was investigated and found not
worth building (`seat-correlation-gap-2026-09-15.md`).

## First, a parity gap that hid the evidence

`fed`, `sa` and `qld` wrote a full per-seat per-party probability table.
**`nsw`, `vic` and `wa` did not** -- `wp <- as.data.table(sim$win_prob)` sat in
memory in all three and was discarded at the last step. The Queensland harness
even carries a comment describing that exact loss at its own equivalent line,
and it was never ported.

So any emergence analysis saw 1,284 seats, 82% of them federal, and federal has
almost no emergences. The first run of this analysis reported "only 2 seats
below 1%, worth 3.0% of log loss" -- an artefact of the missing jurisdictions.
Fixed in all three in the same commit, per the rule that a fix to one harness
is a fix to all of them.

The corpus went 1,284 -> 2,064 winners, and the two worst cases in the entire
corpus were in the part that had been invisible.

## Where the log loss actually is

Every row is a seat somebody won; `prob` is what we gave the eventual winner.

| winner's own probability | seats | % of seats | % of pooled log loss |
|---|--:|--:|--:|
| < 0.0001 | 1 | 0.0% | 1.7% |
| 0.0001-0.01 | 5 | 0.2% | 5.6% |
| 0.01-0.05 | 17 | 0.8% | 10.6% |
| 0.05-0.10 | 13 | 0.6% | 5.8% |
| 0.10-0.25 | 69 | 3.3% | 21.2% |
| 0.25-0.50 | 136 | 6.6% | 23.0% |
| > 0.50 | 1823 | 88.3% | 32.1% |

**Six seats -- 0.3% of the corpus -- cost 7.3% of pooled seat log loss.**
Twenty-three seats under 5% cost 17.9%.

The worst, with what we gave them:

| seat | winner | our probability | log-loss cost |
|---|---|--:|--:|
| Barwon | OTH_RIGHT | **0.00005** | 9.90 |
| Orange | OTH_RIGHT | 0.00020 | 8.52 |
| Pilbara | IND | 0.00085 | 7.07 |
| Alfred Cove | IND | 0.00225 | 6.10 |
| Calare | LNP | 0.00525 | 5.25 |
| New England | LNP | 0.00690 | 4.98 |

Barwon and Orange are nsw2019, the Shooters, and both were invisible before the
parity fix. Barwon at 0.00005 is a one-in-twenty-thousand call that happened.

## The prize

Upper bound -- what a perfect detector could deliver if it only ever raised the
seats that deserved it:

| if no winner scored below | pooled log loss | gain |
|---|--:|--:|
| current | 0.2783 | -- |
| 1% | 0.2714 | 0.0069 |
| 2% | 0.2687 | 0.0096 |
| **5%** | **0.2619** | **0.0164** |
| 10% | 0.2525 | 0.0258 |

For scale: the best measured change of the entire session -- all seven census
columns under an elastic net across 22 pairs -- moved pooled seat log loss by
**0.0018**. A 5% targeted floor is **nine times** that, from 23 seats.

## A blanket floor does NOT work, which localises the problem exactly

Raising every party in every seat to a floor and renormalising, so the cost on
the 1,823 seats the favourite won is actually paid:

| floor | pooled log loss | net gain |
|---|--:|--:|
| 0 (control) | 0.2783 | -- |
| 0.002 | 0.2774 | **+0.0009** |
| 0.005 | 0.2809 | -0.0026 |
| 0.01 | 0.2898 | -0.0115 |
| 0.05 | 0.3706 | -0.0923 |

The floor-0 control reproduces the baseline to nine decimal places and every
seat's probabilities sum to 1.0000.

An earlier version of this table was wrong: it grouped on `(file, seat)`, and
the Victorian and WA files hold several pairs each, so same-named seats from
different elections were pooled and renormalised together. A 0.2% floor
appeared to move log loss by 0.40, and the implausible size is what made it
visible. The control row exists because of that.

So a tiny blanket floor is worth +0.0009, and everything above 0.5% is actively
harmful. **The entire prize is in knowing WHICH seats deserve the raise.**

## The discriminator already exists

`AUSPOL_XGB_SURGE` -- out-of-fold **AUC 0.936**, built 2026-09-11 after "we
cannot predict who surges" was overturned by giving the model the full feature
set instead of 7 of 25. Per `docs/MODEL-REGISTRY.md` it is:

- wired into `backtest_candidate_sa.R` **alone**, which the registry itself
  flags as the all-harnesses rule outstanding rather than satisfied;
- carrying an **unimplemented live-path stub**, so `fit_seats_full.R` cannot
  honour it even if asked;
- **refused** on a pre-registered bar, and judged over-dispersed by a later
  calibration check.

That refusal was made without knowing the prize was 0.0164. It does not reverse
it -- a refusal stands on its criterion -- but the expected value of revisiting
the question, with the classes and the calibration fixed in advance, is now
very different.

## What has NOT been established

- **That the 23 seats are predictable.** AUC 0.936 is on a surge/emergence
  label, not on "this seat's winner will be scored under 5%". Related, not
  identical.
- **The cost of raising the wrong seats.** The blanket-floor table is the crude
  version of that cost; a targeted model's false-positive cost is unmeasured.
- **Whether the fix belongs in the probability or upstream in the primary.**
  Barwon at 0.00005 may be a primary-vote failure rather than a probability
  one, exactly as sa2026 One Nation turned out to be.
- **Anything about Victoria 2026.** No Victorian pair is among the 23.
