# AEC two-party flow to Labor by STATE and party CLASS, every federal election 2007-2025, for
# AUSPOL_STATE_FLOWS_AEC (docs/plans/prereg-state-flows-aec-2026-10-30.md). Small and committed, so the
# published run on GitHub has it without output/ or the raw AEC files.
# Input: output/aec-tpp-flows.csv (scripts/build_aec_tpp_flows.R; state_party rows, AEC HouseTppFlowByStateByParty).
# Output: inst/extdata/aec-state-class-flows.csv: fed_year, state (lower case), party (class), alp_votes,
#   lnp_votes, flow_alp (percent of the class's transferred votes reaching Labor).
# Check codes AFS1-AFS2.
suppressMessages(library(data.table))
A <- fread("output/aec-tpp-flows.csv")
s <- A[A$row_type == "state_party"]
cat(sprintf("AFS1 %d state_party rows, years %s, states %s\n", nrow(s), paste(sort(unique(s$year)), collapse = ","),
            paste(sort(unique(s$state)), collapse = ",")))
o <- s[, list(alp_votes = sum(alp_votes), lnp_votes = sum(lnp_votes)), by = list(fed_year = year, state = tolower(state), party = party_class)]
o[, flow_alp := round(100 * alp_votes / (alp_votes + lnp_votes), 3)]
setorder(o, fed_year, state, party)
chk <- o[o$state == "vic" & o$party == "GRN"]
cat("AFS2 VIC Greens by year:", paste(sprintf("%d %.2f", chk$fed_year, chk$flow_alp), collapse = " | "), "\n")
dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
fwrite(o, "inst/extdata/aec-state-class-flows.csv")
cat(sprintf("AFS2 wrote %d rows\n", nrow(o)))
