# Upper-house count model from real ballots (pre-registration, 26 Nov 2026)

Written before any flow was fitted. Branch `upper-house-count`. Switch `AUSPOL_UPPER_HOUSE_COUNT_MODEL`
(`"0"` = the current `count()` in `scripts/build_upper_house_forecast.R`, `"1"` = this model), published at `"0"`.

## Why

The Legislative Council forecast's count assumes its preferences: same-bloc groups favoured about 2.5 to 1, and
5-30% of votes exhausting at each exclusion. Neither number is measured. For 2026 Victoria abolished group voting
tickets, so preferences now follow what voters write, as in the Senate since 2016. The Senate's ballot-level
files record exactly that, for Victorian voters, at two elections.

## The rule we are modelling (enacted)

Electoral Amendment (Miscellaneous Matters) Act 2026 (Act 28/2026, assent 18 Aug 2026, text identical to the bill
as introduced):

- New s 93A(2) and (3): number at least 1 to 5 above the line (or all groups if 5 or fewer), or at least 1 to 5
  below the line.
- New s 112A(2): an above-the-line ballot with fewer than 5 numbers, starting at 1, is formal "in relation to the
  preferences marked by the number 1 or ... up to a break in the sequence". A single 1 is formal. s 112A(3): a tick
  or cross counts as 1.
- s 93A(3A)/(3B): an above-the-line vote runs down the group's own candidates, then to the next group numbered.
- Exhaustion and the surplus method are not changed by the Act (existing Schedule rules apply; not read here).

The Senate rule differs in one number: the instruction is 1 to at least 6 above the line (1 to 12 below), with the
same savings for fewer. That gap is the main transfer from Senate to Victoria and is handled explicitly (below).

## What is measured (Victorian Senate ballots, 2022 and 2025)

Source: AEC "formal preferences" files, one row per ballot paper, raw zips plus manifest in
`external/reference/aec/senate-prefs/` (gitignored). Parsed by `scripts/parse_senate_formal_prefs.py` into
group-order sequences (BTL ballots collapsed to the order of their first candidate per group).

1. **How many boxes above-the-line voters number**: the full distribution, the share at exactly the instructed
   minimum (6), the share under it (saved ballots), the share numbering every group.
2. **Where a ballot goes next**: for each first-preference party class, the share whose next preference is each
   other class, and the share with no next preference (exhausts). Classes: ALP, LNP, GRN, ONP, and every minor party
   that stands both in the Senate file and in a 2026 Victorian region (Legalise Cannabis, Animal Justice, Family
   First, Victorian Socialists, Sustainable Australia, Libertarian, Shooters, Democrats, Citizens); every other party
   goes to a left, right or centre pool. n is given for every cell.
3. **Exhaustion deeper in the count** falls out of the same sequences: a ballot exhausts when every party it
   numbered is out.

**Shrinkage**: each class's sequences are mixed with its bloc's pooled sequences at weight n / (n + K), K = 200
ballots, so a class with few first preferences leans on its bloc. (At Senate sizes this barely binds; it is there for
the thin pools.)

**Senate to Victoria**: a ballot that stopped at exactly the Senate minimum (6) is taken to stop at 5 in Victoria
(the voter follows the instruction). Ballots that numbered more or fewer keep their length. A party on the Senate
ballot that has no group in a region is replaced, in that ballot, by a group from the same bloc's pool there if one
is left, and otherwise dropped.

## The count

Group-level STV, 5 seats, Droop quota (1/6 of formal votes): a group reaching a quota wins a seat and keeps the
remainder for its next candidate, every ballot in its pile scaled by (votes - 1 quota) / votes (inclusive Gregory);
a group that has run out of candidates passes its remainder on; otherwise the lowest group is excluded and each
ballot goes to the next group on it still in the count, or exhausts. Once the groups left equal the seats left, they
are all elected. Ballots are simulated as weighted sequence patterns (a fixed sample of M sequences per group,
reweighted each simulation by that group's first preferences).

## Validation, and what counts as passing (fixed now)

V0 **mechanics**: the group-level count, run on the real ballots (every sequence, not the model), must elect the
actual 2022 and 2025 Victorian Senate results (6 seats, quota 1/7) by party. Failure = a bug, fixed before anything
else is reported.

V1 **model, in sample**: first preferences by group + flows fitted on the same year's ballots must elect the actual
result by party, in both years.

V2 **model, time-forward (the honest one)**: 2025 first preferences + flows fitted on 2022 ballots only (parties
mapped by class) must elect the actual 2025 result by party.

Passing = V0 exact in both years; V1 and V2 the same seats by party. A miss is reported with the margin at the last
seat (votes between the last elected and the runner-up, in quotas) and compared with the margin in the actual count.
The current `count()` (aff 2.5, ex 0.175) is scored on the same three counts, so the comparison is between two
models on identical inputs.

If the sibling NSW LC 2023 or SA LC 2026 first preferences land in time, they are checked too, using Victorian
Senate flows by class (no ballot file for those). Reported, not a pass condition.

Speed: 4,000 simulations x 8 regions timed, target under two minutes.

What would make an apparent pass unacceptable: V0 passing only because of the "groups left = seats left" shortcut
deciding the last seat (reported if it does); V2 using any 2025 ballot.

## Amendments (added after fitting; the text above is unedited)

1. **Last two for the last seat** (added after comparing V0's exhaustion with the AEC's): with one seat left and two
   groups in, the higher is elected and the other is not excluded, as the AEC and VEC counts stop. It changes no
   winner, only the exhausted total reported at the end.
2. **Step-by-step replay** (post hoc, and the only test here that discriminates): a flow set with every party's
   ballots shuffled to another party still passed V0-V2 on seats, so seats by party cannot fail on these counts.
   The added test follows the real count's own path and measures, after each step, the quota sitting with the wrong
   group and the exhausted error. Results in docs/reviews/upper-house-count-validation-2026-11-26.md.
3. **Pattern bank instead of M samples**: per group, the 150 most common class sequences exactly plus 150 weighted
   draws for the rest (unbiased), not M = 400 random draws.
4. **The plan's own "unacceptable" clause fired once**: in the free count, the 2022 last seat (Babet, UAP) was
   first decided by the "groups left = seats left" shortcut, after Labor's third candidate was excluded. With
   amendment 1 it is decided as the AEC decided it: Babet 0.839 quotas against Labor 0.709 on real ballots.
5. **Last-seat margins against the AEC** (in quotas, from the distribution of preferences' final count):
   2025 actual Labor (Ananda-Rajah) 0.869 vs One Nation (Pickering) 0.814; our count on real ballots 0.889 vs
   0.814; model with 2025 flows 0.87-0.90 vs 0.80-0.82; with 2022 flows 0.85-0.88 vs 0.745.
   2022 actual UAP (Babet) 0.834 vs Labor (Nunn) 0.685; real ballots 0.839 vs 0.709; model 0.82-0.84 vs 0.70-0.73.
