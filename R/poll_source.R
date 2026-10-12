# Our own poll source, layered over AE's file (AUSPOL_POLL_SOURCE = "layered"; Pete, 2026-10-12).
# docs/plans/prereg-own-poll-source-step2-2026-10-12.md. Off ("ae") until the deciding run ships it.
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
  v <- Sys.getenv("AUSPOL_POLL_SOURCE", "ae")
  if (!v %in% c("ae", "layered")) stop("AUSPOL_POLL_SOURCE must be \"ae\" or \"layered\", not ", v)
  v
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
  keep <- w$row_type == "poll" & w$table_type == "primary" & w$region == reg &
    !grepl("Sub-national|Subpopulation|Electorate|seat|Hypothetical|Exit|By gender|By age|By generation|By language|By country",
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

#' Layer our polls over AE's for one region (see the file header)
#'
#' @param ae AE's polls as [load_polls()] reads them (before layering).
#' @param region Poll region.
#' @param path Path to `statewide_polls_wiki.csv`; `AUSPOL_POLL_WIKI` or the scrape folder by default.
#' @param window Days apart two midpoints may be and still be the same poll.
#' @return `ae`'s shape with our numbers on matched polls and our unmatched polls added; attribute `layer_log`.
#' @export
poll_layer <- function(ae, region, path = NULL, window = 4L) {
  if (is.null(path)) path <- Sys.getenv("AUSPOL_POLL_WIKI", file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "statewide_polls_wiki.csv"))
  if (!file.exists(path)) stop("AUSPOL_POLL_SOURCE=layered needs ", path, " (scripts/fetch_statewide_poll_samples.R; CI sets AUSPOL_POLL_WIKI)")
  alias_f <- file.path(dirname(path), "firm_alias.csv")
  alias <- if (file.exists(alias_f)) data.table::fread(alias_f, showProgress = FALSE) else
    data.table::fread(file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "firm_alias.csv"), showProgress = FALSE)
  parties <- attr(ae, "parties")
  ours <- wiki_polls(region, parties, path)
  ae <- data.table::copy(ae)
  ae$canon <- .ps_canon(ae$firm, alias); ours$canon <- .ps_canon(ours$firm_raw, alias)
  # one-to-one matching, closest midpoints first
  cand <- ours[, list(oi = .I, canon, d_o = date)][ae[, list(ai = .I, canon, d_a = date)], on = "canon", allow.cartesian = TRUE, nomatch = NULL]
  cand <- cand[abs(as.integer(cand$d_o - cand$d_a)) <= window]
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
  # A party our row does not report (the page folded it into Others: the wa2017 table has no One Nation column)
  # keeps AE's figure, and our Others gives that share back. Without this, layering blanked One Nation on the
  # final WA 2017 polls and wa2017 seat log loss rose 0.086 (deciding run, 2026-10-12).
  named_p <- setdiff(parties, "OTH")
  for (p in named_p) {
    fill <- !is.finite(ours[[p]][po]) & is.finite(ae[[p]][pa])
    if (any(fill) && "OTH" %in% parties) ours$OTH[po[fill]] <- pmax(0, ours$OTH[po[fill]] - ae[[p]][pa[fill]])
    ours[[p]][po[fill]] <- ae[[p]][pa[fill]]
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
    ae <- rbind(ae[, setdiff(names(ae), "canon"), with = FALSE], add, use.names = TRUE, fill = TRUE)
  } else ae <- ae[, setdiff(names(ae), "canon"), with = FALSE]
  data.table::setorderv(ae, "date")
  log <- list(region = region, ae_rows = sum(!used_a) + length(pair_a), ours = nrow(ours), matched = length(pair_o),
              ours_only = nrow(extra), ae_only = sum(!used_a), matched_differ_gt2 = sum(diff_big), differ = differ)
  message(sprintf("PZ1 poll source layered [%s]: %d ours (%d matched to AE, %d ours only), %d AE only; %d matched polls differ by > 2 points on a major party (two-party check kept ours on %d, AE on %d); own check: %d swapped back, %d suspect (%d unmatched suspect dropped), %d without a two-party figure; %d unmatched rows had Others blanked (a party missing that nearby polls report)",
                  region, nrow(ours), length(pair_o), nrow(extra), sum(!used_a), sum(diff_big), sum(diff_big & use_ours), sum(diff_big & !use_ours),
                  sum(ours$check == "swapped"), sum(ours$check == "suspect"), n_suspect_dropped, sum(ours$check == "no_tpp"), n_oth_blanked))
  data.table::setattr(ae, "parties", parties)
  data.table::setattr(ae, "layer_log", log)
  ae
}
