# Pre-registration: price salience into the primary AND into its variance

Written and committed **before** any arm was run, 2026-09-07.

## The problem, in one seat

Suzanna Sheed won Shepparton in 2014 with **32.7%** of the primary, from a seat
where independents had polled 3.6% four years earlier. Her Google Trends jump
puts her in the 98th–99.5th salience percentile. The model's own band table says
a candidate in that band polls **13.9%, sd 12.6** — measured off 36 candidates.

The simulator uses neither number.

- The **point estimate** the seat gets is the class prior, about 6%, not 13.9%.
  The mechanism to use 13.9% exists (`AUSPOL_SALIENCE_EXPECTED`), was refused on
  2026-09-07, and is wired into the federal harness only.
- The **variance** it gets is `level_sd = a + b*sqrt(p(1-p))` with a = 1.10,
  b = 8.67. At p = 0.139 that is **4.10**, not 12.6. And because the curve is
  binomial-shaped it peaks near 50%, so it gives an ALP candidate on 30% MORE
  uncertainty (5.07) than a top-percentile insurgent on 13.9%. That is backwards
  for the case we keep losing.

`exp_sd` is computed in `R/salience_surge.R` and **read by nothing**. It appears
in no other file in the repo.

At sd 4.10 around a 6% prior, Sheed's actual 32.7% is a seven-sigma event. No
amount of point-estimate correction alone reaches it; the tail has to open too.

## The three arms

They are separated because they act on different parts of the distribution and
are not assumed additive.

- **Arm A — expected primary.** `AUSPOL_SALIENCE_EXPECTED=1`: a governed
  candidate's projected share becomes their salience band's `exp_pcv`. Already
  implemented federally; this pre-registration extends it to all six harnesses,
  which is itself a change and is stated as one.
- **Arm B — expected variance.** New. A governed candidate's per-seat deviation
  sd becomes their band's `exp_sd` instead of `level_sd`. Nothing else moves.
- **Arm C — both.** Run as its own arm, not inferred from A and B. Widening the
  tail around a point estimate that has also moved is a different object from
  either alone.

Baseline is the shipped configuration, `scripts/published_flags.R`, at the
current head.

## The criterion

**Primary: PB3f, pooled seat log loss EXCLUDING seats where either arm gives the
actual winner ≤ 1e-4.** Currently **0.3056** over 2,045 seat-elections.

**Reported beside it and never decisive:** pooled log loss including those seats
(currently 0.3386), the count of floor seats (currently 5) and which pairs they
are in, and pooled seat-share RMSE.

**Why not plain pooled log loss.** It is dominated by the floor: 5 of 2,050
seat-elections carry 10.0% of it. One seat crossing the 1e-6 boundary moved it
0.0019 on 2026-09-07 with no change to the model at all. A metric that a single
hopeless seat moves further than the effect under test cannot decide anything.
That failure is why the same expected-primary mechanism was refused this
morning, and re-testing it against an instrument that can see it is the express
purpose of this plan.

**The floor count is a first-class result here, not a footnote.** These arms
exist to move seats off the floor. An arm that leaves PB3f flat while taking the
floor count from 5 to 3 has done exactly what it was built to do, and the write-up
must say so rather than reporting a tie.

**Decision rule.** Adopt the best arm if:
1. PB3f improves, or is unchanged within 0.001 while the floor count falls; AND
2. no jurisdiction's log loss worsens by more than 0.01; AND
3. pooled seat-share RMSE does not worsen by more than 0.05.

If two arms qualify, take the one with the lower PB3f; on a tie there, the
simpler arm (A or B over C).

### Sizing, before running

Six harnesses, 22 pairs, 2,050 seat-elections. The arms touch only *governed*
candidates — roughly 150–200 per election, one to three per seat — so most seats
are untouched and the pooled move will be small even if the mechanism is right.
Expected effect on PB3f: 0.002–0.010. The floor count is the more sensitive
instrument at this sample size, which is why clause 1 admits it.

### Dry-run of the criterion, on cases whose answer is already known

1. **Shepparton 2014.** Sheed, band expectation 13.9 ± 12.6, actual 32.7, our
   current p = 0.0469 after today's seat-name fix. A correct arm raises her
   materially. If an arm leaves Shepparton unchanged it has not fired, and that
   is a bug to find before reading any pooled number. **The criterion sees this
   through the floor count and the per-seat table.**
2. **Barwon 2019.** Roy Butler is NOT in `output/salience-v6.csv` at all —
   `fetch_seat_salience.R` fetches five candidates per seat ranked incumbent,
   IND, majors, GRN, ONP, then OTH_RIGHT eighth, and Barwon had nine
   candidates. **No arm here can fix Barwon**, because there is no jump to
   price. Predicted in advance so that an unchanged Barwon is not read as the
   arms failing. It is a separate fix.
3. **A quiet independent on 3%.** Must NOT be widened much: their band is the
   bottom one, `exp_sd` around 4.5, close to `level_sd`. If arm B widens
   low-salience candidates as much as high-salience ones it is behaving like the
   refused `AUSPOL_LEVEL_MULT_IND` blunt multiplier, and the band structure is
   not doing any work. Check this explicitly before reading the metric.

## Refusal section — what disqualifies an apparent win

1. **A win that is only the floor count.** If PB3f worsens beyond 0.001 while
   the floor count falls, the arm is buying tail coverage by degrading every
   other seat. Refuse.
2. **Losers raised as much as winners.** These arms lift high-salience
   candidates whether or not they went on to win. Report the count of governed
   candidates given p > 0.30 who LOST, before and after. If it more than
   doubles, refuse — that is the "false independent" failure the 2026-08-27
   salience precision criterion was written for and mis-specified.
3. **A gain confined to Victoria.** Victoria has just had two bugs fixed and its
   numbers moved a long way today. If the improvement is Victorian and nowhere
   else, it is likelier to be interaction with those fixes than the mechanism
   working. Require the sign to hold in at least three jurisdictions.
4. **Calibration slope collapsing.** Widening tails can improve log loss while
   making the model uselessly vague. Slope is never decisive in this repo, but a
   fall below 0.5 pooled is a refusal, not a footnote.

## What the criterion cannot see

- Whether `exp_sd` is the right *shape*. It is a within-band standard deviation
  of realised vote, which is not the same object as the sd of a forecast error,
  and it is estimated on 12–48 candidates in the top bands.
- Whether the bands themselves are well cut. They are percentile bins of `jump`,
  and the top band holds 12 candidates.
- Anything about seats whose winner is absent from the salience corpus, which is
  Barwon and an unknown number of others. The `OTH_RIGHT`-eighth priority bug
  bounds that, and it is a separate change.

## Order of work

1. Commit this file.
2. Arm B first — it is the new code and the one expected to matter most, because
   it acts on the tail and the tail is where the floor seats are.
3. Arm A, extended beyond the federal harness.
4. Arm C.
5. Apply the rule; report the floor count and the per-seat movement for
   Shepparton in every case.
