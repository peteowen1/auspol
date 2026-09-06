# Where the seat model misses, and why — 2026-09-06

Pete's question: which elections do we forecast, how do we score against AE
Forecasts, and are the big misses polling misses we cannot fix or patterns in
our model that we can. Everything below is measured from files on disk on
2026-09-06; the scripts that produced each table are in the session, and the
per-party table the federal harness now writes (`backtest-fed-allprobs*.csv`)
is what made the last section answerable.

## 1. What we forecast, and on what terms

| harness | elections | statewide input | AEF overlap |
|---|---|---|---|
| `backtest_candidate_fed.R` | fed2010, 2013, 2016, 2019, 2022, 2025 | **polls as at election day** (`AUSPOL_FORECAST_MODE=1`, `trend_as_at()` + fundamentals) | fed2022, fed2025 — a fair comparison |
| `_vic.R` | vic2018, vic2022 | the ACTUAL statewide result, injected | vic2022 — we are advantaged |
| `_nsw.R` | nsw2023 | actual | nsw2023 — advantaged |
| `_sa.R` | sa2026 | actual | sa2026 — advantaged |
| `_wa.R` | wa2001 … wa2025 (7 pairs) | actual | wa2025 — advantaged |

So "a forecast with data as at election date" exists for the six federal
elections only. The four state harnesses measure the seat model given a
perfect statewide call. AEF also archives qld2024 and sa2022, which we have no
harness for.

## 2. Scores, and which configuration they describe

The harness run that produced last session's headline (`fed2025 0.2886`) had
`AUSPOL_IND_SALIENCE=1` (the v1 national-level salience ratio, which
`fit_seats_full.R` does NOT read) and `AUSPOL_SALIENCE_SURGE_V2` **off**
(which `fit_seats_full.R` has **on** by default since 2026-09-04). What was
measured was not what ships. Re-run with surge-v2 on, seed 42:

| election | n | harness as run yesterday (v1 ratio ON, surge OFF) | + surge-v2 (v1 still ON) | **what ships** (`published_flags.R`) | AEF |
|---|--:|--:|--:|--:|--:|
| fed2010 | 147 | 0.4525 | 0.3963 | **0.3963** (Brier 0.1000) | — |
| fed2013 | 150 | 0.4386 | 0.3817 | **0.3817** (0.1012) | — |
| fed2016 | 147 | 0.4080 | 0.3924 | **0.3814** (0.0965) | — |
| fed2019 | 143 | 0.2619 | 0.2643 | **0.2643** (0.0842) | — |
| fed2022 | 150 | 0.6065 | 0.4804 | **0.4960** (0.1104, accuracy 87.3%) | **0.2353** |
| fed2025 | 150 | 0.2898 | 0.3017 | **0.3103** (0.0931) | **0.3025** |
| **six-pair mean** | 887 | 0.4096 | 0.3695 | **0.3717** (Brier 0.0976) | |
| vic2018 | 88 | 0.3212 | — | **0.3218** | — |
| vic2022 | 78 | 0.2258 | — | **0.2466** | 0.2572 (we are advantaged) |
| nsw2023 | 88 | 0.4252 | — | **0.3251** | 0.2138 (advantaged, still behind) |
| sa2026 | 47 | 0.3867 | — | **0.3865** (accuracy 76.6%) | 0.3525 (advantaged, still behind) |
| wa2025 | 53 | 0.2589 | — | **0.2787** | 0.3537 (advantaged) |

**Superseded the same night by the rule-2 baseline** (P1 shipped; see
`prereg-vote-belongs-to-the-person-2026-09-06.md`), published defaults, seed
42, log loss / seat-share RMSE: fed2010 0.4047 / 3.84, fed2013 0.3807 / 4.72,
fed2016 0.3566 / 4.84, fed2019 0.2639 / 4.73, fed2022 0.4819 / 4.56, fed2025
0.3037 / 4.30 (six-pair mean **0.3653**, Brier 0.0977); vic2018 0.3218 / 4.90,
vic2022 0.2466 / 4.75, nsw2023 0.3085 / 5.20, sa2026 0.3409 / 4.84, wa2025
0.2787 / 4.09 (wa pooled Brier 0.0995). That column, not this one, is what
P4 is measured against.

The "what ships" column is the baseline every future number in this repo is
measured against: `scripts/published_flags.R` applied to a bare harness run,
fingerprints `a9e385c` (fed), `a8447fb` (sa) and their siblings. Removing the
v1 ratio is visible where it was doing damage: fed2022 accuracy 85.3 → 87.3%
and its best Brier of the three columns (Cowper, Hunter and Mallee were the
v1 multiplier's work), fed2016 0.3924 → 0.3814. fed2025 is now **0.008
behind** AEF, not ahead.

Log loss throughout (the repo's primary metric). Surge-v2 lowers the six-pair
mean by 0.040 against the v1-only column and raises Brier in every pair: the shape of a hedge that
spreads a little probability everywhere, scored under a metric that punishes
zeros without limit. Surge-v2's fed2022 gain is
almost entirely the log-loss clamp: North Sydney, Goldstein and Fowler move
from 0.000 to 0.004, worth 5–8 each at `eps = 1e-6`, while it costs real
probability in safe seats (Hume 0.85 → 0.73, Flinders 0.90 → 0.78). It hedges;
it does not forecast an emergence.

**P0 — DONE 2026-09-06 evening.** `scripts/published_flags.R` is the one
registry; `fit_seats_full.R` (whose RUN_FLAGS list still said shrink 0.10)
and all five harnesses apply it to every unset switch. The forecast's outputs
are byte-identical before and after, so the registry equals the code
defaults; the "what ships" column above is the re-baseline.

## 3. The misses, classified

44 seats across every harness where the winner got under 0.10 from us. Federal
misses decomposed on the ALP two-party scale into national poll error, the
state's deviation from the national swing, and the seat's own residual.

### A. A first-time independent (16 of 44, and the bulk of every gap to AEF)

fed2022 excess log cost against AEF is **55.7 over 150 seats; 80% of it is
the 11 seats an independent won**. NSW's entire gap is Wakehurst and Kiama.
Denison and Lyne 2010, Indi 2013, Mayo 2016, Warringah 2019, the six teals and
Fowler 2022, Wakehurst and Kiama 2023, Morwell 2018, Pilbara 2001, Kalgoorlie
2008 — every independent miss is an emergence or a defector.

Two sub-types with different fixes:

- **Emergence proper** (teals, Wilkie, McGowan, Steggall, Regan). AEF had
  0.30–0.69 on all of them pre-election; surge-v2 as shipped gives 0.000–0.015,
  Mackellar 0.10. The salience signal (AUC 0.82–0.96) exists; the hazard that
  uses it is scaled to a mean of 0.012 per seat.
- **Defector recontesting as IND** (Kiama 2023: Ward 53.6% as LNP → 38.8% as
  IND, we gave 0.007; Morwell 2018: Northe 44.4% NAT → 19.6% IND and won; Lyne
  2010, Pilbara 2001, Kalgoorlie 2008). `major_discount` fitted at 0.28–0.31
  floors the base at ~15% for Ward. The fitted mean is right for the average
  defector and wrong for every one who wins.

### B. Independent OVER-prediction (11 false IND calls in 886 federal seats)

Cowper 2022 (0.83 to an IND who lost 47.6–52.4), Hunter 2022 (0.53), Mallee
2022 (0.51), New England 2013 (0.99) and 2016 (0.95), Lyne 2013, Dobell 2016,
Tangney 2016, Kennedy 2013, Cowper 2025, Goldstein 2025. AEF called Cowper and
Goldstein 2025 for the IND too (0.55, 0.64); the rest are ours alone. Traced
to three mechanisms, each with the number from the trace run:

| seat, 2022 | our IND share into the sim | actual | mechanism |
|---|--:|--:|---|
| Cowper | 35.9 | 26.3 | the v1 **national IND multiplier** (2019 level 3.70 → predicted 5.78, ×1.56) applied uniformly to Oakeshott's 22.6% inheritance |
| Hunter | 24.3 IND **+ 17.6 ONP** | 7.5 + 10.0 | **double count**: Bonds' 21.6% as ONP in 2019 becomes his personal IND base AND stays in the ONP class |
| Mallee | 31.0 | 12.2 | **fragmentation**: three 2019 independents (8.3 + 8.2 + 2.6) summed into one competitor |

Flows are NOT the problem: ALP → IND when the survivors are {IND, LNP} is 76%
in 2010–2019, 76% in 2022 and 76% in 2025 (Cowper realised 71%). On the
correct shares the simulator would have Cowper at about 47–53, a loss.

New England 2013/2016, Lyne 2013 and Dobell 2016 are the same shape from the
other side: a departed or defeated independent's class share carried to the
next election. Nomination zeroing only fires when NO independent stands.

### C. State-level swing, unmodelled (major-vs-major misses)

The federal simulator applies the national swing plus iid seat noise; there is
no state term. Measured deviation of each state's swing from the national one:

| election | between-state sd | within-state sd | largest |
|---|--:|--:|---|
| fed2010 | 2.98 | 3.22 | TAS +8.1, VIC +3.7, SA +3.5 |
| fed2013 | 1.81 | 2.35 | TAS −6.5 |
| fed2016 | 1.28 | 3.50 | NT +4.3, TAS +2.8 |
| fed2019 | 1.92 | 3.37 | QLD −2.9, ACT +3.9 |
| fed2022 | 2.95 | 3.34 | **WA +7.2**, TAS −5.8 |
| fed2025 | 2.08 | 3.59 | **TAS +9.2**, ACT +3.8 |

Roughly 20–45% of seat-level swing variance is state-shared, and it is the
whole story in Braddon 2013 and 2025, Lyons 2013, and Tangney, Pearce and Swan
2022 (the WA bucket is 6% of the fed2022 excess). The anchor holds state poll
breakdowns for 2025fed only (`analysis/Regional/2025fed-polls.csv`), so the
centre can come from data in the live cycle and the spread must come from
these six elections.

### D. National poll error (not model-fixable)

Projection minus actual on ALP TPP: 2010 +3.4, 2013 +2.3, 2016 −0.3, 2019
+3.4, 2022 +0.1, 2025 −2.1. The fundamentals blend helped in 2019 and 2025 and
hurt in 2010 and 2013. Brisbane and Macquarie 2010, Bass 2019 and the 2025
trio (Hughes, Braddon, Melbourne) are on the wrong side of that error. The
statewide variance is honestly sized (claimed 2.42, realised 2.42, measured
2026-08-22), so the remedy is nothing beyond keeping that variance.

### E. Redistributions without a notional baseline

`output/notional-baselines.csv` covers fed2025 only. Macarthur and Paterson
2016 carry seat residuals of +15.5 and +16.3 points because the model started
from the pre-redistribution seat. Cheap and mechanical for 2010–2022.

### F. Greens and One Nation contests (a separate diagnosis)

fed2025 is the one election where the Greens cost us against AEF: Melbourne
0.010 vs their 0.119, Griffith and Brisbane over-called for the Greens (0.64,
0.45 vs 0.28, 0.34). fed2022 Ryan and Brisbane under-called. South Australia
is a near tie with One Nation allocation wrong in both directions (MacKillop
0.027, Hammond 0.671, Narungga 0.179). Needs one seat walked end to end before
any fix is proposed.

### G. Harness defects found on the way

- **Duplicate columns in the federal statewide draws**: `sw_draws` carries
  IND and OTH_RIGHT twice (means 5.78/4.03 and 1.13/6.10) because the trend
  model already had them and the unmodelled-class `cbind` appended them again.
  `simulate_seat_contests()` takes the first by name. Forecast mode only.
- `output/dump-shares-fed*.csv` is gated and last written 2026-08-28; it
  misled this diagnosis for an hour. Write it every run, fingerprinted.
- The federal harness never wrote per-party probabilities; it does now
  (`backtest-fed-allprobs*.csv`, same shape as SA's).
- The `eps = 1e-6` clamp sits below the simulation's own resolution
  (1/20,000), see NEXT-STEPS.

## 4. Sizing, and the order to fix

fed2022 excess against AEF by bucket: IND won 80%, major-vs-major other
states 8%, false IND calls 6%, WA 6%, Greens 1%, Tasmania −1%. fed2025 we are
level; the residual is Greens and Tasmania.

1. **P0 — harness defaults mirror the published script.** Surge-v2 on in all
   five; decide whether the v1 national ratio ships or goes. Re-baseline every
   number in this file on that config.
2. **P1 — the three IND over-prediction bugs (B).** Targeted, so the primary
   criterion is the named seats: Cowper, Hunter, Mallee 2022; New England 2013
   and 2016; Lyne 2013; Dobell and Tangney 2016. Guard: election-wide log loss
   on all six pairs must not worsen. Fixes, in order of confidence:
   - remove a candidate's personal base from the class they left when
     `personal_prior_vote()` moves it (Hunter);
   - apply the national IND multiplier only where the salience screen permits
     or, better, retire it in favour of the seat-level hazard (Cowper);
   - carry a departed independent's share forward at the "new candidate,
     screen refuses" slope (~0.33), not 1.0 (New England, Lyne, Dobell);
   - fragmentation waits for candidate-count weighting after nominations
     close (already queued for November).
   Also fix G's duplicate columns and the gated dump in the same PR.
3. **P2 — a state term in the federal simulator (C).** General change: a
   shared per-state draw with sd fitted from the six elections' between-state
   deviations (about 2.2 points), correlated across seats in the state, with
   state poll breakdowns as the centre where the anchor has them. Primary:
   six-pair mean log loss; guard: per-state slices, especially Tasmania and WA,
   so a fix that widens everything cannot pass by hedging.
4. **P3 — notional baselines for 2010–2022 (E).** Mechanical. Targets:
   Macarthur and Paterson 2016 first, then every redistributed seat per cycle.
5. **P4 — emergence (A).** The hardest and the biggest. Two directions,
   Pete's call which:
   - inside the model: a pre-registered sweep of the surge-v2 hazard scale so
     a top-decile salience jump carries ~0.3, not 0.01, scored on the 20
     independent-won federal seats with the false-IND list as the guard;
   - outside it: seat polls, betting odds, or a curated list of confirmed
     high-profile independents, which is what AEF's 0.3–0.7 on the teals
     implies they used. Odds are a different kind of input and need a
     decision, not a plan.
   Defectors are a sub-case: fit `major_discount` by whether the candidate
   was the sitting member and by salience, on the 13 known cases.
6. **P5 — Greens and One Nation flows (F).** One seat walked end to end
   (Melbourne 2025, MacKillop 2026) before any variant is fitted.

What no model change fixes: D. Half of the poll-driven federal misses sit on
the wrong side of a 2–3 point national poll error, and the variance already
covers it honestly.
