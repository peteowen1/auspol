# Pre-registration: let the xgb layer learn where a party's growth lands (2026-10-18)

Committed BEFORE anything is built or run. Pete, 18 Oct 00:xx, on fed2025 vs AEF (Melbourne: notional ALP 25.2
-> our base 22.2 -> actual 31.3, One Nation 0.8 -> 6.1 -> 2.5): "this is big we need to fix this --
alp/lnp/grn/onp should gain/fall where we expect not just same number every seat ... remember to do a universal
fix not just a hack". Evidence: NEXT-STEPS (18 Oct entries), scratchpad `alloc2.R`, `ratio.R`, `slopes.R`.

## What the component tests settled (actual statewide level fed in, time-forward, stood-both-times cells)

Every one-formula rule loses to the shipped linear slope (`dev_slope()`): seat RMSE linear 4.99-5.09, uniform
5.27, proportional 6.40, logit slope 5.35, growth-ratio slope 5.52; flat+proportional blend within noise.
ROOT: a minor class's realised slope swings between elections (One Nation 0.19 in wa2021 to 1.95 in wa2025, sd
0.64; independents sd 0.26; majors sd 0.12-0.15) and tracks the class's growth in hindsight -- a surge keeps
strongholds ahead, a collapse pulls every seat toward zero -- but one time-forward constant cannot know which
year it is in. The xgb layer has `seat_prev_pcv`, `level_prev`, `level_pred`, `dev_prev`, so in principle it
can learn it, and trims about a third of the fed2025 One Nation miss; a tree cannot easily build
ratio x deviation out of splits.

## Arm

| Arm | Switch | Rule |
|---|---|---|
| A (shipped) | `AUSPOL_XGB_RATIO_FEATS=0` | as published. |
| R | `AUSPOL_XGB_RATIO_FEATS=1` | two xgb features added, models retrained (stages 3-5), every target as at its day. |

- `growth_ratio = (level_pred + 0.5) / (level_prev + 0.5)`: the class's predicted statewide growth (pre-election:
  `level_pred` is the forecast's own level). The 0.5-point offset keeps a class new to the state finite.
- `ratio_dev = (growth_ratio - 1) * dev_prev`: how far proportional growth would move this seat beyond a flat
  swing (0 when the class is steady or the seat sits at the state average).

Built in the training table (`scripts/fit_xgb_primary_v6.R`) and in live prediction (`R/xgb_primary_override.R`)
from the same inputs; switch off leaves both byte-identical. No new data, no new fit beyond the retrain.

## Criterion

Needs a full rebuild from stage 3 (the xgb models are retrained), in an ISOLATED COPY of the repo (copied
`output/` and `external/`, never junctions), against the published rebuild `20261017-2242-c0e3b37-from6`.

1. **Primary: seat share RMSE of the published path on minor classes (ONP, IND, OTH_RIGHT, OTH, GRN)**, all
   elections, SE clustered on election. R must be lower by more than 1 SE. (The change targets where minor growth
   lands; majors are the guard.)
2. **Guard: seat log loss, all 35 elections**, not worse by more than 1 SE; ALP/LNP share RMSE not worse by more
   than 1 SE.
3. **Reported:** fed2025 One Nation miss by previous-share band (the motivating case); Melbourne fed2025; the
   surge elections (sa2026, wa2025, qld2017) and collapse elections (wa2021, qld2020) separately; AEF-7.

Shipping is Pete's call on the result.

## What would make an apparent win unacceptable (decided now)

- One election supplies more than half the primary gain -> refused.
- The live vic2026 One Nation level (statewide) moves by more than 1 point: the features should move where One
  Nation's vote lands, not how much of it there is; reported to Pete before shipping.

## What this cannot see

- A seat's own pre-election signal of growth (local campaign, candidate) beyond what the features already carry.
- Independents' over-call (Melbourne 1.0 -> 6.7, fed2025 Wannon/Monash/McMahon/Cowper favoured and lost) is a
  separate question: next, once this one is scored.
