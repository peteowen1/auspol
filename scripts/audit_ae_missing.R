# Split the "missing" bucket of scripts/audit_ae_dependence.R: AE-only polls in elections Wikipedia covers. Is each
# one on the Wikipedia page but dropped by our parser or filters (parser work), or not on the page (source work)?
# Looks for the same poll (same firm after aliasing, midpoint within 4 days) in EVERY parsed row of the scrape,
# including the tables and rows wiki_polls() filters out, and names why it was dropped. Also lists tables the
# scraper could not parse on the pages of those elections. Writes output/ae-missing-split.csv. Emits AM* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
Sys.setenv(AUSPOL_POLL_SOURCE = "layered")
base <- file.path("external", "reference", "polls", "statewide-samples")
W <- fread(file.path(base, "statewide_polls_wiki.csv"), showProgress = FALSE)
alias <- fread(file.path(base, "firm_alias.csv"), showProgress = FALSE)
TO <- fread(file.path(base, "table_outcomes.csv"), showProgress = FALSE)
cyc <- load_election_cycles(); eds <- election_dates()
targets <- c(vapply(all_election_pairs(), `[[`, "", "election"), "vic2026", "nsw2027")
fs <- as.Date(W$fieldwork_start); fe <- as.Date(W$fieldwork_end)
W$mid <- as.Date(ifelse(is.finite(fs) & is.finite(fe) & fs <= fe, as.integer(fs) + (as.integer(fe) - as.integer(fs)) %/% 2L, as.integer(fe)), origin = "1970-01-01")
W$span <- as.integer(fe - fs)
W$canon <- .ps_canon(W$firm_raw, alias)
excl_sec <- "Sub-national|Subpopulation|Electorate|seat|Hypothetical|Exit|By gender|By age|By generation|By language|By country"
why <- function(r) {
  if (r$table_type != "primary") return(paste0("table type '", r$table_type, "'"))
  if (r$row_type != "poll") return(paste0("row type '", r$row_type, "'"))
  if (grepl(excl_sec, r$section, ignore.case = TRUE)) return("excluded section")
  if (is.finite(r$span) && r$span > 45) return("aggregate over 45 days")
  if (!is.finite(suppressWarnings(as.numeric(r$alp_fp))) || !is.finite(suppressWarnings(as.numeric(r$lnp_fp)))) return("ALP or LNP not parsed")
  "kept, but not matched (date or firm label)"
}
out <- list()
for (rg in c("fed", "nsw", "qld", "sa", "vic", "wa")) {
  L <- suppressMessages(load_polls(rg)); P <- attr(L, "provenance")
  stopifnot(nrow(P) == nrow(L), identical(P$date, L$date))
  w <- W[W$region == rg]
  for (e in targets[startsWith(targets, rg)]) {
    yr <- as.integer(sub("^[a-z]+", "", e)); cy <- cyc[cyc$region == rg & cyc$year == yr]; if (!nrow(cy)) next
    ed <- as.Date(unname(eds[e])); end <- if (is.finite(ed) && ed <= Sys.Date()) ed else Sys.Date()
    inc <- L$date > cy$start[1] & L$date < end
    covered <- sum(P$source[inc] %in% c("ours", "ours_only", "ours_only_oth_blank", "ae_dispute", "ae_suspect")) >= 5
    if (!covered) next
    idx <- which(inc & P$source == "ae_only")
    for (i in idx) {
      cn <- .ps_canon(L$firm[i], alias)
      cand <- which(w$canon == cn & is.finite(w$mid) & abs(as.integer(w$mid - L$date[i])) <= 4)
      reason <- if (!length(cand)) "not in any parsed table" else why(w[cand[which.min(abs(as.integer(w$mid[cand] - L$date[i])))]])
      out[[length(out) + 1L]] <- data.table(election = e, date = L$date[i], firm = L$firm[i], ALP = L$ALP[i], LNP = L$LNP[i],
                                            final30 = L$date[i] >= end - 30, reason = reason)
    }
  }
}
M <- rbindlist(out)
cat(sprintf("AM1 %d AE-only polls in covered elections (%d in the final 30 days)\n", nrow(M), sum(M$final30)))
cat("AM2 why each is missing from our layer (all | final 30 days):\n")
print(M[, .(all = .N, final30 = sum(final30)), by = reason][order(-all)])
cat("AM3 by election (all | final 30 days not in any parsed table):\n")
print(M[, .(missing = .N, not_parsed_anywhere = sum(reason == "not in any parsed table"), on_page_dropped = sum(reason != "not in any parsed table"),
            f30 = sum(final30), f30_not_anywhere = sum(final30 & reason == "not in any parsed table")), by = election][order(-f30, -missing)], nrows = 30)
cat("AM4 firms behind 'not in any parsed table' (top 12):\n"); print(head(M[reason == "not in any parsed table", .N, by = firm][order(-N)], 12))
un <- TO[TO$outcome != "parsed"]
cat(sprintf("AM5 tables the scraper could not parse, by outcome: %s\n", paste(un[, .N, by = outcome][, sprintf("%s %d", outcome, N)], collapse = ", ")))
fwrite(M, out_path("ae-missing-split.csv")); cat(sprintf("AM6 wrote %s\n", out_path("ae-missing-split.csv")))
