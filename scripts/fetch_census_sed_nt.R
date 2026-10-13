# ABS Census 2016 and 2021 General Community Profile at State Electoral Division
# for the NORTHERN TERRITORY -- the state the existing fetchers
# (fetch_census_sed.R, fetch_census_sed_2016.R) left out. Needed for the nt2016,
# nt2020 and nt2024 backtests (build_census_features_vintage.R).
#
# Same DataPack URL pattern as the other states (verified HTTP 200 on 2026-10-13),
# same G01 table, same columns. Writes census-sed-2016-nt.csv and
# census-sed-2021-nt.csv NEXT TO the existing census-sed-*.csv (NEW files; the
# existing national ones are not touched). The raw zips are kept too.
# Names come from the ABS boundary .dbf for that vintage; seat = name with the
# upper-house suffix stripped (NT has none; the strip is harmless).
# Emits CNT* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
CEN <- file.path("external", "reference", "census")
BND <- file.path("external", "reference", "boundaries")

verify_zip <- function(z) {
  l <- utils::unzip(z, list = TRUE); td <- tempfile(); on.exit(unlink(td, recursive = TRUE))
  utils::unzip(z, exdir = td)
  s <- file.size(file.path(td, l$Name)); !anyNA(s) && all(s == l$Length)
}
read_dbf_fields <- function(path, want) {
  con <- file(path, "rb"); on.exit(close(con))
  h <- readBin(con, "raw", 32)
  nrec <- readBin(h[5:8], "integer", size = 4, endian = "little")
  hlen <- readBin(h[9:10], "integer", size = 2, endian = "little")
  rlen <- readBin(h[11:12], "integer", size = 2, endian = "little")
  nm <- character(0); wd <- integer(0)
  repeat {
    d <- readBin(con, "raw", 32)
    if (length(d) < 32 || d[1] == as.raw(0x0d)) break
    fn <- d[1:11]; fn <- fn[fn != as.raw(0)]
    nm <- c(nm, rawToChar(fn)); wd <- c(wd, as.integer(d[17]))
  }
  seek(con, hlen); out <- vector("list", nrec)
  for (i in seq_len(nrec)) {
    rec <- readBin(con, "raw", rlen)
    stopifnot(length(rec) == rlen)
    off <- 2L; vals <- character(length(nm))
    for (j in seq_along(nm)) {
      ch <- rec[off:(off + wd[j] - 1L)]; ch <- ch[ch != as.raw(0)]
      vals[j] <- trimws(rawToChar(ch)); off <- off + wd[j]
    }
    out[[i]] <- vals
  }
  d <- as.data.table(do.call(rbind, out)); setnames(d, nm); d[, ..want]
}

for (v in c("2016", "2021")) {
  zip <- file.path(CEN, sprintf("%s_GCP_SED_NT.zip", v))
  if (!(file.exists(zip) && file.size(zip) > 1e6 && verify_zip(zip))) {
    url <- sprintf("https://www.abs.gov.au/census/find-census-data/datapacks/download/%s_GCP_SED_for_NT_short-header.zip", v)
    utils::download.file(url, zip, quiet = TRUE, mode = "wb")
    stopifnot(verify_zip(zip))
  }
  cat(sprintf("CNT1 %s NT pack %.1f MB, verified\n", v, file.size(zip) / 1e6))
  ls_ <- utils::unzip(zip, list = TRUE)
  f <- grep("G01_NT_SED\\.csv$", ls_$Name, value = TRUE); stopifnot(length(f) == 1)
  con <- unz(zip, f); g1 <- fread(text = readLines(con, warn = FALSE), showProgress = FALSE); close(con)
  codecol <- paste0("SED_CODE_", v); stopifnot(codecol %in% names(g1))
  setnames(g1, codecol, "sed_code")
  if (v == "2016") {
    look <- read_dbf_fields(file.path(BND, "SED_2016_AUST.dbf"), c("SED_CODE16", "SED_NAME16"))
    look <- look[, .(sed_code = paste0("SED", SED_CODE16), sed_name = SED_NAME16)]
  } else {
    look <- read_dbf_fields(file.path(BND, "SED_2021_AUST_GDA2020.dbf"), c("SED_CODE21", "SED_NAME21"))
    look <- look[, .(sed_code = paste0("SED", SED_CODE21), sed_name = SED_NAME21)]
  }
  cen <- merge(g1, look, by = "sed_code", all.x = TRUE)
  cen[, seat := trimws(sub("\\s*\\(.*\\)\\s*$", "", sed_name))]
  cen[, state := "NT"]
  cat(sprintf("CNT2 %s: %d rows, %d unnamed (non-geographic codes)\n", v, nrow(cen), sum(is.na(cen$seat))))
  named <- cen[!is.na(seat)]
  stopifnot(!anyDuplicated(named$seat), "Tot_P_P" %in% names(named))
  cat(sprintf("CNT3 %s NT divisions: %d; summed Tot_P_P %s; names: %s\n", v, nrow(named),
              format(sum(named$Tot_P_P), big.mark = ","), paste(sort(named$seat), collapse = ", ")))
  fwrite(named, file.path(CEN, sprintf("census-sed-%s-nt.csv", v)))
}
