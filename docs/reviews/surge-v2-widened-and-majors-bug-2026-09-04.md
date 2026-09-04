# A week-old silent bug found widening surge-v2, fixed, then the widening itself

2026-09-04. Extends `scripts/fit_salience_surge_v2.R`'s training pairs from
the original 5 (`prereg-salience-surge-v2.md`, 2026-08-27) to 9, using the
wider election set `prereg-salience-c3-v3.md` validated the same day. Found
and fixed a real bug along the way that has nothing to do with the widening.

## The bug: `governed_population()` had no major-party filter

`R/salience_screen.R`'s `governed_population()` flags a candidate as
"governed" (a case the salience screen or hazard model is entitled to speak
about) whenever their own prior vote in that seat is under 15%, they are not
of a surging class, and they are not personally returning. It never excluded
major parties, because it never needed to: `output/salience-v6.csv` held only
non-major candidates until the majors fetch landed on 2026-08-28, one day
after this function was written. There was nothing else in the corpus to
match.

Once majors were added, that silently broke. A brand-new LNP candidate
replacing a retiring MP in a seat that has been safely LNP for decades reads
`prev_party` — this PERSON's own prior vote in this seat, by design — near
zero, identically to a genuine independent emergence. Every safe-seat
succession in the corpus started scoring as a "governed emergence."

**Found widening the training pairs, not caused by it.** Re-running the
*original* 5-pair set against today's data (no widening at all) reproduces
the same contamination: vic2022's governed population goes from 1 real
emergence (Gabrielle de Vietri, Richmond) to 11, ten of them new-candidate
LNP holds of already-safe LNP seats. This is a week-old regression nothing
had re-validated against since the fetch that caused it.

**Fixed**: `governed_population()` now excludes `ALP`/`LNP`/`NAT` explicitly.
Confirmed the fix restores the ORIGINAL document's population exactly —
fed2019 305/1, fed2022 291/6, vic2022 166/1, nsw2023 169/1, sa2026 61/0, a
byte-for-byte match — proving the corruption was purely the majors fetch and
the fix reverses it cleanly. A regression test added
(`tests/testthat/test-salience_screen.R`) reproducing the exact failure shape
(a new major-party candidate in their own party's held seat).

**Not caught earlier because nothing re-ran this validation between the
majors fetch and tonight.** The published forecast was not affected — the
screen mechanism is called with `vic2026`, for which no salience data exists
yet, so it returns `NULL` and falls back to the unscreened arm regardless —
but the same corruption would have hit the moment Victoria's own candidates
are fetched, silently, unless this was found first.

## The widened population, with the fix applied

9 election pairs (the original 5 plus fed2010, fed2013, fed2016, wa2008 — the
four `prereg-salience-c3-v3.md` found usable and confirmed contain a genuine
governed emergence; qld2020/2024 and every other WA cycle were checked and
confirmed to contribute nothing real).

| pair | n | winners |
|---|--:|--:|
| fed2010 | 286 | 2 |
| fed2013 | 162 | 1 |
| fed2016 | 326 | 1 |
| fed2019 | 305 | 1 |
| fed2022 | 291 | 6 |
| vic2022 | 166 | 1 |
| nsw2023 | 169 | 1 |
| sa2026 | 61 | 0 |
| wa2008 | 105 | 1 |

**14 governed winners across 9 elections**, all confirmed non-major. Fewer
than my own independent census (17-18) from the same source data, because
this definition additionally excludes surging-class candidates and correctly
applies the `SEAT_RENAMES` fix (Wilkie's Denison→Clark transition, which my
own quicker census missed and would have miscounted as a fresh emergence —
`governed_population()` already handled it correctly).

**Nested LOO, ridge-penalised: mean log loss 0.0329 against a base-rate-only
0.0418** — beats baseline by roughly 21%. Wins in 7 of 9 elections
individually (fed2010, fed2013, fed2016, fed2019, fed2022, nsw2023, sa2026);
vic2022 and wa2008 are each slightly worse than base rate, both on a single
governed winner, so neither is more than noise at that n.

**Dry-run holds**: Ian Cook (Mulgrave 2022, 18% actual, lost) scores
`p_hat = 0.078` — appropriately low, not overconfident, the same safety
property the original 5-pair fit established.

**Vic2022 is still an honest near-wash**, essentially unchanged from the
original document's finding. This is not a failure of the widening — Victoria
itself carries exactly one prior governed emergence (De Vietri) whichever
population it is measured against, and adding more federal and WA data does
not manufacture more Victorian history. The widening's value is in the
*overall* model — 9 elections and 14 winners fund the fit now, instead of 5
elections and 9 — not in resolving vic2022's specific data scarcity, which
`prereg-salience-surge-v2.md` already named as the thing that "matters live"
and could not be fixed without more Victorian elections existing.

## What this does and does not settle

**Settles**: the surge-v2 mechanism, refit on a corrected and now
substantially wider population, still beats baseline, and the specific
overconfidence failure mode it was built to avoid (Bandt-style false alarms)
still does not reproduce.

**Does not settle**: whether to turn `AUSPOL_SALIENCE_SURGE_V2` on for the
published forecast. That is Pete's call, not authorised by this result alone
— and per the original document, there remains no genuinely Victoria-specific
out-of-sample test possible, since Victoria's own candidates for 2026 do not
exist yet.
