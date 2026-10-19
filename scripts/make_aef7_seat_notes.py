"""One-off generator for docs/aef7-seat-notes.csv (2026-10-19).

The CSV is the committed source of truth afterwards: edit the CSV, not this
script. This script is kept only so the first classification (and the evidence
for each row) can be audited. Run: python -I scripts/make_aef7_seat_notes.py
"""
import csv

R = []  # (election, seat, kind, text, status, fixed_by, source)


def fact(e, s, text, source):
    R.append((e, s, "fact", text, "", "", source))


def model(e, s, text, status, fixed_by, source):
    R.append((e, s, "model", text, status, fixed_by, source))


SR = "docs/SEAT-REGISTRY.md"
NOTE = "ledger notes db 2026-09-15/16 (artifact 3YAUawbwdQBn96Bi5nqF4A)"
LED = "output/aef7-ledger-data.json built 2026-10-19 17:24"

# ---------------------------------------------------------------- fed2022
fact("fed2022", "Brisbane", "Greens won (part of the inner-Brisbane Greens cluster with Ryan and Griffith, which all went Green in 2022). Missed again in fed2025 in the opposite direction.", NOTE)
model("fed2022", "Brisbane", "Original note: cause unknown. The 'Greens under-concentrated' explanation was RETRACTED 2026-09-15 (selection bias, placebo reproduced it). Now our win probability for the Greens is 0.371 (AEF 0.129) and the winner's primary miss is +0.2, so this seat has improved a lot; which change did it was not isolated.", "PARTLY", "not isolated (ledger 2026-10-19: p 0.371, primary miss +0.2)", "docs/reviews/greens-under-concentration-2026-09-15.md; " + LED)

fact("fed2022", "Fowler", "Independent Dai Le won on 29.5 against Labor's Kristina Keneally (a Senator parachuted in). Le had a prior vote as an independent in Cabramatta (nsw2019, 25.9). A candidate-level result, not a swing.", "docs/reviews/cross-seat-personal-vote-2026-10-05.md; " + NOTE)
model("fed2022", "Fowler", "Cause: a person's vote in another seat (Le, Cabramatta) was not carried to Fowler. AUSPOL_CROSS_SEAT_VOTE carries it at a fitted, shrunk rate (~0.47). Win probability still only 0.093 (AEF 0.051) and the primary miss is +12.4 (was +15.9), so the carry is too small here.", "PARTLY", "AUSPOL_CROSS_SEAT_VOTE=1 (2026-10-06, Amendment A1)", "docs/DECISIONS.md 2026-10-06; docs/reviews/cross-seat-personal-vote-2026-10-05.md; " + LED)

fact("fed2022", "Griffith", "Greens won on 34.6 (we had 27.3 in the first run). Third of the inner-Brisbane Greens trio (Brisbane, Ryan, Griffith). Missed again in fed2025, that time by over-predicting the Greens.", NOTE)
model("fed2022", "Griffith", "Cause unknown (group D). The under-concentration explanation was retracted. Still a miss: win probability 0.101 (AEF 0.229), primary miss +7.9.", "OPEN", "", "docs/reviews/greens-under-concentration-2026-09-15.md; " + LED)

fact("fed2022", "Hasluck", "WA 2022: Labor swung far harder than the nation (the 2021 WA state landslide effect). Same cause as Tangney, Swan and Pearce.", NOTE)
model("fed2022", "Hasluck", "WA state swing. AUSPOL_STATE_DEV (adopted 2026-09-15) corrects for it but only by the polled state deviation. Now called correctly (p 0.519, AEF 0.526) but the winner's primary miss is still +6.2 against AEF's +2.5. The v2 correction (AUSPOL_STATE_DEV=2) was REFUSED 2026-09-19 and the registry still lists the WA state swing as OPEN.", "PARTLY", "AUSPOL_STATE_DEV=1 (2026-09-15)", "docs/SEAT-REGISTRY.md (fed2022 Tangney/Pearce/Hasluck/Swan); docs/plans/prereg-state-deviation-v2-2026-09-19.md; " + LED)

fact("fed2022", "Ryan", "Greens won on 30.2 (we had 20.5 in the first run); one of three inner-Brisbane Greens seats missed together with Brisbane and Griffith.", NOTE)
model("fed2022", "Ryan", "Cause unknown (group D); the under-concentration explanation was retracted 2026-09-15. Win probability 0.146 (AEF 0.028), primary miss +6.8 (was +9.7). We beat AEF here but still miss.", "OPEN", "", "docs/reviews/greens-under-concentration-2026-09-15.md; " + LED)

model("fed2022", "Swan", "WA 2022 state swing, same cause as Tangney. Fixed: called correctly at p 0.94 with a -1.0 primary miss (log loss 0.62 -> 0.49 on the 2026-09-15 re-run, now 0.06).", "FIXED", "AUSPOL_STATE_DEV=1 (2026-09-15)", "docs/SEAT-REGISTRY.md; " + LED)

fact("fed2022", "Tangney", "WA 2022: Labor swung to a much bigger result than the nation (mean Labor per-seat primary error +6.43 over 15 WA seats, positive in 14).", NOTE)
model("fed2022", "Tangney", "WA state swing; state polls only knew +3.53 of the +6.43. AUSPOL_STATE_DEV (2026-09-15) took Labor from 0.029 to 0.044 then later changes to 0.232 (AEF 0.084); primary miss now +4.0 (was +10.5 in the v38 run). Still a wrong favourite.", "PARTLY", "AUSPOL_STATE_DEV=1 (2026-09-15); later gains not isolated", "docs/SEAT-REGISTRY.md; docs/reviews/statewide-forecast-audit-2026-09-20.md; " + LED)

# ---------------------------------------------------------------- fed2025
fact("fed2025", "Bass", "Tasmania swung +8.06 to Labor against the national trend (same as Braddon).", NOTE)
model("fed2025", "Bass", "Tasmanian swing not visible to the federal model: no Tasmanian state-level federal polling and no state-deviation data for fed2025. Win probability 0.298 (AEF 0.297), primary miss +9.8. State-deviation v2 was refused 2026-09-19; it reopens only with Tasmanian state results in the corpus.", "OPEN", "", "docs/NEXT-STEPS.md (State-deviation); " + LED)

fact("fed2025", "Braddon", "Sitting Liberal Gavin Pearce retired. Tasmania swung +8.06 to Labor against the national trend. Labor won on 39.5 against our 22.2 in the first run, the second-largest primary miss in the corpus.", "docs/SEAT-REGISTRY.md (fed2025 Braddon); " + NOTE)
model("fed2025", "Braddon", "The state-swing correction cannot reach Tasmania (no state-level federal polling). Our win probability for Labor has improved from 0.07 to 0.179 (AEF 0.130) but the primary miss is still +11.5. One of the six 95%+ favourites that lost.", "OPEN", "", "docs/SEAT-REGISTRY.md; docs/reviews/statewide-forecast-audit-2026-09-20.md; " + LED)

fact("fed2025", "Goldstein", "Zoe Daniel (IND) held it on 34.5 in 2022, recontested and fell to 30.7; Tim Wilson (LNP) took it back on 43.4. A sitting independent defeated while standing again, not a departure.", NOTE)

# ---------------------------------------------------------------- nsw2019 (not in the AEF-7 ledger; kept for history)
fact("nsw2019", "Orange", "A 21.7-point Nationals seat that had already gone to the Shooters at a 2016 by-election, so the previous general election's winner was long gone. Not in the AEF-7 ledger (nsw2019 is outside the seven), kept here as history.", NOTE)
model("nsw2019", "Orange", "Was the worst single case of the NSW departed-member failure (winner given ~0). By-election winners are now credited the sitting non-major level: Orange 0.01 -> 0.76.", "FIXED", "AUSPOL_BYELEC_LEVEL=1 (2026-10-05)", "docs/DECISIONS.md 2026-10-05")

# ---------------------------------------------------------------- nsw2023
fact("nsw2023", "Bega", "Andrew Constance left (federal tilt). The seat also had a 2022 by-election, so the sitting-member field 'who holds it now' is not 'who won the last general election'.", "docs/SEAT-REGISTRY.md (Bega, Monaro by-elections); " + NOTE)
model("nsw2023", "Bega", "Departed member plus by-election baseline. Fixed: Labor now 0.924 (AEF 0.762).", "FIXED", "AUSPOL_BYELECTION_PRIOR=blend (2026-09-18), AUSPOL_MAJOR_DEPARTED=1 (2026-09-18)", "docs/SEAT-REGISTRY.md; " + LED)

fact("nsw2023", "Heathcote", "Lee Evans (Lib) stood again, so this is not a departed-member seat. Labor won on 44.2. Western Sydney swung to Labor far beyond the statewide swing.", NOTE + "; docs/SEAT-REGISTRY.md (Auburn, Parramatta, Heathcote)")
model("nsw2023", "Heathcote", "Western-Sydney over-swing (registry pattern 3, NSW landslide): swing model, not a candidate issue. Labor now 0.674 (was 0.233), AEF 0.945; primary miss +5.1 against AEF's +0.6. Call is right but under-confident.", "PARTLY", "not isolated", "docs/SEAT-REGISTRY.md; docs/NEXT-STEPS.md (seat polls item); " + LED)

fact("nsw2023", "Monaro", "John Barilaro's seat, held by 11.6, and he was not on the ballot (it had a 2021 by-election). Part of the NSW departed-member pattern: a seat held by 5+ points whose previous winner is absent was called wrong 26.2% of the time (11 of 42) across both NSW pairs, against 1.8% when the member stands again; NSW-specific (z=+3.89 on nsw2019, pooled over seven elections z=+0.74).", "docs/reviews/nsw-departed-member-2026-09-15.md; " + NOTE)
model("nsw2023", "Monaro", "Fixed: Labor now called at 0.502 (AEF 0.283).", "FIXED", "AUSPOL_MAJOR_DEPARTED=1 and AUSPOL_MAJOR_SLOPE=1 (2026-09-18), AUSPOL_BYELECTION_PRIOR=blend (2026-09-18)", "docs/plans/prereg-major-departed-slope-2026-09-18.md; " + LED)

fact("nsw2023", "Parramatta", "Geoff Lee (Lib) retired; Labor won on 47.0 against our 34.6 first run (AEF 41.9). One of eleven safe NSW seats whose previous winner was absent and which we then called wrong. Western Sydney over-swing as well.", "docs/reviews/nsw-departed-member-2026-09-15.md; " + NOTE)
model("nsw2023", "Parramatta", "Labor win probability 0.148 -> 0.436 (AEF 0.717) after the departed-major slope shipped; still the wrong favourite (LNP), primary miss +8.6 vs AEF +5.1. The 2026-09-16 'tried, not shipped' text is out of date: the major-party departed/present slopes were shipped 2026-09-18. What is left needs per-seat variance widening for departed-member seats, designed with Pete.", "PARTLY", "AUSPOL_MAJOR_DEPARTED=1, AUSPOL_MAJOR_SLOPE=1 (2026-09-18)", "docs/SEAT-REGISTRY.md (nsw2023 Parramatta); docs/NEXT-STEPS.md (Seat polls: walk Parramatta, Heathcote with Pete); " + LED)

fact("nsw2023", "Riverstone", "Kevin Conolly retired; Labor won on 44.2. Same departed-member group as Monaro, Parramatta, Bega, South Coast and Wakehurst.", NOTE)
model("nsw2023", "Riverstone", "Fixed: Labor now 0.903 (AEF 0.800), primary miss +4.9.", "FIXED", "AUSPOL_MAJOR_DEPARTED=1 (2026-09-18)", LED)

fact("nsw2023", "South Coast", "Shelley Hancock (Lib) retired from a 10.6-point seat and Labor took it. One of the eleven safe departed-member seats.", NOTE)
model("nsw2023", "South Coast", "Labor probability 0.235 -> 0.365 after the departed-major slope; still the wrong favourite (LNP). We still beat AEF here (0.057).", "PARTLY", "AUSPOL_MAJOR_DEPARTED=1 (2026-09-18)", LED)

fact("nsw2023", "Wakehurst", "Independent Michael Regan won on 35.9 from no prior vote in the seat. A Sky News poll about 1 March 2023 had Liberal 41, Regan 37, 50-50 on the two-candidate count (pollster/date/sample unconfirmed).", "docs/reviews/seat-polls-independents-2026-10-06.md; " + NOTE)
model("nsw2023", "Wakehurst", "Was the largest primary miss in the AEF-7 (+22.2). Now called correctly (independent 0.604, AEF 0.342), miss +6.1. The seat poll's independent primary is now read; the surge model's recipient set is still only IND/OTH/OTH_RIGHT. The general teal/independent under-call is PARKED by Pete (2026-09-18).", "PARTLY", "AUSPOL_SEAT_POLL_IND_MAP/_IND_WEIGHT/_HANDKEYED=1 (2026-10-06): that review names Wakehurst as correctable; not isolated by a seat-level run", "docs/reviews/seat-polls-independents-2026-10-06.md; docs/NEXT-STEPS.md (Teal/independent under-call); " + LED)

# ---------------------------------------------------------------- qld2024
fact("qld2024", "Mirani", "Stephen Andrew (One Nation, held 2017/2020) disendorsed and ran for Katter's Australian Party (OTH_RIGHT) in 2024; he lost to the LNP. LNP led the real primary count.", "docs/reviews/mirani-party-defection-2026-09-16.md; " + NOTE)
model("qld2024", "Mirani", "Was LNP 0.088 against AEF 0.416 (the deciding One Nation/KAP versus LNP preference flow rests on one real observation). Now LNP 0.403 (AEF 0.416). Minor-to-minor defector rules shipped; registry verdict: NOTHING TO FIX, AEF's edge was luck.", "FIXED", "AUSPOL_MINOR_DEFECT_BASE_PRED=1 (2026-09-18), AUSPOL_MINOR_DEFECT_CONSERVE=1 (2026-09-19); flow work AUSPOL_FLOW_ASAT/HTV_FLOW (2026-09-18)", "docs/SEAT-REGISTRY.md (qld2024 Mirani); " + LED)

fact("qld2024", "South Brisbane", "Labor won the seat back from the Greens (sitting member Amy MacMahon). The LNP put the Greens last on its 2024 how-to-vote card (73% of LNP preferences went to Labor; real two-candidate count Labor 56.0).", "docs/SEAT-REGISTRY.md (qld2024 South Brisbane); " + NOTE)
model("qld2024", "South Brisbane", "Our flow was learned from qld2020, when the LNP put the Greens above Labor (36% to Labor). Labor primary is right (25.8 vs AEF 25.2, actual 32.0) but win probability is 0.040 (AEF 0.162). Needs the LNP card order as an input; not available. Still OPEN.", "OPEN", "", "docs/SEAT-REGISTRY.md; docs/reviews/flow-uncertainty-fallback-only-2026-09-16.md; " + LED)

# ---------------------------------------------------------------- sa2026
fact("sa2026", "Black", "David Speirs (Liberal, 50.1 in 2022) RESIGNED; Labor's Alex Dighton won the 2024 by-election and held the seat in 2026 (43.2) with Speirs back as an independent (about 14). The earlier note called it a disendorsement; the registry says resignation.", "docs/SEAT-REGISTRY.md (sa2026 Black); docs/reviews/defector-carry-2026-10-05.md")
model("sa2026", "Black", "Was our worst sa2026 seat (Labor 0.058, independent favoured 0.94). The model took Speirs as the independent class's returning sitting member and ignored the by-election. Fixed: by-election winner is the sitting member, and the by-election is half-blended into the baseline. Labor now 0.804 (AEF 0.925); primary miss +6.0.", "FIXED", "AUSPOL_BYELECTION_MP=1 (2026-09-19), AUSPOL_BYELECTION_PRIOR=blend (2026-09-18)", "docs/SEAT-REGISTRY.md; docs/plans/prereg-byelection-mp-2026-09-19.md; " + LED)

fact("sa2026", "Hammond", "One Nation won on 27.4. Third of the One Nation trio (Hammond, MacKillop, Narungga): the only statistically real concentration in the AEF-7 (p=0.007 against a 9% base rate).", NOTE)
model("sa2026", "Hammond", "Was LNP favoured at 0.81. Now One Nation 0.570 (AEF 0.128). Which of the One Nation concentration / flow changes did it was not isolated.", "FIXED", "AUSPOL_ONP_CONC_SD=auto (2026-09-14), AUSPOL_FLOW_TF=1 tf2 flow trees (2026-10-12); not isolated", LED)

fact("sa2026", "MacKillop", "One Nation won on 35.3, the biggest One Nation primary miss in the corpus. Rural, Yorke/south-east, lowest Year 12 band.", NOTE)
model("sa2026", "MacKillop", "One Nation concentration (pattern C). Win probability now 0.345 (AEF 0.181) but the primary miss is still +11.6, unchanged from +11.5; the demographic correction moved it +0.5 only. Concentration failure, not a statewide level failure.", "PARTLY", "AUSPOL_ONP_CONC_SD=auto (2026-09-14) for the win probability; primary not fixed", "docs/reviews/onp-concentration-validated-2026-09-09.md; " + LED)

fact("sa2026", "Narungga", "One Nation 37.5; the sitting independent fell from 40.8 to 17.0. The official two-candidate count is One Nation 50.16 over LNP.", NOTE + "; docs/DECISIONS.md 2026-10-08")
model("sa2026", "Narungga", "One Nation concentration. Win probability now 0.343 (AEF 0.092), primary miss +8.8 (was +7.9, not better). Our own preference reconstruction put the final pair in the wrong order (we said LNP by 50.4).", "PARTLY", "AUSPOL_ONP_CONC_SD=auto (2026-09-14); primary not fixed", "docs/reviews/aef7-worst-seats-2026-09-15.md; " + LED)

# ---------------------------------------------------------------- vic2022
fact("vic2022", "Mildura", "Ali Cupper (IND) held it on 32.7 in 2018, recontested and increased to 33.9; she led the primary vote and lost. Jade Benham (Nat) won from 25.9 on preferences.", NOTE)
model("vic2022", "Mildura", "A preference-flow miss, not a primary one: Nationals/Liberal preferences. Coalition split into two candidates shipped 2026-10-17 but Victoria got worse on average; Mildura still p 0.204 (AEF 0.245).", "OPEN", "", "docs/reviews/lib-nat-plumbing-2026-10-16.md; docs/DECISIONS.md 2026-10-17; " + LED)

fact("vic2022", "Morwell", "Russell Northe won 2014 as a National (44.4), held 2018 as an independent (19.6) and retired in 2022. Martin Cameron (Nat) won while Labor led the primary on 31.4.", "docs/SEAT-REGISTRY.md (vic2022 Morwell); " + NOTE)
model("vic2022", "Morwell", "The old note said the model assumes ~100% retention for a departing member; that is out of date (AUSPOL_HONOUR_DEPARTED decays it toward 0.38). What remains: his released vote is spread pro-rata over every class instead of returning to the Nationals (+11 points, the miss). Built as AUSPOL_DEPARTED_ORIGIN but the 15-case criterion missed by 0.06 SE and it is off. Win probability 0.070 (AEF 0.571).", "OPEN", "", "docs/SEAT-REGISTRY.md; docs/reviews/departed-leader-honour-fix-2026-09-18.md; " + LED)

fact("vic2022", "Shepparton", "Suzanna Sheed (IND) held it on 38.4 in 2018, RECONTESTED and fell to 29.4; Kim O'Keeffe (Nat) won on 32.1 (Coalition class 52.6 with the second Nationals candidate). Not a departure.", NOTE)
model("vic2022", "Shepparton", "Independent over-call: the first-defence term for a sitting independent was REFUSED at share level (2026-10-07). Listed in NEXT-STEPS as 'overcalled independents, NOT DONE'. Win probability 0.127 (AEF 0.282), primary miss +15.6.", "OPEN", "", "docs/DECISIONS.md 2026-10-07; docs/NEXT-STEPS.md (Overcalled independents); " + LED)

# ---------------------------------------------------------------- wa2025
model("wa2025", "Pilbara", "Old note: primary miss ran against us by 8.3. It no longer does: Labor is now over-predicted by 3.7 and called at 0.756 (AEF 0.674). The cause of the change was not traced; the WA seat-swing nudge (2026-10-06) is a candidate but nothing isolates it.", "UNVERIFIED", "", "docs/DECISIONS.md 2026-10-06 (WA seat-swing nudge); " + LED)

# ============================================================== big misses with no earlier note
# (winner got under 25% from us in the 2026-10-19 ledger). Written only from evidence in docs/.
model("fed2025", "Melbourne", "Reason unknown. Labor won the Greens leader's seat (Bandt); win probability 0.006 (AEF 0.119). A Greens 'under-concentration' idea was retracted; the leader-seat bonus for Bandt was resized 2026-09-30 and a RedBridge poll mis-entry was corrected 2026-10-18 with no visible effect. Group D 'missed together, cause unknown'.", "OPEN", "", "docs/plans/prereg-leader-bonus-size-2026-09-30.md; docs/DECISIONS.md 2026-10-18; docs/reviews/greens-under-concentration-2026-09-15.md")
fact("fed2025", "Melbourne", "The Greens leader's seat (Adam Bandt).", "docs/plans/prereg-leader-bonus-size-2026-09-30.md")
fact("fed2025", "Dickson", "Peter Dutton's seat (the opposition leader).", "docs/plans/prereg-leader-bonus-size-2026-09-30.md")
model("fed2025", "Dickson", "Reason unknown. Labor won at p 0.085 (AEF 0.230), primary miss +7.7. The model has a leader's-seat bonus (resized 2026-09-30) but no explanation for this miss is written down.", "OPEN", "", "docs/plans/prereg-leader-bonus-size-2026-09-30.md; " + LED)
model("fed2025", "Hughes", "Part of the national Labor under-call in fed2025: Labor primary averaged 30.2 predicted vs 34.8 actual over 150 seats (Hughes 28.5 vs 39.0), plus Right-wing preference flows to the Liberals that had masked it. Not seat-specific. Labor 0.060 (AEF 0.090). The 2026-10-12 time-forward flow trees were shipped but the primary under-call remains.", "OPEN", "", "docs/reviews/lnp-onp-flows-by-election-2026-10-11.md; " + LED)
model("fed2025", "Forde", "Same national Labor under-call as Hughes (Forde Labor 26.4 predicted vs 34.2 actual). Labor 0.129 (AEF 0.096).", "OPEN", "", "docs/reviews/lnp-onp-flows-by-election-2026-10-11.md; " + LED)
model("fed2025", "Leichhardt", "Same national Labor under-call as Hughes (Leichhardt Labor 25.3 predicted vs 36.5 actual). Labor 0.185 (AEF 0.257).", "OPEN", "", "docs/reviews/lnp-onp-flows-by-election-2026-10-11.md; " + LED)
model("fed2025", "Griffith", "Reason unknown (group D 'missed together, cause unknown', with fed2022 Griffith/Brisbane/Ryan). The Greens were over-predicted this time and Labor won: Labor 0.165 (AEF 0.279), primary miss +7.3. The earlier Greens 'under-concentration' idea was retracted.", "OPEN", "", "docs/reviews/greens-under-concentration-2026-09-15.md; " + LED)
model("fed2025", "Petrie", "Hand-labelled ledger failure group A, state swing (label not re-checked against a state result). Labor 0.141 (AEF 0.061).", "OPEN", "", "output/aef7-seat-groups.csv; docs/plans/prereg-state-deviation-2026-09-15.md; " + LED)
model("fed2025", "Banks", "Hand-labelled ledger failure group A, state swing (label not re-checked). Labor 0.229 (AEF 0.191), primary miss +3.3.", "OPEN", "", "output/aef7-seat-groups.csv; " + LED)
model("fed2025", "Monash", "Independent Russell Broadbent (ex-Liberal) was over-carried: we favoured the independent and the Liberals won. The federal-only defector carry (2026-10-05) pulled our independent share down 34.1 -> 29.5 (actual 27.3) but the Liberals still won at only 0.176 (AEF 0.676).", "PARTLY", "AUSPOL_DEFECT_BY_LEVEL=2 (2026-10-05)", "docs/plans/prereg-defector-by-level-2026-10-05.md; " + LED)
fact("fed2025", "Monash", "Sitting member Russell Broadbent left the Liberals and recontested as an independent.", "docs/plans/prereg-defector-by-level-2026-10-05.md")
model("fed2025", "Wannon", "Independent over-call: we favoured the independent and the Liberal won (0.203; AEF 0.659). Listed in prereg-growth-ratio as 'a separate question, next'. No seat-level cause written.", "OPEN", "", "docs/plans/prereg-growth-ratio-features-2026-10-18.md; " + LED)
model("fed2025", "Cowper", "Independent over-call (favoured the independent, the Nationals won at 0.232, AEF 0.442). Same unexplained group as Wannon and Monash.", "OPEN", "", "docs/plans/prereg-growth-ratio-features-2026-10-18.md; " + LED)
model("fed2025", "Bonner", "Reason unknown. Labor won at 0.224 (AEF 0.095), primary miss +11.0; probably the same national Labor under-call as Hughes but not traced.", "OPEN", "", LED)
model("fed2025", "Menzies", "Reason unknown. Labor won at 0.218 (AEF 0.196), primary miss +5.4.", "OPEN", "", LED)

model("fed2022", "North Sydney", "Ledger failure group B, independent from nowhere (Kylea Tink). Independent 0.213 (AEF 0.336), primary miss +7.6. The general teal/independent under-call is PARKED by Pete.", "OPEN", "", "output/aef7-seat-groups.csv; docs/NEXT-STEPS.md (Teal/independent under-call); " + LED)

model("qld2024", "Maryborough", "One Nation surge in a regional seat ate the Labor primary (Labor 45.1 vs 38.6, One Nation 10.0 vs 15.4). Registry verdict OPEN, tails (One Nation concentration). LNP 0.166 (AEF 0.055).", "OPEN", "", "docs/SEAT-REGISTRY.md (qld2024 Maryborough); " + LED)
model("qld2024", "Ipswich West", "A 2021-24 by-election seat: the by-election baseline overstates a protest swing (LNP 40 at the by-election fell to 34). A half blend shipped, yet the LNP won at only 0.141 against AEF 0.581. Candidate cause only; not traced for the general election.", "PARTLY", "AUSPOL_BYELECTION_PRIOR=blend (2026-09-18) addresses the baseline only", "docs/SEAT-REGISTRY.md (qld2024 by-elections); " + LED)
model("qld2024", "Bundaberg", "Reason unknown. Labor won at 0.135 (AEF 0.181), primary miss +6.3.", "OPEN", "", LED)
model("qld2024", "Capalaba", "Reason unknown. LNP won at 0.154 (AEF 0.214), primary miss +7.3.", "OPEN", "", LED)
model("qld2024", "Mulgrave", "Reason unknown. LNP won at 0.229 against AEF 0.021, so we beat AEF here; the LNP primary was over- not under-called (-4.6).", "OPEN", "", LED)

model("vic2022", "Northcote", "Reason unknown. Labor won at 0.146 (AEF 0.162), primary miss +6.6 (Greens versus Labor seat). The vic2022 Labor/Greens seats were traced 2026-10-10 to the Liberal primary under-called statewide by 3.1 (day-before trend lagged late polls) after the card-flow fix (AUSPOL_HTV_FLOW) shipped; Northcote itself is not named.", "OPEN", "", "docs/SEAT-REGISTRY.md (vic2022 Footscray, Richmond, Brunswick, Pascoe Vale, Preston); " + LED)

model("sa2026", "Bragg", "Reason unknown. LNP won at 0.190 against AEF 0.540, primary miss +9.6. The only mention is an earlier One Nation allocation residual (+11.8).", "OPEN", "", "docs/reviews/onp-allocation-sa-2026-08-17.md; " + LED)

model("wa2025", "Kalamunda", "Reason unknown. LNP won at 0.113 against AEF 0.662; primary miss only +0.6, so this is a flow/two-candidate call, not a vote-share miss.", "OPEN", "", LED)
model("wa2025", "Murray-Wellington", "Reason unknown. LNP won at 0.194 (AEF 0.278), primary miss +0.4. (The NEXT-STEPS note about Murray-Wellington is wa2017, a different election.)", "OPEN", "", LED)

model("nsw2023", "Holsworthy", "Reason unknown. LNP won at 0.209 against AEF 0.546, primary miss +2.5.", "OPEN", "", LED)

with open("docs/aef7-seat-notes.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["election", "seat", "kind", "text", "status", "fixed_by", "source"])
    w.writerows(R)
print(len(R), "rows")
