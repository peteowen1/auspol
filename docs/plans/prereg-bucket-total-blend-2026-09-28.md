# Pre-registration: a shrunk blend of the poll and candidate totals for the unpolled bucket

Written 2026-09-28, before running. Motivated by three refused size fixes
(`prereg-others-bucket-size`, `prereg-close-proportional`,
`prereg-bucket-total-candidates`), each failing in DIFFERENT elections: the
poll remainder is too big in 17 of 22; the candidate sum is right in
vic2022/fed2019/qld2024 and far off in sa2026/wa2025/nsw2019. Pete's rule:
partial-pool, never a cliff.

## The change

`AUSPOL_BUCKET_TOTAL=blend`: the bucket total becomes
`poll + w * (cand - poll)`, applied before the two-party anchoring exactly as
the `cand` arm was.

`w` for an election is fitted ONLY on pairs dated strictly before it, from
`output/bucket-total-history.csv` (per pair: the poll total and candidate
total the forecast would have used, and the actual bucket), by least squares
on `actual - poll = w * (cand - poll)`:

    w_hat = sum(d_c * d_a) / sum(d_c^2),   d_c = cand - poll, d_a = actual - poll
    se    = sqrt(sum(resid^2) / (n - 1)) / sqrt(sum(d_c^2))
    w     = clamp(w_hat, 0, 1) * w_hat^2 / (w_hat^2 + se^2)

With fewer than 3 earlier pairs, `se` is not estimable and `w = 0` (the
poll total). That is a floor on estimability, not a trust cliff: from 3
pairs on, `w` rises smoothly with the evidence. The earlier size correction
failed on exactly this (fed2007 trusted two points).

## Criterion, in order

1. **Primary**: statewide audit, 22 pairs, mean |bucket size error| falls by
   at least one paired SE (against v44, `AUSPOL_BUCKET_SPLIT=cand_naive`).
2. **Do no harm**: mean |miss| ALP/LNP/GRN does not rise by more than one SE.
3. **Rebuild decides**: seat log loss not above v44's 0.2881.

**Unacceptable**: any `w` fitted on a pair on or after its target (each
pair prints n and the latest pair used); a win carried by one pair.
