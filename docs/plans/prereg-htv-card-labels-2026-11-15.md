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
