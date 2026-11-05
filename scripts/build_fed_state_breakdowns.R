# Federal polls' state breakdowns for the recent-poll blend (AUSPOL_LEVEL_FED_R, shipped 0.15 2026-10-12;
# docs/plans/prereg-federal-breakdowns-in-blend-2026-10-12.md). Parses the archived Wikipedia federal
# opinion-polling pages (scripts/fetch_statewide_poll_samples.R) with fed_state_breakdowns_parse() and writes
# output/fed-state-breakdowns.csv, which the blend reads and the release carries. Rebuild stage 5b.
#
# Since 2026-11-05 it also writes output/fed-state-breakdowns-full.csv, the four-source union the trend arm
# AUSPOL_TREND_FED_SRC=full reads (docs/plans/prereg-fed-breakdowns-in-trend-2026-10-26.md step 7): Wikipedia,
# BludgerTrack's federal tables (state scopes), state-federal-polls.csv (scope state, hand-verified) and Newspoll's
# quarterly state breakdowns. One row per poll (same state, same canonical firm, fieldwork end within 3 days).
# Values come from Wikipedia, then BludgerTrack, then state-federal, then Newspoll quarterly; a missing field is
# filled from the next source and every disagreement over 1 point is printed. EVERY source column is carried
# through, prefixed wiki_ / bt_ / sf_ / nq_ (a column empty on every row used is dropped: it carries nothing).
# n_nat is the same firm's NATIONAL sample for the same poll (end within 3 days), for the trend arm's
# sample-size imputation.
#
#   Rscript scripts/build_fed_state_breakdowns.R [--full-only]
# --full-only leaves output/fed-state-breakdowns.csv untouched (the blend's input) and writes only the union.
# Emits FK* codes (shipped file) and FU* codes (union).
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
full_only <- "--full-only" %in% commandArgs(TRUE)
src <- file.path("external", "reference", "polls", "statewide-samples", "statewide_polls_wiki.csv")
out <- fed_state_breakdowns_parse(src)
cov <- out[, .(polls = .N, lnp = mean(is.finite(LNP)), grn = mean(is.finite(GRN)), from = min(end), to = max(end)), by = st][order(st)]
cat(sprintf("FK1  %d polls from %s (source modified %s)\n", nrow(out), src, format(file.info(src)$mtime, "%Y-%m-%d %H:%M")))
print(cov)
# Coverage, not presence: a column parsed to all-NA would pass a schema check and quietly drop that class.
mainland <- c("nsw", "vic", "qld", "wa", "sa")
if (!all(mainland %in% cov$st)) stop("FK2! a mainland state has no federal breakdowns: ", paste(setdiff(mainland, cov$st), collapse = ", "))
# Wikipedia DELETED the sub-national sections from the fed2028 page on 2026-10-24 (revision 1381724607, "excessive
# detail"), so a local refresh of fed2028_opinion parses to no breakdowns from May 2025 on. The 6 Oct set (471
# polls) is final; never overwrite it with fewer or older. Pre-deletion copy: raw/fed2028_opinion-oldid1381712590.html.
prev_f <- out_path("fed-state-breakdowns.csv")
if (file.exists(prev_f)) {
  prev <- fread(prev_f, select = "end")
  if (nrow(out) < nrow(prev) || max(out$end) < max(as.Date(prev$end)))
    stop(sprintf("FK2! would shrink %s: %d polls to %s now vs %d to %s on disk. The fed2028 page lost its state sections on 2026-10-24; restore raw/fed2028_opinion.html from raw/fed2028_opinion-oldid1381712590.html and re-run the fetcher. Delete the output file only if the shrink is intended.",
                 prev_f, nrow(out), format(max(out$end)), nrow(prev), format(max(as.Date(prev$end)))))
}
if (nrow(out) < 300) stop("FK2! only ", nrow(out), " polls parsed (439 on 2026-10-12): the source or the parser changed")
if (mean(is.finite(out$LNP)) < 0.9 || mean(is.finite(out$GRN)) < 0.8)
  stop(sprintf("FK2! coverage too low: LNP %.0f%%, GRN %.0f%% (2026-10-12: 100%% / ~97%%)", 100 * mean(is.finite(out$LNP)), 100 * mean(is.finite(out$GRN))))
age <- as.integer(Sys.Date() - max(out$end))
if (age > 45) cat(sprintf("FK3! newest federal breakdown is %d days old: refetch scripts/fetch_statewide_poll_samples.R\n", age))
if (!full_only) {
  fwrite(out, out_path("fed-state-breakdowns.csv"))
  cat(sprintf("FK4  wrote %s\n", out_path("fed-state-breakdowns.csv")))
} else cat("FK4  --full-only: output/fed-state-breakdowns.csv left as it is\n")

# ---- the four-source union (trend arm, AUSPOL_TREND_FED_SRC=full) ----------------------------------------------
P <- file.path("external", "reference", "polls")
num <- function(x) suppressWarnings(as.numeric(sub("%", "", trimws(as.character(x)), fixed = TRUE)))
pdate <- function(s) {
  s <- as.character(s); out <- as.Date(rep(NA_character_, length(s)))
  iso <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", s); dmy <- grepl("^[0-9]{2}/[0-9]{2}/[0-9]{4}$", s)
  out[iso] <- as.Date(substr(s[iso], 1, 10), format = "%Y-%m-%d"); out[dmy] <- as.Date(s[dmy], format = "%d/%m/%Y")
  out
}
pmax_na <- function(...) { v <- do.call(pmax, c(list(...), na.rm = TRUE)); v }
keep_cols <- function(d) d[, names(d)[vapply(d, function(v) any(!is.na(v) & nzchar(as.character(v))), TRUE)], with = FALSE]
alias <- fread(file.path(P, "statewide-samples", "firm_alias.csv"), showProgress = FALSE)
is_result <- function(f) grepl("election|exit poll|^result", tolower(f))
STN <- c("New South Wales" = "nsw", "Victoria" = "vic", "Queensland" = "qld", "Western Australia" = "wa",
         "South Australia" = "sa", "Tasmania" = "tas")

# W: Wikipedia, every column
wr <- fread(src, colClasses = "character", showProgress = FALSE)
ws <- wr[wr$region == "fed" & grepl("^Sub-national polling > ", wr$section) & wr$row_type == "poll"]
gcol <- function(d, cc) { cc <- intersect(cc, names(d)); if (!length(cc)) return(rep(NA_real_, nrow(d))); do.call(pmax_na, lapply(cc, function(k) num(d[[k]]))) }
W <- data.table(src = "wiki", st = unname(STN[sub(" >.*", "", sub("^Sub-national polling > ", "", ws$section))]),
                start = pdate(ws$fieldwork_start), end = pdate(ws$fieldwork_end),
                firm = ifelse(nzchar(ws$firm), ws$firm, ws$firm_raw), ALP = num(ws$alp_fp),
                LNP = ifelse(is.finite(num(ws$lnp_fp)), num(ws$lnp_fp),
                             ifelse(is.finite(num(ws$lib_fp)) | is.finite(num(ws$nat_fp)), rowSums(cbind(num(ws$lib_fp), num(ws$nat_fp)), na.rm = TRUE), NA_real_)),
                GRN = gcol(ws, c("pv_Grn", "pv_GRN", "pv_Green", "pv_Gre")), ONP = gcol(ws, c("pv_ONP", "pv_ON")), n = num(ws$sample_n))
Wraw <- keep_cols(ws); setnames(Wraw, paste0("wiki_", names(Wraw)))
W <- cbind(W, Wraw)
# national rows (sample size of the same firm's national poll)
wn <- wr[wr$region == "fed" & wr$row_type == "poll" & grepl("^(Data table|House of Representatives opinion polling|National polling > Voting intention)", wr$section)]
NAT <- data.table(firm = ifelse(nzchar(wn$firm), wn$firm, wn$firm_raw), end = pdate(wn$fieldwork_end), n = num(wn$sample_n))

# BT: BludgerTrack. The Oct-13 parse (scripts/extract_bludgertrack.R) plus the newest dated fed2028 refetch, whose
# fed2028 rows supersede the older file's (the later file carries every earlier poll of the term too).
bt <- fread(file.path(P, "pollbludger", "bludgertrack_polls.csv"), colClasses = "character", showProgress = FALSE)
raw_dir <- file.path(P, "pollbludger", "raw", "bludgertrack")
dated <- sort(list.files(raw_dir, "^fed2028-current-[0-9]{4}-[0-9]{2}-[0-9]{2}[.]xml$"))
if (length(dated)) {
  f <- utils::tail(dated, 1)
  x <- xml2::read_xml(file.path(raw_dir, f))
  pts <- xml2::xml_find_all(x, "//table/point")
  d <- rbindlist(lapply(pts, function(p) {
    a <- as.list(xml2::xml_attrs(p)); ch <- xml2::xml_children(p)
    v <- as.list(xml2::xml_text(ch)); names(v) <- xml2::xml_name(ch); c(a, v)
  }), fill = TRUE)
  d[, `:=`(cycle = "fed2028", section = vapply(pts, function(p) xml2::xml_name(xml2::xml_parent(xml2::xml_parent(p))), ""),
           file_stamp = xml2::xml_attr(x, "date"))]
  old_n <- sum(bt$cycle == "fed2028" & bt$section == "federal")
  bt <- rbind(bt[bt$cycle != "fed2028"], d, fill = TRUE)
  cat(sprintf("FU0  BludgerTrack: %s (stamp %s) replaces the 13 Oct fed2028 rows: federal-section rows %d -> %d\n",
              f, xml2::xml_attr(x, "date"), old_n, sum(bt$cycle == "fed2028" & bt$section == "federal")))
}
bs <- bt[bt$section == "federal" & bt$scope %in% c("VIC", "NSW", "QLD", "WA", "SA", "TAS") & !is_result(bt$pollster)]
bonp <- if ("ONP" %in% names(bs)) num(bs$ONP) else rep(NA_real_, nrow(bs))
bonp[!is.finite(bonp)] <- num(bs$PHON)[!is.finite(bonp)]
B <- data.table(src = "bt", st = tolower(bs$scope), start = pdate(bs$start), end = pdate(bs$end), firm = bs$pollster,
                ALP = num(bs$ALP), LNP = num(bs$LNC), GRN = num(bs$GRN), ONP = bonp, n = num(bs$sample))
Braw <- keep_cols(bs); setnames(Braw, paste0("bt_", names(Braw)))
B <- cbind(B, Braw)
bn <- bt[bt$section == "federal" & bt$scope == "NAT" & !is_result(bt$pollster)]
NAT <- rbind(NAT, data.table(firm = bn$pollster, end = pdate(bn$end), n = num(bn$sample)))

# SF: state-federal-polls.csv, scope == state
sf <- fread(file.path(P, "state-federal", "state-federal-polls.csv"), colClasses = "character", showProgress = FALSE)
sf <- sf[sf$scope == "state"]
m <- regmatches(sf$extra_fp, regexpr("ONP=[0-9.]+", sf$extra_fp))
sonp <- rep(NA_real_, nrow(sf)); sonp[grepl("ONP=[0-9.]+", sf$extra_fp)] <- num(sub("ONP=", "", m))
S <- data.table(src = "sf", st = tolower(sf$state), start = pdate(sf$fieldwork_start), end = pdate(sf$fieldwork_end), firm = sf$pollster,
                ALP = num(sf$alp_fp), LNP = num(sf$lnp_fp), GRN = num(sf$grn_fp), ONP = sonp, n = num(sf$sample_n))
Sraw <- keep_cols(sf); setnames(Sraw, paste0("sf_", names(Sraw)))
S <- cbind(S, Sraw)

# NQ: Newspoll quarterly state breakdowns (one row per party in the file; one row per poll here)
nq <- fread(file.path(P, "newspoll-quarterly", "breakdowns.csv"), colClasses = "character", showProgress = FALSE)
nq <- nq[nq$dimension == "state" & tolower(nq$group) %in% c("nsw", "vic", "qld", "wa", "sa", "tas")]
nq[, pk := paste(pollster, period_start, period_end, published, group, sep = "|")]
nqw <- dcast(nq, pk + pollster + period_start + period_end + published + group + sample_n + source_url ~ party, value.var = "fp",
             fun.aggregate = function(v) v[1], fill = NA)
tpp <- nq[, list(tpp_alp = tpp_alp[1]), by = "pk"]
nqw <- merge(nqw, tpp, by = "pk")
nend <- pdate(nqw$period_end); nend[!is.finite(nend)] <- pdate(nqw$published)[!is.finite(nend)]
pcol <- function(k) if (k %in% names(nqw)) num(nqw[[k]]) else rep(NA_real_, nrow(nqw))
Q <- data.table(src = "nq", st = tolower(nqw$group), start = pdate(nqw$period_start), end = nend, firm = nqw$pollster,
                ALP = pcol("ALP"), LNP = pcol("LNP"), GRN = pcol("GRN"), ONP = pcol("ONP"), n = num(nqw$sample_n))
Qraw <- keep_cols(nqw); setnames(Qraw, paste0("nq_", names(Qraw)))
Q <- cbind(Q, Qraw)

A <- rbindlist(list(W, B, S, Q), fill = TRUE)
A <- A[!is.na(A$st) & is.finite(A$end) & (is.finite(A$ALP) | is.finite(A$LNP)) & !is_result(A$firm)]
A$start[!is.finite(A$start) | A$start > A$end] <- A$end[!is.finite(A$start) | A$start > A$end]
A$canon <- .ps_canon(A$firm, alias)
cat("FU1  rows per source (state scope, results dropped):", paste(names(table(A$src)), table(A$src), collapse = ", "), "\n")
cat("FU1  canonical firms:", paste(sprintf("%s=%s", names(table(A$canon)), table(A$canon)), collapse = ", "), "\n")

# ---- dedupe: same state, same canonical firm, fieldwork end within 3 days -------------------------------------
PRI <- c(wiki = 1L, bt = 2L, sf = 3L, nq = 4L)
A$pri <- PRI[A$src]
setorderv(A, c("st", "pri", "end"))
cl <- integer(nrow(A)); ncl <- 0L
cl_st <- character(0); cl_canon <- character(0); cl_end <- as.Date(character(0)); cl_srcs <- list()
within_dup <- 0L
for (i in seq_len(nrow(A))) {
  cand <- which(cl_st == A$st[i] & cl_canon == A$canon[i] & abs(as.integer(cl_end - A$end[i])) <= 3L)
  if (length(cand)) {
    k <- cand[which.min(abs(as.integer(cl_end[cand] - A$end[i])))]
    if (A$src[i] %in% cl_srcs[[k]]) within_dup <- within_dup + 1L
    cl[i] <- k; cl_srcs[[k]] <- c(cl_srcs[[k]], A$src[i])
  } else {
    ncl <- ncl + 1L; cl[i] <- ncl
    cl_st[ncl] <- A$st[i]; cl_canon[ncl] <- A$canon[i]; cl_end[ncl] <- A$end[i]; cl_srcs[[ncl]] <- A$src[i]
  }
}
A$cl <- cl
cat(sprintf("FU2  %d source rows -> %d polls; %d rows duplicated a source already in their poll (first kept)\n", nrow(A), ncl, within_dup))
VAL <- c("start", "end", "firm", "ALP", "LNP", "GRN", "ONP", "n")
dis <- list()
U <- rbindlist(lapply(split(seq_len(nrow(A)), A$cl), function(ix) {
  d <- A[ix]; d <- d[order(d$pri)]
  top <- d[1]
  for (k in c("ALP", "LNP", "GRN", "ONP", "n")) {
    v <- d[[k]]; fin <- which(is.finite(v))
    if (length(fin)) top[[k]] <- v[fin[1]]
    if (k != "n" && length(fin) > 1L && diff(range(v[fin])) > 1)
      dis[[length(dis) + 1L]] <<- data.table(st = top$st, firm = top$canon, end = top$end, cls = k,
                                            values = paste(sprintf("%s %.1f", d$src[fin], v[fin]), collapse = " / "))
  }
  if (!is.finite(top$start) || top$start == top$end) { s <- d$start[is.finite(d$start) & d$start < d$end]; if (length(s)) top$start <- s[1] }
  out <- data.table(st = top$st, start = top$start, end = top$end, firm = top$firm, canon = top$canon,
                    ALP = top$ALP, LNP = top$LNP, GRN = top$GRN, ONP = top$ONP, n = top$n,
                    sources = paste(unique(d$src), collapse = "+"), n_src = uniqueN(d$src))
  # raw columns: each source's first row in this poll
  for (s in unique(d$src)) {
    r <- d[d$src == s][1]
    rc <- grep(paste0("^", s, "_"), names(r), value = TRUE)
    out <- cbind(out, r[, rc, with = FALSE])
  }
  out
}), fill = TRUE)
dis <- rbindlist(dis)
cat(sprintf("FU3  %d disagreements over 1 point between sources (value kept: the first source listed):\n", nrow(dis)))
if (nrow(dis)) print(dis, nrows = 400)

# national sample of the same poll, for the arm's imputation step 2
NAT <- NAT[is.finite(NAT$end) & is.finite(NAT$n) & !is_result(NAT$firm)]
NAT$canon <- .ps_canon(NAT$firm, alias)
U$n_nat <- vapply(seq_len(nrow(U)), function(i) {
  j <- which(NAT$canon == U$canon[i] & abs(as.integer(NAT$end - U$end[i])) <= 3L)
  if (!length(j)) NA_real_ else NAT$n[j[which.min(abs(as.integer(NAT$end[j] - U$end[i])))]]
}, 0)
setorderv(U, c("st", "end", "canon"))
setcolorder(U, c("st", "start", "end", "firm", "canon", "ALP", "LNP", "GRN", "ONP", "n", "n_nat", "sources", "n_src"))
covu <- U[, list(polls = .N, onp = sum(is.finite(ONP)), n = sum(is.finite(n)), n_nat = sum(is.finite(n_nat)),
                 from = min(end), to = max(end)), by = "st"][order(st)]
cat("FU4  union coverage per state (polls; with ONP; with state n; with national n; fieldwork end range):\n"); print(covu)
cat("FU4  newest fieldwork end per source:", paste(sprintf("%s %s", c("wiki", "bt", "sf", "nq"),
    vapply(c("wiki", "bt", "sf", "nq"), function(s) format(max(A$end[A$src == s])), "")), collapse = ", "), "\n")
# Coverage, not presence (CLAUDE.md): the columns the arm reads must be populated.
if (mean(is.finite(U$ALP)) < 0.95 || mean(is.finite(U$LNP)) < 0.9) stop("FU5! ALP/LNP coverage collapsed in the union")
if (sum(is.finite(U$ONP)) < 200) stop("FU5! only ", sum(is.finite(U$ONP)), " polls carry a One Nation figure")
if (sum(is.finite(U$n)) < 300) stop("FU5! only ", sum(is.finite(U$n)), " polls carry a state sample size")
if (!all(mainland %in% U$st)) stop("FU5! a mainland state is missing from the union")
fwrite(U, out_path("fed-state-breakdowns-full.csv"))
cat(sprintf("FU6  wrote %s: %d polls x %d columns\n", out_path("fed-state-breakdowns-full.csv"), nrow(U), ncol(U)))
