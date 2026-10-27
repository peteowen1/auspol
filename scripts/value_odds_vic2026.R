# value_odds_vic2026.R -- our published Victoria 2026 seat probabilities against every bookmaker price on a
# benchmark date, as a value table and a one-file HTML page with a click-through per seat.
#
#   Rscript scripts/value_odds_vic2026.R [--date=YYYY-MM-DD]
#
# Reads the raw captures scripts/snapshot_benchmarks.R saved under external/reference/benchmarks/vic2026/<date>/
# (sportsbet/, tab/, betfair/, ours/), plus output/published-predictions.csv (the 2022 result per seat),
# output/seat-swing-port-vic2026.csv and output/onp-senate-vic2026.csv. Writes to docs/benchmarks/vic2026/<date>/:
#   value-odds.csv     one row per seat x selection: best price and book, margin-removed bookies' probability
#                      (power method, averaged over the books listing it), our probability for that class, edge
#   value-page.html    the page: scripts/value-page-template.html with the data filled in. Publishing it as an
#                      Artifact is a separate, manual step.
#
# Edge = our probability x best price - 1: what $1 returns on average if our probability is right.
# Class matching: Liberal, Nationals and Coalition -> LNP; a named Independent -> our whole IND class; "Any other"
# -> OTH + OTH_RIGHT, plus IND when the book lists no Independent in that seat. A seat where one book prices
# Liberal and Nationals separately, or names two Independents, is left out of the value table (we forecast one
# class for each) and printed.
#
# The contested-seat notes on the page (REVIEW, NOTES) are hand-written in the template and dated; they do not
# update themselves.
#
# Check codes: VO1 (inputs), VO2 (matching), VO3 (outputs). A `!` code stops the run.

suppressMessages({ library(data.table); library(oddsdata); library(jsonlite) })

args <- commandArgs(trailingOnly = TRUE)
DAY <- sub("^--date=", "", grep("^--date=", args, value = TRUE))
if (!length(DAY)) DAY <- format(Sys.time(), "%Y-%m-%d", tz = "UTC")
RAW <- file.path("external", "reference", "benchmarks", "vic2026", DAY)
OUT <- file.path("docs", "benchmarks", "vic2026", DAY)
TEMPLATE <- file.path("scripts", "value-page-template.html")
if (!dir.exists(RAW)) stop("VO1! no captures for ", DAY, " at ", RAW)
if (!file.exists(TEMPLATE)) stop("VO1! page template missing: ", TEMPLATE)

rd <- function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
newest <- function(src, pat) {
  f <- sort(list.files(file.path(RAW, src), pat, full.names = TRUE))
  if (length(f)) tail(f, 1) else NA_character_
}
man <- fread(file.path(RAW, "manifest.tsv"), sep = "\t")

# ---- bookmaker prices, same parsers and file patterns as compare_bookmaker_odds.R ----
books <- list(
  sportsbet = function(f) sb_parse_markets(rd(f), "x")[, seat := market],
  tab       = function(f) tab_parse_markets(rd(f))[market == "Seat Winner"][, seat := sub(" State Election$", "", event)],
  betfair   = function(f) bf_parse_prices(rd(f))[event == "Individual Electorates"][, seat := sub("^Seat of ", "", market)]
)
pats <- c(sportsbet = "^event-.*-markets-.*json$", tab = "^Politics-Victorian-Politics.*\\.json$", betfair = "^markets-.*json$")
got <- list(); fetched <- list()
for (src in names(books)) {
  f <- newest(src, pats[[src]])
  if (is.na(f)) { cat(sprintf("VO1  %s: no capture for %s -- left out\n", src, DAY)); next }
  x <- books[[src]](f)
  ft <- man$fetched_utc[man$file == file.path(src, basename(f))]
  ft <- if (length(ft)) ft[1] else NA_character_
  cat(sprintf("VO1  %s: %d seats, %d prices, fetched %s (%s)\n", src, uniqueN(x$seat), nrow(x),
              if (is.na(ft)) "NOT IN MANIFEST" else ft, basename(f)))
  if (!nrow(x)) stop("VO1! ", src, " capture parsed to zero seat prices: ", f)
  got[[src]] <- x[, source := src]
  fetched[[src]] <- list(seats = uniqueN(x$seat), fetched_utc = ft)
}
if (!length(got)) stop("VO1! no bookmaker captured for ", DAY)
px <- rbindlist(got, fill = TRUE)
okey <- function(x) fcase(
  grepl("^Labor$", x), "ALP", grepl("^(Liberals?|Nationals?|Coalition)$", x), "LNP", grepl("^Gre+ns$", x), "GRN",
  grepl("^One Nation$", x), "ONP", grepl("^Independent", x), "IND", grepl("^(Any )?Other", x), "OTHER")
px[, cls := okey(selection)]
if (anyNA(px$cls)) stop("VO2! selections with no class: ", paste(unique(px[is.na(cls), selection]), collapse = ", "))
px[, key := toupper(trimws(seat))]
px <- implied_probs(px, "power", by = c("source", "key"))

# ---- our published forecast as captured that day ----
fj_path <- file.path(RAW, "ours", "forecast-vic2026.json")
sp_path <- file.path(RAW, "ours", "seat-probs-vic-2026.csv")
if (!file.exists(fj_path) || !file.exists(sp_path)) stop("VO1! our forecast files missing under ", file.path(RAW, "ours"))
fj <- fromJSON(fj_path, simplifyVector = FALSE)
ours <- fread(sp_path)[, key := toupper(seat)]
cat(sprintf("VO1  ours: forecast built %s (git %s), %d seats in seat-probs\n", fj$built_at, fj$git_sha, uniqueN(ours$seat)))
if (uniqueN(ours$seat) != 88L) stop("VO1! seat-probs has ", uniqueN(ours$seat), " seats, not 88")
miss <- setdiff(unique(px$key), ours$key)
if (length(miss)) stop("VO2! bookie seats not in our forecast (name mismatch?): ", paste(miss, collapse = ", "))

oc <- ours[, .(p = sum(prob)), by = .(key, c = fcase(party %in% c("ALP", "LNP", "GRN", "ONP", "IND"), party, default = "OTHER"))]
ow <- dcast(oc, key ~ c, value.var = "p", fill = 0)
for (k in c("ALP", "LNP", "GRN", "ONP", "IND", "OTHER")) if (!k %in% names(ow)) ow[, (k) := 0]
px <- merge(px, ow, by = "key", all.x = TRUE)
px[, has_ind := any(cls == "IND"), by = .(source, key)]
px[, our_p := fcase(cls == "ALP", ALP, cls == "LNP", LNP, cls == "GRN", GRN, cls == "ONP", ONP, cls == "IND", IND,
                    cls == "OTHER" & has_ind, OTHER, cls == "OTHER", OTHER + IND)]
px[, n_lnp := sum(cls == "LNP"), by = .(source, key)]
px[, n_ind := sum(cls == "IND"), by = .(source, key)]
skip <- px[n_lnp > 1 | n_ind > 1, unique(key)]
if (length(skip)) cat(sprintf("VO2  left out of the value table (Liberal and Nationals priced separately, or two named Independents): %s\n",
                              paste(skip, collapse = ", ")))

ok <- px[!key %in% skip]
best <- ok[, .(best_price = max(price), book = source[which.max(price)], nbook = uniqueN(source),
               mkt_p = mean(prob), our_p = our_p[1], cls = cls[1], seat = seat[1]), by = .(key, selection)]
best[, edge := our_p * best_price - 1]
best[, seat := ours$seat[match(key, ours$key)]]
setorder(best, -edge)
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
fwrite(best[, .(seat, selection, class = cls, best_price, book, nbook, mkt_p = round(mkt_p, 4),
                our_p = round(our_p, 4), edge = round(edge, 4))], file.path(OUT, "value-odds.csv"))

# ---- favourites, both sides, by class ----
mk <- px[, .(m = mean(prob)), by = .(key, source, cls)][, .(m = sum(m) / uniqueN(source)), by = .(key, cls)]
fav_m <- mk[, .SD[which.max(m)], by = key][, .(key, mf = cls)]
fav_o <- oc[key %in% mk$key][, .SD[which.max(p)], by = key][, .(key, of = c)]
fav <- merge(fav_m, fav_o, by = "key")
differ <- ours$seat[match(fav[mf != of, key], ours$key)]
cat(sprintf("VO3  same favourite in %d of %d priced seats; differ: %s\n", fav[mf == of, .N], nrow(fav), paste(differ, collapse = ", ")))

# ---- per-seat detail for the click-through ----
pp <- fread(file.path("output", "published-predictions.csv"), select = c("pair", "seat", "party", "candidate", "actual"))
pp <- pp[pp[["pair"]] == "vic2022"]
port <- fread(file.path("output", "seat-swing-port-vic2026.csv"))
onp <- fread(file.path("output", "onp-senate-vic2026.csv"))
seat_names <- vapply(fj$seats, function(s) s$seat, "")
v22_keys <- toupper(pp$seat); port_keys <- toupper(port$seat); onp_keys <- toupper(onp$seat); px_keys <- px$key
seats <- list()
for (s in fj$seats) {
  k <- toupper(s$seat); f2 <- s$final_two
  pr <- lapply(s$parties, function(p) list(p$party, p$candidate %||% NULL, isTRUE(p$sitting), p$primary,
                                           p$primary_q$q05, p$primary_q$q95, p$win_prob))
  vk <- pp[v22_keys == k]
  vk <- vk[order(-actual)]
  sx <- px[px_keys == k]
  seats[[k]] <- list(
    n = s$seat, r = s$region,
    f2 = list(f2$leader, f2$other, f2$p_pair, f2$p_leader_wins_pair, f2$leader_tcp$q05, f2$leader_tcp$q50,
              f2$leader_tcp$q95, f2$swing_to_flip %||% NA),
    p = pr,
    v22 = lapply(seq_len(nrow(vk)), function(i) list(vk$party[i], round(vk$actual[i], 1), vk$candidate[i])),
    port = round(port$fed_swing[match(k, port_keys)], 2),
    onp = round(onp$senate_pct[match(k, onp_keys)], 2),
    px = lapply(seq_len(nrow(sx)), function(i) list(sx$source[i], sx$selection[i], sx$cls[i], sx$price[i], round(sx$prob[i], 4))))
}
no22 <- names(seats)[vapply(seats, function(x) !length(x$v22), TRUE)]
if (length(no22)) cat(sprintf("VO2  no 2022 result row for: %s\n", paste(no22, collapse = ", ")))
if (length(seats) != 88L) stop("VO3! seat detail has ", length(seats), " seats, not 88")

ch <- fj$chamber
pq <- function(p) ch$parties[[p]]
meta <- list(
  day = DAY, built_at = fj$built_at, git_sha = fj$git_sha, n_sims = fj$n_sims, books = fetched,
  n_priced = nrow(fav), n_same = fav[mf == of, .N], differ = as.list(differ), skipped = as.list(skip),
  p_hung = ch$p_hung, p_onp_bop = ch$p_onp_balance_of_power,
  parties = lapply(c(LNP = "LNP", ALP = "ALP", ONP = "ONP", GRN = "GRN"), function(p)
    list(expected = pq(p)$expected, p_majority = pq(p)$p_majority, p_most = pq(p)$p_most_seats,
         q05 = pq(p)$quantiles[["5%"]], q95 = pq(p)$quantiles[["95%"]])),
  favs = as.list(table(vapply(fj$seats, function(s) s$favourite, ""))))

rows <- best[, .(seat, selection, cls, best_price, book, nbook, mkt_p = round(mkt_p, 4), our_p = round(our_p, 4), edge = round(edge, 4))]
tj <- function(x) as.character(toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
page <- rd(TEMPLATE)
for (ph in c("__ROWS__", "__SEATS__", "__META__")) if (!grepl(ph, page, fixed = TRUE)) stop("VO3! template has no ", ph)
page <- sub("__ROWS__", tj(unname(lapply(seq_len(nrow(rows)), function(i) unname(as.list(rows[i]))))), page, fixed = TRUE)
page <- sub("__SEATS__", tj(seats), page, fixed = TRUE)
page <- sub("__META__", tj(meta), page, fixed = TRUE)
writeLines(page, file.path(OUT, "value-page.html"), useBytes = TRUE)
cat(sprintf("VO3  %s: %d selections (%d with positive edge) over %d seats -> %s, %s\n", DAY, nrow(best),
            best[edge > 0, .N], uniqueN(best$key), file.path(OUT, "value-odds.csv"), file.path(OUT, "value-page.html")))
