# Neither competitor solved this with a swing model. They both went outside it.

2026-08-25, after ten hypotheses were tested and refused in one session.
Written in answer to: *"AEF and YouGov have got it working — what methodology
have they used?"*

**They have not got a swing model working. They both replaced or bypassed it.**

## What we are

Our seat model projects each seat as **its own previous result plus the
statewide swing**. Every one of today's ten experiments varied *how* that swing
is distributed — proportional, proximity-weighted, magnitude-dependent,
cross-party, concentrated. All refused, and uniform survived every one.

**A swing model cannot predict a seat that breaks from its own history.** That
is not a tuning failure, it is what the model class is. MacKillop's Coalition
went **67.0 → 26.9**. No function of "67.0 plus a statewide number" produces
26.9 unless the statewide number is −40, which it was not (−17.1).

## What YouGov does: MRP — it does not use the seat's history at all

Multilevel regression and poststratification builds each seat from **its
people**, not its past. Model vote choice on demographics from pooled survey
data, then poststratify onto each seat's Census composition.

So MacKillop is not "a seat that was 67% Liberal". It is a rural, older,
lower-income electorate, and the model asks how voters with that profile are
voting **now**. If One Nation is winning that demographic nationally, MacKillop
follows — regardless of what it did in 2022.

**That is why YouGov can call a 40-point collapse and we cannot.** It is a
different model class, not a better coefficient.

`docs/ANCHOR-MODEL.md:142` already lists "No MRP / no raw crosstab usage" as a
known gap. It is the gap.

## What AE Forecasts does: it does not model these seats — it imports them

AEF's seat model is, like ours, largely history-plus-swing:
`ANCHOR-MODEL.md:116` records that it uses "only a coarse
urban/provincial/rural label and each seat's own history", and
`ANCHOR-MODEL.md:141` lists "Seat demographics essentially unused".

**So how does it get independents and minor parties right? It buys the answer.**
`ANCHOR-MODEL.md` lists among his inputs:

- **Seat betting odds** — *"Prominent INDs, Greens, minor-party seat chances"*,
  collected by a dedicated repo.
- **Seat polls** — *"Prominent candidates, heavily discounted"*.

And [aeforecasts-benchmark-2026-08-22.md](aeforecasts-benchmark-2026-08-22.md)
found that **four of their eight archived finals are seat-betting updates.**

**AEF solves exactly the seats we fail on by taking an external signal that
already knows the answer**, applied precisely where a swing model is weakest —
prominent independents and minor parties. They did not find a better swing
coefficient either.

## So the ten refusals were not ten failures

They were a fairly thorough demonstration that **the fix is not inside the
swing model**. That is worth knowing, and it is consistent with what both
working competitors actually do.

## The three real options

**1. Import an external signal — what AEF does.** Seat betting odds and/or seat
polls for the seats a swing model cannot reach. Cheapest by far and proven to
work by the benchmark we are scored against.

`docs/NEXT-STEPS.md` **already identified this and it is blocked on Pete**:
*"the next attempt is the exogenous one refusal E4 excluded — a named list of
confirmed independents, seat polls, and possibly market odds. Odds need Pete's
call: it is a different kind of input."* That decision has been outstanding
since 2026-08-20.

**2. Build MRP — what YouGov does.** Rebuild seats from Census demographics
rather than history. This is the principled fix and the one that would make the
model genuinely better rather than better-informed. It needs ABS CED/SED Census
data, AEC booth-level results, and raw poll crosstabs — all listed as
unexploited in `ANCHOR-MODEL.md`. **Months, not days**, and Victoria is 95 days
away.

**3. Widen per-seat uncertainty and accept the miss.** Do not claim to predict
MacKillop; stop claiming **1.000** for the Coalition there. SA's calibration
slope is **0.299** — the model is not just wrong, it is far too confident.
This fixes the *scoring* damage without fixing the *prediction*, and it is the
only one of the three deliverable before Victoria.

## Recommendation

**Options 1 and 3, and they are complementary.** Option 3 is defensive and
cheap and should happen regardless — a model that says 1.000 and is wrong is
strictly worse than one that says 0.7 and is wrong, on every proper scoring
rule. Option 1 is the one that would actually move seat calls, and it needs a
decision from Pete that has been pending for five days.

**Option 2 is the right long-term answer and cannot be built before 28 November
2026.** Recording that plainly rather than starting it and half-finishing it.
