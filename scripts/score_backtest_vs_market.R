# Score our backtest seat probabilities against bookmaker seat odds Pete saved at the time.
# Metric: log loss of the actual winner's class (clamped at 1e-6, as everywhere in auspol); lower is better.
suppressMessages({ library(data.table); library(oddsdata) })
H <- "external/reference/historical-odds"
P <- file.path(H, "petes-2022-scrapes")

cls <- function(x) {
  y <- fcase(grepl("^Labor$", x, TRUE), "ALP",
             grepl("^(Coalition|Liberal National Party|The Nationals|Liberal|Nationals?)$", x, TRUE), "LNP",
             grepl("^Greens?$", x, TRUE), "GRN", grepl("^One Nation$", x, TRUE), "ONP",
             grepl("^(Independent|ind)\\b", x, TRUE), "IND", grepl("^Centre Alliance$", x, TRUE), "IND",
             grepl("^Katter", x, TRUE), "OTH_RIGHT",
             grepl("^(Other|Any Other|Any Other Candidate|any_other)$", x, TRUE), "ANY_OTHER",
             default = "OTH")
  y
}
key <- function(s) gsub("[^a-z]", "", tolower(sub(" *\\(.*$| - .*$", "", s)))
long_wide <- function(f, seatcol, cols) {
  w <- fread(f); w <- w[, c(seatcol, cols), with = FALSE]
  l <- melt(w, id.vars = seatcol, variable.name = "party", value.name = "odds", variable.factor = FALSE)
  setnames(l, seatcol, "seat"); l[odds < 999]
}
books <- list(
  fed2022 = list(
    sportsbet = as.data.table(readRDS(file.path(P, "2022-05-20_sb_afe22.rds")))[, .(seat = electorate, party, odds)],
    tab       = as.data.table(readRDS(file.path(P, "2022-05-20_tab_afe22.rds")))[, .(seat = location, party, odds)]),
  fed2025 = list(
    sportsbet = long_wide(file.path(H, "afe2025/sportsbet_wide.csv"), "electorate",
                          c("Coalition", "Labor", "Any Other Candidate", "Independent", "Greens", "One Nation", "Katter's Australian Party", "Centre Alliance")),
    tab       = long_wide(file.path(H, "afe2025/tab_wide.csv"), "seat",
                          c("labor", "coalition", "any other", "ind", "greens", "one nation", "katters ap", "centre alliance")),
    betr      = long_wide(file.path(H, "afe2025/betr_wide.csv"), "seat",
                          c("coalition", "labor", "any_other", "independent", "greens", "one_nation", "centre_alliance"))),
  sa2022  = list(sportsbet = as.data.table(readRDS(file.path(P, "2022-03-18_SA_election_2022.rds")))[, .(seat = electorate, party, odds)]),
  qld2020 = list(unnamed  = as.data.table(readxl::read_excel(file.path(P, "Queensland_state_election_2020.xlsx"), "data"))[, .(seat = Place, party = Party, odds = Odds)])
)
dates <- c(fed2022 = "2022-05-20 (election 21 May)", fed2025 = "2025-04-22/23 (election 3 May)",
           sa2022 = "2022-03-18 (election 19 Mar)", qld2020 = "file saved 2020-10-28 (election 31 Oct)")
# party labels in the 2025 wide files
fix25 <- c(labor = "Labor", coalition = "Coalition", `any other` = "Other", any_other = "Other", ind = "Independent",
           independent = "Independent", greens = "Greens", `one nation` = "One Nation", one_nation = "One Nation",
           `katters ap` = "Katter", centre_alliance = "Centre Alliance", `centre alliance` = "Centre Alliance")

ours_all <- fread("output/biggest-misses.csv")[metric == "logloss", .(pair, seat, win = party, ours = as.numeric(ours))]
res <- list(); per <- list()
for (pr in names(books)) {
  ours <- ours_all[pair == pr][, k := key(seat)]
  stopifnot(nrow(ours) > 0, !anyDuplicated(ours$k))
  mk <- list()
  for (b in names(books[[pr]])) {
    x <- copy(books[[pr]][[b]])
    x[party %in% names(fix25), party := fix25[party]]
    x[, k := key(seat)][k == "mcphrsn", k := "mcpherson"]
    # a price <= 1 is a truncated favourite: removing just it would let the margin removal inflate the longshots,
    # so the whole seat leaves this book
    badk <- unique(x[is.na(odds) | odds <= 1, k])
    if (length(badk)) cat(sprintf("MV1 %s %s: %d seats dropped for a price <= 1 or missing: %s\n", pr, b, length(badk), paste(badk, collapse = ", ")))
    x <- x[!k %in% badk][, cl := cls(party)]
    # TAB 2022 carries one stray row, One Nation 101 under "Murray" (the pre-2018 name of Nicholls); Nicholls is priced separately
    if (pr == "fed2022" && b == "tab" && any(x$k == "murray")) {
      cat(sprintf("MV1 fed2022 tab: dropped %d stray row(s) under 'Murray'\n", sum(x$k == "murray"))); x <- x[k != "murray"] }
    miss <- setdiff(unique(x$k), ours$k)
    if (length(miss)) stop(sprintf("MV2! %s %s seats not in our backtest: %s", pr, b, paste(miss, collapse = ", ")))
    ip <- implied_probs(x[, .(source = b, fetched_utc = "x", market_id = k, selection = paste(party, seq_len(.N)), price = odds, k, cl)], "power")
    agg <- ip[, .(p = sum(prob)), by = .(k, cl)]
    m <- merge(ours[, .(k, seat, win)], agg, by.x = c("k", "win"), by.y = c("k", "cl"), all.x = TRUE)
    # winner's class not listed by name: the bookie's "any other" runner is the price on that candidate
    oth <- agg[cl == "ANY_OTHER", .(k, po = p)]
    m <- merge(m, oth, by = "k", all.x = TRUE)
    m[, via_other := is.na(p) & !is.na(po)][via_other == TRUE, p := po]
    m <- m[k %in% unique(x$k)]
    if (any(m$via_other)) cat(sprintf("MV3 %s %s: winner priced via 'any other' in %d seats: %s\n", pr, b, sum(m$via_other), paste(m[via_other == TRUE, seat], collapse = ", ")))
    m[is.na(p), p := 0]
    mk[[b]] <- m[, .(k, p)][, book := b]
  }
  mm <- rbindlist(mk)[, .(mkt = mean(p), nbooks = .N), by = k]      # average over books pricing the seat
  d <- merge(ours, mm, by = "k")
  cat(sprintf("MV4 %s: %d of %d backtest seats priced; odds date %s\n", pr, nrow(d), nrow(ours), dates[[pr]]))
  ll <- function(p) -log(pmax(p, 1e-6))
  d[, `:=`(ll_ours = ll(ours), ll_mkt = ll(mkt), ll_blend = ll((ours + mkt) / 2))]
  per[[pr]] <- d[, pair := pr]
  dif <- d$ll_ours - d$ll_mkt
  res[[pr]] <- data.table(pair = pr, seats = nrow(d), books = paste(names(books[[pr]]), collapse = "+"),
    ours = mean(d$ll_ours), market = mean(d$ll_mkt), blend = mean(d$ll_blend),
    ours_minus_mkt = mean(dif), se = sd(dif) / sqrt(nrow(d)),
    ours_fav_right = mean(d$ours > 0.5), mkt_fav_right = mean(d$mkt > 0.5))
}
r <- rbindlist(res)
print(r[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 4) else v)])
all <- rbindlist(per)
cat(sprintf("\nPOOLED %d seats: ours %.4f  market %.4f  50/50 blend %.4f\n", nrow(all), mean(all$ll_ours), mean(all$ll_mkt), mean(all$ll_blend)))
cat("\nseats where we were most wrong relative to the market (ours far below market on the winner):\n")
print(all[order(ll_mkt - ll_ours)][1:12, .(pair, seat, winner = win, ours = round(ours, 3), market = round(mkt, 3))])
cat("\nseats where the market was most wrong relative to us:\n")
print(all[order(ll_ours - ll_mkt)][1:12, .(pair, seat, winner = win, ours = round(ours, 3), market = round(mkt, 3))])
fwrite(all, "output/backtest-vs-market-seats.csv")
