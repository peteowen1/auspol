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

# REAL integrity check, not just "the central directory lists it": `unzip(...,
# list = TRUE)` only reads the zip's directory and proves nothing about
# whether the compressed bytes themselves are intact -- a truncated download
# can still produce a complete, listable directory (CLAUDE.md's own recorded
# case: a truncated file passed a size guard and parsed to zero rows). This
# extracts every member to a scratch directory and checks each extracted
# file's size against the size the directory itself claims, which forces the
# decompression to actually happen.
verify_zip_integrity <- function(zip_path) {
  listing <- utils::unzip(zip_path, list = TRUE)
  tdir <- tempfile("zipcheck")
  ok <- tryCatch({
    utils::unzip(zip_path, exdir = tdir)
    sizes <- file.size(file.path(tdir, listing$Name))
    !anyNA(sizes) && all(sizes == listing$Length)
  }, error = function(e) FALSE)
  unlink(tdir, recursive = TRUE)
  ok
}

# ---- acquire: national census pack ------------------------------------------
census_zip <- file.path(CEN, "2021_GCP_CED_AUS.zip")
if (!file.exists(census_zip) || file.size(census_zip) < 1e6 || !verify_zip_integrity(census_zip)) {
  url <- paste0("https://www.abs.gov.au/census/find-census-data/datapacks/",
                "download/2021_GCP_CED_for_AUS_short-header.zip")
  dl_err <- tryCatch({
    utils::download.file(url, census_zip, quiet = TRUE, mode = "wb")
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(dl_err)) stop("CED census download failed: ", dl_err)
  if (!verify_zip_integrity(census_zip))
    stop("CED census zip downloaded but failed integrity verification (extracted ",
         "member size mismatch) -- treat as corrupt, do not use")
  cat(sprintf("CE1  census pack downloaded and verified (%.1f MB)\n", file.size(census_zip)/1e6))
} else {
  cat(sprintf("CE1  census pack already present and verified (%.1f MB)\n", file.size(census_zip)/1e6))
}
zi <- utils::unzip(census_zip, list = TRUE)
cat(sprintf("CE1  archive verified, %d members\n", nrow(zi)))

# ---- acquire: CED boundary shapefile -----------------------------------------
bnd_zip <- file.path(BND, "CED_2021_AUST_GDA2020_SHP.zip")
dbf <- file.path(BND, "CED_2021_AUST_GDA2020.dbf")
if (!file.exists(dbf)) {
  dir.create(BND, showWarnings = FALSE, recursive = TRUE)
  url <- paste0("https://www.abs.gov.au/statistics/standards/",
                "australian-statistical-geography-standard-asgs-edition-3-july-2021-june-2026/",
                "access-and-downloads/digital-boundary-files/CED_2021_AUST_GDA2020_SHP.zip")
  dl_err <- tryCatch({
    utils::download.file(url, bnd_zip, quiet = TRUE, mode = "wb")
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(dl_err)) stop("CED boundary download failed: ", dl_err)
  if (!verify_zip_integrity(bnd_zip))
    stop("CED boundary zip downloaded but failed integrity verification -- treat as corrupt")
  utils::unzip(bnd_zip, exdir = BND)
  if (!file.exists(dbf)) stop("CED boundary zip extracted but .dbf missing")
  cat(sprintf("CE2  boundary shapefile fetched, verified and extracted (%.1f MB)\n", file.size(bnd_zip)/1e6))
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
  n_read <- 0L
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
    n_read <- i
  }
  # A short read means the .dbf is truncated -- the header's own record count
  # (nrec) says how many rows to expect, and reading fewer must be visible
  # rather than silently returning a short table (the same "size floor is not
  # completeness" trap this repo has hit before, here on a record count
  # instead of a byte count).
  if (n_read < nrec) {
    stop(".dbf truncated: header claims ", nrec, " records, only ", n_read,
         " could be read from ", path, " -- treat the file as corrupt, do not use")
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
# This is a fixed allowlist of two known residual patterns, not a verified-
# complete list -- if ABS ever adds or renames a residual category, a row
# with a plausible-but-fake "seat" name would silently survive as a real
# electorate. A broader, case-insensitive check for the words that mark every
# residual category ABS has ever used catches a new one even if its exact
# wording changes, rather than trusting the allowlist stays exhaustive.
still_residual_looking <- grepl("usual address|migratory|no fixed address",
                                 cen$ced_name, ignore.case = TRUE)
if (any(still_residual_looking)) {
  stop("Row(s) surviving exclusion still look like ABS residual categories, not real ",
       "electorates -- the allowlist above is stale: ",
       paste(cen$ced_name[still_residual_looking], collapse = ", "))
}

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
