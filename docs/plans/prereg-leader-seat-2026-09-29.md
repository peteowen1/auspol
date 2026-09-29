# Pre-registration: leader's own-seat bonus (`AUSPOL_LEADER_SEAT=1`)

Written 2026-09-29 23:35, before the rebuild. Pete's theory test, then his
questions: does it differ by party, and for a sitting premier against a
challenger?

## Evidence that prompted it (v51, all elections, so NOT time-forward)

Seat-specific miss of a leader's own party in the leader's seat (actual minus
ours, less that party's median miss that election): +2.75 points (SE 0.64,
34 of 44 positive) for Labor and Coalition leaders. By role: head of
government +3.36 (SE 0.67, n 22), opposition leader +2.14 (SE 1.10, n 22),
minor-party leader +4.64 (SE 3.37, n 8), Nationals leaders +1.2 (n 3, left
out). Kogarah 2023 (Minns) +9.9 was the prompt. General candidate
over-performance does NOT persist once the model has run (slope 0.009, SE
0.021, 1,370 repeat candidacies), so no separate candidate term.

## The change

`R/leader_seat.R`. Leaders and seats from each election article's infobox
(`scripts/fetch_leaders.R`, raw wikitext kept). Bonus per role (gov, opp,
minor), fitted on leader seats of elections BEFORE the target against the
as-at `xgb_pred_seat` in `output/forecasts.csv`; each role partially pooled
toward the pooled mean (method-of-moments tau^2), the pooled mean shrunk
toward 0. Added to the leader's class in the leader's seat, row rescaled to
its total. After the seat-poll blend and demographic step in all six
harnesses; wired into live `fit_seats_full.R` and the shipped tables
(`leader-seat-vic2026.csv`: Carroll/Niddrie, Wilson/Kew, Sandell/Melbourne,
+2.33 each).

## Measurement (rebuild X, leader bonus only, against fresh v51 = rebuild R2)

1. **Primary (targeted): absolute error of the leader's own-party primary in
   leader seats**, all scored elections, paired by seat. Must improve by more
   than 1 SE.
2. **Guard: primary RMSE over all rows** of the share-detail files must not
   worsen by more than 1 SE (clustered on seat-election).
3. **Guard: pooled seat log loss** (`compare_rebuilds.R` CR2) must not
   worsen by more than 1 SE.
4. Reported: AEF-7 ledger; Kogarah, Epping, Grayndler, Mulgrave; bonus per
   role per target.
5. Unacceptable: any non-leader seat moving by more than rescaling noise
   (rows move only in leader seats).

Ships with the demographic correction (passed today) in one combined rebuild
and publish.
