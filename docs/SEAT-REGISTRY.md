# Seat registry: what we already know about individual seats

Pete, 2026-09-18: *"we keep researching some of the same ones over and over."*
**Check here before digging into a seat.** One entry per (election, seat)
that has been investigated, with the verdict and where the evidence lives.
Numbers are from the ledger build named in the entry; the live ledger
(v32+, built by `scripts/rebuild_forecasts.sh`) may differ slightly.

Verdict codes: **NOTHING TO FIX** (understood, leave it), **OPEN** (a fix is
identified but not built), **PARKED** (Pete's call to defer), **DATA** (a
data or scoring defect, fixed).

Add an entry whenever a seat is dug into, even if the answer is "nothing".
The ledger's per-seat notes are the same information in the artifact; this
file is the durable copy.

## qld2024

- **Mirani** — **NOTHING TO FIX** (Pete, 2026-09-18). Stephen Andrew
  (elected One Nation 2020, ran KAP 2024) lost to the LNP. Our primary for
  him matched AEF's, our confidence in the real LNP v KAP pairing was
  better than AEF's, and our margin matched theirs. AEF scores better on log
  loss only because it gave weight to an ALP v LNP final two that was never
  close (ALP lost comfortably), and that mistake happened to help them. A
  lucky miss on their side, not a model gap on ours. Don't reopen unless the
  question is different. Earlier digs: `reviews/mirani-party-defection-2026-09-16.md`,
  `reviews/minor-defector-two-rate-2026-09-17.md`. One residual observation
  for a possible minor-defector "conserve" rule: ONP kept 11.9 with a new
  candidate where we gave them 0.9 (all of Andrew's vote moved with him).
- **South Brisbane** — Greens led the primary and lost on preferences; LNP
  preferences in inner Brisbane flow to ALP over GRN more than the pooled
  flow says. Pattern E in `reviews/worst-seats-five-patterns-2026-09-13.md`;
  same family as Footscray/Richmond below (**OPEN**, preference flow).

## vic2022

- **Morwell** — **OPEN**, the biggest single seat in the corpus (log loss
  2.70 on the v32 ledger). Russell Northe won 2014 as a National (44.4),
  held 2018 as an independent (19.6), retired 2022. Our base_pred decays his
  IND base toward the measured 0.38 retention (`AUSPOL_HONOUR_DEPARTED`) but
  the released vote is spread pro-rata over every class. It went home: the
  Nationals rose from our 27.2 to 38.4, and that 11 points is the miss. His
  origin party is in `output/candidacies.csv`, so this is knowable. **Built
  and measured 2026-09-18** (`AUSPOL_DEPARTED_ORIGIN`, `route_departed_origin()`):
  Morwell itself goes 1.86 -> 1.03 and 8 of 15 such cases improve, but the
  15-case pooled criterion fell 0.06 SE short and the switch stays off;
  `plans/prereg-departed-origin-return-2026-09-18.md`. Re-decide when the
  corpus grows. Note the
  09-18 honour fix's "3.05 -> 1.88" was measured under the old look-ahead
  xgb cache; under the honest as-at model the seat is back at 2.70.
  `reviews/departed-leader-honour-fix-2026-09-18.md`, pattern D in
  `reviews/worst-seats-five-patterns-2026-09-13.md`.
- **Footscray, Richmond, Brunswick, Pascoe Vale** (ALP v GRN) — we over-
  favour ALP by 9-11 points of 2CP given the real pairing (Footscray 65.8
  predicted vs 54.2 real). Inner-Melbourne Liberal and minor preferences
  flow to the Greens more than the pooled, margin-blind flow table says.
  Richmond also: the Liberals did not run in 2018, so their 2022 re-entry
  had no seat base (6.8 predicted, 18.8 actual). **OPEN**, pattern 3 (flow),
  diagnosed 2026-09-18 and not yet fixed.
- **Mornington** — **NOTHING TO FIX** on its own. We drew the real LNP v IND
  pairing 19% of the time, and the 2CP we report for it (IND 63.9) is the
  mean over the draws where the IND surged enough to reach it, so it is
  conditional on that scenario and reads high. The primary miss (IND 15.2 vs
  23.9) is the teal under-prediction pattern below.
- **South-West Coast, Murray Plains** — safe LNP seats where the second
  place is contested between ALP and an IND/minor; we draw the real pairing
  55% / 84%. Seat noise is calibrated (checked by band 2026-09-18, ratio
  0.84-1.15), so this is a real three-way race in the numbers, not a bug.
  **NOTHING TO FIX** unless the flow question above changes it.
- **Geelong** — fixed by the departed-leader honour change (0.43 -> 0.03).

## fed2022

- **Hughes** — **NOTHING TO FIX**. Craig Kelly (Liberal 53.2 in 2019) ran as
  UAP. The major-defector discount gave him 0.28-0.37 of his vote and
  conserved the rest with the Liberals, then the statewide Liberal swing
  and renormalisation took the Liberals to 26.3 (actual 43.5). Kelly kept
  only 0.14 of his vote, the second-lowest of 18 sitting-MP defectors in
  the corpus (only 2 went to a minor party rather than IND, so a
  destination-split rate cannot be fitted). AEF also missed it (33.0). A
  pooled constant was right to use; this is the tail. Checked 2026-09-18.
- **Mallee, Maranoa** — **NOTHING TO FIX** (checked against the AEC
  distribution of preferences, 2026-09-18). Ledger v31's 9.6% / 46% for
  drawing the real LNP v ALP pairing was a vintage bug (stale TCP file);
  true figures 33% / 76%. The real three-candidate count was ALP 22.9 v
  IND 20.9 in Mallee and ALP 20.1 v ONP 20.0 in Maranoa, so second place
  was a genuine coin-flip in both. AEF's 96% / 91% there is Mirani-style
  luck, not a better model. Our Mallee primaries are within 2 points on
  every class.
- **New England** — a real miss, not a coin-flip: the three-candidate
  count was ALP 26.2 v IND 15.4 (10.8-point gap) and we drew LNP v ALP only
  38% of the time (AEF 96%). Cause is primaries: ALP 13.1 predicted vs
  18.6 actual, right-minor 9.3 vs 5.9. **OPEN**; the ALP under-prediction in
  safe National seats is worth a look alongside the swing-beyond-statewide
  seats.
- **Higgins, Tangney** — the swing to ALP beat the statewide swing by 6-11
  points (Higgins ALP 22.2 base vs 28.5). Pattern A (state swing, federal).
  **OPEN** in the sense that only a seat-level swing model fixes it; no
  bug. `reviews/notional-prior-redistribution-2026-09-13.md` for Tangney.
- **Wentworth** — AEF pick semantics confusion, fixed in the ledger
  (2026-09-18): both sides' "pick" now always names the real pairing's
  predicted winner. **DATA**.
- **Bradfield (fed2025)** — 26-vote margin after recount; ranking ABC
  finalists by rounded percentage called it for the wrong side. Fixed by
  ranking on raw votes. **DATA**, 2026-09-18.

## fed2025

- **Flynn** — LNP 31.5 vs 37.4 actual; we picked ALP in the real pairing.
  The 2022 LNP vote was Colin Boyce's first term; swing model only. No
  candidate-identity issue found. `reviews/flow-audit-fed2025-2026-09-05.md`.
- **Kooyong** — IND 61.1 predicted vs 50.7 real in the IND v LNP pairing;
  same over-favouring of the teal on preferences as the Greens seats above.
  **OPEN**, flow.

## nsw2023

- **Wakehurst, Pittwater, Kiama** (plus fed2022 Curtin, Goldstein, North
  Sydney, Mackellar) — independents we under-predict by 15-23 points where
  they win. Pattern 2 (teal/IND emergence). **PARKED** by Pete 2026-09-18
  ("deal with them separately afterwards"). Kiama is Gareth Ward, a
  defector who kept 0.72 of his Liberal vote; the person-vs-label problem is
  the same one as Hughes/Morwell from the other side.
  `reviews/aef7-worst-seats-2026-09-15.md`, `reviews/nsw-departed-member-2026-09-15.md`.
- **Cabramatta** — ALP 58.3 base vs 41.3 actual. Nick Lalich retired; the
  new ALP candidate lost 17 points with an IND and a right-minor taking
  them. The retirement discount is one flat rate regardless of how
  prominent the member was (pattern A, `reviews/worst-seats-five-patterns-2026-09-13.md`).
  **OPEN**, no candidate-level fix identified.
- **Northern Tablelands** — LNP 66.3 base, xgb pulled it DOWN to 56.6,
  actual 71.6 (Adam Marshall retired, the Nationals vote went up). The as-at
  xgb model learned "rural incumbent retires, party loses ~10" and applied
  it. A miss, not a bug. The IND we gave 10.7 got 3.0. **NOTHING TO FIX**
  without a better retirement model.
- **Auburn, Parramatta, Heathcote** — western-Sydney swing to ALP far beyond
  the statewide swing (Auburn ALP 48.8 vs 60.1). Pattern 3 in the 2026-09-18
  dig (NSW landslide); same shape as Higgins/Tangney. **OPEN**, swing model.
- **Port Macquarie** (and **wa2025 Roe**) — Liberal v National final two;
  `classify_party()` puts both in one LNP class so no TCP can be scored. AEF
  has the identical limitation. **PARKED** (Pete, 2026-09-18), excluded from
  TCP metrics, `docs/NEXT-STEPS.md`.

## sa2026

- **Black** — **OPEN**. David Speirs (Liberal 50.1 in 2022) resigned; ALP's
  Alex Dighton won the 2024 by-election, then held in 2026 (43.2) with
  Speirs back as an IND (14.1). Our base_pred has ALP 34.7 (no by-election
  in the baseline) and IND 16.6, and the as-at xgb model then pushed the
  IND to 27.4. Two things: by-election results are knowable and unused as
  the seat baseline; and the xgb IND boost is worth a SHAP look. Pattern C
  in `reviews/worst-seats-five-patterns-2026-09-13.md`.
- **Kavel** — Dan Cregan (Liberal 48.1 in 2022, IND 50.5 in 2022 as a
  defector) fell to 21.4 as the One Nation surge took the right vote. We
  gave him 45. AEF gave 21.7. The One Nation surge in SA is the parked
  "no same-jurisdiction precedent" problem. **OPEN** via that item.
- **MacKillop** — One Nation won with 35.3; we gave them 27.9 and drew the
  real ONP v LNP pairing 2% of the time (AEF 44%). One Nation
  concentration, pattern C. `reviews/onp-concentration-validated-2026-09-09.md`.

## wa2025

- **Cottesloe** — LNP 67.2 predicted vs 55.5 real in the LNP v IND pairing;
  teal preferences again. **OPEN**, flow.
- **Kalgoorlie** — wrong winner class in the TCP reference until the
  official WAEC distribution was parsed (2026-09-18). **DATA**.
