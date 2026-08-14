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
| Census demographics | Barely (3-level seat type) | **Yes, ecological regression** | Presumably (undisclosed) | No |
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
  simulator is the best-designed piece of machinery any of these have.
- **DemosAU** is a pollster publishing an occasional MRP as content. Note they
  are also an input to our own model, where our 2028 fit gives their polls a
  −2.1 point house effect on ALP FP.
- **buildaballot** is a different product for a different audience — helping
  someone fill in a ballot, not predicting the result.

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

The temptation is to copy AE Forecasts feature-for-feature and lose. Two
things are genuinely ours to take:

1. **Transparency as a product, not a methodology page.** Nobody in Australia
   publishes pollster house effects as a live feature. We compute them for
   free as a byproduct, along with per-pollster noise factors and a
   binomial-floor herding check. A standing "pollster scorecard" — who leans
   which way, who is noisier than their sample size allows — is publishable
   content no one else offers, and it costs us almost nothing.
2. **Census demographics at seat level**, which is the anchor's weakest flank
   and the one place theswingison is ahead of him. ABS publishes on CED/SED
   geographies with SA1 correspondences.

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

theswingison's **preference simulator**: a rule hierarchy keyed on who has
been eliminated and who remains, with a confidence tier per rule. Our current
single flow-rate-to-ALP is much cruder. Take the design, not the code.

### Worth avoiding

theswingison's **outlier down-weighting** — penalising a poll for disagreeing
with the local consensus is herding by construction, and it is the mechanism
that made the 2019 polls all agree and all be wrong. The right version is
fat-tailed observation noise, which discounts a genuine outlier through the
likelihood rather than by rule. That is already queued as the Stan stage.
