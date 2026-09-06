# The amended C3's emergence count recomputed: 5, not 9, and the amendment's own refusal clauses fire

2026-09-04. Reproduces, from scratch and independently, the unsourced claim in
`plan-candidate-level-model.md`'s C2 ticket ("the corrected person-based
definition leaves 5 held-out emergences, not 9, and 4 of the 5 are One Nation
in one state"). No prior review recorded this recount; it existed only as
prose in the plan. This document sources it.

**Consequence: `prereg-salience-c3-amended.md`'s own pre-registered refusal
clauses fire before the test is even run.** Not a marginal miss — the
population it needs does not exist at the size it assumed.

## The recount, reproduced

`prereg-salience-c3-amended.md` counted **9** held-out emergences across
nsw2023 (5) and sa2026 (4), using non-major winners as the population.

A class-level prior-vote check (does the winning PARTY CLASS have under 15%
share in that seat at the previous election — the same threshold the salience
gate uses throughout section C) reproduces exactly 9: 5 in nsw2023, 4 in
sa2026. **This is the wrong check, and it is the exact trap this repo has
already found and fixed once this session** (the party-switching-incumbent
bug in `analyse_incumbent_transfer.R`, `f5a0851`/`80d223c`): a party CLASS
reading near-zero in a seat says nothing about whether the PERSON who wins it
next time is new.

Checked by name instead — nsw2023's 5 "emergences" against nsw2019's winner
in the same seat:

| seat | 2023 winner | 2023 party | 2019 winner | 2019 party | same person? |
|---|---|---|---|---|---|
| Barwon | Butler, Roy | IND | Butler, Roy | OTH_RIGHT | **yes** |
| Kiama | Ward, Gareth | IND | Ward, Gareth | LNP | **yes** |
| Murray | Dalton, Helen | IND | Dalton, Helen | OTH_RIGHT | **yes** |
| Orange | Donato, Philip | IND | Donato, Philip | OTH_RIGHT | **yes** |
| Wakehurst | Regan, Michael | IND | Hazzard, Brad | LNP | **no** |

**Four of the five are the same sitting member, re-elected, reclassified**
(Shooters-adjacent `OTH_RIGHT` → `IND` in three cases; a sitting Liberal MP
expelled from the party and re-elected as an independent in the fourth,
Kiama). None of them is a person a voter had not already returned to
parliament once. Only **Wakehurst** — a genuinely open seat, the sitting
Liberal minister retired, a new independent won it — is a real emergence.

sa2026's 4 checked the same way, against different people in every case
(Hammond, MacKillop, Narungga all had a different 2022 incumbent of a
different party; Ngadjuri did not exist as a seat in 2022). **All four are
genuine** — a real One Nation breakthrough, four new people.

**Total: 1 + 4 = 5.** Exactly what the plan's unsourced note claimed.

## Why this kills the amendment as written, not just weakens it

`prereg-salience-c3-amended.md` names its own refusal conditions, and this
count trips them directly:

- *"If it works on nsw2023 but not sa2026, or vice versa. With 2 clusters, one
  election carrying the result is indistinguishable from chance."* NSW's
  cluster now has **one** emergence. A one-observation cluster cannot show
  anything about whether the signal generalises within that election; the
  test degenerates to "does salience detect Michael Regan," a sample size of
  one person.
- *"If the One Nation emergences drive the whole gain... Report the two
  subsets separately."* Four of five held-out emergences are the same party,
  in the same state, in the same election. There is no meaningful second
  subset to compare against — it is 4 versus 1, not two comparable groups.
- The amendment's own MDE (9.7 points, sized on 9 emergences across 2
  clusters) is now computed on the wrong n. Five emergences, more lopsided
  across clusters than the 9 it was sized for, gives a worse MDE than the
  document already called "weak" and "the weakest part, named twice."

**Running the amended C3 as currently specified would very likely fail on
its own pre-registered terms before any salience number is even looked at.**
That is not a reason to run it and record the failure — nothing about the
underlying question is answered by a test that cannot resolve it, and a
result from n=5 with 4 confounded into one party-state pair would not be
trustworthy even if it happened to pass.

## What this means for the thread

C3 (the real positive test) has now failed to reach a runnable population
twice: the original design (fed2010–2019, chained Trends windows) was
abandoned as untested before it ran; its replacement (nsw2023/fed2025/sa2026,
one window) is now shown to have a population five times smaller than
assumed, concentrated in one party and one state.

**Two live paths, neither attempted here:**

1. **Revisit the original fed2010–2019 design.** The salience data for it
   already exists — `salience-v6.csv` carries fed2010 (668 rows), fed2013
   (667), fed2016 (717) and fed2019 (727), fetched with a fixed
   per-era anchor (the sitting PM) rather than the chained-window approach
   the original document flagged as untested. Whether a fixed-era-anchor
   design gives comparable scale across eras is itself unverified and would
   need its own check before trusting a cross-era MAE comparison — the same
   "abandon rather than run on incomparable scales" instruction the original
   document already gave.
2. **Widen the amended design's pool further.** vic2022 now has a winners
   file (resolved 2026-08-27, verified this session) — the amendment listed
   its absence as a limitation. qld2020/2024 and the WA cycles are also on
   disk and unused by either C3 design. Whether they contain any genuine
   person-level emergences (by the same by-name check used above, not a
   class-level proxy) is unknown and would need the same recount done here
   applied to each.

Neither is started. This document exists to stop effort going into scoring
the amendment as specified, which the numbers above show cannot pass its own
gates, and to hand the two live options to whoever picks this up next with
the population problem already diagnosed rather than discovered again.
