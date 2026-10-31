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

## Addendum, 31 Oct evening: the per-fix split, and the surge mixture off

Victoria 2022 replayed from the VEC's own hourly snapshots (`scripts/night_replay_vec.R`, the live conversion path).
Night-average seat log loss over every replay time with something counted (lower is better; 20k sims):

| arm | fed2022 | fed2025 | vic2022 |
|---|---|---|---|
| as shipped before 31 Oct | 0.1071 | 0.1897 | 0.0712 |
| surge on, fade only | 0.0848 | 0.1685 | 0.0614 |
| surge on, fade + median | 0.0783 | 0.1566 | 0.0713 |
| surge on, all three (0.065 floor) | 0.0790 | 0.1574 | 0.0766 |
| **surge OFF, fade** | 0.0747 | 0.1417 | 0.0639 |
| **surge OFF, fade + median** (shipped) | 0.0745 | 0.1420 | 0.0631 |

- The 0.065 floor never helped: back to 0.01. With the surge on, the median helped federal and hurt Victoria
  (Mildura, Mornington, Hawthorn 7-10pm), because it was compensating for the surge draws.
- With the surge mixture off (`plans/prereg-surge-off-2026-10-31.md`) the median makes at most 0.001 of difference on
  any night. It stays on: neutral here, and it protects against any future outlying minority of draws.
- Wentworth 2022, surge off, mean centre: 0.37 in the afternoon, 0.90 at 7:15pm, 0.99 at 7:45pm, and it holds.
- vic2022 surge off: afternoon 0.2643 -> 0.2423; at 8pm 0.1257 against 0.1038 for surge-on fade-only; 87 of 88 right
  from 9pm (Bass the miss). Fix 2 (each draw's flow from its own primaries) is no longer needed for Wentworth.

## Addendum 2, 31 Oct evening: fix 2 (each draw's flow from its own primaries) and why it needs flow uncertainty

Built as `night_apply_tcp(own_fp = TRUE)` / `night_run_update(tcp_own_fp = TRUE)` (off by default). Surge off,
fade + median, floor 0.01: fed2025 0.1420 -> 0.1447 night average (end 0.1126 -> 0.1223), worse. Cowper fed2025 at
3am, Nationals' win (they held): 0.706 -> 0.274. Traced: the draws' own primaries average the count exactly (IND 31.9,
LNP 37.3) and so do their implied flows (0.66), but with `AUSPOL_FLOW_SD = 0` every draw's OWN implied flow is
identical, so the prior flow sd is the 0.01 floor and a counted flow of 0.54 (se 0.02) moves the prior only to
~0.64: posterior IND share 0.506, IND win 0.73. With the counted primaries, the draws' implied flows scatter (their
primaries differ from the count), which the update reads as flow uncertainty, so the count dominates: 0.495, IND
0.29. Right answer for the wrong reason. Fix 2 is correct only with an honest flow uncertainty: the measured 0.065
floor (arm running) or flow noise in the seat simulation (`plans/prereg-flow-sd-2026-10-31.md`).
