# Poll coverage BOTH ways, per scored election: which polls does Wikipedia list that
# the AE Forecasts poll files (external/aus-polling-analyser) do not have, and which
# does AE have that Wikipedia lacks? Pete, 2026-10-11: polls should come from our own
# source, not from the model we benchmark against (docs/PETE-ASKED-FOR.md); this is
# step 1 of 2 (measure the Wikipedia source), see
# docs/reviews/own-poll-source-step1-2026-10-11.md.
#
# Inputs (both written by earlier scripts):
#   external/reference/polls/statewide-samples/statewide_polls_wiki.csv
#       scripts/fetch_statewide_poll_samples.R
#   output/statewide-poll-samples.csv
#       scripts/join_statewide_poll_samples.R -- matches each AE poll to at most one
#       Wikipedia row: same firm through firm_alias.csv, within 4 days, primaries
#       within 0.5.
#
# ELECTION IS ASSIGNED BY DATE, not by the page a row came from: a poll belongs to the
# scored election whose window (previous polling day, this polling day] contains it.
# The fed2010 page, for instance, carries one poll from 20-22 Nov 2007, which is a
# fed2007 poll. A Wikipedia headline primary-vote poll is "covered" when that row, or
# an identical duplicate of it (same firm, end date and ALP/Coalition primaries -- the
# scrape repeats a poll across tables and pages), was matched. Everything else is a
# candidate gap, to be checked by hand: the join tolerances can miss a real match.
#
# Writes (all under output/, which is gitignored):
#   poll-coverage-by-election.csv   one row per scored election, both directions
#   poll-coverage-wiki-only.csv     Wikipedia polls AE lacks (candidate gaps)
#   poll-coverage-ae-only.csv       AE polls Wikipedia lacks, with the join's reason
# Emits PC* codes. Run from the repo root; needs no package load.
suppressMessages(library(data.table))
source(file.path("R", "election_dates.R"))
base <- file.path("external", "reference", "polls", "statewide-samples")
W <- fread(file.path(base, "statewide_polls_wiki.csv"), showProgress = FALSE)
J <- fread(file.path("output", "statewide-poll-samples.csv"), showProgress = FALSE)

# The 22 scored elections (quick_units() in R/quick_arm.R) and the election before each
# (all_election_pairs() in R/reentry_prior.R). wa2021 is a pair but is NOT scored.
scored <- data.table(
  election = c(paste0("fed", c(2007, 2010, 2013, 2016, 2019, 2022, 2025)),
               paste0("wa", c(2001, 2005, 2008, 2013, 2017, 2025)),
               paste0("vic", c(2014, 2018, 2022)), paste0("nsw", c(2019, 2023)),
               paste0("qld", c(2020, 2024)), paste0("sa", c(2022, 2026))),
  prev = c("fed2004", "fed2007", "fed2010", "fed2013", "fed2016", "fed2019", "fed2022",
           "wa1996", "wa2001", "wa2005", "wa2008", "wa2013", "wa2021",
           "vic2010", "vic2014", "vic2018", "nsw2015", "nsw2019",
           "qld2017", "qld2020", "sa2018", "sa2022"))
ed <- election_dates()
scored[, `:=`(region = sub("[0-9]+$", "", election),
              polling_day = as.Date(unname(ed[election])), prev_day = as.Date(unname(ed[prev])))]
stopifnot(nrow(scored) == 22, !anyNA(scored$polling_day), !anyNA(scored$prev_day))
assign_election <- function(region, d) {
  out <- rep(NA_character_, length(d))
  for (i in seq_len(nrow(scored))) {
    hit <- region == scored$region[i] & !is.na(d) & d > scored$prev_day[i] & d <= scored$polling_day[i]
    out[hit] <- scored$election[i]
  }
  out
}

# ---- Wikipedia side ----------------------------------------------------------------
W[, wiki_id := paste(page_key, table_idx, row_in_table, sep = "/")]
W <- W[row_type == "poll" & table_type == "primary" & headline %in% TRUE & !is.na(fieldwork_end)]
W[, end := as.Date(fieldwork_end)]
W[, lnp_any := fifelse(is.finite(lnp_fp), lnp_fp, fifelse(is.finite(lib_fp), lib_fp + fifelse(is.finite(nat_fp), nat_fp, 0), NA_real_))]
W[, key := paste(region, tolower(firm), end, round(alp_fp, 1), round(lnp_any, 1))]
matched_ids <- unique(J$wiki_id[J$matched %in% TRUE & nzchar(J$wiki_id)])
covered_keys <- unique(W$key[W$wiki_id %in% matched_ids])
W[, covered := key %in% covered_keys]
U <- unique(W, by = "key")                      # one row per distinct poll
U[, election_w := assign_election(region, end)]
U <- U[!is.na(election_w)]
U[, days_out := as.integer(scored$polling_day[match(election_w, scored$election)] - end)]

# ---- AE side -----------------------------------------------------------------------
A <- copy(J)
A[, MidDate := as.Date(MidDate)]
A[, election_a := assign_election(region, MidDate)]
A <- A[!is.na(election_a)]
A[, days_out := as.integer(scored$polling_day[match(election_a, scored$election)] - MidDate)]
A[, has_primary := is.finite(anchor_alp) & is.finite(anchor_lnp)]
A[, matched := matched %in% TRUE]

summ <- function(sub_w, sub_a) {
  list(wiki_polls = nrow(sub_w), wiki_first = as.character(suppressWarnings(min(sub_w$end))),
       wiki_last = as.character(suppressWarnings(max(sub_w$end))),
       ae_polls = nrow(sub_a), ae_first = as.character(suppressWarnings(min(sub_a$MidDate))),
       ae_last = as.character(suppressWarnings(max(sub_a$MidDate))),
       ae_with_primary = sum(sub_a$has_primary), matched = sum(sub_a$matched),
       wiki_covered = sum(sub_w$covered), wiki_only = sum(!sub_w$covered),
       ae_only = sum(!sub_a$matched), ae_only_with_primary = sum(!sub_a$matched & sub_a$has_primary))
}
rows <- lapply(scored$election, function(e) {
  w <- U[election_w == e]; a <- A[election_a == e]
  all_ <- summ(w, a)
  f <- summ(w[days_out <= 30], a[days_out <= 30])
  c(list(election = e, polling_day = as.character(scored$polling_day[scored$election == e])), all_,
    setNames(f[c("wiki_polls", "ae_polls", "ae_with_primary", "matched", "wiki_only", "ae_only", "ae_only_with_primary")],
             paste0("f30_", c("wiki_polls", "ae_polls", "ae_with_primary", "matched", "wiki_only", "ae_only", "ae_only_with_primary"))))
})
R <- rbindlist(rows)
# anchors: Wikipedia + AE counts must add up to what the two tables hold for these windows
stopifnot(sum(R$ae_polls) == nrow(A), sum(R$wiki_polls) == nrow(U),
          all(R$matched + R$ae_only == R$ae_polls), all(R$wiki_covered + R$wiki_only == R$wiki_polls))

# ---- RELAXED MATCH: the same poll on a different base -------------------------------
# The join requires primaries within 0.5. Essential (and a few others) list "undecided" on
# Wikipedia and AE renormalises it away, so the same poll differs by 5 or 6 points and is
# counted as a gap in BOTH directions. For every poll still unmatched on both sides, look for
# the same firm (alias patterns below, a short copy of firm_alias.csv), same region, within
# 4 days, whose ALP and Coalition agree within 1.0 point AFTER rescaling the Wikipedia row
# over its decided share, 100 / (100 - UND). Each AE row is used once (nearest wiki row first).
fk <- function(x) {
  x <- tolower(x)
  pats <- c("newspoll", "yougov", "morgan", "essential", "resolve", "red ?bridge|accent", "freshwater",
            "demos|premier national", "galaxy", "wolf", "nielsen", "reach ?tel", "ipsos", "lonergan",
            "ucomms", "taverner", "spectre", "fox ?& ?hedgehog", "^anu$", "dynata", "utting", "westpoll|patterson",
            "painted dog", "^advertiser", "jws", "saulwick", "synesis", "mccrindle", "morning consult", "^amr$")
  out <- gsub("[^a-z0-9]", "", x)
  for (p in pats) out[grepl(p, x)] <- p
  out
}
und_num <- function(v) { v <- suppressWarnings(as.numeric(gsub("[^0-9.]", "", v))); v[!is.finite(v)] <- 0; v }
Uw <- U[covered == FALSE]
Uw[, `:=`(fk = fk(firm), f = 100 / (100 - (if ("pv_UND" %in% names(Uw)) und_num(pv_UND) else 0)))]
Ao <- A[matched == FALSE & has_primary]
Ao[, `:=`(fk = fk(Firm), ae_row = .I)]
cand <- merge(Uw[, .(wiki_key = key, region, fk, end, alp = alp_fp * f, lnp = lnp_any * f)],
              Ao[, .(ae_row, region, fk, MidDate, aalp = anchor_alp, alnp = anchor_lnp)],
              by = c("region", "fk"), allow.cartesian = TRUE)
cand <- cand[abs(as.integer(end - MidDate)) <= 4 & abs(alp - aalp) <= 1 & abs(lnp - alnp) <= 1]
cand[, d := abs(as.integer(end - MidDate)) + abs(alp - aalp) + abs(lnp - alnp)]
setorder(cand, d)
cand <- cand[!duplicated(ae_row)][!duplicated(wiki_key)]
U[, relaxed := key %in% cand$wiki_key]
A[, relaxed := FALSE]
Ao_rows <- A[matched == FALSE & has_primary, which = TRUE]
A[Ao_rows[cand$ae_row], relaxed := TRUE]
R[, `:=`(relaxed_pairs = vapply(election, function(e) sum(U$relaxed & U$election_w == e), 0L),
         f30_relaxed_pairs = vapply(election, function(e) sum(U$relaxed & U$election_w == e & U$days_out <= 30), 0L))]
stopifnot(sum(A$relaxed) == sum(U$relaxed))

# ---- POLL BLUDGER (nsw2019, vic2018 only): second own source where Wikipedia has little ---
# scripts/fetch_pollbludger_tracker_polls.R. Same rule as the join: same firm, within 4 days,
# ALP and Coalition within 0.5. Counted against ALL AE polls with primaries, not only the
# Wikipedia-unmatched ones, so "AE polls covered by Wikipedia or Poll Bludger" is one number.
A[, `:=`(pb_matched = FALSE, arow = .I)]
R[, `:=`(pb_polls = 0L, pb_matched_to_ae = 0L, ae_covered_wiki_or_pb = 0L, f30_pb_polls = 0L, f30_ae_covered_wiki_or_pb = 0L)]
pbf <- file.path(base, "pollbludger_polls.csv")
if (file.exists(pbf)) {
  PB <- fread(pbf, showProgress = FALSE)[row_type == "poll" & is.finite(alp_fp) & is.finite(lnp_fp)]
  PB[, date := as.Date(date)]
  PB[, election_p := assign_election(region, date)]
  PB <- PB[!is.na(election_p)]
  PB[, `:=`(fk = fk(POLLSTER), prow = .I,
            days_out = as.integer(scored$polling_day[match(election_p, scored$election)] - date))]
  pc <- merge(PB[, .(prow, region, fk, date, alp = alp_fp, lnp = lnp_fp)],
              A[has_primary == TRUE, .(arow, region, fk = fk(Firm), MidDate, aalp = anchor_alp, alnp = anchor_lnp)],
              by = c("region", "fk"), allow.cartesian = TRUE)
  pc <- pc[abs(as.integer(date - MidDate)) <= 4 & abs(alp - aalp) <= 0.5 & abs(lnp - alnp) <= 0.5]
  pc[, d := abs(as.integer(date - MidDate)) + abs(alp - aalp) + abs(lnp - alnp)]
  setorder(pc, d)
  pc <- pc[!duplicated(arow)][!duplicated(prow)]
  A[arow %in% pc$arow, pb_matched := TRUE]
  PB[, in_ae := prow %in% pc$prow]
  for (e in unique(PB$election_p)) {
    R[election == e, `:=`(pb_polls = sum(PB$election_p == e), pb_matched_to_ae = sum(PB$in_ae[PB$election_p == e]),
                          f30_pb_polls = sum(PB$election_p == e & PB$days_out <= 30))]
  }
  cat(sprintf("PB2  Poll Bludger polls: %s; matched to an AE poll: %s\n",
              paste(PB[, .N, by = election_p][, paste0(election_p, "=", N)], collapse = ", "),
              paste(PB[, sum(in_ae), by = election_p][, paste0(election_p, "=", V1)], collapse = ", ")))
}
R[, `:=`(ae_covered_wiki_or_pb = vapply(election, function(e) sum((A$matched | A$pb_matched) & A$election_a == e), 0L),
         f30_ae_covered_wiki_or_pb = vapply(election, function(e) sum((A$matched | A$pb_matched) & A$election_a == e & A$days_out <= 30), 0L))]
cat(sprintf("PC0  relaxed match (same firm, within 4 days, primaries within 1.0 after rescaling for undecided): %d of the %d Wikipedia-only polls and %d of the %d AE-only polls with primaries are the SAME poll on a different base\n",
            sum(U$relaxed), sum(!U$covered), sum(A$relaxed), sum(!A$matched & A$has_primary)))
fwrite(R, file.path("output", "poll-coverage-by-election.csv"))

cat(sprintf("PC1  Wikipedia: %d distinct headline polls over the 22 scored elections; %d covered by an AE poll, %d not\n",
            sum(R$wiki_polls), sum(R$wiki_covered), sum(R$wiki_only)))
cat(sprintf("PC2  AE: %d polls over the same windows (%d with ALP and Coalition primaries); %d matched to Wikipedia, %d not (%d of those have primaries)\n",
            sum(R$ae_polls), sum(R$ae_with_primary), sum(R$matched), sum(R$ae_only), sum(R$ae_only_with_primary)))
cat(sprintf("PC3  final 30 days: Wikipedia %d polls (%d not in AE); AE %d polls (%d with primaries; %d not on Wikipedia, %d of those with primaries)\n",
            sum(R$f30_wiki_polls), sum(R$f30_wiki_only), sum(R$f30_ae_polls), sum(R$f30_ae_with_primary),
            sum(R$f30_ae_only), sum(R$f30_ae_only_with_primary)))
none <- R$election[R$wiki_polls == 0]
cat(sprintf("PC4  no Wikipedia headline polls at all for: %s\n", paste(none, collapse = ", ")))
print(R[, .(election, wiki_polls, wiki_last, ae_polls, ae_last, matched, wiki_only, ae_only,
            f30_wiki_polls, f30_ae_polls, f30_matched, f30_wiki_only, f30_ae_only)], nrows = 40)

G <- U[covered == FALSE][order(election_w, end)]
fwrite(G[, list(election = election_w, end, days_out, firm, client, alp_fp, lnp_fp = lnp_any, sample_n, relaxed, page_key, source_url)],
       file.path("output", "poll-coverage-wiki-only.csv"))
cat(sprintf("PC5  wrote output/poll-coverage-wiki-only.csv (%d candidate gaps); final 30 days:\n", nrow(G)))
print(G[days_out <= 30, list(election = election_w, end, days_out, firm, alp_fp, lnp = lnp_any)], nrows = 80)

O <- A[matched == FALSE][order(election_a, MidDate)]
fwrite(O[, list(election = election_a, MidDate, days_out, Firm, Brand, anchor_alp, anchor_lnp, anchor_tpp, has_primary, relaxed, pb_matched, unmatched_reason)],
       file.path("output", "poll-coverage-ae-only.csv"))
cat(sprintf("PC6  wrote output/poll-coverage-ae-only.csv (%d AE polls Wikipedia lacks); why:\n", nrow(O)))
print(O[, .N, by = unmatched_reason][order(-N)])
cat("PC7  the same, final 30 days only:\n")
print(O[days_out <= 30, .N, by = unmatched_reason][order(-N)])
cat("PC8  AE polls in the final 30 days that Wikipedia lacks:\n")
print(O[days_out <= 30, list(election = election_a, MidDate, days_out, Firm, anchor_alp, anchor_lnp, anchor_tpp, relaxed, pb_matched, unmatched_reason)], nrows = 200)
