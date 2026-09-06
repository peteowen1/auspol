# AE Forecasts got 1 of the 4 too — their edge is CONFIDENCE, not prediction

2026-08-25. Answer to: *"what did AEF have for these 4?"* — and it reframes
what the target should be.

**AEF's archive does include SA 2026**, 47 seats, so this is a direct
comparison on the exact seats that consumed the day.

## The four seats One Nation won

| seat | **AEF called** | AEF P(ONP) | **we call** | our P(ONP) |
|---|---|---:|---|---:|
| Ngadjuri | **ONP ✓** | **0.405** | LNP 0.793 | 0.031 |
| MacKillop | LNP 0.520 | **0.181** | LNP **0.952** | 0.047 |
| Hammond | IND 0.327 | **0.128** | LNP 0.729 | 0.025 |
| Narungga | IND 0.741 | 0.092 | IND 0.820 | 0.029 |

**AEF got one of four. They missed three, exactly as we did.**

So the premise that "AEF have got it working" is **not right for this
scenario**. A One Nation surge displacing a major is hard for them too.

## What they actually do better

**They are far less certain about being wrong.**

- **MacKillop**: they call it Coalition at **0.520** — a coin flip. We called it
  **1.000** this morning and **0.952** after wiring in `shrink`. They give One
  Nation **0.181**; we give **0.047**.
- Across the four, their mean probability on the actual winner is **0.202**
  against our **0.033** — **six times** ours.
- Overall accuracy: **AEF 42/47, us 38/47.** A four-seat gap, and three of those
  four are not the One Nation seats.

## Why this matters more than another modelling hypothesis

The gap on these seats is **not** that AEF predicts the winner and we do not.
Neither of us predicts three of them. The gap is that **AEF's distribution
admits the outcome and ours does not.**

That is a calibration problem, and this session already showed calibration is
the cheap lever: wiring `shrink` into the SA harness — a parameter the
published model already used and the harness had been missing for four days —
halved the log score, moved every seat off 0.000, and took MacKillop from 1.000
to 0.952.

**It got us from 0.000 to 0.033. AEF sit at 0.202. The remaining gap is
another factor of six, and it is in the same direction.**

## The revised target

**Not "predict MacKillop".** Neither forecaster does, and today's eleven
hypotheses are strong evidence a swing model cannot.

**Instead: match AEF's uncertainty.** Concretely — a seat where a major is
collapsing and a minor party is surging should not be called at 0.95. AEF
call it 0.52.

That is measurable, has a benchmark to hit, and is far cheaper than
booth-level regression. It is also the thing that most improves the published
forecast's *scoring* if Victoria produces a surprise, which is precisely the
scenario the One Nation numbers imply.

## What this says about booth-level regression

It does not kill it, but it reorders it. AEF reach 0.181 on MacKillop **without
booth-level demographics** — `ANCHOR-MODEL.md` records their seat model as
using "only a coarse urban/provincial/rural label and each seat's own history",
plus betting odds and seat polls for prominent minor-party contests.

**So the observable gap to AEF does not require demographics to close.** It may
be reachable through per-seat uncertainty alone, which is days of work rather
than months.

## Caveat

AEF's SA 2026 numbers may incorporate seat betting odds — the benchmark review
found four of their eight archived finals are seat-betting updates, though it
did not establish which. **If SA 2026 is one of them, their 0.405 on Ngadjuri
is partly a market price, not a model output**, and the comparison flatters
their modelling. Worth establishing before treating their per-seat numbers as a
pure modelling benchmark.
