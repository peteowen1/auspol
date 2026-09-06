# Pre-registration: the surge goes to the candidate the hazard was fitted for (P4b)

Written and committed 2026-09-06 night BEFORE any code. Follows the stage 1
refusal in `prereg-surge-hazard-scale-2026-09-06.md`. Baseline: the rule-2
baseline at published defaults (`82bf887`).

## The defect

`surge_hazard_for()` fits a per-(seat, class) probability that a governed
candidate breaks out, from that candidate's salience, and collapses it to a
per-seat hazard with the comment "the mechanism itself picks the strongest
eligible candidate in the draw, so collapsing party here is fine". It is not
fine. `simulate_seat_contests()` awards a surge to the LARGEST non-major
class in the seat at that draw (`cand[which.max(v[cand])]`), and refuses any
class under `surge_floor = 2`%. In Kooyong, Goldstein, North Sydney and
Curtin 2022 the largest non-major is the Greens; the independent the hazard
was fitted for gets nothing, and Goldstein's 1.3% base is barred outright.
Stage 1 measured the consequence: x8 hazard moves Goldstein 0.000 → 0.001.

## The change

1. `simulate_seat_contests()` gains `surge_party`: a per-seat character
   vector (or `NULL`, the old rule) naming the class that receives the surge
   in that seat when the hazard fires. When given, that class is eligible
   regardless of `surge_floor`, and if the named class is absent from the
   seat's columns the seat falls back to the old rule (reported in the
   returned diagnostics, not silent).
2. `surge_hazard_for()` returns `seat_recipient`: per seat, the class whose
   `p_hat` is largest in `seat_party_hazard` — the candidate the hazard IS.
3. The four harnesses with surge-v2 and `fit_seats_full.R` pass it. A
   switch `AUSPOL_SURGE_RECIPIENT` (published value 1 once adopted; 0 = the
   old rule) so the two can be compared in one sweep.
4. Then the scale grid of P4 (x1, x2, x4) is re-run with the recipient
   fixed, because the scale question was asked of the wrong recipient.

## Targets (primary), fed2022 at the rule-2 baseline

Goldstein 0.000, Fowler 0.000, North Sydney 0.002, Curtin 0.005, Kooyong
0.007, Mackellar 0.033; Wakehurst 0.000, Kiama 0.007 in NSW. With the
recipient fixed at scale x1, the hazards those seats carry (0.025–0.045)
should show as win probabilities of that order, 0.02–0.05, no longer 0.000;
with x2–x4, 0.05–0.20. AEF: 0.28–0.51.

Dry run on known cases: Wentworth 2022 (already 0.70) must not fall; Clark
must not move; Cowper and Mallee, where the independent already IS the
largest non-major, must be unchanged by the recipient rule at x1 (their
hazard reaches the same candidate either way) — if they move at x1 the
implementation is wrong, not the model.

## Guards, over ALL 17 elections at stage 2 (Pete's objective)

- Pooled seat-weighted log loss must improve by more than one SE of the
  paired per-election differences; pooled seat-share RMSE must not rise by
  more than 0.1 point.
- Per-election table: not carried by fed2022 alone.
- False-independent list must not grow by more than the emergences newly
  called above 0.05.
- Greens-won seats (Melbourne 2010–2022, Griffith, Ryan, Brisbane 2022):
  the Greens LOSE the surge they were wrongly receiving, so their
  probabilities may fall. Reported per seat; a fall of more than 0.10 on a
  Greens-won seat is a named cost, and if the Greens seats' total log cost
  rises by more than the independents' falls, the change is refused on
  Pete's pooled objective regardless of the teals.

## Stages

1. 5,000 draws, fed2022 / fed2025 / nsw2023 / sa2026, recipient ON at x1,
   x2, x4, against recipient OFF at x1 (the stage 1 files already exist).
2. 20,000 draws, all 17 elections, recipient ON at the stage 1 pick and x1.

## Refusal

Refused if stage 2's pooled log loss does not beat the baseline by one SE, if
the Greens cost exceeds the independents' gain, or if the targets move only
in the clamp (nothing above 0.05).

## Stage 1 result, 2026-09-07 00:30 (5,000 draws, code `3841dc5`)

| election | n | recipient OFF x1 | ON x1 | ON x2 | ON x4 |
|---|--:|--:|--:|--:|--:|
| fed2022 | 150 | 0.5261 | **0.3897** | 0.3677 | 0.3575 |
| fed2025 | 150 | 0.3034 | 0.3035 | 0.3120 | 0.3441 |
| nsw2023 | 88 | 0.3137 | **0.2944** | 0.2989 | 0.3175 |
| sa2026 | 47 | 0.3402 | **0.3276** | 0.3256 | 0.3327 |
| pooled (435) | | 0.3865 | **0.3340** | 0.3315 | 0.3399 |

Targets, fed2022 p(IND): Goldstein 0.000 → 0.017 (x1) / 0.069 (x4), Fowler
0.000 → 0.007 / 0.040, North Sydney 0.002 → 0.023 / 0.099, Curtin 0.005 →
0.029 / 0.133, Kooyong 0.007 → 0.043 / 0.168, Mackellar 0.033 → 0.055 /
0.176. Every target is above 0.000 at x1 and the top-ranked above 0.10 at
x4; none reaches AEF's 0.3–0.5, which is the hazard's calibration and is
recorded, not chased here. Cowper 0.469 → 0.482 and Mallee 0.201 → 0.193 at
x1: unchanged, as the dry run required.

**One cost, as the Greens guard anticipated**: Clark 2022 (Wilkie, 0.994 →
0.969 at x1, 0.902 at x4). The hazard there names a Green, and the surge now
goes to that Green instead of harmlessly to Wilkie. Every Greens-won and
returning-independent seat is scored in stage 2.

**Stage 1 pick: x1**, with x2 as the neighbour (it wins fed2022 and SA by a
little and loses NSW and fed2025). Stage 2 runs recipient ON at x1 across all
17 elections at 20,000 draws against the rule-2 baseline, then x2.
