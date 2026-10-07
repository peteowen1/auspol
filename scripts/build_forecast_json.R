# THE FORECAST AS ONE JSON DOCUMENT, plus a one-row-per-day history table.
# Written 2026-09-19 for the ITG page: everything a seat map, a chamber
# odds panel and per-seat cards need, in one file a static site can fetch
# from the `forecast-latest` GitHub release (release-as-data-bus, the
# ecosystem convention -- C:\dev\CLAUDE.md). Reads only what
# fit_seats_full.R already writes; computes nothing new about the model.
#
#   output/forecast-<election>.json -- seats, chamber, meta (forecast-vic2026.json)
#   output/forecast-history.csv    -- appended: one row per build (expected
#                                     seats per party, majority odds), so a
#                                     page can chart movement over time
#
# Runs as a run_all.R stage after build_page.R; the workflow uploads both.
#
# WHICH ELECTION: AUSPOL_FORECAST_ELECTION (default "vic2026"). Everything that
# differs between elections is in ELECTIONS below and nowhere else in this file.
# An NA there means "not verified / does not exist yet": the script then either
# skips the optional input or stops naming it, it never guesses.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
ELECTIONS <- list(
  vic2026 = list(
    election = "vic2026", election_date = "2026-11-28",
    chamber_seats = 88L, majority = 45L,
    file_tag = "vic-2026",           # seat-probs-<file_tag>.csv etc. (fit_seats_full.R's names)
    json_stem = "forecast-vic2026",  # output/<json_stem>.json
    history_stem = "forecast-history",   # the published history table, kept at its original name
    # Tracked Wikipedia candidate table: leading candidate per class and the
    # list of seats the chamber has but the simulation dropped.
    candidates_file = file.path("external", "reference", "wikipedia", "vic2026-candidates.csv"),
    # Legislative Council region per district (Wikipedia, tracked): the ITG
    # page groups the seat table and a map by it.
    region_file = file.path("external", "reference", "vec", "vic-district-regions.csv")),
  nsw2027 = list(
    election = "nsw2027",
    # Fourth Saturday of March 2027 (NSW fixed-term rule). NOT in election_dates()
    # and the anchor's election-cycles.csv says 2027-03-20 for the cycle end; both
    # disagree with / lack this. Confirm against the NSWEC writ date before publishing.
    election_date = "2027-03-27",
    chamber_seats = 93L,             # Legislative Assembly; all NSW harness years (2015/19/23) score 93 (docs/DATA-REGISTRY.md)
    majority = 47L,                  # 93 %/% 2 + 1
    file_tag = "nsw-2027",           # none of these inputs exist yet: the script stops naming them
    json_stem = "forecast-nsw2027",
    history_stem = "forecast-history-nsw2027",   # separate file: the shared name would mix NSW rows into Victoria's chart
    candidates_file = NA_character_, # no NSW 2027 candidate table exists (output/candidacies.csv has no nsw2027 rows)
    region_file = NA_character_))    # no NSW district-to-region table in the repo; seats publish region = null
ELECTION <- Sys.getenv("AUSPOL_FORECAST_ELECTION", "vic2026")
if (!ELECTION %in% names(ELECTIONS))
  stop("FJ0! unknown AUSPOL_FORECAST_ELECTION '", ELECTION, "'; known: ", paste(names(ELECTIONS), collapse = ", "))
CFG <- ELECTIONS[[ELECTION]]
stopifnot(identical(CFG$election, ELECTION), CFG$chamber_seats %/% 2L + 1L == CFG$majority)
OUT <- "output"; SUF <- Sys.getenv("AUSPOL_OUT_SUFFIX", "")
f_probs  <- file.path(OUT, sprintf("seat-probs-%s%s.csv", CFG$file_tag, SUF))
f_shares <- file.path(OUT, sprintf("seat-shares-%s%s.csv", CFG$file_tag, SUF))
f_sims   <- file.path(OUT, sprintf("seat-sims-full-%s%s.csv", CFG$file_tag, SUF))
miss_f <- Filter(function(f) !file.exists(f), c(f_probs, f_shares, f_sims))
if (length(miss_f)) stop("FJ0! ", ELECTION, ": missing ", paste(miss_f, collapse = ", "), " -- run scripts/fit_seats_full.R for this election first")
probs  <- fread(f_probs, showProgress = FALSE)
shares <- fread(f_shares, showProgress = FALSE)
sims   <- fread(f_sims, showProgress = FALSE)
stopifnot(nrow(probs) > 0, nrow(shares) > 0, nrow(sims) > 1000)
parties <- setdiff(names(sims), "seat")
# THE CHAMBER (Victoria: 88 seats, majority 45). Since 2026-09-19 fit_seats_full.R
# simulates all 88 (Narracan via its January 2023 supplementary baseline);
# seats_not_simulated stays in the document so a page can say so if a seat
# ever drops out again.
CHAMBER <- as.integer(Sys.getenv("AUSPOL_CHAMBER_SEATS", CFG$chamber_seats)); majority <- CHAMBER %/% 2 + 1
n_seats <- nrow(shares)
cand_f0 <- CFG$candidates_file
# Without a candidate table the dropped seats cannot be named, so a short seat file must stop, not publish.
if (is.na(cand_f0) && n_seats != CHAMBER)
  stop("FJ0! ", ELECTION, ": ", n_seats, " seats simulated but the chamber has ", CHAMBER,
       " and no candidates_file is configured to name the missing ones")
excluded <- if (!is.na(cand_f0) && file.exists(cand_f0)) setdiff(unique(fread(cand_f0, showProgress = FALSE)$seat), shares$seat) else character(0)
cat(sprintf("FJ1  %d of %d seats simulated (excluded: %s), %d parties, %d simulations; majority is %d\n",
            n_seats, CHAMBER, if (length(excluded)) paste(excluded, collapse = ", ") else "none", length(parties), nrow(sims), majority))

# candidates (leading candidate per class, from the tracked Wikipedia table)
cand_f <- cand_f0
cands <- if (!is.na(cand_f) && file.exists(cand_f)) fread(cand_f, showProgress = FALSE) else NULL
if (!is.null(cands) && exists("classify_party")) cands[, party := classify_party(party_raw)]
if (!is.null(cands) && !"party" %in% names(cands)) {
  suppressMessages(devtools::load_all(quiet = TRUE)); cands[, party := classify_party(party_raw)]
}

# Region per district (CFG$region_file): the ITG page groups the seat table and a map by it.
reg_f <- CFG$region_file
REG <- if (!is.na(reg_f) && file.exists(reg_f)) fread(reg_f, showProgress = FALSE) else NULL
region_of <- function(s) if (is.null(REG)) NULL else { r <- REG[district == s]$region; if (length(r)) r[1] else NULL }
# Per-seat ranges from fit_seats_full.R's own draws (2026-09-30): each party's
# primary quantiles and the likeliest final two. Optional: a run without them
# (an older fit) publishes the seat without these fields, and says so.
prim_f <- file.path(OUT, sprintf("seat-primary-ranges-%s%s.csv", CFG$file_tag, SUF))
tcp_f  <- file.path(OUT, sprintf("seat-tcp-ranges-%s%s.csv", CFG$file_tag, SUF))
PRIM <- if (file.exists(prim_f)) fread(prim_f, showProgress = FALSE) else NULL
TCPR <- if (file.exists(tcp_f)) fread(tcp_f, showProgress = FALSE) else NULL
if (is.null(PRIM) || is.null(TCPR)) cat("FJ1! per-seat range files missing -- seats published WITHOUT primary_q / final_two
")
.qcols <- c("q05", "q25", "q50", "q75", "q95")
prim_q <- function(st, pt) {
  if (is.null(PRIM)) return(NULL)
  r <- PRIM[which(PRIM$seat == st & PRIM$party == pt)]
  if (!nrow(r)) return(NULL)
  as.list(unlist(r[1, .qcols, with = FALSE]))
}
final_two <- function(st) {
  if (is.null(TCPR)) return(NULL)
  r <- TCPR[which(TCPR$seat == st)]
  if (!nrow(r)) return(NULL)
  list(leader = r$leader[1], other = r$other[1], p_pair = r$p_pair[1],
       p_leader_wins_pair = r$p_leader_wins_pair[1],
       leader_tcp = as.list(setNames(unlist(r[1, paste0("leader_tcp_", .qcols), with = FALSE]), .qcols)),
       swing_to_flip = r$swing_to_flip[1])
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
         primary_q = prim_q(s, p),
         candidate = if (length(nm)) nm[1] else NULL,
         sitting = if (!is.null(cands) && length(nm)) isTRUE(cands[seat == s & party == p]$sitting[1]) else NULL)
  })
  ps <- ps[order(-vapply(ps, `[[`, numeric(1), "win_prob"))]
  list(seat = s, region = region_of(s), favourite = ps[[1]]$party, favourite_prob = ps[[1]]$win_prob,
       final_two = final_two(s), parties = ps)
})

# chamber block from the simulation totals
q <- function(x) as.list(round(stats::quantile(x, c(0.05, 0.25, 0.5, 0.75, 0.95)), 1))
row_max <- do.call(pmax, as.list(sims[, ..parties]))   # once, not once per party
# p_most_seats counts a tie for most seats for EVERY tied party, so the
# parties' values sum past 1 (by about the tie share). The ITG page shows the
# majors side by side, where readers add them up: p_most_seats_strict counts
# only outright leads, and p_tie_most (chamber level) is the rest.
n_at_max <- Reduce(`+`, lapply(parties, function(p) sims[[p]] == row_max))
chamber <- lapply(parties, function(p) list(party = p, expected = round(mean(sims[[p]]), 2),
                                            p_majority = round(mean(sims[[p]] >= majority), 4),
                                            p_most_seats = round(mean(sims[[p]] == row_max), 4),
                                            p_most_seats_strict = round(mean(sims[[p]] == row_max & n_at_max == 1L), 4),
                                            quantiles = q(sims[[p]])))
p_tie_most <- round(mean(n_at_max > 1L), 4)
names(chamber) <- parties
hung <- mean(row_max < majority)
maj_l <- if ("LNP" %in% parties) sims$LNP else 0; maj_a <- if ("ALP" %in% parties) sims$ALP else 0
onp <- if ("ONP" %in% parties) sims$ONP else 0
# One Nation balance of power: no majority, and One Nation's seats would carry the larger major over the line
onp_bop <- mean(pmax(maj_l, maj_a) < majority & pmax(maj_l, maj_a) + onp >= majority & onp > 0)
gitsha <- tryCatch(trimws(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)), error = function(e) NA_character_)
# Locally promote_rebuild.R writes output/shipped/MANIFEST.json; on CI the
# workflow downloads the release's copy to output/MANIFEST.json. Read whichever
# exists (the first live JSON had models_promoted_at null for this reason).
man_f <- Filter(file.exists, c(file.path(OUT, "shipped", "MANIFEST.json"), file.path(OUT, "MANIFEST.json")))
man <- if (length(man_f)) jsonlite::fromJSON(man_f[1]) else NULL
if (is.null(man)) cat("FJ1! no MANIFEST.json found -- models_promoted_at will be null
")
doc <- list(
  election = CFG$election, election_date = CFG$election_date, built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  git_sha = gitsha, models_promoted_at = if (!is.null(man)) man$promoted_at else NULL,
  # The track record the ITG page quotes, straight from the promoted models' manifest
  # (AEF-7 ledger), so the page's numbers move with every publish instead of being typed in.
  track_record = if (!is.null(man) && !is.null(man$aef7)) c(man$aef7, list(pairs = man$pairs, seat_elections = man$seat_elections)) else NULL,
  # which commit of d-j-hirst/aus-polling-analyser the polls came from (set by
  # the workflow; NULL locally). The poll file itself is polls-vic-snapshot.csv on the release.
  poll_source = list(repo = "d-j-hirst/aus-polling-analyser",
                     sha = if (nzchar(Sys.getenv("AUSPOL_ANCHOR_SHA"))) Sys.getenv("AUSPOL_ANCHOR_SHA") else NULL),
  chamber_seats = CHAMBER, seats_simulated = n_seats, seats_not_simulated = I(excluded),   # I(): always a JSON array, even for one seat
  majority = majority, n_sims = nrow(sims),
  chamber = list(parties = chamber, p_hung = round(hung, 4), p_onp_balance_of_power = round(onp_bop, 4), p_tie_most = p_tie_most),
  seats = seat_rows)
out_f <- file.path(OUT, sprintf("%s%s.json", CFG$json_stem, SUF))   # a suffixed (diagnostic) run never overwrites the published name
writeLines(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null", digits = 4), out_f)
cat(sprintf("FJ2  wrote %s (%.0f KB)\n", out_f, file.size(out_f) / 1024))

# history: one row per build
hist_f <- file.path(OUT, sprintf("%s%s.csv", CFG$history_stem, SUF))
row <- data.table(built_at = doc$built_at, git_sha = gitsha, p_hung = round(hung, 4), p_onp_bop = round(onp_bop, 4))
for (p in parties) { row[[paste0("exp_", p)]] <- round(mean(sims[[p]]), 2); row[[paste0("pmaj_", p)]] <- round(mean(sims[[p]] >= majority), 4) }
# built_at read as text: left to guess, fread parses it as a datetime and
# fwrite writes it back in another format, so the column's shape drifted
# between days (26 Sep row) and would clash with the new character row.
H <- if (file.exists(hist_f)) rbind(fread(hist_f, showProgress = FALSE, colClasses = list(character = "built_at")), row, fill = TRUE) else row
fwrite(H, hist_f)
cat(sprintf("FJ3  history now %d row(s): %s\n", nrow(H), paste(sprintf("%s %.1f", parties, unlist(row[, paste0("exp_", parties), with = FALSE])), collapse = ", ")))
cat(sprintf("FJ3  P(hung) %.3f | P(One Nation balance of power) %.3f\n", hung, onp_bop))
