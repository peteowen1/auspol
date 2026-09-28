# Pre-registration: set the unpolled bucket's TOTAL from the per-candidate model

Written 2026-09-28, before running.

## Why

After v44 the bucket is split by the per-candidate model but its total is
still `100 - polled parties`, too big in 17 of 22 elections (mean |size
error| 2.01; nsw2023 +2.88). That excess comes out of the majors' first
preferences: nsw2023 Labor primary -4.83 while its two-party miss was only
+2.25, and five of v44's worst 12 seats against AEF are nsw2023 Labor wins.
The statewide two-party spread itself is calibrated (misses in sd units:
sd 1.04, 1 of 22 beyond 2 sd), so heavier tails are not the fix. The
candidate model's summed class shares were the closest predictor of group
totals (mean |error| 1.115 vs 1.506 current).

## The change

`AUSPOL_BUCKET_TOTAL=cand`: in `statewide_draws_as_at()`, before the
two-party anchoring, the bucket (OTH plus folded classes) is rescaled with
`others_bucket_apply()` so its mean equals the sum of the candidate model's
predicted shares for the bucket classes (`candidate_bucket_ratio`'s source
file, `pred_naive`, time-forward); the removed or added share goes to the
polled classes in proportion, and the anchoring then rebalances Labor and
Coalition to the two-party target. A pair with a bucket class lacking a
prediction keeps today's total, printed. Run with `AUSPOL_BUCKET_SPLIT=cand_naive`
(v44) in both arms. The federal harness builds its statewide through the
same `statewide_draws_as_at()`, so it is covered.

## Criterion, in order

1. **Primary**: statewide audit, 22 pairs, mean |bucket size error| falls by
   at least one paired SE.
2. **Do no harm**: mean |miss| ALP/LNP/GRN does not rise by more than one
   paired SE.
3. **Rebuild decides**: seat log loss not above v44's 0.2881.

**Unacceptable**: a win carried by one pair (largest mover removed is
reported); any bucket total read from a prediction that saw its election.
