# Build the data for the site's Victoria 2026 seat odds page (inthegame-blog politics/odds.qmd)
# from one benchmark capture folder: every source's per-district win chances, bookmaker prices
# for the edge column, the majority-market table and the capture note.
#
#   Rscript scripts/build_seat_odds_json.R [capture_dir] [out_file]
#   defaults: the newest docs/benchmarks/vic2026/<date>/ that holds ours-calls.csv,
#             output/seat-odds-vic2026.json
#   upload:   wrangler r2 object put inthegame-data/auspol/seat-odds-vic2026.json \
#               --file output/seat-odds-vic2026.json --content-type application/json --cache-control "public, max-age=300" --remote
#
# Inputs in the capture folder: <source>-calls.csv (district, call_class, prob) from
# scripts/snapshot_benchmarks.R, bookmaker-odds-top4.csv (prices), majority-markets.csv and
# capture-note.txt (both written by hand at capture time). Sitting MPs and regions come from
# docs/benchmarks/vic2026/district-mps.csv (static until polling day).
#
# Our model's chances are the ones captured WITH the prices (ours-calls.csv), not today's live
# forecast: an edge against a frozen price is only meaningful against the model of that moment.
#
# Check codes: SOJ1! (missing input / bad coverage, stops), SOJ2 (summary of what was written).

suppressPackageStartupMessages({ library(data.table); library(jsonlite) })

args <- commandArgs(trailingOnly = TRUE)
bench <- "docs/benchmarks/vic2026"
cap <- if (length(args) >= 1) args[1] else {
  d <- sort(list.dirs(bench, recursive = FALSE))
  d <- d[file.exists(file.path(d, "ours-calls.csv"))]
  tail(d, 1)
}
out_file <- if (length(args) >= 2) args[2] else "output/seat-odds-vic2026.json"
stopifnot(length(cap) == 1, dir.exists(cap))

need <- c("majority-markets.csv", "capture-note.txt", "bookmaker-odds-top4.csv")
miss <- need[!file.exists(file.path(cap, need))]
if (length(miss)) stop(sprintf("SOJ1! %s lacks %s", cap, paste(miss, collapse = ", ")))

# Source order and labels as the page shows them; GES gives a single call, not a chance.
SOURCES <- data.table(
  id    = c("ours", "sportsbet", "tab", "betfair", "theswingison", "aeforecasts", "firstpreference", "poliwave", "ges"),
  label = c("Our model", "Sportsbet", "TAB", "Betfair", "The Swing Is On", "AE Forecasts", "First Preference", "Poliwave", "Global Election Sim"),
  kind  = c("model", "book", "book", "book", "model", "model", "model", "model", "call"))

# Every source's own class labels collapse to the page's six groups.
to_group <- function(x) {
  g <- ifelse(x %in% c("LNP", "ALP", "ONP", "GRN", "IND"), x, "OTH")
  g
}

mps <- fread(file.path(bench, "district-mps.csv"), encoding = "UTF-8")
if (nrow(mps) != 88 || anyDuplicated(mps$district)) stop("SOJ1! district-mps.csv is not 88 unique districts")

calls <- rbindlist(lapply(SOURCES$id, function(k) {
  f <- file.path(cap, paste0(k, "-calls.csv"))
  if (!file.exists(f)) { message(sprintf("SOJ1 %s-calls.csv absent in %s; source left out", k, cap)); return(NULL) }
  x <- fread(f, encoding = "UTF-8")
  x[, src := k]
  x
}))
calls[, grp := to_group(call_class)]
# A call-only source (GES) publishes no chance: its single call is stored as 1, and the page
# reads the source's kind ("call") to show it as a call, never as a 100% chance.
call_src <- SOURCES$id[SOURCES$kind == "call"]
calls[src %in% call_src, prob := 1]
if (anyNA(calls$prob)) stop("SOJ1! missing win chance in: ", paste(unique(calls[is.na(prob), src]), collapse = ", "))
bad <- setdiff(unique(calls$district), mps$district)
if (length(bad)) stop("SOJ1! district names not in district-mps.csv: ", paste(bad, collapse = ", "))
agg <- calls[, .(prob = sum(prob)), by = .(src, district, grp)]

cover <- agg[, .(n = uniqueN(district)), by = src]
srcs <- merge(SOURCES, cover, by.x = "id", by.y = "src")
srcs <- srcs[order(match(id, SOURCES$id))]
srcs <- srcs[!is.na(n)]
if (!"ours" %in% srcs$id || srcs$n[srcs$id == "ours"] != 88) stop("SOJ1! our model must cover all 88 districts")

# Prices: one row per (district, outcome) with each book's decimal price. "Any other" groups
# every small party and independent, so its model chance is IND + OTH.
pr <- fread(file.path(cap, "bookmaker-odds-top4.csv"), encoding = "UTF-8")
setnames(pr, c("Seat", "Outcome", "Sportsbet", "TAB", "Betfair", "Bookies prob (margin removed)", "Our class"),
         c("district", "outcome", "sportsbet", "tab", "betfair", "book_p", "cls"))
pr[, grp := fifelse(cls == "OTHER+IND", "IND+OTH", cls)]
# A price that covers only PART of a group has no matching chance: the sources give one
# Coalition chance, not Liberal and Nationals apart, and one IND+OTH chance, not each
# independent. Such rows keep their prices but get grp NA, and the page shows no edge for
# them (24 Nov review: Ripon Nationals at $11 was scored against the whole Coalition, +409%).
# Read as text: a capture with no Nationals runner anywhere gives an all-empty column, which fread
# would type as logical NA, and nzchar(NA) is TRUE (every Liberal row would lose its edge).
both_coal <- fread(file.path(cap, "bookmaker-odds.csv"), encoding = "UTF-8", colClasses = "character")
has <- function(v) !is.na(v) & nzchar(v)
both_coal <- both_coal[has(`Liberal best`) & has(`Nationals best`), Seat]
pr[, part := .N > 1, by = .(district, grp)]
pr[grp == "LNP" & district %chin% both_coal, part := TRUE]
n_part <- pr[part == TRUE, .N]
pr[part == TRUE, grp := NA_character_]
message(sprintf("SOJ2 %d price rows cover only part of a group, shown without an edge: %s", n_part,
                paste(unique(pr[is.na(grp), sprintf("%s %s", district, outcome)]), collapse = "; ")))
num <- function(v) suppressWarnings(as.numeric(v))
pr[, `:=`(sportsbet = num(sportsbet), tab = num(tab), betfair = num(betfair), book_p = num(book_p))]

mk <- fread(file.path(cap, "majority-markets.csv"), encoding = "UTF-8")
note <- trimws(paste(readLines(file.path(cap, "capture-note.txt"), encoding = "UTF-8"), collapse = " "))

seats <- lapply(seq_len(nrow(mps)), function(i) {
  d <- mps$district[i]
  p <- list()
  for (k in srcs$id) {
    a <- agg[src == k & district == d]
    if (!nrow(a)) next
    p[[k]] <- as.list(setNames(round(a$prob, 4), a$grp))
  }
  q <- pr[district == d]
  list(seat = d, region = mps$region[i], mp = mps$mp[i], p = p,
       prices = lapply(seq_len(nrow(q)), function(j) list(
         outcome = q$outcome[j], grp = q$grp[j], book_p = q$book_p[j],
         sportsbet = q$sportsbet[j], tab = q$tab[j], betfair = q$betfair[j])))
})

res <- list(
  election = "vic2026", capture = basename(cap), capture_note = note,
  built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  sources = lapply(seq_len(nrow(srcs)), function(i) list(key = srcs$id[i], label = srcs$label[i], kind = srcs$kind[i], n = srcs$n[i])),
  markets = list(columns = names(mk)[-1],
                 rows = lapply(seq_len(nrow(mk)), function(i) unname(as.list(mk[i])))),
  seats = seats)

dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
writeLines(toJSON(res, auto_unbox = TRUE, na = "null", null = "null", digits = NA), out_file, useBytes = TRUE)
cat(sprintf("SOJ2 %s: %d districts, sources %s, %d price rows, %d market rows -> %s\n",
            basename(cap), length(seats), paste(sprintf("%s(%d)", srcs$id, srcs$n), collapse = " "),
            nrow(pr), nrow(mk), out_file))
