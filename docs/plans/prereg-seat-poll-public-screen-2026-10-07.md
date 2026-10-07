# Screen: `AUSPOL_SEAT_POLL_SOURCES=public` (2026-10-07)

Written before the screen's result was read.

**Why.** McMahon fed2025: xgb Labor primary 46.7, published 34.7, actual 45.5.
The drop comes from the seat-poll blend reading a Compass Polling direct poll
(8 Apr 2025, n=1,003: ALP 19, LIB 20, IND 41, summing to 80) with the IND
direct-poll weight shipped 2026-10-06. 54 of 1,210 seat polls name two or more
classes and sum below 90, nearly all campaign pollsters. The existing switch
`AUSPOL_SEAT_POLL_SOURCES="public"` keeps MRP releases plus direct polls by
`PUBLIC_SEAT_POLLSTERS` with no recorded sponsor.

**Arm.** `AUSPOL_SEAT_POLL_SOURCES=public`, everything else at published flags.
Screen: `scripts/quick_arm.R`, all 22 pairs, default sims.

**Primary (targeted):** McMahon fed2025 Labor winner primary moves toward 45.5.
**Guard (election-wide):** pooled seat-winner log loss, SE clustered on
election. "WORSE" by more than 1 SE stops the line; within 1 SE or better
proceeds to a full 20k arm before any ship decision.

**What would make a win unacceptable:** the gain coming from dropping public
polls by accident (check the SPB0 kept-count line per pair), or IND winners
whose only seat signal was a campaign poll (Wills, Bradfield, Cowper,
Monash, Calare fed2025) losing more log loss than McMahon-type seats gain;
report those seats separately.
