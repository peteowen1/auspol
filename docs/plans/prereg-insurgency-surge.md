# Pre-registration: a flat-hazard insurgency surge, in place of `shrink`

Written 2026-08-25, **before the mechanism was implemented**. Committed before
running.

## Why not the two things already tried

**`shrink` is not a model of anything.** It is a per-draw coin toss that
overrules the count: "10% of the time, ignore the simulation". Nothing in an
election works that way, and it caps every seat at `1 - shrink/2` — measured at
0.9598 on the federal corpus, with zero seats above 0.99 where the unshrunk
model had 529.

**Widening `seat_sd` was already measured and does not work.**
`docs/reviews/seat-calibration-2026-08-22.md`, 24 grid points over six federal
elections: "`seat_sd` barely matters across 1.0–2.0." The reason is now clear.
Symmetric widening inflates each party's vote around its projection, and no
plausible Gaussian flips a seat a major leads by 30 points — but that is exactly
where the over-confidence lived (called at 99.9%, won 95.7%). **The failure is a
fat tail, not a wider bell.**

**Per-seat `shrink` was built, and refused** — `docs/plans/prereg-insurgency-
conditional-shrink.md`. It lifted the ceiling and kept the confident band
calibrated (97.1% said, 95.8% won) but broke the mid-range: reliability buckets
outside their CI went 0 of 6 to 2 of 7, worst at (0.8, 0.9] saying 86.3% where
76.5% won. Raising an override in risky seats drags probability toward 0.5 in
seats that were fine.

## The mechanism

In each draw, in each seat, with probability `h`, the strongest non-major's
share is increased by a surge drawn from `N(mu, sigma)` truncated at 0, and the
remaining parties are scaled down proportionally to keep the seat at 100. **The
count then runs normally and decides the winner.** A surge that is not big
enough loses, which is the entire point of doing this generatively.

**No parameter is fitted per seat.** `P(surge)` was fitted and is
**anti-predictive** — out-of-sample AUC **0.326**, with the seats it rates at
11.7% surging 0.0% of the time. `nm_from` and `nm_held` predict *wins* (AUC
0.878) because they find non-majors who are already competitive, which is close
to the opposite of about to surge. So the hazard is **flat**, taken from the
measured base rate, and there is nothing here to overfit.

Values, all measured in `scripts/fit_insurgency_surge.R` and **fixed here**:

| | value | source |
|---|---:|---|
| hazard `h` | **0.0508** | 45 surges in 886 seat-elections |
| surge mean `mu` | **+15.6** pts | mean gain among surging seats |
| surge sd `sigma` | **6.1** pts | sd of the same |

**Eligibility.** The surge applies only where a non-major exists to surge — a
seat with no non-major polling above 2% at the previous election is untouched.
That floor is pre-registered and will not be moved.

## Criterion

Federal, 5,000 sims, against **flat `shrink = 0.10`** as the incumbent. All
three must hold.

1. **Reliability at least as good.** Buckets outside their own 95% binomial CI
   must be **0**, matching the incumbent. The refused per-seat arm scored 2 of
   7; that is the failure this must not repeat.
2. **The ceiling must lift.** At least 50 seats above `pred_p` 0.99, against
   **0** for flat shrink, AND the top bucket's outcome CI must contain what was
   said. At n ≈ 100 the binomial SE on a 98% rate is 1.4 points, so a claim more
   than ~3 points above the realised rate is detectable.
3. **Pooled log score not worse by more than 0.02.** Incumbent is 0.4233 over
   886 seats.

## Refusal — what disqualifies a winner

- **If the eight named misses do not move.** Denison, Lyne, Melbourne, Fairfax,
  Indi, Warringah, Curtin, Fowler were all called at ~100% for a major. If their
  mean probability for the actual winner stays below 0.01, the mechanism is not
  doing the job it was built for, whatever the aggregate says. Refuse.
- **If accuracy falls at all.** A surge that flips seats the model was right
  about is buying calibration with correctness. Note this is a *whole-seat*
  clause and therefore weakly powered — it is a guard, not a decision rule, and
  it may only REFUSE, never justify adoption on its own.
- **If the mid-range degrades the way per-seat shrink did** — any bucket below
  0.9 moving outside its CI — refuse. That is the specific failure being fixed.
- **If the result depends on the hazard value.** `h` is measured, not tuned. If
  moving it to 0.04 or 0.06 changes the verdict, the mechanism is fragile and
  the pre-registered `h` is doing work the data does not support. Report both.

## What the criterion cannot see

- **Whether the surge is the right shape.** `N(+15.6, 6.1)` is fitted to seats
  that surged by at least 10 points, so it is a truncated sample and understates
  small surges by construction. The threshold of 10 is itself a choice.
- **It cannot catch a first-time insurgent with no prior non-major vote.** Three
  of 49 wins came from a base under 10% — Lyne, Indi, Fowler — and the 2% floor
  will exclude the most extreme of those.
- **The teal wave is not stationary.** Surge rates by election run 1.4, 8.0,
  4.8, 4.2, 8.0, 4.0 percent. A flat hazard of 5.08% is wrong in every single
  election; it is only right on average. Conditioning it correctly is what the
  salience signal is for, after nominations close on 9 November 2026.
- **Nothing about Victoria.** The live target has no federal teal history, and
  the transfer of a federally-measured hazard to a state election is untested.
