# First-time independents: the walk-through (9 Nov 2026)

For the model-design walk with Pete (CLAUDE.md: walk real rows before building). Read-only; nothing rerun.
Numbers: `output/published-predictions.csv` (the published path, 9 Nov 10:42am rebuild) and the main model's inputs in
`output/xgb-primary-v6-features.csv` (9 Nov 9:07am). Independent share is the seat's whole IND class; "first-timer" means
no earlier candidacy in that jurisdiction in `output/candidacies.csv` and not the sitting member (matched on surname and
first initial; spot-checked, not audited; the matcher wrongly kept Woollard wa2005 and Xenophon sa2018).

## Correction to the 6 Nov line

"A newcomer independent gets the generic 4-8%" came from the per-candidate side model (`scripts/fit_minor_candidates.R`,
`pred_xgb`). That number reaches a seat only through the class split (`R/class_split.R`, `AUSPOL_CLASS_SPLIT`), which is
OFF (refused 6 Nov). The published seat number comes from the main model, and it gave Spender 26.9, Ryan 25.5, Daniel 23.2.

## The size of it

649 seats where the only independent was a first-timer. Our published IND share, by what they actually got:

| Actual IND share | Seats | Our mean predicted share |
|---|---|---|
| under 5% | 442 | 3.5 |
| 5-10% | 103 | 5.4 |
| 10-15% | 34 | 6.1 |
| 15-25% | 47 | 10.9 |
| 25% and over | 23 | 15.7 |

So 70 of 649 (11%) took 15% or more, and we gave those 70 about a third of what they got. The 442 that took under 5%
are why a blanket lift is wrong: it would over-call two thirds of the rows to fix a tenth.

## Six seats

Shares in %. AEF is AE Forecasts' independent share where we have it. Model inputs, plain words:
`base_pred` is the pre-xgb swing baseline for the IND class; `seat_prev` the IND share in this seat last time (any
candidate); `voices` a local "Voices of" endorsement; `c200` Climate 200 funding; `search` the campaign search-interest
score (`surge_h`); `council` an elected local councillor.

| Seat | Candidate | Ours | AEF | Actual | Won | What the model knew |
|---|---|---|---|---|---|---|
| Shepparton, vic2014 | Suzanna Sheed (+1 other IND) | 7.0 | - | 35.2 | yes, at 0% | base 5.3, seat_prev 3.6, no voices/c200, search 0.04 |
| Mackellar, fed2022 | Sophie Scamps | 18.6 | 23.0 | 38.1 | yes, at 9% | base 8.7, seat_prev 12.2, voices 1, c200 1, search 0.13 |
| Pittwater, nsw2023 | Jacqui Scruby | 22.7 | 26.5 | 35.9 | no (lost narrowly) | base 8.7, seat_prev 2.2, c200 1, search 0.07 |
| Cowper, fed2022 | Caz Heise | 4.6 | 14.2 | 26.3 | no | base 9.9, seat_prev 25.9 (Oakeshott 2019), c200 1, search 0.07 |
| Condamine, qld2012 | Shane White | 20.3 | - | 2.2 | no | base 17.8, seat_prev 26.5 (a different IND), nothing else |
| Deakin, fed2025 | Jess Ness | 12.0 | - | 7.1 | no | base 4.2, seat_prev 1.3, voices 1, c200 1, search 0.06 |

- **Shepparton is the Victorian case and the hardest.** Nothing on file said she was coming: no endorsement, low search,
  3.6% independent vote last time. Whatever signal there was (local campaign, the Nationals-Liberal contest) is not a
  feature we have.
- **Mackellar had every flag** (Voices, Climate 200, the highest search score of the six) and still got half her vote.
  The flags move the number; they do not move it far enough.
- **Cowper and Condamine are mirror images.** Both seats had a big independent vote last time from a different person.
  The model cut Cowper to 4.6 (Heise got 26.3; AEF 14.2) and carried most of Condamine (White got 2.2). Whether the
  seat's last independent vote transfers to a new independent is decided by the same input both ways.
- **Deakin is the over-call** from the same flags that under-called Mackellar: Voices plus Climate 200 at 12.0, actual 7.1.
- UNVERIFIED (not checked against a pre-election source): who the earlier independents in Cowper and Condamine were,
  and Scruby's margin. `council` is 0 for all six; Sandy Bolton (Noosa 2017, 7.2 against 34.4) was a Noosa councillor
  from memory, so the council field may be missing some.

## Questions for Pete

1. Is the target the 70 big ones (seat log loss on seats a first-timer won or came close in), with all 35 elections as
   the do-no-harm guard?
2. Which signal do you trust to tell Mackellar from Deakin before the vote: endorsement and funding, search interest,
   seat polls, or the bookmakers' odds (`docs/DATA-REGISTRY.md` lists what is captured)?

## Which signal separates them: seat polls against bookmakers (added 9 Nov, Pete: "Go")

Federal 2022 and 2025 only (the two elections with both seat polls and saved odds): 59 seats where the only independent
was a first-timer, 14 of whom took 15% or more. Odds: Sportsbet 20 May 2022 (`petes-2022-scrapes/2022-05-20_sb_afe22.rds`,
`win_prob`) and 23 Apr 2025 (`afe2025/sportsbet_wide.csv`, 1/odds normalised over the seat), both before polling day.
Seat polls: the `seat_poll` column of `output/ind-model-eval-preds.csv` (9 Oct). AUC: the chance a random 15%+ seat
ranks above a random one under 15% (0.5 is a coin flip, 1.0 perfect). With 14 positives each AUC carries roughly 0.03-0.04
of noise, so the gaps below are about one standard error, not a proven ranking.

| Signal | Seats | 15%+ | AUC |
|---|---|---|---|
| Market independent win probability | 58 | 14 | 0.966 |
| Our published share | 59 | 14 | 0.925 |
| Search interest (`surge_h`) | 59 | 14 | 0.899 |
| Voices + Climate 200 | 59 | 14 | 0.887 |
| Seat poll independent share | 35 | 12 | 0.859 |

The level is the bigger story. Win probability, ours against the market, for the 2022 winners:
Goldstein 0.38 v 0.70, Wentworth 0.32 v 0.48, Mackellar 0.09 v 0.39, Curtin 0.32 v 0.35, North Sydney 0.07 v 0.31. The
seat polls under-called them too (Mackellar poll 23.4, actual 38.1; Goldstein 30.7 v 34.5), and they already reach the
published number through the seat-poll blend, so more seat-poll weight would not have found Scamps.

Odds on disk: fed2022, fed2025, sa2022, qld2020 (`external/reference/historical-odds/`), and vic2026 live
(`vic2026-extra/`, Sportsbet and Betfair). DECISIONS 2026-10-26 kept odds out for "no archived history to backtest";
these four elections are that history (they were used in `reviews/backtest-vs-bookmakers-2026-10-24.md`, which also
found the bookmakers beat us on seats with prominent independents). `AUSPOL_NEWIND_SEATPOLL` from the same decision was
never built; this table says it would not have helped the 2022 cases.
