# Pre-registration: the by-election winner is the sitting member

Written 2026-09-19 morning, before any run under the switch. Found by
SHAP on Black sa2026 (ledger v36): the as-at xgb model gave David Speirs,
standing as an independent after resigning the seat and losing it at the
2024 by-election, +2.2 for `same_mp_i` and +2.9 for `historic_elected_i`,
and predicted him at 30.2 against 13.9 actual. `candidate_returns()` takes
the sitting member from the previous general election and knows nothing
about the by-election. Pete's standing rule: match on the person.

## The rule

`byelection_winner_rows(from, to)` (from
`external/reference/byelections/byelection-results.csv` and the new
`byelection-winners.csv`, 89 by-elections' winners) gives the winning
candidate of each by-election between the two elections as a candidacy
row with `elected = TRUE`. Under `AUSPOL_BYELECTION_MP=1`,
`candidate_returns()` clears the previous general election's `elected`
flags for that seat and adds the winner's row, so `same_mp`, `mp_departed`,
`prior_leader_returns` and everything downstream (the MP slope tier, the
departed-major tier, the xgb `same_mp_i` feature via the harnesses'
returns) see the by-election winner as the member. Nothing else changes.

Seats it touches in the backtest pairs (member changed at a by-election):
Black, Dunstan (sa2026); Wentworth (fed2019, Phelps); Aston (fed2025);
Bega (nsw2023); Ipswich West (qld2024); Orange and Wagga Wagga (nsw2019);
Lyne (fed2010); Northcote (vic2018); Darling Range (wa2021). Seats where
the same party won the by-election change only the person's key.

## Criterion, in order

1. **Primary, targeted**: mean absolute base_pred primary error over the
   class cells of the seats where the by-election changed the member
   (about 11 seats), all six harnesses at `AUSPOL_XGB_PRIMARY=0`, 20,000
   sims, before vs after; must fall by more than one clustered SE
   (cluster = seat). Small n; say so.
2. **Do-no-harm**: pooled seat log loss over 23 pairs not worse by more
   than one SE (cluster = pair).
3. **Secondary**: Black's IND and ALP cells; the by-election seats where
   the same party won must be near-unchanged.

Unacceptable-win clause: if the gain is Black alone and the other ten are
flat or worse, it is not a rule, it is one seat.
