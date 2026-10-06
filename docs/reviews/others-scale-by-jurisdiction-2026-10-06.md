# Others-bucket scale by jurisdiction: built, not run (2026-10-06)

Follow-up to `reviews/major-party-error-2026-10-06.md` pattern 2 (the two majors' summed error +4.41
in Victoria, +4.63 in Queensland). Branch `worktree-agent-a9cb9eebe64bafa28` (`8ad808b`, unmerged):
`AUSPOL_OTHERS_SCALE_JUR`, per-jurisdiction log-ratio scale, time-forward, partially pooled.

Result: the between-jurisdiction variance (tau^2) is 0 for every target from fed2016 on, so the
per-jurisdiction scale equals the pooled one (vic2026 k 0.906 either way) -- i.e. the arm refused on
2026-09-28. It differs only for early WA and federal targets, where it is worse. Summed ALP+LNP error
(actual minus forecast, points), off / pooled: vic2014 +3.07 / +2.93, vic2018 +1.23 / +0.51, vic2022
+2.69 / +1.29, qld2020 +4.52 / +4.05, qld2024 +2.93 / +2.34. The Vic/Qld majors gap is mostly not the
bucket size; it sits in the seat allocation. Not run as an arm; branch kept for reference.
