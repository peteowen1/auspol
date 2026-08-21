# Pre-registration: add Western Australia to the flow matrix

Written 2026-08-21, **before anything is measured**. Committed before running.

Same shape as `prereg-qld-flows.md`, which this deliberately mirrors so the two
data additions are decided on the same terms.

## What changes

| | current (VIC+SA+QLD) | plus WA |
|---|---:|---:|
| exclusion events | 1,496 | **3,130** |
| cells at n >= 3 | 78 | **97** |
| pairs observed at all | 115 | **140** |
| One Nation exclusions | 198 | **359** |
| One Nation votes transferred | 619,631 | **834,069** |

Seven Western Australian elections: 1996, 2005, 2008, 2013, 2017, 2021, 2025.
2001 is excluded by the fetcher on exhaustion (2.27%) under a rule that
predates this experiment, and **this pre-registration does not reopen it**.

## The structural difference, found before measuring and stated here

**Western Australia's LNP transfers go to another LNP candidate 55.8% of the
time. In the current matrix that figure is 16.3%.**

That is Liberal-versus-Nationals three-cornered contests, which Western
Australia has many of and Victoria has few. LNP-origin exclusions are only 5.4%
of the WA pool, so this is a small share of the data landing squarely on the
row it can distort. It is written down now because noticing it afterwards and
then acting on it would be indistinguishable from fitting the answer.

Origin-class mix otherwise, current vs WA: OTH_RIGHT 25.1/28.8, OTH 22.8/19.6,
GRN 18.5/23.1, IND 15.6/11.2, ONP 13.2/9.9, LNP 3.3/5.4, ALP 1.5/2.0.

## Leakage, and the control this design does NOT get for free

Queensland's design leaned on five backtest elections that predated both
Queensland elections and therefore had to come out byte-identical. **Western
Australia has no such control**: the earliest WA election here is December 1996,
which precedes every backtest election, so all ten can legitimately use some WA
data. Losing the control is the main methodological cost of this change.

It is replaced with a **plumbing control**, which tests the filter rather than
the data: a run with the WA cutoff forced to 1990-01-01 admits no WA election
and **must reproduce the baseline byte-for-byte**. If it does not, the date
filter is not doing what it claims and nothing else in the run can be believed.

Each backtest election admits only WA elections held strictly before it:

| election predicted | WA elections admitted |
|---|---|
| fed2010 (Aug 2010) | 1996, 2005, 2008 |
| fed2013 (Sep 2013), nsw2019, vic2018, fed2016, fed2019 | + 2013 |
| fed2022, vic2022, nsw2023 | + 2017, 2021 |
| fed2025 (May 2025), sa2026 | + 2025 |

## What is measured

**Per-seat log score, leave-one-election-out, clustered on the election** --
the harnesses' native criterion, unchanged from the Queensland run.

Reported alongside: accuracy, and the One Nation seat range for Victoria 2026.

## Decision rule, fixed now

Ten elections, so the paired per-election difference has **9 degrees of
freedom**. For scale, Queensland measured +1.55 SE on 4.

- **Adopt if the clustered difference exceeds 2 SE.**
- **If positive but under 2 SE, adopt anyway**, provided the plumbing control
  is byte-identical and no refusal fires. The reasoning is the Queensland one
  and is written down now rather than afterwards: this is a data-coverage
  change, and a rate estimated from 359 One Nation exclusions is not worse than
  one estimated from 198 merely because a test on 9 df cannot separate them.
- **If negative by more than 1 SE, refuse and investigate.** That would say
  Western Australian transfers are unlike Victorian ones in a way that matters,
  which is a finding about transferability, not a reason to shrug.

## Refusals

Named in advance, including the directional side effects that would disqualify
a winner -- the section `CLAUDE.md` requires because two of three experiments
were refused on grounds invented after the result.

- **W1 -- the plumbing control must be byte-identical.** With the cutoff at
  1990 no WA election is admitted and every arm must match the baseline exactly.
- **W2 -- the LNP row.** If the pooled LNP->LNP conditional rate exceeds **30%**
  (it is 16.3% now, and WA alone is 55.8%), stop and report. A rate driven by
  three-cornered contests Victoria mostly does not hold is a Western Australian
  artefact, not a transferable rate. The pre-specified fallback, fixed now so it
  cannot be invented later, is to admit WA's non-LNP-origin exclusions and drop
  its LNP-origin ones -- **and that fallback must be scored and reported as its
  own arm, never substituted for the primary one after seeing it lose.**
- **W3 -- One Nation improving is EXPECTED and is not the evidence.** The
  motivation is more One Nation data, so resting the case on One Nation's own
  numbers is circular.
- **W4 -- the live forecast.** If any party's Victoria 2026 median moves by more
  than **2 seats**, stop and report rather than ship.
- **W5 -- no cherry-picking the pool.** All seven admitted elections go in or
  none. 2001's exclusion is the fetcher's pre-existing exhaustion rule and is
  not a choice made here.
- **W6 -- the directional side effect.** If One Nation's win probability rises
  in more than **80% of Victorian seats** while the overall gain is under 2 SE,
  stop and report. This is the exact shape that disqualified the One Nation
  seat-uncertainty change on 2026-08-19, and it is named here in advance so the
  same judgement cannot be presented as a fresh insight.

## What this cannot see

- **Whether WA's Liberal/National split behaves like Victoria's.** The matrix is
  keyed on party class, and both parties are class LNP, so a Liberal-versus-
  National contest is an LNP-versus-LNP contest to the model. W2 bounds the
  damage; it does not measure the assumption.
- **The One Nation evidence WA adds comes from its LOW elections.** One Nation
  polled 9.58% in WA in 2001 -- its best -- and that election is the one
  excluded on exhaustion. The 161 WA One Nation exclusions come from elections
  where it polled 1.3% to 4.9%. Victoria 2026 is forecast near 24%, so this
  widens the evidence base without extending it upward.
- **WA exhausts a little where Victoria exhausts almost nothing** (0.15-0.88%
  against roughly zero). Pooled rates are conditional on non-exhausted
  transfers, and a fraction under 1% is assumed not to matter rather than shown
  to not matter.
- **Anything about the One Nation allocation**, a separate input still fitted on
  one election.
