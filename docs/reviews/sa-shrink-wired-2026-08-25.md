# Wiring `shrink` into the SA harness: log score halves, nothing is at 0.000

2026-08-25. The first material improvement of the session, and it is a
**correctness fix, not a modelling change** — the harness was measuring a
configuration we do not ship.

## What was wrong

`backtest_candidate_sa.R` passed **neither `shrink` nor `statewide_draws`**.
`fit_seats_full.R`, the model that publishes, passes `shrink = 0.10` — the
per-draw calibration shrink adopted 2026-08-21 after measuring over-confidence
on 1,187 seats. `simulate_seat_contests()` defaults it to 0.

This is the **same defect** `docs/reviews/calibration-2026-08-21.md` found in
the federal, Victorian and NSW harnesses. It was fixed there and **never fixed
here**, so every calibration figure this harness has produced — including the
slope of 0.299 and the four One Nation seats at 0.000 that drove a full day of
investigation — described a model we do not publish.

## The effect

| | shrink = 0 | **shrink = 0.10** |
|---|---:|---:|
| accuracy | 38/47 | 38/47 |
| Brier | 0.1531 | 0.1488 |
| **log score** | **1.3670** | **0.5171** |
| **calibration slope** | **0.299** | **1.333** |
| mean P(ONP) in the four won seats | **0.000** | **0.033** |
| expected ONP seats | 0.0 | **1.4** |

**The log score more than halves.** That is the metric that punishes confident
wrong calls, and it is precisely the damage a 0.000 on a real outcome does.

Per seat, nothing sits at zero any more:

| seat | P(ONP) before | after | our call before | after |
|---|---:|---:|---|---|
| MacKillop | 0.000 | **0.047** | LNP **1.000** | LNP 0.952 |
| Ngadjuri | 0.000 | 0.031 | LNP 0.838 | LNP 0.793 |
| Narungga | 0.000 | 0.029 | IND 0.851 | IND 0.820 |
| Hammond | 0.000 | 0.025 | LNP 0.772 | LNP 0.729 |

**MacKillop is no longer called at 1.000.** The anchor-check failure that
started this — a seat claimed as certain that the other side won — is gone.

## What this does NOT do, stated plainly

- **It does not fix a single prediction.** Accuracy is unchanged at 38/47 and
  all four seats are still called for the wrong party.
- **It does not meet the pre-registered anchor** from
  [../plans/prereg-onp-concentration-transport.md](../plans/prereg-onp-concentration-transport.md),
  which required mean probability **0.20**. At 0.033 the model still cannot
  meaningfully elect One Nation.
- **The slope now overshoots** at 1.333 against a target of 1.0. Mildly
  under-confident, which is far safer than 0.299, but it is not calibrated and
  should not be described as such.

This is **option 3** from
[why-swing-models-cannot-do-this-2026-08-25.md](why-swing-models-cannot-do-this-2026-08-25.md)
doing exactly what that review said it would: fixing the scoring damage without
fixing the prediction. A model that says 0.95 and is wrong is strictly better,
on every proper scoring rule, than one that says 1.000 and is wrong.

## Still outstanding in this harness

`statewide_draws` is **still not passed**. The federal harness gained it
through forecast mode; SA has no equivalent. Until it does, the SA harness
still injects the actual statewide result as the centre with only per-seat
noise, which `simulate_seat_contests()` documents as making the seat range
"roughly 40% too tight". **The slope of 1.333 above is therefore still not the
published model's calibration**, only a much closer approximation than 0.299.

## The lesson worth carrying

A full day of hypothesis-testing was aimed at explaining four seats at 0.000.
**Some of that 0.000 was the harness, not the model** — and the harness defect
was already documented, already fixed elsewhere, and listed in this repo's own
review from four days earlier.

**Check that a harness passes what the published model passes before
investigating what its numbers mean.** That is the same lesson
`docs/reviews/aeforecasts-benchmark-2026-08-22.md` recorded when it found the
same thing, and it cost a day here because the SA harness was never included in
that fix.
