# Mirani: a mid-campaign party defection, not a data bug

2026-09-16, following up Pete's question on the AEF-7 Seat Ledger about
Mirani (qld2024) — the model gave OTH_RIGHT (KAP) 90.6% to hold the seat;
LNP won it. This looked at first like a data error (the qld2020 candidate
list for Mirani shows no KAP candidate at all) and turned out to be a real,
verified, and distinct mechanism from anything else diagnosed tonight.

## What actually happened, verified against real-world sources

Stephen Andrew won Mirani for **One Nation** in 2017 and held it for One
Nation again in 2020 — `output/candidacies.csv` classifies him `ONP` in
both years, correctly. In 2024 he was **disendorsed by One Nation** and
joined **Katter's Australian Party**, recontesting Mirani under the new
banner (classified `OTH_RIGHT`, also correct) and **losing to LNP**.

This is not a retirement (he's still standing) and not a by-election (the
seat didn't change hands mid-term) — it's a third case none of tonight's
work covers: the same person, defending the same seat, under a different
party label, close to the election.

## Why every feature tells a different story about the same row

| feature | value | what it actually measures |
|---|--:|---|
| `is_incumbent_party` | TRUE | correctly flags OTH_RIGHT as defending the seat |
| `seat_prev_pcv` (OTH_RIGHT, qld2020) | 1.1% | correct — KAP barely contested Mirani before he switched |
| `own_prev_pcv` (matched by name) | 31.66% | correct — his own real ONP result last time, found across the party change |
| model's predicted primary | 32.5-34.5% | close to `own_prev_pcv`, barely discounted for the defection |
| **actual 2024 result** | **25.0%** | a real ~6.6-point drop from his own last result |

`personal_prior_vote()` handled the hard part correctly — it matched Stephen
Andrew by identity across a party change and found his real prior result
(31.66%, exactly 9,320/29,441 from the 2020 count). The problem is what
happens next: the model leans on that number almost undiscounted, when a
mid-campaign defection should cost a real, measurable share of personal
vote — which is exactly what happened (31.66% -> 25.0%).

## What this is not

- **Not a `classify_party()` bug.** ONP in 2017/2020 and OTH_RIGHT in 2024
  are both correct classifications of what he actually ran as.
- **Not a `candidacies.csv` gap.** The 2020 Mirani data is complete and
  accurate; there is genuinely no KAP candidate in it because KAP genuinely
  didn't contest that seat that year.
- **Not the incumbent-classification bug fixed earlier tonight.** That fix
  was about the FEATURE reaching the model at all; here it reaches the model
  and is used, just without a defection-specific discount.

## This is not a gap in the model -- it's a design call, and this case contradicts it

`R/candidate_returns.R`'s defector-discount machinery (`fit_defector_discount()`,
`major_discount`) exists precisely for "same candidate, different party" --
but is deliberately restricted to `MAJ <- c("ALP", "LNP", "NAT")` defectors.
The comment directly above it: *"Switching FROM an already-minor label
(Shooters, Fishers and Farmers, One Nation, Green, other independent) is a
much smaller behavioural jump for voters and is not excluded [from using the
undiscounted prior vote]."*

Stephen Andrew is exactly the excluded case -- One Nation to KAP, minor to
minor -- and his real result (31.66% -> 25.0%, a 21% relative loss) is a
concrete data point against that assumption. One case does not overturn a
design call sized on 14+ major-party cases, but it is a real contradiction
worth checking, not dismissing.

## What this establishes and what it does not

**Established**: the mechanism, precisely, with real vote counts on both
sides, and the exact line of code responsible — `MAJ <- c("ALP", "LNP",
"NAT")` in `personal_prior_vote()`, which by design gives minor-to-minor
defectors (Andrew's case) the FULL undiscounted prior vote, unlike
major-party defectors, who already get `fit_defector_discount()`'s rate.
Whether the underlying assumption ("minor-to-minor is a smaller jump for
voters") is wrong in general, or just wrong for this one case, is not
established.

**Not established**: how many other MINOR-to-minor defection cases exist in
the corpus specifically (major-party defectors already have
`fit_defector_discount()`), and whether the size of the effect (a ~6.6-point
drop here) generalises. Before touching `MAJ` or building a second rate:
search the corpus for other same-person, minor-to-minor party changes
(`personal_prior_vote()`'s own `.k` identity matching, filtered to
`prior_party` and `current_party` both outside `MAJ` and unequal to each
other) and measure the same way Pattern A was sized on all 349 retirement
cases before being built — not on this one case alone.

## Where this leaves the AEF-7 miss

Mirani's win-probability miss (90.6% for the loser) is bigger than its
primary-vote miss (32.5% predicted vs 25.0% actual, ~7.5 points) would
suggest on its own — LNP led primaries 36.7% to 25.0%, an 11.7-point gap
that would need a large preference-flow advantage to overcome. Whether the
SIMULATION is additionally over-trusting KAP/ONP-type preference flows in
a seat like this is a second, separate question this review does not answer
— the primary-vote mechanism above is confirmed; the flow side is not yet
examined.
