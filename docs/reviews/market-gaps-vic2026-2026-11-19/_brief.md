# Brief: why does our forecast disagree with the bookmakers in ONE seat?

You are investigating one Victorian state seat (election 28 Nov 2026) where our forecast's
favourite differs from TAB's and Sportsbet's. The question, for your seat only:

**Is the gap a DEFECT we should fix, or a MODEL VIEW we can defend (a reason the market may be
missing)?** The precedent for a defect is Essendon (18 Nov): three independents were simulated as
one candidate, so their votes were summed and the "Independent" chance read 85%. That was a
modelling bug, not a view. A defensible view is something like: seat polls, a real statewide
One Nation surge applied to a seat with the right profile, a strong local candidate, a known
redistribution effect.

## Ground rules (hard)

- READ-ONLY. Do not edit, create or delete any file in C:\dev\auspol, except your one output file
  (below). No git commands that move HEAD (checkout, switch, reset, stash, commit). No pushes.
- **Do NOT run R, Rscript, the forecast, any harness, quick_arm or check_like_ci.** The machine is
  low on memory and 20 other agents are running. Python (`python -I`) on CSV/JSON files is fine;
  keep each script small.
- Never kill any process, by name or otherwise.
- Cap command output (`| head -60`). Do not cat whole large files; grep them.
- Web search is allowed for local candidate/news context. Mark every web-sourced claim
  "(web: <site>)" and every claim you could not confirm "UNCONFIRMED".
- Evidence is a file + line/row you read, or a computed number. Not a guess from a name.

## Our forecast (the one live on the site, built 19 Nov 2026 8:12am AEDT)

- `C:\Users\peteo\AppData\Local\Temp\claude\dc1a17ec65ae517e\efac9395-fa9b-4edd-bcef-278bdbc1bcda\scratchpad\fl\forecast-vic2026.json`
  -> `seats[]` (seat, region, favourite, final_two, ind_split, parties[] with party, win_prob,
  primary (forecast first-preference %), primary_q quantiles, candidate, candidates, sitting).
  `statewide[]`: forecast statewide levels LNP 30.7, ALP 22.5, GRN 14.3, ONP 21.5, OTH 11.0.
- The run's own log (every check code the pipeline printed):
  `C:\Users\peteo\AppData\Local\Temp\claude\dc1a17ec65ae517e\efac9395-fa9b-4edd-bcef-278bdbc1bcda\scratchpad\refresh.log`
  (18k lines; grep it for your seat name and for codes near it).

Party classes: LNP = Liberal/National, ALP, GRN, ONP = One Nation, IND, OTH_RIGHT, OTH.

## The other side (captured 18 Nov 2026 midday)

`C:\dev\auspol\docs\benchmarks\vic2026\2026-11-18\`: `tab-calls.csv`, `sportsbet-calls.csv`
(bookmaker win probabilities, margin removed; columns district, call_class, prob; ANY_OTHER
includes independents), `bookmaker-odds.csv` (raw prices), `aeforecasts-calls.csv` (AE Forecasts,
a rival model), `theswingison-calls.csv` (The Swing Is On, another model).
Expected seats out of 88 (ours / TAB / Sportsbet / AEF / TSIO): ONP 15.8 / 12.9 / 13.6 / 8.3 / 17.9;
LNP 39.1 / 44.3 / 44.8 / 49.5 / 39.3; GRN 7.5 / 5.3 / 5.2 / 5.1 / 5.6; ALP ~23 everywhere.
So One Nation and the Greens high and the Coalition low are a model-wide pattern; say whether
your seat is just that pattern or something seat-specific.

## Inputs worth reading (C:\dev\auspol)

- Past results: `external/elections/archive/<year>vic-firstprefs.csv` and `-tcp.csv`
  (2014, 2018, 2022). Candidate history: `output/candidacies.csv` (grep the seat).
- By-elections: `external/reference/byelections/byelection-results.csv`. Victorian contests since
  2022: Narracan supplementary (Jan 2023, Labor did not stand), Warrandyte (2023), Mulgrave (2023),
  Werribee and Prahran (Feb 2025), Nepean (May 2026).
- Seat-level inputs: `output/seat-poll-blend-vic2026.csv` (seat polls), `output/onp-senate-vic2026.csv`
  (One Nation's federal Senate vote by state seat), `output/council-history-vic2026.csv`,
  `output/leader-seat-vic2026.csv`, `output/demo-resid-vic2026.csv`,
  `output/seat-swing-port-vic2026.csv`, `output/vic2026-live-salience.csv` and
  `output/salience-v6.csv` (candidate Google-search interest), `output/ind-split-fit-vic2026.csv`.
- Earlier reviews of the live forecast: `docs/reviews/salience-vic2026-live-walk-2026-11-12.md`
  (search-interest feature moved Benambra and Narracan), `docs/reviews/FABLE-FULL-REVIEW-2026-11-15.md`,
  `docs/reviews/ind-split-armk-live-walk-2026-11-18.md`. Grep `docs/` for your seat name.
- Backtest track record (how the model did in similar seats at past elections):
  `output/published-predictions.csv` (grep header first). Does the model historically over-call
  this kind of seat (e.g. One Nation in regional seats, Greens in inner seats)?
- Switches the forecast runs with: `scripts/published_flags.R` (grep, don't read whole).

## What to produce

Write ONE file: `C:\Users\peteo\AppData\Local\Temp\claude\dc1a17ec65ae517e\efac9395-fa9b-4edd-bcef-278bdbc1bcda\scratchpad\market-gaps\<Seat>.md`
(the directory exists) and return the same text as your final answer. At most 40 lines:

1. `VERDICT: DEFECT | MODEL VIEW | UNCLEAR` and one line why.
2. A small table: each party's forecast primary and win chance (ours) vs TAB / Sportsbet / AEF / TSIO.
3. The mechanism in plain words: what inputs drive our number (starting result, swing, seat polls,
   search interest, candidate, flows), with the file/row for each.
4. If DEFECT: what is wrong, which file/function, and roughly how much it moves the number.
   If MODEL VIEW: what evidence the market may be missing, and the strongest argument against us.
5. Whether this is the model-wide One Nation/Greens pattern or seat-specific.

Finish line: the file is written with a verdict and evidence. Spend at most ~25 tool calls.
