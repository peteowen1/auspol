# Election-night side scripts (Victoria, 28 Nov 2026)

**Copies, saved at 11:35pm on the night so a reboot could not lose them.** Written live, tested on real fetches only,
NOT reviewed, no tests. The copies that ran on the night are in `external/reference/benchmarks/vic2026-night/`
(gitignored) and a session temp folder. Paths inside (`C:/night28/...`, the temp folder) are the night's own and are
not portable. Before reuse: review, give each a test, and move what survives into `scripts/` proper.

| file | what it does | writes (R2 key under `auspol/night/`) |
|---|---|---|
| `raw_watch.R` | raw counts per seat from the VEC pages, no model | `raw-vic2026.json` |
| `feed_watch.R` + `booths_fn.R` | per-booth feed and the booth table: tonight v 2022, the model's estimate for booths still out (`model_fp`), a two-candidate estimate (`model_tcp`), the pre-count expectation (`pre_fp`, `pre_tcp`) and `surprise` | `booth-feed-vic2026.json`, `booths-vic2026.json` |
| `check_tcp.py` | reads the 88 district pages for the SEAT-LEVEL two-candidate totals; prints the model-v-count gap. Its output is what `NIGHT_TCP_SEAT_TOTALS` feeds back into the model | `tcp-totals-vic2026.json` |
| `upper_parse.py` (ITG's) | raw upper-house count from the 8 region pages | `raw-upper-house-vic2026.json` |
| `mk_live2.R` | live upper-house forecast inputs: `base` (live lower-house first preferences, narrowing = live sd / pre-election sd) and `blend` (blends the de-biased upper-house count for the four main parties); then `scripts/build_upper_house_forecast.R`. `mk_live.R` is v1 (fixed 0.3 narrowing) | `upper-house-forecast-live-vic2026.json` |
| `model_capture.R` + `night_loop_capture.R` | a copy of the night loop with a read-only hook that saves each seat's per-booth projection grid | (local, read by `booths_fn.R`) |
| `flow_by_type.R` | vic2022: preference flow by vote type (the 11:27pm sizing: postal v booth gap about 1 point of flow in Labor v Coalition seats) | prints |
| `upd.py` | status summary for updates: matched-booth swings, favourite changes, chamber | prints |
| `swing-chart.html` | the share-card template (placeholders `__DATA__`, `__TIME__`, `__TITLE__`, `__VOTES__`), rendered with headless Chrome | PNG |
| `launchers/` | the detached bash loops as they ran. `live_take5.sh` is the live run: `--proj-sd=max --flow-pool=on` with `NIGHT_TCP_SEAT_TOTALS` set | |

Known faults: `--tcp-by-type=on` was tried at 11:25pm and made the model worse (gap to the counted two-candidate share
0.9 -> 3.8 points); it had only the frozen 7:48pm by-booth pages to learn from. `booths_fn.R`'s 423 fallback estimates
(seat forecast plus the booth's 2022 lean) were never checked against booths that later reported.
