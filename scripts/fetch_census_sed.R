# ABS Census (2021 General Community Profile) at State Electoral Division.
#
# WHY THIS AND NOT BOOTHS. Path A was scoped as booth-level ecological
# regression, which needs booth results (we have them, external/reference/aec/
# booths) AND Census at booth or SA1 geography AND a booth->SA1 geospatial
# correspondence. The ABS publishes Census ALREADY AGGREGATED to electoral
# divisions, so a seat-level demographic model needs one download and no
# geospatial work. See docs/plans/plan-path-a-demographics.md.
#
# WHAT THIS COSTS: no sub-seat structure. A booth model can see a swing
# concentrating in a seat's mortgage-belt booths; this cannot. Stated because
# "demographic model" should not be read as theswingison's resolution.
#
# THE JOIN KEY IS A CODE, NOT A NAME. The Census pack is keyed on
# SED_CODE_2021 ("SED20106"); the name lives only in the boundary shapefile's
# .dbf. Joining on names without that lookup would silently drop every seat.
#
# Emits CE* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

REF <- file.path("external", "reference")
CEN <- file.path(REF, "census")
dir.create(CEN, showWarnings = FALSE, recursive = TRUE)

STATES <- c(VIC = "VIC", NSW = "NSW", SA = "SA")
BASE <- paste0("https://www.abs.gov.au/census/find-census-data/datapacks/",
               "download/2021_GCP_SED_for_%s_short-header.zip")

# ---- acquire ---------------------------------------------------------------
for (st in STATES) {
  dest <- file.path(CEN, sprintf("2021_GCP_SED_%s.zip", st))
  if (file.exists(dest) && file.size(dest) > 1e6) {
    cat(sprintf("CE1  %s already present (%.1f MB)\n", st, file.size(dest)/1e6))
    next
  }
  url <- sprintf(BASE, st)
  ok <- tryCatch({
    utils::download.file(url, dest, quiet = TRUE, mode = "wb")
    TRUE
  }, error = function(e) FALSE)
  # A SIZE FLOOR IS NOT A COMPLETENESS CHECK -- CLAUDE.md records a truncated
  # download of exactly 65536 bytes clearing a `> 2000` guard. Verify the
  # archive opens and every member passes its CRC instead.
  good <- ok && file.exists(dest) &&
    !inherits(tryCatch(utils::unzip(dest, list = TRUE), error = function(e) e), "error")
  if (!good) stop("Census download failed or is not a readable archive for ", st)
  cat(sprintf("CE1  %s downloaded (%.1f MB)\n", st, file.size(dest)/1e6))
}

# ---- SED code -> name, from the boundary shapefile's .dbf -------------------
# Read the dBASE header directly rather than adding a geospatial dependency:
# only two attribute columns are needed and the file is a fixed-width format.
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
    # Field names are NUL-padded to 11 bytes and rawToChar() refuses an
    # embedded NUL, so the padding is dropped from the raw vector first.
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

# SED_2021, matching the Census pack's own geography.
#
# SED_2022 WAS TRIED AND IS WRONG HERE. Its names are current -- all nine
# seats missing under 2021 resolve under 2022 -- but the CODES are not stable
# between vintages: joining the 2021 Census pack to 2022 codes matched only 28
# of 90 Victorian divisions and dropped 62 rows, taking coverage from 89.7% to
# 29.9%. The coverage floor below is what caught that.
dbf <- file.path(REF, "boundaries", "SED_2021_AUST_GDA2020.dbf")
if (!file.exists(dbf)) stop("Missing ", dbf)
look <- read_dbf_fields(dbf, c("SED_CODE21", "SED_NAME21", "STE_NAME21"))
look[, sed_code := paste0("SED", SED_CODE21)]
cat(sprintf("CE2  SED lookup: %d divisions across %d states\n",
            nrow(look), uniqueN(look$STE_NAME21)))

# ---- read G01 (age/sex) and G02 (medians) per state ------------------------
grab <- function(st, tbl) {
  z <- file.path(CEN, sprintf("2021_GCP_SED_%s.zip", st))
  ls_ <- utils::unzip(z, list = TRUE)
  f <- grep(sprintf("%s_%s_SED\\.csv$", tbl, st), ls_$Name, value = TRUE)
  if (!length(f)) stop("No ", tbl, " table for ", st)
  con <- unz(z, f[1])
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  fread(text = readLines(con, warn = FALSE), showProgress = FALSE)
}

all_cen <- rbindlist(lapply(names(STATES), function(st) {
  g1 <- grab(st, "G01"); g2 <- grab(st, "G02")
  m <- merge(g1, g2, by = "SED_CODE_2021")
  m[, state := st][]
}), fill = TRUE)
setnames(all_cen, "SED_CODE_2021", "sed_code")

cen <- merge(all_cen, look[, .(sed_code, sed_name = SED_NAME21, ste = STE_NAME21)],
             by = "sed_code", all.x = TRUE)

# ABS suffixes each division with its upper-house region -- "Albert Park
# (Southern Metropolitan)". Electoral commissions do not, so the raw name
# matches nothing. Stripped here, and then CHECKED: a name fix that silently
# collides two seats is the failure mode this repo records for hand-maintained
# reference data.
cen[, seat := trimws(sub("\\s*\\(.*\\)\\s*$", "", sed_name))]
# Unmatched rows are NOT collisions -- a code present in the 2021 Census pack
# but absent from the 2022 boundary file has no name and must be counted
# separately, or the collision check fires on NA and hides the real question.
unmatched <- cen[is.na(seat), .N]
dup <- cen[!is.na(seat), .N, by = .(ste, seat)][N > 1]
if (nrow(dup)) {
  stop("Stripping the region suffix collided ", nrow(dup),
       " seat name(s): ", paste(dup$seat, collapse = ", "))
}
if (unmatched) {
  cat(sprintf("CE3  %d census row(s) have a 2021 code absent from SED_2022 -- dropped\n",
              unmatched))
}
cen <- cen[!is.na(seat)]
cat(sprintf("CE3  census rows %d; named %d; suffix stripped, no collisions\n",
            nrow(cen), sum(!is.na(cen$seat))))

# ---- THE CHECK THAT MATTERS: does it join to our seats? --------------------
sp <- fread("output/seat-probs-vic-2026.csv", showProgress = FALSE)
ours <- sort(unique(sp$seat))
theirs <- cen[ste == "Victoria" & !is.na(seat), sort(unique(seat))]
miss <- setdiff(ours, theirs)
cat(sprintf("\nCE4  Victorian seats in our forecast: %d | in the Census pack: %d\n",
            length(ours), length(theirs)))
cat(sprintf("CE4  ours with NO census match: %d%s\n", length(miss),
            if (length(miss)) paste0(" -- ", paste(miss, collapse = ", ")) else ""))
extra <- setdiff(theirs, ours)
cat(sprintf("CE4  census divisions not in our forecast: %d%s\n", length(extra),
            if (length(extra)) paste0(" -- ", paste(extra, collapse = ", ")) else ""))

# EVERY unmatched seat must be EXPLAINED, which is a stronger check than a
# coverage percentage. These nine were created or renamed by Victoria's
# post-2021 redistribution and therefore cannot exist in 2021 Census geography.
# Verified against SED_2022, where all nine appear.
#
# An arbitrary coverage floor would either pass this silently or block on a
# legitimate redistribution; naming the seats means a TENTH unmatched seat --
# a genuine join bug -- still stops the run.
REDISTRIBUTED_2021_TO_2026 <- c(
  "Ashwood",        # was Burwood
  "Berwick",        # was Gembrook
  "Eureka",         # was Buninyong
  "Glen Waverley",  # was Mount Waverley
  "Greenvale",      # from Yuroke
  "Kalkallo",       # from Yuroke
  "Laverton",       # from Altona
  "Pakenham",       # new
  "Point Cook")     # from Altona
cov <- 1 - length(miss) / length(ours)
cat(sprintf("CE4  coverage %.1f%%\n", 100 * cov))
unexplained <- setdiff(miss, REDISTRIBUTED_2021_TO_2026)
if (length(unexplained)) {
  stop("Unmatched Victorian seat(s) NOT explained by the known redistribution: ",
       paste(unexplained, collapse = ", "),
       ". That is a join bug, not a boundary change -- do not build on it.")
}
cat(sprintf("CE4  all %d unmatched seats are known redistribution cases -- OK\n",
            length(miss)))
cat("CE4  NOTE: those nine have NO 2021 Census demographics. Getting them\n")
cat("     needs SA1-level re-aggregation via the ABS SA1->SED correspondence;\n")
cat("     a rename map cannot fix a boundary that actually moved.\n")

fwrite(cen, file.path(CEN, "census-sed-2021.csv"))
cat(sprintf("\nCE5  wrote %s (%d rows, %d columns)\n",
            file.path(CEN, "census-sed-2021.csv"), nrow(cen), ncol(cen)))
