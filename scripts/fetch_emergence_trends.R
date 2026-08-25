# Query Google Trends for the emergence test: each non-major candidate paired
# against the person they were actually running against.
#
# ANCHOR = THE RE-CONTESTING INCUMBENT. That is the comparison a voter makes,
# and it is Pete's preference over a national figure. Where the incumbent is not
# re-contesting -- a retirement, which is exactly when these seats fall -- there
# is no such person, and the fallback is the prime minister of the day, FLAGGED
# in the output so the two anchor types are never pooled without noticing.
#
# NO LEAKAGE. The window is the seven days ENDING THE DAY BEFORE polling day.
# Nothing from election day or the count can reach it. This is tighter than the
# 70-day window the original gate used, deliberately: a long window picks up
# post-nomination coverage that a one-week pre-poll window cannot confuse with
# result reporting.
#
# ONE QUERY PER CANDIDATE, not batched: each row has its own anchor, so
# candidates cannot share a query without losing the pairing that makes the
# ratio comparable.
#
# Emits ET* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))
source("scripts/trends_fetch.R")

SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "6"))
POLL <- c(fed2010 = "2010-08-21", fed2013 = "2013-09-07", fed2016 = "2016-07-02",
          fed2019 = "2019-05-18", fed2022 = "2022-05-21", fed2025 = "2025-05-03")
PM <- function(d) {
  d <- as.Date(d)
  if (d < as.Date("2010-06-24")) "Kevin Rudd"
  else if (d < as.Date("2013-06-27")) "Julia Gillard"
  else if (d < as.Date("2013-09-18")) "Kevin Rudd"
  else if (d < as.Date("2015-09-15")) "Tony Abbott"
  else if (d < as.Date("2018-08-24")) "Malcolm Turnbull"
  else if (d < as.Date("2022-05-23")) "Scott Morrison"
  else "Anthony Albanese"
}
# The AEC writes surnames in caps. Google does not.
tidy <- function(x) {
  x <- gsub("\\s+", " ", trimws(x))
  vapply(strsplit(x, " "), function(p)
    paste(toupper(substring(p, 1, 1)), tolower(substring(p, 2)), sep = "",
          collapse = " "), character(1))
}

S <- fread("output/emergence-test.csv", showProgress = FALSE)
S <- S[election %in% names(POLL)]
# SEARCH FORM, NOT LEGAL FORM. Google is searched for "Kylea Tink"; the AEC
# records "Kylea Jane Tink", and querying that returned 0.000 for her and for
# "Clive Frederick Palmer" -- two of the most-searched names in the sample.
# plan-wire-salience-into-forecast.md already recorded that this one fix lifted
# the 2022 AUC from 0.830 to 0.854.
#
# Built from the given/surname FIELDS rather than by stripping the middle word,
# because that heuristic turns "Dominic WY KANAK" into "Dominic Kanak".
search_form <- function(given, surname, fallback) {
  first <- sub(" .*$", "", trimws(given))
  out <- ifelse(is.na(given) | is.na(surname) | first == "" ,
                tidy(fallback), paste(tidy(first), tidy(surname)))
  out
}
S[, cand := search_form(given, surname, name)]
S[, anchor := fifelse(inc_running,
                      search_form(inc_given, inc_surname, inc_name),
                      NA_character_)]
drop <- S[tidy(name) != cand, .(name, cand)]
if (nrow(drop)) {
  cat("ET0  middle names dropped for the query:
")
  for (i in seq_len(nrow(drop)))
    cat(sprintf("       %-28s -> %s
", drop$name[i], drop$cand[i]))
}
# A CANDIDATE ANCHORED ON THEMSELVES IS A SELF-COMPARISON, ratio 1.000 by
# construction. That happens when the sitting member IS the non-major on the
# ballot -- Wilkie 2013, Katter 2013. The original gate excluded these
# deliberately and the rebuild lost it; they are incumbency, not emergence.
self <- S[!is.na(anchor) & cand == anchor]
if (nrow(self)) {
  cat(sprintf("ET0  dropping %d self-comparison row(s): %s
", nrow(self),
              paste(unique(self$cand), collapse = ", ")))
  S <- S[is.na(anchor) | cand != anchor]
}
S[is.na(anchor), anchor := vapply(election, function(e) PM(POLL[[e]]), character(1))]
S[, anchor_type := fifelse(inc_running, "incumbent", "PM fallback")]
cat(sprintf("ET1  %d rows | %d anchored on the re-contesting incumbent, %d on the PM\n",
            nrow(S), sum(S$anchor_type == "incumbent"),
            sum(S$anchor_type != "incumbent")))

rows <- list()
for (i in seq_len(nrow(S))) {
  to <- as.Date(POLL[[S$election[i]]]) - 1
  from <- to - 7
  r <- trends_batch(S$cand[i], geo = "AU", from = from, to = to,
                    anchor = S$anchor[i])
  a <- if (!is.null(r) && S$anchor[i] %in% names(r)) as.numeric(r[[S$anchor[i]]]) else NA_real_
  v <- if (!is.null(r) && S$cand[i] %in% names(r)) as.numeric(r[[S$cand[i]]]) else NA_real_
  rows[[i]] <- data.table(
    grp = S$grp[i], election = S$election[i], seat = S$seat[i],
    name = S$cand[i], party = S$party[i], pcv = S$pcv[i], won = S$won[i],
    our_p = S$our_p[i], anchor = S$anchor[i], anchor_type = S$anchor_type[i],
    cand_hits = v, anchor_hits = a,
    ratio = if (is.finite(a) && a > 0) v / a else NA_real_)
  cat(sprintf("ET2  %-9s %-14s %-22s vs %-20s ratio %s\n",
              S$election[i], substr(S$seat[i], 1, 14), substr(S$cand[i], 1, 22),
              substr(S$anchor[i], 1, 20),
              if (is.finite(rows[[i]]$ratio)) sprintf("%.3f", rows[[i]]$ratio) else "--"))
  Sys.sleep(SLEEP)
}
R <- rbindlist(rows)
fwrite(R, "output/emergence-trends.csv")

ok <- R[is.finite(ratio)]
cat(sprintf("\nET8  %d of %d rows returned a usable ratio\n", nrow(ok), nrow(R)))
if (nrow(ok) && uniqueN(ok$grp) > 1) {
  print(ok[, .(n = .N, median = round(median(ratio), 3),
               mean = round(mean(ratio), 3),
               above_0.1 = sum(ratio > 0.1)), by = grp], row.names = FALSE)
  a <- ok[grp == "A_won"]; b <- ok[grp == "B_lost"]
  rk <- rank(ok$ratio); n1 <- nrow(a); n0 <- nrow(b)
  cat(sprintf("\nET9  AUC %.3f  (%d winners vs %d losers)\n",
              (sum(rk[ok$grp == "A_won"]) - n1 * (n1 + 1) / 2) / (n1 * n0), n1, n0))
  cat(sprintf("ET9  Mann-Whitney p = %.4g\n",
              suppressWarnings(wilcox.test(a$ratio, b$ratio)$p.value)))
}
cat("ET9  wrote output/emergence-trends.csv\n")
