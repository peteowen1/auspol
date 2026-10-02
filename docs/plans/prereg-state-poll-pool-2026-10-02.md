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
