# Pre-registration: lean toward the sponsor in paid SEAT polls (arm SPL), 14 Nov 2026

Pete, 14 Nov ("Build it"), after the walk `reviews/seat-poll-paid-lean-walk-2026-11-14.md`: 29 measurable paid
seat polls overstate the sponsor's side by +3.03 points net of independent seat polls of the same election
(SE 0.92 treating polls as independent; 20 of 29 positive). Statewide arm PPC (shipped 13 Nov) is the template.
Paid seat polls already get a wider noise floor (`direct_stake`, arm H, 18 Oct); this arm adds only the lean.

Switch: `AUSPOL_SEAT_POLL_PAID_LEAN` ("0" published until this passes). Code: `R/seat_paid_lean.R`, applied in
`.seat_poll_shares_impl()` to each paid poll's figures before they are averaged into the seat (every harness and
`fit_seats_full.R` read seat polls through that one function).

## Method (fixed before any score)

1. **Per paid seat poll** (group `direct_stake`, side from `sponsor_side.csv` via `paid_poll_side()` on the sponsor
   in `poll_methods.csv`, else the poll's `client`): the sponsor side's share minus its actual share in that seat.
   Primary when the poll names ALP, LNP and GRN (its figures scaled to 100); else the two-candidate share when the
   poll's pair is the final pair in `external/elections/aec-fed-tcp.csv` (federal only). An IND-side poll with no
   IND figure is measured on two-candidate only. UNKNOWN sides are not measured and get no lean.
2. **Net of independent polls**: minus the mean of the same side measure over independent direct seat polls
   (`direct_indep`, primary, complete) of the same election, that mean shrunk to 0 by n/(n+3)
   (`AUSPOL_CONSERVE_SHRINK_K`'s form): an election's general polling error is not a sponsor's lean.
3. **Time-forward**: the lean for target election T uses only elections with polling day before T's.
4. **Pooling**: per side, m = mean net gap. SE clustered on (election, sponsor): pooled residual variance over all
   paid polls divided by the side's number of clusters (Advance's six same-day polls are one cluster, not six).
   Across sides, DerSimonian-Laird as arm PPC: mu (inverse-variance), tau^2, w0 = mu^2/(mu^2 + se_mu^2),
   mu_s = w0 * mu, side lean = mu_s + w (m - mu_s) with w = tau^2/(tau^2 + se^2). A known side with no data gets mu_s.
5. **Apply**: the lean (scaled by the poll's own total / 100) comes off the side's parties in proportion to their
   figures and goes to the poll's other figures in proportion. An IND-side poll with no IND figure is left alone.

## Checks and decision rule

- **C1 placebo** (`scripts/screen_seat_paid_lean.R`): 20 repeats, each labelling 25 random independent direct seat
  polls as paid with sides drawn from the real paid sides; the fit on all elections must give |side lean| < 1 SE on
  every side and pool in at least 16 of 20. Fail = the estimator invents a lean: stop.
- **C2 untouched**: every scored election with no paid seat poll before its polling day is byte-identical
  (quick_arm prints 0 changed cells).
- **C3 targeted, primary**: seat-winner log loss on the seats of the touched scored elections (fed2022, fed2025,
  nsw2023; the paid polls of fed2016 and fed2019 have no earlier data, so no lean) that HAVE a paid seat poll,
  `quick_arm.R --pairs=fed2022,fed2025,nsw2023`, clustered SE on election.
- **C4 guard**: seat log loss on all seats of those elections not worse by more than 1 SE.
- **C5 live walk**: vic2026 with and without, the Hawthorn poll before and after, every seat whose win
  probability moves by more than 1 point.

**Decision**: the walk is the evidence for the lean; the targeted set is about 30 seats, so its MDE is far larger
than the expected effect (a 3-point primary shift in one poll among several per seat) and C3 cannot confirm it.
C3 is therefore a do-no-harm check: **ship if C1 passes, C2 is byte-identical, C3 is not worse by more than 1 SE,
and C4 passes.** Anything else goes to Pete with the split. What would make an apparent pass unacceptable: a lean
on any side larger than 6 points after shrinkage (twice the walk's pooled net), or the live Hawthorn Liberal
figure moving by more than the poll's own lean.

Limits named now: the noise floors (arm H) were fitted on uncorrected polls, so paid polls stay slightly too wide
after the lean comes off (conservative). The two-candidate measure exists for federal only.
