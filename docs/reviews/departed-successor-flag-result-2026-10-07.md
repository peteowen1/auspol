# The departed-independent successor flag: coded leak-free, no signal

2026-10-07. Pre-registration: `docs/plans/prereg-departed-successor-flag-2026-10-07.md`
(with Amendments 1 and 2). Pete asked for it to be "VERY careful about leakage".

## How the flag was built, and how leakage was kept out

1. **Population:** 85 seat-elections where the previous election's leading independent
   (>= 10%) did not stand again and another independent did
   (`scripts/build_departed_successors.R`; 82 decided, 3 live vic2026).
2. **First coding REJECTED:** an agent searching the open web. 16 of its 26 TRUEs had
   missing, vague or post-election dates, and the TRUEs concentrated on candidates later
   famous for winning. Quarantined as `*.websearch-REJECTED-2026-10-07.csv`.
3. **Sources fixed instead, both read only as they stood before polling day:**
   - ABC election-guide seat pages, from the latest Wayback capture before polling day
     (`scripts/fetch_abc_guide_snapshots.py`): 58 of 85 cells saved, every capture checked
     earlier than polling day.
   - Wikipedia seat, candidates-list and linked candidate articles at the last revision
     before polling day (`scripts/fetch_wikipedia_preelection.py`): 151 revisions, every
     timestamp checked earlier than polling day (closest: the day before).
   - Three extractor bugs fixed along the way would have biased coverage by era
     (`SURNAME, Given` names never matched; 2010-era profiles inside removed tables;
     untagged profile paragraphs skipped): profiles found 12 -> 44 of 72 on saved ABC pages.
4. **Coding:** a Sonnet agent with no web access, reading only the saved text
   (`external/reference/successors/coding-text.csv`: no votes, no result, candidates
   alphabetical), with a verbatim quote and source date for every TRUE.
5. **Gates and audit before any outcome was read:** coverage 143/143, every TRUE dated
   before polling day (`scripts/fit_departed_successor_rates.R`); all 22 TRUE rows checked
   mechanically: quote verbatim in the saved source, date matches that source, before
   polling day. 22 of 22 pass.

## What the flag contains

22 candidates with a TRUE: `local_office` 18, `community_group` 3, `former_staffer` 1
(Fatchen, Mount Gambier 2026), **`endorsed_by_departed` 0** (no saved pre-election text
mentions an endorsement). 71 of 143 candidates had no candidate-specific text (all of WA
2001/05/17/21, most of NSW and Queensland). Cells: 15 strong, 27 weak, 39 unknown (excluded),
4 excluded as sitting or former MPs.

## Result

Retention = the IND class share now / before (ratio of means). All history before vic2026:

| group | cells | retention |
|---|--:|--:|
| strong (any TRUE) | 12 | 0.54 |
| weak (all FALSE) | 27 | 0.50 |

The between-group variance is below the noise at every target, so the shrinkage weight is 0
throughout and both groups take the pooled time-forward rate (0.31-0.51 by target). **On the
information these two sources hold, the flag does not separate successors who hold the vote
from those who lose it.**

What this does NOT show: that successors are unpredictable. The component expected to matter
most (an endorsement by the departing member) never reached the coder, and 39 of 82 decided
cells had no text. "No signal from local office / community group / staffer on ~40 cells" is
the reportable sentence.

The arm as it stands is a time-forward, held pooled rate (about 0.5, against the leaked 0.38
that rescales to about 0.6). Its screen is recorded below.
