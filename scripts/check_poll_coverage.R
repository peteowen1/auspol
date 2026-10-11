# Which polls does Wikipedia list that the AE Forecasts poll files (our only
# poll source, external/aus-polling-analyser) do not have? Pete, 2026-10-11:
# "can we check if theres any polling data we're missing anywhere?"
#
# Reads the scrape (external/reference/polls/statewide-samples/statewide_polls_wiki.csv,
# scripts/fetch_statewide_poll_samples.R) and the AE-to-Wikipedia join
# (output/statewide-poll-samples.csv, scripts/join_statewide_poll_samples.R,
# which matches each AE poll to at most one Wikipedia row: same firm through
# firm_alias.csv, within 4 days, primaries within 0.5). A Wikipedia headline
# primary-vote poll is "covered" when that row, or an identical duplicate of it
# (same page, firm, end date and ALP/Coalition primaries -- the scrape repeats a
# poll across tables), was matched. Everything else is a candidate gap, to be
# checked by hand: the join tolerances can miss a real match.
#
# Elections whose Wikipedia pages did not parse are listed, not scored.
# Writes output/poll-coverage-wiki-only.csv. Emits PC* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
base <- file.path("external", "reference", "polls", "statewide-samples")
W <- fread(file.path(base, "statewide_polls_wiki.csv"), showProgress = FALSE)
J <- fread(out_path("statewide-poll-samples.csv"), showProgress = FALSE)
W[, wiki_id := paste(page_key, table_idx, row_in_table, sep = "/")]
W <- W[row_type == "poll" & table_type == "primary" & headline %in% TRUE & !is.na(fieldwork_end)]
W[, end := as.Date(fieldwork_end)]
W[, lnp_any := fifelse(is.finite(lnp_fp), lnp_fp, fifelse(is.finite(lib_fp), lib_fp, NA_real_))]
W[, key := paste(page_key, tolower(firm), end, round(alp_fp, 1), round(lnp_any, 1))]
matched_ids <- unique(J$wiki_id[J$matched %in% TRUE & nzchar(J$wiki_id)])
covered_keys <- unique(W$key[W$wiki_id %in% matched_ids])
W[, covered := key %in% covered_keys]
U <- unique(W, by = "key")   # one row per distinct poll
ed <- election_dates()
U[, polling_day := as.Date(unname(ed[election]))]
U <- U[is.finite(polling_day) & end < polling_day]
U[, days_out := as.integer(polling_day - end)]
pairs <- vapply(all_election_pairs(), `[[`, "", "election")
S <- U[election %in% pairs, list(distinct_wiki = .N, covered = sum(covered), missing = sum(!covered),
                                 missing_final28 = sum(!covered & days_out <= 28)), by = election]
empty <- setdiff(pairs, S$election)
cat(sprintf("PC1  %d distinct Wikipedia headline polls over %d elections; %d covered by an AE poll, %d not\n",
            sum(S$distinct_wiki), nrow(S), sum(S$covered), sum(S$missing)))
cat(sprintf("PC2  Wikipedia scrape has no polls for: %s (pages not found or tables not parsed; see pages_manifest.csv)\n",
            paste(empty, collapse = ", ")))
print(S[order(-missing_final28, -missing)], nrows = 40)
G <- U[!covered & election %in% pairs][order(election, end)]
fwrite(G[, list(election, end, days_out, firm, client, alp_fp, lnp_fp = lnp_any, sample_n, page_key, source_url)],
       out_path("poll-coverage-wiki-only.csv"))
cat(sprintf("PC3  wrote %s (%d candidate gaps)\n", out_path("poll-coverage-wiki-only.csv"), nrow(G)))
cat("PC4  candidate gaps in the final 28 days:\n")
print(G[days_out <= 28, list(election, end, days_out, firm, alp_fp, lnp = lnp_any)], nrows = 80)
