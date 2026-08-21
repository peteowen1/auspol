# Queensland is scorable now. Coordinates did not improve the cycles that already worked.

Run 2026-08-20. Two results, one positive and one negative, and the negative
one refutes the reason the work was started.

## What was built

`scripts/build_correspondence.R` assigns each AEC polling place to whichever
state electoral district contains it, using AEC coordinates (99-100% coverage)
and ABS state electoral boundaries. It replaces nothing that already works; it
creates what did not exist.

**Queensland 2020 and 2024 now have correspondences**, 93 of 93 districts each.
Seats available to test a feature against `fed_swing`: **180 to 548**.

## Why Queensland is trusted without a reference to check it against

Queensland has no published `fed_swing`, so there is no direct check. Two
indirect ones:

- **Reproduction.** ABS SED_2021 carries Victoria on 2018 boundaries and NSW on
  2019 boundaries, the vintages two shipped correspondences describe. Rebuilding
  those from coordinates alone agrees with the hand-built files on **97.8%** and
  **97.7%** of booths.
- **Anchor check.** The transposed statewide mean is **−4.14** for qld2020
  against Queensland's actual federal-2019 swing of about −4.3, and **+4.67**
  for qld2024 against about +4.3.

## The negative result: coordinates are not better where a comparison exists

The stated motivation was that the shipped correspondences match booths through
a **federal division name** carrying whichever redistribution was current when
they were written — which is why `booths-2018vic.txt` needs 192 name-fallback
matches against federal 2016. Coordinates do not consult division names at all,
so they should be cleaner.

Measured against the published `fed_swing`:

| cycle | shipped | coordinates |
|---|---|---|
| VIC 2022 | **r = 0.952**, MAD 1.97 | **r = 0.862**, MAD 2.15 |
| NSW 2023 | r = 0.949, MAD 3.11 | r = 0.951, MAD 3.07 |

**Worse for Victoria, a wash for NSW.** The `r < 0.9` guard fired and refused to
write the output.

The reference is **not independent** — the published `fed_swing` comes from the
same repository that ships the correspondences, so agreement partly rewards
shared method. That means this test cannot *vindicate* coordinates. It also
means there is no evidence for them and one number against, so **the shipped
files keep the four cycles they cover** and coordinates are used only for
Queensland, where they compete with nothing.

**Why Victoria degrades is not explained.** The correlation falls a long way
while the mean absolute difference barely moves, which is the signature of a few
large outliers rather than a uniform loss. Those outliers have not been
identified. Open.

## Queensland 2020 gains nothing, for a reason that was not on the list

| election | baseline MAE | gain from `fed_swing` |
|---|---:|---:|
| **qld2020** | **1.676** | **−0.285** |
| vic2018 | 3.153 | −0.202 |
| vic2022 | 3.351 | +0.330 |
| nsw2019 | 3.399 | −0.050 |
| nsw2023 | 4.508 | +0.377 |

This morning's review attributed the negative cycles to a noisy measure. **That
cannot explain qld2020**, whose correspondence is the cleanest of the five — an
exact ID join, 93 of 93 districts, anchor-checked statewide.

What is different is the election. Its baseline MAE is **1.676** against 3.2-4.5
everywhere else: Queensland 2020 swung almost uniformly, so **there was nothing
for any predictor to explain**, and a fixed coefficient only added noise.

That makes `docs/reviews/fed-swing-coefficient-2026-08-20.md` **incomplete
rather than wrong**, and it raises a question about the live model that is not
answered here: `SEAT_SWING_COEF` is applied to Victoria 2026 unconditionally,
and on this evidence its value depends on a property of the election — how much
seats disperse around the statewide swing — that is not known in advance.

Five elections cannot fit that relationship. Recorded, not acted on.

## A guard that could not fail, caught by its own output

`districts()` read a fixed column name, and the ABS suffixes those with the
vintage year: SED_2021 has `SED_NAME21`, SED_2022 has `SED_NAME22`. Against
SED_2022 the filter selected **zero** districts.

The completeness check read `got < want`, which was `1 < 0`, which is `FALSE`.
**Three empty correspondence files were written and reported as successes.**
Fixed to `got != want`, plus a floor rejecting any state resolving to fewer than
20 districts.

Same family as the entries already in `CLAUDE.md`, and it survived precisely
because a comparison written the natural way is one-sided.

## Western Australia cannot be done this way

Its 2023 redistribution postdates every ABS vintage published. SED_2021 and
SED_2022 both carry the pre-redistribution districts, six of which — Bibra Lake,
Girrawheen, Mid-West, Mindarie, Oakford, Secret Harbour — do not appear at all.
It needs a WAEC shapefile, not another ABS download. **59 seats, still blocked.**
