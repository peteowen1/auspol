# Can the model see its zero-probability upsets coming? (2026-10-02)

Seven v58 seat-elections gave the winner under 1 in 10,000 (13% of all log
loss). Blanket insurance (plans/prereg-upset-floor-2026-10-02.md) improved
22-election log loss (0.3444 -> 0.3396) but failed the Brier guard, so the
question was whether the insurance could be TARGETED.

## Evidence (offline, v58 probabilities and features, everything time-forward)

Big primary surprises (beat the prediction by 15+ points): 50 of 5,523 minor/IND
candidates predicted at 2%+. They differ from the rest on: elected councillor
28% vs 5.5%; surge recipient 44% vs 16%; surge hazard 0.042 vs 0.011; council
share 6.3 vs 1.8; more candidates in the class; a lower statewide class level.

A time-forward logistic propensity model on those features: surprise AUC 0.837
(4,660 rows, 42 surprises); win AUC 0.967 (5,134 rows, 103 winners).

Insurance weighted by them, eps fitted time-forward (lower is better):

| weighting | 22-election log loss | Brier | Victoria | AEF-7 elections |
|---|---|---|---|---|
| none (v58) | 0.3444 | 0.0894 | | |
| predicted share | 0.3396 | 0.0904 | -0.0008 | +0.0034 |
| share x surprise propensity | 0.3433 | 0.0903 | +0.0062 | +0.0043 |
| surprise propensity | 0.3452 | 0.0910 | +0.0089 | +0.0072 |
| win propensity | 0.3429 | 0.0902 | +0.0009 | +0.0041 |

No targeted version beats plain share weighting; every version costs Brier.

## Why

The headline upsets are not visible in advance: Denison and Lyne 2010 have too
few earlier elections to train on (flat base rate); Barwon, Shepparton and
Murray rank at the 87th-92nd percentile of surprise propensity but at ~1% in
absolute terms, alongside dozens who did not surge; only Indi 2013 is flagged
(99th percentile win score). The features describe candidates who are likelier
to do well, not the rare ones who win from 5-9%.

## Conclusion

No usable targeted signal from the data on hand; the upset floor stays off.
What could change it is information about the CAMPAIGN rather than the
candidate's record: seat polls (v50 already lifted the 2022 teals from ~10-14%
to 25-37%), local media and search salience during the campaign (Google Trends
cache is sparse and federal-only), and endorsement/funding signals (Climate
200 for the teals). Not pursued today.
