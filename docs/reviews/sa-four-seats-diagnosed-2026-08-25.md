# Why the four SA seats are wrong: we get One Nation right and lose on the RUNNER-UP

2026-08-25. Direct per-seat diagnosis, after eight hypotheses were tested and
refused. **Nothing changed yet.** This is the mechanism, not a proposal.

## The headline

**In two of the four seats our projected One Nation vote is nearly exactly
right, and we still give the party ~0.** The error is in who comes *second*,
which decides the exclusion order and therefore where preferences flow.

Model = 2022 seat share + uniform statewide swing (ALP −2.50, LNP −17.10,
ONP +20.25, GRN +1.25).

### Hammond — One Nation projected to 0.3 points

| party | 2022 | model | **actual** | error |
|---|---:|---:|---:|---:|
| ONP | 6.9 | **27.1** | **27.4** | **−0.3** |
| LNP | 43.7 | 26.6 | 22.3 | +4.3 |
| ALP | 23.3 | 20.8 | **27.0** | **−6.3** |

Our One Nation number is essentially perfect. But we put **LNP second and ALP
third**; reality was **ALP second and LNP third**. Model gave ONP **0.000**.

### Ngadjuri — same shape

| party | 2022 | model | **actual** | error |
|---|---:|---:|---:|---:|
| ONP | 11.0 | **31.3** | **34.9** | −3.6 |
| LNP | 46.8 | 29.7 | 25.3 | +4.4 |
| ALP | 25.6 | 23.1 | **29.5** | **−6.4** |

Our model has One Nation **leading on primaries** (31.3 against LNP's 29.7) and
still gives it **0.007**.

**A party we project to lead the count, losing in ~20,000 of 20,000
simulations, is not a swing problem or a concentration problem.**

## Why the runner-up decides it

The count excludes from the bottom. Our order puts **Labor third**, so Labor is
excluded first and its preferences break heavily to the Coalition, which then
beats One Nation.

Reality put **the Coalition third**. When the Coalition is excluded, its
preferences went **54.0% to One Nation** — measured directly from SA 2026's own
transfer file. One Nation then wins comfortably.

So the same three primary votes, with second and third swapped, produce
opposite winners. We are getting One Nation's vote right and the contest wrong.

## The cause: the Labor swing is uniform when it should not be

Statewide Labor fell 2.50 points and the model applies that everywhere. In
these seats Labor **rose**:

| seat | ALP 2022 | ALP actual | move |
|---|---:|---:|---:|
| Hammond | 23.3 | 27.0 | **+3.7** |
| Ngadjuri | 25.6 | 29.5 | **+3.9** |

This is not a new hypothesis — it is the fact already measured in
[sa-2026-attribution-2026-08-25.md](sa-2026-attribution-2026-08-25.md):
**in Coalition-held seats Labor rose +0.6 on average while falling statewide.**
That review recorded it and did not connect it to the seat failures. It is the
same number, and it is worth about **6 points** of error in exactly the seats
that decide whether One Nation wins.

## MacKillop is a different and harder problem

| party | 2022 | model | actual | error |
|---|---:|---:|---:|---:|
| LNP | 67.0 | 49.9 | **26.9** | **+23.1** |
| ONP | 8.1 | 28.3 | 35.3 | −6.9 |

**−6.93 standard deviations** against the harness's `seat_sd` of 3.33. No swing
rule tested today reaches it (proportional gives 35.3, still 8 points high).
This seat needs either much wider per-seat uncertainty or a mechanism for
stronghold collapse, and it is **not** the same problem as Hammond and
Ngadjuri.

Narungga is a third shape again — the model under-states **both** One Nation
(−11.9) and the Coalition (−9.4).

## What this means for priority

Two of four seats fail for a reason that is **specific, measured, and about
second place rather than One Nation**. That is a much smaller problem than any
of the eight hypotheses tested today, and it was invisible to all of them
because every one looked at One Nation's own vote.

**The tractable question, and it must be pre-registered like everything else:**
does allowing the major-party swing to differ by seat type — Labor holding up
or rising where it starts low and the Coalition is collapsing — fix the
exclusion order without breaking the 2,878-observation corpus where uniform
currently wins?

That is a **conditional** swing, not proportional and not proximity-weighted,
and it is aimed at the runner-up rather than at One Nation. Note the standing
warning from today: uniform has survived three alternatives, so the bar is
that any conditional rule must not degrade the pooled corpus.

## What must not be concluded from this

- **This is one election.** Two seats.
- **It does not license a seat-type coefficient fitted on SA 2026** and applied
  to Victoria. That is the `sa_ratio` circularity in a new costume.
- **It does not explain MacKillop or Narungga**, which are 2 of the 4 and are
  different failures.
