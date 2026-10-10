# Pre-registration: an independent's vote follows the person, not the seat (2026-10-10)

Written BEFORE any arm ran or any outcome was computed for these cells.

## Why

Pete, 2026-10-10 (quiz on Malvern 2022 and Bankstown 2023, `docs/SEAT-REGISTRY.md`): *"Person, not
seat"* -- an independent's starting vote is their own best earlier vote anywhere, or the new-independent
level if they never stood; a different person's class vote in the seat does not pass to them.

Traced: Steve Stefanopoulos (Malvern 2022, actual 1.6, published 8.6) and Max Boddy (Bankstown 2023,
actual 2.7, published 8.3) each had one earlier run under 1% (Prahran 2014 IND 0.61; Hunter fed2019
0.67). The base is `level_now + slope x (seat prior - level_prev)` (`dev_slope()`), so the statewide
independent level reaches every IND cell however unknown its candidate; swapping a person's record into
the seat prior would still leave Boddy near 7. The existing cross-seat credit
(`AUSPOL_CROSS_SEAT_VOTE`, `R/cross_seat_vote.R`) already finds these records but applies
`max(class base, carry x record)`, so it can only raise.

## What already exists, and what is new

- "Never stood -> a typical new-independent level" is `AUSPOL_IND_TYPICAL`, built and REFUSED
  2026-10-09 (`plans/prereg-ind-typical-2026-10-09.md`, arms A1/A3). It is re-measured here only in
  combination (arm B), not re-litigated.
- New: `AUSPOL_IND_PERSON`. For an IND class leader who is NOT a sitting member and has no record in this
  seat at the previous election, but HAS an earlier non-major record matched by the cross-seat machinery
  (time-forward, surname + full first name, same state, ambiguous names refused), the cell is SET to
  `carry x best earlier record`, where `carry` is the cross-seat carry already fitted time-forward
  (`fit_cross_seat_carry()`), whether that is higher or lower than the class base. Freed or added share
  is balanced pro rata across the seat's other classes. Applied through `ind_typical_apply()`'s hook,
  so at stage "base" (before the frozen as-at trees) or "final" (after them, what publishes).

## Arms (all at shipped settings otherwise; baseline = shipped)

- **A-final**: `AUSPOL_IND_PERSON=final`, `AUSPOL_NEW_IND_SHRINK=1` (shipped).
- **A-base**: `AUSPOL_IND_PERSON=base` (same cells, before the trees; the CLAUDE.md "test base_pred AND
  the xgb layer" rule).
- **B**: A-final plus `AUSPOL_IND_TYPICAL=final` for never-stood independents (needs
  `AUSPOL_NEW_IND_SHRINK=0`, as that arm required) -- the full version of Pete's rule.

Screen: `scripts/quick_arm.R`, all 22 elections, 1,000 sims. Deciding run for any arm that passes the
screen: full 20,000-sim stage 6 (`AUSPOL_REBUILD_ONLY`).

## Criteria (each arm judged alone; metric order per PRE-REGISTRATION-RULES.md)

1. PRIMARY (targeted): squared error of the published primary on the cells the arm changes falls by
   more than 2 SE (cells as units, SE clustered on election).
2. GUARD: pooled seat-winner log loss over all 22 elections rises by no more than 1 SE (clustered on
   election). Lower is better.
3. GUARD: AEF-7 ledger seat log loss rises by no more than 1 SE.
4. UNACCEPTABLE-WIN (named in advance): the arm lowers the published win probability of any
   independent who actually WON by more than 0.10. A person whose earlier run was small and who then
   broke through is exactly the case this rule could break, and a pooled gain must not hide one.
5. Named targets, reported not gated: Malvern vic2022 and Bankstown nsw2023 IND cells move toward the
   actual (1.6, 2.7).

Ship rule: an arm ships only if 1 passes, 2 and 3 hold and 4 does not fire. If more than one passes,
the one with the larger primary gain ships. If none passes, everything stays off and the split goes
to Pete (memory `clause-refusals-go-to-pete`). Any amendment is added below, with this text unedited.

## Dry run (to be filled in before the screen, without outcomes)

How many cells each arm changes per election, and the two named targets' before/after values.

Dry run (2026-10-10, before the screen; no outcomes read). Arm A sets 69 cells over 20 of 22 elections
(none in wa2001, wa2013). The cross-seat carry is about 0.47-0.48 everywhere, so a person's record is roughly
halved. Named targets: Malvern vic2022 Stefanopoulos 0.6 (Prahran 2014) -> 0.3; Bankstown nsw2023 Boddy is
NOT a cell -- his one earlier run (Hunter fed2019, 0.67) was for a party, "OTH", not as an independent, and
the matcher counts personal votes only (Pete's 2026-10-05 ruling, R/cross_seat_vote.R), so only arm B
reaches him. Sitting members are excluded wherever they now stand (code fixed in the dry run to match the
scope above: Brock Stuart sa2022, Bedford Newland sa2022 had been included). Watched for clause 4: Fowler
fed2022 Dai Le (record 25.9, set 12.5).

## Result, arm A-final, screen (2026-10-10): primary FAILS on 6 elections

`quick_arm.R "AUSPOL_IND_PERSON=final" --pairs=fed2016,fed2019,fed2022,fed2025,vic2022,qld2020 --slots=1`
(the six elections with the most cells; the 22-election screen was killed for low memory before it ran).
1,000 sims, baseline = shipped. 227 changed cells (the set IND cells plus the classes rescaled around them).

1. PRIMARY: squared error on changed cells 3,916 -> 3,828 (-88, SE 218, 6 election clusters): FAILS (needs -2 SE).
2. GUARD: seat log loss over these 6 elections 0.2831 -> 0.2830 (SE 0.0003): holds.
3. GUARD: AEF-7 ledger subset (389 seats) 0.2981 -> 0.2978: holds.
4. UNACCEPTABLE-WIN: no independent who won lost more than 0.10 win probability: does not fire.
5. Named target: Malvern Stefanopoulos 8.6 -> 0.6 (actual 1.6).

The split behind the flat total: of 39 IND cells moved by more than 0.5, 24 improve and 15 worsen (net
squared error -6). Weak records cut to near zero are almost always right (Malvern -48.9, Wills -33.5,
Tarneit -21.4, Goldstein 2019 -18.2); strong records halved by the single 0.48 carry are wrong (Fremantle
2025, record 25.6, actual 23.0, set 12.1: +57.0; Fowler 2022 Dai Le, actual 29.5: +45.6; North Sydney
2016 +26.5; Lyne 2025 +18.5), and one faded strong record was raised (Barker 2019, record 22.7, actual 2.9,
set 11.5: +43.9). A single ratio cannot be right at both ends. Arms A-base and B not yet run. To Pete.
