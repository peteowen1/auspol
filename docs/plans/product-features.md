# Feature landscape and what auspol should build

Written 2026-08-14 (session 2). Persisted per the "plan big, execute small"
rule so a cheaper model can execute against it later.

Compares the four Australian sites we've looked at, states where auspol
actually stands, and proposes a build order. Sources: our own
[ANCHOR-MODEL.md](../ANCHOR-MODEL.md) analysis for AE Forecasts; published
methodology pages for the others (fetched 2026-08-14).

## Who does what

| | AE Forecasts | theswingison | DemosAU | buildaballot |
|---|---|---|---|---|
| Poll trend over time | Yes, Bayesian latent state | Yes, kernel average | No | No |
| Removes pollster house effects | Yes, time-varying | **No, deliberately** | n/a | n/a |
| Fundamentals (result with no polls) | Yes, elastic net | No | No | No |
| Seat-level estimates | Yes, 100k+ simulations | Yes, uniform swing | Yes, MRP | No |
| Win probabilities | Yes | No, confidence tiers | Seat ranges only | No |
| Preference flows | National, with noise | **12-rule, elimination-aware** | Mixed prev-election/respondent | n/a |
| Census demographics | Barely (3-level seat type) | **Yes — booth regression + AES, per seat** | Presumably (undisclosed) | No |
| Elections covered | Federal + states | **Six, incl. Vic/Qld/WA/SA** | Federal | Federal |
| Published backtests | Yes | Yes | **No** | n/a |
| Optional preferential (NSW) | Yes | **No, CPV only** | n/a | n/a |
| Voter-facing tool | No | Swing explorer | No | **Yes, the whole product** |
| Live product | Yes | Yes | No — one news article | Yes |

Bold marks where a site is notably ahead or notably behind the field.

### What each is really for

- **AE Forecasts** is the only complete probabilistic forecast. It is the
  thing we are trying to match and then beat. Its weakest flank is seat-level
  demographics.
- **theswingison** is a *swing explorer*, not a forecast: it answers "what if
  the vote moved like this?" rather than "what will happen?". Its preference
  simulator is the best-designed piece of machinery any of these have. Its
  four tools are catalogued below — it is a much bigger product than the
  methodology page suggests.
- **DemosAU** is a pollster publishing an occasional MRP as content. Note they
  are also an input to our own model, where our 2028 fit gives their polls a
  −2.1 point house effect on ALP FP.
- **buildaballot** is a different product for a different audience — helping
  someone fill in a ballot, not predicting the result.

## theswingison in detail (browsed 2026-08-14)

Four interactive tools, each covering **six elections** — Federal 2027/28,
Victoria 2026, NSW 2027, Queensland 2028, WA 2029, SA 2030. We cover two.

**Track a Poll** — primary-vote scatter with a kernel-weighted aggregate,
dots sized by sample. Scrub to any date and it runs that day's aggregate
through the preference engine to project all 150 seats: totals, seats
changing hands, close contests, hemicircle and map views. Toggles for
per-election preference calibrations and for "add missing One Nation
candidates" (they model ONP not contesting every seat).

**Model an Election** — user-defined swing rules with a source and
destination party, scoped by state, seat type or Census demographic. Multiple
rules compose without ever pulling more votes from a party than it has.
"Estimate swings for me" inverts a target result into swing rules via
Sinkhorn. Preference flows are user-editable. Starts from actual 2025
primary counts.

**Run a Race** — enter candidates and primary votes (or preload a real 2025
division), then watch round-by-round elimination with the rule that fired and
the flow percentages at each step. This is their preference engine exposed
directly, and it is a genuinely good explainer.

**Build a Voter** — pick a location (national, state, seat type, or any of
the 150 seats) plus up to two Census characteristics, and get that voter's
likely 2025 vote. Three-stage model: booth-level regression on 2021 Census
per demographic category; a correction for groups being geographically
concentrated; then calibration to each electorate's own actual result. Age
and gender are additionally informed by the **Australian Election Study**.
Pre-computed vote rates for every category in every seat. Small-sample
warning below 1,000 matching voters.

Every tool has a shareable "copy this page" state.

### This forces a correction to our differentiation

[ANCHOR-MODEL.md](../ANCHOR-MODEL.md) lists ABS Census at electorate level,
AEC booth-level results, and the AES as *our* opportunities, on the grounds
that AE Forecasts uses none of them. theswingison already uses **all three**,
and does it well. That differentiator is largely taken.

What is still unclaimed, and it is the important part: **nobody combines
demographics with a real forecast.** theswingison is explicit that its
projections assume uniform swing and are "an illustrative guide rather than
a seat-by-seat forecast", and it publishes no probabilities anywhere — the
strongest uncertainty statement on the whole site is a small-sample warning
and a three-level confidence tier. AE Forecasts has the probabilities and
barely any demographics. The empty niche is the intersection, which is
harder than either but is genuinely open.

Their aggregate on 2026-08-14 was Labor 28.6, One Nation 26.6, Coalition
21.2, Greens 13.0, Other 10.6, against our 28.0 / 26.4 / 21.4 / 12.7 / 10.3.
Agreement within 0.6 points is **weak** validation, not strong: our
sum-to-zero constraint forces house effects to average out, so our trend is
close to a weighted poll average by construction. The two approaches should
only diverge when the pollster mix is unbalanced — which is exactly when
house effects matter, and exactly what to check rather than today's number.

## Where auspol actually stands

**Strong, arguably best of the four:** the poll trend itself. Specifically —
house effects estimated explicitly and per-pollster; hyperparameters chosen
by marginal likelihood rather than by hand; per-pollster noise weighting;
per-cycle volatility; model scale selected by evidence; optional-preferential
exhaust handling that theswingison explicitly cannot do; an exact posterior
that runs in seconds where the anchor's Stan version takes 1–4 hours.

**Absent:** literally everything downstream. No fundamentals, no projection
to election day, no seat model, no simulation, no site. We have the best
engine and no car around it.

## What we should build, and why

The temptation is to copy AE Forecasts feature-for-feature and lose. Having
now browsed theswingison properly, two things are genuinely ours:

1. **Transparency as a product, not a methodology page.** Nobody in Australia
   publishes pollster house effects as a live feature — theswingison
   deliberately does not even estimate them. We compute them for free as a
   byproduct, along with per-pollster noise factors and a binomial-floor
   herding check. A standing "pollster scorecard" — who leans which way, who
   is quieter than their own sample size permits — is publishable content no
   one else offers, and it costs us almost nothing.
2. **Probability, applied to demographics.** Not demographics alone: that is
   taken, and done well. The gap is that the site with the demographics has
   no forecast and no uncertainty, while the site with the forecast has no
   demographics. Doing both means a seat model that is demographic AND
   probabilistic — genuinely harder, and genuinely unoccupied.

### Build order

1. **Fix One Nation folded into Others.** Not a feature — a live correctness
   bug worth 6–9 points on the Others series, which feeds two-party-preferred
   and would corrupt every downstream feature. Blocking.
2. **Fundamentals + projection.** Elastic net on the anchor's authored
   inputs, leave-one-out validated. Without this there is no forecast, only a
   trend.
3. **Pollster scorecard.** Cheapest real feature we have; already computed.
   Ship it before the seat model, because it is publishable on its own.
4. **Seat model with Census demographics.** The differentiator. Needs the
   ABS CED/SED pull and AEC booth-level results first.
5. **Simulation → probabilities.** Turns the seat model into a forecast.

Deliberately deferred: a voter-facing ballot tool (buildaballot already does
it well, different audience), upper houses, and betting-odds ingestion.

### Worth stealing

- The **preference simulator**: a rule hierarchy keyed on who has been
  eliminated and who remains, with a confidence tier per rule. Our current
  single flow-rate-to-ALP is much cruder. Take the design, not the code.
- **Exposing the engine as an explainer.** Run a Race shows round-by-round
  elimination with the rule that fired and the flow at each step. The same
  move for us is showing how a house effect is estimated, or what a poll did
  to the trend — turning internals into content instead of hiding them
  behind a methodology page.
- **Shareable tool state** ("copy this page"). Cheap, and it is how these
  tools spread.
- **Modelling that a minor party does not contest every seat** — their "add
  missing One Nation candidates" toggle. Directly relevant to us, since ONP
  is now the second-largest primary vote federally.

### Worth avoiding

theswingison's **outlier down-weighting** — penalising a poll for disagreeing
with the local consensus is herding by construction, and it is the mechanism
that made the 2019 polls all agree and all be wrong. The right version is
fat-tailed observation noise, which discounts a genuine outlier through the
likelihood rather than by rule. That is already queued as the Stan stage.
