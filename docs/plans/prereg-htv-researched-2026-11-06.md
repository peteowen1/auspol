# Pre-registration: the researched Coalition card order (`AUSPOL_HTV_TABLE=researched`)

Written 2026-11-06 ~8:45pm, before any screen. Pete, 6 Nov: "spin up an agent to research this - and create the data
ourselves if needed".

## What it changes

`AUSPOL_HTV_FLOW` (shipped 18 Sep) overrides the Liberal-excluded, Labor-and-Greens-alive flow cell with a fitted share
for the card order the table records. The shipped table has 9 rows, state-level, several sourced from the observed split
(the outcome). The researched table (`external/reference/htv/coalition-card-order-researched.csv`, agent 6 Nov, 36
elections, sources dated before polling day, raw pages under `htv/raw/`) keeps 22 rows in 12 elections (HIGH/MED
confidence, Liberal/LNP/CLP, cards that order the two). Open tickets ("just vote 1"), no card, split and unknown cards
give no override, so the flows learned from earlier counts stand. Training of the two fitted shares is unchanged.

Affected elections (where the override changes): gain a card fed2013, fed2016, qld2017, sa2018 (Greens above Labor),
vic2010, vic2014, wa2013 (+ Fremantle Greens-above); lose it nsw2019, nsw2023 (OPEN, HIGH: the shipped FALSE was wrong),
fed2019 (no dated source), vic2018 (only a LOW, post-election source). fed2025's Tasmanian and Goldstein rows equal its
ALL row (no change). Every other election is byte-identical by construction.

## Known answers, stated before the screen

- nsw2019/nsw2023 Labor-v-Greens seats (Balmain, Newtown) move toward the Greens (the 61-62% Labor-above share is gone).
- vic2018 and fed2019 lose a card that agreed in direction with their results: expect them to get slightly WORSE.
- Applied check: HTV13 printed once per run with the kept/dropped counts; HTV1 per affected election.

## Screen

`scripts/quick_arm.R "AUSPOL_HTV_TABLE=researched" --pairs=fed2013,fed2016,fed2019,nsw2019,nsw2023,qld2017,sa2018,vic2010,vic2014,vic2018,wa2013 --sims=1000`.

- Primary: seat-winner log loss (lower is better) over the 11 affected elections, SE clustered on election.
- Guard: no election worse by more than 2 SE of its own seats, except the two named above (vic2018, fed2019), whose
  expected small loss is the cost of the source rule (dropping a card with no dated pre-election source).
- Decision (standard rule): better by more than 1 SE: recommend the deciding run and shipping. Within 1 SE: a tie, to
  Pete as a data-correctness fix (the shipped NSW rows are factually wrong). Worse: to Pete with the split.

What would make a win unacceptable: a gain driven by vic2018/fed2019 losing their card (it would mean the source rule,
not the data, did the work). Reported per election.

## RESULT

(not run)
