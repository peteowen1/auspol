# Pre-registration: preference flows are treated as known. What is that worth, and can adopting uncertainty be justified?

Written 2026-08-19 (overnight), **before the sizing experiment's numbers were
seen**. Committed before reading them.

## The gap

In `fit_seats_full.R`, `flow_of(p)` returns a single number per party — the mean
of the last five observed flows — and that number is **identical in all 20,000
simulation draws**. Preference flows are a forecast quantity treated as known.

For One Nation this is not a small assumption. Its flow to Labor has fallen from
**54.4% (federal 1998) to the 25–35% range** across the last decade — a strong
secular trend, not noise. The value used for Victoria 2026 is **33.7%**, and a
trend fitted on 21 elections predicts 34.1%, so the central estimate is not in
dispute. The **spread** is: the one-step-ahead error of "mean of the last five"
is **sd 3.65 points** over 19 One Nation observations, MAE 4.07.

This also sits on the largest external disagreement we have: our 3 One Nation
seats against YouGov's 17, where YouGov's own explanation is about preferences
— they have Labor winning 9 seats One Nation leads on primaries, "as One Nation
struggles to attract preferences".

## Step 1, already running: size it before building anything

Two diagnostic runs shifting every minor party's flow by **±3.65 points** (one
standard deviation of the forecast error), reporting the change in each party's
expected seats. `AUSPOL_FLOW_SHIFT`, default 0, inert.

This is a sensitivity, not the fix. A per-draw random flow would produce a
*wider* distribution, not a shifted one, so the shift measures the lever's
length rather than the correction's effect.

**If a ±1 sd shift moves One Nation's expected seats by less than 0.5, stop.**
The mechanism is real but too small to be worth the complexity, and this project
has spent days on effects that size.

## Step 2, and the honest problem with it

The correction itself would be: draw `flow_p ~ N(flow_hat_p, sd_p)` once per
simulation, with `sd_p` the one-step-ahead error measured per party the same way
it was measured for One Nation.

**Adoption is blocked, and this plan says so in advance.** The standing rule in
this project is that nothing gets adopted for resembling another model — it has
to improve predictiveness out of sample. **There is currently no out-of-sample
test for this.** The candidate-level seat model has never been backtested: the
one calibration we have (161 seats, Victoria 2022 and NSW 2023, slope 1.113)
scores the **two-party** model, which does not use flows at all.

So the decision rule is:

- **Do not adopt on the sizing result alone**, however large it is. A big number
  measures how much the answer depends on flows, which is a reason to build the
  test, not a reason to skip it.
- **The test that would justify adoption** is a candidate-model backtest:
  reconstruct Victoria 2022 and NSW 2023 from what was knowable beforehand,
  simulate seats with and without flow uncertainty, and compare the calibration
  of the per-seat probabilities and the seat-count intervals. That requires
  preference data for two past elections that the repo already fetches, so it is
  buildable — it is a session of work, not a blocker.
- **If the backtest cannot be built**, adopt nothing and publish the sensitivity
  as a stated limitation instead. A forecast that says "our One Nation seat
  number moves by X if the flow is off by one standard deviation" is honest;
  one that quietly widens on an untested mechanism is not.

## Refusal section — what would disqualify an apparent win

- **W1 — a one-way ratchet check is mandatory, as for the FP correction.** If
  flow uncertainty raises One Nation's *probability of winning at least one
  seat* while its expected seats also rise, that is the same asymmetry that got
  the ONP seat sd refused. Report both, always.
- **W2 — no per-party sd unless each is measured.** One Nation's 3.65 comes from
  19 observations. If Greens or Others have fewer than 10, use a pooled sd
  rather than a per-party one fitted on a handful.
- **W3 — the flow and the primary must not both absorb the same error.** The
  first-preference correction adopted today (2.419 in quadrature) already widens
  minor-party shares. If flow uncertainty is added on top, check that the
  two-party total's spread still matches the projection's — `fit_seats_full.R`
  asserts this within 0.3 and that assertion must keep passing, not be relaxed.
- **W4 — agreement with YouGov is not evidence.** If this narrows the 3-versus-17
  gap, that is a consequence to report, never a justification. The gap is
  primarily a primary-vote disagreement (20.2 against 24), and a preference fix
  that appears to resolve a primary disagreement is fixing the wrong thing.

## What the criteria cannot see

- **Whether the central flow estimate is right.** This is about spread. If One
  Nation's Victorian preferences behave unlike its recent national average, a
  wider distribution around the wrong centre does not help.
- **Correlation between flows and primaries.** A party polling unusually high
  may attract different preferences than the same party polling low. Drawing the
  flow independently of the primary assumes no such relationship, which is an
  assumption, not a finding.
- **Seat-level variation.** Flows are applied statewide. Real flows differ by
  seat, and nothing here touches that.
