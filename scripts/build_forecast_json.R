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
    # `source` value of the commission's final list in output/candidacies.csv (nominations closed 9 Nov 2026):
    # names come from there once those rows exist. NA = no final list yet, Wikipedia names are used.
    final_source = "vec",
    # Legislative Council region per district (Wikipedia, tracked): the ITG
    # page groups the seat table and a map by it.
    region_file = file.path("external", "reference", "vec", "vic-district-regions.csv")),
  nsw2027 = list(
    election = "nsw2027",
    # Saturday 13 March 2027, brought forward two weeks from the fixed-term date to
    # avoid Easter (NSWEC Bulletin No. 2, 27 May 2026; Electoral Legislation
    # Amendment (Elections) Act 2026). The anchor's election-cycles.csv still says
    # 2027-03-20: do not take the date from there. Literal, not election_dates():
    # this block runs before the package is loaded. Keep equal to R/election_dates.R.
    election_date = "2027-03-13",
    chamber_seats = 93L,             # Legislative Assembly; all NSW harness years (2015/19/23) score 93 (docs/DATA-REGISTRY.md)
    majority = 47L,                  # 93 %/% 2 + 1
    file_tag = "nsw-2027",           # fit_seats_full.R with AUSPOL_TARGET=nsw2027 writes these
    json_stem = "forecast-nsw2027",
    history_stem = "forecast-history-nsw2027",   # separate file: the shared name would mix NSW rows into Victoria's chart
    candidates_file = file.path("external", "reference", "wikipedia", "nsw2027-candidates.csv"),  # parse_wikipedia_candidates.py ... nsw2027 (2026-10-08)
    final_source = NA_character_,    # nominations not closed: Wikipedia names
    # Hand-coded 2026-10-09 (Pete chose ~8 hand regions): NSW has no upper-house
    # regions, so these are Sydney in five parts plus four regional groups,
    # assigned from each district's position (ABS SED 2022 boundaries).
    region_file = file.path("external", "reference", "nsw", "nsw-district-regions.csv")))
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
# THE FINAL NOMINATIONS, once the commission has published them (2026-11-15). The Wikipedia table above is a
# provisional list: on 15 Nov it had 380 names against the VEC's 734, left 219 of 572 seat cards' party rows
# with no name, and named a Liberal in Croydon who did not nominate. output/candidacies.csv carries the
# commission's list (source == CFG$final_source) with the SAME party class the model uses, ballot order, and
# who holds the seat (historic_elected); the daily workflow downloads it with the models. When those rows
# exist they replace the Wikipedia names; an election with no final list yet keeps Wikipedia.
pretty_name <- function(x) {   # "MCRAE, Ross" -> "Ross McRae"; "DAVINDER KAUR" -> "Davinder Kaur"
  cap <- function(s) {
    s <- gsub("(^|[ '-])([[:alpha:]])", "\\1\\U\\2", tolower(s), perl = TRUE)
    gsub("\\bMc([[:alpha:]])", "Mc\\U\\1", s, perl = TRUE)
  }
  has_comma <- grepl(",", x, fixed = TRUE)
  sur <- trimws(sub(",.*$", "", x)); giv <- trimws(sub("^[^,]*,", "", x))
  ifelse(has_comma, paste(giv, cap(sur)), cap(trimws(x)))
}
CAND_SOURCE <- if (is.null(cands)) "none" else "wikipedia"
cc_f <- Sys.getenv("AUSPOL_CAND_OUT", file.path(OUT, "candidacies.csv"))   # the builder's own override, for a scratch copy
if (!is.null(CFG$final_source) && !is.na(CFG$final_source) && file.exists(cc_f)) {
  cc <- fread(cc_f, showProgress = FALSE, encoding = "UTF-8",
              select = c("election", "year", "seat", "name", "party", "historic_elected", "ballot_position",
                         "source", "pcv"))
  keep_cc <- cc$election == ELECTION & cc$source == CFG$final_source
  # Each final-list name's best earlier vote share anywhere in the corpus (2026-11-16). Where a class has
  # several candidates, the class's vote is mostly the one with a record: Essendon's Independent share is
  # Oscar Yildiz's carried 23.5 from Pascoe Vale 2018, and ballot order alone named Ava Adams.
  this_year <- suppressWarnings(as.integer(cc$year[which(keep_cc)][1]))
  name_key <- toupper(trimws(cc$name))
  earlier <- which(!keep_cc & cc$year < this_year & is.finite(cc$pcv))
  prior_best <- if (length(earlier)) tapply(cc$pcv[earlier], name_key[earlier], max) else numeric(0)
  cc[, prior_pcv := as.numeric(prior_best[name_key])]
  cc <- cc[which(keep_cc)]
  if (nrow(cc)) {
    # `sitting` (holds THIS seat) stays with the Wikipedia table, matched on seat and the last word of the
    # surname. historic_elected is not that: on 15 Nov it was TRUE for 69 candidates against 67 sitting members,
    # the extra two being Preston's independent William Fowles and Evelyn's Family First candidate Michelle
    # O'Brien, neither of whom holds the seat they are standing in (Lambert and Vallence do).
    last_word <- function(x) tolower(sub("^.*[ ]", "", trimws(x)))
    wiki_sit <- if (!is.null(cands) && "sitting" %in% names(cands))
      paste(cands$seat, last_word(cands$name))[which(cands$sitting %in% c(TRUE, "TRUE"))] else character(0)
    fin <- data.table(seat = cc$seat, name = pretty_name(cc$name), party = cc$party,
                      sitting = paste(cc$seat, last_word(sub(",.*$", "", cc$name))) %in% wiki_sit,
                      prior = ifelse(is.na(cc$prior_pcv), -1, cc$prior_pcv),
                      ballot = as.integer(cc$ballot_position))
    cat(sprintf("FJ4  sitting members: %d of the %d the Wikipedia table lists are on the final list\n",
                sum(fin$sitting), length(wiki_sit)))
    # the sitting member first, then the best earlier vote, then ballot order: the first name of a class is
    # the one the card shows
    fin <- fin[order(fin$seat, fin$party, -fin$sitting, -fin$prior, fin$ballot)]
    # FJ6 counts the cards where the earlier vote changed the name, against sitting-then-ballot order
    multi <- fin[, .(n = .N, moved = ballot[1] != min(ballot[sitting == sitting[1]])), by = .(seat, party)][n > 1]
    cat(sprintf("FJ6  seat-classes with several candidates: %d; named by an earlier vote, not ballot order: %d\n",
                nrow(multi), sum(multi$moved, na.rm = TRUE)))
    no_list <- setdiff(shares$seat, fin$seat)
    if (length(no_list)) stop("FJ4! ", ELECTION, ": the final candidate list has no rows for ", length(no_list),
                              " published seat(s): ", paste(no_list, collapse = ", "))
    cands <- fin; CAND_SOURCE <- CFG$final_source
  } else cat(sprintf("FJ4! %s: %s has no '%s' rows for this election -- names fall back to the provisional Wikipedia table\n",
                     ELECTION, cc_f, CFG$final_source))
}
cat(sprintf("FJ4  candidate names from: %s (%d rows)\n", CAND_SOURCE, if (is.null(cands)) 0L else nrow(cands)))

# Region per district (CFG$region_file): the ITG page groups the seat table and a map by it.
reg_f <- CFG$region_file
REG <- if (!is.na(reg_f) && file.exists(reg_f)) fread(reg_f, showProgress = FALSE) else NULL
region_of <- function(s) if (is.null(REG)) NULL else { r <- REG[district == s]$region; if (length(r)) r[1] else NULL }
# A table that misses a district would publish region = null for it and the page
# would drop it from its group silently: every published seat must have one.
if (!is.null(REG)) {
  if (anyDuplicated(REG$district)) stop("FJ0! ", reg_f, ": duplicated district(s) ", paste(REG$district[duplicated(REG$district)], collapse = ", "))
  no_reg <- setdiff(shares$seat, REG$district)
  if (length(no_reg)) stop("FJ0! ", reg_f, " has no region for ", length(no_reg), " seat(s): ", paste(no_reg, collapse = ", "))
  cat(sprintf("FJ0 regions: %d of %d seats, %d regions
", length(intersect(shares$seat, REG$district)), length(shares$seat), uniqueN(REG$region)))
}
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
# Every final-two pair in 1%+ of runs (fit_seats_full.R TCP2; Pete 23 Nov), most likely first; final_two above is
# the first of these. A missing file (an older fit) publishes [] and says so.
pairs_f <- file.path(OUT, sprintf("seat-tcp-pairs-%s%s.csv", CFG$file_tag, SUF))
TPAIRS <- if (file.exists(pairs_f)) fread(pairs_f, showProgress = FALSE) else NULL
if (is.null(TPAIRS)) cat(sprintf("FJ1! %s missing -- seats published with final_twos []\n", basename(pairs_f)))
final_twos <- function(st) {
  if (is.null(TPAIRS)) return(I(list()))
  r <- TPAIRS[which(TPAIRS$seat == st)]
  # file order: most runs first, ties in the order final_two used, so final_twos[0] is final_two
  I(lapply(seq_len(nrow(r)), function(i) list(a = r$a[i], b = r$b[i], p_pair = r$p_pair[i],
    a_tcp = if (is.na(r$a_tcp_q50[i])) NULL else list(q05 = r$a_tcp_q05[i], q50 = r$a_tcp_q50[i], q95 = r$a_tcp_q95[i]))))
}
# per-seat block
# WHICH SEATS' INDEPENDENTS WERE SPLIT (AUSPOL_CLASS_SPLIT, shipped 2026-11-18 with the cred2 gate): asked of the same
# class_split_args() the forecast run used, so a page can tell a seat whose Independent figure is one candidate's
# from one that adds several together. The R/ defaults are the published values, so a plain run here matches a plain
# fit_seats_full.R run. If it cannot be determined, `ind_split` is left out (never guessed) and FJ8! says so.
ind_split <- tryCatch({
  if (!exists("class_split_args")) suppressMessages(devtools::load_all(quiet = TRUE))
  cs <- NULL
  invisible(utils::capture.output(cs <- class_split_args(ELECTION, shares$seat)))
  sp <- if (is.null(cs)) character(0) else names(cs$cls)[!is.na(cs$cls) & cs$cls == "IND"]
  cat(sprintf("FJ8 %s: independents split in %d seat(s)%s\n", ELECTION, length(sp),
              if (length(sp)) paste0(": ", paste(sp, collapse = ", ")) else ""))
  sp
}, error = function(e) {
  cat(sprintf("FJ8! %s: could not tell which seats' independents were split (%s); ind_split left out of the JSON\n",
              ELECTION, conditionMessage(e)))
  NULL
})

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
         candidates = I(nm),   # every candidate of the class, the card's name first; always a JSON array
         sitting = if (!is.null(cands) && length(nm)) isTRUE(cands[seat == s & party == p]$sitting[1]) else NULL)
  })
  ps <- ps[order(-vapply(ps, `[[`, numeric(1), "win_prob"))]
  rec <- list(seat = s, region = region_of(s), favourite = ps[[1]]$party, favourite_prob = ps[[1]]$win_prob,
              final_two = final_two(s), final_twos = final_twos(s), parties = ps)
  if (!is.null(ind_split)) rec$ind_split <- s %in% ind_split   # TRUE: the Independent figure is split, not summed
  rec
})

# Named cells: a party row with a vote and no name is a card with a blank. With the final list in hand the four
# classes that stand almost everywhere must be named in at least 95% of the cells they have a vote in.
.cells <- rbindlist(lapply(seat_rows, function(sr) rbindlist(lapply(sr$parties, function(q)
  data.table(seat = sr$seat, party = q$party, voted = isTRUE(q$primary > 0), named = !is.null(q$candidate))))))
.voted <- .cells[which(.cells$voted)]
.main <- .voted[which(.voted$party %in% c("ALP", "LNP", "GRN", "ONP"))]
cat(sprintf("FJ5  named cells: %d of %d with a vote (ALP/LNP/GRN/ONP %d of %d); %d cell(s) carry a name and no vote\n",
            sum(.voted$named), nrow(.voted), sum(.main$named), nrow(.main), sum(.cells$named & !.cells$voted)))
if (!identical(CAND_SOURCE, "wikipedia") && !identical(CAND_SOURCE, "none") && nrow(.main) && mean(.main$named) < 0.95)
  stop(sprintf("FJ5! %s: only %d of %d ALP/LNP/GRN/ONP cells with a vote have a candidate name from the final list",
               ELECTION, sum(.main$named), nrow(.main)))

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
# THE STATEWIDE VOTE THE FORECAST USES (2026-11-16, review A6 / Issue 4; Pete's B2: the site's party tiles show
# it). fit_seats_full.R's FP0 line is the blended level every seat starts from; the page's tiles showed the
# poll trend (build_page.R's fp_now), 0.9 apart for Labor on 15 Nov. forecast_level is that FP0 file;
# seats_mean is the plain average of the seat primaries (not voter-weighted), which is what the 88 seats add to.
lev_f <- file.path(OUT, sprintf("statewide-level-%s%s.csv", CFG$file_tag, SUF))
statewide <- NULL
if (!file.exists(lev_f)) {
  cat(sprintf("FJ7! %s missing -- published WITHOUT the statewide block\n", lev_f))
} else {
  # fit_seats_full.R writes the level a few minutes BEFORE the seat files, so it is always a little older;
  # more than 2 hours older means it came from another run, and the tiles would show a different forecast.
  lag_h <- as.numeric(difftime(file.mtime(f_shares), file.mtime(lev_f), units = "hours"))
  if (lag_h > 2) stop(sprintf("FJ7! %s is %.1f hours older than %s: not the same run", lev_f, lag_h, f_shares))
  LEV <- fread(lev_f, showProgress = FALSE)
  if (anyDuplicated(LEV$party) || !nrow(LEV)) stop("FJ7! ", lev_f, ": empty or duplicated parties")
  # The level's OTH is every minor class together (FP0 has LNP ALP GRN ONP OTH); the seats split it into
  # IND, OTH and OTH_RIGHT, so the seat columns the level does not name are added into its OTH.
  seat_cols <- setdiff(names(shares), "seat")
  fold <- setdiff(seat_cols, LEV$party)
  if (length(fold) && !"OTH" %in% LEV$party) stop("FJ7! ", lev_f, " has no OTH to hold seat classes ", paste(fold, collapse = ", "))
  sw_parties <- intersect(LEV$party, c(seat_cols, "OTH"))
  if (!length(sw_parties)) stop("FJ7! ", lev_f, ": no party in common with ", f_shares)
  seat_mean_of <- function(p) {
    cols <- if (p == "OTH") union(intersect("OTH", seat_cols), fold) else p
    mean(rowSums(as.matrix(shares[, cols, with = FALSE])))
  }
  statewide <- lapply(sw_parties, function(p) list(
    party = p, forecast_level = round(LEV$level[match(p, LEV$party)], 2),
    seats_mean = round(seat_mean_of(p), 2)))
  cat(sprintf("FJ7  seat classes counted in OTH: %s\n", paste(union(intersect("OTH", seat_cols), fold), collapse = ", ")))
  cat(sprintf("FJ7  statewide forecast level vs seat mean: %s\n",
              paste(vapply(statewide, function(r) sprintf("%s %.2f/%.2f", r$party, r$forecast_level, r$seats_mean), ""),
                    collapse = ", ")))
}
# SWITCHES THAT MOVED SINCE THE TREES WERE TRAINED (FJ9!, 23 Nov 2026). The site ran on trees promoted 13 Nov until
# 23 Nov while switches that change what the trees learn from were flipped on main; the age warning fired daily and
# was not read. This names each switch whose shipped value differs from the value in the trees' manifest, and the
# JSON carries the list, so anyone reading the forecast sees it. Not every switch acts before the trees: a listed one
# may be harmless (post-xgb), but only a retrain or a check of that switch says so. Manifests from before 23 Nov
# recorded the settings file, not the run's values (scripts/promote_rebuild.R).
flag_drift <- NULL
# Advisory only: an error here (an odd manifest value, the settings file not found) prints FJ9! and never stops the forecast.
if (!is.null(man) && !is.null(man$flags)) tryCatch({
  if (!exists("PUBLISHED_FLAGS")) source(file.path("scripts", "published_flags.R"))
  .now <- vapply(names(PUBLISHED_FLAGS), function(n) as.character(PUBLISHED_FLAGS[[n]]), "")
  .was <- vapply(names(PUBLISHED_FLAGS), function(n) if (is.null(man$flags[[n]])) NA_character_ else as.character(man$flags[[n]]), "")
  .d <- names(.now)[is.na(.was) | .was != .now]
  flag_drift <- lapply(.d, function(n) list(switch = n, trees = unname(.was[n]), now = unname(.now[n])))
  if (length(.d)) cat(sprintf("FJ9! %d switch(es) differ from the shipped trees' manifest (promoted %s): %s -- retrain, or check each acts after the trees\n",
                              length(.d), man$promoted_at, paste(sprintf("%s %s->%s", .d, ifelse(is.na(.was[.d]), "(absent)", .was[.d]), .now[.d]), collapse = ", ")))
  else cat(sprintf("FJ9  every shipped switch matches the trees' manifest (promoted %s)\n", man$promoted_at))
}, error = function(e) { flag_drift <<- NULL; cat(sprintf("FJ9! could not compare the switches with the trees' manifest: %s\n", conditionMessage(e))) })
doc <- list(
  election = CFG$election, election_date = CFG$election_date, built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  git_sha = gitsha, models_promoted_at = if (!is.null(man)) man$promoted_at else NULL,
  models_flag_drift = I(if (is.null(flag_drift)) list() else flag_drift),   # I(): always an array
  # The track record the ITG page quotes, straight from the promoted models' manifest
  # (AEF-7 ledger), so the page's numbers move with every publish instead of being typed in.
  track_record = if (!is.null(man) && !is.null(man$aef7)) c(man$aef7, list(pairs = man$pairs, seat_elections = man$seat_elections)) else NULL,
  # which commit of d-j-hirst/aus-polling-analyser the polls came from (set by
  # the workflow; NULL locally). The polls the run read are polls-<region>-snapshot.csv on the release (scripts/build_poll_snapshot.R).
  poll_source = list(repo = "d-j-hirst/aus-polling-analyser",
                     sha = if (nzchar(Sys.getenv("AUSPOL_ANCHOR_SHA"))) Sys.getenv("AUSPOL_ANCHOR_SHA") else NULL),
  chamber_seats = CHAMBER, seats_simulated = n_seats, seats_not_simulated = I(excluded),   # I(): always a JSON array, even for one seat
  majority = majority, n_sims = nrow(sims),
  chamber = list(parties = chamber, p_hung = round(hung, 4), p_onp_balance_of_power = round(onp_bop, 4), p_tie_most = p_tie_most),
  statewide = statewide,
  seats = seat_rows)
out_f <- file.path(OUT, sprintf("%s%s.json", CFG$json_stem, SUF))   # a suffixed (diagnostic) run never overwrites the published name
writeLines(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null", na = "null", digits = 4), out_f)   # numeric NA (a same-class final two) as null, not the string "NA"
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
