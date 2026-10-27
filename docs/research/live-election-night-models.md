# How AEF, the NYT Upshot, The Poll Bludger and the ABC run live election-night models

Research for issue #151 (map #148). Question: how do established live
election-night models work, and which methods should ours take? Methods only:
our model never takes their live numbers as inputs.

Written 2026-10-28. Branch `research/live-election-night-models`, never merged.

## How much to trust each section

| Outlet | Source quality | What I could and could not confirm |
| --- | --- | --- |
| AE Forecasts (AEF) | **Primary, strong.** The model's author publishes the full C++ and design docs (`d-j-hirst/aus-polling-analyser`, `docs/live-*.md`, `analysis/reports/live-category-tpp/`). | Method: confirmed from the docs. What the public live page shows: **not confirmed**. `aeforecasts.com` pages are JavaScript-rendered and returned only a title to my fetcher. The repo README links a methodology page at `aeforecasts.com/methodology` that I could not read. |
| ABC (Antony Green) | **Primary, partial.** Green's own blog post on Queensland 2024; the rest is a secondary reconstruction. | The formulas are not published. Steps and calling rule come from a secondary write-up (Simplify Stats). |
| The Poll Bludger (Bowe) | **Primary but anecdotal.** Only his live-blog comments; no methodology page found. | His current live-results tool: **not confirmed**. Searched pollbludger.net, 2005 to 2018 live threads only. |
| NYT Upshot needle | **Weakest.** `nytimes.com` and `web.archive.org` are blocked to my fetcher, so I could not read the Upshot's own 2016 or 2020 methodology articles. | Everything below on the needle is from secondary coverage (Reuters Institute, CJR, FAIR, Quartz summaries, one reprint). Treat details as unverified. |

## 1. AE Forecasts (primary: the author's repository)

Source: `https://github.com/d-j-hirst/aus-polling-analyser`, files
`docs/live-turnout.md`, `docs/live-tpp-composition.md`,
`analysis/reports/live-category-tpp/README.md`, `live_scripts/README.md`
(master, pushed 2026-10-27). Used live at federal 2022 and 2025, NSW 2023, QLD
2024, SA 2022 and 2026, WA 2025 (the repo ships saved project files for each).

**What it updates from.** The commission's results feed (XML), re-read as a new
snapshot each time. Every snapshot conditions the same pre-election baseline on
the cumulative counts; it does not use the previous snapshot's posterior as the
next prior, so repeating a run never counts evidence twice. It keeps per-booth,
per-vote-category first-preference (FP) and two-candidate (TCP) counts, and
estimates a two-party-preferred (TPP) figure from FP where TCP is not in yet.

**Counted versus uncounted.** Counted votes are kept exactly as lower bounds.
Uncounted votes are the sum of three separately modelled things:
- *Turnout and size.* A frozen pre-election "prior" of possible final formal
  counts per booth and category (enrolment, past turnout and formality, early
  and postal application counts). Each draw keeps all districts together so a
  state-wide turnout shock stays correlated. Unreported booths are adjusted for
  shortfalls at reported ones (a "compensation" coefficient by booth size,
  0 for under 2,000 expected votes up to 1.17 for 4,000 to 8,000).
- *Late declaration votes (postal, absent, provisional).* Each unfinished
  category mixes four outcomes: routine additions that fade after the receipt
  deadline, tiny additions, a low-probability "exceptional late batch" (starts
  at 2%, declines with time), and an exactly-zero outcome. Completion flags make
  zero certain; quietness alone does not.
- *Composition of what remains.* Two estimates of the outstanding first
  preferences are blended in log-odds: a historical-swing projection and one
  from current absolute shares. The weight on the absolute one is
  `G A^4 / (A^4 + H^4)`, so a booth with no usable history (new or
  redistributed) leans almost wholly on current shares. The gate
  `G = N/(N+500) * B/(B+1)` stops a few small booths taking over, where `B`
  is the effective number of reporting locations.

**Vote types are modelled as different, correlated populations.** For each
category (early booth, early declaration, day absent, postal) it estimates a
"contrast": the category's swing relative to ordinary booths after removing its
last-election lean.
- Election-wide (shared) contrast plus district-local contrast; both kept.
- Fitted from 14 election pairs (7 federal, 4 VIC, 2 NSW, 1 QLD): response of a
  category to the ordinary-booth error was 0.75 (all early), 0.85 (postal),
  0.73 (absent); the departure SDs 1.6, 2.8 and 1.7 transformed points
  (about percentage points near 50%). Early and postal departures correlate at
  0.70, absent is slightly negative. Treating categories as independent
  "would lose a material part of the uncertainty".
- A plain "carry the ordinary swing" rule beat the fitted slopes on held-out
  elections for most categories (RMSE 1.58 early, 2.66 postal against 1.66 and
  3.01 fitted). The author says the data "support retaining a common movement
  with uncertain category departures" more than any fitted slope, and rejects a
  universal 60% reversion.
- Shared contrasts get 10% larger SDs (covariance x1.21) as a conservative
  inflation, and are scaled down if they would exceed the seat-prior covariance
  budget (10% reserved for other errors).
- Growing early voting gets **no deterministic directional adjustment**.

**Uncertainty and correlation between seats.** The baseline is the mean and
covariance of the actual pre-election seat TPP draws. The live update conditions
all seats jointly (a Gaussian conditional on a transformed scale
`z = 25 log(p/(100-p))`, linearised around the prepared centre), while keeping
the actual non-Gaussian baseline draws. So ten seats reporting move the other
seats through the shared component, and "a common error affecting many seats
does not disappear merely because many seats report". Category effects are
allocated inside the existing seat covariance, not added on top ("it does not
add a second national TPP error distribution"). All noise enters before
conditioning; none is added afterwards.

**Small early samples.** One finished tiny booth is a reliable count of that
booth but a weak sample of the seat. Each observation gets extra sampling
variance `V * [5000 (1-c) / max(1,N)]^2` (`N` received votes, `c` fraction of
category in). 1,000 votes multiplies variance about 26x, 5,000 about 2x,
20,000 about 1.06x, and it vanishes at 100% counted. Chosen by comparing early
response on the federal 2022 checkpoint; the author says not a multi-election
calibration.

**Unrepresentative early reporting.** FP early-uncertainty allowance, SD
`exp(-C/0.1) / sqrt(B+1)` in log proportions of the remaining pool, fading as
counting proceeds. The author's own audit notes that the final VIC 2022
ordinary-vote error is slightly negative, which "does not contradict an early
election-night estimate being too favourable to Labor" -- i.e. reporting order
mattered there.

**Handoff weight from prior to count.** `W = G Vb / (Vc + G Vb)` on log-odds
variances (baseline `Vb`, count-based `Vc`), applied draw by draw:
`(1-W) * prior + W * count`. That is a precision-weighted combination with the
pre-election forecast as prior, the same shape as our plan.

**Preferences.** FP is converted to TPP/TCP with configured flows corrected by
matched FP/TCP booths. Unresolved-pool variance: `(4 qG + 35 (q-qG)) *
(0.2 + 0.8/(1+2E))` points squared (`qG` Greens pool, `q` all non-major pool,
`E` effective matched booths); 35 was set from aligned errors of about 29 per
unit pool in 27 federal 2022 non-classic seats. Greens and independent flow
errors are shared across districts (SD `2*qG` and `5*qI` points). Information
weight shifts from FP-derived to measured TCP smoothly,
`1/(1+(19 f/(1-f))^2)` for `f` the fraction of FP awaiting preferences: even
split at a 5% gap, 2.4% measured weight at a 25% gap. Candidate-level FP
rechecks are corrected against the original TCP rather than treated as new.

**Independents.** Cross-seat sharing of an independent's movement is weighted
`s^2/(s^2+0.05^2)` by that independent's pre-count baseline share, so a 1%
independent rising to 3% barely informs other seats and a 20% one almost fully.

**Feed hygiene.** Whole-vector rollback of an invalid count to the last
accepted one (never patch one candidate); TCP exceeding FP by more than
`max(10 votes, 5% of FP)` triggers recovery; a "reconciliation hold" keeps the
last coherent FP/TCP pair when a recount resets FP; absence from one capture is
never a closure or zero; and every raw snapshot is archived with a fingerprint
so any night can be replayed in time order. Replay scripts exist for federal
2025 (nine retained AEC updates) and SA 2026.

**What it shows.** The GUI has live booth tables, snapshot sequences and graphs.
The public site's live page: **not confirmed**.

**Known failures and limits (author's own words).**
- Most constants are "initial", "conservative working" or "not calibrated";
  the turnout and compensation coefficients are from federal 2025 reliable
  matches only, "not independently validated on another election".
- Category evidence is observational; NSW 2019 to 2023 iVote/postal definitions
  are not comparable; SA historical batching cannot be split into early and
  declaration, so SA uses synthetic baselines with 5 transformed points of error.
- WA 2021 TCP was unusable; only one district passed the coverage screen.
- The 14-pair sample is small ("not rigorously calibrated 95% coverage").

## 2. NYT Upshot election needle (secondary sources only)

I could not read the Upshot's own methodology articles (blocked). The following
is from secondary coverage and is **unconfirmed against the NYT text**.

- *Inputs.* A pre-election benchmark for each county or precinct from polls,
  past results and demographics; then AP vote counts plus the Times' own
  collection from officials (Reuters Institute, 2024 piece quoting the team).
- *Update rule.* If a candidate beats the benchmark in one county, the model
  expects them to beat it in similar counties; the needle moves from the
  pre-election estimate toward an "in-between modelled estimate" (same source).
  The 2016 needle started from the Upshot forecast of Clinton 85% (secondary).
- *Vote method (2020).* Per a reprint of the explainer, Times/Siena polls were
  used to estimate how each voter votes by demographics and vote method, then
  aggregated to precinct by vote method; the model needed to know whether
  uncounted votes were Election Day, early in person or mail. The key risk was a
  candidate beating the projection in the absentee vote (lightlynews reprint,
  and Reuters Institute; reprint, so lower trust).
- *Scope.* In 2020 the Times declined a national needle because of mail-ballot
  uncertainty and ran only Georgia, Florida and North Carolina, states that
  report most votes quickly including mail (Reuters Institute; CJR).
- *Display.* A gauge with a jittering needle. Critics (CJR public-editor
  column, FAIR) called it "extra bouncy" and "false confidence"; the Times'
  defence (Cohn) was that it makes transparent what TV network models do and
  that those models allow for early counts being unrepresentative.
- *Failures.* 2016: the needle swung to Trump in the evening and Cohn later said
  it "performed exactly as we had hoped", a leading indicator of an upset.
  2018 PA-18 drew heavy criticism. 2020: Georgia's needle swung and was turned
  off at 6 am (CJR). The Times' own later words, via secondary coverage, called
  it "the single, predictive needle that offered readers false confidence".
- *Not found.* The exact model family, the uncertainty and correlation
  structure, and any explicit prior-versus-count weighting. I found no source
  mentioning a Gaussian process; do not assume one.

## 3. The Poll Bludger (William Bowe), live blog comments

Only anecdotal primary evidence; no methodology page found.
- On Victoria 2018 night (`pollbludger.net/2018/11/25/victorian-election-call-board/`):
  he "turned off booth-matching for my aggregations and predictions, at least
  for the two-party vote", leaving primary-vote swings "slightly anomalous".
  Reason: pre-poll and postal votes "very often failed to replicate the massive
  swings to Labor on election day"; Brighton's 10.2% election-day swing was
  2.6% on pre-polls and 1.8% on postals. His model on Mildura was "not
  sufficiently cognisant of how well the Nationals tend to do on postals".
- On Gaven 2006: early results flatter whichever party's booths report first.
- Live threads are timestamped updates with comment from readers; whether his
  current live-results page projects at all is **not confirmed**.

## 4. ABC election computer (Antony Green)

Primary: Green's QLD 2024 post
(`antonygreen.com.au/qld2024-preference-flows-and-vote-by-type-compared-to-2020/`).
Secondary: Simplify Stats, "Calling a seat on election night" (Mealing, 2022,
updated 2024), reconstructing the method. Exact formulas not published.
- *Method.* Compute the 2CP swing over booths that have reported, add it to the
  seat's previous final 2CP, refresh about every 2 minutes (secondary).
- *Why swing.* Green cites Ross Cunningham: variance of swing is smaller than
  variance of 2PP percent, and swing "was not correlated with booth size", so
  it is an unbiased estimator (primary). The assumption breaks when early votes
  differ from election-day votes.
- *QLD 2024 data.* Swing against Labor 4.9% polling day, 8.6% pre-poll, 10.3%
  initial postal count, which is why the swing grew all evening (primary).
  Pre-poll is bigger and arrives late, so the early-evening swing is a biased
  estimate of the final one. With one early centre per seat, "you can't know
  how different early vote swing is until an early vote centre reports".
- *Calling rule (secondary).* At least 3% of the seat counted and the predicted
  value outside a 99% interval around 50%; the ABC "adds more variance" because
  of postal and pre-poll growth, so it waits longer. Braddon example: predicted
  Liberal share went 46.9, 55.9, 51.5, final 53.09.
- *Preferences.* Flows differ by booth size and by region, so handled by booth
  type (Green, ADSEI podcast, via search summary; unverified). Small seat
  contests with a minor party such as South Brisbane kept "in doubt" with the
  leader at each update, projections "may bounce around".
- *Reported lineage.* Software redesigned by Green after 1990, in use since the
  1992 QLD election; he says the early-1990s formula still makes most seat calls
  with manual overrides (search summary of an ABC interview; unverified).
- *Criticism.* Mainly sensitivity to late early and postal volume.

## What this means for our plan

`docs/plans/election-night-booth-model.md` already has booth matching, a
booth-swing projection, booth-type pooling and a precision-weighted blend with
the afternoon forecast. Outside evidence agrees on the shape. The evidence
points to four places where ours is thin or untested.

## Ranked ideas for us

Cost scale: S under a day, M a few days, L a week or more.

| # | Idea | Why | Cost | Source |
| --- | --- | --- | --- | --- |
| 1 | **Pre-poll and postal are a separate, correlated swing, with an unknown-until-it-reports uncertainty on them.** Model per-booth-type contrast to ordinary booths, shared across the state plus a local part, and carry it as variance until that type reports. | Every source names this as the dominant night failure: Bowe VIC 2018 (Brighton 10.2 vs 2.6 vs 1.8), Green QLD 2024 (4.9 / 8.6 / 10.3), AEF's fitted 0.75 to 0.85 response and 1.6 to 2.8 SDs. VIC 2022 counted own-district early votes on the night, so this is in our first batch. | M | AEF `live-tpp-composition.md`, `live-category-tpp/README.md`; Green QLD 2024 post; Bowe 2018 |
| 2 | **Start from "carry ordinary swing, widen the uncertainty", not a fitted per-type slope.** Fit contrasts from our 2018 to 2022 VIC booth files and test against carry on held-out pairs. | AEF's own held-out test: carry beat fitted slopes for most types. Only 14 pairs exist; we have fewer. | S | AEF `live-category-tpp/README.md` |
| 3 | **Treat count progress as part of the variance.** Extra sampling variance for tiny reported shares, `V*[K(1-c)/max(1,N)]^2`, vanishing at 100%; plus a reporting-order allowance that decays with counted fraction and effective number of booths. | Stops one small early booth moving a seat and the chamber. Matches our plan's "sampling sd that falls with counted fraction plus floor". Gives it a concrete form. K=5,000 is AEF's number for federal, so ours must be refit on VIC replay. | S | AEF `live-turnout.md`, `live-tpp-composition.md` |
| 4 | **Weight the update by evidence quality: a smooth gate on reporting breadth.** `N/(N+K)` times `B/(B+1)`, with `B = N^2 / sum(n_i^2)`. Booths with no usable 2022 match get weight on current shares instead. | Handles dominance by one large early centre, which Green flags as the QLD 2024 failure; also handles new and closed booths. | S | AEF `live-turnout.md` |
| 5 | **Chamber correlation: condition all 88 seats jointly on what reported, in a transformed share scale, retaining the forecast's real draws.** Do not add a second national error. | Matches our chamber step; AEF shows the exact form (Gaussian conditional on the baseline draws, linearised). Checks that early swing in ten seats legitimately moves the rest without double-counting. | M | AEF `live-tpp-composition.md` |
| 6 | **Calling rule for readers, separate from the probability.** "Likely" only past a minimum counted fraction (ABC: 3%) and an interval clear of 50%. Show win probability and counted % together. | The ABC's rule is the most field-tested; the NYT lesson is that a lone twitchy number costs credibility. Needs our own calibration (log loss at 25/50/75% counted from the replay). | S | Simplify Stats (secondary); Green; CJR, FAIR |
| 7 | **Preference variance as a pool-weighted term that shrinks as TCP comes in.** Unresolved non-major pool x flow-uncertainty, smooth switch from FP-derived to measured TCP by the fraction of FP awaiting preferences. | Our plan reuses the flow model with "no new preference machinery"; this is the cheap piece that stops it being over-confident in Greens and independent contests. Constants (35, 4, 19, 5%) are AEF's and not ours. | M | AEF `live-tpp-composition.md` |
| 8 | **Archive every raw feed snapshot with a fingerprint and replay in time order.** Reject a count whose TCP exceeds FP by more than `max(10, 5%)`; roll back whole vectors, never one candidate. | Gets us the dress rehearsal we lack (booth report order is unrecorded in final files) and guards against feed errors on the night. Aligns with the raw-scrape rule. | S | AEF `live-turnout.md`, `live_scripts/README.md` |
| 9 | **Late-batch outcome mixture for postals not yet counted.** Routine, tiny, exceptional late batch, and zero; timed to the VEC receipt deadline. | Only matters for what we show after the night's 75% count; defer unless we publish past 6.30-11 pm. | M | AEF `live-turnout.md` |
| 10 | **Share an independent's movement across seats weighted by their pre-count baseline.** | Cheap guard against a one-seat independent surge dragging the chamber. Needs a Victorian check. | S | AEF `live-turnout.md` |
| 11 | **Do not copy:** a jittering single gauge, a national call from partial data when late-counted votes are uncertain, or switching booth matching off wholesale. | NYT 2016/2018/2020 criticism; Bowe's switch-off was a fix for the exact problem idea 1 models. | n/a | CJR, FAIR; Bowe 2018 |

## Not found, worth another look

- The Upshot's own 2016 and 2020 methodology articles (blocked here). Read them
  from a normal browser before any needle-like feature.
- AEF's public live page and `aeforecasts.com/methodology`.
- Bowe's current live-results method, if any.
- Green's actual variance adjustment and seat-calling code; a possible route is
  his other blog posts on election-night methodology (not located).
- AEF model performance on the night: the docs describe design and constants but
  I found no published scoreboard of live accuracy.
