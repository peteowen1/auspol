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

## Amendment 1 (2026-10-10, after the A-final screen; Pete chose it from the split above) -- carry by record size

POST HOC, and marked so: chosen after seeing that one ratio is right for tiny records and wrong for strong
ones. The clauses above are unedited. `AUSPOL_IND_PERSON_CARRY="linear"` (default "ratio" = the arm above)
replaces `carry x record` with `a + b x record`, floored at 0, where (a, b) is ordinary least squares of the
actual vote on the record over EARLIER elections' person cells (the same `ind_person_cells()` definition,
every election dated before the target, any jurisdiction; the actual is that person's own share there).
Fewer than 3 earlier cases (two parameters need three points) falls back to the ratio. Arm A1-final:
`AUSPOL_IND_PERSON=final AUSPOL_IND_PERSON_CARRY=linear`. Same four criteria, same six-election screen first,
then all 22 elections if memory allows; a pass on the six alone is not a ship.
What would make an apparent win unacceptable here, in advance: the fitted slope b above 1 (a record
amplified, not discounted) on any target, or the intercept a above the new-independent level the cell had
before (the rule would then raise every weak record, the opposite of the traced fault).

### Amendment 1 result (screen, same 6 elections): FAILS. Both arms refused; AUSPOL_IND_PERSON stays off.

1. PRIMARY: 169 changed cells, squared error 2,599 -> 2,719 (+120, SE 308): FAILS.
2. GUARD: seat log loss 0.2831 -> 0.2829: holds. 3. GUARD: ledger subset 0.2981 -> 0.2980: holds.
4. Does not fire. 5. Malvern: 1.37 (actual 1.6).
Fitted slopes 0.25-0.64, intercepts 0.9-2.7 (neither unacceptable condition fired).

Victoria improves under both carries (vic2022 -167 ratio, -161 linear); the federal failure is two seats in
opposite directions: Fowler 2022 (Dai Le, record 25.9 in Cabramatta, won with 29.5; cut 15.0 -> 10.6, +147)
and Barker 2019 (Gladigau, record 22.7 in Hammond SA 2018, polled 2.9; raised 8.3 -> 15.1, +120). A small
record is reliable evidence of a weak candidate; a large record is noisy in both directions, so no single
carry, ratio or line, fits both ends. Not tried, and not to be tried on these same six elections (a third
look at the same data): applying the rule to small records only. If revisited, it is judged on the 16
unscreened elections first. Arms A-base and B were not run: A-final's failure is in which cells the rule
touches and how much, which the stage does not change, and B adds the arm refused on 2026-10-09.

## Amendment 2 (2026-10-10, after Amendment 1's result; Pete: go) -- records may only lower, judged on unseen elections

POST HOC, and marked so. Clauses above unedited. "Small records only" written cliff-free: a record may only
LOWER the cell (`new = min(old, a + b x record)`, `AUSPOL_IND_PERSON_DIR="lower"`), never raise it. There
is no size threshold (Pete's no-hard-caps rule); a small record lowers because it says the person is weaker
than the generic level, a large one rarely does. Pete has objected before to one-sided caps that keep only
the helpful half of a fix (new-IND shrink, 2026-10-06); the case for it here is evidence, not convenience:
the screen showed the raising half is the unreliable one (Barker 2019 +120), and that is stated so he can
overrule it.
Arm A2-final: `AUSPOL_IND_PERSON=final AUSPOL_IND_PERSON_CARRY=linear AUSPOL_IND_PERSON_DIR=lower`.
JUDGED ONLY on the 16 elections not yet screened (fed2007, fed2010, fed2013, nsw2019, nsw2023, qld2024,
sa2022, sa2026, vic2014, vic2018, wa2001, wa2005, wa2008, wa2013, wa2017, wa2025), with the same four
criteria. The six already-seen elections are reported for completeness and cannot pass or fail it. Known in
advance from the six: the rule still cuts Fowler 2022 (Dai Le), so clause 4 is checked on all 22.

### Amendment 2 result (16 unscreened elections): primary FAILS; guards hold

`quick_arm.R "AUSPOL_IND_PERSON=final AUSPOL_IND_PERSON_CARRY=linear AUSPOL_IND_PERSON_DIR=lower"`, the 16
elections, 1,000 sims, one process.
1. PRIMARY: 98 changed cells (11 of 16 elections), squared error 2,021 -> 1,948 (-73, -4%, SE 102): FAILS
   (needs about -203).
2. GUARD: seat log loss, 1,337 seats, 0.3248 -> 0.3247: holds. 3. GUARD: ledger subset (292 seats) 0.2426 ->
   0.2425, better by more than 1 SE. 4. Largest win-probability move 0.017: does not fire.
Better in 8 of 11 elections with changed cells (vic2018 -60, nsw2019 -34, vic2014 -26, wa2017 -16, sa2026
-13, sa2022 -9, qld2024 -1), worse in wa2008 +50, nsw2023 +29, wa2025 +5, wa2005 +2. The direction holds
out of sample; the size does not clear the pre-registered bar. Off unless Pete overrides (to Pete).
