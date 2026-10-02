# Pre-registration: state signal pooled from seat polls (`AUSPOL_STATE_POLL_POOL = "1"`)

Registered 2026-10-02 before any harness run with it on.

## Evidence (exploratory, not a test)
Over 34 state-years (fed2019-fed2025, >=2 polled seats), relative to each
election's own average, the polled seats' mean gap (poll - our prediction)
predicted the state's mean actual error: correlation 0.675, slope 1.16
(0.91 / 1.16 / 1.35 leaving each election out). Tasmania 2025, Labor: polls
said +4.5 relative, actual +7.2 (Braddon, Lyons the largest misses).

## Change
R/state_poll_pool.R `state_poll_pool_apply()`, federal harness only, applied
BEFORE the seat-poll blend. Per state and class (ALP, LNP): mean(poll - pred)
over polled seats (>=2), minus the seat-weighted election mean; every seat of
the state shifted by b times that, rows renormalised. b per class fitted on
EARLIER federal elections only (as-at predictions, the blend weight's
source), SE over state-years, shrunk b*b^2/(b^2+se^2), clamped to [0, 1].
Dry run: fed2019/fed2022 b = 0 (nothing earlier to learn from); fed2025
ALP b 1.000 (raw 1.70, se 0.22), LNP 0.608 (raw 0.73, se 0.32), 9 state-years.
Tasmania 2025 shift: ALP +2.5, LNP -3.2 on every seat.

So this is a test on ONE election (fed2025, 150 seats).

## Criteria (against whichever of v59 / A2 ships)
1. PRIMARY: fed2025 final primary RMSE (post-correction shares) improves by
   more than 0.031.
2. GUARD: fed2025 seat log loss not worse; 22-election log loss not worse by
   more than 0.0020.
3. GUARD: Victoria unchanged (federal only by construction; any change is a bug).
UNACCEPTABLE: the RMSE gain comes from Tasmania alone while the other states
get worse.

## RESULT, 2026-10-02 22:20: REFUSED by the unacceptable clause
`output/snapshots/20261002-2212-579df5c-from6` against v59.
1. fed2025 final primary RMSE 3.431 -> 3.398 (-0.033 against a bar of 0.031):
   PASS, barely.
2. fed2025 seat log loss 0.3570 -> 0.3453; 22-election 0.3440 -> 0.3434: PASS.
3. Victoria unchanged: PASS. Every other pair byte-identical.
UNACCEPTABLE CLAUSE FIRES: by state, Tasmania 5.752 -> 5.008, Qld -0.168,
SA -0.148, ACT -0.129, but NSW +0.153, NT +0.102, WA +0.040; every state but
Tasmania 3.322 -> 3.328 (worse). The gain is Tasmania's.
Braddon ALP 25.0 -> 26.9 (actual 39.5), Lyons 30.1 -> 31.9 (43.1): the right
direction, a small fraction of the miss.
Not shipped. Note: federal only, so it would not have changed the Victorian
forecast either way; it is one election (fed2025) of evidence, the slope
learned from 9 state-years of fed2022.

## OVERRIDE, 2026-10-02: SHIPPED as v60 by Pete's decision
Pete chose to ship despite the unacceptable clause, after seeing the split:
fed2025 seat log loss summed by state, Tasmania -1.864 (Braddon 4.06 -> 3.10,
Bass 1.55 -> 1.05, Lyons 0.86 -> 0.49); every other state +0.108 over 145
seats (Qld -0.892, NSW +1.041). Reasons on record: the slope was learned from
fed2022 only, so the Tasmanian gain is out of sample; catching the one state
that moved is the method's purpose; elsewhere the change is noise-sized
(+0.0007 log loss per seat, +0.006 RMSE). The clause is NOT amended; this is
an explicit override, visible as one. Federal only: the Victorian forecast is
unchanged. Retest when another federal election with seat polls is scored.
