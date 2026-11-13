# Who paid for each statewide poll (arm SPN of docs/plans/prereg-poll-lean-2026-11-02.md; Pete, 1 Nov: "we 100%
# should be treating different polls differently based on the poll type and company and how old it is").
#
# The poll table the trend fits (load_polls()) carries date, firm and shares only. The sponsor is in our Wikipedia
# scrape (external/reference/polls/statewide-samples/statewide_polls_wiki.csv: client, client_raw, client_fn), so
# each fitted poll is matched back to its Wikipedia row: same region, same firm (firm_alias.csv), fieldwork
# midpoint within 4 days, Labor primary within 1.5 points. Three classes, as registered:
#   party   commissioned by a party or an advocacy group (Liberal Party, Australia Institute, Climate Council, ...)
#   media   a listed media client, or no client listed on a firm that runs a regular media series (3+ of its
#           Wikipedia polls name a media client)
#   unknown everything else, including every fitted poll with no Wikipedia row (AE-only and pre-Wikipedia polls)
# The class is a label known when the poll is published, not an outcome, so labelling with the firm's whole
# Wikipedia record is not leakage; the lean itself is still learned time-forward (poll_lean_table()).

POLL_SPONSOR_ADVOCACY <- paste0("party|labor|liberal|greens|nationals|institute|council|threads|fair go|lobby|",
                                "group|union|amplify|blueprint|members|campaign|alliance|foundation")   # arm SPN

#' Sponsor class of every poll the trend fits
#'
#' @param region Poll region.
#' @param polls From [load_polls()] for that region.
#' @param path Path to `statewide_polls_wiki.csv`; by default the copy the trend reads ([poll_wiki_path()]).
#' @return Character vector, one of `"party"`, `"media"`, `"unknown"` per row of `polls`; attribute
#'   `matched` (rows matched to a Wikipedia row) and attribute `sponsor` (the matched row's client text, `""` when
#'   unmatched).
#' @export
poll_sponsor_class <- function(region, polls, path = poll_wiki_path()) {
  lab <- .sponsor_wiki_labels(path)
  reg <- region
  is_reg <- lab$region == reg
  wl <- lab[is_reg]
  out <- rep("unknown", nrow(polls))
  spn <- rep("", nrow(polls))   # the matched Wikipedia row's client text (arm PPC reads it for the sponsor's side)
  matched <- 0L
  if (nrow(wl) && nrow(polls)) {
    alias <- poll_wiki_alias(path)
    p_fam <- .ps_family(.ps_canon(polls$firm, alias))
    p_date <- polls$date; p_alp <- if ("ALP" %in% names(polls)) polls$ALP else rep(NA_real_, nrow(polls))
    w_fam <- wl$fam; w_mid <- wl$mid; w_alp <- wl$alp; w_cls <- wl$cls
    for (i in seq_len(nrow(polls))) {
      if (is.na(p_fam[i]) || !is.finite(p_date[i])) next
      dd <- abs(as.integer(w_mid - p_date[i]))
      hit <- which(w_fam == p_fam[i] & is.finite(dd) & dd <= 4L &
                     (!is.finite(w_alp) | !is.finite(p_alp[i]) | abs(w_alp - p_alp[i]) <= 1.5))
      if (!length(hit)) next
      j <- hit[which.min(dd[hit])]
      out[i] <- w_cls[j]; spn[i] <- wl$sponsor[j]
      matched <- matched + 1L
    }
  }
  structure(out, matched = matched, sponsor = spn)
}

.sponsor_cache <- new.env(parent = emptyenv())

# One row per Wikipedia statewide primary-vote poll: region, firm family, fieldwork midpoint, Labor primary, class.
#' @noRd
.sponsor_wiki_labels <- function(path) {
  if (!is.null(.sponsor_cache[[path]])) return(.sponsor_cache[[path]])
  if (!file.exists(path)) stop("poll_sponsor_class(): ", path, " not found (scripts/fetch_statewide_poll_samples.R)")
  w <- data.table::fread(path, showProgress = FALSE, encoding = "UTF-8",
                         select = c("region", "row_type", "table_type", "fieldwork_start", "fieldwork_end",
                                    "firm", "firm_raw", "client", "client_raw", "client_fn", "alp_fp"))
  w <- w[w$row_type == "poll" & w$table_type == "primary"]
  alias <- poll_wiki_alias(path)
  fs <- as.Date(substr(as.character(w$fieldwork_start), 1, 10)); fe <- as.Date(substr(as.character(w$fieldwork_end), 1, 10))
  mid <- as.Date(ifelse(is.finite(fs) & is.finite(fe) & fs <= fe, as.integer(fs) + (as.integer(fe) - as.integer(fs)) %/% 2L,
                        as.integer(fe)), origin = "1970-01-01")
  txt <- function(x) { x <- trimws(as.character(x)); x[is.na(x) | x %in% c("", "\u2014", "-", "N/A", "n/a")] <- ""; x }
  sp <- trimws(paste(txt(w$client), txt(w$client_raw), txt(w$client_fn)))
  fam <- .ps_family(.ps_canon(ifelse(is.na(w$firm) | w$firm == "", w$firm_raw, w$firm), alias))
  cls <- ifelse(sp == "", "none", ifelse(grepl(POLL_SPONSOR_ADVOCACY, sp, ignore.case = TRUE), "party", "media"))
  # A firm with a regular media series: 3+ Wikipedia polls naming a media client. Its unlabelled polls are media.
  n_media <- table(fam[cls == "media"])
  series <- names(n_media)[n_media >= 3L]
  cls[cls == "none"] <- ifelse(fam[cls == "none"] %in% series, "media", "unknown")
  lab <- data.table::data.table(region = w$region, fam = fam, mid = mid,
                                alp = suppressWarnings(as.numeric(w$alp_fp)), cls = cls, sponsor = sp)
  lab <- lab[is.finite(lab$mid)]
  .sponsor_cache[[path]] <- lab
  lab
}
