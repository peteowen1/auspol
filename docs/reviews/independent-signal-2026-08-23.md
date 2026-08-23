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
