# Real-night replay of fed2022 and fed2025 from the AEC's archived feed (2026-10-31)

Run 30 Oct 9:49pm-11:03pm, `scripts/night_replay_feed.R` at 20,000 sims, state dumps from
`backtest_candidate_fed.R` (`AUSPOL_NIGHT_DUMP`). At each Canberra clock time the model sees exactly
the polling places the AEC had published first preferences for by then
(`output/night-feed/booth-returns-fed<year>.csv`), and two-candidate counts only where the pair on
screen was the final pair. Outputs: `output/night-feed/replay/fed<year>-<label>-{summary,seats}.csv`
(gitignored; copied from the session scratch queue).

- **base** = as shipped (surge keeps firing after the count, 2CP flows centred on the mean draw, flow sd floor 0.01).
- **fixes** = `--surge-fade=1 --tcp-center=median --tcp-flow-floor=0.065` (NRF1 confirms all three applied).

Simplifications (as the script header): a reported place carries its final count, not its first-night
figure; declaration votes are never counted; a 2CP count is used only when the on-screen pair equals
the night's last pair.

## Call times (Canberra = Sydney time on both nights; a call = P >= 0.99 and stays there)

| call | fed2022 base | fed2022 fixes | fed2025 base | fed2025 fixes |
|---|---|---|---|---|
| Labor majority | never (peaks 0.79) | never (peaks 0.84) | 7:30pm, 8% counted | 7:30pm, 8% counted |
| Labor largest party | 8:15pm, 30% | 8:00pm, 24% | 7:00pm, 1.5% | 7:00pm, 1.5% |
| Wentworth independent | never (0.33 from 7:45pm) | 7:45pm at 20% counted (holds from 8:45pm) | 8:00pm | 7:15pm, 4% counted |

Labor won 77 of 151 in 2022 (majority by one seat). Never reaching 0.99 on night ordinary votes is
the right answer: the AEC itself did not confirm the majority for days.

## End of night (3am Canberra, ~77% / 73% counted): seats wrong (credited winner <= 0.5)

| | fed2022 | fed2025 |
|---|---|---|
| base | 4 of 151: Deakin, Lyons (0.50 tie), Mackellar, Wentworth | 7 of 150: Bullwinkel, Fowler, Melbourne, Bradfield, Curtin, Kooyong, Monash |
| fixes | 1 of 151: Deakin (Liberal by 0.2% after declaration votes) | 4 of 150: Bullwinkel, Melbourne, Goldstein, Monash |

Seat-winner log loss at 3am (lower is better): fed2022 0.0696 -> 0.0358, fed2025 0.1697 -> 0.1201.
At 6pm the two arms are identical (0.2136 / 0.3652), as they must be with nothing counted.

Still wrong with the fixes: Melbourne 2025 (Labor won on Liberal preferences; the model's 2CP pair is
Greens v Labor and gives Labor 0.00) and Monash 2025 (independent 0.99, Liberal won) are both the
"draw with a different final pair is never corrected" defect already open in NEXT-STEPS.
