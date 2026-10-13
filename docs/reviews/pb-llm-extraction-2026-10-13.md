# Polls read from Poll Bludger posts by a language model (2026-10-13)

Coverage program (`plans/coverage-program-2026-10-13.md`), poll track. The rule extractor (`extract_pollbludger.R`)
confirmed only 142 of the 941 polls that still carry AE's numbers (15%, `POLL-REGISTRY.md`). This tests reading the
posts with a model instead.

**Method.** Posts of each AE-dependent cycle written to text files (whole posts, chunks of at most ~45k tokens), one
Sonnet agent per chunk (17 agents, workflow `wf_1df2d15f-d6b`, ~2.1M tokens), each writing one CSV row per
statewide voting-intention poll with the source sentence quoted. A Haiku pilot died of context overflow on a 33k-token
file; Sonnet read in 150-line pieces. Inputs, outputs and scores: `external/reference/polls/pollbludger/llm-extracted/`.
Scored by `scripts/score_pb_llm_extraction.R` against the poll set the trend reads (mostly AE's numbers in these
cycles): same firm (YouGov Galaxy = Galaxy, uComms = ReachTEL), post 0-45 days after the poll's midpoint, closest
numbers first; each pair compared with undecided kept and divided out, the closer counting (AE is inconsistent).

**Result.** Columns: polls the model extracted; how many matched a poll in the key; of matches with primaries,
every party within 0.5 point (higher is better) and any party off by more than 2 (lower is better); AE-only polls in
the key that a post now confirms.

| cycle | extracted | matched | within 0.5 | off > 2 | AE-only confirmed | rules confirmed (for comparison) |
|---|---|---|---|---|---|---|
| nsw2019 | 32 | 32 | 23 | 0 | 31 of 52 | 7 |
| fed2007 | 78 | 64 | 37 | 3 | 64 of 228 | 28 |
| fed2010 | 225 | 202 | 128 | 9 | 143 of 202 | 35 |
| vic2014 | 53 | 50 | 49 | 0 | 25 of 39 | 6 |
| vic2018 | 31 | 29 | 17 | 0 | 14 of 37 | 2 |
| wa2005 | 23 | 6 | 1 | 5 | 5 of 62 | 1 |
| wa2008 | 13 | 11 | 1 | 4 | 9 of 62 | 0 |
| wa2013 | 14 | 9 | 0 | 4 | 9 of 27 | 5 |

Matches without "within 0.5" or "off > 2" are two-party-only rows (no primaries in the post).

**Reading.**
- Federal, NSW and Victoria: the model's numbers agree with AE's on almost every poll that has primaries (12 off by
  more than 2 out of about 270), and it confirms 277 of the 558 AE-only polls in those cycles against 78 for the rules.
- WA is not usable yet: our WA convention keeps the Liberals and Nationals apart (`load_polls()`), the agents added
  them as "Coalition", and some Westpoll rows also differ beyond that. Needs a WA pass with separate Liberal and
  National columns.
- fed2007's coverage stays partial (64 of 228): many 2004-2007 weekly Morgan and Newspoll results were posted without
  primaries, or not posted at all.
- The 14 + 23 extracted federal polls with no match are either polls AE lacks or extraction errors: not checked.
- Some agents filled a figure from a neighbouring post ("no change on the previous fortnight"); each such row says so
  in its notes (workflow result file). These are inferences, and must be flagged, not used as stated numbers.

**Not yet in the model.** Using these rows (Poll Bludger as the named source for polls only AE had, and as a third
opinion on disputes) is the next step, with the same screen-then-deciding-run discipline as the Wikipedia layer.
