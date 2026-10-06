# Sophomore surge: do non-major sitting members gain at their first re-election, and is the model under-calling them? (2026-10-06)

Measurement only. Nothing in `R/`, `scripts/` or `output/` was edited; no harness, rebuild or fit was run.
Scripts and raw printouts are in the session scratchpad `...\scratchpad\sophomore\` (`pop.R` builds the
population, `an3.R` the tables below, `tf.R` the time-forward test; `an3.out`, `tf` output). Companion to
`docs/reviews/byelection-level-2026-10-05.md` (the L1 level for by-election winners).

## Answer first

- **No separable sophomore effect once by-election winners are set aside.** The model's signed error (actual
  class share minus `xgb_pred`) on non-Green first re-elections is **+2.2 (SE 2.1, n = 18)** against **-1.7
  (SE 1.3, n = 28)** for later re-elections. Difference **+3.8, SE 2.5 (Welch p = 0.13; SE 2.7 when
  bootstrapped over members)**. Drop the four by-election winners and it falls to **+1.2 (SE 2.2, n = 14 v
  27, p = 0.59)**. So the visible gap is the by-election-level problem already queued (Orange, Wagga, Lyne),
  not a first-re-election effect.
- **The raw vote does rise on a first re-election, weakly.** Non-Green members elected at a general election:
  next share minus prior share **+3.1 points (SE 1.8, n = 15) first v -0.9 (SE 1.5, n = 30) later**;
  difference 4.1, SE 2.3 (p = 0.09; member-bootstrap SE 2.0). Ratio next/prior 1.125 v 0.972, difference
  0.153 (SE 0.074, p = 0.05). About two SEs at n = 15 v 30, not a clean result.
- **The model already absorbs most of it.** `base_pred` (before xgb) under-calls non-Green first
  re-elections by **+7.7 (SE 1.7)** against **+2.2 (SE 1.3)** for later ones, difference 5.5 (about 2.5 SEs).
  After xgb the gap is 3.8 and not separable. So the sophomore pattern exists in the base layer and the xgb
  layer corrects it.
- **A shrunk time-forward adjustment makes things worse**, so none is proposed (section 4): squared error
  rises on 15 scored rows (RMSE 7.7 to 9.7; paired mean change +35 squared points, SE 34).
- **The four named rows are not sophomore effects.** Stuart (Brock) is a member who moved seats; Kavel
  (Cregan) is a major-party defector; Hinchinbrook (Dametto) cannot be classified from the corpus; Orange
  (Donato) is a by-election winner with no general-election share. Section 3.

## 1. Population

Rule. A member counts when `output/candidacies.csv` has them `elected` at the previous general election in a
non-major class (IND, OTH, OTH_RIGHT, ONP; GRN kept apart), or when `byelection_winner_rows(prev, t)` names
them as the winner of a by-election in the window (the by-election winner replaces the general-election member
in that seat, as in `candidate_returns()`). They are matched to the same seat at election t (renamed seats
through `seat_rename_map()`) by `match_key(rule = "person")` plus `align_person_keys()`. Standing again is the
condition, so members who retired are absent and the population is conditioned on re-contesting. Class at t
can differ from class at t-1 (Butler, Dalton, Donato, Katter).

**First re-election** = the first general election after the member won the seat, by any route. For a general
election winner at t-1 it means: not elected in that seat at t-2 AND not a by-election winner in the window
(t-2, t-1) (this is why Donato at nsw2023 is "later", although he first won the seat as a by-election winner
in 2016). For a by-election winner it means not elected in that seat at t-1. **"Unknown"**: the corpus starts
at fed2004, nsw2015, qld2017, sa2018, vic2010 (no `elected` flags) and wa1996, so for a t-1 election that is
the first in the corpus there is no t-2 to look at. 19 rows are unknown and are kept out of the first/later
comparison; the `historic_elected` column cannot fill the gap (it reads FALSE for Donato at nsw2019 although
he had held the seat since 2016, and for Dametto at qld2017).

Table: member-election pairs where the member's PRIOR is a general-election share. "Prior" and "next" are the
member's own first-preference share at t-1 and t, in points. "Change" is next minus prior and "ratio" is next
divided by prior; the SE is the standard deviation divided by the square root of n. Higher change means more
vote gained on re-election. Rows repeat members (Katter, Wilkie, Bandt), so SEs are understated.

| Group | Re-election | n | Members | Mean prior | Mean next | Mean change | Median change | SE change | Mean ratio | Median ratio |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| Non-Green | first | 15 | 15 | 33.9 | 37.1 | +3.15 | +2.77 | 1.76 | 1.125 | 1.094 |
| Non-Green | later | 30 | 19 | 41.9 | 41.0 | -0.95 | -0.41 | 1.50 | 0.972 | 0.991 |
| Non-Green | unknown | 13 | 13 | 44.0 | 45.2 | +1.15 | +4.45 | 3.87 | 1.112 | 1.081 |
| Green | first | 6 | 6 | 34.4 | 34.7 | +0.32 | -1.29 | 1.67 | 1.004 | 0.955 |
| Green | later | 9 | 6 | 41.3 | 42.1 | +0.79 | +0.55 | 2.14 | 1.034 | 1.013 |
| Green | unknown | 6 | 6 | 34.0 | 38.1 | +4.13 | +4.00 | 2.23 | 1.148 | 1.138 |

Greens show no first-re-election gain (first - later change -0.5, SE 2.7 to 3.0, n = 6 v 9).

Table: the non-Green split by jurisdiction. Same columns; federal n = 25, state n = 20 (unknown excluded).

| Jurisdiction | Re-election | n | Members | Mean change | Median change | SE change | Mean ratio |
|---|---|--:|--:|--:|--:|--:|--:|
| Federal | first | 10 | 10 | +2.73 | +2.07 | 2.03 | 1.117 |
| Federal | later | 15 | 6 | +0.25 | +0.74 | 1.70 | 1.017 |
| State | first | 5 | 5 | +3.98 | +3.66 | 3.70 | 1.140 |
| State | later | 15 | 13 | -2.14 | -0.70 | 2.50 | 0.927 |

By state: NSW first n = 2 (Butler, Dalton, +11.7 each, class change from OTH_RIGHT to IND), SA first n = 1
(Brock, -8.2), VIC first n = 1 (Cupper, +1.1), WA first n = 1 (Woollard, +3.7), QLD none classifiable. Too thin
to read.

Table: by-election winners (prior = the by-election share, which the earlier review showed carries no
information about the next share). Points; "next" is the member's own share at the next general election.

| Election | Seat | Member | First re-election | By-election % | Next % | Change |
|---|---|---|---|--:|--:|--:|
| fed2010 | Lyne | Oakeshott | yes | 63.8 | 47.2 | -16.7 |
| nsw2019 | Orange | Donato | yes | 23.8 | 49.1 | +25.4 |
| nsw2019 | Wagga Wagga | McGirr | yes | 25.4 | 44.6 | +19.2 |
| fed2019 | Wentworth | Phelps | yes | 29.2 | 32.4 | +3.2 |
| fed2019 | Mayo | Sharkie | no (general winner 2016) | 44.4 | 34.2 | -10.2 |

## 2. Error of the published model on these rows

Source: `output/forecasts.csv` (built 2026-10-06 00:42, the as-at table; 76 of 84 population rows join, the
other 8 are at elections before the first forecast cutoff: wa2001 to wa2008, fed2007). Joined on election,
seat and the member's class at t; the `candidate` field contains the member's surname on all 76 rows.

**Caveat on what a row is.** `forecasts.csv` scores the CLASS row (all candidates of that class in the seat),
not the member alone. First re-election rows have more class-mates (mean 1.9 candidates per class row v 1.4),
which pushes `actual_share` up by itself. The single-candidate rows below remove that.

Table: signed error, actual class share minus the model's `xgb_pred`, in points. Positive means the model
under-called; closer to zero is better. SE = sd / sqrt(n). "Base" is the same error against `base_pred`
(before xgb). n is rows; members is distinct people.

| Group | Re-election | n | Members | Mean error xgb | SE | Mean error base | SE |
|---|---|--:|--:|--:|--:|--:|--:|
| Non-Green | first | 18 | 18 | +2.16 | 2.08 | +7.70 | 1.72 |
| Non-Green | later | 28 | 19 | -1.66 | 1.31 | +2.20 | 1.32 |
| Non-Green | unknown | 9 | 9 | +7.21 | 2.43 | +8.65 | 2.51 |
| Green | first | 6 | 6 | -2.53 | 2.72 | +1.05 | 2.17 |
| Green | later | 9 | 6 | -1.10 | 2.01 | +1.78 | 1.96 |
| Green | unknown | 6 | 6 | +3.82 | 2.21 | +4.72 | 2.22 |

Table: tests of first minus later on the xgb error (points). SEs: Welch, and a bootstrap that resamples whole
members (4,000 draws), which is the one to use because members repeat.

| Population | n first | n later | Difference | Welch SE | p | Member-bootstrap SE |
|---|--:|--:|--:|--:|--:|--:|
| Non-Green, all | 18 | 28 | +3.82 | 2.46 | 0.13 | 2.74 |
| Non-Green, general-election priors only | 14 | 27 | +1.22 | 2.21 | 0.59 | not run |
| Non-Green + Green | 24 | 37 | +2.51 | 2.04 | 0.23 | 2.26 |
| Non-Green, one candidate in the class | 8 | 19 | +3.27 | 3.07 (by hand) | not run | not run |

By jurisdiction (non-Green xgb error): federal first -0.01 (SE 2.48, n = 12) v later +1.14 (SE 1.49, n = 16);
state first +6.49 (SE 3.39, n = 6) v later -5.40 (SE 1.90, n = 12). The state row looks large (diff 11.9) but
six first rows include Orange, Wagga and Dametto-like by-election and thin-history cases, and the later state
rows are dragged by Shepparton (-13.3), Alfred Cove (-11.3), Hill (-10.4), Traeger (-10.8) and Narungga
(-13.8), which are members who lost vote on re-election. It is not separable and not interpretable.

The pattern over time, not tested: first re-elections were under-called before 2022 (Wilkie fed2013 +16.4,
Bandt fed2013 +8.9, Oakeshott, Donato, McGirr) and over-called at fed2025 (Curtin -6.8, Goldstein -6.1,
Kooyong -5.4, Mackellar -9.8, Wentworth -5.1; those five average -6.6). xgb is trained on the
earlier years' under-call and applies the correction to the 2025 teals, where the first re-election gain did
not arrive (members' own change at fed2025: Curtin +2.8, Fowler +4.0, Kooyong -6.4, Scamps -0.1, Spender
+0.7, Daniel -3.8). That is the opposite of a stable first-re-election effect.

Context. Other non-major class rows with a named candidate that are not a re-contesting sitting member:
n = 5,843, mean signed error -0.15 (SE 0.05); among those with actual share 15 or more (n = 473) +4.9. The
second figure is selection on the outcome and is not a comparison, listed only so nobody quotes it as one.

## 3. The four named rows

Table: the four worst remaining rows. Points; error = actual minus `xgb_pred`.

| Row | What the member is | In the sophomore population? | xgb | Actual | Error |
|---|---|---|--:|--:|--:|
| sa2022 Stuart, Brock | sitting member who MOVED seat (Frome to Stuart, held 45.97 in Frome at sa2018) | no, moved seat; found by a cross-seat person match, 1 of 2 movers | 25.1 | 48.5 | +23.3 |
| sa2022 Kavel, Cregan | LNP member (48.1 at sa2018) who left the party and stood as IND | no, was elected in a major class; found as a defector, 1 of 15 | 27.8 | 50.5 | +22.6 |
| qld2020 Hinchinbrook, Dametto | first-term KAP member elected at qld2017 (20.9) | yes, first-vs-later unknown from the corpus (qld2017 is the first QLD election in it) | 21.8 | 43.9 | +22.0 |
| nsw2019 Orange, Donato | by-election winner (2016), first general election | yes, by-election entry, first re-election | 34.5 | 56.2 | +21.7 |

Dametto: the model's 21.8 is almost exactly his 20.9 at qld2017, so the model carried his old share and gave
the seat no first-term gain; he went to 42.5 (class row 43.9 with a second candidate). Whether the corpus says
"first" depends on a qld2015 result that is not in it; I did not look up whether he first won the seat in 2017
(Pete's brief says first-term; unconfirmed in the data). Donato: no general-election share, the model's 34.5
is a class-row level driven by the by-election share, the case the L1 level was fitted for.

Movers and defectors, for completeness. Defectors from a major (15 rows with forecasts): mean error -1.3
(SE not computed), no systematic sign; the big ones are Cregan +22.6, Duluk +9.3, Ward +8.2 against Johnson
(Ryan, fed2010) -22.2 and McBride -16.1. The two seat movers are Brock (+23.3) and Bedford (Florey to
Newland, -0.9). Two rows do not make a mover effect.

## 4. Proposal, and why none

**None proposed. No separable first-re-election effect at n = 18 v 28 (xgb error), and the part that looks
like one comes from the four by-election winners, which the L1 level already addresses.**

What I tested anyway, so the negative is from the strongest version available here: the one shrunk,
time-forward adjustment that fits the shape of the finding, a flat additive term on the xgb prediction for
non-Green first re-elections. For each scored row, the training set is every first-re-election row at an
earlier election date (same-day rows excluded, at least 3), the adjustment is the mean training error shrunk
toward zero by w = tau^2 / (tau^2 + s^2/n), with tau^2 = max(0, m^2 - s^2/n).

Table: effect of that adjustment on squared error, scored rows only (15 with by-election winners, 10 without).
RMSE in points, lower is better; the change is new minus old squared error, positive means worse.

| Rows | n scored | RMSE before | RMSE after | Mean change in squared error | SE |
|---|--:|--:|--:|--:|--:|
| First re-elections incl. by-election winners | 15 | 7.68 | 9.71 | +35.3 | 34.2 |
| First re-elections, general-election priors only | 10 | 5.17 | 7.47 | +29.0 | 10.3 |

It fails because of fed2025: the training mean (about +5 to +7) is set by the 2010 to 2019 rows and then added
to six teal rows that were already over-called. The shrinkage weight stayed 0.6 to 0.9 because the training
rows agreed with each other, which is the problem: the effect is a pre-2022 regularity.

Worked examples, for what the adjustment would do. Donato (first, by-election entry): training mean 11.4 over 3
rows, w 0.83, adjustment +9.5; 34.5 becomes 44.0 against actual 56.2, error 21.7 to 12.2. Dametto (corpus first
flag unknown, so the adjustment would not be applied under the rule as built; if it were tagged first, the
training rows are the six first re-elections before qld2020, four of them by-election winners; the adjustment
would be roughly +10 to +12 by comparison with the neighbouring rows (Wentworth's fed2019 fit, 5 rows, mean
+13.2, w 0.94, was +12.3), so 21.8 becomes about 33 against 43.9, error 22.0 to about 11; not computed
exactly). Both gains come from by-election-winner training rows, which is the L1 problem again: the correct fix for Donato is the pooled level (about 41 for the own share
plus class-mates, `byelection-level-2026-10-05.md`), not a sophomore flag. Not built.

If Pete wants this revisited, the one test worth running is whether the 2025 teals' lack of gain is real
(six rows at one election, one correlated event: the 2025 federal swing) or a model fault. That is a
fed2025-only question, not a population one.

## 5. Not confirmed, and where I looked

- **"First" for 19 rows is unknown from the corpus** (everything whose t-1 election is the first one held for
  that region, including Dametto, Greenwich, Piper, Sheed, Knuth, Katter R., Bolton, Andrew, Bell and the
  state-level Greens). I did not use outside knowledge to fill them. Their error is +7.2 (SE 2.4, n = 9) for
  non-Green, the largest of any group; if most are in fact first re-elections that would change the answer
  (the group is 6 state seats at qld2020/nsw2019/sa2022, where xgb has the fewest training pairs). **This is
  the main open item: a hand-checked first-elected year for these 19 would settle it.** I did not do it.
- **Class-row contamination.** The error is on the class row, not the member's own share (section 2 caveat).
  Single-candidate rows give first +0.28 (SE 2.68, n = 8) v later -2.99 (SE 1.48, n = 19); the first-v-later
  difference there (3.3) was computed by hand and has no test.
- **Member repeats.** Members appear up to 5 times; Welch SEs are understated. The member bootstrap was run on
  the headline rows only (2.74 and 2.26); other SEs are plain.
- **Defector and mover coverage.** Detection is by person key plus class or seat change; Kavel was found, but I
  did not audit for missed ones (class changes within the same non-major bucket are invisible).
- **By-election winners without results rows** (Northcote 2017, Fremantle 2009 and others, logged as BYW1! when
  the script ran) are absent. Same limit as the earlier review.
- **Time-forward test is on 15 rows** with one election (fed2025, 6 rows) dominating; the sign of the result
  is robust to dropping by-election winners but the size is not.
- **Forecasts vintage.** `forecasts.csv` built 2026-10-06 00:42; I did not check whether it differs from the
  2026-10-05 build quoted in the by-election review.
- Greens are in the population table and error table but are not part of the answer.
