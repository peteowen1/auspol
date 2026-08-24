# On the one election One Nation won, our backtest gives it 0.000 in every seat

2026-08-25. **Nothing changed.** Run of the existing
`scripts/backtest_candidate_sa.R`, after four hypotheses about the Victorian
One Nation seat-type asymmetry each failed. This stops inferring the defect
from Victoria and reproduces it on ground where the answer is known.

## The result

South Australia 2022 → 2026, 47 districts, scored against ECSA's declared
winners:

| | |
|---|---:|
| accuracy | 38/47 (80.9%) |
| Brier | 0.1531 |
| log | 1.3670 |
| calibration slope | **0.299** |
| **seats One Nation actually won** | **4** |
| **our mean probability in those seats** | **0.000** |
| **expected One Nation seats across the simulation** | **0.0** |

And it is not uncertain — it is **confidently wrong**:

| seat | we said | our probability | actual |
|---|---|---:|---|
| MacKillop | LNP | **1.000** | ONP |
| Narungga | IND | 0.851 | ONP |
| Ngadjuri | LNP | 0.838 | ONP |
| Hammond | LNP | 0.772 | ONP |

A seat called at **1.000** that the other side won is the anchor-check failure
this project's own discipline exists to catch.

## The mechanism, printed by the harness itself

> `BS1  districts with no 2022 One Nation vote to swing from: 28 of 47`

One Nation held essentially nothing in South Australia in 2022. A **uniform**
statewide allocation gives every district roughly the statewide figure and
cannot produce concentration — but One Nation's actual vote was concentrated:
**37.5% in Narungga and 35.3% in MacKillop against 22.87% statewide.**

Without concentration the party is second nearly everywhere and first nowhere,
which is exactly the observed output.

## The caveat that decides what this does and does not prove

`backtest_candidate_sa.R` says so at the top of the file, in capitals, and it
was written before today:

> *"This harness allocates a party's statewide movement to districts UNIFORMLY…
> `fit_seats_full.R` — the model that publishes — does NOT… That step is the
> entire reason One Nation can win a seat in the published Victorian forecast,
> and NO BACKTEST IN THIS REPO IMPLEMENTS IT. So a One Nation result here is a
> bound on the model WITHOUT its allocation, and must not be reported as the
> published model's performance."*

**So this is not the published model failing.** It is the published model's
*allocation step* being the only thing standing between it and this result —
and that step has never been tested out of sample. The same file names the
consequence: *"SA 2026 is the only completed election that can test that
allocation out of sample, and it never has been."*

## The half of the allocation that CAN be tested, and it works

The allocation has two parts: an **ordering** (rank seats by transposed federal
One Nation vote) and a **concentration** (quantile-map onto `sa_ratio`).

The ordering is testable here without circularity, and it is good. Across 47
South Australian districts, transposed federal One Nation vote against actual
2026 One Nation vote:

**Spearman +0.939, Pearson +0.926.**

The four seats One Nation won ranked **1, 6, 10 and 15 of 47** on our ordering
— all in the top third, three in the top ten. **The ordering finds the right
seats.** (This reproduces the +0.939 already recorded in `NEXT-STEPS.md`, which
is a useful check that the computation is right rather than a new finding.)

## What cannot be tested the obvious way

`sa_ratio` — the concentration curve — **is fitted on SA 2026 itself**.
`CLAUDE.md` already records this: *"no election can test it."* So "apply the
published allocation to SA 2026 and see if it elects the right seats" is
circular as stated, and must not be run in that form and reported as validation.

A non-circular version needs the concentration to come from somewhere else:
Western Australia 2017 or Queensland, or a concentration implied by the
ordering alone with the spread held to a value not derived from this election.
**That is a real experiment and needs its own pre-registration**, including
what result would disqualify it.

## Where this leaves the Victorian question

The asymmetry that started this — 6 of 6 Victorian One Nation seats in
Labor-leaning territory against SA's 0 of 5 — is **still unexplained**, but the
search space is now much smaller. Ruled out today:

- **the allocation ordering** — validated at +0.939 out of sample here;
- **the projected One Nation primary** — identical by seat type in Victoria
  (20.2 vs 20.2);
- **the swing shape** — uniform beats proportional, MAE 3.724 vs 3.970 on 2,878
  observations;
- **district-level vote sourcing** — refused, sign reversed by the confound control;
- **proximity substitution** — refused, sign reversed by the size control;
- **the statewide attribution** — the Victorian trend is faithful to its polls,
  and the Coalition *is* paying for One Nation there once the two phases of the
  swing are separated.

What is left is the **concentration** step and the **count**. This run is the
first evidence that points at concentration specifically, because it shows what
happens when concentration is absent: **0.000 in all four seats.**
