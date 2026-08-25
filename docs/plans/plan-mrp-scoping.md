# Scoping: can we build MRP? Not as YouGov does it — the blocker is data, not time

Written 2026-08-25, in answer to option 2 of
[../reviews/why-swing-models-cannot-do-this-2026-08-25.md](../reviews/why-swing-models-cannot-do-this-2026-08-25.md):
YouGov predicts seats that break from their own history because MRP rebuilds
each seat from its **people** rather than its past.

**Scoped before estimating any timeline, because the timeline turned out not to
be the constraint.**

## MRP needs respondent-level survey data. We have toplines.

Multilevel regression and poststratification is two halves:

1. **Multilevel regression** — model vote choice on **individual** demographics
   (age, gender, education, location) from survey **respondents**.
2. **Poststratification** — reweight those predictions onto each seat's Census
   composition.

Checked directly. Our poll data is:

```
MidDate, Firm, Brand, @TPP, LNP FP, ALP FP, GRN FP, ONP FP,
UAP FP, DEM FP, OTH FP, GLApp, GLDis, Comments
```

**Published toplines only. No respondent records, no crosstabs, no
demographics.** `ANCHOR-MODEL.md:142` already records this as "polls enter as
topline numbers only."

**There is nothing to run the regression half on.** This is not a
"months of work" problem — it is a missing input that cannot be manufactured
from what we hold. A timeline for building MRP on this data would be fiction.

## What is actually available

| input | status |
|---|---|
| respondent-level poll data | **absent**, and not obtainable without a commercial arrangement |
| ABS Census at CED/SED | **absent** — no census or ABS files anywhere in `external/` |
| booth-level results | **present**, in the anchor's archive (`booths-2022vic.txt`, `booths-2018sa.txt`, and siblings) |
| Australian Election Study | absent, but **publicly available** |

## The two realistic paths, neither of which is MRP

### Path A — booth-level ecological regression (what theswingison actually does)

`docs/plans/product-features.md:74` describes their method: *"booth-level
regression on 2021 Census per demographic category; a correction for groups
being geographically concentrated; then calibration to each electorate's own
actual result."* Age and gender additionally informed by the AES.

**That is not MRP.** It infers demographic voting patterns from **aggregate**
booth results against booth-area demographics — ecological regression — rather
than from individual respondents. It is vulnerable to the ecological fallacy in
a way MRP is not, which is presumably why they calibrate back to each seat's
actual result.

**We have the booth results. We would need Census at booth or SA1 geography.**
That is a real, bounded acquisition task and the ABS publishes it.

### Path B — Australian Election Study as the respondent source

The AES is a genuine respondent-level academic survey with demographics, run
since 1987, publicly available. It is the only individual-level Australian
voting data we could obtain without buying it.

**Its limits are severe for this purpose.** It is **post-election**, so it
cannot inform a forecast of the election it surveys — only the next one. And it
is roughly 2,000 respondents nationally, which is a handful per seat and
essentially nothing per Victorian district.

So AES can **calibrate** demographic vote propensities; it cannot substitute
for live polling.

## Honest verdict on the timeline

**Neither path is deliverable before 28 November 2026, and MRP proper is not
deliverable at all on current data.**

- Path A needs Census acquisition at a new geography, a booth-to-seat
  correspondence, an ecological regression, and validation — and it would be
  the largest single piece of work in this repo's history.
- Path B needs AES acquisition and would still leave the live-forecast problem
  unsolved.
- Both would then need to beat a uniform swing model that has, this session,
  survived proportional, proximity-weighted, magnitude-dependent, cross-party
  and concentration-based alternatives.

**Recording that plainly rather than starting it and half-finishing it**, which
is what the option-2 review recommended.

## What this changes about the original framing

The review said MRP was "months, not days". **That understated it.** MRP as
YouGov does it is not a scheduling question — we do not hold, and cannot cheaply
obtain, the input its first half requires. What is achievable is Path A, which
is a *different technique* with a known weakness (ecological inference), and
which is what our other competitor actually built.

**If demographics are the direction, Path A is the project**, and it should be
named as booth-level ecological regression rather than MRP so nobody expects
YouGov's method from it.

## Recommended sequencing

1. **Nothing before 28 November.** The Victorian forecast ships on the current
   model plus whatever the salience work delivers.
2. **After the election**, if demographics are still wanted: acquire ABS Census
   at SA1/booth geography and build Path A against the elections already in the
   corpus, where it can be validated out of sample.
3. **Score it against uniform swing before adopting anything.** That bar has
   survived five alternatives this session and should not be waived for a
   technique because it is fashionable or because a competitor uses it.
