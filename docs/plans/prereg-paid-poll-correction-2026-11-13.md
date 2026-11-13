# Pre-registration: correct party- and advocacy-paid statewide polls (noise + lean toward the sponsor), 13 Nov 2026

Pete, 13 Nov, after the Greens' internal ORU Victorian poll (14-26 Oct) was found entering the trend at full weight
through the Wikipedia layer: *"Test it first. Let's get it working. Shrinkage or better method. Don't just add as is."*
Method chosen by Pete from two options: **extra noise AND a lean toward the sponsor's side**, both shrunk. Sponsor
sides: `external/reference/polls/sponsor_side.csv` (drafted by Claude, approved by Pete 13 Nov as drafted).

## Why the 4 Nov arm SPN does not answer this

SPN (`prereg-poll-lean-2026-11-02.md`) learned leans against RESULTS, and Wikipedia names sponsors only from 2025, so its
"party" class had **zero training elections**. Its +0.0548 came from the media and unknown classes. Party-paid polls are
untested, not refused.

## Method (arm PPC, switch `AUSPOL_PAID_POLL_CORRECT`, published value "0" until decided)

Everything is estimated from POLLS ONLY, as of the forecast's cutoff, so there is no outcome and no leakage: a paid
poll is compared with the independent polls taken at the same time.

1. **Which polls are paid.** A fitted poll (`load_polls()` row) whose matched Wikipedia row has a client hit by
   `POLL_SPONSOR_ADVOCACY` (`R/poll_sponsor.R`, class "party"). Its side is the first `sponsor_side.csv` pattern that
   hits the client: LNP, ALP, GRN, ALP+GRN, IND or UNKNOWN. All regions, all dates up to the cutoff.
2. **Reference.** For each fitted poll (paid or not), per party: the mean of the OTHER independent polls (class
   media/unknown) of the same region with fieldwork midpoint within 21 days, needing at least 2 of them. Deviation
   `d = poll - reference`. Independent polls' own deviations (leave-self-out) give the baseline variance `v0` per
   party: what an ordinary poll's gap from its neighbours looks like.
3. **Lean.** For a paid poll with a known side, `s = sum of d over the side's parties` (the side's combined share gap;
   for IND, the IND column or OTH where IND is not separate). Per side: mean `m_side` with standard error from `v0`
   and the polls' count. Partial pooling, the CLAUDE.md shrinkage rule: sides are draws around an overall
   toward-sponsor lean `mu` (precision-weighted mean of the side means); between-side variance `tau^2` by
   DerSimonian-Laird; `shrunk_side = mu_s + w (m_side - mu_s)`, `w = tau^2 / (tau^2 + se_side^2)`, where `mu_s` is
   `mu` itself shrunk to zero by `w0 = mu^2 / (mu^2 + se_mu^2)` (no evidence of a lean, no lean). A side with no
   polls gets `mu_s`; UNKNOWN gets 0.
4. **Correction.** The side's share in each paid poll is lowered by its shrunk lean, split over the side's parties in
   proportion to their shares; the removed points go to the other parties in proportion, so the poll still sums to
   its total.
5. **Extra noise.** After the lean, residual `r = d - lean` per party for paid polls; extra variance
   `x^2 = max(0, mean(r^2) - mean(v0))`, shrunk by `n / (n + 3)` (the `AUSPOL_CONSERVE_SHRINK_K` precedent).
   Each paid poll is fitted under its own firm label (`<firm> [paid]`) with `firm_factors` noise multiplier
   `sqrt(1 + x^2 / mean(v0))`, so it counts for less in the trend. No clip.

## Checks named before any number is seen

- **C1 placebo (instrument check).** Run steps 2-5 with a random 20 of the independent polls of 2024+ labelled "paid"
  (side drawn at random from the paid polls' sides), 20 repeats. Expect the shrunk lean within 1 SE of zero and the
  noise factor under 1.1 in at least 16 of 20. Failure means the estimator invents bias, and the arm stops.
- **C2 untouched.** Every scored election whose cycle has no paid poll before its cutoff must be byte-identical to the
  published trend (same day-before primaries to 1e-9).
- **C3 do-no-harm** on the scored elections that DO have paid polls (screen harness of
  `scripts/screen_poll_lean_spn.R`, day-before mean absolute error over ALP, LNP, GRN, ONP, other): no worse than
  published by more than 1 SE of that election's change. Expected to be very few elections (sponsors are recorded only
  from 2025); the count is printed and the result is a do-no-harm check, not evidence of a gain.
- **C4 the live walk, vic2026**, shown to Pete row by row: each paid Vic poll (the Greens' ORU, Common Threads, the
  2025 Liberal Freshwater) before and after, the lean table, the noise factor, and the trend's primaries with and
  without. Pete decides from C1-C4; a pass of C1-C3 is necessary, not sufficient.

## Not done here (said plainly)

- Seat polls: stakeholder seat polls already get their own noise floor (`direct_stake`, arm H, shipped 18 Oct); a
  seat-poll lean against results (68 polls, 48 of them fed2025) is a separate arm after this one.
- No outcome-based test of a gain is possible yet; vic2026 (28 Nov) is the first completed election with labelled
  party polls in a scored cycle.

## RESULT

(Filled in after the runs; this section is the only part written after numbers were seen.)
