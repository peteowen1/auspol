# The nightly Forecast refresh still doesn't complete end-to-end

2026-09-13, immediately after PR #37 (merged) fixed the covariance-stage
crash that had failed the nightly workflow since 2026-09-03. This records
what's still blocking a full, successful run, so it isn't rediscovered from
scratch.

## What's confirmed fixed

Two real `workflow_dispatch` runs against `dev` (not just local simulation)
confirm `estimate_statewide_cov.R` no longer crashes: it correctly prints
`CV1! only 1 election pair(s)... writing the INDEPENDENCE fallback` and
`CV7 wrote output/statewide-cov.rds (DEGRADED: independence assumed)`, and
the pipeline proceeds well past that stage.

## What's blocking it now: `fit_seats_full.R`'s MP-slope tier

The second real run got into `fit_seats_full.R` (real `S0`/`LV1`/`LV2`/`S6`/
`CN1`/`DS1`/`DS2` output, genuinely computing) and died there:

```
Error in eval(ei, envir) :
  the MP slope tier needs output/mp-slope-by-class.csv -- run scripts/fit_mp_slope.R.
  Set AUSPOL_MP_SLOPE=0 to publish without it.
```

`AUSPOL_MP_SLOPE=1` is the shipped default (`published_flags.R`), so this is
a real, published feature — turning it off is not the right fix, it would
silently degrade what actually gets forecast. Neither `fit_mp_slope.R` nor
its own prerequisite, `build_candidacies.R`, is a stage in `run_all.R`'s
`STAGES` list at all. This is the exact same shape of gap
`estimate_statewide_cov.R` had — *"it has to be a pipeline stage rather than
a fetch step, and it was neither"* — just one layer further down.

## Why the obvious fix (add both as stages) doesn't work as-is

Tried locally, not committed. Simulated CI's actual data (moved aside all 17
first-preferences files the workflow's fetch step never produces — federal,
all three NSW years, three historical VIC years, one historical SA year, one
historical QLD year, and all seven WA years, since WA has no fetcher in the
workflow at all) and ran `build_candidacies.R` directly against it:

```
Error: vic2010: vec-2010-vic-firstprefs.csv is absent, so seat names would
stay in the page-slug form. A silent drop here disables salience and the
personal-vote transfer for every seat this election.
```

This is a **deliberate** hard `stop()`, not an oversight — the message states
its own reasoning: silently proceeding without VIC 2010's seat-name
resolution would break two features invisibly for that whole election,
which the author judged worse than refusing outright. Unlike
`estimate_statewide_cov.R` (which had graceful per-pair skip logic
everywhere except the one eager federal read), `build_candidacies.R` treats
this specific case as unrecoverable by design.

VIC 2010 is part of `fetch_preferences_vic_historical.R`, one of the four
fetchers the workflow deliberately excludes (the same NSW-runner-IP decision
recorded in `forecast.yaml`), so this file is **permanently** absent in CI,
not an intermittent gap.

## What this needs, not attempted here

`build_candidacies.R` is a large (700+ line), carefully-reasoned script with
its own considered philosophy about which missing-data cases fail loudly and
which degrade quietly (compare its existing per-region guards, e.g. the
sa2018 block, which already skips gracefully). Giving it a THIRD option —
degrade gracefully for a whole election it cannot fully build, rather than
either crashing or silently corrupting seat-name resolution — is real design
work on a script that deserves a careful pass, not a rushed patch appended
at the end of an already-long session.

The likely shape of a real fix: skip the affected ELECTION (not silently
drop the seat-name feature within it) when its required historical file is
absent, printing which election and why, and confirm `fit_mp_slope.R`'s own
downstream behaviour (it already hard-stops on any target with zero panel
rows, from this same session's earlier commits) tolerates a candidacies.csv
with some elections missing entirely.

## CORRECTED, same night: the scope is bigger than the section above states

The VIC 2010 stop() above was diagnosed from a test that, in hindsight, was
ALSO not fully representative — the same class of mistake made twice already
on this exact investigation (see `docs/reviews/xgb-primary-circularity-
2026-09-13.md` and this file's own earlier correction). That test removed
files from `external/elections/` but left `external/reference/vec/2010/`
(the RAW SCRAPED VEC pages this block actually reads) fully intact on this
machine, so the block never exercised its OWN already-graceful
`if (!dir.exists(dir_y)) next` skip (line 664) -- it read the real, present
HTML pages, built `v` successfully, and only THEN hit the stop() because the
SEPARATE reference CSV used purely for seat-name resolution had been moved.

In real CI, `external/reference/` is never created, fetched, or cached at
all -- the workflow's only cache step is `path: external/elections`. So
`external/reference/vec/2010/` almost certainly does not exist there either,
which means the EARLIER, already-graceful skip at line 664 would fire FIRST,
and the stop() this section originally centred on may never be reached in
practice.

`build_candidacies.R` reads from SEVEN `external/reference/` subdirectories
(`aec`, `ecq`, `ecsa`, `nsw`, `vec`, `waec` -- confirmed by grep, plus
`wikipedia` used elsewhere in the corpus), none of which CI ever populates,
across roughly 14 `stop()` calls and 15 existence guards in this one script.
The earlier "BC5 wa2001: 366 candidates" / "BC6 qld2020: 599 candidates"
success lines in this file's first version were run against a machine that
still had ALL of `external/reference/` intact -- they prove those blocks work
when the raw scraped data is present, not that they degrade correctly when
it (genuinely, in CI) is not.

## Recommendation, revised

The real question is not "does the VIC block crash" -- it's "does EVERY
per-region block correctly degrade when its own `external/reference/`
subdirectory is entirely absent," which needs each of roughly 14 `stop()`
sites checked against a true simulation (moving aside whole
`external/reference/{aec,ecq,ecsa,nsw,vec,waec}` trees, not individual
files -- a bigger, more careful operation than anything attempted tonight,
given the risk of mishandling large cached directories). That is real,
multi-hour audit work on a ~900-line script with 14 independent failure
points, not a same-session continuation. Queued as its own item with this
corrected scope, so whoever picks it up next does not have to re-discover
that the original diagnosis was itself incomplete.
