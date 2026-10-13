# Parse the AEC's official two-party preference FLOW tables (House, by state by
# party, 2007-2025) into one tidy file.
#
# Source: external/reference/aec/raw/tppflow/HouseTppFlowByStateByPartyDownload-<event>.csv
# (2004 returned 404 from the AEC, so the series starts 2007).
# Output: output/aec-tpp-flows.csv
#
# What one row is: for one party in one state (or nationally), the votes cast with
# that party as first preference that ended with Labor and with the Coalition in the
# AEC's two-party-preferred count (notional counts included), and the percent to Labor.
# `row_type`:
#   state_party     one row of the AEC file (state x party), every file column kept
#   total           the AEC's "First Preferences" row (PartyAb empty): ALL first
#                   preferences of the state, flowing or not, used as a coverage check
#   national_party  sum over states of a PartyAb (our aggregation)
#   national_class  sum over states and parties of one of OUR party classes
#
# COLUMN ORDER DIFFERS BY YEAR (Labor first in 2010, 2013 and 2025, Coalition first
# otherwise), so columns are mapped by HEADER NAME, never by position.
#
# Check codes: TQ1 columns mapped by name and percent recomputed from votes agrees with
# the published percent; TQ2 the mapping fails on a deliberately swapped input;
# TQ3 row counts and national Greens / One Nation per year.
#
# Run:  powershell.exe -Command 'Rscript "scripts/build_aec_tpp_flows.R"'

options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

DIR <- "external/reference/aec/raw/tppflow"
OUT <- "output/aec-tpp-flows.csv"

# Returns the mapped table. swap_for_test reverses which header gets which meaning,
# which is what a position-based reader would do on a differently ordered year.
read_tppflow <- function(f, swap_for_test = FALSE) {
  title <- readLines(f, n = 1, warn = FALSE)
  x <- fread(f, skip = 1, showProgress = FALSE, colClasses = list(character = c("StateAb", "PartyAb", "PartyNm")))
  nm <- names(x)
  col_for <- function(who, what) {
    hit <- grep(paste0("^", who, " Transfer ", what, "$"), nm)
    if (length(hit) != 1L) stop(sprintf("%s: expected exactly one column for %s %s, found %d",
                                        basename(f), who, what, length(hit)))
    nm[hit]
  }
  alp <- "Australian Labor Party"; lnp <- "Liberal/National Coalition"
  if (swap_for_test) { tmp <- alp; alp <- lnp; lnp <- tmp }
  yr <- as.integer(sub("^(\\d{4}) .*", "\\1", title))
  ev <- sub(".*\\[Event:(\\d+) .*", "\\1", title)
  data.table(year = yr, event = ev, state = x$StateAb, party_ab = x$PartyAb, party_name = x$PartyNm,
             alp_votes = as.numeric(x[[col_for(alp, "Votes")]]),
             lnp_votes = as.numeric(x[[col_for(lnp, "Votes")]]),
             alp_pct_published = as.numeric(x[[col_for(alp, "Percentage")]]),
             lnp_pct_published = as.numeric(x[[col_for(lnp, "Percentage")]]),
             source_file = basename(f), file_header = paste(nm, collapse = " | "))
}

files <- sort(list.files(DIR, "^HouseTppFlowByStateByPartyDownload-\\d+\\.csv$", full.names = TRUE))
stopifnot(length(files) == 7L)
A <- rbindlist(lapply(files, read_tppflow))
A[, row_type := fifelse(party_ab == "", "total", "state_party")]
A[, party_class := fifelse(row_type == "total", NA_character_, classify_party(party_name, party_ab))]
A[, flow_alp := 100 * alp_votes / (alp_votes + lnp_votes)]
setorder(A, year)
cat(sprintf("TQ3 read %d files, %d rows, years %s\n", length(files), nrow(A), paste(sort(unique(A$year)), collapse = " ")))
stopifnot(identical(sort(unique(A$year)), c(2007L, 2010L, 2013L, 2016L, 2019L, 2022L, 2025L)),
          !anyNA(A$alp_votes), !anyNA(A$lnp_votes))

# TQ1: recomputed percent equals the published percent (within rounding) on every row
d1 <- A[(alp_votes + lnp_votes) > 0, max(abs(flow_alp - alp_pct_published))]
d2 <- A[(alp_votes + lnp_votes) > 0, max(abs(100 - flow_alp - lnp_pct_published))]
cat(sprintf("TQ1 max |recomputed - published| ALP pct %.4f, LNP pct %.4f (rounding is 0.005): %s\n", d1, d2,
            if (d1 < 0.011 && d2 < 0.011) "OK" else "MISMATCH"))
stopifnot(d1 < 0.011, d2 < 0.011)

# TQ2 anchor check: the Greens send well over half their votes to Labor in every
# state and year (75-90% in this series). A reader that swapped the Labor and Coalition
# columns, as a position-based reader does on a differently ordered year, would put
# them under 40%. The percent-agreement check above cannot see that (votes and percent
# swap together; the first version of this test used it and did not fail), so this
# anchor is the one that matters. It must fail on swapped input.
greens_ok <- function(d) {
  g <- d[party_ab == "GRN" & (alp_votes + lnp_votes) > 5000]
  list(n = nrow(g), min = min(g$alp_votes / (g$alp_votes + g$lnp_votes)),
       ok = nrow(g) > 40 && all(g$alp_votes > g$lnp_votes))
}
g_real <- greens_ok(A)
cat(sprintf("TQ2 real input: %d Greens state-years, lowest Labor share %.3f -> %s\n", g_real$n, g_real$min,
            if (g_real$ok) "OK" else "FAIL"))
stopifnot(g_real$ok)
S <- rbindlist(lapply(files, read_tppflow, swap_for_test = TRUE))
g_bad <- greens_ok(S)
cat(sprintf("TQ2 swapped-column input: lowest Labor share %.3f -> check %s\n", g_bad$min,
            if (!g_bad$ok) "FAILS as it must" else "DID NOT FAIL (the check is blind)"))
stopifnot(!g_bad$ok)

# national rows: by PartyAb, and by our class
real <- A[row_type == "state_party"]
nat_p <- real[, .(alp_votes = sum(alp_votes), lnp_votes = sum(lnp_votes), party_name = party_name[1],
                  party_class = party_class[1], n_states = uniqueN(state)), by = .(year, party_ab)]
nat_p[, `:=`(state = "AUS", row_type = "national_party")]
nat_c <- real[, .(alp_votes = sum(alp_votes), lnp_votes = sum(lnp_votes)), by = .(year, party_class)]
nat_c[, `:=`(state = "AUS", row_type = "national_class", party_ab = NA_character_, party_name = NA_character_)]
nat_t <- A[row_type == "total", .(alp_votes = sum(alp_votes), lnp_votes = sum(lnp_votes)), by = year]
nat_t[, `:=`(state = "AUS", row_type = "total", party_ab = "", party_name = "First Preferences", party_class = NA_character_)]
N <- rbind(nat_p, nat_c, nat_t, fill = TRUE)
N[, flow_alp := 100 * alp_votes / (alp_votes + lnp_votes)]
ALL <- rbind(A, N, fill = TRUE)
setcolorder(ALL, c("year", "state", "party_ab", "party_name", "party_class", "row_type", "alp_votes", "lnp_votes", "flow_alp"))
setorder(ALL, year, row_type, state, party_ab)
dir.create("output", showWarnings = FALSE)
fwrite(ALL, OUT)

g <- N[row_type == "national_class" & party_class %in% c("GRN", "ONP")]
w <- dcast(g, year ~ party_class, value.var = c("flow_alp", "alp_votes"))
w[, `:=`(GRN_votes = alp_votes_GRN, ONP_votes = alp_votes_ONP)]
cat("TQ3 national flow to Labor, percent (Greens, One Nation) by year:\n")
print(g[, .(year, party_class, votes = alp_votes + lnp_votes, flow_alp = round(flow_alp, 2))], nrows = 50)
cat(sprintf("wrote %s: %d rows\n", OUT, nrow(ALL)))
