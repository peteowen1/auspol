# The model has two ways to be structurally unable to produce the right winner. South Australia used both.

Run 2026-08-20 from `scripts/check_classic_exposure.R`. No model change. This
sizes an assumption in the published forecast against the nearest comparable
election.

## What `simulate_seats()` assumes

```r
cl <- seats[which(seats$classic), ]
...
alp_nonclassic <- sum(seats$incumbent == "ALP" & !seats$classic)
```

Two rules, and each is a way of being wrong that no amount of simulation can
correct:

1. **A `classic` seat can only return Labor or Liberal.** The simulation draws a
   two-party share and asks whether it exceeds 50. No third party can win it at
   any draw.
2. **A non-`classic` seat is returned at its current incumbent with probability
   1.** Not a high probability — an exact constant, added after the simulation.

## What that would have cost in South Australia

`2026sa.txt` flagged **44 of 47** as classic before the poll.

**Seven seats had a winner the model could not have produced at any draw:**

| seat | flagged | incumbent | margin | actual winner | runner-up |
|---|---|---|---:|---|---|
| Finniss | classic | LNP | −6.7 | **IND** | LIB |
| Hammond | classic | LNP | −5.1 | **ONP** | ALP |
| Kavel | classic | LNP | −3.5 | **IND** | ALP |
| MacKillop | classic | LNP | −22.6 | **ONP** | LIB |
| Mount Gambier | non-classic | LNP | −13.8 | **IND** | ONP |
| Narungga | non-classic | IND | −14.0 | **ONP** | LIB |
| Ngadjuri | classic | LNP | −3.2 | **ONP** | ALP |

Both failure modes fired:

- **5 of 44** flagged-classic seats were won by neither major — **11.4%**.
- **2 of 3** flagged non-classic seats changed hands, against a rule that gave
  them to the incumbent with certainty.

MacKillop is the one to sit with: a **−22.6** margin, safe on any conventional
reading, won by One Nation.

## And the successes are weaker than they look

**26 further seats returned the right winner from the wrong contest** — Labor
beating One Nation where the model assumed Labor beating Liberal. The answer is
right; the mechanism that produced it did not occur. Scored on winners alone the
model looks 85% right in SA. Scored on whether the contest it simulated actually
happened, it is right in **21 of 47**.

## Victoria 2026's exposure

| | seats |
|---|---:|
| classic, simulated | **83** |
| held aside at their incumbent, probability 1 | **5** |

The five returned with certainty whatever the polls do:

| seat | incumbent | challenger | margin |
|---|---|---|---:|
| Brunswick | GRN | ALP | 34.1 |
| Melbourne | GRN | ALP | 25.0 |
| Richmond | GRN | ALP | 24.1 |
| Prahran | LNP | GRN | 11.1 |
| South-West Coast | LNP | IND | −8.0 |

Labor's floor from those is **0**, so this does not bias Labor's headline seat
count — but it fixes five seats as certainties, and in South Australia two of
three such seats fell.

Applying SA's 11.4% to Victoria's 83 classic seats gives roughly **9 seats**
whose winner the model could not produce. **That is a magnitude, not a
forecast** — it assumes Victoria behaves like South Australia, which is exactly
what nobody knows. It is here only to show whether the exposure is worth
attention. In an 88-seat chamber where 45 is a majority, nine is.

## What this does and does not establish

**Establishes:** the assumption is load-bearing, it failed in 15% of seats in
the nearest comparable election, and it fails silently — a seat the model cannot
lose does not appear in any interval, any calibration check, or any Brier score,
because it is never a prediction in the first place.

**Does not establish:** that Victoria will behave this way. South Australia's
Liberal collapse was extreme even by 2026 standards, going from the final two in
47 of 47 districts to 18.

**Not proposed here:** a fix. Making a seat winnable by a third party is a
change to the model's structure, not a constant, and it needs its own
pre-registration with a criterion that can see the thing being fixed — which the
existing Brier and calibration checks cannot, for the reason above. Note also
that a related line was already tried and closed:
[flow-uncertainty-v2-2026-08-20.md](flow-uncertainty-v2-2026-08-20.md) found
Victoria's own history could not test One Nation because it transferred no votes
in two of three test elections.

**The measurement worth having first** is whether the existing backtest can
detect this failure at all. If a seat held at probability 1 never enters the
scoring, then every calibration number this repo has published is silent about
five Victorian seats, and nobody has checked.
