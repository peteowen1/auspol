# Prereg: fill the first-term-member flag from our own corpus (AUSPOL_SEAT_CONTEXT_SOPH)

Written 2026-10-20, before any rebuild. Code at 375ccd5.

## Why

`soph_cand` (the sitting member first won the seat at the previous election) reaches the trees only from the
anchor's seat file, which has it for 10 of 35 elections. In the other 25 it is blank, and the trees cannot tell a
first-term member from a long-serving one. In those 25, 379 first-term members stood again, and the published
forecast under-calls them by +1.24 points (SE 0.28). Where the flag exists, first-term members still beat
longer-serving ones in the same election by +1.84 (Labor, SE 0.81, 8 of 10 elections positive) and about +1.5
(Coalition, 9 of 9).

`scripts/build_seat_context.R` derives it from `output/candidacies.csv` plus `byelection-winners.csv` (41 rows added
today from the Wikipedia lists). Agreement with the seat file where both exist: 97.3% over 913 seats; the remaining
disagreements are mostly definitional (the seat file follows the person: Epping 2023 Perrottet, Waite 2022). The
arm fills blanks only; seat-file values are never replaced.

## Two rebuilds (isolated copies at 375ccd5, from stage 3, 20,000 sims)

- **Baseline**: the refreshed `seat-context.csv` (now built at stage 3; the old one was stale at 24 of 35
  elections, so the shipped incumbent/retiring fill missed 11), `AUSPOL_SEAT_CONTEXT_SOPH=0`.
- **Arm**: the same, `AUSPOL_SEAT_CONTEXT_SOPH=1`.

The baseline is also compared with the live published predictions (19 Oct), REPORTED, not voted: it measures the
stale-file fix, which is a repair of a shipped feature and goes out with the next publish either way. Any election
worse by more than 2 SE there is reported to Pete.

## Criterion (the standard rule)

Targets, named in advance from the data, not from predictions: seats in the 25 filled elections where the seat file
has no flag and our flag says a first-term member is standing again (`same_mp_i == 1`): 379 seats in 18 elections,
listed in `docs/plans/first-term-targets-2026-10-20.csv`, scored with `scripts/score_contest_feats.R <base> <arm>
1e-6 docs/plans/first-term-targets-2026-10-20.csv` (dry run, self against self: 379 found, change 0). Seat-winner
log loss, lower is better, SE clustered on election:

1. Target seats better by more than 1 SE.
2. All seats not worse by more than 1 SE.
3. Leave-one-election-out holds on the primary.
4. No election worse by more than 2 SE of its own seats.
5. Without the two largest-gain seats the target change keeps its sign.

Reported, not voted: primary-vote miss on first-term members (mean and RMSE, by filled vs seat-file elections);
the 1e-4 floor; AEF-7.

## Named in advance: what would make a win unacceptable

(a) The gain lives only at the 1e-6 floor.
(b) The arm moves the 10 seat-file elections' first-term members the WRONG way (their mean miss grows): the fill
    would then be teaching the trees something the seat-file flag contradicts.
(c) Live vic2026 reads the seat file's own flag, so the live forecast changes only through the retrained model:
    diff the live forecast with and without; any favourite change goes to Pete.

Shipping is Pete's call on the result.

## RESULT (2026-10-20): REFUSED on clauses 1 and 3

Two isolated stage-3 rebuilds at 20k from 1e93959 (`deciding-runs/first-term-rebuilds/`). The arm's own pipeline
stopped at its stability check (SPZ3: the error-quantile and composition tables moved again after the stage 6-7
rerun, rows fed2022 onward only; the baseline's did not), so its predictions were written by running stage 8 alone on
the second pass's outputs. Caveat: the arm's stage 6 read tables one refit behind its final ones.

Fill applied: 8,285 rows in 18 elections (SCS). Seat-winner log loss change, lower is better:

| clause | floor 1e-6 | floor 1e-4 | verdict |
|---|---|---|---|
| 1 primary, 379 named first-term seats in 18 elections | +0.0001 (SE 0.0009) | +0.0001 (SE 0.0009) | within 1 SE: FAIL |
| 2 guard, all 2,931 seats | +0.0007 (SE 0.0016) | -0.0009 (SE 0.0004) | PASS |
| 3 leave-one-election-out | 0 of 18 | 0 of 18 | FAIL |
| 4 elections worse by more than 2 SE | 0 | 0 | PASS |

(The 1e-6 guard carries nsw2019 Barwon, a floor seat that moves in every arm: +0.048 for that election alone.)

Primary vote, first-term members standing again, mean miss (actual minus forecast) and RMSE in points: filled
elections (378) +1.16 -> +1.05, RMSE 5.503 -> 5.498; seat-file elections (194) +0.63 -> +0.51 (named-in-advance (b):
not the wrong way). The trees barely use the flag: a ~1-point under-call on members who mostly hold their seats moves
no seat calls. The base_pred version was already refused on 2026-09-28 (sitting-member shift, member stands +1.14:
no seat gain, RMSE worse; `prereg-sitting-member-baseline-2026-09-28.md`). Switch stays "0".

### The baseline against the published predictions (reported, not voted)

The baseline differs from the 19 Oct publish only by the refreshed `seat-context.csv` (built in the pipeline from
today; the old file was stale at 24 of 35 elections). Pooled seat log loss 0.3256 -> 0.3270 (+0.0014, SE 0.0014).
The 11 newly filled elections -0.0073 (SE 0.0040, 664 seats); the other 24 +0.0040 (SE 0.0012, 2,267 seats), whose
seat-context values are byte-identical old vs new (0 incumbent or retiring changes), so their loss is the retrained
trees learning from the 11. No election worse by more than 2 SE. Goes to Pete: it ships with the next publish.
