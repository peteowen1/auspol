# South Australia is a real negative, not a measurement artefact

2026-08-27. Follows `salience-new-candidates-2026-08-27.md`, which refused C1
and said sa2026 was **unmeasurable** rather than negative. After fixing three
separate measurement faults, it is measurable, and it still fails.

## What was wrong before, and is now fixed

| fault | effect |
|---|---|
| **Search terms surname-first** — `"Brock, Geoff"` not `"Geoff Brock"` | all four winners returned ZERO non-zero weeks. 7,505 of 14,953 corpus rows affected |
| **One shared 2021–2026 window** | its maximum is set by federal campaigns, so SA state candidates fell under Google's publishing threshold |
| **Chain anchored on the strongest PRIOR non-major** | Brandon Turton has no search presence, so every rescale divided by zero |

Corrected: per-election window, `AU-SA` geography, a fixed head-of-government
anchor, and real names. 28 batches, weekly granularity, **0 candidates dropped**.

## The result, now trustworthy

| winner | seat | jump | percentile among new candidates |
|---|---|--:|--:|
| **Chantelle Thomas** | Narungga, 37.7% from a 5.4% prior | 0.0526 | **99th** |
| **Travis Fatchen** | Mount Gambier | 0.0394 | **96th** |
| David Paton | Ngadjuri | 0.0000 | 51st |
| Jason Virgo | MacKillop | 0.0000 | 51st |
| Matt Schultz | Kavel | 0.0000 | 51st |
| Lou Nicholson | Finniss | 0.0000 | 51st |
| Geoff Brock | Stuart | −0.0108 | 4th |

**AUC over new candidates 0.703**, against a pre-registered bar of 0.80. Median
winner percentile 52 against a bar of 85. **C1 fails on sa2026.**

## Why, and it is not fixable by measuring harder

**104 of 111 South Australian candidates have no measurable search volume at
all.** Not compressed, not below a rescaling threshold — absent. Four of the
seven winners sit at exactly zero and tie with 100 others, which is what drags
the AUC to 0.703 despite the two genuine emergences ranking 99th and 96th.

That is a property of the election, not the instrument. A South Australian
district holds about 25,000 voters; a candidate can win one without ever being
searched enough for Google to publish a figure.

## The false positive at the top is the other half of the lesson

The highest jump in the state belongs to **David Speirs, 0.1887, on 14.1% of the
vote** — a former SA Liberal leader with a drug conviction. Enormous search
volume, no electoral consequence.

This is the Cameron Smith failure again: salience measures **attention**, and
attention is not the same as electoral support. Federally the two correlate
because a teal insurgency generates coverage; in a state election notoriety and
emergence are separable, and the signal cannot tell them apart.

## Where this leaves salience

| election | AUC over new candidates | verdict |
|---|--:|---|
| fed2022 | 0.979 | fitting election |
| **nsw2023** | **0.894** | passes, out of sample |
| **sa2026** | **0.703** | **fails** |

C1's refusal clause — *"if it works on nsw2023 but not sa2026, one election
carrying the result is indistinguishable from chance"* — stands, and now stands
on a sound measurement rather than a broken one.

**The honest reading is that salience works where candidates are searched and
fails where they are not**, and that the boundary runs between federal and
small-state elections rather than between good and bad measurement. Victoria is
the live target and sits between the two: 88 districts of ~50,000 voters, larger
than SA's, smaller than a federal division.

## What should NOT be concluded

That salience is worthless. Chantelle Thomas went from a 5.4% prior to winning
on 37.7%, and salience put her at the **99th percentile** of her field. Nothing
else in the model can see that — arm C proved the seat model actively harms such
candidates by shrinking them toward the mean.

The finding is narrower: **the signal exists, and its coverage is limited by
search volume**, so any use of it must degrade gracefully to "no information"
rather than to "no emergence". A gate that reads zero as evidence of absence
would be wrong in exactly the four SA seats above.

---

# The finding that matters is not the AUC

Measured after the above, on the same corpora: what happens to candidates
salience is SILENT on?

| election | silent | winners among them | fired | winners among those |
|---|--:|--:|--:|--:|
| fed2022 | 243 | **0** | 121 | 16 |
| fed2025 | 258 | **0** | 130 | 13 |
| nsw2023 | 175 | **1** | 31 | 11 |
| sa2026 | 104 | 6 | 7 | 2 |

**Across two federal elections, 501 candidates registered zero salience and not
one of them won.** In New South Wales, 1 of 175.

That is a stronger and more usable statement than any AUC, because it says where
the model is entitled to be confident rather than how well it ranks. The rule:

> **A non-zero campaign jump is necessary for a non-major to win, wherever
> search volume is measurable at all.**

South Australia is exactly where it is not measurable — 6 of its 7 winners came
from the silent group — which breaks the premise rather than the rule, and is
why any implementation must treat zero as *no information* in a low-volume
election and as *evidence against* only where the field as a whole registers.

A workable test of "measurable at all" is available from the field itself and
needs no outcome data: fed2022 had 121 of 364 candidates fire, nsw2023 31 of
206, sa2026 **7 of 111**. An election where under ~10% of the field registers
cannot support the necessity rule.

Within South Australia the direction still holds even so: candidates salience
fired on averaged **17.9%** of the vote against **10.6%** for the silent ones
(Wilcoxon p = 0.072, n = 7 — suggestive, not significant).

## What this changes about how salience should be used

Not as a ranking fed into a slope. As a **screen**:

- **Silent, in a measurable election** → this candidate does not win. Worth more
  than it sounds: arm C showed the seat model's real damage is applying an
  emergent's slope to the 300 candidates who will poll nothing.
- **Fires** → cannot be dismissed; the model must not shrink them toward the
  mean. Chantelle Thomas at the 99th percentile is the case.
- **Whole field silent** → no information, fall back to the class-based model.

That is a different design from every arm tried so far, and it is the one the
data actually supports.
