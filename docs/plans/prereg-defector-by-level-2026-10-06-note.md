# Note: a small-n-safe SE does not rescue the state defector rate (2026-10-06, not run as an arm)

Dry run only (`fit_defector_discount()`, sitting-member carry per target). Mode "3" floored each
level's sd before dividing by sqrt(n). With the floor at the ALL-case sd, the federal/state gap itself
counted as noise and pulled the federal rate back up (fed2022 0.211 -> 0.386 against a measured 0.21).
With the floor at the WITHIN-level sd, the state rates barely moved (wa2017 0.622 -> 0.620, vic2014
0.639 -> 0.637, qld2024 0.551 -> 0.550).

So the refused state rate was not a precision artefact: state defectors keep about 0.55-0.64 of their
old vote, with real scatter. Hillarys (Rob Johnson, wa2017, kept 0.31) and MacKillop (McBride, sa2026,
kept 0.24) are low cases inside a high-carry group; no pooled rate fits both. That is the same
hold-or-collapse split parked in `docs/reviews/personal-vote-uncertainty-2026-10-05.md`. The code
change was reverted; the shipped mode "2" (federal only) stands.
