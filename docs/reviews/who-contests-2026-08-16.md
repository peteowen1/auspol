# The model has no theory of who contests a seat

2026-08-16. Prompted by Pete asking why `simulate_seats()` only handles
Labor-versus-Coalition seats, and whether we can assume a field rather than
assume it away.

## What the model does now

`simulate_seats()` simulates the 83 seats where **both** the incumbent and the
challenger are majors. The other 5 are held at their current holder, with no
uncertainty at all.

The five, and who holds them:

| Seat | Held by | Challenger | Labor's TPP margin |
|---|---|---|---:|
| Brunswick | GRN | ALP | +34.1 |
| Melbourne | GRN | ALP | +25.0 |
| Richmond | GRN | ALP | +24.1 |
| Prahran | LNP | GRN | +11.1 |
| South-West Coast | LNP | IND | −8.0 |

**Labor holds none of them**, so the published median of 39 is not understated
— a concern worth checking and now checked.

Each exclusion is individually correct: a Labor two-party number cannot decide
a Liberal-versus-independent contest, and pretending otherwise would be worse
than abstaining. **The problem is not the exclusion rule. It is that the field
of contenders is frozen.**

## Three things the model cannot represent

1. **One Nation winning anywhere.** Across every seat of every election in the
   anchor's files — all regions, all years — One Nation has never been listed
   as an incumbent or challenger. KAP appears 8 times, GRN 57, IND 65, NAT 69.
   So a party polling **20%** statewide is assigned exactly zero seats by
   construction.
2. **A new independent emerging.** In 2022 the federal teals took six
   previously safe Liberal seats. Nothing in the previous election's field
   predicted them, and nothing here could represent them.
3. **A frozen seat changing hands.** The five above carry no uncertainty. Three
   are Green-held on 24–34 point margins, which is defensible; Prahran at 11.1
   is not obviously safe and is treated as certain.

All three share one root: **the model represents Labor-versus-Coalition plus a
fixed list of exceptions, and has no mechanism for that list to change.**

## What the source data supports

The anchor's format already anticipates this. His **2022** Victorian file
carries:

- `sRunningParties` — which parties contest each seat (69 seats include IND,
  17 do not)
- `sMinorViability` — a score for a viable minor, e.g. `IND,1.00`, in 9 seats

His **2026** file carries **neither**. Zero of each. Those fields are populated
for completed elections and not yet for the live one.

So "assume the same field as last election" is buildable from 2022, and is
**strictly better than the current implicit assumption**, which is not "the
same field as last time" but the much stronger "two majors everywhere, forever,
except five".

## What is buildable now, and what is not

**Now, without new data:**

- Simulate the five frozen seats instead of fixing them. Their two-candidate
  margins are known; giving them the same swing-plus-noise treatment as the
  others would at least carry honest uncertainty. Prahran at 11.1 is the case
  that matters.
- Carry `sRunningParties` forward from 2022 as the assumed 2026 field, and say
  so, rather than assuming two majors implicitly.

**Not now — blocked on data:**

- One Nation or a new independent making a final two. That needs seat-level
  first preferences, which no file here contains. The seat files carry
  two-party margins only.
- theswingison's preference simulator, for the same reason: it distributes
  preferences among remaining candidates as others are eliminated, and there
  is nothing per-seat to eliminate.

## Also unread: fields we already have

`load_seats()` reads five fields. The 2026 file offers eleven:

| Field | Seats | Read? |
|---|---:|---|
| `fTransposedFederalSwing` | 89 | no |
| `bSophomoreCandidate` | 22 | no |
| `bRetirement` | 20 | no |
| `bSophomoreParty` | 8 | no |
| `fByElectionSwing` | 3 | no |

Retirement and sophomore effects are among the best-documented seat-level
swing predictors in Australian psephology. The page's caveat says
"Retirements, candidate quality... are all absent" — true, but that reads as a
data limitation when it is a choice made without noticing the data was there.

**Sizing first, as always:** the measured decomposition says the statewide
vote dominates the seat count (sd 10.87 from the projection alone against 3.96
from all seat and regional variation). So per-seat predictors are the smaller
lever, and should be judged against that, not adopted because they are
well-documented elsewhere.
