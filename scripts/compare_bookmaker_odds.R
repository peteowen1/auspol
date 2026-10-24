# compare_bookmaker_odds.R -- one row per Victorian seat: the best price for every outcome across
# Sportsbet, TAB and Betfair, whether backing all of them would lock in a profit (an arbitrage), each
# bookie's own margin, and the bookies' favourite beside ours.
#
#   Rscript scripts/compare_bookmaker_odds.R [--date=YYYY-MM-DD]
#
# Reads the raw captures scripts/snapshot_benchmarks.R saved under
# external/reference/benchmarks/vic2026/<date>/ and writes
# docs/benchmarks/vic2026/<date>/bookmaker-odds.csv (committed; about 60 rows).
# snapshot_benchmarks.R runs this at its end, so every freeze date gets one.
#
# "Best odds combined %" is the sum of 1/best price over the outcomes, as a percentage: what it costs
# to collect $100 whoever wins. Under 100 is an arbitrage. A Coalition win IS a Liberal or National
# win, so that outcome is covered once, by the cheaper of "Coalition" and "Liberal + Nationals".
# Outcome lists that overlap between books only over-cover, so the total is a safe upper bound.
#
# Check codes: VB16 (inputs and coverage), VB17 (result).

suppressMessages({ library(data.table); library(oddsdata) })

args <- commandArgs(trailingOnly = TRUE)
DAY <- sub("^--date=", "", grep("^--date=", args, value = TRUE))
if (!length(DAY)) DAY <- format(Sys.time(), "%Y-%m-%d", tz = "UTC")
RAW <- file.path("external", "reference", "benchmarks", "vic2026", DAY)
OUT <- file.path("docs", "benchmarks", "vic2026", DAY, "bookmaker-odds.csv")
if (!dir.exists(RAW)) stop("VB16! no captures for ", DAY, " at ", RAW)

rd <- function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
newest <- function(src, pat) {
  f <- sort(list.files(file.path(RAW, src), pat, full.names = TRUE))
  if (length(f)) tail(f, 1) else NA_character_
}
books <- list(
  sportsbet = function(f) sb_parse_markets(rd(f), "x")[, seat := market],
  tab       = function(f) tab_parse_markets(rd(f))[market == "Seat Winner"][, seat := sub(" State Election$", "", event)],
  betfair   = function(f) bf_parse_prices(rd(f))[event == "Individual Electorates"][, seat := sub("^Seat of ", "", market)]
)
pats <- c(sportsbet = "^event-.*-markets-.*json$", tab = "^Politics-Victorian-Politics.*\\.json$", betfair = "^markets-.*json$")
man <- fread(file.path(RAW, "manifest.tsv"), sep = "\t")
got <- list()
for (src in names(books)) {
  f <- newest(src, pats[[src]])
  if (is.na(f)) { cat(sprintf("VB16! %s: no capture for %s -- left out\n", src, DAY)); next }
  x <- books[[src]](f)
  # the parsers stamp parse time; the fetch time is in the manifest
  ft <- man$fetched_utc[man$file == file.path(src, basename(f))]
  cat(sprintf("VB16  %s: %d seats, %d prices, fetched %s (%s)\n", src, uniqueN(x$seat), nrow(x),
              if (length(ft)) ft[1] else "NOT IN MANIFEST", basename(f)))
  if (!nrow(x)) stop("VB16! ", src, " capture parsed to zero seat prices: ", f)
  got[[src]] <- x
}
if (length(got) < 2L) stop("VB16! fewer than two bookies captured for ", DAY, ": nothing to compare")

# outcome key per selection: Liberal and Nationals are separate outcomes for an arbitrage
okey <- function(x) fcase(
  grepl("^Labor$", x), "ALP", grepl("^Liberals?$", x), "LIB", grepl("^Nationals?$", x), "NAT",
  grepl("^Coalition$", x), "COAL", grepl("^Gre+ns$", x), "GRN", grepl("^One Nation$", x), "ONP",
  grepl("^Independent", x), paste0("IND:", sub("^Independent *", "", x)), grepl("^(Any )?Other", x), "OTHER")
all <- rbindlist(got, fill = TRUE)[, key := okey(selection)]
if (anyNA(all$key)) stop("VB16! selections with no outcome key: ", paste(unique(all[is.na(key), selection]), collapse = ", "))
all[, seat := toupper(trimws(seat))]
# for the top-4 table: TAB's "Coalition" is Sportsbet's "Liberal" in a seat with no Nationals runner
all[, key4 := fifelse(key == "COAL" & !any(key == "NAT"), "LIB", key), by = seat]

# our published forecast on the same day
ours <- fread(file.path(RAW, "ours", "seat-probs-vic-2026.csv"))[, seat := toupper(seat)]
miss <- setdiff(unique(all$seat), ours$seat)
if (length(miss)) stop("VB16! bookie seats not in our forecast (name mismatch?): ", paste(miss, collapse = ", "))

# margin removed (power method), collapsed to our party classes
p <- implied_probs(all, "power", by = c("source", "seat"))
p[, class := fifelse(key %in% c("LIB", "NAT", "COAL"), "LNP", sub(":.*", "", key))]
main <- c("ALP", "LNP", "GRN", "ONP")
p[!class %in% main, class := "OTHER+IND"]
pc <- p[, .(prob = sum(prob)), by = .(source, seat, class)]
# average over the books pricing the seat, an outcome a book does not list counting as 0 there
# (Betfair is thin: reported, not averaged in)
mk <- pc[source != "betfair"][, nb := uniqueN(source), by = seat][, .(mkt = sum(prob) / nb[1]), by = .(seat, class)]
stopifnot(mk[, abs(sum(mkt) - 1) < 1e-6, by = seat]$V1)
o2 <- ours[, .(ours = sum(prob)), by = .(seat, class = fifelse(party %in% main, party, "OTHER+IND"))]
fm <- mk[, .SD[which.max(mkt)], by = seat][, .(seat, mkt_fav = class, mkt_p = mkt)]
fo <- o2[seat %in% all$seat, .SD[which.max(ours)], by = seat][, .(seat, ours_fav = class, ours_p = ours)]

# arbitrage: best price per outcome across books
best <- all[, .(price = max(price, na.rm = TRUE), from = source[which.max(price)]), by = .(seat, key)]
lnp_cost <- function(k, pr) {
  q <- setNames(1 / pr, k)
  a <- if ("COAL" %in% k) q[["COAL"]] else Inf
  b <- if (any(c("LIB", "NAT") %in% k)) sum(q[intersect(c("LIB", "NAT"), k)]) else Inf
  if (is.infinite(min(a, b))) 0 else min(a, b)
}
arb <- best[, .(book = sum(1 / price[!key %in% c("LIB", "NAT", "COAL")]) + lnp_cost(key, price)), by = seat]
arb <- merge(arb, all[, .(n = uniqueN(source)), by = seat], by = "seat")

own <- dcast(all[, .(own = round(100 * sum(1 / price, na.rm = TRUE), 1)), by = .(seat, source)], seat ~ source, value.var = "own")
best[, cell := sprintf("%.2f %s", price, c(sportsbet = "SB", tab = "TAB", betfair = "BF")[from])]
best[grepl("^IND:", key), key := "IND"]
bw <- dcast(best, seat ~ key, value.var = "cell", fun.aggregate = function(x) paste(x, collapse = " / "), fill = "")

sheet <- Reduce(function(a, b) merge(a, b, by = "seat", all.x = TRUE),
                list(arb[, .(seat, n, pct = round(100 * book, 1))], own, bw, fm, fo))
sheet[, `:=`(mkt_p = round(mkt_p, 2), ours_p = round(ours_p, 2))]
setorder(sheet, pct)
sheet[, seat := tools::toTitleCase(tolower(seat))]
nm <- c(seat = "Seat", n = "Bookies pricing it", pct = "Best odds combined % (under 100 = arbitrage)",
        betfair = "Betfair own book %", sportsbet = "Sportsbet own book %", tab = "TAB own book %",
        ALP = "Labor best", LIB = "Liberal best", NAT = "Nationals best", COAL = "Coalition best", GRN = "Greens best",
        ONP = "One Nation best", IND = "Independent best", OTHER = "Any other best",
        mkt_fav = "Bookies favourite", mkt_p = "Bookies fav prob (margin removed)", ours_fav = "Our favourite", ours_p = "Our fav prob")
cols <- intersect(names(nm), names(sheet))
sheet <- sheet[, ..cols]
setnames(sheet, cols, nm[cols])
if (anyNA(sheet[["Our favourite"]])) stop("VB16! a seat has no favourite of ours after the merge")

dir.create(dirname(OUT), recursive = TRUE, showWarnings = FALSE)
fwrite(sheet, OUT)

# second table: each bookie's price for the top 4 outcomes in every seat (ranked by the bookies'
# average margin-removed probability, Sportsbet and TAB; Betfair where it is the only book)
lab <- c(ALP = "Labor", LIB = "Liberal", NAT = "Nationals", COAL = "Coalition", GRN = "Greens", ONP = "One Nation", OTHER = "Any other")
p[, nb := uniqueN(source[source != "betfair"]), by = seat]
kp <- p[source != "betfair" | nb == 0L, .(bk = sum(prob) / max(nb[1], 1L)), by = .(seat, key = key4)]   # unlisted at a book = 0 there
kp[, bk := bk / sum(bk), by = seat]
top4 <- kp[order(seat, -bk)][, head(.SD, 4L), by = seat]
pw <- dcast(all[, .(seat, key = key4, source, price)], seat + key ~ source, value.var = "price", fun.aggregate = max, fill = NA)
cand <- merge(top4, pw, by = c("seat", "key"), all.x = TRUE)
bst <- all[, .(best = max(price)), by = .(seat, key = key4)]
cand <- merge(cand, bst, by = c("seat", "key"))
cand[, class := fifelse(key %in% c("LIB", "NAT", "COAL"), "LNP", sub(":.*", "", key))]
cand[!class %in% main, class := "OTHER+IND"]
cand <- merge(cand, o2, by = c("seat", "class"), all.x = TRUE)
cand[is.na(ours), ours := 0]
cand[, outcome := fifelse(grepl("^IND:", key), paste("Independent", sub("^IND: *", "", key)), lab[key])]
cand[outcome == "Independent ", outcome := "Independent"]
setorder(cand, seat, -bk)
cand[, rank := seq_len(.N), by = seat]
cand[, seat := tools::toTitleCase(tolower(seat))]
for (s in c("sportsbet", "tab", "betfair")) if (!s %in% names(cand)) cand[, (s) := NA_real_]
cand <- cand[, .(Seat = seat, Rank = rank, Outcome = outcome, Sportsbet = sportsbet, TAB = tab, Betfair = betfair,
                 `Best price` = best, `Bookies prob (margin removed)` = round(bk, 3),
                 `Our prob (party class)` = round(ours, 3), `Our class` = class)]
if (cand[, any(is.na(Sportsbet) & is.na(TAB) & is.na(Betfair))]) stop("VB16! a top-4 outcome has no price at any bookie")
OUT2 <- sub("\\.csv$", "-top4.csv", OUT)
fwrite(cand, OUT2)
cat(sprintf("VB17 top-4 table: %d rows over %d seats -> %s\n", nrow(cand), uniqueN(cand$Seat), OUT2))

top <- head(sheet[sheet[["Bookies pricing it"]] > 1], 5)
cat(sprintf("VB17 %s: %d seats; %d priced by 2+ bookies; arbitrage (under 100%%) in %d; closest %s\n", DAY, nrow(sheet),
            sum(sheet[["Bookies pricing it"]] > 1), sum(sheet[[3]] < 100 & sheet[["Bookies pricing it"]] > 1),
            paste(sprintf("%s %.1f%%", top$Seat, top[[3]]), collapse = ", ")))
cat(sprintf("VB17 same favourite as ours in %d of %d seats -> %s\n",
            sum(sheet[["Bookies favourite"]] == sheet[["Our favourite"]], na.rm = TRUE), nrow(sheet), OUT))
