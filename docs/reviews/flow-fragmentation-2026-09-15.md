# Preference flows track field fragmentation, not closeness

2026-09-15. The question left standing after the Victorian truncation finding
was retracted: **preference flows are only ever observed in seats that went to
a full distribution, which happens precisely when a seat is close.** Are
flows-in-close-seats a biased sample of flows everywhere?

**No. But the test found a feature the flow model does not have.**

## The design

A full distribution happens when a seat stays live; a safe seat stops on a
majority or never distributes at all. So the late rounds are selected. **Round
1 and 2 are not** -- they happen in every seat that distributes anything,
whatever the eventual margin. Comparing early-round flows across levels of seat
safety therefore carries no selection in the flow itself.

3,031 (seat x source-class) observations across all six jurisdictions,
restricted to transfers of 50+ votes with 30+ landing on a major.

## First answer, which was wrong

Flow to ALP as a share of the two majors, against the leading candidate's
first-preference share:

| leader's primary | n | ALP share |
|---|--:|--:|
| <35 (marginal) | 97 | 38.4% |
| 35-40 | 301 | 45.1% |
| 40-45 | 754 | 46.0% |
| 45-50 | 823 | 47.7% |
| 50+ (safe) | 1056 | 48.2% |

A 9.8-point gap, slope +0.181 per point, t = +4.14. The obvious confound --
that "safe" might just mean "safe for Labor" -- does not explain it: LNP leads
1,488 observations at mean safety 48.6 and ALP 1,429 at 47.7, and controlling
for the leading party leaves the slope at +0.183 (t +4.20).

**But the leader's primary share measures two things at once**: how close the
contest is, and how fragmented the field is. A seat with a 35% leader might be
a knife-edge or a safe seat with eight candidates.

## Separating them, with the two-candidate margin

Using the two-candidate margin now available for 624 seats (official where the
commission publishes it, derived from preference flows otherwise), on 872
observations:

| 2CP margin | n | ALP share |
|---|--:|--:|
| 0-2 (knife edge) | 100 | 49.0% |
| 2-5 | 129 | 42.9% |
| 5-10 | 228 | 44.9% |
| 10-20 | 342 | 49.3% |
| 20+ (very safe) | 73 | 53.8% |

| model | slope on margin | t |
|---|--:|--:|
| margin alone | +0.357 | +3.56 |
| **margin + leader's primary** | **+0.003** | **+0.02** |
| (leader's primary in that model) | **+0.508** | **+3.69** |

**Closeness explains nothing once fragmentation is controlled.** The entire
apparent effect is the leader's primary share.

## What this settles, and what it opens

**The selection worry is answered: there is nothing to fix.** Flows do not
differ between close and safe seats, so estimating them from seats that went
the distance and applying them everywhere is sound. The retracted truncation
finding leaves no residue.

**The flow model has no fragmentation feature.**
`scripts/fit_xgb_flows_v1.R:162`:

```
feat_cols <- c("cond_rate","cond_n","pool_rate","pool_n","to_primary","from_primary",
               "dest_same","dest_same_mp","n_survivors",
               surv_*, from_*, to_*, region_*)
```

It knows the source and destination classes' own primary shares and how many
survivors remain. It does not know how dominant the leading candidate is --
`to_primary` is the destination class's share, which is not the same quantity
and does not describe the seat's shape when the destination is not the leader.

The measurement above says that quantity carries real signal for flow
direction: **+0.508 points of ALP share per point of leader primary, t = 3.69**,
on 872 observations, surviving a control that kills the closeness story.

## Not established

- **That adding the feature improves the model.** A correlation in a linear fit
  is not an improvement in a fitted tree that already has `from_primary`,
  `to_primary` and class dummies, which may already capture some of it. Four
  mechanisms have died this way today.
- **Why fragmentation moves flows.** Plausibly a fragmented field means a
  different kind of minor candidate, whose voters differ -- but that is a story,
  not a measurement.
- **Whether it survives out of fold.** Everything here is in-sample across the
  whole corpus.

Adding it gets a pre-registration, a leave-one-election-out fit, and the
permutation control that is now standard here.
