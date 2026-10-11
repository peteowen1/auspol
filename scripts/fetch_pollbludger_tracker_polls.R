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
base_dir <- "external/reference/polls/statewide-samples"
raw_dir <- file.path(base_dir, "raw")
ua <- "Mozilla/5.0 auspol-research/1.0 (contact: fptpost@gmail.com)"
sheets <- data.table(
  election = c("nsw2019", "vic2018"), region = c("nsw", "vic"),
  sheet_id = c("1zwqzVu5J3Xx0Rd8UzmV44PAIGN1ez1CLYGwEsdBfFe4", "1DN2V1AkSSUGrgqhzkraN9sBlVRZJq9jUV7PHC6BRapI"),
  page = c("https://www.pollbludger.net/nsw2019/polltracker.htm", "https://www.pollbludger.net/vic2018/polltracker.htm"))
out <- list()
for (i in seq_len(nrow(sheets))) {
  f <- file.path(raw_dir, sprintf("pollbludger_%s_sheet_gid0.csv", sheets$election[i]))
  if (!file.exists(f) || file.size(f) == 0) {
    message("Fetching ", sheets$election[i])
    url <- sprintf("https://docs.google.com/spreadsheets/d/%s/gviz/tq?tqx=out:csv&gid=0", sheets$sheet_id[i])
    download.file(url, f, method = "libcurl", headers = c(`User-Agent` = ua), quiet = TRUE)
    Sys.sleep(1)
  }
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
