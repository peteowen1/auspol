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
  set(cd %in% c("LP", "LNP", "NP", "LNQ", "NAT", "LIB"), "LNP")
  set(cd %in% c("GRN", "GVIC", "TG"), "GRN")
  set(cd %in% c("ON", "PHON", "ONP"), "ONP")

  # "Labor DLP" is a different party from Labor and belongs on the right.
  set(grepl("democratic labour|labour dlp|\bdlp\b", n), "OTH_RIGHT")
  set(grepl("labor|labour", n), "ALP")
  # Liberal Democrats are not the Liberal Party; checked before "liberal".
  set(grepl("liberal democrat|libertarian", n), "OTH_RIGHT")
  set(grepl("liberal|national", n), "LNP")
  set(grepl("green", n), "GRN")
  set(grepl("one nation|hanson", n), "ONP")
  set(grepl(paste0("family|freedom|christian|conservative|liberty|shooters|",
                   "fishers|farmers|united australia|katter|country|citizens|",
                   "trumpet|australia first"), n), "OTH_RIGHT")
  set(!nzchar(n) | grepl("independent", n), "IND")
  out[is.na(out)] <- "OTH"
  out
}
