# Pre-registration: One Nation preference keys from the history rate, not the per-seat trees (2026-11-24)

Written and committed BEFORE any arm is run. Pete chose "Build targeted fix today" (24 Nov, 7:45am).

## What was found

The per-seat flow model (`xgb_flow_conditional_override_for()`, `R/xgb_flow_override.R`) predicts every
(from | survivors -> to) split for every seat. In contests that include One Nation it leans toward One Nation
against both the history and the cards. Live vic2026 night state, median over 88 seats:

| Key (who is distributed, between whom) | per-seat model | pooled table | measured, earlier elections |
|---|---|---|---|
| Labor between Liberal and One Nation, % to Liberal | 55.1 | 65.5 | 63.4 (6 rows; sa2026 71.5 on 2) |
| Liberal between Labor and One Nation, % to Labor | 26.1 | 31.8 | 32.4 (14 rows, 11 sa2026) |
| Greens between Labor and One Nation, % to Labor | 70.9 | 80.4 | 79.9 (12 rows, all sa2026) |

Labor's registered Ripon card numbers One Nation 12th of 12, the Liberals 8th and 9th.

Sizing (not an arm): the whole flow model off moves vic2026 One Nation 14.9 -> 9.7 expected seats and is WORSE on
sa2026/qld2024/fed2025 (seat log loss +0.0078, SE 0.0062). So the trees earn their place overall; the question is only
the One Nation keys, where training rows are few (6 to 14 per key).

## Arms (one switch, `AUSPOL_ONP_FLOW_KEYS`, default "0" = today's behaviour, byte-identical)

- **A `cond`**: every key whose survivors include One Nation takes the history rate the trees are built on
  (`key_rates$cond_rate`: time-forward, earlier elections only, recency half-life `AUSPOL_FLOW_RATE_HL`) instead of the
  per-seat prediction.
- **B `cond2`**: the same, only for keys with exactly two survivors, one of them One Nation (the final-count splits).

Both act in the one shared function, so all harnesses and the published forecast get it with no per-harness edit.

## Measurement

`scripts/quick_arm.R "AUSPOL_ONP_FLOW_KEYS=<arm>" --pairs=all` at 1,000 simulations, baseline = shipped config.

- **Primary:** pooled seat-winner log loss over every scored election, SE clustered on election.
- **Ship rule:** primary better by more than 1 SE, and leave-one-election-out: the pooled change stays negative with
  any single election removed.
- **Unacceptable even if the primary passes:** sa2026 worse (the one election where One Nation won seats and the
  splits were measured), or vic2026's three keys landing outside 50-85% to the non-One-Nation side.
- **If A and B both pass:** ship the one with the lower pooled log loss; if within 1 SE of each other, B (it changes less).
- **If neither passes:** no change before 28 Nov; tell Pete in a message, and the post carries the 10-15 seat range.

## Limits, stated now

- 1,000 sims floors winner probabilities at 0.0005; a far-tail change is invisible (CLAUDE.md quick_arm limit).
- No 20,000-sim deciding run before 28 Nov (time); the screen decides, Pete's call if it is close.

## RESULT (24 Nov 8:40am): both arms REFUSED. Live model unchanged.

`quick_arm.R --pairs=all`, 1,000 sims, 35 elections, 2,931 seats; seat-winner log loss, lower is better, SE clustered on
election.

| Arm | elections changed | pooled change | sa2026 change | verdict |
|---|---|---|---|---|
| A `cond` | 16 of 35 | +0.0004 (SE 0.0003), worse by more than 1 SE | +0.0128 | refused: primary fails, and the sa2026 clause |
| B `cond2` | 2 of 35 (sa2026, fed2025) | +0.0001 (SE 0.0001), within 1 SE | +0.0082 | refused: the sa2026 clause |

Where arm A lost on sa2026: the seats One Nation actually WON. Hammond (won ONP) 0.638 -> 0.471, Ngadjuri 0.944 -> 0.861,
MacKillop 0.380 -> 0.357, Narungga 0.317 -> 0.307. The tree flows that lean toward One Nation gave those seats more of
their real result than the history rates did. Most likely reason, NOT tested here: the trees' lean offsets One Nation
primaries that the model under-calls (minors under-called 29 of 35 pairs, NEXT-STEPS A7 (3)); the flow-only oracle
(`scripts/score_flows_oracle.R`, primaries taken out) would separate the two. After 28 Nov.

`AUSPOL_ONP_FLOW_KEYS` stays in the code at "0": the new branch is skipped entirely at "0", so the published forecast
and every harness are unchanged.
