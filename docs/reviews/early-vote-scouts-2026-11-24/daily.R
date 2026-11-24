suppressPackageStartupMessages(library(data.table))
d <- "external/reference/aec/prepoll-daily"
wide <- function(f, el, fmt = "%d/%m/%Y") { x <- fread(file.path(d, f), encoding = "UTF-8", header = TRUE); setnames(x, 1:3, c("state", "seat", "ppvc"))
  m <- melt(x, id.vars = c("state", "seat", "ppvc"), variable.name = "day", value.name = "n", variable.factor = FALSE)
  m[, `:=`(date = as.Date(day, format = fmt), n = suppressWarnings(as.numeric(n)), election = el)]; m[, .(election, seat, date, n)] }
long <- function(f, el, fmt) { x <- fread(file.path(d, f), encoding = "UTF-8"); setnames(x, c("state", "seat", "ppvc", "day", "n"))
  x[, .(election = el, seat, date = as.Date(day, format = fmt), n = as.numeric(n))] }
A <- rbind(wide("20160702_WEB_Pre-Poll_Report.csv", "fed2016", "%Y-%m-%d"), wide("20190518_WEB_Pre-poll_Report_FE2019.csv", "fed2019"),
           long("20220620_WEB_FINAL_Pre-poll_report_FE2022.csv", "fed2022", "%d/%m/%y"), long("pre-pollvotesissued_final_FE25.csv", "fed2025", "%d/%m/%Y"))
cat("rows with unparsed date:", sum(is.na(A$date)), " unparsed count:", sum(is.na(A$n)), "\n")
A <- A[!is.na(date) & !is.na(n)]
print(A[, .(seats = uniqueN(seat), days = uniqueN(date), first = min(date), last = max(date), issued = sum(n)), by = election])
A[, rk := frank(-as.numeric(date), ties.method = "dense"), by = election]   # 1 = last day
A[, ndays := max(rk), by = election]
F <- A[, .(issued = sum(n), late3 = sum(n[rk <= 3]) / sum(n), first_half = sum(n[rk > ndays / 2]) / sum(n), last_day = sum(n[rk == 1]) / sum(n)), by = .(election, seat)]
pred <- fread("output/published-predictions.csv", encoding = "UTF-8")[grepl("^fed", pair), .(ours = sum(ours), actual = sum(actual)), by = .(election = pair, seat, party)]
pred[, miss := actual - ours]
tot <- fread("output/early-vote/panel-seat.csv")[, .(election, seat, tot, early)]
F <- merge(F, tot, by = c("election", "seat"), all.x = TRUE)
F[, issued_rate := issued / tot]
cat("check: issued pre-poll vs counted early votes in the panel, correlation by election (should be high):\n")
print(F[, .(n = .N, matched = sum(!is.na(tot)), r = round(cor(issued, early, use = "complete.obs"), 3), ratio = round(sum(issued) / sum(early, na.rm = TRUE), 3)), by = election])
setorder(F, seat, election); F[, d_late3 := late3 - shift(late3), by = seat]
D <- merge(pred, F, by = c("election", "seat"))
feats <- c("late3", "first_half", "last_day", "issued_rate", "d_late3")
cat("\nWithin-election correlation of each daily-shape feature with our miss (actual - predicted primary), by party.\n",
    "late3 = share of pre-poll votes issued in the final 3 days; first_half = share in the first half of the period;\n",
    "last_day = share on the final day; issued_rate = pre-poll issued / formal votes; d_late3 = change in late3 since last election.\n",
    "About +-0.16 is 2 SE for one election of 150 seats; pooled over 4 elections about +-0.08.\n", sep = "")
out <- rbindlist(lapply(feats, function(f) rbindlist(lapply(c("ALP", "LNP", "GRN", "IND", "ONP", "OTH_RIGHT"), function(tg) {
  x <- D[party == tg & is.finite(get(f))]
  x[, `:=`(fz = get(f) - mean(get(f)), m = miss - mean(miss)), by = election]
  per <- x[, .(r = cor(fz, m)), by = election]
  data.table(feature = f, party = tg, seats = nrow(x), pooled_r = round(cor(x$fz, x$m), 3),
             by_election = paste(sprintf("%s %+.2f", sub("fed", "", per$election), per$r), collapse = "  "))
}))))
print(out, nrows = 100)
fwrite(F, "output/early-vote/fed-prepoll-daily-features.csv")
