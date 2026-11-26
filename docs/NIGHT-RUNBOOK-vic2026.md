# Election night, Victoria, Sat 28 Nov 2026: the runbook

One page. Every command runs from `C:\dev\auspol` in Git Bash. Written 27 Nov 2026 from the scripts and the 21-26 Nov
rehearsals. The detail behind each step is in `docs/NEXT-STEPS.md` ("NIGHT SOURCE", "NIGHT BACKUP").

## Decision for Pete first: how hard to hit the VEC website

The VEC refused a live feed, so the night model reads the VEC results website. That site answers fast request rates
with HTTP 999 (refused):

| when | who | rate | result |
|---|---|---|---|
| 22 Nov | GitHub runner | 2 pages at a time | passed |
| 24 Nov | GitHub runner | every 90 s | refused on every page for 45 minutes |
| 24 Nov | GitHub runner | 2 pages at a time | blocked outright |
| 26 Nov 9:10pm | laptop | 4 pages at a time (the script's default) | 32 of 174 pages refused |

So the script's own defaults (`--parallel=4 --every=90`) are the ones that have already been refused. A fetch is 174
pages (88 districts, 2 pages each): about 1 minute at 4 at a time, and over 9 minutes at 1 at a time.

Recommended start: `--parallel=2 --every=180`, then drop to `--parallel=1 --every=300` at the first `VWF5!` line that
counts HTTP 999. The cost is a refresh every 4-10 minutes rather than every 2-3. A block costs far more: 45 minutes
with no update.

## Before 6pm

1. Check the 4:30am forecast run went green. Its night state (`night-state-vic-2026.rds` on release
   `forecast-latest`) is the night model's starting point, and the script downloads it itself.
2. Turn the VPN off.
3. Check free memory is at least 4 GB:
   `powershell.exe -Command "(Get-Counter '\Memory\Available MBytes').CounterSamples.CookedValue"`.
   Don't run any rebuild or quick_arm that night.
4. Make a fresh work folder outside the repo, for example `C:/night28`.

## 6pm: start the night

```
bash scripts/night_vic2026.sh auto C:/night28 --upload --parallel=2 --every=180
```

- `auto` finds the 2026 results index on https://www.vec.vic.gov.au/results/state-election-results. If it can't, pass
  that page's URL instead: the page that links every district's results page.
- `--upload` writes to the LIVE page's file, `auspol/night/vic2026.json`. Leave it off for a dry start.
- Logs: `C:/night28/fetch.log` (the website fetch) and `C:/night28/archive/night-loop.log` (one `OK` line per model
  cycle: seats with data, seats updated, seats with a two-candidate count).

## If it goes wrong

| what you see | what it means | do this |
|---|---|---|
| `VWF5! ... HTTP 999` in `fetch.log` | the VEC is refusing requests | Ctrl+C, then rerun with `--parallel=1 --every=300` into a NEW work folder (the state is downloaded again) |
| `VWF3! ... no DONE` | one fetch was incomplete | nothing: the loop keeps the previous snapshot and retries |
| `NV8!` | the fetcher died, so the loop was stopped too | read the last lines it prints; usually the index URL, so rerun with the explicit URL |
| laptop dies or loses internet | | GitHub: Actions > "Election-night backup" > Run workflow on `main`: key `auspol/night/vic2026.json`, source `web`, index `auto`, minutes `330`, every `300`, parallel `1` |

Never run the laptop and the backup against the live key at the same time: both write the same file.

## What the page shows, and its known limits

- A seat moves when its OWN booths come in. A seat with nothing counted keeps its afternoon forecast, whatever the
  counted seats show. Borrowing the swing across seats was built and replayed on 26 Nov, and stays off
  (`docs/reviews/night-borrowed-swing-2026-11-26.md`).
- The page calls a seat at 0.99 with at least 10% counted. On the real fed2022, fed2025 and vic2022 nights that rule made
  one wrong call: Melbourne, fed2025.
- The chamber range includes the region and seat-type correlation, from the afternoon forecast.

## After the count

1. Build the results file: `Rscript scripts/build_vec_results_2026.R --source=C:/night28/web`. Districts not yet
   declared are written `pending`.
2. Once every district is declared, score the benchmarks:
   `Rscript scripts/score_benchmarks_vic2026.R --results=<that csv>`.
