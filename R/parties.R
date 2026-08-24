# Party classification -------------------------------------------------------
#
# Election commissions name parties in full and inconsistently: "Australian
# Labor Party - Victorian Branch", "Labor SA", "The Nationals". The model works
# in classes, and which class a party lands in is a MODELLING decision, not
# string tidying -- whether Family First counts with the Coalition or as its
# own minor-right bloc changes measured preference flows by tens of points.
#
# So it lives in the package with tests rather than being repeated in each
# fetch script, where two copies would drift and nobody would notice.
#
# Independents are their own class. They are not "other": measured across 452
# Victorian exclusions they send 61.1% of preferences to Labor against
# minor-right's 35.4%, and the model's single OTH bucket averages the two.

#' Classify a party name into a modelling class
#'
#' @param name Character vector of party names as published. Empty or `NA`
#'   entries are treated as independents, which is how commissions record them.
#' @param code Optional character vector of party codes (e.g. `"ON"`, `"LP"`),
#'   used in preference to the name where supplied and recognised.
#' @return Character vector of classes: `ALP`, `LNP`, `GRN`, `ONP`,
#'   `OTH_RIGHT`, `IND` or `OTH`.
#' @export
classify_party <- function(name, code = NULL) {
  n <- tolower(trimws(ifelse(is.na(name), "", name)))
  cd <- if (is.null(code)) rep("", length(n)) else toupper(trimws(ifelse(is.na(code), "", code)))
  if (length(cd) != length(n)) stop("code must be the same length as name")

  out <- rep(NA_character_, length(n))
  set <- function(idx, cls) out[is.na(out) & idx] <<- cls

  # Codes first where they are unambiguous.
  set(cd %in% c("ALP", "ALP1"), "ALP")
  set(cd %in% c("LP", "LNP", "NP", "LNQ", "NAT", "NATS", "LIB"), "LNP")
  set(cd %in% c("GRN", "GVIC", "TG"), "GRN")
  set(cd %in% c("ON", "PHON", "ONP"), "ONP")
  # Western Australia publishes a CODE and no party name at all, so these two
  # arrive as the literal strings "IND" and "SFF". Both previously fell through
  # every name rule to OTH: 27 independents and the Shooters in 26 districts,
  # silently. A code is only usable here where it means the same thing in every
  # jurisdiction, which is why "CLP" above is deliberately excluded.
  set(cd == "IND", "IND")
  set(cd == "SFF", "OTH_RIGHT")

  # Centre Alliance / Nick Xenophon Team / SA-BEST function as a community
  # independent rather than a bloc party -- Mayo has returned Rebekha Sharkie
  # under this banner in 2016, 2019, 2022 and 2025, and it fits none of
  # ALP/LNP/GRN/ONP/OTH_RIGHT. Classed IND here for the SIMULATION only; the
  # party's own name is a separate, unhandled concern for display/reporting.
  set(grepl("centre alliance|nick xenophon|\\bnxt\\b|sa[- ]best", n), "IND")

  # The NT Coalition party is spelled three ways by the AEC across seven
  # elections -- "Country Liberals (NT)", "NT CLP" and "C.L.P." -- and only the
  # first contains the word "liberal". The other two fell through to OTH, so
  # Lingiari and Solomon recorded the Coalition's entire vote as "other" in
  # 2007, 2022 and 2025.
  #
  # The CODE cannot be used to fix this. "CLP" is the Country LIBERAL Party in
  # the Northern Territory and the Country LABOR Party in New South Wales --
  # opposite sides of politics under one acronym. So this matches on the name,
  # and it must come BEFORE the "labor" rule below, which would otherwise be
  # reached first by nothing here but would be by a future variant.
  set(grepl("country liberal", n), "LNP")
  set(n %in% c("nt clp", "c.l.p.", "clp"), "LNP")

  # "Labor DLP" is a different party from Labor and belongs on the right.
  # Two backslashes and not one: "\b" in an R STRING is the backspace
  # character, so this alternative matched a control code and never fired.
  set(grepl("democratic labour|labour dlp|\\bdlp\\b", n), "OTH_RIGHT")
  set(grepl("labor|labour", n), "ALP")
  # "Liberals For Climate" is a micro-party that ran against the Liberals in
  # two WA seats in 2021, and the "liberal" rule below would file it as LNP.
  # Same shape as the Liberal Democrats line that follows.
  set(grepl("liberals for climate", n), "OTH")
  # Liberal Democrats are not the Liberal Party; checked before "liberal".
  set(grepl("liberal democrat|libertarian", n), "OTH_RIGHT")
  set(grepl("liberal|national", n), "LNP")
  set(grepl("green", n), "GRN")
  set(grepl("one nation|hanson", n), "ONP")
  # "Palmer United Party" and "United Australia Party" are the same movement
  # under the same man, and only the second matched. Palmer United took 5.56%
  # of the 2013 federal vote and WON Fairfax, so one of the largest minor
  # parties in the corpus sat in OTH with a seat beside it. Word order was the
  # entire difference. "Rise Up Australia" is the same shape: an explicitly
  # Christian-nationalist party whose name contains none of the tokens below.
  set(grepl("palmer united|rise up australia", n), "OTH_RIGHT")
  set(grepl(paste0("family|freedom|christian|conservative|liberty|shooters|",
                   "fishers|farmers|united australia|katter|country|citizens|",
                   "trumpet|australia first|call to australia"), n), "OTH_RIGHT")
  set(!nzchar(n) | grepl("independent", n), "IND")
  out[is.na(out)] <- "OTH"
  out
}
