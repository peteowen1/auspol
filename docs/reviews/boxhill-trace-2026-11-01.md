# Box Hill vic2026: why we give Labor 0.86 and Sportsbet about 0.25 (2026-11-01)

Box Hill is the biggest seat-winner gap on the Vic 2026 Edge Board (https://claude.ai/artifact/8U33eGJMiAbpZFSW2dsfQu):
our Labor win probability 0.858 against Sportsbet's margin-free 0.251 (price 3.00), read 11:10pm Sat 31 Oct.
Trace: `AUSPOL_TRACE_SEAT="Box Hill" AUSPOL_OUT_SUFFIX=-trace Rscript scripts/fit_seats_full.R`, published configuration
of dev at 12:25am 1 Nov, fresh poll inputs (`scripts/refresh_local_poll_inputs.sh`; clone 5262153).

## Primary vote by stage (%)

| stage | ALP | LNP | GRN | ONP | other |
|---|--:|--:|--:|--:|--:|
| 2022 result | 41.35 | 35.15 | 14.13 | 0.00 | 9.38 |
| base swing (statewide levels: ALP 36.66 -> 23.88, LNP 34.48 -> 29.44, slopes 0.92 / 0.88) | 28.21 | 30.03 | 16.22 | 0.00 | 6.50 (sum 80.95) |
| One Nation allocated (10.26) and the rest scaled up to 100 | 31.27 | 33.29 | 17.98 | 10.26 | 7.19 |
| xgb trees (ALP +1.61: historic_elected +1.63, sitting party +0.53; LNP -1.00) | 32.86 | 32.29 | 18.73 | 10.07 | 6.05 |
| seat-swing port, demographic correction | 33.34 | 31.69 | 19.00 | 9.97 | 6.00 |
| final point forecast | 33.34 | 31.69 | 19.00 | 9.97 | 6.00 |

## What decides it

Labor leads narrowly on primaries and the Greens' 19.0 flows mostly to Labor, so Labor wins most simulations.

The step that matters is the One Nation fill (`AUSPOL_ONP_FILL = "prop"`). The base swing removes every class's
statewide loss in points (Labor -13.1 here), then One Nation's seat share (10.3, low because Box Hill is a weak One
Nation seat) is added and every other class is scaled up by the same factor (x1.107) to fill the gap. In a weak One
Nation seat that hands a large part of Labor's statewide loss back: Labor ends -8.0 in Box Hill against -12.8
statewide, while the Coalition ends -3.5 against -5.0. The market looks to be pricing Labor's loss as close to
uniform, which would put the Liberal ahead on primaries.

This is the mechanism `reviews/market-disagreement-vic2026-2026-10-25.md` flagged for the eastern seats (Box Hill,
Ashwood, Glen Waverley, Bentleigh, Bayswater: "unclear, leaning that the truth is between the two"), and Pete chose on
30 Oct to keep the proportional fill (DECISIONS 2026-10-30; `reviews/onp-fill-personal-vote-2026-10-30.md`,
`new-party-fill-proportional-vs-uniform-2026-10-28.md`: proportional supported over 4 elections). Nothing changed
overnight. For the morning: walk Box Hill, Ashwood and Glen Waverley with Pete on these rows; the question is
whether One Nation's gain in a weak seat comes out of Labor in proportion to Labor's size there, or mostly out of
the Coalition, as the market seems to assume.

## Follow-up 1 Nov morning: does a "middle" fill have support? (Pete: "Test a middle version")

The fill is live-only (no harness has it), so it cannot be backtested over 35 elections. Tested instead on the four
past new-party surges the 28 Oct analysis used (sa2026, qld2017, qld2024 One Nation; sa2018 SA-Best), fitting each
major's vote change on BOTH the proportional term (prev_share x new-party share / 100) and a flat term (new-party
share). Script `scripts/test_onp_fill_blend.R`; source `output/published-predictions.csv` (19,616 rows, 35 pairs).

| major | pooled proportional b (SE) | pooled flat b (SE) | n |
|---|---|---|---|
| ALP | -0.97 (0.13) | +0.09 (0.06) | 256 |
| LNP | -1.07 (0.16) | +0.21 (0.08) | 256 |

A proportional coefficient of -1 is exactly the shipped fill; a 50/50 blend with uniform would sit near -0.5,
about 3.6 SE from Labor's estimate. The flat term has the wrong sign for a middle version. Per election, only
sa2026 Labor leans the bookmakers' way (flat -0.27, SE 0.15). Verdict: the record supports the proportional fill;
no middle version built. The Box Hill gap stays a known disagreement with the market, flagged on the Edge Board.
