# Wires the pre-nomination vic2026 salience fetch into the file
# governed_population()/surge_hazard_for() actually read (output/salience-v6.csv).
#
# WHY THIS SCRIPT EXISTS. scripts/fetch_seat_salience_vic2026_live.R writes
# output/vic2026-live-salience.csv -- a DIFFERENT file, DIFFERENT schema
# (seat, cand, party, sal_share, sal_raw, fetched_at). Nothing read that file
# until now: governed_population() (R/salience_screen.R) reads exclusively
# output/salience-v6.csv, keyed by election/seat/party/keyword and expecting
# columns jump/prev_party/elected/pcv/governed. The two pipelines were built
# in separate sessions and never actually connected -- caught by review
# 2026-09-10, before AUSPOL_XGB_PRIMARY_LIVE was flipped on, not after. An
# earlier ad-hoc test had hand-edited salience-v6.csv directly to prove the
# mechanism COULD work; that edit was never reproducible from any script and
# did not survive a later regeneration. This script is the real, rerunnable
# version of that edit.
#
# IDEMPOTENT: removes any existing vic2026 rows before appending fresh ones,
# so re-running (e.g. after more candidates are fetched, or after 9 Nov
# nominations close and a fuller fetch replaces this one) is safe.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
live_f <- file.path(OUT, "vic2026-live-salience.csv")
sal_f  <- file.path(OUT, "salience-v6.csv")
cand_f <- file.path(OUT, "candidacies.csv")

if (!file.exists(live_f)) {
  stop("Missing ", live_f, " -- run scripts/fetch_seat_salience_vic2026_live.R first.")
}
if (!file.exists(sal_f)) stop("Missing ", sal_f)
if (!file.exists(cand_f)) stop("Missing ", cand_f)

live <- fread(live_f, showProgress = FALSE)
need <- c("seat", "cand", "party", "sal_raw")
miss <- setdiff(need, names(live))
if (length(miss)) stop(live_f, " is missing column(s): ", paste(miss, collapse = ", "))
cat(sprintf("BV1  %d live-salience rows read (%d seats, %d candidates)\n",
            nrow(live), uniqueN(live$seat), uniqueN(live$cand)))

# prev_party: the CLASS's own max(pcv) in the seat at the prior election
# (vic2022) -- same convention scripts/fetch_salience_v6.R uses (its own
# `prev_pcv`, max(pcv) by (seat,party), 0 where the class did not contest).
C <- fread(cand_f, showProgress = FALSE)
PREV <- C[C$election == "vic2022"]
prevp <- PREV[, .(prev_party = max(pcv, na.rm = TRUE)), by = .(seat, party)]
prevp[!is.finite(prev_party), prev_party := 0]

new_rows <- merge(live, prevp, by = c("seat", "party"), all.x = TRUE)
new_rows[!is.finite(prev_party), prev_party := 0]

# jump: normally a campaign-vs-baseline RISE in search interest; no baseline
# period exists this early (candidates only just started registering any
# interest at all), so the raw interest LEVEL (sal_raw) is used directly as
# a proxy. Its observed range (0-22.6) sits inside historical jump's real
# positive range (0-31.3) -- not rescaled further, since doing so from a
# 43-candidate sample would invent precision this data doesn't support.
# pcv/elected are the TARGET election's own outcome columns -- genuinely
# unknowable before 28 Nov 2026, left NA rather than guessed. Neither is
# read by governed_population()'s own logic (confirmed: it computes
# `governed` from prev_party/party/surging/ret only), so NA here is safe,
# not a silent gap.
out <- new_rows[, .(
  keyword = cand,
  election = "vic2026",
  seat = seat,
  party = party,
  pcv = NA_real_,
  elected = NA,
  prev_party = prev_party,
  jump = sal_raw
)]

existing <- fread(sal_f, showProgress = FALSE)
before_n <- nrow(existing)
existing <- existing[existing$election != "vic2026"]
dropped <- before_n - nrow(existing)
if (dropped) cat(sprintf("BV2  removed %d stale vic2026 row(s) before re-appending (idempotent rerun)\n", dropped))

combined <- rbindlist(list(existing, out), fill = TRUE)
fwrite(combined, sal_f)
cat(sprintf("BV3  wrote %s: %d vic2026 rows added, %d total rows (was %d)\n",
            sal_f, nrow(out), nrow(combined), before_n))
cat(sprintf("BV3  by class: %s\n",
            paste(sprintf("%s=%d", names(table(out$party)), as.integer(table(out$party))), collapse = " ")))
