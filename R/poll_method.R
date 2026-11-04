# How each statewide poll was taken (arm MOD of docs/plans/prereg-poll-lean-2026-11-02.md; Pete, 1 Nov: "we 100%
# should be treating different polls differently based on the poll type and company and how old it is").
#
# Three sources, in this order of precedence, each counted per poll by poll_method_class():
#   1. AE's own firm label, where AE split a firm by method: "F2F Morgan" in person, "Morgan Phone" phone,
#      "SMS Morgan" SMS, "Morgan multi-mode" mixed, "Newspoll" (to 2015) phone. Data, not inference.
#   2. Our Wikipedia scrape's method labels (`mode_raw`, `x_Method_`). They exist only in the FEDERAL tables, in
#      2016 and from 2019 (0% of state rows: prereg step 0), so the method is a property of the FIRM AND ERA,
#      applied to every poll of that firm in every region, AE-only rows included. Each poll takes the method of
#      the NEAREST labelled poll of its firm in time, so a switch falls at the midpoint between two labels, and a
#      one-off label (Resolve's single 2022 phone-and-online poll) moves only the polls nearest it. The earliest
#      label therefore extends back to the firm's first poll and the latest forward: an assumption, counted as
#      "extended" (nearest label more than 90 days away), never silently.
#   3. POLL_METHOD_KNOWN: three large firms with no label anywhere, set by hand from general knowledge and NOT
#      checked against a document (Nielsen phone, Morning Consult online, Westpoll phone). Counted separately.
#   Else "unknown".
# Classes (prereg list; robopoll and MRP have no label of their own in the data, so IVR counts as phone):
# phone, online, sms, inperson, mixed (two or more modes), unknown. The method is known at publication, so it is
# not leakage; the lean is learned time-forward (poll_lean_table()).

POLL_METHOD_AE <- c("F2F Morgan" = "inperson", "Morgan Phone" = "phone", "SMS Morgan" = "sms",
                    "Morgan multi-mode" = "mixed", "Newspoll" = "phone")                       # arm MOD, source 1
POLL_METHOD_KNOWN <- c(nielsen = "phone", morningconsult = "online", westpoll = "phone")     # arm MOD, source 3, unchecked

#' Every labelled poll's method, from the Wikipedia method labels
#'
#' @param path Path to `statewide_polls_wiki.csv`; by default the copy the trend reads ([poll_wiki_path()]).
#' @return data.table `fam` (firm family, firm_alias.csv), `method`, `d` (fieldwork end), sorted by firm and date.
#' @export
poll_method_eras <- function(path = poll_wiki_path()) {
  w <- data.table::fread(path, showProgress = FALSE, encoding = "UTF-8",
                         select = c("row_type", "table_type", "fieldwork_end", "firm", "firm_raw", "mode_raw", "x_Method_"))
  w <- w[w$row_type == "poll" & w$table_type == "primary"]
  alias <- poll_wiki_alias(path)
  fam <- .ps_family(.ps_canon(ifelse(is.na(w$firm) | w$firm == "", w$firm_raw, w$firm), alias))
  txt <- function(x) { x <- trimws(as.character(x)); x[is.na(x)] <- ""; x }
  cls <- .poll_method_label(tolower(trimws(paste(txt(w$mode_raw), txt(w$x_Method_)))))
  d <- as.Date(substr(as.character(w$fieldwork_end), 1, 10))
  ok <- !is.na(cls) & is.finite(d) & !is.na(fam) & nzchar(fam)
  x <- data.table::data.table(fam = fam[ok], method = cls[ok], d = d[ok])
  data.table::setorderv(x, c("fam", "d"))
  x
}

# Free-text method label -> class; NA for no label ("", an em dash, "?", a stray sample size).
#' @noRd
.poll_method_label <- function(m) {
  online <- grepl("online", m); phone <- grepl("telephone|landline|cati|ivr|mobile|phone", m)
  sms <- grepl("sms", m); person <- grepl("in person|face", m)
  k <- online + phone + sms + person
  out <- rep(NA_character_, length(m))
  out[k >= 2L] <- "mixed"
  out[k == 1L & online] <- "online"; out[k == 1L & phone] <- "phone"
  out[k == 1L & sms] <- "sms"; out[k == 1L & person] <- "inperson"
  out
}

#' Method class of every poll the trend fits
#'
#' @param region Poll region (unused for the lookup, which is by firm and date; kept for the arm's `group_by` shape).
#' @param polls From [load_polls()].
#' @param eras From [poll_method_eras()].
#' @param alias firm_alias.csv as a table.
#' @return Character vector, one class per row of `polls`; attribute `source`, a named count of polls by where
#'   their method came from (`ae_label`, `wiki_near` (a label of the firm within 90 days), `wiki_extended`,
#'   `known_unchecked`, `unknown`).
#' @export
poll_method_class <- function(region, polls, eras = poll_method_eras(), alias = poll_wiki_alias(poll_wiki_path())) {
  fam <- .ps_family(.ps_canon(polls$firm, alias))
  pd <- as.integer(polls$date)
  out <- rep("unknown", nrow(polls)); src <- rep("unknown", nrow(polls))
  ae <- unname(POLL_METHOD_AE[polls$firm])
  hit <- !is.na(ae)
  out[hit] <- ae[hit]; src[hit] <- "ae_label"
  e_fam <- eras$fam; e_d <- as.integer(eras$d); e_m <- eras$method
  for (f in unique(fam[!is.na(fam) & !hit])) {
    is_f <- which(e_fam == f)
    if (!length(is_f)) next
    for (i in which(fam == f & !hit & is.finite(pd))) {
      gap <- abs(e_d[is_f] - pd[i])
      j <- which.min(gap)
      out[i] <- e_m[is_f][j]
      src[i] <- if (gap[j] <= 90L) "wiki_near" else "wiki_extended"
    }
  }
  kn <- unname(POLL_METHOD_KNOWN[fam])
  hk <- src == "unknown" & !is.na(kn)
  out[hk] <- kn[hk]; src[hk] <- "known_unchecked"
  lv <- c("ae_label", "wiki_near", "wiki_extended", "known_unchecked", "unknown")
  structure(out, source = setNames(as.integer(table(factor(src, levels = lv))), lv))
}
