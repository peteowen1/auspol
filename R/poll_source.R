# Our own poll source, layered over AE's file (AUSPOL_POLL_SOURCE = "layered", SHIPPED 2026-10-13; Pete).
# docs/plans/prereg-own-poll-source-step2-2026-10-12.md. "ae" = AE's file alone.
#
# AE's poll-data-<region>.csv is hand-maintained: one column per party, undecided divided out, firm labels that
# carry methodology eras ("Newspoll3", "SMS Morgan"). Our scrape (scripts/fetch_statewide_poll_samples.R) keeps
# the source's own numbers. Layering, per poll: a poll in both files keeps OUR numbers under AE's firm label (so
# the house effect keeps its era); a poll only AE has is kept; a poll only we have is added under the label of
# the same firm's nearest AE poll. Found necessary 2026-10-12: AE carried RedBridge 2-8 Oct 2026 (Vic) with the
# Greens and One Nation swapped, and lacked Resolve 6-10 Oct.

.ps_memo <- new.env(parent = emptyenv())

# Implied ALP two-party share from primaries: ALP + 0.83 GRN + 0.35 ONP + 0.45 rest (rough national preference
# flows). Used only to check a poll row against its own published two-party figure, never as a forecast input.
#' @noRd
.ps_implied <- function(alp, lnp, grn, onp) {
  z <- function(x) ifelse(is.finite(x), x, 0)
  alp + 0.83 * z(grn) + 0.35 * z(onp) + 0.45 * pmax(100 - alp - lnp - z(grn) - z(onp), 0)
}

#' Which poll source the trend reads
#' @return `"ae"` or `"layered"`.
#' @export
poll_source_mode <- function() {
  v <- Sys.getenv("AUSPOL_POLL_SOURCE", "layered")
  if (!v %in% c("ae", "layered")) stop("AUSPOL_POLL_SOURCE must be \"ae\" or \"layered\", not ", v)
  v
}

# Two rows of one firm with the same primaries (Labor, Coalition and, where both report it, the Greens and One
# Nation, each within 0.5 point) are one poll dated differently when their dates are up to 31 days apart.
# Found 2026-10-13: Resolve's two-month Victorian polls sit 14-29 days apart across Wikipedia, AE and
# BludgerTrack (Resolve Vic 24/41 was in the shipped set twice, as AE's 1 Mar 2025 and Wikipedia's 30 Mar);
# outside the 4-day midpoint window they were counted twice.
#' @noRd
.ps_same_poll_far <- function(dd, a, b, ia, ib) {
  eq <- function(p) {
    x <- if (p %in% names(a)) a[[p]][ia] else rep(NA_real_, length(ia)); y <- if (p %in% names(b)) b[[p]][ib] else rep(NA_real_, length(ib))
    !(is.finite(x) & is.finite(y)) | abs(x - y) <= 0.5
  }
  core <- abs(a$ALP[ia] - b$ALP[ib]) <= 0.5 & abs(a$LNP[ia] - b$LNP[ib]) <= 0.5
  abs(dd) <= 31L & !is.na(core) & core & eq("GRN") & eq("ONP")
}

# canonical firm name from external/reference/polls/statewide-samples/firm_alias.csv (regex -> canonical)
#' @noRd
.ps_canon <- function(firm, alias) {
  out <- rep(NA_character_, length(firm)); f <- tolower(firm)
  for (i in seq_len(nrow(alias))) {
    hit <- is.na(out) & grepl(alias$pattern[i], f, perl = TRUE)
    out[hit] <- alias$canonical[i]
  }
  ifelse(is.na(out), gsub("[^a-z]", "", f), out)
}

#' Our voting-intention polls for one region, in load_polls()'s shape
#'
#' @param region Poll region.
#' @param parties The region's party columns in AE's file (output columns; anything else folds into OTH).
#' @param path Path to `statewide_polls_wiki.csv`.
#' @return data.table: `date` (fieldwork midpoint), `end`, `firm_raw`, `canon`, `tpp_published`, one column per
#'   party, `und` (undecided share divided out).
#' @export
wiki_polls <- function(region, parties, path) {
  w <- data.table::fread(path, showProgress = FALSE)
  reg <- region
  # Statewide lower-house voting intention only. "Sub-state", "Legislative Council", "Voting consideration" and
  # "Leader satisfaction" were missing until 2026-10-13: 85 rows (Inner Melbourne, Regional SA, upper-house votes)
  # entered sa2026, vic2026 and nsw2027 as statewide polls, found by comparing against BludgerTrack's own table.
  keep <- w$row_type == "poll" & w$table_type == "primary" & w$region == reg &
    !grepl("Sub-national|Sub-state|Subpopulation|Electorate|seat|Hypothetical|Exit|By gender|By age|By generation|By language|By country|Legislative Council|Voting consideration|Leader satisfaction",
           w$section, ignore.case = TRUE) &
    !grepl("exit poll", paste(w$firm_raw, w$footnote_raw), ignore.case = TRUE)
  w <- w[keep]
  fs <- as.Date(w$fieldwork_start); fe <- as.Date(w$fieldwork_end)
  span <- as.integer(fe - fs)
  w <- w[is.finite(fe) & (is.na(span) | span <= 45L)]
  fs <- as.Date(w$fieldwork_start); fe <- as.Date(w$fieldwork_end)
  mid <- as.Date(ifelse(is.finite(fs) & fs <= fe, as.integer(fs) + (as.integer(fe) - as.integer(fs)) %/% 2L, as.integer(fe)), origin = "1970-01-01")
  pct <- function(x) suppressWarnings(as.numeric(gsub("[%,]", "", as.character(x))))
  pick <- function(cols) {   # first non-missing of several spellings
    cols <- intersect(cols, names(w)); if (!length(cols)) return(rep(NA_real_, nrow(w)))
    v <- pct(w[[cols[1]]]); for (cc in cols[-1]) { u <- pct(w[[cc]]); v[is.na(v)] <- u[is.na(v)] }; v
  }
  lib <- suppressWarnings(as.numeric(w$lib_fp)); nat <- suppressWarnings(as.numeric(w$nat_fp))
  lnp <- suppressWarnings(as.numeric(w$lnp_fp))
  vals <- list(ALP = suppressWarnings(as.numeric(w$alp_fp)),
               GRN = pick(c("pv_GRN", "pv_Green", "pv_Grn", "pv_Gre")),
               ONP = pick(c("pv_ONP", "pv_ON")), UAP = pick("pv_UAP"), SFF = pick("pv_SFF"), KAP = pick("pv_KAP"),
               SAB = pick("pv_SAB"), FF = pick("pv_FFP"), DEM = pick(c("pv_Dem", "pv_AD")), DLP = pick("pv_DLP"))
  # Coalition split into Liberal and National sub-columns under one "L/NP" header (federal 2026 tables): the
  # parser reads the Liberal cell as lnp_fp and the National cell as pv_L/NP_1. Add it only when the row's
  # primaries then sum closer to 100 and the cell is small (under 12), so a two-party "L/NP" column is never
  # mistaken for the Nationals.
  lnp2 <- pick("pv_L/NP_1")
  oth_cells <- rowSums(cbind(pick(c("pv_Others", "pv_OTH", "pv_Other", "pv_Oth")), pick("pv_IND"), pick("pv_UND")), na.rm = TRUE)
  base_sum <- rowSums(cbind(suppressWarnings(as.numeric(w$alp_fp)), lnp, vals$GRN, vals$ONP, vals$UAP), na.rm = TRUE) + oth_cells
  add_nat <- is.finite(lnp) & is.finite(lnp2) & lnp2 < 12 & abs(base_sum + lnp2 - 100) < abs(base_sum - 100)
  lnp[add_nat] <- lnp[add_nat] + lnp2[add_nat]
  if (identical(region, "wa")) {   # load_polls() renames WA's LIB to LNP and keeps NAT apart
    vals$LNP <- ifelse(is.finite(lib), lib, ifelse(is.finite(lnp) & !is.finite(nat), lnp, NA_real_)); vals$NAT <- nat
  } else {
    vals$LNP <- ifelse(is.finite(lnp), lnp, ifelse(is.finite(lib) | is.finite(nat), rowSums(cbind(lib, nat), na.rm = TRUE), NA_real_))
  }
  und <- pick(c("pv_UND"))
  named <- setdiff(intersect(parties, names(vals)), "OTH")
  out <- data.table::data.table(date = mid, end = fe, firm_raw = trimws(w$firm_raw), tpp_published = suppressWarnings(as.numeric(w$alp_tpp)))
  for (p in named) out[[p]] <- vals[[p]]
  # undecided divided out (AE's rule), then OTH is the decided remainder
  u <- ifelse(is.finite(und) & und > 0 & und < 50, und, 0)
  scale <- 100 / (100 - u)
  for (p in named) out[[p]] <- out[[p]] * scale
  if ("OTH" %in% parties) {
    s <- rowSums(as.matrix(out[, named, with = FALSE]), na.rm = TRUE)
    out$OTH <- pmax(0, 100 - s)
  }
  out$und <- u
  # One copy per poll before the self-check, so a check can never split two copies of one poll apart.
  dup <- duplicated(out, by = c("date", "end", "firm_raw", intersect(c("ALP", "LNP", "GRN", "ONP"), names(out))))
  out <- out[!dup]; tpp_l_rows <- which(!dup)
  # Published two-party figure, normalised: Essential publishes it with undecided left in (46 / 44, total 90).
  tpp_l <- pick(c("tpp_L/NP", "tpp_LNP", "tpp_Lib/Nat", "tpp_L/NP_1"))[tpp_l_rows]
  stopifnot(length(tpp_l) == nrow(out))
  tsum <- out$tpp_published + tpp_l
  norm <- is.finite(tsum) & tsum > 75 & tsum < 99
  out$tpp_published[norm] <- 100 * out$tpp_published[norm] / tsum[norm]
  # Self-check against the poll's own two-party figure, no AE needed. A row that fits only with Labor and the
  # Coalition swapped is swapped back (Wikipedia's own row can be wrong: Galaxy Qld 17-18 Nov 2015 lists ALP 42 /
  # LNP 37 beside ALP 49 two-party); a row that fits neither way is marked suspect.
  e0 <- abs(.ps_implied(out$ALP, out$LNP, out$GRN, out$ONP) - out$tpp_published)
  es <- abs(.ps_implied(out$LNP, out$ALP, out$GRN, out$ONP) - out$tpp_published)
  # Swap only on strong evidence and while One Nation is small: the flow weights above are rough, and at One
  # Nation 20+ they are too uncertain to tell a swap from a flow error (RedBridge Vic Oct 2026, ON 24, was wrongly
  # "swapped" by a looser rule).
  small_on <- !is.finite(out$ONP) | out$ONP < 10
  swap <- is.finite(e0) & is.finite(es) & small_on & es < 1.5 & e0 > 5
  if (any(swap)) { a <- out$ALP[swap]; out$ALP[swap] <- out$LNP[swap]; out$LNP[swap] <- a }
  out$check <- ifelse(!is.finite(e0), "no_tpp", ifelse(swap, "swapped", ifelse(e0 > 5, "suspect", "ok")))
  out <- out[is.finite(out$ALP) & is.finite(out$LNP) & is.finite(out$date)]
  # The same poll can appear twice on a page (e.g. RedBridge 2-8 Oct 2026, vic2026): count it once.
  out <- unique(out, by = c("date", "end", "firm_raw", intersect(c("ALP", "LNP", "GRN", "ONP"), names(out))))
  for (p in setdiff(parties, names(out))) out[[p]] <- NA_real_
  out
}

#' Whether BludgerTrack's poll tables join our own polls (AUSPOL_POLL_BT, "1" shipped 2026-10-13)
#' @return logical.
#' @export
poll_bt_on <- function() {
  v <- Sys.getenv("AUSPOL_POLL_BT", "1")
  if (!v %in% c("0", "1")) stop("AUSPOL_POLL_BT must be \"0\" or \"1\", not ", v)
  identical(v, "1")
}

#' The Poll Bludger's own poll tables for one region, in wiki_polls()'s shape
#'
#' BludgerTrack publishes the poll table behind its aggregate for the current cycles only (fed2025, fed2028,
#' vic2026; built by `scripts/build_bludgertrack_polls.R`). Each row carries undecided separately, so it is
#' divided out (AE's rule, and wiki_polls()'s where Wikipedia shows it; Wikipedia folds Essential's undecided
#' into Others). National rows for `fed`, the state table for a state.
#' @param region Poll region.
#' @param parties The region's party columns in AE's file.
#' @param path Path to `bludgertrack_polls.csv`.
#' @return data.table like [wiki_polls()], or `NULL` when the region has no table.
#' @export
bludgertrack_polls <- function(region, parties, path) {
  b <- data.table::fread(path, colClasses = "character", showProgress = FALSE)
  reg <- region
  keep <- if (identical(reg, "fed")) b$section == "federal" & b$scope == "NAT" else
    b$section == c(vic = "victoria", nsw = "nsw", qld = "queensland", sa = "sa", wa = "wa")[reg] & b$scope == "STATEWIDE"
  keep <- keep & !is.na(keep) & !grepl("^Election$", b$pollster)
  b <- b[keep]
  if (!nrow(b)) return(NULL)
  n <- function(k) if (k %in% names(b)) suppressWarnings(as.numeric(b[[k]])) else rep(NA_real_, nrow(b))
  fs <- as.Date(b$start_date); fe <- as.Date(b$end_date); md <- as.Date(b$median_date)
  mid <- data.table::fifelse(is.finite(md), md,
    as.Date(ifelse(is.finite(fs) & fs <= fe, as.integer(fs) + (as.integer(fe) - as.integer(fs)) %/% 2L, as.integer(fe)), origin = "1970-01-01"))
  onp <- n("ONP"); onp[!is.finite(onp)] <- n("PHON")[!is.finite(onp)]
  vals <- list(ALP = n("ALP"), LNP = n("LNC"), GRN = n("GRN"), ONP = onp)
  und <- n("UND"); u <- ifelse(is.finite(und) & und > 0 & und < 50, und, 0)
  named <- setdiff(intersect(parties, names(vals)), "OTH")
  out <- data.table::data.table(date = mid, end = fe, firm_raw = trimws(b$pollster), mode_bt = b$mode, sample_n = n("sample"))
  for (p in named) out[[p]] <- vals[[p]] * 100 / (100 - u)
  if ("OTH" %in% parties) out$OTH <- pmax(0, 100 - rowSums(as.matrix(out[, named, with = FALSE]), na.rm = TRUE))
  out$und <- u
  t2 <- n("ALP2"); l2 <- n("LNC2"); s2 <- t2 + l2
  out$tpp_published <- ifelse(is.finite(s2) & s2 > 75 & s2 < 99, 100 * t2 / s2, t2)
  e0 <- abs(.ps_implied(out$ALP, out$LNP, out$GRN, out$ONP) - out$tpp_published)
  out$check <- ifelse(!is.finite(e0), "no_tpp", ifelse(e0 > 5, "suspect", "ok"))
  out <- out[is.finite(out$ALP) & is.finite(out$LNP) & is.finite(out$date)]
  out <- unique(out, by = c("date", "end", "firm_raw", intersect(c("ALP", "LNP", "GRN", "ONP"), names(out))))
  for (p in setdiff(parties, names(out))) out[[p]] <- NA_real_
  out
}

# Our own polls from two sources: Wikipedia and BludgerTrack. A poll both have keeps BludgerTrack's row (undecided
# handled the same way on every poll, sample size, mode) unless that row failed its own two-party check and
# Wikipedia's did not; a poll only one has is kept. Same one-to-one matching as poll_layer(). `origin` says whose.
#' @noRd
.ps_merge_own <- function(wiki, bt, alias, window = 4L) {
  wiki$origin <- "wiki"
  if (is.null(bt) || !nrow(bt)) return(list(ours = wiki, log = c(bt = 0L, both = 0L, bt_only = 0L, differ_gt1 = 0L)))
  bt$origin <- "bludgertrack"
  wiki$canon <- .ps_canon(wiki$firm_raw, alias); bt$canon <- .ps_canon(bt$firm_raw, alias)
  cand <- wiki[, list(wi = .I, canon, d_w = date)][bt[, list(bi = .I, canon, d_b = date)], on = "canon", allow.cartesian = TRUE, nomatch = NULL]
  dd <- as.integer(cand$d_w - cand$d_b)
  cand <- cand[abs(dd) <= window | .ps_same_poll_far(dd, wiki, bt, cand$wi, cand$bi)]
  num <- abs(wiki$ALP[cand$wi] - bt$ALP[cand$bi]) + abs(wiki$LNP[cand$wi] - bt$LNP[cand$bi])
  cand$score <- abs(as.integer(cand$d_w - cand$d_b)) + ifelse(is.finite(num), num, 50) / 2
  data.table::setorderv(cand, "score")
  uw <- logical(nrow(wiki)); ub <- logical(nrow(bt)); pw <- integer(0); pb <- integer(0)
  for (k in seq_len(nrow(cand))) {
    w <- cand$wi[k]; b <- cand$bi[k]
    if (uw[w] || ub[b]) next
    uw[w] <- ub[b] <- TRUE; pw <- c(pw, w); pb <- c(pb, b)
  }
  take_bt <- !(bt$check[pb] == "suspect" & wiki$check[pw] != "suspect")
  d1 <- abs(wiki$ALP[pw] - bt$ALP[pb]) > 1 | abs(wiki$LNP[pw] - bt$LNP[pb]) > 1
  # both sources had it: the kept row says so
  bt$origin[pb[take_bt]] <- "bludgertrack+wiki"; wiki$origin[pw[!take_bt]] <- "wiki+bludgertrack"
  drop_w <- pw[take_bt]; drop_b <- pb[!take_bt]
  ours <- rbind(wiki[!seq_len(nrow(wiki)) %in% drop_w], bt[!seq_len(nrow(bt)) %in% drop_b], use.names = TRUE, fill = TRUE)
  ours$canon <- NULL
  data.table::setorderv(ours, "date")
  list(ours = ours, log = c(bt = nrow(bt), both = length(pb), bt_only = sum(!ub), differ_gt1 = sum(d1, na.rm = TRUE)))
}

#' Layer our polls over AE's for one region (see the file header)
#'
#' @param ae AE's polls as [load_polls()] reads them (before layering).
#' @param region Poll region.
#' @param path Path to `statewide_polls_wiki.csv`; `AUSPOL_POLL_WIKI` or the scrape folder by default.
#' @param window Days apart two midpoints may be and still be the same poll.
#' @return `ae`'s shape with our numbers on matched polls and our unmatched polls added; attribute `layer_log`.
#' @export
poll_layer <- function(ae, region, path = NULL, window = 4L) {
  if (is.null(path)) {
    # AUSPOL_POLL_WIKI, else the scrape folder (local), else output/polls-wiki/ (CI: the published file merged with
    # that morning's fresh live pages by forecast.yaml; every job that gets output/ gets it too).
    cands <- c(Sys.getenv("AUSPOL_POLL_WIKI", ""),
               file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "statewide_polls_wiki.csv"),
               out_path(file.path("polls-wiki", "statewide_polls_wiki.csv")))
    cands <- cands[nzchar(cands) & file.exists(cands)]
    path <- if (length(cands)) cands[1] else "statewide_polls_wiki.csv (not found)"
  }
  if (!file.exists(path)) stop("AUSPOL_POLL_SOURCE=layered needs statewide_polls_wiki.csv: set AUSPOL_POLL_WIKI, run scripts/fetch_statewide_poll_samples.R, or put it in output/polls-wiki/ (forecast.yaml does)")
  alias_f <- file.path(dirname(path), "firm_alias.csv")
  alias <- if (file.exists(alias_f)) data.table::fread(alias_f, showProgress = FALSE) else
    data.table::fread(file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "firm_alias.csv"), showProgress = FALSE)
  parties <- attr(ae, "parties")
  ours <- wiki_polls(region, parties, path)
  bt_log <- c(bt = 0L, both = 0L, bt_only = 0L, differ_gt1 = 0L)
  if (poll_bt_on()) {
    # AUSPOL_POLL_BT_FILE, else beside the Wikipedia table (CI: output/polls-wiki/), else the build folder
    bc <- c(Sys.getenv("AUSPOL_POLL_BT_FILE", ""), file.path(dirname(path), "bludgertrack_polls.csv"),
            file.path(pkg_root(), "external", "reference", "polls", "pollbludger", "bludgertrack_polls.csv"))
    bc <- bc[nzchar(bc) & file.exists(bc)]
    if (!length(bc)) stop("AUSPOL_POLL_BT=1 needs bludgertrack_polls.csv: run scripts/build_bludgertrack_polls.R, set AUSPOL_POLL_BT_FILE, or AUSPOL_POLL_BT=0")
    mo <- .ps_merge_own(ours, bludgertrack_polls(region, parties, bc[1]), alias)
    ours <- mo$ours; bt_log <- mo$log
  } else ours$origin <- "wiki"
  ae <- data.table::copy(ae)
  ae$canon <- .ps_canon(ae$firm, alias); ours$canon <- .ps_canon(ours$firm_raw, alias)
  # one-to-one matching, closest midpoints first
  cand <- ours[, list(oi = .I, canon, d_o = date)][ae[, list(ai = .I, canon, d_a = date)], on = "canon", allow.cartesian = TRUE, nomatch = NULL]
  dd <- as.integer(cand$d_o - cand$d_a)
  cand <- cand[abs(dd) <= window | .ps_same_poll_far(dd, ours, ae, cand$oi, cand$ai)]
  # Closest midpoints first, and among those the closest numbers: two Morgan polls (phone, face to face) can
  # share a date, and pairing them crosswise compares different polls.
  num <- abs(ours$ALP[cand$oi] - ae$ALP[cand$ai]) + abs(ours$LNP[cand$oi] - ae$LNP[cand$ai])
  cand$score <- abs(as.integer(cand$d_o - cand$d_a)) + ifelse(is.finite(num), num, 50) / 2
  data.table::setorderv(cand, "score")
  used_o <- logical(nrow(ours)); used_a <- logical(nrow(ae)); pair_o <- integer(0); pair_a <- integer(0)
  for (k in seq_len(nrow(cand))) {
    o <- cand$oi[k]; a <- cand$ai[k]
    if (used_o[o] || used_a[a]) next
    used_o[o] <- TRUE; used_a[a] <- TRUE; pair_o <- c(pair_o, o); pair_a <- c(pair_a, a)
  }
  majors <- intersect(c("ALP", "LNP", "GRN", "ONP"), parties)
  diff_big <- if (length(pair_o)) vapply(seq_along(pair_o), function(j) {
    d <- abs(unlist(ours[pair_o[j], majors, with = FALSE]) - unlist(ae[pair_a[j], majors, with = FALSE])); any(d > 2, na.rm = TRUE) }, TRUE) else logical(0)
  fmt <- function(D, idx) apply(round(as.matrix(D[idx, majors, with = FALSE]), 1), 1, paste, collapse = "/")
  differ <- if (any(diff_big)) data.table::data.table(date = ours$date[pair_o][diff_big], firm = ae$firm[pair_a][diff_big],
                                                      parties = paste(majors, collapse = "/"),
                                                      ours = fmt(ours, pair_o[diff_big]), ae = fmt(ae, pair_a[diff_big])) else NULL
  # A pair that disagrees by more than 2 points: keep whichever row's primaries fit the poll's own published
  # two-party figure better, by at least 1 point. Implied ALP two-party = ALP + 0.83 GRN + 0.35 ONP + 0.45 rest
  # (rough national preference flows; only used to tell two copies of one poll apart, never as a forecast input).
  # Undecidable (no published figure, or neither clearly closer): keep AE's row. A row of ours that failed its own
  # two-party check (wiki_polls(): "suspect") never wins.
  implied <- function(D, idx) {
    g <- function(p) if (p %in% names(D)) D[[p]][idx] else rep(NA_real_, length(idx))
    .ps_implied(g("ALP"), g("LNP"), g("GRN"), g("ONP"))
  }
  use_ours <- ours$check[pair_o] != "suspect"
  if (any(diff_big)) {
    j <- which(diff_big)
    tpp <- ours$tpp_published[pair_o[j]]; tpp[!is.finite(tpp)] <- ae$tpp_published[pair_a[j]][!is.finite(tpp)]
    e_o <- abs(implied(ours, pair_o[j]) - tpp); e_a <- abs(implied(ae, pair_a[j]) - tpp)
    use_ours[j] <- use_ours[j] & is.finite(e_o) & is.finite(e_a) & e_o + 1 <= e_a
    if (!is.null(differ)) { differ$tpp <- tpp; differ$err_ours <- round(e_o, 1); differ$err_ae <- round(e_a, 1)
                            differ$kept <- ifelse(use_ours[j], "ours", "ae") }
  }
  # matched: our numbers (where kept) under AE's label and date
  po <- pair_o[use_ours]; pa <- pair_a[use_ours]
  # Provenance of every output row, for the move-off-AE audit (scripts/audit_ae_dependence.R): where its numbers
  # came from, which parties AE had to fill, and whether the firm label is AE's.
  ae$.prov <- "ae_only"
  ae$.prov[pair_a] <- ifelse(use_ours, "ours", ifelse(diff_big, "ae_dispute", "ae_suspect"))
  ae$.fill <- ""; ae$.label_ae <- TRUE
  ae$.origin <- "ae"; ae$.origin[pa] <- ours$origin[po]
  # A party our row does not report (the page folded it into Others: the wa2017 table has no One Nation column)
  # keeps AE's figure, and our Others gives that share back. Without this, layering blanked One Nation on the
  # final WA 2017 polls and wa2017 seat log loss rose 0.086 (deciding run, 2026-10-12).
  named_p <- setdiff(parties, "OTH")
  for (p in named_p) {
    fill <- !is.finite(ours[[p]][po]) & is.finite(ae[[p]][pa])
    if (any(fill) && "OTH" %in% parties) ours$OTH[po[fill]] <- pmax(0, ours$OTH[po[fill]] - ae[[p]][pa[fill]])
    ours[[p]][po[fill]] <- ae[[p]][pa[fill]]
    ae$.fill[pa[fill]] <- paste0(ae$.fill[pa[fill]], p, " ")
  }
  for (p in parties) ae[[p]][pa] <- ours[[p]][po]
  # unmatched ours: label of the same firm's nearest AE poll, else our own text
  extra <- ours[!used_o]
  n_suspect_dropped <- sum(extra$check == "suspect")
  extra <- extra[extra$check != "suspect"]   # no second copy to check against: a row that fails its own check is left out
  # An unmatched row of ours missing a party that AE's polls within 60 days do report: its Others holds that
  # party too, so Others is blanked rather than read as Others.
  n_oth_blanked <- 0L
  if (nrow(extra) && "OTH" %in% parties) for (p in setdiff(parties, c("OTH", "ALP", "LNP"))) {
    miss <- which(!is.finite(extra[[p]]))
    for (i in miss) {
      near <- abs(as.integer(ae$date - extra$date[i])) <= 60
      if (any(near) && mean(is.finite(ae[[p]][near])) >= 0.5 && is.finite(extra$OTH[i])) { extra$OTH[i] <- NA_real_; n_oth_blanked <- n_oth_blanked + 1L }
    }
  }
  if (nrow(extra)) {
    lab <- vapply(seq_len(nrow(extra)), function(i) {
      m <- which(ae$canon == extra$canon[i]); if (!length(m)) return(extra$firm_raw[i])
      ae$firm[m[which.min(abs(as.integer(ae$date[m] - extra$date[i])))]]
    }, "")
    add <- data.table::data.table(date = extra$date, firm = lab, tpp_published = extra$tpp_published)
    for (p in parties) add[[p]] <- extra[[p]]
    add$.prov <- ifelse(is.finite(extra$OTH) | !("OTH" %in% parties), "ours_only", "ours_only_oth_blank")
    add$.fill <- ""; add$.label_ae <- lab != extra$firm_raw; add$.origin <- extra$origin
    ae <- rbind(ae[, setdiff(names(ae), "canon"), with = FALSE], add, use.names = TRUE, fill = TRUE)
  } else ae <- ae[, setdiff(names(ae), "canon"), with = FALSE]
  data.table::setorderv(ae, "date")
  # origin: whose numbers the row carries (wiki, bludgertrack, both, or ae)
  prov <- data.table::data.table(date = ae$date, firm = ae$firm, source = ae$.prov, origin = ae$.origin,
                                 ae_filled = trimws(ae$.fill), label_from_ae = ae$.label_ae)
  ae <- ae[, setdiff(names(ae), c(".prov", ".fill", ".label_ae", ".origin")), with = FALSE]
  log <- list(region = region, ae_rows = sum(!used_a) + length(pair_a), ours = nrow(ours), matched = length(pair_o),
              ours_only = nrow(extra), ae_only = sum(!used_a), matched_differ_gt2 = sum(diff_big), differ = differ, bt = bt_log)
  if (bt_log[["bt"]] > 0) message(sprintf("PZ2 BludgerTrack [%s]: %d polls, %d also on Wikipedia (%d differ by > 1 point on Labor or the Coalition), %d BludgerTrack only",
                                          region, bt_log[["bt"]], bt_log[["both"]], bt_log[["differ_gt1"]], bt_log[["bt_only"]]))
  message(sprintf("PZ1 poll source layered [%s]: %d ours (%d matched to AE, %d ours only), %d AE only; %d matched polls differ by > 2 points on a major party (two-party check kept ours on %d, AE on %d); own check: %d swapped back, %d suspect (%d unmatched suspect dropped), %d without a two-party figure; %d unmatched rows had Others blanked (a party missing that nearby polls report)",
                  region, nrow(ours), length(pair_o), nrow(extra), sum(!used_a), sum(diff_big), sum(diff_big & use_ours), sum(diff_big & !use_ours),
                  sum(ours$check == "swapped"), sum(ours$check == "suspect"), n_suspect_dropped, sum(ours$check == "no_tpp"), n_oth_blanked))
  data.table::setattr(ae, "parties", parties)
  data.table::setattr(ae, "layer_log", log)
  data.table::setattr(ae, "provenance", prov)
  ae
}
