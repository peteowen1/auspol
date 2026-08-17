# Pre-registration: is one OTH preference flow right for a bucket that changed?

Written 2026-08-17, before the test is run. Committed before any result.

## The question

`derive_tpp()` gives the whole OTH bucket a single flow to Labor — **48.9%**
for Victoria 2026, estimated as the mean of the last five observed elections
(`scripts/backtest_flows.R`, adopted 2026-08-16).

That estimate is an empirically correct **blend for the composition it was
measured on**. The concern is that the 2026 composition is not that
composition, for a specific structural reason: **One Nation is modelled
separately in 2026**, at 20.9%. Whatever ONP absorbs is no longer inside OTH.
If ONP draws disproportionately from the minor-right, the residual OTH bucket
is more left-leaning than the historical blend and 48.9% is **too low**. If it
draws evenly, nothing changes.

Round 1's incidental finding motivates the question but does not answer it:
Labor took **0.203** of minor-right transfers in SA 2026
([../reviews/onp-allocation-sa-2026-08-17.md](../reviews/onp-allocation-sa-2026-08-17.md)).
That is the flow of the bloc ONP competes with, not the flow of the bucket the
model actually applies 48.9% to.

**The direction of the error is therefore not known in advance**, and the
review that raised it leant toward "too high" without warrant. Stating that
here so the result cannot be read as confirming a prior.

## The estimand, which is not what round 1 measured

`flow_alp` is a **two-party** quantity: of all ballots for party X, the share
that end up counted for Labor in the final two-party count. Round 1 measured
the **immediate transfer** at the moment of exclusion, which is a different
thing — a vote transferred to the Greens may be redistributed again later.

Primary estimand here is the two-party one: **the transfer at the final
exclusion, in seats whose final two are ALP and LNP.** At that point the
transfer is by definition the two-party flow, directly comparable to 48.9%.

Secondary, reported but not decisive: the pooled immediate-transfer figure
across all exclusions of non-ONP minor parties, which has more observations
and more bias.

## Method

From the 16 SA 2026 distribution-of-preferences tables:

1. Restrict to districts whose final two are ALP and LNP.
2. Take the final exclusion in each. Record the excluded party and the share of
   its votes transferring to Labor.
3. Classify the excluded party as minor-right or other-minor, per the existing
   mapping in the parser.
4. Report the vote-weighted flow for each class and pooled.

Then size the effect on the published number: recompute Victoria's statewide
ALP two-party with the OTH flow replaced, holding everything else fixed.

## Decision rule, fixed now

Let ΔTPP be the change in the published Victorian ALP two-party figure when
the measured flow replaces 48.9%.

- **|ΔTPP| < 0.3 points** — record as a negative result and do not build. The
  published figure carries a 95% interval about 5 points wide; a shift below
  0.3 is not something a reader could act on.
- **0.3 ≤ |ΔTPP| < 1.0** — build a composition-weighted OTH flow, but as a
  normal change with its own held-out check, not a correction.
- **|ΔTPP| ≥ 1.0** — treat as a defect in the published number and fix it
  before the next refresh, since it exceeds the entire measured effect of the
  One Nation flow question (+1.2).

## Known limitations, stated before the run

- **16 districts, and the final exclusion is one observation each.** The
  primary estimand will rest on very few counts. If fewer than 5 districts
  qualify, the primary estimand is declared underpowered and the decision falls
  to the secondary with an explicit caveat, not quietly to whichever is
  larger.
- **South Australia is not Victoria.** The minor-party field differs — SA has
  Family First as a significant presence, Victoria has Legalise Cannabis and
  Victorian Socialists. A flow measured there is evidence about the mechanism,
  not a Victorian constant.
- **The blend depends on Victorian OTH composition**, which is not forecast by
  the model — it forecasts one OTH number. Any composition weighting has to
  assume 2022 composition carries forward, which is itself an assumption of the
  kind this project tries not to make.
- SA 2026 has already been looked at repeatedly today. This is a different
  quantity from the two rounds before it, but it is the same dataset, and the
  honest reading of a positive result is "worth testing on Victorian data",
  not "established".
