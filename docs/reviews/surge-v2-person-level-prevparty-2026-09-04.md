# Two more governed_population() bugs, found asking about Allegra Spender

2026-09-04, same evening as `surge-v2-widened-and-majors-bug-2026-09-04.md`.
Pete asked why Allegra Spender (Wentworth, fed2022 -- a teal win, jump_pctile
0.982, the same signature as Ryan/Chaney/Scamps/Tink) wasn't in the surge-v2
winner list. She wasn't governed at all. Two real bugs found chasing that,
fixed in sequence, both in `R/salience_screen.R`'s `governed_population()`.

## Bug 1: `prev_party` was the IND/OTH CLASS's prior vote, not this candidate's

`prev_party` is computed as `max(pcv)` grouped by `(seat, party)`
(`fetch_salience_v6.R`). For ALP/LNP/NAT/GRN/ONP that's a real signal --
those labels denote one continuous organisation, and Pete's own read on this
(worth keeping): a party's own prior result there is genuinely useful
information about the seat, even for IND, since it shows the electorate is
willing to vote non-major -- it just isn't the same kind of continuity a real
party's vote carries, because IND is candidate-driven, not brand-driven. That
distinguishes "useless" from "wrong feature for this purpose": the class-level
number is a real, separate signal (already captured as `prev_ind`, the seat's
total prior IND vote, a feature the ridge model already fits its own
coefficient on) -- but using it as `prev_party`, which GATES whether a
candidate counts as a governed emergence at all, wrongly required a
first-time independent to somehow have no OTHER independent's history in the
seat either. Spender's recorded prev_party was 32.4% -- Kerryn Phelps' 2019
result, a different person -- despite Spender never having contested any
seat before. That failed the `prev_party < 15` gate and excluded her
entirely.

**Fixed**: for IND and OTH only (real parties unchanged), `prev_party` is now
this specific candidate's own prior result, found by the same person-level
name match (`search_form()`) the function already used for the
returning-member check -- reusing the existing match rather than adding a
second one. A governed IND/OTH candidate is by construction a first-timer in
that seat under their own name (anyone who genuinely returns is already
excluded via `ret`), so their own prior vote is correctly 0 unless the match
finds an earlier row for them personally.

## Bug 2, unmasked by fixing bug 1: seat renames applied retroactively

Refitting immediately after bug 1's fix produced Andrew Wilkie as a governed
WINNER in fed2013 and fed2016 Denison -- both times he was the sitting
member, returning under his own name, not a fresh emergence.

`apply_renames()` maps `denison -> clark` unconditionally, but the rename
only actually took effect for fed2019+. For a pair entirely BEFORE it (e.g.
fed2013, prev fed2010 -- both elections still call the seat Denison), the
function renamed the PREVIOUS election's seat to "clark" anyway, so the
returning-member match key became `"clark andrew wilkie"` instead of
`"denison andrew wilkie"` and never matched his own prior row. `ret` came
back FALSE, and once `prev_party` became person-level (bug 1's fix), nothing
else stopped him from reading as a fresh governed candidate with
`prev_party = 0` in the seat he already held. **Previously invisible**: the
OLD class-level `prev_party` threshold excluded him anyway, by pure
coincidence, for the unrelated reason that his own result was folded into
the seat's IND class max either way.

**Fixed**: match against both the pre- and post-rename spelling of every
`PREVT` seat, rather than choosing one. This is correct regardless of which
side of the rename either election in a pair falls on, with no need to
special-case eras -- and it fixed the identical error already present in the
returning-member check, not just the new prev_party lookup, since both reuse
the same seat-key vectors.

Two regression tests added (`tests/testthat/test-salience_screen.R`): a
returning member excluded when NEITHER election crosses a rename, and an
IND's `prev_party` read as their own result rather than a different
independent's.

## The corrected population

18 governed winners across 9 elections (up from 14 after the majors fix
alone, and briefly 20 with bug 1 fixed but bug 2 still live):

| pair | n | winners | vs previous (majors-fix only) |
|---|--:|--:|---|
| fed2010 | 291 | 2 | unchanged |
| fed2013 | 166 | 1 | unchanged (Wilkie's return correctly excluded again) |
| fed2016 | 327 | 1 | unchanged |
| fed2019 | 313 | 2 | **+1**: Helen Haines (Indi) now correctly included |
| fed2022 | 294 | 7 | **+1**: Allegra Spender (Wentworth) now correctly included |
| vic2022 | 166 | 1 | unchanged |
| nsw2023 | 172 | 1 | unchanged |
| sa2026 | 73 | 2 | **+2**: Matt Schultz (Kavel), Travis Fatchen (Mount Gambier) |
| wa2008 | 105 | 1 | unchanged |

Sanity-checked by name, not just count: Haines succeeded McGowan in Indi --
same pattern as Spender, a first-timer inheriting a predecessor's strong IND
result. Fatchen's Mount Gambier had been held by Troy Bell, also IND -- the
identical succession pattern again.

**Nested LOO, ridge-penalised: mean log loss 0.0404 against base-rate-only
0.0595** -- beats baseline by ~32%, in 7 of 9 elections individually (fed2013
and vic2022 are each a small wash on a single governed winner, unchanged
from every prior version of this population). Dry-run holds: Ian Cook
(Mulgrave, lost) scores `p_hat = 0.060`.

**Discrimination on the full population: AUC 0.976**, mean `p_hat` 0.109 for
the 18 winners vs 0.008 for the 1889 losers -- both stronger than the
majors-fix-only version (was AUC 0.972, 0.126 vs 0.007), because Haines,
Spender, Schultz and Fatchen are now scored as what they actually were
(genuine high-percentile emergences that won) instead of not being scored at
all.

## What this does and does not settle

**Settles**: `prev_party` now measures what its own name says for every
party class in the corpus, not just the majors. The surge-v2 population and
fit shipped in the prior commit (`b55ae06`) undercounted real winners by 4
and is superseded by this one.

**Does not settle**: whether `prev_ind` (the seat-level receptivity signal
this fix deliberately preserves rather than discards) is weighted correctly
relative to `prev_party` and `jump_pctile` in the fitted hazard -- that's a
question about the ridge fit's own coefficients, unexamined here. Also
**Checked, not left open**: whether ONP's SA 2026 breakthrough needed the
same person-vs-class fix. It doesn't, and the reason is already load-bearing
elsewhere in this function. `surging_parties("sa", 2022, 2026, 5)` flags
`c("ONP", "LNP")` for that pair -- SA ONP's statewide mean primary jumped
6.6% (2022, 19 candidates) to 22.5% (2026, 47 candidates, contesting nearly
every seat, now above LNP's own 2026 mean of 18.1%) -- and `governed` is
FALSE for every ONP candidate in sa2026 regardless of `prev_party`,
including the four who won (Thomas/Narungga, Virgo/MacKillop, Paton/Ngadjuri,
Roylance/Hammond). A genuine statewide swing is already routed away from the
candidate-level salience mechanism entirely, correctly, by the pre-existing
surge-threshold check -- so `prev_party`'s person-vs-class distinction, which
only matters for candidates the function treats as individually governed,
never comes into play for them. Federally ONP's mean primary has stayed in
the 5-13% band since 2016 with no comparable structural jump, so it does not
trip `surging_parties()` there and stays candidate-scale. No change made;
none was needed.
