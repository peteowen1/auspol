# ABS Census (2016 General Community Profile) at Commonwealth Electoral
# Division -- the 2016 counterpart to fetch_census_ced.R (2021).
#
# WHY A SEPARATE SCRIPT, not a year parameter on fetch_census_ced.R: the 2016
# census pack's internal folder/file naming differs in one real way from
# 2021's ("...for AUST/2016Census_G01_AUS_CED.csv" -- folder says "AUST",
# filename says "AUS", not "AUST" as 2021's does) and the boundary file comes
# from a DIFFERENT product family entirely -- 2021's lives under the modern
# ASGS Edition 3 "digital-boundary-files" product page; 2016's ASGS Edition 2
# boundaries are not republished there and had to be located via the old
# AUSSTATS subscriber.nsf redirect system (catalogue 1270.0.55.003, "Non ABS
# Structures, July 2016"). Confirmed working 2026-09-10; if ABS ever migrates
# this off AUSSTATS the URL below will need re-finding, not just re-dating.
#
# THE JOIN KEY IS STILL A CODE: CED_CODE_2016 in the census pack,
# CED_CODE16 in the boundary .dbf (confirmed by inspecting the .dbf directly,
# not assumed from the 2021 pattern -- 2-digit year suffix matches, but this
# was verified, not copied blind).
#
# Emits CE6* codes (2016-specific, to not collide with fetch_census_ced.R's
# CE1-CE6 in a combined log).

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

REF <- file.path("external", "reference")
CEN <- file.path(REF, "census")
BND <- file.path(REF, "boundaries")
dir.create(CEN, showWarnings = FALSE, recursive = TRUE)

# Real integrity check -- extract every member to a scratch dir and compare
# sizes against the archive's own directory listing, not just "the zip opens".
# Same rationale and implementation as fetch_census_ced.R's verify_zip_integrity().
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

# ---- acquire: national 2016 census pack -------------------------------------
census_zip <- file.path(CEN, "2016_GCP_CED_AUS.zip")
if (!file.exists(census_zip) || file.size(census_zip) < 1e6 || !verify_zip_integrity(census_zip)) {
  url <- paste0("https://www.abs.gov.au/census/find-census-data/datapacks/",
                "download/2016_GCP_CED_for_AUS_short-header.zip")
  dl_err <- tryCatch({
    utils::download.file(url, census_zip, quiet = TRUE, mode = "wb")
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(dl_err)) stop("2016 CED census download failed: ", dl_err)
  if (!verify_zip_integrity(census_zip))
    stop("2016 CED census zip downloaded but failed integrity verification")
  cat(sprintf("CE61  census pack downloaded and verified (%.1f MB)\n", file.size(census_zip)/1e6))
} else {
  cat(sprintf("CE61  census pack already present and verified (%.1f MB)\n", file.size(census_zip)/1e6))
}
zi <- utils::unzip(census_zip, list = TRUE)
cat(sprintf("CE61  archive verified, %d members\n", nrow(zi)))

# ---- acquire: 2016 CED boundary shapefile (AUSSTATS, not the modern ASGS
# product page -- see header comment) ----------------------------------------
bnd_zip <- file.path(BND, "CED_2016_AUST.zip")
dbf <- file.path(BND, "CED_2016_AUST.dbf")
if (!file.exists(dbf)) {
  dir.create(BND, showWarnings = FALSE, recursive = TRUE)
  url <- paste0("https://www.abs.gov.au/ausstats/subscriber.nsf/log?openagent",
                "&1270055003_ced_2016_aust_shape.zip&1270.0.55.003&Data%20Cubes",
                "&447BE1AE2E3E7A3ACA25802C00144C3C&0&July%202016&13.09.2016&Previous")
  dl_err <- tryCatch({
    utils::download.file(url, bnd_zip, quiet = TRUE, mode = "wb")
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(dl_err)) stop("2016 CED boundary download failed: ", dl_err)
  if (!verify_zip_integrity(bnd_zip))
    stop("2016 CED boundary zip downloaded but failed integrity verification")
  utils::unzip(bnd_zip, exdir = BND)
  if (!file.exists(dbf)) stop("2016 CED boundary zip extracted but .dbf missing")
  cat(sprintf("CE62  boundary shapefile fetched, verified and extracted (%.1f MB)\n", file.size(bnd_zip)/1e6))
} else {
  cat("CE62  boundary shapefile already present\n")
}

# ---- CED code -> name, from the boundary shapefile's .dbf -------------------
# Same hand-rolled reader as fetch_census_ced.R (avoids a geospatial
# dependency for two attribute columns), including its truncation guard.
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
  if (n_read < nrec) {
    stop(".dbf truncated: header claims ", nrec, " records, only ", n_read,
         " could be read from ", path, " -- treat the file as corrupt, do not use")
  }
  d <- as.data.table(do.call(rbind, out))
  setnames(d, nm)
  d[, ..want]
}

# Field names verified directly against the extracted .dbf before writing
# this, not assumed from the 2021 pattern: 2016's CED .dbf carries only
# CED_CODE16 / CED_NAME16 / AREASQKM16 -- NO state-name field, unlike 2021's
# boundary file (which has STE_NAME21). Not needed here: this script only
# checks coverage against FEDERAL elections (no state stratification), so
# state is not required for the join or the coverage check below.
look <- read_dbf_fields(dbf, c("CED_CODE16", "CED_NAME16"))
look[, ced_code := paste0("CED", CED_CODE16)]
cat(sprintf("CE63  CED lookup: %d divisions\n", nrow(look)))

# ---- read G01 (age/sex) and G02 (medians) -----------------------------------
zdir <- grep("^2016 Census GCP", zi$Name, value = TRUE)
zdir <- unique(dirname(zdir))[1]
grab <- function(tbl) {
  # Folder says "...for AUST", but the CSV filename inside uses "AUS", not
  # "AUST" -- confirmed by listing the archive directly, not assumed from
  # 2021's "...AUST_CED.csv" pattern.
  f <- sprintf("%s/2016Census_%s_AUS_CED.csv", zdir, tbl)
  if (!f %in% zi$Name) stop("No ", tbl, " table found at ", f)
  con <- unz(census_zip, f)
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  fread(text = readLines(con, warn = FALSE), showProgress = FALSE)
}
g1 <- grab("G01"); g2 <- grab("G02")
all_cen <- merge(g1, g2, by = "CED_CODE_2016")
setnames(all_cen, "CED_CODE_2016", "ced_code")

cen <- merge(all_cen, look[, .(ced_code, ced_name = CED_NAME16)],
             by = "ced_code", all.x = TRUE)

# NOT REAL ELECTORATES -- same residual-category exclusion as fetch_census_ced.R
# (2021), broadened past the fixed allowlist the same way that file's own
# review fix did: any name that still LOOKS like a residual category after
# exclusion stops the run rather than silently passing as a real seat.
is_residual <- grepl("^(No usual address|Migratory - Offshore - Shipping)\\b", cen$ced_name)
if (sum(is_residual)) {
  cat(sprintf("CE64  excluding %d non-electorate residual row(s): %s\n",
              sum(is_residual), paste(cen$ced_name[is_residual], collapse = ", ")))
}
cen <- cen[!is_residual]
still_residual_looking <- grepl("usual address|migratory|no fixed address",
                                 cen$ced_name, ignore.case = TRUE)
if (any(still_residual_looking)) {
  stop("Row(s) surviving exclusion still look like ABS residual categories: ",
       paste(cen$ced_name[still_residual_looking], collapse = ", "))
}

has_paren <- grep("\\(", cen$ced_name, value = TRUE)
if (length(has_paren)) {
  stop("Unexpected parenthetical suffix on a real-looking division name(s): ",
       paste(has_paren, collapse = ", "))
}
cen[, seat := ced_name]
unmatched <- cen[is.na(seat), .N]
dup <- cen[!is.na(seat), .N, by = seat][N > 1]
if (nrow(dup)) stop("Division name collision(s): ", paste(dup$seat, collapse = ", "))
if (unmatched) cat(sprintf("CE64  %d row(s) with no name -- dropped\n", unmatched))
cen <- cen[!is.na(seat)]
cat(sprintf("CE64  census rows %d, all named, no collisions\n", nrow(cen)))

fwrite(cen, file.path(CEN, "census-ced-2016.csv"))
cat(sprintf("CE65  wrote %s (%d rows, %d columns)\n",
            file.path(CEN, "census-ced-2016.csv"), nrow(cen), ncol(cen)))

# ---- coverage: fed2016 (SAME YEAR as the census -- the clean case) and the
# adjacent pairs (fed2013, fed2019), every unmatched seat NAMED --------------
cf <- file.path("output", "candidacies.csv")
if (file.exists(cf)) {
  C <- fread(cf, showProgress = FALSE)
  theirs <- cen[!is.na(seat), sort(unique(seat))]
  for (el in c("fed2013", "fed2016", "fed2019")) {
    ours <- sort(unique(C[election == el, seat]))
    if (!length(ours)) { cat(sprintf("CE66  %s: no candidacy rows, skipped\n", el)); next }
    miss <- setdiff(ours, theirs)
    cov <- 1 - length(miss) / length(ours)
    cat(sprintf("CE66  %-10s our seats %3d | census divisions %3d | coverage %5.1f%%\n",
                el, length(ours), length(theirs), 100 * cov))
    if (length(miss)) cat(sprintf("CE66    unmatched (%d): %s\n", length(miss), paste(miss, collapse = ", ")))
  }
} else {
  cat("CE66  output/candidacies.csv not found -- coverage not checked this run.\n")
}
