# fed_swing computed for twice as many seats — and the constant we shipped today may be too large

Run 2026-08-20. `scripts/transpose_fed_swing.R`.

## Why

`fed_swing` is the strongest seat-level predictor in this model (t = 8.46) and
exists in exactly **two** "before" seat files. So every feature ever proposed as
an addition to it could only be tested on **180 seats** — the binding limit on
feature testing here, and the reason a seat-type variable was dismissed at
F = 0.36 on a sample too small to say much.

The AEC publishes two-party-preferred by polling place with its own per-booth
swing, and the anchor ships booth-to-district correspondences. Joining them
computes `fed_swing` for any state cycle with a correspondence file.

**362 seats now, against 180.**

## Two defects the validation caught

The script recomputes `fed_swing` for the two cycles that already have it, and
refuses to proceed if it cannot reproduce them. It could not, twice.

**A sign error.** The first run returned a correlation of **−0.952** — near
perfect in magnitude, inverted. The AEC's `Swing` column in the two-party file
runs opposite to this repo's "toward Labor" convention. Unflipped, this would
have silently **reversed the strongest predictor in the seat model**, and every
downstream number would have looked plausible.

**A boundary-vintage error.** `booths-2018vic.txt` names Macnamara, Monash,
Cooper, Nicholls and Fraser — all renamed or created in the **2019** federal
redistribution — while the election preceding the November 2018 state poll is
federal **2016**. Matching against 2019 would have worked perfectly and
**leaked**, because that election came after. Renames are mapped back, and a
new division like Fraser falls back to booth-name matching within the state,
restricted to names that are unique.

After both fixes: **VIC 2022 r = +0.952, NSW 2023 r = +0.949**, mean absolute
differences 1.97 and 3.11 points.

## The first thing it found reverses a conclusion from an hour earlier

Seat type on top of `fed_swing`:

| sample | F | p |
|---|---:|---:|
| n = 180, 2 elections | 0.36 | 0.78 |
| **n = 348, 4 elections** | **5.14** | **0.0017** |

**It does add signal.** The earlier "adds nothing" was an artefact of the
underpowered test, and the correction recorded then — that one categorical
variable on 180 seats cannot settle anything — was right for a reason narrower
than stated: the sample, not the variable.

This also revives the demographics case. If a crude four-level proxy is
significant on top of a direct measurement, richer demographics plausibly carry
more.

## And it raises a question about a constant shipped this morning

`SEAT_SWING_COEF = c(fed = 0.7452)` went live today, fitted on the two
elections that had a published `fed_swing`.

| fit | coefficient |
|---|---:|
| published `fed_swing`, 2 elections | **0.7452** — shipped |
| transposed `fed_swing`, **same** 2 elections | 0.6207 |
| transposed `fed_swing`, **4** elections | **0.393** |

The two measures correlate at 0.942, so roughly 17% of the drop is attenuation
— a noisier predictor pulls its own coefficient toward zero. **The rest is a
genuine sample effect.** Correcting for attenuation, the four-election estimate
of the true coefficient is about **0.44**, against the 0.745 now live.

If that holds, the published model is applying the seat-swing adjustment about
**70% too strongly**.

**Nothing has been changed.** This is the same trap the day has been about — a
constant fitted on two elections and moving substantially on four — and the
answer is a pre-registered re-fit against held-out error, not a swap at the end
of a long session. Recorded as the top open item.

## What is now available

`external/elections/fed-swing-transposed.csv`: **543 district-cycles** across
six state cycles (vic2018, vic2022, vic2026, nsw2019, nsw2023, nsw2027),
including the three future cycles where no published `fed_swing` will exist
until the anchor produces one.
