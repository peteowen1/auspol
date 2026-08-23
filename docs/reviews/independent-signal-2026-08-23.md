# It is not that the independent was absent. It is that they were 1.3%.

A diagnosis that corrects my own reasoning from an hour earlier and redirects
the line that was closed this morning.

## The claim I got wrong

After the fifth refusal I said the structural cause was that "a seat where no
independent stood has no `IND` vote to swing", and that **nomination data** —
public before polling day and never used — would fill the hole. Nominations do
eliminate a lot of seats:

| independents nominated | divisions | independent won |
|---:|---:|---:|
| **0** | **558** | **0 (0.0%)** |
| 1 or more | 494 | 33 (6.7%) |

**53% of division-elections are impossible for an independent and we could know
it for free.** That part is true and worth having.

**But it does not touch the seats that matter**, which is what I claimed and did
not check before claiming it.

## Every teal seat already had an independent standing

| seat | IND vote, previous election | IND vote when they won |
|---|---:|---:|
| Goldstein | **1.3%** | 35.3% |
| North Sydney | 4.3% | 24.7% |
| Curtin | 7.8% | 30.2% |
| Kooyong | 10.6% | 41.4% |
| Mackellar | 12.3% | 37.9% |
| Wentworth | 32.7% | 36.3% |

And the 2025 first-time wins: Bradfield 24.3 → 30.5, Calare 20.0 → 36.5, Fowler
27.8 → 29.6.

**In every case an independent was already on the ballot last time.** The model's
failure is not that the candidate class was absent. It is that the previous
independent polled 1.3% and the next one polled 35.3%.

## Which is why five attempts failed

Every refused version predicted the independent vote from **seat
characteristics** — margin, prior non-major vote, who holds the seat, prior
independent share. Goldstein 2022 and a seat where a 1.3% independent stays at
1.3% are **identical on every one of those features**. No amount of refitting
separates them, because the difference is not in the seat. It is in who decided
to run and how the campaign went.

That is a genuine explanation for a five-times-refused result, and it is not one
any of the five could have reached from inside its own feature set.

## What could separate them

Only something measured **during the campaign**, about the specific candidate:

- **search interest** in the candidate's name, against the sitting member;
- **news coverage** of the seat or the candidate.

Both are contemporaneous observations rather than structural priors, which is
the category none of the five attempts drew from. Note AE Forecasts reaches for
the same category from a different direction — four of its eight final reports
are seat-betting updates, which is also a live read on a specific contest.

`docs/ANCHOR-MODEL.md:131` lists Google Trends among minor sources as "probably
noise". That judgement was made about general seat modelling, not about this
problem, and this problem is the one place where a salience signal is the only
remaining candidate mechanism.

## Feasibility, checked before any plan

Reachable from this environment: `trends.google.com`, `news.google.com`,
`api.gdeltproject.org`, and CRAN (so `gtrendsR` is installable). None of it is
blocked, which was the first thing that could have killed the idea.

The known constraint: **Google Trends has no electoral-division geography.** It
resolves to states and territories, not seats. So the usable signal is national
or state-level interest in a *named candidate*, not search volume inside the
division. For a teal with a real campaign that is probably enough; for a token
independent there should be nothing to find. GDELT gives dated article counts by
keyword and can be queried per candidate or per seat name.

## Reopening a line I closed this morning

`prereg-independent-remeasure.md` closed independent emergence "for good", on the
grounds that a sixth attempt "would be searching for a configuration that
flatters it".

**That rule was about configurations of the same model on the same inputs.** A
new information source is not that, and reopening on those grounds is recorded
here explicitly rather than done quietly — the closure was mine and it deserves
to be argued with rather than ignored.

What does carry over: the five refusals establish that **no rearrangement of
seat history predicts a teal**, which is exactly why the next attempt must bring
information from outside the seat's history or not be attempted at all.

## The probe, and what it did NOT establish

A first attempt to read GDELT article volume for the 2022 teal winners came back
**rate-limited (HTTP 429)** on four of six queries, and throttled on both
queries of a slower retry twelve seconds apart.

**The two that returned are not a result**: "Zoe Daniel" 0.0016 and "Goldstein"
0.0336 mean article volume over the campaign window. Two numbers with no
comparison set establish nothing.

**Recorded explicitly because the failure mode is this repo's favourite one:**
the throttled queries returned "no data", and reading that as "this candidate
had no coverage" would be absence of evidence dressed as measurement. It is not
a finding that Monique Ryan generated no news in April 2022. It is a finding
that the API refused to answer.

So feasibility is **unresolved**, not negative. What is established: the hosts
are reachable and the endpoint works. What is not: whether the signal separates
a teal from a token independent, which is the entire question.

Next attempt should query slowly from a cold start, or use `gtrendsR` against
Google Trends, which is a different service with a different rate limit.

## The signal exists — n = 2

GDELT stayed hard-429 through a cold-start retry, so the probe moved to Google
Trends via `gtrendsR`, which is a different service with its own limit.

**Anchored on the sitting member**, because Trends returns 0-100 normalised
*within each query*: "Monique Ryan" scoring 100 in one query and "Oliver Yates"
scoring 100 in another would mean nothing. Putting Josh Frydenberg in both makes
them comparable.

| Kooyong | challenger | Frydenberg | ratio |
|---|---:|---:|---:|
| **2022** — Ryan **won** on 41.4% | 10.2 | 17.9 | **0.57** |
| **2019** — Yates stood on 8.9% | 0.4 | 6.9 | **0.058** |

**A ten-fold difference between a winner and an 8.9% candidate, in the same seat
against the same incumbent.**

**This is a probe, not a result.** One seat, two cycles, both chosen because the
answer was already known. The question that decides feasibility is the one not
yet asked: **do independents who stood and did NOT break out look like Yates?**
If some look like Ryan, the signal does not separate and this dies here.

### On forking gtrendsR

Considered and rejected. The package is a thin wrapper over Google's unofficial
widget endpoint, and neither hard problem lives in it: **rate limiting is
server-side** and a fork can only be politer, while **relative scaling** is a
study-design issue — the anchor term above is what made the probe work, and that
is a query choice rather than a package feature.

What is worth building, once and only once a gate passes: a repo-local wrapper
that always injects an anchor, caches to disk so a re-run costs no requests, and
filters strictly by date. Fifty lines calling `gtrendsR`, not a fork to
maintain. If the package were unmaintained, vendoring the part we need would
beat forking, since there would be no upstream worth tracking.

## The gate ran, and measured the wrong thing

20 candidacies sampled (10 breakout, 10 not), 18 retrieved. Nominal result:
breakout ratio median 8.83, non-breakout 0.88, **AUC 0.669 — inconclusive**.

**That number is not evidence of anything, and the tell is in the raw values.**

| candidate | challenger | incumbent | ratio | actual |
|---|---:|---:|---:|---:|
| Ben SMITH | 20.61 | **0.00** | 206.1 | 20.5% |
| Caz HEISE | **1.408** | 0.00 | 14.09 | 26.4% |
| Barry SMITH | **1.408** | 0.00 | 14.09 | 1.3% |
| Mick GALLAGHER | **1.408** | 0.00 | 14.09 | 2.1% |
| David William SHELDON | **1.408** | 0.00 | 14.09 | 2.1% |

**1.408 is 100/71** — a 71-point weekly series where exactly one point is 100 and
the rest are 0. Google Trends scales the **maximum within each query to 100**, so
a candidate with almost no search volume still hits 100 at their single blip. Six
queries produced that same artefact. And the incumbent anchor returned **0.000 in
7 of 18 cases**, which is impossible for a sitting MP and means the challenger's
spike dominated the scaling and pushed the incumbent under the reporting floor.

**The anchor design was wrong.** I used the sitting member, but the sitting member
varies enormously between queries — Josh Frydenberg is nationally famous, Pat
Conaghan is not — so each query carries its own scale and the ratios do not
compare across seats. The Kooyong probe worked because both names had real
volume there; it does not generalise, and I made exactly the error I had warned
about one document earlier.

Two further contaminants, worth naming for the next attempt:

- **Official name forms.** The AEC gives "Stewart Gordon BROOKER" and "Robert
  OAKESHOTT"; people search "Rob Oakeshott". Three challengers returned exactly
  zero, including a nationally known former MP.
- **Common-name collisions.** "Ben Smith", "Barry Smith", "Peter George" pick up
  search volume that has nothing to do with the election.

### What the next attempt needs

- **One constant high-volume anchor term in every query** — the same word
  everywhere — so all queries share a scale, with candidate and incumbent both
  measured against it. This is the whole fix for the scaling problem.
- **Search-form names**, not AEC official forms.
- **A disambiguation check** for common names, or their exclusion.
- **A guard that refuses a query whose anchor returns zero**, since that is
  proof the scale collapsed rather than a measurement of anything.

The gate is therefore **not yet run**. What was run measured normalisation
artefacts, and reporting 0.669 as a near-miss would be treating a broken
instrument as a weak signal.

## Redesigned, and the gate PASSES: AUC 0.830

The fix was the one the artefacts pointed at: **a single constant anchor term in
every query** (`"Anthony Albanese"`), instead of the sitting member. Every
candidate in an election is then measured on one scale, and a candidate nobody
searches reads a genuine **0.0000** rather than being rescaled to their own peak.

2022, all 10 breakout challengers and 12 sampled non-breakouts:

| candidate | seat | salience | actual |
|---|---|---:|---:|
| Monique Ryan | Kooyong | 0.1465 | 39.1% |
| Allegra Spender | Wentworth | 0.0853 | 34.9% |
| Zoe Daniel | Goldstein | 0.0779 | 33.3% |
| Kate Chaney | Curtin | 0.0327 | 28.5% |
| Sophie Scamps | Mackellar | 0.0230 | 36.7% |
| Dai Le | Fowler | 0.0175 | 26.4% |
| Tim Bohm | Canberra | 0.0023 | 5.1% |
| *ten no-hopers* | | **0.0000** | 0.7–9.5% |

**Breakout median 0.0203, non-breakout median 0.0000, AUC 0.830** — above the
0.75 pass mark fixed before the first attempt. The top six are all winners; ten
of twelve no-hopers are exactly zero.

**The threshold did not move; the instrument was repaired.** The earlier run
measured normalisation artefacts and was recorded as not-a-result for that
reason. That distinction is mine to have drawn and is stated so it can be
argued with.

### Two known flaws, both of which depress the number

- **Middle names.** Queries used the AEC's full legal form. "Kylea Jane Tink"
  reads 0.0000; querying "Kylea Tink" earlier gave 11.28 against her opponent.
  Boele, Priestly and Heise are the other breakouts reading near-zero and are
  candidates for the same problem.
- **The anchor is slightly too large.** Trends reports integers 0–100, so a
  candidate below roughly 0.5% of Albanese rounds to zero. Genuinely mid-tier
  candidates are being compressed into the same bucket as no-hopers.

Both push the AUC **down**, so 0.830 is a floor. Fixing them is the obvious next
step and would only improve separation.

### It holds across three elections

Same design, per election so the anchor's own changing profile cannot distort
the comparison:

| election | breakouts | others | AUC |
|---|---:|---:|---:|
| 2019 | 4 | 12 | 0.823 |
| 2022 | 10 | 12 | 0.854 |
| **2025** | 7 | 12 | **0.964** |

2025 is near-clean — the top five by search interest are all breakouts (Ben
Smith, Boele, Dyson, Hulett, George). 2019's top two are Steggall and Phelps.

Fixing the name form lifted 2022 from 0.830 to 0.854 on its own: **Kylea Tink
went from 0.0000 to 0.0198** once queried as "Kylea Tink" rather than the AEC's
"Kylea Jane Tink".

### Remaining errors, and they run in useful directions

- **False positives are common-name collisions**, not the method firing on
  genuine unknowns. Will Anderson (Kooyong, 0.3%) scores 0.0129 because a UK
  comedian shares the name; David Norman (Hinkler, 1.3%) is the 2019 equivalent.
- **Misses are regional.** Boele (Bradfield), Priestly (Nicholls) and Heise
  (Cowper) all read near zero on 20–25% of the vote. A national search index
  cannot see a Cowper campaign, so this currently looks more like a **teal
  detector** than an independent detector.

### National versus state: TESTED, INCOMPLETE, no verdict

Every figure above is national (`geo = "AU"`). A state-level run was attempted
and **returned only 9 of 22 candidates**, with all of NSW missing — throttling,
not absence — so the nominal "AUC national 0.850 vs state 0.775" is on a small,
mostly-Victorian subset and settles nothing.

What the partial data does show, in both directions:

- **In-state is much stronger for real candidates**: Monique Ryan 0.147 national
  → **0.363** in Victoria; Kate Chaney 0.033 → **0.237** in WA.
- **Small jurisdictions inflate**: Tim Bohm in Canberra rose to 0.180 — third
  overall — on 5.1% of the vote, because any candidate is a larger share of a
  small search population.

The likely design is **both as separate features** rather than a choice: national
catches wave candidates, state catches locally-strong ones, and the ratio
between them distinguishes a nationally-famous challenger from a purely local
one. Untested.

### What this does and does not establish

**Does**: a campaign-time signal exists, is retrievable historically, and
separates breakout independents from token ones better than chance by a wide
margin — which no feature built from seat history has ever managed across five
attempts.

**Does not**: that adding it to the model improves a forecast. Separation in a
diagnostic is not a gain in log score, and the five refusals are a standing
warning about the distance between those two things.

## What must be true before a plan is written

- **A signal must be visible at all** — a serious independent must be
  distinguishable from a token one in the data, before the election, for
  candidates we already know the answer for. If it is not, this dies at the gate
  like bucket-narrowing did.
- **It must be retrievable historically** for 2016, 2019, 2022 and 2025, or
  there is nothing to backtest on.
- **It must be leakage-free** — every observation timestamped strictly before
  polling day, which for search and news data means filtering by date rather
  than trusting a query default.
