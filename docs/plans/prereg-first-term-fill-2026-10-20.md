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
