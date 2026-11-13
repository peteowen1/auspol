# Arm SPL checks that need no harness run (docs/plans/prereg-seat-paid-lean-2026-11-14.md):
#   SPS1  the fits per target election (time-forward), as SPL1 prints them
#   SPS2  C1 placebo: 20 repeats, 25 random independent direct seat polls labelled paid with real sides
#   SPS3  C5 live: vic2026 seat-poll cells with the arm off and on (Hawthorn's paid poll), per class
# C2-C4 come from the deciding run (scripts/deciding_run.ps1 -Arm "AUSPOL_SEAT_POLL_PAID_LEAN=1").
#   powershell.exe -Command 'Rscript "scripts/screen_seat_paid_lean.R"'
# Writes nothing to output/. Data.table NSE: no local shares a column name inside [...].

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
source("scripts/published_flags.R")
for (k in names(PUBLISHED_FLAGS)) if (Sys.getenv(k) == "") do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[k]]), k))

cat("SPS1  time-forward fits:\n")
for (t in c("fed2022", "nsw2023", "fed2025", "vic2026")) invisible(seat_paid_lean(t))

ed <- election_dates()
utils::capture.output(s <- .read_seat_polls_file(file.path(pkg_root(), "external", "reference", "polls", "seat-polls", "seat_polls.csv")))
els <- intersect(unique(s$election), names(ed))
els <- els[as.Date(unname(ed[els])) < as.Date(unname(ed["vic2026"]))]
INP <- Filter(Negate(is.null), setNames(lapply(els, .seat_paid_lean_inputs), els))
cat("SPS2  elections with seat polls and results:", paste(names(INP), collapse = ", "), "\n")
real <- rbindlist(lapply(names(INP), function(e) { r <- INP[[e]]$raw
  u <- unique(r[r$group == "direct_stake", c("poll_id", "sponsor"), with = FALSE], by = "poll_id"); u }))
real_sides <- paid_poll_side(real$sponsor); real_sides <- real_sides[real_sides %in% SEAT_PAID_LEAN_SIDES]
pool <- rbindlist(lapply(names(INP), function(e) { r <- INP[[e]]$raw
  data.table(el = e, poll_id = unique(r$poll_id[r$group == "direct_indep"])) }))
cat(sprintf("SPS2  real paid sides %d (%s); independent direct polls to draw from %d\n", length(real_sides),
            paste(names(table(real_sides)), table(real_sides), collapse = ", "), nrow(pool)))
stopifnot(length(real_sides) > 0, nrow(pool) >= 25)

set.seed(20261114)
plc <- rbindlist(lapply(1:20, function(rep_) {
  pick <- pool[sample(nrow(pool), 25)]
  pick[, side := sample(real_sides, .N, replace = TRUE)]
  per <- lapply(names(INP), function(e) {
    inp <- INP[[e]]; r <- copy(inp$raw)
    r$group[r$group == "direct_stake"] <- "excluded"
    ids <- pick$poll_id[pick$el == e]
    r$group[r$poll_id %in% ids] <- "direct_stake"
    inp$raw <- r
    .seat_paid_lean_election(e, inp, sides = setNames(pick$side[pick$el == e], ids))
  })
  per <- Filter(Negate(is.null), per)
  dev <- rbindlist(lapply(per, `[[`, "dev"), fill = TRUE)
  dfi <- sum(vapply(per, `[[`, 1, "ind_df"))
  f <- seat_paid_lean_fit(dev, if (dfi > 0) sum(vapply(per, `[[`, 1, "ind_ss")) / dfi else NA_real_, dfi)
  worst <- if (nrow(f$lean)) max(abs(f$lean$shrunk) / f$lean$se) else 0
  data.table(rep = rep_, measured = f$n, sides = nrow(f$lean), pooled = f$mu, shrunk = f$mu_s,
             max_abs_lean = if (nrow(f$lean)) max(abs(f$lean$shrunk)) else 0, max_lean_in_se = worst, pass = worst < 1)
}))
cat("\nSPS2  C1 placebo (lean in points of the side's share; pass = every side's shrunk lean under 1 SE)\n")
print(plc[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 2) else x)])
cat(sprintf("SPS2  C1: %d of 20 pass (need 16): %s\n", sum(plc$pass), if (sum(plc$pass) >= 16) "PASS" else "FAIL -- the estimator invents a lean; stop"))

cat("\nSPS3  C5 live vic2026 seat-poll cells, arm off vs on (poll = the seat's blended poll figure, %):\n")
Sys.setenv(AUSPOL_SEAT_POLL_PAID_LEAN = "0"); off <- seat_poll_shares("vic2026")
Sys.setenv(AUSPOL_SEAT_POLL_PAID_LEAN = "1"); on <- seat_poll_shares("vic2026")
cmp <- merge(off[, c("seat", "class", "poll"), with = FALSE], on[, c("seat", "class", "poll"), with = FALSE],
             by = c("seat", "class"), suffixes = c("_off", "_on"))
cmp[, change := poll_on - poll_off]
print(cmp[abs(cmp$change) > 1e-9][order(seat, class)])
cat(sprintf("SPS3  cells changed: %d of %d (seats: %s)\n", sum(abs(cmp$change) > 1e-9), nrow(cmp),
            paste(unique(cmp$seat[abs(cmp$change) > 1e-9]), collapse = ", ")))
