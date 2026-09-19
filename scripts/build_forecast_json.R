# THE FORECAST AS ONE JSON DOCUMENT, plus a one-row-per-day history table.
# Written 2026-09-19 for the ITG page: everything a seat map, a chamber
# odds panel and per-seat cards need, in one file a static site can fetch
# from the `forecast-latest` GitHub release (release-as-data-bus, the
# ecosystem convention -- C:\dev\CLAUDE.md). Reads only what
# fit_seats_full.R already writes; computes nothing new about the model.
#
#   output/forecast-vic2026.json   -- seats, chamber, meta
#   output/forecast-history.csv    -- appended: one row per build (expected
#                                     seats per party, majority odds), so a
#                                     page can chart movement over time
#
# Runs as a run_all.R stage after build_page.R; the workflow uploads both.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
OUT <- "output"; SUF <- Sys.getenv("AUSPOL_OUT_SUFFIX", "")
f_probs  <- file.path(OUT, sprintf("seat-probs-vic-2026%s.csv", SUF))
f_shares <- file.path(OUT, sprintf("seat-shares-vic-2026%s.csv", SUF))
f_sims   <- file.path(OUT, sprintf("seat-sims-full-vic-2026%s.csv", SUF))
for (f in c(f_probs, f_shares, f_sims)) if (!file.exists(f)) stop("FJ0! missing ", f, " -- run scripts/fit_seats_full.R first")
probs  <- fread(f_probs, showProgress = FALSE)
shares <- fread(f_shares, showProgress = FALSE)
sims   <- fread(f_sims, showProgress = FALSE)
stopifnot(nrow(probs) > 0, nrow(shares) > 0, nrow(sims) > 1000)
parties <- setdiff(names(sims), "seat")
# THE CHAMBER, not the simulated seat count: the Legislative Assembly has 88
# seats and a majority is 45. fit_seats_full.R simulates 87 -- Narracan's
# 2022 poll was deferred (a candidate's death) and the pipeline has no 2022
# baseline for it; its January 2023 supplementary result sits in the
# by-election table and wiring it in is an open item. Until then the page
# must say 87 of 88 simulated, and must not call 44 a majority.
CHAMBER <- as.integer(Sys.getenv("AUSPOL_CHAMBER_SEATS", "88")); majority <- CHAMBER %/% 2 + 1
n_seats <- nrow(shares)
cand_f0 <- file.path("external", "reference", "wikipedia", "vic2026-candidates.csv")
excluded <- if (file.exists(cand_f0)) setdiff(unique(fread(cand_f0, showProgress = FALSE)$seat), shares$seat) else character(0)
cat(sprintf("FJ1  %d of %d seats simulated (excluded: %s), %d parties, %d simulations; majority is %d\n",
            n_seats, CHAMBER, if (length(excluded)) paste(excluded, collapse = ", ") else "none", length(parties), nrow(sims), majority))

# candidates (leading candidate per class, from the tracked Wikipedia table)
cand_f <- file.path("external", "reference", "wikipedia", "vic2026-candidates.csv")
cands <- if (file.exists(cand_f)) fread(cand_f, showProgress = FALSE) else NULL
if (!is.null(cands) && exists("classify_party")) cands[, party := classify_party(party_raw)]
if (!is.null(cands) && !"party" %in% names(cands)) {
  suppressMessages(devtools::load_all(quiet = TRUE)); cands[, party := classify_party(party_raw)]
}

# per-seat block
seat_rows <- lapply(shares$seat, function(s) {
  pr <- probs[seat == s]; sh <- shares[seat == s]
  cls <- parties[parties %in% names(sh)]
  ps <- lapply(cls, function(p) {
    nm <- if (!is.null(cands)) cands[seat == s & party == p]$name else character(0)
    list(party = p,
         win_prob = round(if (p %in% pr$party) pr[party == p]$prob else 0, 4),
         primary = round(sh[[p]], 2),
         candidate = if (length(nm)) nm[1] else NULL,
         sitting = if (!is.null(cands) && length(nm)) isTRUE(cands[seat == s & party == p]$sitting[1]) else NULL)
  })
  ps <- ps[order(-vapply(ps, `[[`, numeric(1), "win_prob"))]
  list(seat = s, favourite = ps[[1]]$party, favourite_prob = ps[[1]]$win_prob, parties = ps)
})

# chamber block from the simulation totals
q <- function(x) as.list(round(stats::quantile(x, c(0.05, 0.25, 0.5, 0.75, 0.95)), 1))
chamber <- lapply(parties, function(p) list(party = p, expected = round(mean(sims[[p]]), 2),
                                            p_majority = round(mean(sims[[p]] >= majority), 4),
                                            p_most_seats = round(mean(sims[[p]] == apply(as.matrix(sims[, ..parties]), 1, max)), 4),
                                            quantiles = q(sims[[p]])))
names(chamber) <- parties
hung <- mean(apply(as.matrix(sims[, ..parties]), 1, max) < majority)
maj_l <- if ("LNP" %in% parties) sims$LNP else 0; maj_a <- if ("ALP" %in% parties) sims$ALP else 0
onp <- if ("ONP" %in% parties) sims$ONP else 0
# One Nation balance of power: no majority, and One Nation's seats would carry the larger major over the line
onp_bop <- mean(pmax(maj_l, maj_a) < majority & pmax(maj_l, maj_a) + onp >= majority & onp > 0)
gitsha <- tryCatch(trimws(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)), error = function(e) NA_character_)
man_f <- file.path(OUT, "shipped", "MANIFEST.json")
man <- if (file.exists(man_f)) jsonlite::fromJSON(man_f) else NULL
doc <- list(
  election = "vic2026", election_date = "2026-11-28", built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  git_sha = gitsha, models_promoted_at = if (!is.null(man)) man$promoted_at else NULL,
  chamber_seats = CHAMBER, seats_simulated = n_seats, seats_not_simulated = excluded, majority = majority, n_sims = nrow(sims),
  chamber = list(parties = chamber, p_hung = round(hung, 4), p_onp_balance_of_power = round(onp_bop, 4)),
  seats = seat_rows)
out_f <- file.path(OUT, "forecast-vic2026.json")
writeLines(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null", digits = 4), out_f)
cat(sprintf("FJ2  wrote %s (%.0f KB)\n", out_f, file.size(out_f) / 1024))

# history: one row per build
hist_f <- file.path(OUT, "forecast-history.csv")
row <- data.table(built_at = doc$built_at, git_sha = gitsha, p_hung = round(hung, 4), p_onp_bop = round(onp_bop, 4))
for (p in parties) { row[[paste0("exp_", p)]] <- round(mean(sims[[p]]), 2); row[[paste0("pmaj_", p)]] <- round(mean(sims[[p]] >= majority), 4) }
H <- if (file.exists(hist_f)) rbind(fread(hist_f, showProgress = FALSE), row, fill = TRUE) else row
fwrite(H, hist_f)
cat(sprintf("FJ3  history now %d row(s): %s\n", nrow(H), paste(sprintf("%s %.1f", parties, unlist(row[, paste0("exp_", parties), with = FALSE])), collapse = ", ")))
cat(sprintf("FJ3  P(hung) %.3f | P(One Nation balance of power) %.3f\n", hung, onp_bop))
