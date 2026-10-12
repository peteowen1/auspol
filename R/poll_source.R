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
  data.table::setorderv(cand[, gap := abs(as.integer(d_o - d_a))], "gap")
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
  # matched: our numbers under AE's label and date
  for (p in parties) ae[[p]][pair_a] <- ours[[p]][pair_o]
  # unmatched ours: label of the same firm's nearest AE poll, else our own text
  extra <- ours[!used_o]
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
  message(sprintf("PS1 poll source layered [%s]: %d ours (%d matched to AE, %d ours only), %d AE only; %d matched polls differ by > 2 points on a major party",
                  region, nrow(ours), length(pair_o), nrow(extra), sum(!used_a), sum(diff_big)))
  data.table::setattr(ae, "parties", parties)
  data.table::setattr(ae, "layer_log", log)
  ae
}
