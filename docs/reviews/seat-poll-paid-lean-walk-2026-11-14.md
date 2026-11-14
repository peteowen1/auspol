# Paid seat polls lean toward their sponsor: walk before any fit (14 Nov 2026)

Open part of Pete's 13 Nov paid-poll request: statewide polls got arm PPC (shipped, PR #235); paid SEAT polls already
get a wider noise floor (`direct_stake`, arm H, 18 Oct) but no lean correction. Script: `scripts/walk_paid_seat_polls.R`.

## Measure

For each direct seat poll (MRP and opt-in excluded) of fed2016-fed2025 and nsw2023, the sponsor side's share in the poll
minus its actual share in that seat:

- primary when the poll names ALP, LNP and GRN (named figures scaled to 100); else
- two-candidate share when the poll's pair is the AEC's final pair (federal only).

Side from `sponsor_side.csv` (`paid_poll_side()`), sponsor from `poll_methods.csv`. The same measure on INDEPENDENT
direct seat polls of the same election and side is the baseline (fed2022 polls overstated Labor by 8 points
everywhere, so a raw gap is not a lean).

## Result

68 paid seat polls on file; 29 measurable (the other 39 are mostly Climate 200 polls giving only the Liberal primary
and no two-candidate pair matching the result). Points; positive = the poll overstated its sponsor's side.

| sponsor side | n | raw gap | independent polls, same side | net |
|---|---|---|---|---|
| LNP (Advance, energy and forestry lobbies, Nationals) | 11 | +8.08 | +3.84 | +4.24 |
| ALP+GRN (Australia Institute, GetUp) | 7 | +4.35 | +0.48 | +3.88 |
| IND (Climate 200) | 7 | +1.69 | +2.45 | -0.76 |
| GRN (Greens) | 2 | +5.48 | -0.72 | +6.20 |
| ALP (unions) | 2 | +10.88 | +7.33 | +3.55 |
| **all** | **29** | | | **+3.03 (SE 0.92), 20 of 29 positive** |

Independent direct seat polls: rms primary error per party 4.71 points (59 polls); two-candidate error rms 6.13 (41).

Caveats: 21 of 29 are fed2025; IND is mostly measured on two-candidate figures against a primary baseline; the SE
treats polls as independent (several share a sponsor and a day, e.g. Advance's six 16 Mar 2025 polls).

## Live

vic2026 has one paid seat poll: Hawthorn, Freshwater for a group of Liberal Party members (16 Aug 2025, LNP 41).

## Status

OPEN: walked with Pete before any fit (model-design rule). If built: per-side shrunk lean like arm PPC, pooled across
sides, fitted time-forward on seat results, screened on seat log loss across every election with paid seat polls.
