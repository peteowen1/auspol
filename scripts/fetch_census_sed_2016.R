# ABS Census (2016 General Community Profile) at State Electoral Division --
# the 2016 counterpart to fetch_census_sed.R (2021).
#
# SAME per-state DataPack loop as 2021, SAME URL pattern with the year
# swapped (https://www.abs.gov.au/census/find-census-data/datapacks/download/
# 2016_GCP_SED_for_%s_short-header.zip -- confirmed working directly, not
# guessed from 2021's pattern alone). The boundary shapefile is DIFFERENT
# from 2021's product family: 2016's SED_2016_AUST.dbf lives under the old
# AUSSTATS subscriber.nsf redirect system (cat. 1270.0.55.003, "Non ABS
# Structures, July 2016"), not the modern ASGS Edition 3 digital-boundary-
# files page, and it carries only SED_CODE16/SED_NAME16/AREASQKM16 -- no
# state-name field, unlike 2021's boundary file (STE_NAME21). State is
# derived from WHICH per-state census zip a row came from instead (same
# information 2021's STATES loop already carries), not from the boundary
# file at all.
#
# Emits CE6* codes (2016-specific), same numbering scheme as
# fetch_census_ced_2016.R -- these two scripts don't share a log.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

REF <- file.path("external", "reference")
CEN <- file.path(REF, "census")
BND <- file.path(REF, "boundaries")
dir.create(CEN, showWarnings = FALSE, recursive = TRUE)

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

STATES <- c(VIC = "VIC", NSW = "NSW", SA = "SA", QLD = "QLD", WA = "WA")
BASE <- paste0("https://www.abs.gov.au/census/find-census-data/datapacks/",
               "download/2016_GCP_SED_for_%s_short-header.zip")

# ---- acquire: one census pack per state -------------------------------------
for (st in STATES) {
  dest <- file.path(CEN, sprintf("2016_GCP_SED_%s.zip", st))
  if (file.exists(dest) && file.size(dest) > 1e6 && verify_zip_integrity(dest)) {
    cat(sprintf("CE61  %s already present and verified (%.1f MB)\n", st, file.size(dest)/1e6))
    next
  }
  url <- sprintf(BASE, st)
  dl_err <- tryCatch({
    utils::download.file(url, dest, quiet = TRUE, mode = "wb")
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(dl_err)) stop("2016 SED ", st, " download failed: ", dl_err)
  if (!verify_zip_integrity(dest)) stop("2016 SED ", st, " zip failed integrity verification")
  cat(sprintf("CE61  %s downloaded and verified (%.1f MB)\n", st, file.size(dest)/1e6))
}

# ---- acquire: 2016 SED boundary shapefile (AUSSTATS, not the modern ASGS
# product page -- see fetch_census_ced_2016.R's header comment for why) ------
bnd_zip <- file.path(BND, "SED_2016_AUST.zip")
dbf <- file.path(BND, "SED_2016_AUST.dbf")
if (!file.exists(dbf)) {
  dir.create(BND, showWarnings = FALSE, recursive = TRUE)
  url <- paste0("https://www.abs.gov.au/ausstats/subscriber.nsf/log?openagent",
                "&1270055003_sed_2016_aust_shp.zip&1270.0.55.003&Data%20Cubes",
                "&0158A8AE4969AC0BCA25828300129E54&0&July%202018&07.05.2018&Previous")
  dl_err <- tryCatch({
    utils::download.file(url, bnd_zip, quiet = TRUE, mode = "wb")
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(dl_err)) stop("2016 SED boundary download failed: ", dl_err)
  if (!verify_zip_integrity(bnd_zip)) stop("2016 SED boundary zip failed integrity verification")
  utils::unzip(bnd_zip, exdir = BND)
  if (!file.exists(dbf)) stop("2016 SED boundary zip extracted but .dbf missing")
  cat(sprintf("CE62  boundary shapefile fetched, verified and extracted (%.1f MB)\n", file.size(bnd_zip)/1e6))
} else {
  cat("CE62  boundary shapefile already present\n")
}

# ---- SED code -> name, from the boundary shapefile's .dbf -------------------
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
         " could be read -- treat as corrupt")
  }
  d <- as.data.table(do.call(rbind, out))
  setnames(d, nm)
  d[, ..want]
}

# Verified directly against the extracted .dbf: SED_CODE16 / SED_NAME16, no
# state field (see header comment -- state comes from the per-state zip loop).
look <- read_dbf_fields(dbf, c("SED_CODE16", "SED_NAME16"))
look[, sed_code := paste0("SED", SED_CODE16)]
cat(sprintf("CE63  SED lookup: %d divisions nationally\n", nrow(look)))

# ---- read G01 (age/sex) and G02 (medians) per state -------------------------
grab <- function(st, tbl) {
  z <- file.path(CEN, sprintf("2016_GCP_SED_%s.zip", st))
  ls_ <- utils::unzip(z, list = TRUE)
  # Same AUS-vs-AUST filename quirk as the CED script -- verified against the
  # actual archive listing, not assumed.
  f <- grep(sprintf("%s_%s_SED\\.csv$", tbl, st), ls_$Name, value = TRUE)
  if (!length(f)) stop("No ", tbl, " table for ", st, " -- listing: ",
                        paste(utils::head(ls_$Name, 5), collapse = ", "))
  con <- unz(z, f[1])
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  fread(text = readLines(con, warn = FALSE), showProgress = FALSE)
}

all_cen <- rbindlist(lapply(names(STATES), function(st) {
  g1 <- grab(st, "G01"); g2 <- grab(st, "G02")
  m <- merge(g1, g2, by = "SED_CODE_2016")
  m[, state := st][]
}), fill = TRUE)
setnames(all_cen, "SED_CODE_2016", "sed_code")

cen <- merge(all_cen, look[, .(sed_code, sed_name = SED_NAME16)],
             by = "sed_code", all.x = TRUE)

# ABS suffixes each division with its upper-house region, same as 2021 --
# stripped, then checked for collisions before trusting it.
cen[, seat := trimws(sub("\\s*\\(.*\\)\\s*$", "", sed_name))]
unmatched <- cen[is.na(seat), .N]
dup <- cen[!is.na(seat), .N, by = .(state, seat)][N > 1]
if (nrow(dup)) {
  stop("Stripping the region suffix collided ", nrow(dup),
       " seat name(s): ", paste(dup$seat, collapse = ", "))
}
if (unmatched) cat(sprintf("CE64  %d row(s) with no name -- dropped\n", unmatched))
cen <- cen[!is.na(seat)]
cat(sprintf("CE64  census rows %d; named %d\n", nrow(cen), sum(!is.na(cen$seat))))

fwrite(cen, file.path(CEN, "census-sed-2016.csv"))
cat(sprintf("CE65  wrote %s (%d rows, %d columns)\n",
            file.path(CEN, "census-sed-2016.csv"), nrow(cen), ncol(cen)))

# THE BOUNDARY FILE IS NOT UNIFORMLY "2016". Checked directly (review caught
# this before it went unquestioned): the zip-embedded original timestamp on
# SED_2016_AUST.dbf/.shp/.shx is 2018-05-01, while the same archive's own
# .xml metadata is 2016-09-08 -- ABS re-issued the geometry/attribute files
# under the same "2016" catalogue entry, keeping the old documentation. For a
# state with NO redistribution between the 2016 census and May 2018 (VIC,
# NSW -- both confirmed stable across that window from this session's own
# redistribution history), the label is harmless. For WA specifically, this
# is confirmed to be the CAUSE of the 59.3% coverage figure below: WA's own
# 2015-17 redistribution finished before May 2018, so this "corrected" file
# carries WA's POST-redistribution boundaries under the 2016 label, and its
# seat names/codes silently describe a different geography than the actual
# 2016 census. WA's number below is NOT reliable coverage -- do not build on
# it without sourcing the genuine pre-2017 WA boundary file. QLD and SA are
# UNVERIFIED against this same risk (no redistribution-history cross-check
# done for either, unlike VIC/NSW) -- their numbers below should be treated
# with the same caution as WA until checked, not assumed safe by default.
#
# ---- coverage: state elections near 2016, every unmatched seat NAMED,
# reported not enforced (no verified redistribution table for these yet,
# same discipline fetch_census_sed.R's own QLD/WA block already uses) --------
cf <- file.path("output", "candidacies.csv")
if (file.exists(cf)) {
  C <- fread(cf, showProgress = FALSE)
  checks <- list(
    list(state = "VIC", election = "vic2014", trust = "verified stable, no redistribution 2016-2018"),
    list(state = "VIC", election = "vic2018", trust = "verified stable, no redistribution 2016-2018"),
    list(state = "NSW", election = "nsw2015", trust = "verified stable, no redistribution 2016-2018"),
    list(state = "NSW", election = "nsw2019", trust = "verified stable, no redistribution 2016-2018"),
    list(state = "QLD", election = "qld2017", trust = "UNVERIFIED -- redistribution history not checked"),
    list(state = "QLD", election = "qld2020", trust = "UNVERIFIED -- redistribution history not checked"),
    list(state = "SA",  election = "sa2018",  trust = "UNVERIFIED -- redistribution history not checked"),
    list(state = "SA",  election = "sa2022",  trust = "UNVERIFIED -- redistribution history not checked"),
    list(state = "WA",  election = "wa2013",  trust = "CONFIRMED UNRELIABLE -- boundary file is post-2017-redistribution, not 2016"),
    list(state = "WA",  election = "wa2017",  trust = "CONFIRMED UNRELIABLE -- boundary file is post-2017-redistribution, not 2016"))
  for (chk in checks) {
    ours <- sort(unique(C[election == chk$election, seat]))
    if (!length(ours)) { cat(sprintf("CE66  %s: no candidacy rows, skipped\n", chk$election)); next }
    theirs <- cen[state == chk$state, sort(unique(seat))]
    miss <- setdiff(ours, theirs)
    cov <- 1 - length(miss) / length(ours)
    cat(sprintf("CE66  %-10s (%s) our seats %3d | census divisions %3d | coverage %5.1f%% | %s\n",
                chk$election, chk$state, length(ours), length(theirs), 100 * cov, chk$trust))
    if (length(miss)) cat(sprintf("CE66    unmatched (%d): %s\n", length(miss), paste(miss, collapse = ", ")))
  }
} else {
  cat("CE66  output/candidacies.csv not found -- coverage not checked this run.\n")
}
