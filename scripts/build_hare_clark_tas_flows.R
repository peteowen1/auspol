# build_hare_clark_tas_flows.R -- Tasmanian party transfer counts from the TEC's own distribution of
# preferences (the "Export Count" workbooks for 2024 and 2025, sheet ScrutinyScreen, Table I = ballot papers).
#
#   Rscript scripts/build_hare_clark_tas_flows.R
#
# For every transfer in every division (a surplus or an exclusion, "NAC after <SURNAME>"), the papers that
# went to the source candidate's own ticket, to each other ticket, and exhausted. A ticket is a column group
# of Table I ("Greens", "ALP", "LIB", "JLN", "Group B", "Ungrouped", ...).
#
# Output: output/hare-clark-tas-flows.csv  year, electorate, count, source, src_group, src_class, to_group,
#         to_class (or SAME / EXH), papers.  Classes via classify_party() on the group label.
# CHECK: HCF1 papers out of each count = papers in (total counted at that count), per division.

suppressPackageStartupMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
ref <- file.path("external", "reference", "tas", "raw", "tec")
grp_class <- function(g) {
  g2 <- c(ALP = "Labor", LIB = "Liberal", Greens = "Greens", JLN = "Jacqui Lambie Network",
          `Tas SFFP` = "Shooters Fishers and Farmers", SFF = "Shooters Fishers and Farmers",
          NAT = "Nationals", Nationals = "Nationals", AJP = "Animal Justice")[g]
  out <- classify_party(ifelse(is.na(g2), ifelse(grepl("^Group|^Ungrouped", g), "", g), g2))
  # the Tasmanian Nationals ran against the Liberals: minor right here, as in build_hare_clark_data.R
  out[grepl("^nat", tolower(g))] <- "OTH_RIGHT"
  out
}
rows <- list(); fails <- 0L
for (y in c(2024L, 2025L)) {
  for (f in list.files(file.path(ref, y), pattern = "Export.*\\.xlsx$", full.names = TRUE)) {
    e <- sub("^.*Division of ([A-Za-z]+).*$", "\\1", basename(f))
    x <- as.matrix(suppressMessages(readxl::read_excel(f, sheet = "ScrutinyScreen", col_names = FALSE,
                                                       .name_repair = "minimal")))
    hdr <- which(trimws(x[, 2]) == "Count")[1]
    lab <- x[hdr - 1L, ]; nm <- x[hdr, ]
    jx <- which(grepl("Exhausted at Count", nm))[1]
    jt <- which(grepl("Total Ballot Papers Counted", nm))[1]
    cols <- 4:(jx - 1L)
    grp <- character(length(nm)); cur <- NA_character_
    for (j in cols) { if (!is.na(lab[j])) cur <- lab[j]; grp[j] <- cur }
    tot_cols <- cols[grepl("Totals$", nm[cols])]
    cand_cols <- setdiff(cols, tot_cols)
    num <- function(v) suppressWarnings(as.numeric(v))
    for (i in which(grepl("^NAC after ", x[, 3]))) {
      src <- sub("^NAC after ", "", trimws(x[i, 3]))
      r <- i + 1L                                   # the count row with the papers
      js <- cand_cols[toupper(nm[cand_cols]) == toupper(src)]
      if (length(js) != 1L) { cat(sprintf("HCF0  %s %d %s: source %s matched %d columns, skipped\n", e, y, x[r, 2], src, length(js))); next }
      sg <- grp[js]
      pt <- num(x[r, tot_cols]); pt[is.na(pt)] <- 0
      ex <- num(x[r, jx]); ex[is.na(ex)] <- 0
      tc <- num(x[r, jt])
      ok <- isTRUE(abs(sum(pt) + ex - tc) < 0.5)
      if (!ok) { fails <- fails + 1L; cat(sprintf("HCF1 FAIL  %s %d count %s: %s + %s exhausted vs %s\n", e, y, x[r, 2], sum(pt), ex, tc)) }
      tg <- grp[tot_cols]
      rows[[length(rows) + 1L]] <- data.table(year = y, electorate = e, count = num(x[r, 2]), source = src,
        src_group = sg, to_group = c(tg, "EXH"), papers = c(pt, ex))
    }
  }
}
fl <- rbindlist(rows)
fl[, src_class := grp_class(src_group)]
fl[, to_class := ifelse(to_group == "EXH", "EXH", ifelse(to_group == src_group, "SAME", grp_class(to_group)))]
cat(sprintf("HCF1 %s  %d transfers parsed, %s papers moved; per-count conservation failures %d\n",
            if (fails == 0L) "PASS" else "FAIL", uniqueN(fl[, .(year, electorate, count)]),
            format(sum(fl$papers), big.mark = ","), fails))
print(fl[, .(papers = sum(papers)), by = .(year, src = hc_score_class(src_class), to = ifelse(to_class %in% c("SAME", "EXH"), to_class, hc_score_class(to_class)))][
  , share := round(papers / sum(papers), 3), by = .(year, src)][order(year, src, -papers)])
fwrite(fl, "output/hare-clark-tas-flows.csv")
if (fails) quit(status = 1L)
