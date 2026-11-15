# Pre-registration: card shares learned from the cards, not from the results (`AUSPOL_HTV_LABELS=card`)

Written 2026-11-15 ~10:50am, before any screen. Pete, 15 Nov: "How would we know if previous candidates had open card?
How do we model this without leakage?" then "go" on the leak-free version.

## What it changes

`AUSPOL_HTV_FLOW` (shipped) replaces the Liberal-excluded, Labor-and-Greens-alive flow cell with a share fitted on
earlier elections for the card order the target election's table row records. Today (`AUSPOL_HTV_LABELS=outcome`,
the published behaviour) `htv_observed_splits()` labels each EARLIER election by its own result: under 50% to Labor is
"greens_above", otherwise "labor_above". The card table is never consulted for training. So nsw2019 (open card,
46.7%) trains the Greens-above share, vic2018 (two of four seats open) trains Labor-above, wa2013 (Labor-above card,
Fremantle Greens-above) trains Greens-above as one election, and 9 elections with no known card train both.

`AUSPOL_HTV_LABELS=card`:

1. Training labels come from `coalition-card-order-researched.csv` (sources dated before polling day; HIGH/MED;
   Liberal/LNP/CLP). Per election AND seat: a seat row beats the ALL row; a seat with neither is left out. Elections
   with no kept row (fed2001-2010, fed2019, nsw2015, nt2024, vic2006, wa1996, wa2005, wa2017, wa2021, wa2025) leave training.
2. A third label, `open`, from OPEN cards (statewide nsw2011, nsw2019, nsw2023, qld2015; seats vic2018 Northcote,
   Brunswick; target vic2026 Brunswick). The open share is applied where the target's card is open, statewide or seat.
3. Each label's share is a recency- and seat-weighted mean of (election, label) cells, as today, then partial-pooled
   toward the pooled mean of all labelled cells: `w = tau^2 / (tau^2 + se^2)`, se from the between-cell spread inside
   the label (pooled across labels when a label has one cell), tau^2 the method-of-moments between-label variance.
   Applied to all three labels (shrinkage, no `min_n` cliff).
4. Still time-forward: only cells from elections before the target (`elections_before()`), unchanged.

In `outcome` mode every value is unchanged. Statewide OPEN rows are now kept in the card table as "open" in both
modes; in `outcome` mode an open row has no share, applies to no seat, and the override returns the caller's flows
unchanged (as it did when the row was dropped).

Known before writing this (disclosed): the per-election and per-seat observed splits were printed at 10:40am today
while answering Pete (Victorian seat table; per-election table). No seat-winner score has been looked at.

## Known answers, stated before the screen

- Applied check: `HTV14` printed per fit with the three fitted shares, cells per label and shrink weights; `HTV1`
  per affected election names how many seats took each label.
- Live vic2026 (87 seats, Labor-above): the share moves from 62% UP by 1-4 points (the dropped Labor-above cells
  vic2018 57.7, wa2005 50.3, wa2017 58.0, nsw2011/nsw2023, fed2019 59.0 sit below the kept federal 63-73 and qld2024 73).
  Brunswick takes the open share, expected in the mid-50s.
- nsw2011/nsw2019/nsw2023 and qld2015 gain an override (open) where they had none.
- Found in the dry run (11:05am, fitted shares only, no score seen), added before the screen: qld2020 and sa2018 (Greens-above
  cards) have NO Greens-above card before them in card mode (vic2022 is later; fed2007/fed2010/vic2006 have no dated
  card), so they lose their override and keep their learned flows. Expect them worse if the card mattered; reported
  separately, and not a reason by itself to refuse. Dry-run shares: vic2026 Labor-above 64.1% (outcome 62.1%), open
  57.4%, Greens-above 35.2%; vic2022 62.9 / 53.2 / 41.4; nsw2023 62.7 / 52.6 / 35.2.

## Screen

`Rscript scripts/quick_arm.R "AUSPOL_HTV_LABELS=card" --pairs=fed2013,fed2016,fed2022,fed2025,nsw2011,nsw2019,nsw2023,qld2015,qld2017,qld2020,qld2024,sa2018,sa2026,vic2010,vic2014,vic2018,vic2022,wa2013 --sims=1000`

The 18 elections with a card row (every scorable one). The other 17 have no card row and are byte-identical by
construction (`HTV0 no how-to-vote entry`).

- Primary: seat-winner log loss (lower is better) pooled over the 18, SE clustered on election.
- Secondary, reported: squared error on changed cells.
- Guard: no election worse by more than 2 SE of its own seats; leave-one-election-out: the sign of the pooled change
  holds when any one election is dropped.
- Decision: better by more than 1 SE: deciding run (20,000 sims, the 18) and recommend shipping. Within 1 SE: a tie,
  to Pete as a correctness fix (labels from the outcome are the wrong design, even with no measurable gain). Worse by
  more than 1 SE: refuse, to Pete with the split.

What would make a win unacceptable: a gain carried by the NSW/QLD open-ticket elections alone (optional preferential
voting: those who keep numbering are self-selected, so their split may not carry to a full-preference state). Reported
as a split: full-preference elections vs optional-preferential ones.

## RESULT (2026-11-15 12:26pm, 1,000 sims, the 18 elections; arm cache 15fa041aa161 / base 017393a99047): A TIE; guard FAILS. To Pete.

Seat-winner log loss (lower is better), 1,746 seats: 0.2847 -> 0.2861, +0.0014 (SE 0.0017, clustered on election),
within 1 SE. AEF-7 ledger subset (622 seats): 0.2585 -> 0.2576, -0.0009 (SE 0.0005). 16 of 18 elections changed; HD1
confirmed the arm applied.

| Election | Seats moved | Change |
|---|---|---|
| vic2010 | 31 | +0.0323 |
| qld2020 | 14 | +0.0064 |
| nsw2019 | 7 | +0.0009 |
| nsw2023, fed2022 | 3, 4 | +0.0002, +0.0001 |
| qld2015, wa2013, fed2016 | 1, 0, 4 | 0.0000 |
| sa2018, sa2026 | 4, 3 | -0.0002 each |
| vic2022 | 10 | -0.0005 |
| fed2013 | 5 | -0.0012 |
| vic2014 | 8 | -0.0013 |
| vic2018 | 6 | -0.0018 |
| qld2024 | 3 | -0.0020 |
| fed2025 | 15 | -0.0024 |

- Guard: leave-one-election-out FAILS (dropping vic2010 alone flips the sign); vic2010 is about 2 SE of its own seats
  worse (own SE not printed by quick_arm; 6 Nov's same-size vic2010 move had SE 0.0149: unverified).
- Cause, not anticipated for vic2010 (it was for qld2020): with card labels nothing before 2013 has a dated card, so
  vic2010 has no Labor-above training and loses its override. The arm removes training data for early targets; the
  cost is the design, not the labels.
- Without vic2010 and qld2020 the other 16 average about -0.0006 (from the rows above, by hand).
- Open-ticket split (the unacceptable-win check): not triggered; NSW open elections net +0.0011 (worse), so no gain
  rests on them.

## AMENDMENT 1 (2026-11-15 ~12:45pm, after the RESULT above; Pete chose "Hybrid, rescreen"): `AUSPOL_HTV_LABELS=hybrid`

Written after seeing the card arm's result, so it is a new arm, not a rescue of the old one; the clauses above are left
as they were. Hybrid: a seat's card label where a dated card exists (seat row, else ALL row); seats with neither are
labelled by their election's pooled split among those seats (under 50% to Labor is Greens-above), as the published
"outcome" mode does. It keeps the corrections (NSW open cards, vic2018 open seats, wa2013 by its card) and restores
training for early targets.

Dry-run shares (fitted only, no score seen): vic2026 Labor-above 61.7% (outcome 62.1%), Greens-above 38.3%, open 57.1%;
vic2010 54.4 / 27.0 / none; qld2020 59.6 / 35.8 / 52.6.

Known answers: vic2010 and qld2020 return close to their baseline (both now have training cells); the open-ticket
elections and vic2018 move as in the card arm.

Screen: same command, same 18 elections, `AUSPOL_HTV_LABELS=hybrid`, `--reuse` (the published path's code is
unchanged by this commit; the canary decides). Same primary, guard (no election worse by more than 2 SE of its own
seats; leave-one-election-out sign) and decision rule as above. Unacceptable: a gain that rests on vic2010 or qld2020
returning to baseline (that is the gap closing, not an improvement) -- so the decision is read on the 16 others too.

## RESULT, amendment 1 (2026-11-15 1:07pm, 1,000 sims, the 18; baseline 017393a99047 reused by canary in fed/vic/nsw/qld/sa, wa2013 rebuilt): A TIE. To Pete.

Seat-winner log loss, 1,746 seats: 0.2847 -> 0.2846, -0.0001 (SE 0.0002, clustered on election), within 1 SE. AEF-7
ledger subset (622 seats): +0.0002 (SE 0.0002). 15 of 18 changed; HD1 confirmed the arm applied.

| Election | Seats moved | Change |
|---|---|---|
| qld2024 | 4 | +0.0015 |
| vic2018 | 10 | +0.0012 |
| nsw2019, vic2010 | 4, 4 | +0.0003 each |
| fed2025 | 5 | +0.0002 |
| nsw2023, qld2015 | 3, 4 | +0.0001 each |
| qld2017, fed2016, sa2026 | 2, 7, 0 | 0.0000 |
| fed2022, qld2020 | 2, 6 | -0.0001 each |
| vic2022 | 7 | -0.0004 |
| fed2013 | 8 | -0.0018 |
| vic2014 | 13 | -0.0027 |

- The card arm's data gap is closed: vic2010 +0.0003 (card arm +0.0323), qld2020 -0.0001 (+0.0064).
- Guard: no election moves more than 0.003 (own-seat SEs not printed); leave-one-election-out FAILS on noise (dropping
  fed2013 flips the sign of a -0.0001 total).
- Unacceptable-win check (gain resting on vic2010/qld2020 returning): not triggered; there is no gain.
- Live vic2026 (dry run): Labor-above 62.1% -> 61.7%, open (Brunswick) 57.1%.
