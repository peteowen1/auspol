# Audit the observed preference-flow record for carried-forward duplicates.
#
# The record is what flows_for()/estimate_flow() treat as OBSERVED elections.
# A value repeated verbatim from an earlier election in the same region+party
# series is a carried-forward assumption wearing an observation's clothes, and
# it matters twice over: it is not evidence, and as a BACKTEST TARGET it is
# free money for any estimator that predicts persistence.
#
# This exists because the first audit of this was done ad hoc and its numbers
# could not be reproduced -- a later run of the same logic disagreed with the
# figures already written into docs/reviews/. An audit whose result depends on
# when it was run is not an audit.
#
# Two definitions are reported because they answer different questions and
# give different counts:
#   immediate  - equals the value in the immediately preceding election.
#                This is the one that flatters persistence estimators.
#   any_prior  - equals ANY earlier value in the series. This is the wider
#                measure of how much of the record is not independent evidence.
#
# Run from repo root:  powershell.exe -Command 'Rscript "scripts/audit_flow_record.R"'

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

as_of <- Sys.Date()
flows <- as.data.table(load_preference_flows())
cycles <- load_election_cycles()
flows[, is_obs := is_observed_election(flows, cycles, as_of)]

cat(sprintf("as_of %s | rows in file %d | observed %d\n\n",
            format(as_of), nrow(flows), sum(flows$is_obs)))

obs <- flows[is_obs == TRUE]
setorder(obs, region, party, year)
obs[, immediate := {
  v <- flow_alp
  !is.na(shift(v)) & v == shift(v)
}, by = .(region, party)]
obs[, any_prior := {
  v <- flow_alp
  vapply(seq_along(v), function(i) i > 1L && v[i] %in% v[seq_len(i - 1L)],
         logical(1))
}, by = .(region, party)]
obs[is.na(immediate), immediate := FALSE]

report <- function(d, label) {
  cat(sprintf("%-22s n=%3d | immediate %2d (%.1f%%) | any_prior %2d (%.1f%%)\n",
              label, nrow(d), sum(d$immediate), 100 * mean(d$immediate),
              sum(d$any_prior), 100 * mean(d$any_prior)))
}
report(obs, "all observed rows")
report(obs[year >= 2004], "observed, 2004 on")

cat("\n=== series with repeated values (any_prior) ===\n")
rep_rows <- obs[any_prior == TRUE]
if (nrow(rep_rows)) {
  s <- rep_rows[, .(times = .N + 1L, years = paste(year, collapse = ",")),
                by = .(region, party, flow_alp)][order(-times)]
  print(s)
}

cat("\nNote: a repeat is not proof of error. Only one has been checked against\n")
cat("a real count -- Victorian 2022 Greens, recorded 81.94, measured 79.2.\n")
cat("See docs/reviews/vic-preference-flows-2026-08-18.md.\n")
