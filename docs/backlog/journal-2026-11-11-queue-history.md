# Queue item text moved verbatim from NEXT-STEPS.md (11 Nov 2026, wrap-up)

- OPEN, unblocked 9 Nov (reuse fix on main): `AUSPOL_POLL_SERIES_CLASS=name` (SA-Best, Katter, UAP, FF classed by full name). 20k on 7 pairs a tie
  (-0.0028, SE 0.0038); sa2018 +0.037 of which Morphett +0.031. `plans/prereg-poll-series-class-2026-11-06.md`, last section.
  Pete 10 Nov 11:10pm: "Run all 35". Deciding run scheduled 11:20pm (code 049ebc10, 20k, all pairs):
  `deciding-runs/20261110-2310-poll-series-class-all35/` FAILED 12:20am: all 70 harness runs failed in 17-228 s and
  the cleanup deleted their logs (fixed, 636da0e2). A 200-sim snapshot run passed, so likely memory (two feed parses
  and the test suite ran beside it); UNCONFIRMED. RETRY scheduled 6:00am 11 Nov, after the night-pair job:
  `deciding-runs/20261111-0027-poll-series-class-all35-retry/`. Done when its DONE marker is read and the prereg's standard
  rule applied; ship (published_flags "name" + inline default) only on a pass.

- OPEN, NIGHT MODEL (before 28 Nov). DONE 31 Oct: surge fade ON, flow floor 0.01, median ON, surge mixture OFF;
  surge-off replays settle it (Wentworth 2022 called 7:45pm with no patch; median within 0.001 on all three nights).
  Still wrong: draws with a different final pair are never corrected (Monash 2025; traced 10 Nov, fix proposed, not
  built: `reviews/night-final-pair-2026-11-10.md`; Melbourne 2025 is the AEC's own pair being wrong). BUILT 11 Nov,
  off: `pair_r` (0e621c04, prereg `plans/prereg-night-pair-trust-2026-11-11.md`); detached replay job
  `deciding-runs/20261111-0020-night-pair/` (starts after the poll-series run; reads R/ from this checkout, so no
  R/ or scripts/ edits until its DONE). Review 11 Nov 12:15am (Sonnet): 0 Important. Nits to do after the job: spread
  donors evenly over `hit` rather than cycling; document that `pair_r < 0.5` moves nothing. Mirani qld2024: counted pair right (Kelly v Andrew) and used, still wrong:
  a flow problem, untraced. Statewide draws
  shrink by the national mean counted, not the seat's; projection sd floors at 0.26.
  Fix 2 (`--tcp-own-fp`, each draw's flow from its own primaries) built, OFF: mixed on three nights; needs flow
  uncertainty in the draws, and `plans/prereg-flow-sd-2026-10-31.md` REFUSED that 31 Oct.
