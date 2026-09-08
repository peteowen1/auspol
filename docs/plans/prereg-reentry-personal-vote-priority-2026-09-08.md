# Pre-registration: the re-entry prior overwrites a more-informed personal-vote floor

Written and committed **before any code changes**, 2026-09-08. Follow-up to
`docs/reviews/reentry-prior-nsw-qld-2026-09-08.md`, which found that Kiama
(nsw2023, arm D's single biggest NSW loss) is a genuine model miss on a
major-party defector's personal vote, not contaminated data.

## The defect

`personal_prior_vote()` (`R/candidate_returns.R`), with `AUSPOL_DEFECT_DISCOUNT=1`
(a published default, `major_discount = 0.282`), computes a fitted floor for
a sitting member who defects from a major party and re-contests their own
seat under a non-major label — Gareth Ward (Kiama, LNP 53.6% → IND) is
exactly this case, and the mechanism is fitted on 12 such defectors, mean
retention 0.284 of their prior vote. This floor feeds into the swing-forward
projection via `.own_x()` (all six harnesses,
`backtest_candidate_{fed,nsw,qld,sa,vic,wa}.R`), which correctly substitutes
it for the class's otherwise-near-zero seat-level prior vote before swinging
it forward with `dev_slope()`.

**Then the re-entry prior overwrites it.** Every harness applies
`REENTRY_CELLS` to `shares` immediately after the swing loop, with the
identical design comment in all six: *"Re-entry prior lands here, on the
POST-SWING projection."* This is deliberate — the re-entry GLM/ratio
estimate is already a target-election-level share and would be double-swung
if it went in earlier — but the overwrite is **unconditional**: it replaces
a cell's value regardless of whether that cell's swing-forward value came
from the generic class-level base or from an identity-matched,
`major_discount`-informed floor. The generic re-entry model has never heard
of Gareth Ward; it fits "IND re-entering a seat" in general and discards the
more specific signal.

**Twelve cells across 22 pairs fit this shape** (`major_discount = 0.282`,
`prev_party` a major, checked programmatically against
`output/candidacies.csv` via `personal_prior_vote()` directly, 2026-09-08):

| pair | seat | new class | floor (own_prev_pcv) | prev party | verified defector |
|---|---|---|--:|---|---|
| nsw2019→2023 | Kiama | IND | 15.1 | LNP | Gareth Ward, LNP 53.6%→IND 38.8% |
| wa1996→2001 | Pilbara | IND | 18.0 | ALP | Larry Graham, ALP 63.8%→IND 54.6% |
| fed2007→2010 | Ryan | IND | 15.5 | (major) | not individually checked |
| fed2013→2016 | Tangney | IND | 16.1 | (major) | not individually checked |
| fed2019→2022 | Hughes | OTH_RIGHT | 17.5 | (major) | not individually checked |
| fed2022→2025 | Calare | IND | 33.8 | LNP | Andrew Gee, LNP→IND |
| wa2001→2005 | Vasse | IND | 8.4 | (major) | not individually checked |
| wa2005→2008 | Nedlands | IND | 14.6 | (major) | not individually checked |
| wa2013→2017 | Hillarys | IND | 18.1 | (major) | not individually checked |
| sa2022→2026 | Black | IND | 14.1 | (major) | not individually checked |
| sa2022→2026 | MacKillop | IND | 17.6 | LNP | Nick McBride, LNP 62.3%→IND 14.8% — **see refusal note** |
| qld2017→2020 | Whitsunday | OTH | 9.1 | (major) | not individually checked |
| vic2014→2018 | Morwell | IND | 23.4 | (major) | not individually checked, overlaps `NEXT-STEPS.md`'s "seats that changed hands" item |

**Two of these are already central findings from this session**: Kiama is
arm D's single biggest NSW loss (93% of nsw2023's regression), and Pilbara
is one of arm D's two named floor-loss seats
(`prereg-reentry-lean-gap-2026-09-08.md`). Both currently get a `glm`-path
re-entry fill (n=392 and n=391 respectively — well-supported regressions,
not the sparse flat-ratio path arm H targets), which is consistent with
this being the same overwrite mechanism in both cases.

## The fix

Before writing `REENTRY_CELLS` into `shares`, drop any `(seat, party)` row
that `.own_prev` (personal_prior_vote()'s output, when `major_discount` is
set) already has a non-NA `own_prev_pcv` for. Concretely, in each harness's
post-swing block:

```r
if (!is.null(REENTRY_CELLS) && nrow(REENTRY_CELLS)) {
  RC <- REENTRY_CELLS
  if (!is.null(.own_prev)) {
    op_key <- paste(.own_prev[!is.na(.own_prev$own_prev_pcv)]$seat,
                     .own_prev[!is.na(.own_prev$own_prev_pcv)]$party)
    RC <- RC[!paste(RC$seat, RC$party) %in% op_key, ]
  }
  .ri <- cbind(match(RC$seat, rownames(shares)), match(RC$party, colnames(shares)))
  .rk <- stats::complete.cases(.ri)
  shares[.ri[.rk, , drop = FALSE]] <- RC$value[.rk]
}
```

This is a filter on the WRITE, not a change to either `personal_prior_vote()`
or `apply_reentry_prior()` — both keep computing what they already compute;
only the collision at write time changes. `AUSPOL_DEFECT_DISCOUNT` must
already be `1` for `.own_prev` to carry any `own_prev_pcv` at all, so this
arm is a no-op whenever that switch is off (dry-run case 1, below).

## The arms

- **Baseline**: arm D as currently shipped-and-measured (re-entry always
  overwrites, `AUSPOL_DEFECT_DISCOUNT=1` already on).
- **Arm PV** ("personal vote priority"): the filter above, applied in all
  six harnesses in the same commit (CLAUDE.md's six-harness rule).

## The criterion

**Primary, per CLAUDE.md's targeted-fix rule**: the 12 named cells above,
reported individually every run — probability given to the actual winner,
before and after. This is a targeted fix (it can only ever touch these 12
cells, by construction: a major-party defector re-contesting their own seat
under a new class is rare), so the named cells are primary and the
election-wide number is a do-no-harm guard, not the decision.

**Guard**: pooled seat log loss across all 22 pairs must not worsen by more
than 0.001 against arm D. Given only 12 of ~2,050 seat-elections can move at
all, this guard should be nearly automatic — if it fires, something outside
the 12 named cells moved, which would mean the filter has a bug (e.g.
matching the wrong seats).

**Decision rule.** Adopt arm PV if:
1. The pooled guard holds (≤0.001 worse against arm D); AND
2. Kiama and Pilbara specifically both move toward their actual winner's
   probability (both are known under-estimates today — actual winners
   38.8% and 54.6%, current re-entry GLM estimates 13.1% and unmeasured but
   presumably far below the informed floor); AND
3. No other named cell's probability for the actual winner falls by more
   than half of where it already sat (same concrete bound arm H used).

## Dry-run of the criterion on cases whose answer is already known

1. **`AUSPOL_DEFECT_DISCOUNT=0` (the pre-2026-09-0X default) must reproduce
   the current re-entry-only behaviour exactly** — `.own_prev` is `NULL`
   when the switch is off, so the filter's `!is.null(.own_prev)` guard makes
   it a hard no-op. Not yet run; should be asserted by a test before the
   grid, same discipline as arm D and arm H's `k_sd=0` cases.
2. **Kiama should move toward 38.8%** (the actual result) when its cell is
   protected — its floor (15.1%) is much closer to the truth than the
   generic GLM's 13.1%, and closer still if `dev_slope()`'s swing pushes it
   up further from there. If Kiama's probability does NOT improve, the fix
   is not doing what it claims and should be refused regardless of the
   pooled number.
3. **MacKillop is a genuine risk, not a free win — named in advance.** Its
   defector, Nick McBride, is the LOW outlier in the 12-member fit that
   produced the 0.284 mean (his own retention was 0.24, well below the
   mean, and `personal_prior_vote()`'s own docs single him out: "McBride
   collapsed... while Ward held"). The 17.6% floor this fix would protect
   may overestimate McBride specifically. If MacKillop's probability for
   the actual winner gets WORSE under arm PV, that is expected from this
   note, not a surprise to investigate — but it still counts against
   decision rule #3 and could be the reason to refuse.
4. **A cell with no `.own_prev` entry must be byte-identical to arm D**
   regardless of arm PV, since the filter only touches rows present in
   `.own_prev`. Any such cell moving means the key-matching (`paste(seat,
   party)`) is misaligned.

## Refusal section — what disqualifies an apparent win

1. **Case 1 or 4 failing** — as always in this sequence, a non-zero-default
   plumbing bug invalidates everything measured on top of it.
2. **Kiama or Pilbara not improving** (dry-run case 2) — the two cases this
   fix exists for are also the two the pooled number could most plausibly
   mask a failure on, since they are large individual movers.
3. **MacKillop moving the wrong way by more than decision rule #3's bound**
   — pre-named as a real risk, not treated as an unexpected finding if it
   happens.
4. **A gain confined to the two federal/WA cases with only 12 total cells
   in play is not a broad validation and should not be reported as one** —
   this is a targeted fix by construction; do not let a clean pooled number
   read as more than "12 cells, mostly better."

## What the criterion cannot see

- **Whether `major_discount = 0.282` is even the right value for THIS
  purpose.** It was fitted to predict the DEFECTOR'S OWN vote share, not to
  compete against a generic re-entry GLM's estimate for the same cell — the
  two might have different optimal weights if this fix is adopted and later
  extended to a genuine blend rather than a strict override.
- **The 10 not-individually-checked cells** (Ryan, Tangney, Hughes, Vasse,
  Nedlands, Hillarys, Black, Whitsunday) are trusted on `personal_prior_vote()`'s
  own major-party exclusion logic and the programmatic check above, not
  verified against `output/candidacies.csv` by name the way Kiama, Pilbara,
  Calare and MacKillop were. Worth doing before or during implementation,
  cheaply, given the small number.
- **Traeger, Hill and Burdekin (the other three named seats from the
  NSW/QLD investigation) are NOT covered by this fix at all.** They are not
  major-party-defector cases — Katter and Knuth are SAME-CLASS returning
  incumbents, not defectors, so `personal_prior_vote()` never touches their
  cell; the class that overshoots (ONP) is a genuinely different candidate
  from the incumbent. That needs a separate mechanism (e.g. discounting a
  re-entering class's estimate against a strong same-person incumbent of a
  DIFFERENT class) and is out of scope here.
- **Overlap with `NEXT-STEPS.md`'s "seats that changed hands" open item**
  (Morwell, Orange, Wagga Wagga) — Morwell appears in both lists. That item
  proposes using `load_seats()`'s known-before-polling-day incumbency
  directly; this fix works through a different, narrower mechanism
  (candidate identity matching via the corpus). They may be redundant for
  Morwell specifically, or complementary — not resolved here.
