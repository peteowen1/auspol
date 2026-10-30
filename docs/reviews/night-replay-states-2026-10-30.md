# Night replays for nsw2023, qld2024 and sa2026 (2026-10-30)

Why it matters: the Victorian night model had a replay for one election only. These three replays show how early each result could have been called by the same booth-by-booth update, and where it misleads.

How it was run: each harness saved its afternoon forecast (the "night state", 1,000 simulations); `scripts/night_replay_json.R` then counted booths up to each fraction of the night vote, compared them with the same booths last time, and re-simulated. Scored against the `output/published-predictions.csv` winners by `scripts/score_night_replay.R` and a small summary script (scratch only). "Fraction" is the share of each seat's night vote (ordinary + early + postal) counted. "Vote counted %" is the replay's mean over seats of the counted share of ALL votes in the booth table, which is why it stops below 100 (absent and provisional votes are never counted in the replay). The clock is INDICATIVE only: 6pm + 4 hours x fraction (the replay's own convention, not real reporting times).

## Set-up facts and caveats

- Booth tables: `scripts/build_night_booths_{nsw,qld,sa}.R` write `output/booths-<pair>.csv` (night schema) for the new and the previous election, plus `output/booths-<pair>-2cp.csv` for qld and sa. NSW has no two-candidate file, so it ran with `--tcp=0`.
- booth_type mapping from vote_type. NSW: ordinary; prepoll and ivote -> early; postal; absent; "declared institution" and "enrolment / provision" -> provisional. QLD: ordinary; prepoll -> early; "postal declaration" -> postal; "absent" and "absent early" -> absent; "in person declaration" -> provisional. SA: ordinary; early -> early; anything starting "postal" -> postal; anything containing "absent" -> absent; every other declaration vote -> provisional. These are my judgement calls, not checked against how the commissions count on the night.
- DEVIATION from the brief: `party` is not copied from `party_raw`. `classify_party()` on a bare code files "LIB", "LAB", "LNP", "NAT", "ONP" and every SA code as OTH (checked: nsw2023 and sa2026 came out essentially all OTH). So `party` holds the candidate's class from `output/candidacies.csv` (matched on pair, seat and name; 100% of rows matched in all six tables) written as a name that `classify_party()` maps back to the same class (asserted in the script). The two-candidate files get the same treatment, and their `vote_type` is rewritten to the booth_type names so the units match.
- Districts: 93/93 (nsw), 93/93 (qld), 47/47 (sa) match the published seat names; none missing. Booth sums equal the candidacies totals exactly for nsw2019, nsw2023, qld2020, qld2024 and sa2022. **sa2026 does not**: the booth file has 1,116,641 votes against 980,713 in candidacies, and 46 of 47 districts differ (largest Hurtle Vale, +5,582). Probably the booth file includes declaration votes that candidacies lacks; not verified. The sa2026 results use the booth file as it stands.
- The dump block does nothing when `AUSPOL_NIGHT_DUMP` is unset: with it set, quick_arm reported each arm byte-identical to its baseline (seat-winner log loss nsw2023 0.2050, qld2024 0.2874, sa2026 0.2508, all unchanged).
- Not in the saved state (the Victorian dump has no field for them and the shared replay does not pass them): the NSW exhaustion arm and engine setting (`AUSPOL_NSW_EXHAUST`, off in the published flags) and the QLD fallback flow sd (`AUSPOL_FALLBACK_FLOW_SD`, off). The replay matches the published configuration only while those stay off.
- 1,000 simulations per fraction, so a probability near 0.99 carries roughly +-0.003 of simulation noise.
- Seat log loss is the mean of -log(P(actual winner)), floored at 5e-4; lower is better.

Column key for every table: "winner expected seats" is the mean seat count of the party that won the most seats, with the 5th-95th percentile range; P(majority) is the chance that party holds more than half the chamber; P(largest) is the chance it holds the most seats.

## nsw2023 (ALP 45, LNP 36, IND 9, GRN 3 of 93; no party reached 47)

Table of the replay for Labor, the largest party. Seats right (higher is better), seat log loss (lower is better), Labor's expected seats, and its chance of a majority (47) and of being largest (higher means more confident, but Labor did NOT win a majority).

| fraction | vote counted % | indicative clock | seats right | seat log loss | winner expected seats (90% range) | P(majority) | P(largest) |
|---|---|---|---|---|---|---|---|
| 0.00 | 0.0 | 6:00pm | 82 of 93 | 0.205 | 46.7 (40-54) | 0.507 | 0.943 |
| 0.02 | 1.4 | 6:05pm | 84 of 93 | 0.285 | 47.0 (42-51) | 0.583 | 0.999 |
| 0.05 | 3.8 | 6:12pm | 85 of 93 | 0.188 | 47.2 (43-51) | 0.608 | 0.997 |
| 0.10 | 7.9 | 6:24pm | 84 of 93 | 0.206 | 47.3 (42-52) | 0.634 | 0.996 |
| 0.15 | 11.8 | 6:36pm | 85 of 93 | 0.180 | 47.8 (43-52) | 0.682 | 0.999 |
| 0.20 | 14.9 | 6:48pm | 86 of 93 | 0.187 | 48.4 (44-52) | 0.783 | 1.000 |
| 0.30 | 20.1 | 7:12pm | 86 of 93 | 0.214 | 49.2 (45-53) | 0.879 | 1.000 |
| 0.40 | 23.9 | 7:36pm | 86 of 93 | 0.164 | 48.2 (44-52) | 0.732 | 1.000 |
| 0.50 | 31.0 | 8:00pm | 88 of 93 | 0.126 | 47.5 (43-52) | 0.640 | 0.998 |
| 0.75 | 62.9 | 9:00pm | 90 of 93 | 0.100 | 47.0 (44-50) | 0.611 | 1.000 |
| 1.00 | 91.6 | 10:00pm | 90 of 93 | 0.077 | 46.3 (45-48) | 0.421 | 1.000 |

Call point: **no majority call exists, because Labor won 45 seats and no party reached 47** (a minority government). The model never reached 0.99 for a Labor majority, which was right, but P(majority) was 0.88 at fraction 0.30 (49.2 expected seats) and still 0.42 at the end, so it leaned toward a majority that did not happen. "Labor largest party" first reached 0.99 at fraction 0.02 (1.4% counted, indicative 6:05pm) and stayed there; at the afternoon prior it was already 0.943.

The 5 seats that moved most (afternoon to end of count). The numbers are the probability the model gave the party that actually won the seat; higher is better.

| seat | actual winner | P(winner) afternoon | at 0.10 | at 0.50 | at 0.75 | at 1.00 |
|---|---|---|---|---|---|---|
| Holsworthy | LNP | 0.190 | 0.184 | 0.305 | 0.816 | 0.984 |
| Camden | ALP | 0.266 | 0.101 | 0.547 | 0.936 | 0.987 |
| Winston Hills | LNP | 0.314 | 0.943 | 0.837 | 0.737 | 0.993 |
| Monaro | ALP | 0.385 | 0.878 | 0.838 | 0.894 | 0.978 |
| Goulburn | LNP | 0.402 | 0.470 | 0.490 | 0.910 | 0.993 |

Still wrong at the end: Pittwater (IND favoured, LNP won), Ryde (ALP favoured, LNP won), Terrigal (ALP favoured, LNP won, model gave LNP 0.475). No two-candidate count was used.

## qld2024 (LNP 52, ALP 36, OTH_RIGHT 3, GRN 1, IND 1 of 93)

Table of the replay for the LNP, the winner. P(majority) is of 47 seats; higher is more confident.

| fraction | vote counted % | indicative clock | seats right | seat log loss | winner expected seats (90% range) | P(majority) | P(largest) |
|---|---|---|---|---|---|---|---|
| 0.00 | 0.0 | 6:00pm | 82 of 93 | 0.287 | 50.2 (42-60) | 0.728 | 0.928 |
| 0.02 | 1.0 | 6:05pm | 79 of 93 | 0.464 | 43.2 (37-50) | 0.185 | 0.505 |
| 0.05 | 3.0 | 6:12pm | 83 of 93 | 0.264 | 44.6 (38-52) | 0.318 | 0.634 |
| 0.10 | 6.0 | 6:24pm | 82 of 93 | 0.276 | 44.1 (39-51) | 0.238 | 0.549 |
| 0.15 | 8.2 | 6:36pm | 82 of 93 | 0.272 | 43.1 (38-50) | 0.155 | 0.445 |
| 0.20 | 10.1 | 6:48pm | 83 of 93 | 0.247 | 43.6 (39-50) | 0.187 | 0.491 |
| 0.30 | 11.6 | 7:12pm | 83 of 93 | 0.231 | 43.9 (39-50) | 0.199 | 0.515 |
| 0.40 | 11.7 | 7:36pm | 83 of 93 | 0.232 | 43.9 (39-50) | 0.199 | 0.515 |
| 0.50 | 17.2 | 8:00pm | 87 of 93 | 0.175 | 46.3 (41-53) | 0.437 | 0.773 |
| 0.75 | 54.2 | 9:00pm | 90 of 93 | 0.071 | 50.3 (46-55) | 0.916 | 0.998 |
| 1.00 | 83.4 | 10:00pm | 90 of 93 | 0.126 | 51.2 (49-53) | 1.000 | 1.000 |

Call point: LNP majority >= 0.99 (and staying) only at fraction 1.00 (83.4% counted, indicative 10:00pm). LNP largest party >= 0.99 (staying) from fraction 0.75 (54.2% counted, indicative 9:00pm). Warning sign: the update first moved the wrong way. The afternoon forecast had the LNP on 50.2 expected seats (P(majority) 0.73); after 1% counted it fell to 43.2 (0.19) and stayed at 43-45 until fraction 0.40, then recovered (46.3 at 0.50, 50.3 at 0.75). Mean counted sits at 11.6-11.7% between fractions 0.30 and 0.40 because the early-vote units (prepoll, about 40% of the vote) are placed at random points between 0.3 and 1.0 of the way through; whether that resembles Queensland's real reporting is unverified. I did not investigate the early dip beyond noting it.

The 5 seats that moved most. Probability the model gave the actual winner; higher is better.

| seat | actual winner | P(winner) afternoon | at 0.10 | at 0.50 | at 0.75 | at 1.00 |
|---|---|---|---|---|---|---|
| Ipswich West | ALP | 0.041 | 0.809 | 0.980 | 0.987 | 0.997 |
| Bundaberg | ALP | 0.131 | 0.881 | 0.761 | 0.901 | 0.977 |
| South Brisbane | ALP | 0.040 | 0.875 | 0.949 | 0.931 | 0.886 |
| Maryborough | LNP | 0.154 | 0.279 | 0.274 | 0.908 | 0.992 |
| Capalaba | LNP | 0.164 | 0.049 | 0.127 | 0.421 | 0.989 |

Still wrong at the end: Aspley (LNP favoured, ALP won), Mirani (OTH_RIGHT favoured, LNP won), Rockhampton (ALP favoured, LNP won, model gave LNP 0.177). Two-candidate counts were ON.

## sa2026 (ALP 34, LNP 5, IND 4, ONP 4 of 47)

Table of the replay for Labor, the winner. P(majority) is of 24 seats; higher is more confident.

| fraction | vote counted % | indicative clock | seats right | seat log loss | winner expected seats (90% range) | P(majority) | P(largest) |
|---|---|---|---|---|---|---|---|
| 0.00 | 0.0 | 6:00pm | 42 of 47 | 0.251 | 32.8 (28-36) | 0.998 | 1.000 |
| 0.02 | 1.0 | 6:05pm | 44 of 47 | 0.238 | 31.8 (28-35) | 1.000 | 1.000 |
| 0.05 | 3.1 | 6:12pm | 45 of 47 | 0.228 | 33.0 (29-36) | 1.000 | 1.000 |
| 0.10 | 6.4 | 6:24pm | 45 of 47 | 0.158 | 33.5 (31-35) | 1.000 | 1.000 |
| 0.15 | 9.4 | 6:36pm | 44 of 47 | 0.145 | 34.2 (32-36) | 1.000 | 1.000 |
| 0.20 | 12.5 | 6:48pm | 45 of 47 | 0.130 | 33.6 (32-35) | 1.000 | 1.000 |
| 0.30 | 16.3 | 7:12pm | 45 of 47 | 0.129 | 33.9 (32-36) | 1.000 | 1.000 |
| 0.40 | 19.9 | 7:36pm | 45 of 47 | 0.118 | 34.0 (32-36) | 1.000 | 1.000 |
| 0.50 | 26.9 | 8:00pm | 45 of 47 | 0.114 | 34.0 (32-36) | 1.000 | 1.000 |
| 0.75 | 57.8 | 9:00pm | 46 of 47 | 0.065 | 33.3 (32-35) | 1.000 | 1.000 |
| 1.00 | 84.8 | 10:00pm | 46 of 47 | 0.065 | 33.1 (32-35) | 1.000 | 1.000 |

Call point: **the afternoon forecast already had Labor at P(majority) 0.998 and P(largest) 1.00, and both stayed at or above 0.99 at every fraction**, so the call point is fraction 0 (nothing counted, indicative 6:00pm). The count improved the seat calls (42 -> 46 of 47 right, log loss 0.251 -> 0.065) but did not change the chamber call. Caveats: the sa2026 booth file does not match the candidacies totals (above), and Finniss shows a probability of 1.003 for its winner at the end, which is above 1; I did not investigate it (unverified).

The 5 seats that moved most. Probability the model gave the actual winner; higher is better.

| seat | actual winner | P(winner) afternoon | at 0.10 | at 0.50 | at 0.75 | at 1.00 |
|---|---|---|---|---|---|---|
| Bragg | LNP | 0.207 | 0.968 | 0.998 | 0.998 | 0.998 |
| Finniss | IND | 0.262 | 0.031 | 0.045 | 0.845 | 1.003 |
| Narungga | ONP | 0.262 | 0.980 | 0.981 | 0.989 | 0.989 |
| MacKillop | ONP | 0.286 | 0.887 | 0.993 | 0.993 | 0.994 |
| Morphett | ALP | 0.811 | 0.972 | 0.921 | 0.195 | 0.140 |

Still wrong at the end: Morphett (LNP favoured, ALP won; the model moved the wrong way, 0.81 -> 0.14, between 50% and 75% of the night vote). Two-candidate counts were ON.

## Tooling notes

- `scripts/night_replay_detail.R` requires a two-candidate file, and for NSW fails after writing its JSON on a hard-coded Victorian check (`Bass`, subscript out of bounds). For nsw2023 I passed an empty header-only 2CP file; the detail JSON was written in full before the error. Shared script not changed.
- `scripts/score_night_replay.R` wrote `docs/reviews/night-replay-<pair>-{summary,seats}-2026-10-30.csv` for the three pairs.
- Replay JSON, states and detail JSON are in the session scratch folder, not in the repo.
