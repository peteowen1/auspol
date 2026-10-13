# Hare-Clark (ACT rules) count prototype, 2026-10-13

Track C of `docs/plans/coverage-program-2026-10-13.md`; follows `scoping-tas-nt-act-2026-10-13.md`.
Status: **prototype, standalone, uncommitted.** Code: `scripts/hare_clark_count.R` (check codes `HC1`-`HC6`).
Nothing under `R/`, `tests/`, `output/`, `external/elections/` was touched.

## Result in one line

Run on the 2020 ACT ballot-level files for all five electorates (269,251 formal ballots), the engine reproduces the
official count **exactly**: same winners in the same order, and every candidate's total at every count equals the
official sheet (to within 2 millionths of a vote in one electorate). 182 counts compared. Runs in about 2 s and
120 MB per electorate.

## Sources (what was fetched, where it is, how complete)

All under `external/reference/elections-act/raw/` (gitignored with the rest of `external/reference/`; nothing refetched
once present; 1 request per second; User-Agent names the project, no email).

| What | URL | Stored | Complete? |
|---|---|---|---|
| 2020 ballot-paper preference data (5 x `{Electorate}Total.txt`, `Candidates.txt`, `Groups.txt`, `Electorates.txt`, `BallotPaperVersions.txt`, `DataDescriptions.pdf`) | **Wayback snapshot 2024-03-31** of `elections.act.gov.au/elections_and_voting/2020_legislative_assembly_election/ballot-paper-preference-data-2020-election` (files under `web.archive.org/web/20240331203743id_/https://www.elections.act.gov.au/__data/assets/...`) | `raw/2020/` | Yes. Ballot counts per electorate equal the official formal-vote totals exactly (55,413 / 56,025 / 50,600 / 53,754 / 53,459). |
| 2020 official distribution of preferences, Table 1 (papers) and Table 2 (votes), per electorate, XLSX | `elections.act.gov.au/elections/previous-assembly-elections/2020-election/distribution-of-preferences-2020` (live, 10 files) | `raw/2020/table{1,2}_*.xlsx` | Yes (10 of 10, valid XLSX, parsed). |
| PRSA ACT submission 13A (description of ACT last-parcel rule), Elections ACT Hare-Clark fact sheet | `parliament.act.gov.au/__data/assets/pdf_file/0007/610684/Submission-13A-...pdf`; `elections.act.gov.au/elections/education/fact-sheets/fact-sheet-hare-clark` | `raw/legislation/` | Yes. |

Findings about availability, which change the scoping doc:
- **The 2020 ballot files are no longer on the live site.** The old URL 404s and the new 2020 election page does not
  link them (the 2024 page is live and still linked). The Wayback copy is complete and byte-usable. The scoping doc's
  "[S] 2016/2020 exist" is now "2020 exists, via archive only"; 2016 not checked this session.
- Data layout (from `DataDescriptions.pdf`): one row per preference per ballot (`batch, pindex, pref, pcode, ccode, rcand`);
  only formal ballots; preferences stop at the first gap or repeat. `rcand` is the Robson rotation position.
  `BallotPaperVersions.txt` gives the rotation version (1-60) and batch numbers ending `000` are electronic votes, so
  a rotation / ballot-position effect can be estimated from this data later.
- **Not fetched:** the Electoral Act 1992 Schedule 4 text itself. legislation.act.gov.au rejects the fetcher
  ("Request Rejected") and AustLII is behind a Cloudflare challenge. The rules below were therefore reverse-engineered
  from the official 2020 count sheets and checked against the PRSA and Elections ACT descriptions. **They reproduce
  five full counts exactly, but clauses never triggered in 2020 (below) are from description, not statute text.**

## Rules implemented (state which, per the brief)

The ACT uses the **last-parcel** (Gregory) method, not the Senate "all papers" method.

1. **Quota** = `floor(formal / (seats + 1)) + 1` (55,413 / 6 -> 9,236).
2. **Votes carried to six decimal places.** Transfers are `floor(papers x transfer value, 6 dp)`; the dust goes to
   "loss by fraction" (can be negative on an exclusion). This is visible in the official sheets (e.g. 5640.081618).
3. **Election:** reaching the quota elects at the end of the count. Several in one count are queued in order of election,
   larger surplus first.
4. **Surplus:** the earliest queued surplus is distributed before any exclusion. Only the **last parcel** moves: every
   paper the candidate received at the most recent count at which he received any (for a first-preference quota, all
   papers). Transfer value = surplus / number of papers in that parcel that have a next continuing preference, capped at
   the value each paper already carries (so a transfer value never exceeds 1 and never rises). The part of a surplus
   that a transfer value of 1 cannot carry is non-transferable. **Booking quirk:** the ACT sheets show the
   non-transferable part of a surplus in the "Loss by fraction" column, and only papers exhausted at an exclusion in
   "Votes exhausted"; the code follows that so the columns compare.
5. **Exclusion:** lowest continuing candidate, one at a time (**no bulk exclusion**; the 2020 sheets never use one).
   All his papers move to the next continuing preference at the value they already carry. **The exclusion runs in
   stages, one count per distinct transfer value** (full-value papers first, then each fraction group, highest value
   first), shown officially as "partially excluded" until the last stage. Elections can happen after any stage. This
   was the one rule not obvious from descriptions: without it 4 of 5 electorates diverged (e.g. Ginninderra count 20,
   where Tim Liersch is left holding 3.3 votes of fractional-value papers).
6. **Seats full = count stops**, even in the middle of a staged exclusion (Yerrabi count 31 ends with
   "James MILLIGAN partially excluded. Leanne CASTLEY elected 5").
7. **Surpluses are distributed even when the seats are otherwise filled**; a candidate is elected **without** quota only
   when no surplus is queued and the continuing candidates equal the vacancies (ACT does not auto-elect the
   remainder early as Tasmania does; PRSA submission, Brindabella count 23 shows it).
8. **Ties:** fewer votes at the most recent earlier count at which the tied candidates differed; if never different,
   lot (the code takes the lowest candidate code and records "LOT" in `$ties`). **No tie occurred in the five 2020
   counts, so rule 8 is untested** and is from the PRSA/Tasmanian convention, not verified for ACT.

## Validation

How to read: one row per 2020 electorate; "counts" is the number of counts in the official sheet and in ours (equal is
good); "counts differing" is how many counts have any candidate total different from the official Table 2 (0 is
perfect); "max |diff|" is the largest single candidate-total difference in votes (smaller is better). All 30 checks
`HC1`-`HC6` pass; `HC6` is the negative control (a deliberately nudged total is caught at the right count).

| Electorate | Formal ballots | Quota | Counts (ours / official) | Counts differing | Max abs diff (votes) | Elected, in order | Staged-exclusion counts | Seats elected without a quota |
|---|---|---|---|---|---|---|---|---|
| Brindabella | 55,413 | 9,236 | 23 / 23 | 0 | 0 | identical | 0 | 0 |
| Ginninderra | 56,025 | 9,338 | 42 / 42 | 0 | 0 | identical | 10 | 1 |
| Kurrajong | 50,600 | 8,434 | 56 / 56 | 0 | 0.000002 | identical | 28 | 1 |
| Murrumbidgee | 53,754 | 8,960 | 30 / 30 | 0 | 0 | identical | 3 | 0 |
| Yerrabi | 53,459 | 8,910 | 31 / 31 | 0 | 0 | identical | 7 | 0 |

Also compared and identical: the cumulative "votes exhausted" column and the "loss by fraction" column at every count
(to 2 millionths in Kurrajong).

**Divergences, and their causes.**
- *Final state:* none. Exact match on winners and on every count total.
- *Residual:* Kurrajong differs by 0.000002 of a vote (one rounding step in one count; every total is within 2 micro-votes
  and no result depends on it). Cause not isolated; most likely the order of flooring when a recipient's votes come from
  more than one value group in the same count. Cosmetic for forecasting.
- *Development history (what the first runs diverged on, now fixed):* (1) exclusion was one count, the ACT does it per
  value group; (2) the count must stop when the last seat fills, mid-exclusion; (3) the non-transferable part of a
  surplus is booked to "loss by fraction" in the official sheet.

**What 2020 did NOT exercise (so the engine is unproven there):** ties of any kind (including the lot); bulk exclusion
(if the Act has any); a last parcel containing papers of several different values being capped by `min(value, TV)`
(it is how I read the rule; it matched, but whether any 2020 case had mixed values was not checked); a candidate
elected with exactly a quota (no distribution, handled but untested); the 17-seat, 3-electorate pre-2016 Assembly
(the engine takes `seats`, but older files and 7-member Molonglo are unchecked).

**Reproduce:** `powershell.exe -Command 'Rscript scripts/hare_clark_count.R'` (all five, about 12 s) or add an
electorate name for a count-by-count log.

## Sketch: how the forecast would use it (not built)

Per electorate, per simulation draw:

1. **Statewide party shares.** Reuse the existing statewide trend and fundamentals (`trend_as_at`, projection) and the
   Cholesky-correlated draw. Needs an ACT party list (Labor, Liberal, Greens, plus an "Independents for Canberra"-type
   bucket). Polls are scarce (2 in 2020), so this is mostly prior and the previous result.
2. **Electorate party shares.** `dev_slope()` swing per party per electorate off the 2020/2024 electorate result
   (redistribution changed the boundaries in 2016, so older cycles map poorly) plus seat noise. Five electorates, so the
   between-electorate variance is estimated from few units; shrink hard.
3. **Candidate shares within party.** This is the part with no single-member analogue and is first-order in Hare-Clark.
   From the ballot files: each candidate's share of their party's first preferences by electorate and year, with the
   Robson rotation effect removed (the data records the rotation version and ballot position per paper). Model as a
   Dirichlet around the previous within-party split, with incumbency / "top-of-ticket" terms and shrinkage toward equal
   shares. Retirements and new candidates need a rule (the `successors/` and `retirements/` pattern exists).
4. **Turn shares into a count.** Two routes:
   - **(a) Ballot resampling (recommended first).** Keep a library of real ballots from 2020/2024. For each draw,
     reweight ballot types so first-preference totals match the simulated candidate shares (raking by first preference),
     then run `hc_count()` on the weighted ballots. This gives real preference flows, real exhaustion and the exact
     last-parcel mechanics for free, which is the whole point of having ballot-level data. Weights, not row copies, so
     the engine needs a small change (`npap` already holds a paper count per distinct sequence; it would hold
     non-integer weights, and the vote arithmetic would use weighted counts).
   - **(b) Aggregate transfer model.** Fit candidate-to-candidate flows as the existing `build_flow_matrix` does, and
     simulate the count on vote totals. Faster but throws away the parcel structure that decides close seats.
5. **Seats per party per electorate** = number of that party's candidates elected; sum over electorates. Report the
   seat distribution and the probability of a majority, like the single-member path.

Speed: 2 s per full count means 2,000 draws x 5 electorates is about 5.5 hours at present. The cost is dominated by
the per-count `next preference` join, so it would need the engine in C++ (the pattern already exists in
`src/seat_sim_core.cpp`) or a cache of next-preference lookups per (sequence, continuing set). Both are mechanical.

**Reusable from this prototype as written:** the loader (`hc_read_act_ballots`), the whole count engine (`hc_count`),
the official-sheet parser and comparator (`hc_read_official_act`, `hc_compare`, which also back a regression test), and the
validation harness. **Reusable for Tasmania** with a change of seat number and a different first-preference source:
the same engine (Tasmania also uses last parcel, but its details differ, see below) once ballot data exists, which it
likely does not (scoping doc: Tasmania publishes count sheets, not ballots).

**Tasmania caveats, unchecked:** Tasmania's rules differ from ACT's in several places I expect but have not verified
(bulk exclusion; electing the remainder when continuing equals vacancies; transfer-value rounding; ties by lot or count
history; Robson rotation with a 5-preference minimum). The engine would need a rules switch and its own validation
against a Tasmanian official count before use, and with no per-ballot file Tasmania would use route (b) only.

## Effort to production

Estimates, relative to the existing single-member path; Opus/Sonnet-supervised sessions of a few hours each.

| Piece | Work | Rough effort |
|---|---|---|
| Harden engine: weighted ballots, rules switch, unit tests on the five 2020 counts and 2024 (files confirmed live, same format) | validate on 2024 and 2016 as a second and third out-of-sample test; fix whatever clause they exercise (ties, bulk) | 1-2 sessions |
| Fetch and load 2016 and 2024 ballot files, candidate-name table, party mapping, boundary-change handling | data work; 2012 and earlier if ballots exist | 1-2 sessions |
| Within-party candidate-share model with Robson effect, estimated from the ballot files, backtested 2016 -> 2020 -> 2024 | the main modelling work; pre-registration needed | 2-3 sessions |
| Statewide and electorate shares for ACT (party list, trend, swing) | reuse of existing code, thin data | 1 session |
| Simulation loop, speed (C++ or caching), seat-probability output, calibration/log-loss scoring on 3 elections x 5 electorates | | 2 sessions |
| Site and registry integration (election dates, `published_flags.R`, registries, CONSTANTS) | | 1 session |

About 8-11 sessions for ACT; Tasmania adds the 25-to-35 seat discontinuity, no ballot data and a second rules
validation, roughly 4-6 more. **Biggest risk:** with three ACT elections of ballot data and polls near zero, the forecast
adds little over "previous result plus noise" for statewide shares, so the value is in the seat-allocation step (which party
wins the fifth seat), exactly what this engine now does exactly.
