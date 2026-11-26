# Inputs for the upper-house vote model (R/upper_house_vote.R; docs/plans/upper-house-vote-model-2026-11-26.md).
# Writes two small files so the daily upper-house build never reads the 20 MB council files:
#   external/reference/vec/upper-house-ratio-inputs.csv  election, region, district, cls, upper, lower (votes)
#     Victorian Legislative Council vs Legislative Assembly first preferences by district, 2010, 2018, 2022.
#   external/reference/vec/upper-house-group-totals-2018.csv  2018 council first preferences by region and group
#     (the 2022 file already exists under vec/2022/), for the minor-group regional-pattern backtest.
#   external/reference/vec/upper-house-onp-sources.csv    One Nation upper vs lower by federal state-election
#     (Senate vs House ordinary votes, divisions where One Nation stood in both) and Victoria 2022.
#   Rscript scripts/build_upper_house_ratio_inputs.R [--src=output] [--raw=external/reference/vec]
options(auspol.root = normalizePath(".")); suppressMessages(devtools::load_all(quiet = TRUE))
suppressPackageStartupMessages({ library(data.table); library(readxl) })
a <- commandArgs(trailingOnly = TRUE)
SRC <- { h <- grep("^--src=", a, value = TRUE); if (length(h)) sub("^--src=", "", h) else "output" }
RAW <- { h <- grep("^--raw=", a, value = TRUE); if (length(h)) sub("^--raw=", "", h) else "external/reference/vec" }   # the 2010 .xls (gitignored)
num <- function(v) suppressWarnings(as.numeric(gsub(",", "", v)))
cand <- fread(file.path(SRC, "candidacies.csv"), select = c("election", "seat", "party", "votes", "ordinary"), showProgress = FALSE)

## ---- Victoria: council by district ----
up <- list()
for (y in c(2018, 2022)) {
  g <- fread(file.path(SRC, sprintf("council-fp-%d.csv", y)), select = c("region", "district", "block_kind", "row_kind", "group_name", "total"), showProgress = FALSE)
  d <- g[block_kind == "district_total" & row_kind %in% c("group", "ungrouped")]
  d[, cls := ifelse(row_kind == "ungrouped", "IND", classify_party(group_name))]
  d[, district := sub(" District$", "", district)]
  if (y == 2018) fwrite(d[row_kind == "group", .(votes = sum(total)), by = .(region, group_name)], "external/reference/vec/upper-house-group-totals-2018.csv")
  up[[as.character(y)]] <- d[, .(upper = sum(total)), by = .(region, district, cls)][, election := paste0("vic", y)]
}
# 2010: one sheet per district; the block whose header is "<name> District Total" with ATL/BTL/Total columns is the total.
files <- Sys.glob(file.path(RAW, "state2010*RegionFPVbyVC.xls")); stopifnot(length(files) == 8L)
u10 <- list()
for (f in files) {
  reg <- sub("Region$", "", sub("^state2010(.*)FPVbyVC\\.xls$", "\\1", basename(f)))
  reg <- gsub("([a-z])([A-Z])", "\\1 \\2", reg); reg <- sub("South Eastern", "South-Eastern", reg)
  for (s in excel_sheets(f)) {
    x <- as.data.frame(suppressMessages(read_excel(f, sheet = s, col_names = FALSE, col_types = "text")))
    x[is.na(x)] <- ""
    hdr <- which(grepl(" District Total$", x[[2]]) & x[[11]] == "ATL")
    if (!length(hdr)) next
    h <- max(hdr); dist <- sub(" District Total$", "", x[h, 2]); i <- h + 1L; rows <- list()
    while (i <= nrow(x) && grepl("^GROUP |^UNGROUPED|^Ungrouped", x[i, 2])) { rows[[length(rows) + 1]] <- data.table(group_name = sub("^GROUP [A-Z]+ - ", "", x[i, 2]), upper = num(x[i, 14])); i <- i + 1L }
    stopifnot(length(rows) > 0, x[i, 2] == "Informal")                    # the block ended where it should
    r <- rbindlist(rows); r[, cls := ifelse(grepl("^UNGROUPED", toupper(group_name)), "IND", classify_party(group_name))]
    u10[[paste(reg, dist)]] <- r[, .(upper = sum(upper)), by = cls][, `:=`(election = "vic2010", region = reg, district = dist)]
  }
}
u10 <- rbindlist(u10)
cat(sprintf("UHI1  2010 council: %d districts in %d regions, %.0f formal votes\n", uniqueN(u10$district), uniqueN(u10$region), sum(u10$upper)))
stopifnot(uniqueN(u10$district) == 88L, !anyNA(u10$upper))
U <- rbind(rbindlist(up), u10)
L <- cand[election %in% c("vic2010", "vic2018", "vic2022"), .(lower = sum(votes)), by = .(election, district = seat, cls = party)]
M <- merge(U, L, by = c("election", "district", "cls"), all = TRUE)
M[, region := region[!is.na(region)][1], by = .(election, district)]
miss <- M[, .(u = any(!is.na(upper)), l = any(!is.na(lower))), by = .(election, district)][!(u & l)]
if (nrow(miss)) { cat("UHI2  districts present on one side only (dropped):\n"); print(miss) }
M <- M[!miss, on = .(election, district)]
M[is.na(upper), upper := 0]; M[is.na(lower), lower := 0]
stopifnot(!anyNA(M$region))
for (e in unique(M$election)) cat(sprintf("UHI3  %s: %d districts, %d regions, upper %.0f votes, lower %.0f votes\n", e,
  uniqueN(M[election == e]$district), uniqueN(M[election == e]$region), sum(M[election == e]$upper), sum(M[election == e]$lower)))
fwrite(M[order(election, region, district, cls)], "external/reference/vec/upper-house-ratio-inputs.csv")

## ---- One Nation sources: federal Senate vs House by state-election, plus Victoria 2022 ----
sen <- fread(file.path(SRC, "senate-by-division-class.csv"), showProgress = FALSE)[cls == "ONP"]
sen[, election := paste0("fed", fed)]
ho <- cand[grepl("^fed", election) & !is.na(ordinary)]
ho[, tot := sum(as.numeric(ordinary)), by = .(election, seat)]
ho <- ho[party == "ONP", .(lower = 100 * sum(as.numeric(ordinary)) / tot[1]), by = .(election, division = seat)]
f <- merge(ho, sen[, .(election, state, division, upper = senate_pct)], by = c("election", "division"))
f <- f[lower > 0 & upper > 0]
src <- f[, .(n = .N, lower = mean(lower), upper = mean(upper), log_ratio = log(sum(upper) / sum(lower)),
             se = sd(log(upper / lower)) / sqrt(.N)), by = .(source = paste(election, state))][, kind := "federal Senate vs House"]
v <- M[election == "vic2022", .(upper = 100 * sum(upper[cls == "ONP"]) / sum(upper), lower = 100 * sum(lower[cls == "ONP"]) / sum(lower)), by = district][lower > 0 & upper > 0]
src <- rbind(src, v[, .(source = "vic2022 Victoria", kind = "Victorian council vs assembly", n = .N, lower = mean(lower), upper = mean(upper),
                        log_ratio = log(sum(upper) / sum(lower)), se = sd(log(upper / lower)) / sqrt(.N))])
# Other states' upper houses (output/other-upper-house-fp.csv, branch other-upper-houses 82039762). One Nation's
# ratio only over districts where it stood for the lower house: a statewide ratio is diluted by seats with no One
# Nation candidate (NSW 2019 statewide 6.3). sa2022 has statewide upper rows only, so it cannot be restricted: out.
OTH <- file.path(SRC, "other-upper-house-fp.csv")
nt <- NULL
if (file.exists(OTH)) {
  o <- fread(OTH, showProgress = FALSE)
  od <- o[geo_level == "district"]
  cont <- od[house == "lower" & party_class == "ONP" & votes > 0, .(election, geo)]
  tt <- unique(od[, .(election, house, geo, total_votes)])
  on <- od[party_class == "ONP", .(votes = sum(votes)), by = .(election, house, geo)]
  x <- merge(merge(tt, cont, by = c("election", "geo")), on, by = c("election", "house", "geo"), all.x = TRUE)
  x[is.na(votes), votes := 0]; x[, sh := 100 * votes / total_votes]
  x <- dcast(x, election + geo ~ house, value.var = "sh")[lower > 0 & upper > 0]
  os <- x[, .(n = .N, lower = mean(lower), upper = mean(upper), log_ratio = log(sum(upper) / sum(lower)), se = sd(log(upper / lower)) / sqrt(.N)),
          by = .(source = paste(election, "contested districts"))]
  os[, kind := ifelse(grepl("^wa2021", source), "other state upper vs lower (tickets)", "other state upper vs lower (no tickets)")]   # WA abolished tickets for 2025
  cat(sprintf("UHI5  other states: %d One Nation units from %s (districts where One Nation stood for the lower house)\n", nrow(os), OTH))
  src <- rbind(src, os)
  # No-ticket natural experiments for the majors: WA 2021 (tickets) -> 2025 (none), statewide.
  st <- o[geo_level == "state" & election %in% c("wa2021", "wa2025"), .(v = sum(votes)), by = .(election, house, cls = party_class)]
  st[, sh := v / sum(v), by = .(election, house)]
  nt <- dcast(st[cls %in% c("ALP", "LNP", "GRN")], election + cls ~ house, value.var = "sh")[, .(case = "WA Legislative Council", election, cls, ratio = upper / lower)]
} else cat(sprintf("UHI5  %s not found: no other-state units, no WA ticket experiment\n", OTH))
# Federal Senate tickets abolished between 2013 and 2016: Victorian Senate vs House ordinary votes, majors.
sm <- fread(file.path(SRC, "senate-by-division-class.csv"), showProgress = FALSE)[state == "VIC" & fed %in% c(2013, 2016)]
hv <- cand[election %in% c("fed2013", "fed2016") & !is.na(ordinary) & seat %in% sm$division, .(v = sum(as.numeric(ordinary))), by = .(election, cls = party)]
hv[, sh := v / sum(v), by = election]
sv <- sm[, .(v = sum(v)), by = .(election = paste0("fed", fed), cls)][, sh := v / sum(v), by = election]
fv <- merge(hv, sv, by = c("election", "cls"), suffixes = c("_l", "_u"))[cls %in% c("ALP", "LNP", "GRN"), .(case = "Victorian Senate", election, cls, ratio = sh_u / sh_l)]
nt <- rbind(nt, fv)
fwrite(nt, "external/reference/vec/upper-house-noticket-experiments.csv")
cat(sprintf("UHI6  no-ticket experiments: %d rows (%s)\n", nrow(nt), paste(unique(nt$case), collapse = ", ")))
cat(sprintf("UHI4  One Nation sources: %d (federal state-elections with >= 1 paired division: %d)\n", nrow(src), sum(src$kind == "federal Senate vs House")))
fwrite(src, "external/reference/vec/upper-house-onp-sources.csv")
cat("UHI9  wrote external/reference/vec/upper-house-ratio-inputs.csv, upper-house-onp-sources.csv, upper-house-noticket-experiments.csv\n")
