# AEF-7 gap diagnosis and the `sal` screen (2026-11-07)

Moved verbatim from `NEXT-STEPS.md` on 7 Nov (hub slimming); nothing here was re-run.

## 1. `AUSPOL_MC_EXTRA=sal` screen: no route to the forecast helps

OPEN, PARTLY DONE 6 Nov (`AUSPOL_MC_EXTRA=sal`: independents' RMSE 7.86 -> 7.57; not shipped). SCREENED 7 Nov 12:27am
(refit on the OTH_RIGHT key fix; 1,000 sims, 35 elections): it CANNOT reach the shipped split, which reads `pred_naive`
(`AUSPOL_BUCKET_SPLIT=cand_naive`, `R/forecast_statewide.R:217`; arm byte-identical on 35 of 35). Via
`cand_resid` + the sal file: seat log loss -0.0000 (SE 0.0006), AEF-7 -0.0015 (SE 0.0018), changed-cell share error
+2% (+2,583, SE 1,357, FAIL), sa2026 +0.011. Separated 1:00am: `cand_resid` on the plain -v2 file is seat log loss
+0.0004 (SE 0.0005), AEF-7 +0.0000, shares +3,216 (SE 1,363, worse by >2 SE). So the residual column loses to naive and
sal recovers part of it; neither beats what ships. sal has no route to the forecast that helps (class split refused 6 Nov).
Refits are 73 s now with `AUSPOL_MC_ROUNDS_FROM=<earlier oof csv>` (7dd04a82; exact on the same features). The per-candidate
model gives a newcomer independent the generic 4-8% beside a sitting member (Jones 4.8 vs 12.1, Holmes-Ross 4.3 vs 14.6,
Leonard 7.6 vs 17.1). Table in `reviews/two-candidates-one-class-2026-11-06.md`.

## 2. Where we lose to AEF on AEF-7 (Pete, 7 Nov)

Ledger of 7 Nov 12:16pm (commit 49f19560): seat log loss ours 0.2572, AEF 0.2825 (681 seats; lower is better). We lose
fed2022 (+0.010) and fed2025 (+0.028), win the five state elections. Summed log-loss gap by contest: ALP v LNP -18.3
(611 seats), ONP/OTH_RIGHT -4.6 (10), IND +2.4 (44), GRN +1.5 (18).

Proxies, all 35 elections, `output/published-predictions.csv` of 12:16pm:
- (a) Flattening win probs in IND/GRN contests REFUSED as a lead (IND AEF-7 worse at every temperature, 2 of 7; GRN
  -0.02, 10 of 22, in noise). With C2's 17 Oct loss that is two refusals of "widen IND/GRN": the losses are wrong
  centres on winners we gave 2-30% (30 of the 62 summed log-loss points in IND/GRN contests).
- (b) Unpolled IND by salience (`jump`, every row, SE on election): +0.8 zero (n 808), +1.4 low (298), +2.3 mid (SE 1.3,
  118 cells), +1.8 top 15% (SE 1.75, 51): weak. (An earlier cut on candidates with actual or ours >= 10 selected on the
  outcome and overstated this as +3.8 -> +5.4; corrected in chat.)
- (c) Ipswich West: by-election half blend (`AUSPOL_BYELECTION_PRIOR=blend`, fixed 0.5, never fitted) took LNP base
  21.1 -> 37.2, xgb 45.0, actual 33.5. CHECKED: on 34 both-major by-elections in 12 elections (68 ALP/LNP cells,
  residual after the non-by-election seats' swing) the fitted weight is 0.62 (jackknife SE 0.11 over seats), MAE minimum
  at 0.5 (4.86; 0 gives 6.52, 0.75 gives 5.18, 1 gives 6.02); no gap-to-election trend (0.54 under 12 months, 0.87 over
  24). 0.5 stands, no prereg. Ipswich West's extra +7.8 is the xgb layer, one seat.
- (d) fed2022 direct IND polls +3.2 low, we stayed +10.6 low (7 cells). Only 49 of 492 IND candidates on 10%+ had a
  seat poll naming them.
- Calibration, every IND candidate (35 elections): stated under 2%, 2,730 candidates, 1.4 expected wins, 11 actual;
  70-90%, 30 candidates, 24.8 expected, 21 actual. GRN 2-10%: 38 candidates, 1.7 expected, 5 actual.

Scripts: session scratchpad `aefgap/a1-a7.R`, `b1.R` (not kept).
