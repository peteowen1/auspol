# South Australian 2022 first preferences, and declared winners for both cycles.
#
# WHY A SECOND SCRIPT RATHER THAN AN EXTENSION. scripts/fetch_preferences_sa.R
# reads first preferences out of `finalDistribution`, which is the right source
# when it exists -- it is the count's own round 0. **ECSA publishes
# finalDistribution for 2026 and not for 2022.** So the 2022 first preferences
# have to come from the polling-place records instead, which is a different
# traversal of a differently-shaped payload, and bolting it into the middle of
# the 2026 path would make that function do two unrelated things.
#
# It also writes the DECLARED WINNERS, which nothing in the repo held for South
# Australia. Without them there is no truth to score a backtest against.
#
# THREE VOTE POOLS, NOT TWO. `pollingPlaces` carries ordinary votes,
# `candidates.declarationVotes` carries declaration votes, and `declarations`
# duplicates that same total -- summing both double-counts. `absentOrdinary` is
# separate again and is roughly a sixth of the vote. Omitting it put One
# Nation's 2026 statewide primary at 22.50% against an independently recorded
# 22.88%, and moved one seat from Liberal to Labor. The 2022 payload has no
# `absentOrdinary` key at all.
#
# Emits SF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

API <- "https://apim-ecsa-production.azure-api.net/results-display"
OUT <- election_data_path()
ELECTIONS <- list(list(year = 2022L, date = "2022-03-19"),
                  list(year = 2026L, date = "2026-03-21"))

get_json <- function(path) jsonlite::fromJSON(paste0(API, "/", path),
                                              simplifyVector = FALSE)
`%||%` <- function(a, b) if (is.null(a)) b else a

# Same normalisation as fetch_preferences_sa.R: the two endpoints spell a name
# differently and do NOT share candidate ids.
norm <- function(x) {
  x <- toupper(gsub("[^A-Za-z ]", " ", ifelse(is.na(x), "", x)))
  vapply(strsplit(trimws(gsub(" +", " ", x)), " "),
         function(p) paste(sort(p[nzchar(p)]), collapse = " "), character(1))
}

winners_all <- list()
for (E in ELECTIONS) {
  stat <- get_json(sprintf("HAStatic/%s", E$date))
  chg  <- get_json(sprintf("HAChange/%s/0", E$date))
  if (!identical(chg$electionStatus, "final")) {
    stop("SA ", E$year, ": electionStatus is ", chg$electionStatus %||% "NULL",
         ", not 'final'. These counts can still move.")
  }
  pm <- rbindlist(lapply(stat$districts, function(d) {
    cands <- d$candidates
    if (!length(cands)) return(NULL)
    data.table(seat = d$districtName,
               # BY ID, NOT BY NAME. pollingCandidates carries candidateId and
               # NO candidateName at all, so a name join silently matches
               # nothing and yields zero rows -- which is how the first version
               # of this failed. HAStatic, pollingCandidates, candidates and
               # absentOrdinary all number candidates 1..n by ballot position
               # within a district and DO share that id. Only finalDistribution
               # uses a different, global id space, and it is not read here.
               cand_id = vapply(cands, function(c) as.integer(c$candidateId %||% NA),
                                integer(1)),
               party = classify_party(
                 vapply(cands, function(c) c$partyName %||% "", character(1)),
                 vapply(cands, function(c) c$partyId   %||% "", character(1))))
  }))

  fp_rows <- list(); win_rows <- list()
  for (d in chg$districts) {
    seat <- d$districtId
    # Mask computed OUTSIDE the brackets -- `pm[pm$seat == seat, ]` binds the
    # bare names to columns. CLAUDE.md records this trap five times.
    keep <- which(pm$seat == seat)
    look <- setNames(pm$party[keep], as.character(pm$cand_id[keep]))

    acc <- list()
    push <- function(id, fv, tv) {
      if (is.null(id)) return(invisible(NULL))
      acc[[length(acc) + 1L]] <<- data.table(k = as.character(id),
                                             fv = as.numeric(fv %||% 0),
                                             tv = as.numeric(tv %||% 0))
    }
    for (pp in d$pollingPlaces %||% list()) {
      for (c in pp$pollingCandidates %||% list()) {
        push(c$candidateId, c$formalVotes, c$twoCandidatePref)
      }
    }
    for (c in d$candidates %||% list()) {
      push(c$candidateId, c$declarationVotes, c$twoCandidatePrefDeclarationVotes)
    }
    for (blk in d$absentOrdinary %||% list()) {
      for (cv in blk$candidateVotes %||% list()) {
        push(cv$candidateId, cv$votes, cv$twoCandidatePrefVotes)
      }
    }
    if (!length(acc)) next
    A <- rbindlist(acc)[, .(fv = sum(fv), tv = sum(tv)), by = k]
    tally <- setNames(A$fv, A$k); tcp <- setNames(A$tv, A$k)
    if (!length(tally)) next
    cls <- look[names(tally)]
    ok <- !is.na(cls) & tally > 0
    if (any(ok)) {
      fp_rows[[length(fp_rows) + 1L]] <- data.table(
        seat = seat, party = unname(cls[ok]), votes = unname(tally[ok]))
    }
    if (length(tcp) && max(tcp, na.rm = TRUE) > 0) {
      w <- names(tcp)[which.max(tcp)]
      win_rows[[length(win_rows) + 1L]] <- data.table(
        election = sprintf("sa%d", E$year), seat = seat,
        winner = unname(look[w]))
    }
  }

  fp <- rbindlist(fp_rows)[, .(votes = sum(votes)), by = .(seat, party)]
  win <- rbindlist(win_rows)
  if (uniqueN(fp$seat) != 47L || nrow(win) != 47L) {
    stop("SA ", E$year, ": ", uniqueN(fp$seat), " seats with first preferences ",
         "and ", nrow(win), " with a winner. South Australia has 47.")
  }

  st <- fp[, .(v = sum(votes)), by = party][, .(party, pct = 100 * v / sum(v))]
  setorder(st, -pct)
  cat(sprintf("\nSF1  SA %d: %s formal votes across 47 seats\n", E$year,
              format(sum(fp$votes), big.mark = ",")))
  print(st[, .(party, pct = round(pct, 2))])
  cat(sprintf("SF1  seats won: %s\n",
              paste(sprintf("%s %d", names(table(win$winner)),
                            as.integer(table(win$winner))), collapse = ", ")))

  # ANCHOR CHECK against figures recorded before this script existed. Nothing
  # internal can detect a missed vote pool -- every total is self-consistent
  # with or without absentOrdinary -- so an external number is the only guard.
  if (E$year == 2026L) {
    for (chk in list(c("ALP", 37.5), c("ONP", 22.9), c("GRN", 10.4))) {
      got <- st[party == chk[1], pct]
      if (!length(got) || abs(got - as.numeric(chk[2])) > 0.3) {
        stop("SA 2026 ", chk[1], ": ", round(got, 2), "% here against ",
             chk[2], "% recorded in docs/reviews/onp-allocation-sa-2026-08-17.md. ",
             "A vote pool is missing or double-counted.")
      }
    }
    cat("SF1  anchor check passes against the independently recorded shares.\n")
  }

  if (E$year == 2022L) {
    fwrite(fp, file.path(OUT, "ecsa-2022-sa-firstprefs.csv"))
    cat(sprintf("SF2  wrote %s\n", file.path(OUT, "ecsa-2022-sa-firstprefs.csv")))
  }
  winners_all[[length(winners_all) + 1L]] <- win
}

W <- rbindlist(winners_all)
fwrite(W, file.path(OUT, "ecsa-sa-winners.csv"))
cat(sprintf("\nSF3  wrote %s: %d rows across %d elections\n",
            file.path(OUT, "ecsa-sa-winners.csv"), nrow(W), uniqueN(W$election)))
print(W[, .N, by = .(election, winner)][order(election, -N)])
