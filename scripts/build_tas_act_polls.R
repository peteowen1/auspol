# Tasmanian and ACT statewide voting-intention polls, in the anchor's poll-file
# shape, so load_polls("tas") and load_polls("act") work (same pattern as
# scripts/build_nt_polls.R; load_polls() reads
# external/reference/anchor-supplement/poll-data-<region>.csv when the anchor has
# no file for the region).
#
# TASMANIA comes from our Wikipedia scrape
# (external/reference/polls/statewide-samples/statewide_polls_wiki.csv, built by
# scripts/fetch_statewide_poll_samples.R). The election articles for 2010-2025
# carry EMRS quarterly tables (plus ReachTEL, Morgan, MediaReach, uComms,
# Redbridge, YouGov, DemosAU, Wolf & Smith). Adjacent articles repeat the polls of
# the overlap (the 2014 article lists Feb 2010, the 2018 article lists Feb 2014,
# ...), so rows are de-duplicated on date + firm + first preferences.
# Kept: table_type "primary", row_type "poll", sections that are the statewide
# "Voting intention" / "Polling" table (not Bass/Braddon/Clark/Franklin/Lyons).
#
# Column naming differs by article (Lib/LIB/Liberal, Labor/ALP, Grn/GRN/Greens,
# Undecided/UND, and PUP/IND/JLN/ONP/NAT/SFF/Ind/Other for the rest). Mapping:
# ALP, LNP (the Liberals, as classify_party() files them), GRN, undecided
# (divided out), and EVERYTHING ELSE -> OTH, which includes the Jacqui Lambie
# Network, Palmer United, One Nation, independents and Shooters (classify_party()
# has no separate class for them in the forecast's four-way split; the Hare-Clark
# path reads OTH). The 2025 table also carries a two-party-preferred column
# (tpp_LIB), which is NOT a first preference and is excluded from OTH.
#
# ACT: see the ACT block. Emits TA* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

src <- file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "statewide_polls_wiki.csv")
W <- fread(src, showProgress = FALSE, colClasses = "character")
# Take the number BEFORE the percent sign: a footnote marker is glued on after it
# ("5%1" is 5%, not 51).
pct <- function(x) {
  out <- rep(NA_real_, length(x)); has <- grepl("^[0-9]+([.][0-9]+)?%", x)
  out[has] <- as.numeric(sub("%.*$", "", x[has])); out }
col1 <- function(D, cols) {                       # first non-NA across alias columns
  out <- rep(NA_real_, nrow(D))
  for (k in intersect(cols, names(D))) { v <- pct(D[[k]]); out <- ifelse(is.na(out), v, out) }
  out
}
colsum <- function(D, cols) {
  cols <- intersect(cols, names(D))
  if (!length(cols)) return(rep(0, nrow(D)))
  rowSums(sapply(cols, function(k) { v <- pct(D[[k]]); ifelse(is.finite(v), v, 0) }))
}

build_region <- function(D, label) {
  alp <- col1(D, c("pv_ALP", "pv_Labor")); lnp <- col1(D, c("pv_LIB", "pv_Lib", "pv_Liberal", "pv_LNP"))
  grn <- col1(D, c("pv_GRN", "pv_Grn", "pv_Greens", "pv_Green"))
  und <- col1(D, c("pv_UND", "pv_Undecided")); und[!is.finite(und)] <- 0
  tpp <- col1(D, c("tpp_ALP", "tpp_Labor"))
  named <- c("pv_ALP", "pv_Labor", "pv_LIB", "pv_Lib", "pv_Liberal", "pv_LNP", "pv_GRN", "pv_Grn", "pv_Greens", "pv_Green",
             "pv_UND", "pv_Undecided")
  rest <- setdiff(grep("^pv_", names(D), value = TRUE), named)
  oth <- colsum(D, rest)
  tot <- ifelse(is.finite(alp), alp, 0) + ifelse(is.finite(lnp), lnp, 0) + ifelse(is.finite(grn), grn, 0) + oth
  # undecided divided out: the published undecided share where given, otherwise
  # whatever the reported primaries leave short of 100
  scale <- ifelse(und > 0, 100 / (100 - und), ifelse(tot > 0, 100 / tot, 1))
  for (i in which(is.finite(alp) & abs(scale - 1) > 0.005))
    cat(sprintf("TA0u %s %s %s: primaries rescaled x%.3f (undecided %s)\n", label, D$firm_raw[i], D$date_raw[i], scale[i],
                if (und[i] > 0) sprintf("%.1f published", und[i]) else sprintf("%.1f implied by a %.1f total", 100 - tot[i], tot[i])))
  # A row that does not add up is a transcription error in the source table
  # (EMRS May 2009 lists 33 + 27 + 3 + 24 undecided + 27 = 114): excluded, listed.
  # With undecided published, primaries + undecided must be 95-105; without, the
  # primaries alone must be 75-105 (EMRS reports up to ~25% undecided).
  badsum <- is.finite(alp) & ifelse(und > 0, abs(tot + und - 100) > 5, tot < 75 | tot > 105)
  for (i in which(badsum))
    cat(sprintf("TA0x %s %s %s: EXCLUDED, primaries %.0f + undecided %.0f do not add up\n", label, D$firm_raw[i], D$date_raw[i], tot[i], und[i]))
  alp[badsum] <- NA_real_
  fs <- as.Date(D$fieldwork_start); fe <- as.Date(D$fieldwork_end)
  mid <- as.Date(as.integer(fs) + (as.integer(fe) - as.integer(fs)) %/% 2L, origin = "1970-01-01")
  firm <- ifelse(nzchar(D$firm), D$firm, "Unnamed")
  has_fp <- is.finite(alp) & is.finite(lnp)
  data.table(MidDate = format(mid), Firm = firm, Brand = "",
             `@TPP` = tpp,
             `LNP FP` = ifelse(has_fp, round(lnp * scale, 2), NA),
             `ALP FP` = ifelse(has_fp, round(alp * scale, 2), NA),
             `GRN FP` = ifelse(has_fp & is.finite(grn), round(grn * scale, 2), NA),
             `OTH FP` = ifelse(has_fp, round(oth * scale, 2), NA),
             Comments = sprintf("%s; Wikipedia %s (%s)", D$election, D$page_key, D$date_raw))
}

# ---- Tasmania -------------------------------------------------------------
T <- W[W$region == "tas" & W$table_type == "primary" & W$row_type == "poll" &
       !grepl("^(Bass|Braddon|Clark|Franklin|Lyons)", W$section)]
cat(sprintf("TA0  Tasmania: %d candidate poll rows from the scrape\n", nrow(T)))
ptas <- build_region(T, "tas")
bad <- is.na(ptas$MidDate)
if (any(bad)) cat(sprintf("TA0d dropped, no fieldwork date: %s\n", paste(T$firm_raw[bad], T$date_raw[bad], collapse = "; ")))
ptas <- ptas[!bad & !is.na(`ALP FP`)]
ptas[, key := paste(MidDate, Firm, `ALP FP`, `LNP FP`)]
nd <- nrow(ptas); ptas <- ptas[!duplicated(key)]; ptas[, key := NULL]
cat(sprintf("TA0e %d duplicates (same poll in two articles) removed\n", nd - nrow(ptas)))
setorder(ptas, MidDate)

# ---- ACT ------------------------------------------------------------------
# Wikipedia's ACT articles carry almost no polling (one 2012 paragraph, two 2020
# rows); the hand-keyed file below holds every ACT statewide poll we could source,
# with its source URL. It is read here if present.
act_f <- file.path(pkg_root(), "external", "reference", "polls", "act-polls-handkeyed.csv")
pact <- NULL
if (file.exists(act_f)) {
  A <- fread(act_f, colClasses = "character")
  pact <- data.table(MidDate = A$date, Firm = A$firm, Brand = "", `@TPP` = NA_real_,
                     `LNP FP` = pct(A$lib), `ALP FP` = pct(A$alp), `GRN FP` = pct(A$grn), `OTH FP` = pct(A$oth),
                     Comments = sprintf("%s; %s", A$election, A$source))
  tot <- rowSums(as.matrix(pact[, c("LNP FP", "ALP FP", "GRN FP", "OTH FP"), with = FALSE]), na.rm = TRUE)
  bad <- abs(tot - 100) > 1.5
  if (any(bad)) cat(sprintf("TA0a ACT poll %s %s sums to %.1f, rescaled to 100\n", A$firm[bad], A$date[bad], tot[bad]))
  for (k in c("LNP FP", "ALP FP", "GRN FP", "OTH FP")) pact[, (k) := round(get(k) * 100 / tot, 2)]
  setorder(pact, MidDate)
}

edf <- fread(file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "election_dates.csv"))
ED <- setNames(as.Date(edf[[3]]), edf[[4]])
out_dir <- file.path(pkg_root(), "external", "reference", "anchor-supplement")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
for (r in c("tas", "act")) {
  P <- if (r == "tas") ptas else pact
  if (is.null(P)) { cat(sprintf("TA1  %s: no polls, no file written\n", r)); next }
  f <- file.path(out_dir, sprintf("poll-data-%s.csv", r))
  fwrite(P, f, na = "#N/A")                       # the anchor's own NA token
  cat(sprintf("TA1  wrote %s: %d polls\n", f, nrow(P)))
  yrs <- if (r == "tas") c(2006, 2010, 2014, 2018, 2021, 2024, 2025) else c(2008, 2012, 2016, 2020, 2024)
  ed <- ED[sprintf("%s%d", r, yrs)]
  for (k in 2:length(ed)) {
    inn <- as.Date(P$MidDate) > ed[k - 1L] & as.Date(P$MidDate) < ed[k]
    cat(sprintf("TA2  %s cycle (%s to %s): %d polls; by firm: %s\n", names(ed)[k], ed[k - 1L], ed[k], sum(inn),
                paste(sprintf("%s %d", names(table(P$Firm[inn])), as.integer(table(P$Firm[inn]))), collapse = ", ")))
  }
}
print(ptas, nrows = 200)
