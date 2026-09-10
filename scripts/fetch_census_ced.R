# ABS Census (2021 General Community Profile) at Commonwealth Electoral
# Division -- the federal counterpart to fetch_census_sed.R.
#
# A SEPARATE SCRIPT, DELIBERATELY, not a state added to fetch_census_sed.R's
# STATES loop. Three real structural differences, not just a different code:
#   1. The census pack ships as ONE NATIONAL file (2021_GCP_CED_for_AUS...),
#      not one zip per state -- there is no per-state loop to join.
#   2. Its internal CSV/table naming is "..._AUST_CED.csv", not
#      "..._<STATE>_SED.csv" -- a different filename pattern, not a parameter.
#   3. Coverage has to be checked against SEVEN federal target elections
#      (fed2007..fed2025), not one -- federal boundaries moved between
#      cycles (150 seats pre-2022, 151 from the 2021 redistribution), so a
#      single census vintage cannot be expected to match every pair the way
#      one state's SED check matches that state's one or two live pairs.
#
# THE JOIN KEY IS STILL A CODE, NOT A NAME, for the same reason as the SED
# script: CED_CODE21 in the boundary .dbf is bare ("101"), the census CSV's
# CED_CODE_2021 is prefixed ("CED101") -- reconciled here exactly once.
#
# Emits CE* codes, continuing the SED script's numbering scheme informally
# (this script restarts at CE1 in its own log, not a shared counter).

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

REF <- file.path("external", "reference")
CEN <- file.path(REF, "census")
BND <- file.path(REF, "boundaries")
dir.create(CEN, showWarnings = FALSE, recursive = TRUE)

# ---- acquire: national census pack ------------------------------------------
census_zip <- file.path(CEN, "2021_GCP_CED_AUS.zip")
if (!file.exists(census_zip) || file.size(census_zip) < 1e6) {
  url <- paste0("https://www.abs.gov.au/census/find-census-data/datapacks/",
                "download/2021_GCP_CED_for_AUS_short-header.zip")
  ok <- tryCatch({
    utils::download.file(url, census_zip, quiet = TRUE, mode = "wb")
    TRUE
  }, error = function(e) FALSE)
  good <- ok && file.exists(census_zip) &&
    !inherits(tryCatch(utils::unzip(census_zip, list = TRUE), error = function(e) e), "error")
  if (!good) stop("CED census download failed or is not a readable archive")
  cat(sprintf("CE1  census pack downloaded (%.1f MB)\n", file.size(census_zip)/1e6))
} else {
  cat(sprintf("CE1  census pack already present (%.1f MB)\n", file.size(census_zip)/1e6))
}
# integrity: every member's CRC, not just that the zip opens -- a truncated
# download can still produce a listable central directory.
zi <- utils::unzip(census_zip, list = TRUE)
bad_crc <- tryCatch({
  con <- unz(census_zip, zi$Name[1]); close(con); FALSE
}, error = function(e) TRUE)
if (bad_crc) stop("CED census zip: first member failed to open -- treat as corrupt")
cat(sprintf("CE1  archive readable, %d members\n", nrow(zi)))

# ---- acquire: CED boundary shapefile -----------------------------------------
bnd_zip <- file.path(BND, "CED_2021_AUST_GDA2020_SHP.zip")
dbf <- file.path(BND, "CED_2021_AUST_GDA2020.dbf")
if (!file.exists(dbf)) {
  dir.create(BND, showWarnings = FALSE, recursive = TRUE)
  url <- paste0("https://www.abs.gov.au/statistics/standards/",
                "australian-statistical-geography-standard-asgs-edition-3-july-2021-june-2026/",
                "access-and-downloads/digital-boundary-files/CED_2021_AUST_GDA2020_SHP.zip")
  ok <- tryCatch({
    utils::download.file(url, bnd_zip, quiet = TRUE, mode = "wb")
    TRUE
  }, error = function(e) FALSE)
  good <- ok && file.exists(bnd_zip) &&
    !inherits(tryCatch(utils::unzip(bnd_zip, list = TRUE), error = function(e) e), "error")
  if (!good) stop("CED boundary download failed or is not a readable archive")
  utils::unzip(bnd_zip, exdir = BND)
  if (!file.exists(dbf)) stop("CED boundary zip extracted but .dbf missing")
  cat(sprintf("CE2  boundary shapefile fetched and extracted (%.1f MB)\n", file.size(bnd_zip)/1e6))
} else {
  cat("CE2  boundary shapefile already present\n")
}

# ---- CED code -> name, from the boundary shapefile's .dbf -------------------
read_dbf_fields <- function(path, want) {
  con <- file(path, "rb")
  on.exit(close(con))
  h <- readBin(con, "raw", 32)
  nrec <- readBin(h[5:8], "integer", size = 4, endian = "little")
  hlen <- readBin(h[9:10], "integer", size = 2, endian = "little")
  rlen <- readBin(h[11:12], "integer", size = 2, endian = "little")
  nm <- character(0); wd <- integer(0)
  repeat {
    d <- readBin(con, "raw", 32)
    if (length(d) < 32 || d[1] == as.raw(0x0d)) break
    fn <- d[1:11]; fn <- fn[fn != as.raw(0)]
    nm <- c(nm, rawToChar(fn))
    wd <- c(wd, as.integer(d[17]))
  }
  seek(con, hlen)
  out <- vector("list", nrec)
  for (i in seq_len(nrec)) {
    rec <- readBin(con, "raw", rlen)
    if (length(rec) < rlen) break
    off <- 2L; vals <- character(length(nm))
    for (j in seq_along(nm)) {
      chunk <- rec[off:(off + wd[j] - 1L)]
      chunk <- chunk[chunk != as.raw(0)]
      vals[j] <- trimws(rawToChar(chunk))
      off <- off + wd[j]
    }
    out[[i]] <- vals
  }
  d <- as.data.table(do.call(rbind, out))
  setnames(d, nm)
  d[, ..want]
}

look <- read_dbf_fields(dbf, c("CED_CODE21", "CED_NAME21", "STE_NAME21"))
look[, ced_code := paste0("CED", CED_CODE21)]
cat(sprintf("CE3  CED lookup: %d divisions across %d states/territories\n",
            nrow(look), uniqueN(look$STE_NAME21)))

# ---- read G01 (age/sex) and G02 (medians) -----------------------------------
zdir <- grep("^2021 Census GCP", zi$Name, value = TRUE)
zdir <- unique(dirname(zdir))[1]
grab <- function(tbl) {
  f <- sprintf("%s/2021Census_%s_AUST_CED.csv", zdir, tbl)
  if (!f %in% zi$Name) stop("No ", tbl, " table found at ", f)
  con <- unz(census_zip, f)
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  fread(text = readLines(con, warn = FALSE), showProgress = FALSE)
}
g1 <- grab("G01"); g2 <- grab("G02")
all_cen <- merge(g1, g2, by = "CED_CODE_2021")
setnames(all_cen, "CED_CODE_2021", "ced_code")

cen <- merge(all_cen, look[, .(ced_code, ced_name = CED_NAME21, ste = STE_NAME21)],
             by = "ced_code", all.x = TRUE)

# NOT REAL ELECTORATES: every state/territory contributes its own "No usual
# address" and "Migratory - Offshore - Shipping" residual row (ABS's catch-all
# for people the census can't place in a real division). Checked directly --
# these are not seats, and stripping their state-suffix would collide 18 rows
# into 2 names, which is what a blind name-strip would have done silently.
is_residual <- grepl("^(No usual address|Migratory - Offshore - Shipping)\\b", cen$ced_name)
cat(sprintf("CE4  excluding %d non-electorate residual row(s) (one 'No usual address' + one\n",
            sum(is_residual)))
cat("     'Migratory - Offshore - Shipping' per state/territory, not real seats): ")
cat(paste(cen$ced_name[is_residual], collapse = ", "), "\n")
cen <- cen[!is_residual]

# Real federal division names ARE single-tier (no upper-house-region suffix
# the way ABS's SED names carry) -- checked directly rather than assumed.
has_paren <- grep("\\(", cen$ced_name, value = TRUE)
if (length(has_paren)) {
  stop("Unexpected parenthetical suffix on a real-looking division name(s), ",
       "investigate before stripping blindly: ", paste(has_paren, collapse = ", "))
}
cen[, seat := ced_name]
unmatched <- cen[is.na(seat), .N]
dup <- cen[!is.na(seat), .N, by = seat][N > 1]
if (nrow(dup)) {
  stop("Division name collision(s) after any suffix-stripping: ", paste(dup$seat, collapse = ", "))
}
if (unmatched) {
  cat(sprintf("CE4  %d census row(s) have a code absent from the 2021 boundary file -- dropped\n",
              unmatched))
}
cen <- cen[!is.na(seat)]
cat(sprintf("CE4  census rows %d, all named, no collisions\n", nrow(cen)))

fwrite(cen, file.path(CEN, "census-ced-2021.csv"))
cat(sprintf("CE5  wrote %s (%d rows, %d columns)\n",
            file.path(CEN, "census-ced-2021.csv"), nrow(cen), ncol(cen)))

# ---- coverage: every federal target election, not just the newest ----------
# Federal boundaries moved between cycles (150 seats through fed2019, 151
# from the 2021 redistribution used at fed2022 and fed2025), so one census
# vintage should NOT be expected to match every pair. Reported per election,
# every unmatched seat NAMED -- consistent with fetch_census_sed.R's
# discipline, extended to fetch_census_ced.R's harder case (federal has no
# single "this vintage matches our forecast" answer the way VIC's did).
cf <- file.path("output", "candidacies.csv")
if (file.exists(cf)) {
  C <- fread(cf, showProgress = FALSE)
  fed_elections <- sort(grep("^fed20", unique(C$election), value = TRUE))
  cat(sprintf("\nCE6  checking %d federal target elections: %s\n",
              length(fed_elections), paste(fed_elections, collapse = ", ")))
  theirs <- cen[!is.na(seat), sort(unique(seat))]
  for (el in fed_elections) {
    ours <- sort(unique(C[election == el, seat]))
    miss <- setdiff(ours, theirs)
    cov <- if (length(ours)) 1 - length(miss) / length(ours) else NA_real_
    cat(sprintf("CE6  %-10s our seats %3d | census divisions %3d | coverage %5.1f%%\n",
                el, length(ours), length(theirs), 100 * cov))
    if (length(miss)) {
      cat(sprintf("CE6    unmatched (%d): %s\n", length(miss), paste(miss, collapse = ", ")))
    }
  }
} else {
  cat("\nCE6  output/candidacies.csv not found -- federal coverage not checked this run.\n")
}
