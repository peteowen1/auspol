# What the concentration assumption is worth: One Nation 2 to 8 seats

Measured 2026-08-21. **Nothing changed in the model.**
`AUSPOL_ONP_CV` in `scripts/fit_seats_full.R`.

[onp-concentration-2026-08-21.md](onp-concentration-2026-08-21.md) bounded the
concentration of One Nation's vote at roughly **0.11 to 0.48** and said the
range was "enormous in seat terms" without saying how enormous. This says.

## The sensitivity

| CV | where it comes from | ONP median | ONP 90% | ALP | LNP |
|---:|---|---:|---|---:|---:|
| **0.110** | holding the SD in points fixed from federal | **2** | 0–7 | 42 | 39 |
| **0.334** | South Australia 2026, **what ships** | **5** | 1–12 | 40 | 37 |
| **0.480** | holding the CV fixed from federal | **8** | 3–15 | 38 | 35 |

One Nation's median runs **2 to 8** across the whole defensible range. Labor's
runs 42 to 38, the Coalition's 39 to 35.

**The live value sits in the middle**, which is the least interesting and most
reassuring thing about it: the model is not perched at an end of its own
uncertainty.

## What this does NOT resolve

**Concentration taken to its limit does not close the gap with YouGov.** At the
most concentrated value the federal record can support, this model gives One
Nation **8** seats. YouGov gives **17**.

So the remaining difference is not the concentration assumption. It is
something else in how their MRP distributes One Nation's vote across seats, and
this analysis cannot see what.

That matters for how the disagreement gets described. It would have been easy —
and wrong — to say "our One Nation number is uncertain, and the top of its range
approaches theirs". It does not approach theirs.

## Why this number deserves its own handle

Concentration decides how many seats One Nation **leads**, and on South
Australian evidence leading is most of winning. It is fitted on one election,
cannot be validated until Victoria votes, and **is not inside the published
ranges** — those hold it fixed and vary everything else.

`AUSPOL_ONP_CV` exists so that stays visible rather than becoming a number
nobody remembers is assumed.

## Recorded: the same argument-order bug, twice in one day

The rescale first read `pmax(0.02, onp_ratio)`. A scalar first argument **drops
the names** from a named vector, exactly as `pmax(0.1, m)` drops a matrix's
`dim` — and `onp_ratio` is looked up by seat name immediately afterwards, so
the entire allocation silently became `NA`. It surfaced as "target CV NA" in
the run log rather than as an error.

Both instances are now commented at the call site. The general form: **`pmax`
and `pmin` take their attributes from the longer argument, so the vector goes
first.**
