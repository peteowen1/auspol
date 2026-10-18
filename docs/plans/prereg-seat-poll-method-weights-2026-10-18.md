# Pre-registration: weight seat polls by how they were done and who paid (2026-10-18)

Committed BEFORE anything is built or run. Pete, 18 Oct: "we should check polling methodology for all these polls
and remove or downweight poor / non-rigourous methodology ... using all seats with seat polling, and assigning poll
type and seeing what weights should be".

## Why

McMahon fed2025: one Compass Polling survey (8 Apr 2025, n=1,003) had the independent at 41%; he got 9.8%. It was
an opt-in SMS-link survey with his name appearing preselected (Compass's own replies to ABC Media Watch), and our
blend weighted it like any direct poll, publishing him at 29.0 and 0.71 to win. Every seat poll is now classified
(`external/reference/polls/seat-polls/poll_methods.csv`, `reviews/seat-poll-methods-2026-10-18.md`). First read,
poll minus actual, MAE in points: media-paid direct 4.42 (48 polls); paid by a party, union, advocacy group or
industry body 5.74 (49; independents 7.81 vs 6.02); party-paid majors 15.5 (4); opt-in link 12.4 (2; independents
20.4); MRP 5.33 (940).

## What the blend does now (`R/seat_poll_blend.R`)

Each poll's weight is `0.5^(days/H) / (sampling variance + floor[group])`, the floor per group (`mrp`, `direct`,
`sponsored`) fitted on earlier elections and shrunk by `SEAT_POLL_FLOOR_K`. `sponsored` keys on the `client` column,
filled for about 35 of 1,210 polls, so stake-holder polls are almost all treated as `direct`.
`AUSPOL_SEAT_POLL_FIRM_FLOOR` (each firm's floor scaled by its own record, shrunk to 1) was built 9 Oct and never
scored on seat polls.

## Arms (switch `AUSPOL_SEAT_POLL_GROUPS`, plus the existing firm switch)

| Arm | Rule |
|---|---|
| A (shipped) | groups mrp / direct / sponsored from `client`; firm floor off. |
| G | groups from `poll_methods.csv`: `mrp`; `direct_indep` (media, pollster's own, or unknown sponsor); `direct_stake` (party, union, advocacy group, industry body, candidate campaign); `optin` (method optin_link). Floors fitted exactly as now (time-forward, shrunk to the pool by `SEAT_POLL_FLOOR_K`). A poll missing from the file keeps its old group. |
| F | firm floor on (`AUSPOL_SEAT_POLL_FIRM_FLOOR=1`), firm = `pollster_clean` from the file. |
| GF | both. |

**The opt-in prior, stated now because time-forward fitting cannot see it:** both opt-in polls are fed2025, so no
earlier election has one and G alone gives `optin` the pooled floor. `optin`'s floor prior is therefore 4x the
pooled floor (CHOSEN: an opt-in, self-selected sample has roughly twice the error sd of a panel or phone poll in the
survey-methods literature, so 4x the variance), still shrunk toward the data as elections with opt-in polls accrue.
Reported both with and without this prior (G and G0) so its effect is visible.

## Criterion

Screen on the elections with seat polls (`quick_arm.R --pairs=` fed2016 fed2019 fed2022 fed2025 nsw2015 nsw2019
nsw2023 qld2017 qld2020, 5,000 sims), then a 20,000-sim deciding run on the best arm.

1. **Primary: seat log loss on seats that had at least one seat poll**, SE clustered on election. An arm ships if it
   beats A by more than 1 SE. If more than one does, the simplest (G before F before GF) unless a fuller one is
   better by more than 1 SE again.
2. **Guard: every seat in those elections**, not worse by more than 1 SE.
3. **Reported:** McMahon fed2025 (IND share and win probability), the seat-poll share RMSE by group, fed2025 alone
   (where seat polls deserved about 0.13 and got 0.55), and each group's fitted floor per target.

## What would make an apparent win unacceptable (decided now)

- One election supplies more than half the primary gain -> refused.
- The gain is ONLY McMahon (drop it and the arm is within 1 SE) -> reported to Pete as a one-seat result.
- Live vic2026: any seat whose favourite moves more than 10 points is listed for Pete (vic2026 has few seat polls).

## What this cannot see

- 141 direct polls have no known method and 86 no known sponsor; they keep `direct_indep`.
- Method labels for non-MRP polls are mostly the agent's inference from each firm's usual practice (medium/low
  confidence); only sponsor labels backed by a "commissioned by" footnote are high confidence.

## Amendment 1 (2026-10-18, before anything is built; Pete: "maybe the assumption is weight is 0 until proven otherwise
## and this type of poll stays at weight near 0 ... not being hacky but being bayesian")

The original text stands. The opt-in prior changes from "4x the pooled floor" to an explicit error-size prior:
**an opt-in seat poll is assumed to miss by about 15 points (floor prior 225 = 15^2)** until its own record says
otherwise. CHOSEN, and stated as an error size so it can be read and argued with: at that floor its weight is roughly
a tenth of a typical direct poll's, i.e. near zero, as Pete asked. It is shrunk toward the group's observed floor by
the same `SEAT_POLL_FLOOR_K` pseudo seat-elections as every other group, so only accumulated evidence moves it.
Every other group keeps the existing prior (the pooled floor), so the rule is one rule for all groups with one
documented prior per group, not a special case. G0 (no opt-in prior) is still reported, so the prior's effect is
visible on its own.

## Amendment 2 (2026-10-18, before anything is built or run; Pete: "One Bayesian blend")

The original text and amendment 1 stand. Tracing McMahon end to end in the SHIPPED blend (scratchpad `mcmtrace.R`,
our pre-blend shares fed in) showed the groups alone cannot fix it: IND 4.9 -> 28.3 shipped, 27.5 with arm G, 29.6
with the existing precision blend. Three causes, all general:
1. **One model uncertainty per class.** `seat_poll_model_var()` gives every independent sd 14.8 points, so any poll
   outvotes the model on a 5% independent.
2. **The independent cell is overwritten by the direct-poll figure alone** (`.ind_direct_cells()`), so McMahon's
   MRPs (independent 3.9-6.6) never vote on it, and a lone direct poll is never weighed against anything.
3. **"Others" in a poll is split only over OTH_RIGHT / ONP / OTH**, so McMahon's RedBridge MRP others (17-19)
   went wholly to One Nation (actual 8.7) and none to the independent.

**Arm B (one Bayesian blend)** = all of these together, each behind its own switch so its contribution is measured:
- `AUSPOL_SEAT_POLL_PRECISION_BLEND=1` (built, off): each cell's pull is `v / (v + 1/P)`, P the summed per-poll
  precisions.
- `AUSPOL_SEAT_POLL_SIZEVAR=1` (new): the model's error variance `v` for a cell depends on the class AND our
  predicted share: per class, `v = v_c * ((pred + 1) / (ref_c + 1))^g`, `v_c` and `ref_c` the class's shrunk
  variance and median prediction on earlier elections' polled cells (as now), `g` one exponent fitted on the same
  earlier cells (least squares on log squared error), shrunk toward 0 by its SE (`w = max(0, 1 - se^2/g^2)`).
- `AUSPOL_SEAT_POLL_ALLPOLLS=1` (new): no direct-only override of the independent cell; every poll (MRP and direct)
  enters the cell with its own floor-and-recency weight.
- `AUSPOL_SEAT_POLL_GROUPS=method` (built): group floors from the method file, opt-in prior 225.
- `AUSPOL_SEAT_POLL_SPLIT_ALL=1` (new): a poll's "others" is split over EVERY class standing in the seat that the
  poll does not name (independent and Greens included), in proportion to our as-at expectation; the existing
  endorsed/sitting OTH-to-IND rule is unchanged.

**Arms screened:** A (shipped); B (all five); and B minus each one in turn (five arms). The primary, guard and
refusal clauses above apply to B; the leave-one-out arms are REPORTED, so any piece that adds nothing can be dropped
before the deciding run (a piece whose removal does not worsen B by more than 1 SE is dropped: fewer moving parts).
McMahon's end-to-end independent share and win probability are reported for every arm.

### Amendment 2 bug fix (2026-10-18 14:50; no criterion, grid or decision rule changed)

The first arm-B screen showed SPLIT_ALL excluding every class a poll names. Kennedy 2022's poll names the UAP (our
OTH_RIGHT) at 6 while Katter (also OTH_RIGHT) sits in its OTH 43, so Katter got none of it: P(actual winner)
0.994 -> 0.067. Fixed before any arm was read for a decision. A named single-candidate class (ALP, LNP, GRN, ONP)
takes none of OTH; a named pooled class (IND, OTH_RIGHT, OTH) keeps a claim on its expected share beyond what the poll
reports (the shipped rule's residual). Kennedy OTH_RIGHT now 45.8 (actual 46.1). Also: nsw2015 and nsw2019 have no
seat polls, and fed2016's 268 are two-party only, so the primary metric's polled seats are fed2019 9, fed2022 151,
fed2025 150, nsw2023 1, fed2016 1 (Mayo, hand-keyed); the scorer now counts only polls with a primary figure.
All arms rerun on the fixed code.

## Amendment 3 (2026-10-18 15:45, before anything is built or run; Pete: "go")

The original text and amendments 1-2 stand. Arm B's first full screen (primary -0.0059, SE 0.0040; refused by the
one-election clause, fed2022 89% of the gain) lost on real independents. Traced end to end: Curtin 2022's YouGov MRP
never modelled Chaney; her vote sits in its "others" 14, which the endorsed-independent remap (SPIM `OTH -> IND`) files
as an IND figure, and under ALLPOLLS that derived 14 voted with an MRP's weight: Chaney 25.5 -> 22.6 (actual 29.5).
Pete: polls that name the candidate should do the work and a bad poll should have no influence; a figure carved out of
a poll's "others" is not the pollster's measurement of anyone.

**`AUSPOL_SEAT_POLL_NAMED_ONLY=1` (new):** a poll votes on a seat-class cell only if it names EVERY candidate of that
class standing in the seat (candidates per class from `output/candidacies.csv`, poll entries per class counted BEFORE
any remap or split), or its "others" figure is zero. Single-candidate classes (ALP, LNP, GRN, ONP) are fully named
whenever they appear. Cells built from "others" (the IND remap, the known-class split, SPLIT_ALL) never vote. A cell no
poll measures keeps our own prediction. Kennedy 2022 (UAP named, Katter in others): OTH_RIGHT is not fully named, so
the poll does not vote on it and the model's 44.7 stands (actual 46.1). McMahon: YouGov names the independent (3.9-6.6)
and votes; RedBridge (independent in others) does not.

**Arms:** C = B + NAMED_ONLY; C minus SIZEVAR (the size rule is the other suspect for Warringah 2019 and Mayo 2016,
whose only polls were GetUp-paid). Same metrics, clauses and scorer as B. Reported per arm: McMahon, Curtin, Warringah
2019, Mayo 2016, Goldstein 2025, Kennedy 2022.

## Amendment 4 (2026-10-18 16:00, before anything is built or run; Pete: "lets try this")

The original text and amendments 1-3 stand. Pete: use salience to tell a real independent surge (Steggall 2019, Chaney
2022, Sharkie 2016: polls right, model low) from a lone bad poll (McMahon 2025). Campaign rise in search interest
(`jump`, `output/salience-v6.csv`): Steggall 2019 0.772, Sharkie 2016 0.390, Daniel 2022 0.092, Chaney 2022 0.052,
Camenzuli 2025 0.014. fed2025 is cached (613 candidates); its xgb `surge_h` is a filler 0 (NEXT-STEPS F21), which this
arm does not use.

**`AUSPOL_SEAT_POLL_SALIENCE_VAR=1` (new):** under the precision blend, an independent cell's model variance is
multiplied by `exp(b * x)`, `x = log(jump + 0.01)` minus its mean over the earlier elections' polled independent cells,
`b` fitted on those cells (least squares on log squared error, the same cells as the size exponent), shrunk toward 0
by its SE. High search-interest rise means a less certain model, so a poll moves it more. No salience row: `x = 0`
(multiplier 1, the class's ordinary variance). Reported: `b`, its SE, and the multiplier for the six named seats.

**Arms (with C and C-minus-SIZEVAR from amendment 3):** D = C + SALIENCE_VAR; D minus SIZEVAR. Same metrics, clauses and
scorer. Dry-run before scoring: print the multiplier for Warringah 2019, Curtin 2022, Mayo 2016, McMahon 2025.

## Amendment 5 (2026-10-18 16:30, before anything is built or run; Pete: "go")

The original text and amendments 1-4 stand. The leave-one-out arms located Warringah 2019 (P(win) 0.235 -> 0.121) and
Mayo 2016 (0.084 -> 0.037): unchanged without SIZEVAR or GROUPS, restored only without PRECISION_BLEND. The precision
pull `v / (v + 1/P)` uses a model variance `v` fitted on earlier elections' POLLED cells only; before fed2022 there are
almost none, so `v` sits at its prior 25 (sd 5) for every class, including independents (true model error sd ~15), and
one decent poll gets a pull of ~0.44 where the shipped rule gave 0.891.

**`AUSPOL_SEAT_POLL_MODELVAR_ALL=1` (new):** `v` (per class, and the size exponent) is fitted on EVERY earlier
election's seat-class cells with a prediction and a result (`current_seat_predictions()`, time-forward), not only the
polled ones. The model's own error does not need a poll to be measured. Same shrinkage, same K.

**Arms (replacing amendment 3-4's list; nothing was run under it):** C = B + NAMED_ONLY + MODELVAR_ALL; C minus
MODELVAR_ALL; D = C + SALIENCE_VAR. Same metrics, clauses, scorer and named seats. Dry-run before scoring: print `v` for
IND at fed2016 and fed2019 under both settings.

## Amendment 6 (2026-10-18 17:35, before anything is built or run; Pete: "build direct polls only for now")

The original text and amendments 1-5 stand. Arm C (amendment 5) did not pass (polled seats +0.0007, SE 0.0131) and broke
Mayo 2025: YouGov's MRP lists a generic "IND" 1.9-2.1 that is not Sharkie (she sits in its OTH 31-44); with one
independent on the ballot, NAMED_ONLY read that label as naming her, and the 1.9 voted: Sharkie 31.1 -> 8.5 (actual 29.9),
P(win) 0.947 -> 0.102. An MRP's party columns are not candidates, so a label cannot say whether its IND is the
independent standing. Arm D (C + salience) was stopped unread for the same flaw.

**`AUSPOL_SEAT_POLL_IND_DIRECT=1` (new, with NAMED_ONLY):** an MRP never votes on an independent's cell; direct seat
polls (which ask about the actual candidates) do, each by its own precision (floor by method group, recency, sample),
not by the fixed IND weight. MRPs keep voting on ALP, LNP, GRN and ONP. Pete's longer-term fix, queued: a table of which
named candidates each MRP release modelled (agent research under way, `mrp_candidates.csv`), so an MRP votes on an
independent it names.

**Arms (replacing amendment 5's list; C was read, D was not):** E = C + IND_DIRECT; F = E + SALIENCE_VAR. Same metrics,
clauses, scorer and named seats (adding Mayo 2025 and Warringah 2025).
