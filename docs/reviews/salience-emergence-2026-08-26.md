# Google Trends separates an emergence from a token candidacy: AUC 0.841

2026-08-26. The first properly measured result on this signal, and it
**supersedes** every earlier salience number in this repo.

## The result

Group A: a non-major **won** a seat where the model gave the winning party
under 5%. Group B: a non-major **stood and lost** with at least 5% of first
preferences, from the same elections. Ratio is the candidate's Google search
volume against the person they were running against, averaged over the final
eight campaign weeks and ending the day before polling day.

| cut | AUC | n | p |
|---|---:|---|---:|
| all rows | 0.838 | 15 v 28 | <0.001 |
| incumbent-anchored only | **0.865** | 10 v 17 | 0.001 |
| excluding the hand-added row | 0.838 | 15 v 28 | <0.001 |
| 2013 onward | 0.907 | 12 v 27 | <0.001 |
| 2016 onward | 0.874 | 10 v 19 | 0.001 |
| **incumbent + no hand-add + 2016 on** | **0.841** | 9 v 14 | **0.005** |

**Quote the last row.** It is the strictest cut: real incumbent anchors only,
no hand-added case, and only elections where Trends volume is not marginal.

| | n | zeros | median | mean | max |
|---|---:|---:|---:|---:|---:|
| lost | 28 | **22** | 0.00 | 0.138 | 1.650 |
| **won** | 15 | 2 | **0.55** | 1.003 | 5.375 |

**22 of 28 losers sit at zero; 13 of 15 winners do not.**

## The seats this exists to fix

| seat | candidate | % | model gave | ratio |
|---|---|---:|---:|---:|
| Curtin 2022 | Kate Chaney | 29.5 | **0.0020** | **5.375** |
| Mackellar 2022 | Sophie Scamps | 38.1 | 0.0206 | 3.151 |
| Goldstein 2022 | Zoe Daniel | 34.5 | **0.0000** | 1.550 |
| North Sydney 2022 | Kylea Tink | 25.2 | **0.0000** | 1.479 |
| Kooyong 2022 | Monique Ryan | 40.3 | 0.0026 | 0.746 |
| Warringah 2019 | Zali Steggall | 43.5 | 0.0084 | 0.670 |
| Indi 2013 | Cathy McGowan | 31.2 | **0.0000** | 0.550 |
| Griffith 2022 | Max Chandler-Mather | 34.6 | 0.0116 | 0.405 |

## Why this is credible where AUC 0.87 was not

The earlier figure was measured on 21 breakouts, federal only, from a corpus
that was untracked and had no builder. It predicted **"≥20% of first
preferences"**, which is not the job.

- **The target is right.** Separating a winner the model called hopeless from a
  loser who polled ≥5% is the actual failure mode, established by the anchor
  check: the model handles sitting independents well (0.75–0.95) and fails only
  on transitions.
- **Removing the hand-added case changes nothing** — 0.838 either way. Allegra
  Spender was added at Pete's request as a seat he knows; she is flagged because
  the model already gave her 0.396 and counting her among the failures would
  flatter the signal. It did not.
- **The strict cut survives** at 0.841, p = 0.005.

## The false positives, named

| candidate | seat | % | ratio |
|---|---|---:|---:|
| Caz Heise | Cowper 2022 | 26.3 | 1.650 |
| Claire Garton | Moreton 2022 | 20.8 | 1.000 |
| Jamie Christie | Bean 2022 | 8.2 | 0.773 |
| James Mathison | Warringah 2016 | 11.4 | 0.429 |

Heise is not really a false positive — she took 26.3% and was a genuine
near-miss teal. **Mathison is the true failure mode**: the Australian Idol host,
famous without being competitive. The signal measures attention, and fame is
attention.

That error is far cheaper than the one it fixes. Lifting a seat to 10% when the
answer is 11.4% is a smaller mistake than calling a winner impossible.

## What it took to measure this, and what that means

Four measurement faults produced null results that were then interpreted as
findings — see `docs/reference/google-trends-method.md`. All four are recorded
there because **every one of them was a wrong conclusion published in this
session**, not a hypothetical:

1. "The signal doesn't transfer to the states" (AUC 0.560) — literal names,
   national geo, daily buckets.
2. "Greens wins are party-driven, not candidate-driven" — Chandler-Mather reads
   0.000 daily and 0.405 weekly.
3. "Tink won with no signal" — "Kylea Jane Tink" returns 0.000, "Kylea Tink"
   returns 1.479.
4. "The hyphen is the problem" — it is not; all four hyphen variants return
   0.000 on daily buckets.

Three of the four were caught by Pete checking Google by hand.

## Limits

- **43 usable rows, 15 winners.** Small.
- **2010 is unmeasurable**, not null: Oakeshott 0.000, Bandt 0.020, several
  unreadable. Trends volume in 2010 is too thin for a state-scoped weekly slice.
- **Federal only.** No state election has been tested with the corrected method.
- **This does not yet make the model better.** It separates two groups. Turning
  a ratio into a prior on the independent vote is a modelling step that needs
  its own pre-registration, and the mapping from ratio to vote share is not
  measured here.
- **Anchor availability is a live constraint.** 16 of 53 rows had no
  re-contesting incumbent, which is exactly the retirement case where these
  seats fall. The PM fallback is a different scale and is reported separately.

## Next

Victorian nominations close **12 noon, 9 November 2026**, and the election is
28 November. The signal is candidate-level, so it cannot be computed for
Victoria until nominations exist — 19 days out. Everything needed to run it on
the day now exists and is measured.
