# Hare-Clark party-seat forecast and backtest (Tasmania, ACT), 2026-10-13

Follows `scoping-tas-nt-act-2026-10-13.md` and `hare-clark-prototype-2026-10-13.md`. Code: `R/hare_clark.R`,
`scripts/build_hare_clark_data.R`, `scripts/backtest_hare_clark.R`, `tests/testthat/test-hare_clark.R`.
A separate scored path: not in `all_election_pairs()` or the six single-member harnesses.

**Question answered:** how many seats in each multi-member electorate each class (Labor, Liberal, Greens,
everyone else) wins, with probabilities. Which candidates win inside a party is out of scope.

## Data (all raw files kept under `external/reference/`)

| What | Source | Stored | Check |
|---|---|---|---|
| ACT ballot files 2008, 2012, 2016 (every formal ballot) | Elections ACT pages via the Wayback Machine (the live pages are gone) | `act/raw/{2008,2012,2016}/` | ballots = sum of first preferences (HCD4) |
| ACT ballot files 2024 | Elections ACT, live | `act/raw/2024/` | same |
| ACT ballot files 2020 | already fetched for the prototype | `elections-act/raw/2020/` | same |
| ACT seats won | the validated count engine (`scripts/hare_clark_count.R`) run on each year's ballots | `output/hare-clark-units.csv` | territory totals match ALP/LIB/GRN 7/6/4, 8/8/1, 12/11/2, 10/9/6, 10/9/4 (HCD5) |
| Tasmania 2002-2014 candidate first preferences and winners | Wikipedia "Results of the YYYY Tasmanian state election" (action=raw) | `tas/raw/wikipedia/` | candidates sum to the formal total within 0.1% (HCD1; 2002 Denison is 20 votes short on the page) |
| Tasmania 2018-2025 candidate first preferences | TEC first-preference workbooks (2018 per division; 2021, 2024, 2025 one workbook) | `tas/raw/tec/` | candidates sum exactly to the TEC formal total (HCD3) |
| Tasmania 2024, 2025 winners | TEC count exports (`... Export Count NN.xlsx`, full distribution of preferences) | `tas/raw/tec/{2024,2025}/` | 7 elected per division (HCD3) |
| Tasmania 2018, 2021 winners | Wikipedia "(elected N)" markers, matched to TEC rows by name | | 5 of 5 matched per division |

The Wikipedia 2025 boxes are off the TEC totals by up to 1,578 votes in a division; that is why 2018 onward use
the TEC workbooks. 2006 is used only as the base for 2010 (and 2002 only to fit noise for 2010).

## Model

1. **Statewide level the day before.** `hc_statewide_draws()` calls `load_polls(region)` and
   `statewide_draws_as_at()` cut off at polling day minus one. On this branch neither region has a poll file
   (another agent is adding them), so every run below printed `HCS1 ... FALLBACK -- NOT POLLS`: the previous
   election's statewide shares with a time-forward SD (RMS of earlier statewide changes, both regions pooled,
   shrunk toward 5 points). **Every number in this document is therefore a no-polls forecast.**
2. **Electorate class shares** = previous electorate share + statewide swing (uniform) + electorate noise. The
   noise SD per class is the RMS of earlier electorates' deviations from uniform swing, shrunk toward the pooled
   SD (5 pseudo-observations), pooled toward a 3-point prior. ACT 2016 has no 2012 electorates to swing from:
   its base is a notional built from 2012 ordinary polling places mapped to the 2016 electorate that used them
   (pre-poll and postal places used by several electorates are dropped).
3. **Minor tickets** share the "other" class by their own previous share in the electorate, else their mean
   share elsewhere last time, else a time-forward new-ticket prior (about 1.7 points). Who stands is taken from
   the nominations, which are public before polling day.
4. **Seats** from a party-level Hare-Clark count, `hc_party_count()`: each ticket is a bloc; full quotas
   elect; a ticket that is excluded, or has elected all its candidates, passes its votes on at party transfer
   rates; exhaustion is kept.
5. **Transfer rates** (`hc_flows_from_ballots()`): for each first-preference class, the class of the first
   preference for a different ticket, or exhausted, counted over every ballot of the PREVIOUS ACT election.
   Tasmania publishes no ballot files, so Tasmania borrows the latest ACT ballot file dated before its polling
   day (2010 uses ACT 2008, 2014 uses 2012, 2018 uses 2016, 2021 and 2024 use 2020, 2025 uses 2024).
6. **Scoring.** For each electorate and class, log loss of the probability given to the actual seat count
   (floor 1e-6). Naive baseline: the class's seats in that electorate last time (rescaled for Tasmania 2024's
   5 -> 7 change; territory-wide seat shares for ACT 2016's new electorates), given probability equal to the
   time-forward hit rate of that rule, the rest split over one seat either side.

## Oracle check: the count on the ACTUAL votes

Does the party-level count reproduce the real seat outcome when given the real first preferences? Using the
same transfer rates the forecast uses (time-forward). "Electorates reproduced" = every class's seat count right;
"seats right" = seats whose party the count got right. Higher is better.

| Election | Electorates reproduced | Seats right | ACT only: with that election's OWN ballots' rates |
|---|---|---|---|
| tas2010 | 5 / 5 | 25 / 25 | |
| tas2014 | 5 / 5 | 25 / 25 | |
| tas2018 | 4 / 5 | 24 / 25 | |
| tas2021 | 5 / 5 | 25 / 25 | |
| tas2024 | 4 / 5 | 34 / 35 | |
| tas2025 | 5 / 5 | 35 / 35 | |
| act2012 | 2 / 3 | 16 / 17 | 2 / 3 |
| act2016 | 3 / 5 | 23 / 25 | 3 / 5 |
| act2020 | 2 / 5 | 22 / 25 | 3 / 5 |
| act2024 | 2 / 5 | 22 / 25 | 3 / 5 |

**Tasmania 28 of 30, the ACT 9 of 18.** The ACT misses do not go away with the election's own transfer rates,
so they are the bloc assumption, not the rates: in the ACT the last seat is often decided between a major
ticket's third candidate and a Green, and the ticket's surplus value decays (fractional surpluses, ballots
that stop inside the ticket) in a way a bloc does not. Two fixes were measured over all 61 electorates
(2002-2025, own-year rates) and both made it WORSE: a ticket-leakage term on surpluses (49 -> 46 reproduced)
and six transfer classes splitting minor-right parties and independents from other minors (49 -> 44; it helped
ACT time-forward and hurt Tasmania, whose independents borrow the ACT independent row). Both are kept as arms.
The real fix for the ACT is a candidate-level count on resampled ballots (route (a) of the prototype doc).

## Time-forward backtest (5,000 draws; statewide = previous-result FALLBACK, no polls)

Mean log loss of the probability given to each (electorate, class) actual seat count, lower is better; naive
= same seats as last time with a time-forward hit rate. "Seats right" = seats whose party the model's most
likely count per class got right; "cells exact" = (electorate, class) counts called exactly, of 4 x electorates.

| Election | Electorates x seats | Log loss model | Log loss naive | Seats right model / naive | Cells exact model / naive |
|---|---|---|---|---|---|
| tas2010 | 5 x 5 | 0.672 | 1.020 | 22 / 21 of 25 | 12 / 12 of 20 |
| tas2014 | 5 x 5 | 1.489 | 1.641 | 20 / 20 of 25 | 11 / 11 of 20 |
| tas2018 | 5 x 5 | 0.424 | 0.819 | 22 / 22 of 25 | 15 / 14 of 20 |
| tas2021 | 5 x 5 | 0.743 | 0.502 | 23 / 24 of 25 | 17 / 18 of 20 |
| tas2024 | 5 x 7 | 1.262 | 1.940 | 29 / 27 of 35 | 11 / 5 of 20 |
| tas2025 | 5 x 7 | 0.675 | 0.659 | 33 / 33 of 35 | 14 / 16 of 20 |
| act2012 | 3 x 5/5/7 | 0.774 | 1.157 | 15 / 14 of 17 | 8 / 6 of 12 |
| act2016 | 5 x 5 | 0.349 | 0.620 | 22 / 23 of 25 | 17 / 16 of 20 |
| act2020 | 5 x 5 | 0.718 | 0.863 | 21 / 21 of 25 | 12 / 12 of 20 |
| act2024 | 5 x 5 | 0.717 | 0.594 | 21 / 23 of 25 | 12 / 16 of 20 |

Pooled over 10 elections and 192 cells: **model 0.783, naive 0.974**; mean per-election difference -0.199,
SE 0.087 clustered on election. The model beats the naive rule in 7 of 10 elections and loses in tas2021,
tas2025 and act2024 -- the three where seats barely moved, which is when "same as last time" is hard to beat
and a no-polls forecast spreads probability it does not need to. The biggest wins are the swing elections
(tas2010, tas2024, act2012), where last time's seats were wrong. All of this is WITHOUT polls; the poll path
is wired but untested here (no Tasmanian or ACT poll file on this branch).

## Transfer-rate sensitivity (2,000 draws each; pooled log loss, lower is better)

| Arm | Pooled model log loss | vs naive 0.974 |
|---|---|---|
| default: previous ACT election's ballots, 4 classes | 0.783 (5,000 draws) | -0.199 (SE 0.087) |
| ticket leakage on surpluses (`--leak=1`) | 0.809 | -0.170 (SE 0.092) |
| six transfer classes (`--flowclass=6`) | 0.887 | -0.100 (SE 0.087) |
| uninformed prior, 30% exhaust, rest equal (`--flows=prior`) | 0.935 | -0.052 (SE 0.108) |

The ballot-based rates are worth about 0.15 of log loss over an uninformed prior, mostly in Tasmania (tas2021
0.74 -> 1.16, tas2024 1.26 -> 1.87), even though Tasmania borrows them from the ACT.

## Limitations, unverified

- **No polls in any number here.** Every election ran on the previous-result fallback.
- ACT dates other than 2016 are the October convention, not checked against Elections ACT (they only matter as
  the poll cutoff and for time-forward ordering, which no ACT/Tas date is close enough to change).
- Tasmania 2002-2014 first preferences are Wikipedia transcriptions; only 2018 onward were checked against TEC
  workbooks. Tasmania's 2017 redistribution is ignored (same five divisions, boundaries moved).
- New tickets get a ~1.5-point prior, so a big new independent (Peter George's group, Franklin 2025, 12,499
  votes) is invisible to the forecast.
- The model's most likely count per class need not sum to the electorate's seats (marginal modes).
- `docs/DATA-REGISTRY.md` was NOT regenerated: the worktree holds only the new `tas/`, `act/`, `elections-act/`
  reference folders, so a regeneration here would drop every other source. Rerun
  `scripts/build_data_registry.R` from the main checkout after merge.
- Tasmanian count exports for 2024 and 2025 (full distribution of preferences) are stored but not parsed; they
  would give Tasmanian transfer rates for 2025 onward.

## Round 2 (same day): candidate-level count, Tasmanian transfer rates, polls

### Changes
- **Candidate-level count** (`R/hare_clark_candidates.R`, `src/hare_clark_stv.cpp`, arm `--count=candidate`).
  Each ticket's simulated vote is split over anonymous candidate slots (its number one, number two, ...) by the
  previous election's within-ticket shares shrunk toward equal (`lambda` and log-share noise fitted
  time-forward); then an inclusive-Gregory candidate count (~10 ms) runs on ballot types. ACT: the previous
  election's ballot file folded to slot sequences (`scripts/build_hare_clark_ballots.R`), re-weighted so each
  slot's first preferences match the draw (ACT 2016 pools all 2012 ballots; a ticket with no ballots borrows
  from tickets of its class). Tasmania has no ballot file: synthetic two-transfer-deep ballots from the party
  transfer rates and ticket leakage (`hc_synthetic_ballots()`).
- **Tasmanian transfer rates from Tasmania** (`scripts/build_hare_clark_tas_flows.R`, `hc_flows_from_counts()`):
  733 transfers in the TEC 2024 and 2025 count exports (Table I, papers; every count conserves papers). tas2025
  now uses the 2024 export; earlier Tasmanian elections still borrow the ACT ballots (no earlier export stored).
- **Data fix:** the Tasmanian Nationals (2014, 2025) had been merged into the Liberal ticket because
  `classify_party()` files them with the Coalition; they are now a separate minor-right ticket. This moved the
  block-count tas2014 log loss from 1.489 to 1.749 (the earlier figure was flattered by the merge).

### Oracle: the actual first preferences through each count (electorates reproduced)

| Region | Electorates | Block count | Candidate count (previous ballots / synthetic, re-weighted) | Candidate count on that election's OWN ballots |
|---|---|---|---|---|
| ACT 2012-2024 | 18 | 9 | 13 | **18** |
| Tasmania 2010-2025 | 30 | 28 | 26 | (no ballot files) |

The fast candidate engine reproduces every ACT party result from that election's own ballots, so the
inclusive-Gregory simplification costs nothing at party level. Re-using the previous election's ballots
recovers 4 of the 9 ACT misses. In Tasmania the synthetic ballots lose 3 electorates the block count gets right
(Braddon 2014, Lyons 2024, Bass 2025) and gain 1 (Franklin 2018).

### Backtest, block vs candidate count (2,000 draws each, no polls; log loss lower is better)

| Election | Naive | Block | Candidate |
|---|---|---|---|
| tas2010 | 1.020 | 0.672 | 0.676 |
| tas2014 | 1.641 | 1.749 | 1.790 |
| tas2018 | 0.819 | 0.402 | 0.392 |
| tas2021 | 0.502 | 0.744 | 1.122 |
| tas2024 | 1.940 | 1.271 | 2.062 |
| tas2025 | 0.659 | 0.628 | 0.848 |
| act2012 | 1.157 | 0.765 | 0.875 |
| act2016 | 0.620 | 0.341 | 0.345 |
| act2020 | 0.863 | 0.717 | 0.670 |
| act2024 | 0.594 | 0.718 | 1.746 |
| **Pooled (192 cells)** | **0.974** | **0.802** | **1.060** |

**The candidate count loses pooled log loss, so the block count stays the default.** Almost all of the loss is
five cells given probability exactly zero (each costs 13.8): two new ACT 2024 independents (Independents for
Canberra in Kurrajong, Fiona Carrick in Murrumbidgee), independents in Clark 2021 and Braddon 2024, and
Braddon 2014 Liberal 4. The block count has one such cell. Over the cells that are not at the floor the two are close (candidate about 0.72, block about 0.73), so the next step is a heavier tail for new and independent tickets
in the candidate path, not abandoning it.

### Tasmanian vs borrowed ACT transfer rates, tas2025

| Count | Rates from ACT 2024 ballots | Rates from TEC 2024 count | Oracle electorates (ACT rates / TEC rates) |
|---|---|---|---|
| Block | 0.664 | **0.628** | 5 / 5 |
| Candidate | 0.916 | **0.848** | 4 / 4 |

### Polls
The poll branch (`worktree-agent-a904c8a0ef0b375e8`) had no commits beyond the shared base when checked
(three times over about 70 minutes), so there is no with-polls run. Every number here is still the
previous-result fallback.
