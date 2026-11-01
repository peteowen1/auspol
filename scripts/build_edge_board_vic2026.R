# Data for the Vic 2026 Edge Board (https://claude.ai/artifact/8U33eGJMiAbpZFSW2dsfQu): every Sportsbet Victorian
# 2026 selection against our forecast, plus the per-seat panel data. Moved out of a session scratchpad 1 Nov 2026 so
# the board can be rebuilt without that session.
#
#   Rscript scripts/build_edge_board_vic2026.R [sportsbet-capture.csv] [out_dir]
#   EDGE_RUN=<suffix>  our run to read: output/seat-probs-vic-2026-<suffix>.csv and seat-sims-full-vic-2026-<suffix>.csv
#
# Writes to out_dir (default output/edge-board/):
#   vic26-sportsbet-edges.csv  one row per selection, the board's `edges` dataset (columns as the page reads them)
#   vic26-seat-forecast.csv    one row per seat x party group from the PUBLISHED forecast JSON, the `seats` dataset
# Upload both to the board by hand (Artifact asset upload, then update datasets/edges and datasets/seats).
#
# edge = price x our probability - 1 (expected return per dollar; > 0 favours the bettor; betting/GLOSSARY.md).
# Low end: our probability moved halfway to the bookie's margin-free probability ("if we are only half right about
# where we disagree"); Solid = edge >= 2% there, Possible = >= 2% only at our centre, else Under 2%.
# Emits EB* codes.
suppressMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
SB_F <- if (length(args) >= 1) args[1] else Sys.glob("external/reference/benchmarks/vic2026/2026-10-31-sb-all/sportsbet-all-markets.csv")[1]
OUT <- if (length(args) >= 2) args[2] else file.path("output", "edge-board")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
THRESHOLD <- 0.02

sb <- fread(SB_F)
cat(sprintf("EB1  Sportsbet %s: %d rows, %d markets, fetched (UTC) %s\n", SB_F, nrow(sb), uniqueN(sb$market_id), min(sb$fetched_utc)))
sb <- oddsdata::implied_probs(sb, "power")
RUN <- Sys.getenv("EDGE_RUN", "boardmain")
probs <- fread(file.path("output", sprintf("seat-probs-vic-2026-%s.csv", RUN)))
draws <- fread(file.path("output", sprintf("seat-sims-full-vic-2026-%s.csv", RUN)))
cat(sprintf("EB2  our run '%s': %d seats, %d simulated elections\n", RUN, uniqueN(probs$seat), nrow(draws)))

book_class <- function(x) {
  out <- rep(NA_character_, length(x))
  out[grepl("^Labor$", x)] <- "ALP"; out[grepl("^(Liberals?|Coalition|L-?NP)$", x)] <- "LNP"
  out[grepl("^Nationals?$", x)] <- "NAT"; out[grepl("^Gre+ns$", x)] <- "GRN"; out[grepl("^One Nation$", x)] <- "ONP"
  out[grepl("^Independent", x)] <- "IND"; out[grepl("^(Any )?Other", x)] <- "ANY_OTHER"
  out
}
seat <- sb[event == "Victorian State Election - Seat Betting"]
seat[, cls := book_class(selection)]
if (anyNA(seat$cls)) cat("EB3! unclassed selections:", paste(unique(seat$selection[is.na(seat$cls)]), collapse = ", "), "\n")
# a seat pricing Liberal AND Nationals separately cannot be split by us (our LNP class holds both)
seat[, split_coal := any(cls == "LNP") & any(cls == "NAT"), by = market]
seat[, n_ind := sum(cls == "IND", na.rm = TRUE), by = market]
seat[cls == "NAT" & !split_coal, cls := "LNP"]
pw <- dcast(probs, seat ~ party, value.var = "prob", fill = 0)
ours_for <- function(s, cl) {
  r <- pw[pw$seat == s]; if (!nrow(r)) return(NA_real_)
  if (cl == "ANY_OTHER") return(NA_real_)
  if (!cl %in% names(r)) return(0)
  r[[cl]]
}
seat[, ours := mapply(ours_for, market, cls)]
# any other = 1 - our probability of every class this market names
seat[cls == "ANY_OTHER", ours := { s <- market[1]; named <- unique(seat$cls[seat$market == s & seat$cls != "ANY_OTHER"])
  r <- pw[pw$seat == s]; if (!nrow(r)) NA_real_ else max(0, 1 - sum(unlist(r[, intersect(named, names(r)), with = FALSE]))) }, by = market]
seat[split_coal == TRUE & cls %in% c("LNP", "NAT"), ours := NA_real_]
seat[n_ind > 1 & cls == "IND", ours := NA_real_]
seat[, `:=`(type = "Seat winner", what = market, note = fifelse(split_coal & cls %in% c("LNP", "NAT"), "Liberal and Nationals priced apart; our model holds them together",
                                                fifelse(n_ind > 1 & cls == "IND", "several independents priced; our model holds them together", "")))]

# chamber markets from the simulated elections
D <- draws
maj <- fifelse(D$LNP >= 45, "LNP", fifelse(D$ALP >= 45, "ALP", "none"))
# Who forms government in a hung parliament (Pete via the betting session, 31 Oct): One Nation backs only the
# Coalition. Bloc rule: Coalition bloc = LNP + ONP + OTH_RIGHT, Labor bloc = ALP + GRN; a bloc reaching 45 governs,
# else the larger bloc; IND and OTH unaligned; a bloc tie splits half and half.
right <- D$LNP + D$ONP + D$OTH_RIGHT; left <- D$ALP + D$GRN
lnp_lead <- right >= 45 | (left < 45 & right > left)
tie <- !(right >= 45) & !(left >= 45) & right == left
lnp_lead[tie] <- FALSE
p <- function(x) mean(x)
ch <- list(
  "Coalition Seats|Over" = p(D$LNP > 43.5), "Coalition Seats|Under" = p(D$LNP < 43.5),
  "Labor Seats|Over" = p(D$ALP > 28.5), "Labor Seats|Under" = p(D$ALP < 28.5),
  "One Nation Seats|Over" = p(D$ONP > 10.5), "One Nation Seats|Under" = p(D$ONP < 10.5),
  "Greens Seats|Over" = p(D$GRN > 5.5), "Greens Seats|Under" = p(D$GRN < 5.5),
  "Will There Be a Hung Parliament?|Yes - There will be a Hung Parliament" = p(maj == "none"),
  "Will There Be a Hung Parliament?|No - There will NOT be a Hung Parliament" = p(maj != "none"),
  "Type of Government Formed|Coalition Majority" = p(maj == "LNP"),
  "Type of Government Formed|Labor Majority" = p(maj == "ALP"),
  "Type of Government Formed|Coalition Minority" = p(maj == "none" & lnp_lead & !tie) + p(maj == "none" & tie) / 2,
  "Type of Government Formed|Labor Minority" = p(maj == "none" & !lnp_lead & !tie) + p(maj == "none" & tie) / 2,
  "Type of Government Formed|Any Other Result" = 0,
  "Victorian State Election - Sworn in Government|Coalition" = p(maj == "LNP") + p(maj == "none" & lnp_lead & !tie) + p(maj == "none" & tie) / 2,
  "Victorian State Election - Sworn in Government|Labor" = p(maj == "ALP") + p(maj == "none" & !lnp_lead & !tie) + p(maj == "none" & tie) / 2,
  "Victorian State Election - Sworn in Government|Any Other" = 0)
# The seat-total lines above are the 31 Oct Sportsbet handicaps; a new capture with other lines must fail, not mismatch.
chamber <- sb[event != "Victorian State Election - Seat Betting" & !grepl("Labor Lead", market)]
chamber[, key := paste(market, selection, sep = "|")]
unk <- setdiff(chamber$key, names(ch))
if (length(unk)) stop("EB4! Sportsbet markets with no rule here: ", paste(unk, collapse = "; "))
tot <- chamber[grepl("Seats$", market)]
line_of <- c("Coalition Seats" = 43.5, "Labor Seats" = 28.5, "One Nation Seats" = 10.5, "Greens Seats" = 5.5)
bad_line <- tot[abs(handicap - line_of[market]) > 1e-9]
if (nrow(bad_line)) stop("EB5! seat-total line moved: ", paste(unique(paste(bad_line$market, bad_line$handicap)), collapse = "; "))
chamber[, ours := unlist(ch[key])]
chamber[, `:=`(type = fifelse(grepl("Seats$", market), "Seat total", "Government"),
               what = fifelse(grepl("Seats$", market), sprintf("%s %s %s", market, selection, handicap), paste(market, "-", selection)),
               note = fifelse(grepl("Minority|Sworn", market), "hung parliament: Coalition + One Nation + other right vs Labor + Greens; a bloc at 45 governs, else the larger", ""),
               cls = NA_character_)]
stopifnot(!anyNA(chamber$ours))

cols <- c("type", "what", "market", "selection", "cls", "price", "prob", "ours", "note", "fetched_utc", "event_id")
all <- rbind(seat[, ..cols], chamber[, ..cols])
setnames(all, "prob", "book")
all[, `:=`(edge = price * ours - 1, low = ours - 0.5 * (ours - book))]
all[, edge_low := price * low - 1]
all[, status := fifelse(is.na(edge), "Not priced by us", fifelse(edge_low >= THRESHOLD, "Solid", fifelse(edge >= THRESHOLD, "Possible", "Under 2%")))]
all[, kelly := fifelse(!is.na(edge) & edge > 0, edge / (price - 1), 0)]
all[, long_shot := price >= 10]
all[, read_syd := format(as.POSIXct(fetched_utc, tz = "UTC"), "%a %d %b %I:%M%p", tz = "Australia/Sydney")]
all[, link := fifelse(type == "Seat winner", "https://www.sportsbet.com.au/betting/politics/australian-politics/vic-politics/victorian-state-election-seat-betting-10944986",
                      sprintf("https://www.sportsbet.com.au/betting/politics/australian-politics/vic-politics/e-%s", event_id))]
setorder(all, -edge, na.last = TRUE)
cat("EB6  rows", nrow(all), "| status:", paste(names(table(all$status)), table(all$status), collapse = "; "), "\n")

# the board's shape: what the page reads
r4 <- function(x) round(x, 4)
board <- all[, .(id = sprintf("r%03d", .I), type, market = what, selection, price, book_prob = r4(book), our_prob = r4(ours),
                 edge = r4(edge), edge_low = r4(edge_low), status, kelly = r4(kelly), long_shot = fifelse(long_shot, "yes", "no"),
                 note, read_at = read_syd, draws = nrow(D), link,
                 model_at = format(file.mtime(file.path("output", sprintf("seat-probs-vic-2026-%s.csv", RUN))), "%a %d %b %I:%M%p", tz = "Australia/Sydney"))]
fwrite(board, file.path(OUT, "vic26-sportsbet-edges.csv"))
cat(sprintf("EB7  wrote %s (%d rows)\n", file.path(OUT, "vic26-sportsbet-edges.csv"), nrow(board)))

# per-seat panel: the PUBLISHED forecast, as the site shows it
fc <- jsonlite::fromJSON("https://data.inthegame.blog/auspol/forecast-vic2026.json", simplifyVector = FALSE)
r22 <- jsonlite::fromJSON("https://data.inthegame.blog/auspol/vic2022-results.json", simplifyVector = FALSE)
p22 <- rbindlist(lapply(r22, function(s) rbindlist(lapply(s$primary, function(p) list(seat = s$seat, party = p$party, pct = p$pct)))))
p22 <- p22[, .(pct = round(sum(pct), 2)), by = .(seat, party)]
LAB <- c(ALP = "Labor", LNP = "Liberal/Nationals", GRN = "Greens", ONP = "One Nation", OTH_RIGHT = "Other right-wing",
         IND = "Independents", OTH = "Other minors")
lab <- function(x) if (is.null(x) || !nzchar(x)) "" else if (x %in% names(LAB)) LAB[[x]] else x
`%||%` <- function(a, b) if (is.null(a)) b else a
built <- format(as.POSIXct(fc$built_at, format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC"), "%a %d %b %I:%M%p", tz = "Australia/Sydney")
seats22 <- unique(p22$seat)
sf <- rbindlist(lapply(fc$seats, function(s) {
  ft <- s$final_two
  rbindlist(lapply(s$parties, function(p) {
    q <- p$primary_q %||% list()
    v22 <- if (s$seat %in% seats22) { m <- p22$pct[p22$seat == s$seat & p22$party == p$party]; if (length(m)) m else 0 } else NA_real_
    list(seat = s$seat, region = s$region, party = lab(p$party), candidate = p$candidate %||% "", sitting = if (isTRUE(p$sitting)) "yes" else "no",
         win_prob = p$win_prob, primary = p$primary, primary_q05 = q$q05 %||% NA_real_, primary_q95 = q$q95 %||% NA_real_, primary_2022 = v22,
         final_two = if (is.null(ft)) "" else paste(lab(ft$leader), "v", lab(ft$other)), p_final_two = ft$p_pair %||% NA_real_,
         leader_tcp = ft$leader_tcp$q50 %||% NA_real_, swing_to_flip = ft$swing_to_flip %||% NA_real_, forecast_at = built,
         site_link = paste0("https://inthegame.blog/politics/seat.html#name=", utils::URLencode(s$seat, reserved = TRUE)))
  }))
}))
stopifnot(uniqueN(sf$seat) == length(fc$seats), !anyDuplicated(sf[, .(seat, party)]))
cat(sprintf("EB8  seat panel: %d rows, %d seats, %d without a 2022 result; forecast built %s (git %s)\n",
            nrow(sf), uniqueN(sf$seat), uniqueN(sf$seat[is.na(sf$primary_2022)]), built, fc$git_sha))
fwrite(sf, file.path(OUT, "vic26-seat-forecast.csv"))
cat(sprintf("EB9  wrote %s\n", file.path(OUT, "vic26-seat-forecast.csv")))
