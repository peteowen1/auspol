# I rebuilt something the repo already had. What survives is a correction to two numbers.

Run 2026-08-20. **This file replaces an earlier version of itself that claimed
to remove a blocker. It did not; the blocker was already gone.**

## What I did wrong

[onp-allocation-sa-2026-08-17.md](onp-allocation-sa-2026-08-17.md) says:

> "16 districts is not enough. 97 events spread across 28 distinct cells, most
> with n ≤ 2."
>
> "Settling the seat count needs full distribution-of-preferences tables across
> many elections — a materially larger acquisition than the first-preference
> data, and the real blocker on the rebuild."

I read that as an open task, found the undocumented ECSA API behind the results
site, extracted 294 exclusion events across all 47 districts, and wrote it up as
removing the blocker.

**`scripts/fetch_preferences_sa.R` had already done it on 2026-08-19** — the
same API, the same `HAStatic`/`HAChange` endpoints, the same
`finalDistribution` — into `external/elections/ecsa-2026-sa-transfers.csv` with
**47 districts and 294 exclusion events**, in a **finer** party taxonomy than
mine, keeping `IND` and `OTH_RIGHT` separate where I collapsed both into `OTH`.

My extractor was an exact duplicate producing a worse result. It has been
deleted. `scripts/summarise_sa_transfers.R` now reads the canonical file.

The repo also already holds `vec-2014/2018/2022-vic-transfers.csv`,
`nswec-nsw-transfers.csv` and `aec-fed-transfers.csv`. **The "one state, one
election" gap the review names as its other structural limit is also already
closed**, and I proposed closing it as the next step.

## What survives

The review's matrix section is dated **2026-08-18**. The 47-district file landed
**2026-08-19**. So its published rates come from the 16-district sample and were
never recomputed. Recomputing them from the canonical file moves two of them.

| cell | review (16 districts) | canonical (47 districts) |
|---|---:|---:|
| **ONP → ALP, survivors {ALP, LNP}** | **57.0%** (n = 2) | **31.1%** (n = 7) |
| ONP → ALP, survivors {ALP, GRN, LNP} | 19.3% (n = 3) | 17.7% (n = 6) |
| GRN → ALP, survivors {ALP, LNP} | 74.5% | **84.5%** (n = 6) |
| GRN → ALP, survivors {ALP, ONP} | 81.5% | 80.4% (n = 12) |

**Anchor check passes**: of Liberal preferences reaching Labor or One Nation,
66.2% went to One Nation here against the review's 62.7%.

### The One Nation cell is the one that matters

The review uses a **19.3–57.0** range to argue the model's single fixed **33.7%**
flow-to-Labor "cannot express any of this". On the full sample that range is
**17.7–31.1**, and the model's 33.7 sits just above the top of it rather than in
the middle of a 38-point spread.

That changes the argument's shape. The constant is not failing to span a huge
range; it is **too high across the board**, most severely where the Greens
remain (17.7%). Whether that is worth acting on is a separate question needing
its own pre-registration — but the case for it is different from the one the
review makes, and rests on 7 and 6 events rather than 2 and 3.

### The Greens claim is not supported

The review concludes *"Greens preference Labor harder when the alternative is
One Nation than when it is the Liberals"*. On 47 districts the ordering reverses
— 84.5% against Liberals, 80.4% against One Nation. Neither sample can resolve a
4-point difference. **The claim should be withdrawn rather than inverted.**

## The process failure, which is the more useful part

Three times today I proposed a next step and began building before checking
whether the repo already had it:

1. the SA 2026 One Nation result — already in
   [onp-allocation-sa-2026-08-17.md](onp-allocation-sa-2026-08-17.md);
2. Victoria's exposure to the classic-contest assumption — sized against
   `simulate_seats()`, which `build_page.R` says in a comment does not publish;
3. this acquisition — already done, better, the day before.

Each time the work was real and the framing was wrong, and each was caught only
after committing. The common cause is not carelessness about the code, it is
**treating a review's "what should happen next" section as a description of the
present**. Those sections are written before the work they propose, and this
repo moves fast enough that several were already stale.

**The check that would have caught all three costs about thirty seconds:
`ls external/elections/`, `git log --oneline -15`, and grep the scripts
directory for the thing about to be built.** Doing it before proposing, not
before committing.
