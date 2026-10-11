#!/usr/bin/env Rscript
# Poll Bludger's per-poll tables for the state elections where Wikipedia has no (or almost
# no) polling table of its own: nsw2019 and vic2018 (step 1 of the own-poll-source work,
# docs/reviews/own-poll-source-step1-2026-10-11.md).
#
# Where the data lives. pollbludger.net/<election>/polltracker.htm draws its charts from a
# public Google Sheet whose first tab lists every poll the tracker used: DATE, POLLSTER,
# primaries (LNP, ALP, GRN), two-party and the trend columns. Only vic2018, nsw2019, qld2017
# and sa2018 have a tracker page (checked 2026-10-11 by HTTP status for vic2010/2014/2018/2022,
# nsw2015/2019/2023, qld2015/2017/2020/2024, sa2018/2022/2026, wa2008/2013/2017/2021/2025:
# the others return 404). qld2017 and sa2018 are not scored elections and are not fetched.
#
# Raw response first (CLAUDE.md "store the raw response"): each sheet is saved once as
# external/reference/polls/statewide-samples/raw/pollbludger_<key>_sheet_gid0.csv and never
# re-fetched while on disk; every column is kept in the parsed file, trend columns included.
# Writes external/reference/polls/statewide-samples/pollbludger_polls.csv.
suppressPackageStartupMessages(library(data.table))
base_dir <- Sys.getenv("AUSPOL_POLL_BASE", "external/reference/polls/statewide-samples")   # env override is a test hook
raw_dir <- file.path(base_dir, "raw")
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "fetch_page_lib.R"))
# A sheet is accepted only if it is whole: (1) the final line has as many fields as the header (a
# cut-off download ends mid-row), (2) the newest poll is within 30 days before polling day (a
# truncated or stale sheet stops early), (3) ALP and LNP are filled on >= 90% of poll rows.
# Returns NA when fine, else the reason. The same check runs on a file already on disk.
validate_sheet <- function(path, polling_day) {
  if (!file.exists(path) || file.size(path) == 0) return("missing or empty")
  nf <- tryCatch(utils::count.fields(path, sep = ",", quote = "\"", blank.lines.skip = TRUE), error = function(e) NULL)
  if (is.null(nf) || length(nf) < 21) return("fewer than 21 lines or unreadable")
  if (nf[length(nf)] != nf[1]) return(sprintf("final line has %d fields, header has %d (truncated)", nf[length(nf)], nf[1]))
  d <- tryCatch(fread(path, encoding = "UTF-8", showProgress = FALSE), error = function(e) NULL)
  if (is.null(d) || !all(c("DATE", "POLLSTER", "ALP", "LNP") %in% names(d))) return("expected columns DATE, POLLSTER, ALP, LNP not found")
  d <- d[tolower(POLLSTER) != "election"]
  dt <- as.Date(d$DATE, format = "%d/%m/%Y")
  if (anyNA(dt)) return("unparseable dates")
  gap <- as.integer(polling_day - max(dt))
  if (gap < 0 || gap > 30) return(sprintf("newest poll is %d days before polling day (need 0 to 30)", gap))
  cov <- mean(is.finite(suppressWarnings(as.numeric(d$ALP))) & is.finite(suppressWarnings(as.numeric(d$LNP))))
  if (cov < 0.9) return(sprintf("ALP and LNP present on only %.0f%% of poll rows (need 90%%)", 100 * cov))
  NA_character_
}
ua <- "Mozilla/5.0 auspol-research/1.0 (contact: fptpost@gmail.com)"
sheets <- data.table(
  election = c("nsw2019", "vic2018"), region = c("nsw", "vic"),
  sheet_id = c("1zwqzVu5J3Xx0Rd8UzmV44PAIGN1ez1CLYGwEsdBfFe4", "1DN2V1AkSSUGrgqhzkraN9sBlVRZJq9jUV7PHC6BRapI"),
  page = c("https://www.pollbludger.net/nsw2019/polltracker.htm", "https://www.pollbludger.net/vic2018/polltracker.htm"),
  polling_day = as.Date(c("2019-03-23", "2018-11-24")))
out <- list()
for (i in seq_len(nrow(sheets))) {
  f <- file.path(raw_dir, sprintf("pollbludger_%s_sheet_gid0.csv", sheets$election[i]))
  pd <- sheets$polling_day[i]
  if (!file.exists(f) || file.size(f) == 0) {
    message("Fetching ", sheets$election[i])
    url <- sprintf("https://docs.google.com/spreadsheets/d/%s/gviz/tq?tqx=out:csv&gid=0", sheets$sheet_id[i])
    r <- fetch_page(url, f, ua, complete = function(p) is.na(validate_sheet(p, pd)))
    if (r$status != "on_disk") stop(sprintf("%s sheet not saved: status %s (HTTP %s); nothing written to raw/", sheets$election[i], r$status, r$code))
    Sys.sleep(1)
  }
  why <- validate_sheet(f, pd)
  if (!is.na(why)) stop(sprintf("%s sheet on disk is not acceptable: %s", sheets$election[i], why))
  d <- fread(f, encoding = "UTF-8")
  stopifnot(all(c("DATE", "POLLSTER") %in% names(d)), nrow(d) > 20)
  d[, `:=`(election = sheets$election[i], region = sheets$region[i], source_url = sheets$page[i],
           date = as.Date(DATE, format = "%d/%m/%Y"))]
  stopifnot(!anyNA(d$date))                                   # a date read in the wrong order would be NA or absurd
  stopifnot(all(d$date >= as.Date("2010-01-01") & d$date <= as.Date("2019-12-31")))
  out[[i]] <- d
}
pb <- rbindlist(out, fill = TRUE)
pb[, row_type := fifelse(tolower(POLLSTER) == "election", "result", "poll")]
# ALP/LNP/GRN primaries are named columns in both sheets; ALP2/LNP2 are the two-party figures.
for (cn in c("ALP", "LNP", "GRN", "ALP2", "LNP2")) pb[[cn]] <- suppressWarnings(as.numeric(pb[[cn]]))
setnames(pb, c("ALP", "LNP", "GRN", "ALP2", "LNP2"), c("alp_fp", "lnp_fp", "grn_fp", "alp_tpp", "lnp_tpp"))
setcolorder(pb, c("election", "region", "row_type", "date", "POLLSTER", "alp_fp", "lnp_fp", "grn_fp", "alp_tpp", "lnp_tpp"))
fwrite(pb, file.path(base_dir, "pollbludger_polls.csv"))
cat(sprintf("PB1  wrote %d rows (%d polls) to %s/pollbludger_polls.csv\n", nrow(pb), sum(pb$row_type == "poll"), base_dir))
print(pb[row_type == "poll", .(polls = .N, first = min(date), last = max(date), with_alp_lnp = sum(is.finite(alp_fp) & is.finite(lnp_fp))), by = election])
print(pb[row_type == "poll", .N, by = .(election, POLLSTER)][order(election, -N)])
