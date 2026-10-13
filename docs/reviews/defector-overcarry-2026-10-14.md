# Defectors are over-called, and the xgb layer doubles it (2026-10-14, measured, not acted on)

**Status: OPEN, needs Pete to walk the rows before any change (model-design rule).**

## How this was found

wa2017 Hillarys (Rob Johnson, sitting Liberal, stood as IND) traced to base_pred: Johnson 28.5 vs actual 20.1,
Liberal 25.6 vs 39.6. The SEAT-REGISTRY note had pointed the other way (WA's own defector carry 0.693 vs the pooled
0.42-0.44), which would have made Hillarys worse. So: is over-carry general?

## Measurement

Source: `output/defector-cases-all.csv` (29 cases; file dated 2026-09-09, before the 13 new elections) joined to
`output/forecasts.csv` (run 4e03af5, the published rebuild) on pair, seat and surname. 18 of 29 matched; the 11
unmatched are name-format or pre-as-at elections (fed2007, wa2001-08) and the four fed cases listed below.

Over-call = predicted primary minus actual, percentage points; positive means we gave the defector too much.

| measure | base_pred | xgb (final primary) |
|---|---|---|
| mean over-call, n=18 | +1.45 | +3.04 |
| median | | +3.18 |
| cases over-called | | 13 of 18 |

Largest: fed2010 Ryan (Michael Johnson) +23.6, sa2026 MacKillop (McBride) +10.1, vic2014 Frankston (Shaw) +8.7,
fed2022 Hughes (Kelly) +7.6, wa2017 Hillarys (Johnson) +7.3. Under-called: nsw2023 Kiama (Ward) -12.4, wa2025
Kalgoorlie and Thornlie -5.0 each, vic2014 Mildura (Cupper, not a sitting member) -3.6.

Unmatched (not scored here): fed2022 Casey, fed2013 Dobell, fed2025 Monash, fed2007 Corio, wa2008 Nedlands,
wa2005 Vasse, wa2001 Pilbara, vic2014 Dandenong, vic2018 Melton, wa2013 Central Wheatbelt, fed2007 Lyons.

## What it suggests (UNVERIFIED)

- The xgb layer adds over-call on top of base_pred (+1.45 -> +3.04). Which feature does it is not checked (SHAP).
- The old party keeps more than modelled where the defector is over-called (Hillarys: Liberal +14 under).
- n=18 and the case list predates the new elections; refresh `defector-cases-all.csv` first.

## Not the same case

wa2013 Churchlands (retired independent, Liberal re-entry) and sa2018 Morphett (McFetridge under-called 23.2 vs 26.3;
the Liberal miss came from ALP/GRN over-calls) are different mechanisms.

Script: `scripts/diag_defector_overcarry.R` (join described above; rerun after refreshing the case file).
