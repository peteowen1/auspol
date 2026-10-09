#!/usr/bin/env Rscript
# Join the Wikipedia poll rows (scripts/fetch_statewide_poll_samples.R) to the anchor
# poll files the trend model reads, so every anchor poll carries a sample size and a
# sponsor wherever Wikipedia shows one (step 1 of
# docs/plans/statewide-poll-weighting-scope-2026-10-09.md).
#
# MATCH RULE (all four must hold):
#   1. same region;
#   2. the anchor firm and the Wikipedia firm share a canonical name in
#      external/reference/polls/statewide-samples/firm_alias.csv (written below, so
#      the table you read is the table that ran);
#   3. the Wikipedia fieldwork END or MID date is within 4 days of the anchor MidDate;
#   4. ALP and Coalition primary both agree within 0.5 points (Coalition may be the
#      Wikipedia L/NP column, its Liberal column, or Liberal + National).
# The best candidate (smallest primary-vote gap, then smallest date gap, then one
# that has a sample size) is kept. NO ANCHOR ROW IS EVER DROPPED: unmatched rows stay
# in the output with NA match columns and a reason.
#
# Writes output/statewide-poll-samples.csv and docs/reviews/statewide-poll-samples-2026-10-09.md.

suppressPackageStartupMessages(library(data.table))

base_dir <- "external/reference/polls/statewide-samples"
anchor_dir <- "external/aus-polling-analyser/analysis/Data"
out_csv <- "output/statewide-poll-samples.csv"
out_md <- "docs/reviews/statewide-poll-samples-2026-10-09.md"
regions <- c("fed", "vic", "nsw", "qld", "wa", "sa")
DATE_TOL <- 4      # days
FP_TOL   <- 0.5    # percentage points
NEAR_DAYS <- 45    # "Wikipedia has something near this date" for the unmatched-reason split

# ---- explicit firm alias table ----------------------------------------------------
# Applied to the lower-cased firm name with brackets removed and trailing digits dropped
# ("Newspoll2" -> "newspoll"). A name that hits several patterns gets ALL of those
# canonical names (YouGov-Galaxy is both "yougov" and "galaxy"); a name that hits none is
# its own canonical name (letters and digits only).
alias <- data.table(
  pattern = c("newspoll", "yougov", "morgan", "essential", "resolve", "red ?bridge|accent", "freshwater",
              "demos|premier national", "galaxy", "wolf", "nielsen", "reach ?tel", "ipsos", "lonergan",
              "ucomms", "taverner", "spectre", "fox ?& ?hedgehog", "^anu$", "dynata", "utting", "westpoll|patterson",
              "painted dog", "^advertiser", "jws", "saulwick", "synesis", "mccrindle", "morning consult", "^amr$"),
  canonical = c("newspoll", "yougov", "roymorgan", "essential", "resolve", "redbridge", "freshwater",
                "demosau", "galaxy", "wolfsmith", "nielsen", "reachtel", "ipsos", "lonergan",
                "ucomms", "taverner", "spectre", "foxhedgehog", "anu", "dynata", "utting", "westpoll",
                "painteddog", "advertiser", "jws", "saulwick", "synesis", "mccrindle", "morningconsult", "amr"),
  note = c("Newspoll, Newspoll2, Newspoll3 (era suffixes in the anchor), Newspoll-YouGov",
           "YouGov, YouGov2 (anchor), Newspoll-YouGov, YouGov-Galaxy", "Roy Morgan, F2F Morgan, SMS Morgan, Morgan Phone, Morgan multi-mode, Morgan (face/phone/multi)",
           "Essential", "ResolvePM, ResolvePM2 (anchor); Resolve, Resolve Strategic", "Redbridge, RedBridge/Accent, Accent/RedBridge, RedBridge Group",
           "Freshwater, Freshwater Strategy", "DemosAU, Demos AU, DemosAU/Premier National", "Galaxy, YouGov-Galaxy, Galaxy (Exit Poll)",
           "Wolf&Smith, Wolf + Smith, Wolf & Smith", "Nielsen", "ReachTEL, ReachTel", "Ipsos", "Lonergan, Lonergan Research",
           "uComms", "Taverner", "Spectre, Spectre Strategy", "Fox & Hedgehog", "ANU", "Dynata", "Utting, Utting Research", "Westpoll (WA)",
           "Painted Dog", "Advertiser (SA)", "JWS Research", "Saulwick", "Agenda C Synesis", "McCrindle", "Morning Consult", "AMR"))
fwrite(alias, file.path(base_dir, "firm_alias.csv"))
canon_of <- function(name) {
  vapply(name, function(nm) {
    if (is.na(nm) || !nzchar(trimws(nm))) return(NA_character_)
    z <- tolower(gsub("\\s*\\([^)]*\\)", "", nm))
    z <- trimws(gsub("[0-9]+$", "", trimws(z)))
    hits <- alias$canonical[vapply(alias$pattern, function(p) grepl(p, z), logical(1))]
    hits <- if (length(hits)) hits else gsub("[^a-z0-9]", "", z)
    paste(unique(hits), collapse = "|")
  }, character(1), USE.NAMES = FALSE)
}
expand_canon <- function(dt, id_col, name_cols) {   # long table: one row per (id, canonical)
  long <- rbindlist(lapply(name_cols, function(cn) data.table(id = dt[[id_col]], canon = canon_of(dt[[cn]]))))
  long <- long[!is.na(canon)]
  long <- long[, .(canon = unlist(strsplit(canon, "|", fixed = TRUE))), by = id]
  unique(long)
}

# ---- read anchors (all rows, all regions) ----------------------------------------------
elec <- fread(file.path(base_dir, "election_dates.csv"))
elec[, election_date := as.Date(election_date)]
anch <- rbindlist(lapply(regions, function(rg) {
  a <- fread(file.path(anchor_dir, sprintf("poll-data-%s.csv", rg)), na.strings = c("#N/A", "", "NA"), encoding = "UTF-8")
  a <- a[, !duplicated(names(a)) & nzchar(names(a)), with = FALSE]
  setnames(a, 1, "MidDate")
  coal <- intersect(c("LNP FP", "LIB FP"), names(a))[1]
  data.table(region = rg, anchor_row = seq_len(nrow(a)), MidDate = as.Date(a$MidDate), Firm = a$Firm,
             Brand = a$Brand, anchor_tpp = suppressWarnings(as.numeric(a[["@TPP"]])),
             anchor_alp = suppressWarnings(as.numeric(a[["ALP FP"]])),
             anchor_lnp = suppressWarnings(as.numeric(a[[coal]])), anchor_lnp_col = coal)
}))
stopifnot(!anyNA(anch$MidDate))
n_anchor_total <- nrow(anch)
message(sprintf("Anchor rows read: %d (%s)", n_anchor_total,
                paste(sprintf("%s %d", regions, as.integer(table(factor(anch$region, regions)))), collapse = ", ")))
anch[, anchor_id := paste(region, anchor_row, sep = "#")]
anch[, anchor_firm_canon := vapply(strsplit(canon_of(Firm), "|", fixed = TRUE), `[`, "", 1)]
# cycle = the first election on or after the poll date (NA if the poll is after the last one listed)
cyc_of <- function(rg, mid) {   # plain function: no column names in scope, so no data.table name capture
  e <- elec[elec$region == rg, ]
  e <- e[order(e$election_date), ]
  idx <- findInterval(as.numeric(mid) - 0.5, as.numeric(e$election_date)) + 1L
  ifelse(idx <= nrow(e), e$election[pmin(idx, nrow(e))], NA_character_)
}
anch[, cycle := NA_character_]
for (rg_i in regions) anch[anch$region == rg_i, cycle := cyc_of(rg_i, MidDate)]
stopifnot(all(substr(anch$cycle[!is.na(anch$cycle)], 1, nchar(anch$region[!is.na(anch$cycle)])) == anch$region[!is.na(anch$cycle)]))

# ---- wiki side -------------------------------------------------------------------------
wk <- fread(file.path(base_dir, "statewide_polls_wiki.csv"), na.strings = c("", "NA"))
wk[, `:=`(fieldwork_start = as.Date(fieldwork_start), fieldwork_end = as.Date(fieldwork_end))]
W <- wk[row_type == "poll" & headline == TRUE & !is.na(fieldwork_end)]
W[, wiki_id := paste(page_key, table_idx, row_in_table, sep = "/")]
W[, w_mid := fieldwork_start + as.integer(floor(as.numeric(fieldwork_end - fieldwork_start) / 2))]
W[is.na(w_mid), w_mid := fieldwork_end]
W[, w_lnp3 := fifelse(!is.na(lib_fp) & !is.na(nat_fp), lib_fp + nat_fp, NA_real_)]
message(sprintf("Wikipedia headline poll rows: %d; with sample_n %d; with a client %d",
                nrow(W), sum(!is.na(W$sample_n)), sum(!is.na(W$client))))

# ---- the matcher (a function, so the self-test can feed it broken input) ----------------
match_polls <- function(A, W, date_tol = DATE_TOL, fp_tol = FP_TOL) {
  Al <- expand_canon(A, "anchor_id", c("Firm", "Brand"))
  Wl <- expand_canon(W, "wiki_id", "firm")
  setnames(Al, c("id", "canon"), c("anchor_id", "canon")); setnames(Wl, c("id", "canon"), c("wiki_id", "canon"))
  a_small <- A[, .(anchor_id, region, MidDate, anchor_alp, anchor_lnp)]
  w_small <- W[, .(wiki_id, w_region = region, fieldwork_end, w_mid, w_alp = alp_fp, w_l1 = lnp_fp, w_l2 = lib_fp, w_l3 = w_lnp3, has_n = !is.na(sample_n))]
  pairs <- merge(Al, Wl, by = "canon", allow.cartesian = TRUE)
  pairs <- merge(pairs, a_small, by = "anchor_id")
  pairs <- merge(pairs, w_small, by = "wiki_id")
  pairs <- pairs[region == w_region]
  pairs[, date_gap := pmin(abs(as.numeric(fieldwork_end - MidDate)), abs(as.numeric(w_mid - MidDate)))]
  pairs[, alp_gap := fifelse(is.na(anchor_alp) | is.na(w_alp), Inf, abs(anchor_alp - w_alp))]
  pairs[, lnp_gap := suppressWarnings(pmin(abs(anchor_lnp - w_l1), abs(anchor_lnp - w_l2), abs(anchor_lnp - w_l3), na.rm = TRUE))]
  pairs[is.infinite(lnp_gap) | is.na(anchor_lnp), lnp_gap := Inf]
  pairs[, fp_gap := pmax(alp_gap, lnp_gap)]
  list(near_date = unique(pairs[date_gap <= date_tol, .(anchor_id)]),
       near_firm_date_fp_ok = pairs[date_gap <= date_tol & fp_gap <= fp_tol],
       near_firm_date = pairs[date_gap <= date_tol])
}
best_match <- function(m) {
  x <- m$near_firm_date_fp_ok
  if (!nrow(x)) return(x[0])
  setorder(x, anchor_id, fp_gap, date_gap, -has_n, wiki_id)
  x[, .SD[1], by = anchor_id][, .(anchor_id, wiki_id, date_gap, fp_gap)]
}

# ---- self-test: the matcher must FAIL on deliberately broken input ------------------------
local({
  good <- nrow(best_match(match_polls(anch, W)))
  W_late <- copy(W); W_late[, `:=`(fieldwork_end = fieldwork_end + 400L, w_mid = w_mid + 400L)]
  W_alp <- copy(W); W_alp[, alp_fp := alp_fp + 5]
  W_reg <- copy(W); W_reg[, region := "xx"]
  bad <- c(dates_shifted = nrow(best_match(match_polls(anch, W_late))),
           alp_shifted = nrow(best_match(match_polls(anch, W_alp))),
           region_scrambled = nrow(best_match(match_polls(anch, W_reg))))
  message(sprintf("SELFTEST matches on real input %d; on broken input: %s", good,
                  paste(names(bad), bad, sep = "=", collapse = ", ")))
  stopifnot(good > 100, all(bad <= 0.05 * good))
})

# ---- run the real match --------------------------------------------------------------------
m <- match_polls(anch, W)
bm <- best_match(m)
stopifnot(!anyDuplicated(bm$anchor_id))
wcols <- W[, .(wiki_id, wiki_page_key = page_key, wiki_table_idx = table_idx, wiki_section = section,
               wiki_date_raw = date_raw, wiki_fieldwork_start = fieldwork_start, wiki_fieldwork_end = fieldwork_end,
               wiki_firm_raw = firm_raw, wiki_alp_fp = alp_fp, wiki_lnp_fp = lnp_fp, wiki_lib_fp = lib_fp, wiki_nat_fp = nat_fp,
               sample_raw, sample_n, client, wiki_source_url = source_url)]
out <- merge(anch, merge(bm, wcols, by = "wiki_id"), by = "anchor_id", all.x = TRUE)
out[, match_quality := fcase(is.na(wiki_id), NA_character_,
                             date_gap <= 1 & fp_gap < 0.05, "exact",
                             default = "close")]
# how many anchor rows share one Wikipedia row (many-to-one is possible: two anchor rows can describe one poll)
out[, wiki_row_shared_by := if (is.na(wiki_id[1])) NA_integer_ else .N, by = wiki_id]
out[is.na(wiki_id), wiki_row_shared_by := NA_integer_]

# reason an anchor row is unmatched
wk_dates <- W[, .(region, fieldwork_end)]
wiki_firms_by_region <- expand_canon(W, "wiki_id", "firm")[W[, .(wiki_id, region)], on = .(id = wiki_id), nomatch = NULL]
un <- out[is.na(wiki_id)]
near45 <- vapply(seq_len(nrow(un)), function(i) {
  r <- un$region[i]; d <- un$MidDate[i]
  any(abs(as.numeric(W$fieldwork_end[W$region == r] - d)) <= NEAR_DAYS)
}, logical(1))
un[, near_wiki := near45]
Al_un <- expand_canon(un, "anchor_id", c("Firm", "Brand"))
firm_on_wiki <- Al_un[, .(anchor_id = id, canon)][un[, .(anchor_id, region)], on = "anchor_id"]
firm_on_wiki[, on_wiki := paste(region, canon) %in% paste(wiki_firms_by_region$region, wiki_firms_by_region$canon)]
fow <- firm_on_wiki[, .(firm_on_wiki = any(on_wiki)), by = anchor_id]
un <- merge(un, fow, by = "anchor_id", all.x = TRUE)
nfd <- unique(m$near_firm_date[, .(anchor_id)])
un[, firm_date_ok := anchor_id %in% nfd$anchor_id]
un[, unmatched_reason := fcase(
  is.na(anchor_alp) | is.na(anchor_lnp), "anchor ALP or Coalition primary missing",
  !near_wiki, "no Wikipedia poll table covers this date",
  !firm_on_wiki | is.na(firm_on_wiki), "firm never appears on the Wikipedia pages for this region",
  firm_date_ok, "same firm and date on Wikipedia, but ALP/Coalition primary differ by more than 0.5",
  default = "firm is on Wikipedia but has no poll within 4 days of this date")]
out <- merge(out, un[, .(anchor_id, unmatched_reason)], by = "anchor_id", all.x = TRUE)
out[, matched := !is.na(wiki_id)]
out[, matched_with_n := matched & !is.na(sample_n)]
setorder(out, region, anchor_row)

# ---- NO ANCHOR ROW DROPPED ------------------------------------------------------------------
stopifnot(nrow(out) == n_anchor_total,
          !anyDuplicated(out$anchor_id),
          setequal(out$anchor_id, anch$anchor_id),
          identical(as.integer(table(factor(out$region, regions))), as.integer(table(factor(anch$region, regions)))))
message(sprintf("CHECK all %d anchor rows present exactly once in the output", nrow(out)))

keep <- c("region", "anchor_row", "MidDate", "Firm", "Brand", "anchor_tpp", "anchor_alp", "anchor_lnp", "anchor_lnp_col", "cycle",
          "matched", "matched_with_n", "match_quality", "date_gap", "fp_gap", "sample_n", "sample_raw", "client", "unmatched_reason",
          "wiki_row_shared_by", "wiki_id", "wiki_page_key", "wiki_table_idx", "wiki_section", "wiki_date_raw", "wiki_fieldwork_start",
          "wiki_fieldwork_end", "wiki_firm_raw", "wiki_alp_fp", "wiki_lnp_fp", "wiki_lib_fp", "wiki_nat_fp", "wiki_source_url")
dir.create("output", showWarnings = FALSE)
fwrite(out[, ..keep], out_csv)
message("Wrote ", out_csv)

# ---- report ---------------------------------------------------------------------------------
md_table <- function(d) {
  d <- as.data.frame(d)
  d[] <- lapply(d, function(x) ifelse(is.na(x), "", as.character(x)))
  c(paste0("| ", paste(names(d), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
    apply(d, 1, function(r) paste0("| ", paste(gsub("\\|", "/", r), collapse = " | "), " |")))
}
pct <- function(a, b) ifelse(b > 0, sprintf("%.0f%%", 100 * a / b), "")
cov_tab <- function(d, by) d[, .(anchor_polls = .N, matched = sum(matched), matched_with_sample_n = sum(matched_with_n),
                                 pct_matched = pct(sum(matched), .N), pct_with_sample_n = pct(sum(matched_with_n), .N)), by = by]
rep <- character(0)
add <- function(...) rep <<- c(rep, ...)
d07 <- out[MidDate >= as.Date("2007-01-01")]
d10 <- out[MidDate >= as.Date("2010-01-01")]

add("# Statewide poll sample sizes from Wikipedia: coverage of the anchor poll files", "",
    "Generated 2026-10-09 by `scripts/join_statewide_poll_samples.R` from `external/reference/polls/statewide-samples/statewide_polls_wiki.csv`",
    "(built by `scripts/fetch_statewide_poll_samples.R`). Step 1 of `docs/plans/statewide-poll-weighting-scope-2026-10-09.md`.", "",
    sprintf("Match rule: same region; firm agrees through `firm_alias.csv`; Wikipedia fieldwork end or middle within %d days of the anchor `MidDate`; ALP and Coalition primary both within %.1f points. Best candidate kept. All %d anchor rows are in `output/statewide-poll-samples.csv` (asserted).",
        DATE_TOL, FP_TOL, n_anchor_total), "",
    sprintf("Wikipedia side: %d voting-intention poll rows in headline tables (not sub-national, demographic, seat or upper-house tables); %d have a sample size, %d name a client.",
            nrow(W), sum(!is.na(W$sample_n)), sum(!is.na(W$client))), "",
    "**Read this first.** Wikipedia only has a dedicated statewide opinion-polling page for the elections in the first table below; for every earlier state election the main article carries no poll table, or a table with no sample column. So the gap is mostly Wikipedia not having the data, not the join failing (section 4 splits the two).", "")
pg <- fread(file.path(base_dir, "pages_manifest.csv"))
pgs <- merge(pg, W[, .(headline_rows = .N, rows_with_n = sum(!is.na(sample_n))), by = .(page_key)], by = "page_key", all.x = TRUE)
pgs[is.na(headline_rows), `:=`(headline_rows = 0L, rows_with_n = 0L)]
pgs <- pgs[status == "on_disk" & headline_rows > 0]
add("Pages that supplied poll rows (count of rows; `rows_with_n` = rows that show a sample size):", "",
    md_table(pgs[order(region, election), .(page = page_key, headline_rows, rows_with_n)]), "")
nf <- pg[status == "not_found" & kind == "opinion"]
add(sprintf("Dedicated opinion-polling pages that do not exist on Wikipedia (HTTP 404, checked 2026-10-09; the main election article was parsed instead): %s.",
            paste(nf$election, collapse = ", ")), "")
all_el <- unique(pg$election)
no_rows <- setdiff(all_el, unique(W$election))
no_n <- setdiff(unique(W$election), unique(W[!is.na(sample_n)]$election))
add(sprintf("Elections with NO headline voting-intention poll row on any page we could find (%d): %s.", length(no_rows), paste(no_rows, collapse = ", ")),
    sprintf("Elections with poll rows but no sample size on any of them (%d): %s.", length(no_n), paste(no_n, collapse = ", ")),
    "(fed2007: the 2010 federal page starts after the 2007 election, and `Opinion polling for the 2007 Australian federal election` is a 404. A Wikipedia poll row belongs to the election of the page it sits on, not the election cycle of its date.)", "")

add("## 1. Coverage", "",
    "Counts of anchor polls (rows in `poll-data-<region>.csv`) from 2007 onward, by election cycle (a cycle is the polls between the previous election and the one named). `matched` = a Wikipedia row found; `matched_with_sample_n` = that row shows a sample size. Higher is better; blanks mean no anchor polls.", "")
cyc <- cov_tab(d07[!is.na(cycle)], c("region", "cycle"))[order(region, cycle)]
add(md_table(cyc), "")
add("Pooled by region, polls from 2010-01-01 onward:", "")
reg10 <- cov_tab(d10, "region")[match(regions, region)]
pool10 <- d10[, .(region = "ALL", anchor_polls = .N, matched = sum(matched), matched_with_sample_n = sum(matched_with_n),
                  pct_matched = pct(sum(matched), .N), pct_with_sample_n = pct(sum(matched_with_n), .N))]
add(md_table(rbind(reg10, pool10)), "")
add("Same, restricted to cycles where Wikipedia has a headline table at all (cycles with at least one Wikipedia poll row in the region):", "")
has_tab <- unique(W[, .(region, cycle_el = election)])
d10b <- merge(d10, has_tab, by.x = c("region", "cycle"), by.y = c("region", "cycle_el"))
add(md_table(rbind(cov_tab(d10b, "region")[match(regions, region)][!is.na(region)],
                   d10b[, .(region = "ALL", anchor_polls = .N, matched = sum(matched), matched_with_sample_n = sum(matched_with_n),
                            pct_matched = pct(sum(matched), .N), pct_with_sample_n = pct(sum(matched_with_n), .N))])), "")
add("Match quality of the matched rows (`exact` = date within a day and primaries within 0.05; `close` = within the 4-day / 0.5-point tolerance):", "",
    md_table(out[matched == TRUE, .(rows = .N, median_date_gap_days = median(date_gap), median_primary_gap_pts = round(median(fp_gap), 2)), by = match_quality]), "")
shared <- out[matched == TRUE, .N, by = wiki_row_shared_by]
add(sprintf("Anchor rows that share one Wikipedia row with another anchor row: %d of %d matched rows (a Wikipedia poll can be echoed by two anchor firm labels).",
            sum(out$wiki_row_shared_by > 1, na.rm = TRUE), sum(out$matched)), "")

add("## 2. Spread of sample size", "",
    "Sample size (people interviewed) for anchor polls that matched a Wikipedia row showing one, polls from 2010 onward. `p10` and `p90` are the 10th and 90th percentiles, `p25` and `p75` bound the middle half (interquartile range). Larger n means a more precise poll.", "")
sp <- function(d, by) d[!is.na(sample_n), .(polls = .N, median = round(median(sample_n)), p25 = round(quantile(sample_n, .25)), p75 = round(quantile(sample_n, .75)),
                                           p10 = round(quantile(sample_n, .10)), p90 = round(quantile(sample_n, .90)), min = min(sample_n), max = max(sample_n)), by = by]
sp_reg <- sp(d10, "region")[match(regions, region)][!is.na(region)]
sp_all <- sp(d10[, .(region = "ALL", sample_n)], "region")
add(md_table(rbind(sp_reg, sp_all)), "")
add("By firm (canonical firm name from the alias table), the 12 firms with the most sample sizes, polls from 2010 onward:", "")
d10[, firm_group := anchor_firm_canon]
spf <- sp(d10, "firm_group")[order(-polls)][1:12][!is.na(firm_group)]
add(md_table(spf), "")
add("Share of those polls under 500, 500 to 999, 1000 to 1499, 1500 and over (pooled, 2010 onward):", "",
    md_table(d10[!is.na(sample_n), .(polls = .N, under_500 = sum(sample_n < 500), n500_999 = sum(sample_n >= 500 & sample_n < 1000),
                                     n1000_1499 = sum(sample_n >= 1000 & sample_n < 1500), n1500_plus = sum(sample_n >= 1500))]), "")

add("## 3. Sponsor / client coverage", "",
    "Of the matched anchor polls from 2010 onward, how many carry a client (the organisation that paid for the poll): from the Wikipedia `Client` column, or from a footnote saying 'commissioned by'. Higher is better.", "")
cl <- d10[matched == TRUE, .(matched_polls = .N, with_client = sum(!is.na(client)), pct = pct(sum(!is.na(client)), .N)), by = region][match(regions, region)][!is.na(region)]
cla <- d10[matched == TRUE, .(region = "ALL", matched_polls = .N, with_client = sum(!is.na(client)), pct = pct(sum(!is.na(client)), .N))]
add(md_table(rbind(cl, cla)), "")
add("Of all anchor polls from 2010 onward (matched or not):", "",
    md_table(d10[, .(anchor_polls = .N, with_client = sum(!is.na(client)), pct = pct(sum(!is.na(client)), .N))]), "")
add("Most common clients among matched polls:", "",
    md_table(d10[matched == TRUE & !is.na(client), .(polls = .N), by = .(client)][order(-polls)][1:15]), "")

add("## 4. The 20 largest unmatched groups", "",
    "Unmatched anchor polls from 2010 onward, grouped by region, firm and election cycle; `reason` is the most common cause in the group. Reasons, in the order tested: no Wikipedia poll table covers the date (within 45 days); the firm never appears on Wikipedia for that region; the firm is there but has no poll within 4 days; same firm and date but the primaries differ by more than 0.5 points.", "")
ug <- d10[matched == FALSE, .(unmatched = .N, reason = names(sort(table(unmatched_reason), decreasing = TRUE))[1],
                              share_with_that_reason = pct(max(table(unmatched_reason)), .N)), by = .(region, firm = Firm, cycle)][order(-unmatched)][1:20]
add(md_table(ug), "")
add("Why every unmatched anchor poll from 2010 onward is unmatched:", "",
    md_table(d10[matched == FALSE, .(polls = .N), by = .(reason = unmatched_reason)][order(-polls)]), "",
    "The first and third reasons mean no match is possible (no Wikipedia table for that date, or the anchor row has no primary vote to compare). The second is most likely Wikipedia not listing that poll, but can also be a date convention difference between the two sources. The fourth and fifth are the only ones that could be join or alias gaps; spot-check them before trusting the rule is too strict.", "")

add("## 5. Spot-check: 10 random matched rows, anchor beside Wikipedia", "",
    "Five random matched national rows and five random matched state rows (seed 20261009). `anchor` columns come from the poll file, `wiki` columns from the Wikipedia row it was matched to. Check that the firm, the dates and the two primaries agree.", "")
set.seed(20261009)
mt <- out[matched == TRUE]
pick5 <- function(d, k) d[sample(nrow(d), min(k, nrow(d)))]
sc <- rbind(pick5(mt[region == "fed"], 5), pick5(mt[region != "fed"], 5))   # 5 national + 5 state, so the state join is visible
add(md_table(sc[, .(region, anchor_date = MidDate, anchor_firm = Firm, anchor_ALP = anchor_alp, anchor_Coalition = anchor_lnp,
                    wiki_page = wiki_page_key, wiki_dates = wiki_date_raw, wiki_firm = wiki_firm_raw,
                    wiki_ALP = wiki_alp_fp, wiki_Coalition = fifelse(!is.na(wiki_lnp_fp), wiki_lnp_fp, wiki_lib_fp),
                    sample = sample_raw, n = sample_n, client = client, quality = match_quality)]), "")
add("---", "Row-level detail: `output/statewide-poll-samples.csv`; alias table: `external/reference/polls/statewide-samples/firm_alias.csv`; pages tried: `external/reference/polls/statewide-samples/pages_manifest.csv`.")
writeLines(rep, out_md)
message("Wrote ", out_md)

cat("\n", paste(rep, collapse = "\n"), "\n")
