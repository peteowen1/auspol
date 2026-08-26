# A persistent identity for every candidate, across elections, seats and parties.
#
# WHY. The forecast is party-class based and cannot tell whether the independent
# standing in a seat is the one who polled 35% last time or a stranger. Measured
# across 17 election pairs, that single fact moves a 30% seat to 30.3% or to
# 12.1% -- an 18-point swing the model cannot currently see. It is also what a
# candidate profile page needs: every contest one person has ever fought.
#
# METHOD. Exact first, fuzzy second, human third.
#   1. Normalised surname + given name, matched exactly -> auto-linked.
#   2. Remaining names compared within region by edit distance, with the score
#      reported so a person can triage rather than a threshold deciding silently.
#   3. Anything ambiguous is written to a review queue, never guessed.
#
# WHAT IT DOES NOT DO. It will not merge two genuinely different people who
# share a name, and it will not split someone recorded as Bob and Robert --
# both are left for review. Splitting is the worse error: it turns a returning
# member into a fabricated emergence, which is what four NSW seats did when the
# emergence definition keyed on party class instead of person.
#
# Emits CI* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

C <- fread("output/candidacies.csv", showProgress = FALSE)
C[, `:=`(sur = surname_of(surname, name), giv = given_of(given, name))]
# SCOPE SURNAME-ONLY ROWS TO THEIR SEAT. Western Australia publishes
# BALLOT_PAPER_NAME as a bare surname -- the cached WAEC JSON carries four
# fields and no given name at all -- so 2,803 rows (19% of the corpus, every WA
# election) have a surname and nothing else. Keyed on surname alone they merge
# across the state: every Smith became ONE person with 19 contests in 16 seats
# spanning 1996-2025, which is not a career, it is a collision.
#
# Within a seat, a surname recurring across elections is very likely the same
# person; across seats it is not. So those rows carry the seat in their key.
# The cost is real and is recorded rather than hidden: a WA candidate who moves
# seat becomes two people, and `identity` says which rows are affected.
C[, key := match_key(sur, giv, "full")]
C[, identity := fifelse(nzchar(giv), "name", "surname-only (seat-scoped)")]
C[!nzchar(giv), key := paste(region, seat, sur, sep = "|")]
C[, key_loose := match_key(sur, giv, "initial")]
cat(sprintf("CI0  %d rows have no given name (%.0f%%), all in %s -- keyed within seat
",
            sum(!nzchar(C$giv)), 100 * mean(!nzchar(C$giv)),
            paste(sort(unique(C[!nzchar(giv)]$region)), collapse = ", ")))
cat(sprintf("CI1  %d candidacies | %d distinct exact keys | %d with no surname\n",
            nrow(C), uniqueN(C$key), sum(!nzchar(C$sur))))

# ---- 1. exact clusters -------------------------------------------------------
P <- C[nzchar(sur), .(identity = identity[1], contests = .N, elections = uniqueN(election),
                      regions = uniqueN(region), seats = uniqueN(seat),
                      parties = uniqueN(party),
                      first = min(year), last = max(year)), by = .(key, sur, giv)]
setorder(P, -contests)
P[, candidate_id := sprintf("c%05d", .I)]
cat(sprintf("CI2  %d distinct people by exact name | %d contested more than once\n",
            nrow(P), P[contests > 1, .N]))

# ---- 2. same person, two spellings? ------------------------------------------
# Names sharing a surname AND a seat but differing in the given name are the
# Bob/Robert case. Edit distance ranks them; nothing is merged automatically.
S <- merge(C[nzchar(sur), .(key, sur, giv, region, seat, election, year, party, pcv)],
           P[, .(key, candidate_id)], by = "key")
cand <- S[, .(n = uniqueN(key)), by = .(region, seat, sur)][n > 1]
rev <- list()
for (i in seq_len(nrow(cand))) {
  g <- unique(S[region == cand$region[i] & seat == cand$seat[i] & sur == cand$sur[i],
                .(key, giv, candidate_id, election, party, pcv)])
  ks <- unique(g$giv)
  if (length(ks) < 2) next
  for (a in seq_along(ks)) for (b in seq_along(ks)) {
    if (b <= a) next
    d <- as.integer(utils::adist(ks[a], ks[b]))
    sim <- 1 - d / max(nchar(ks[a]), nchar(ks[b]), 1)
    # A shared prefix is the nickname signature: rob/robert, bill/william is not.
    pref <- substr(ks[a], 1, 3) == substr(ks[b], 1, 3)
    rev[[length(rev) + 1L]] <- data.table(
      region = cand$region[i], seat = cand$seat[i], surname = cand$sur[i],
      given_a = ks[a], given_b = ks[b], distance = d, similarity = round(sim, 2),
      shared_prefix = pref,
      elections_a = paste(sort(unique(g[giv == ks[a]]$election)), collapse = " "),
      elections_b = paste(sort(unique(g[giv == ks[b]]$election)), collapse = " "))
  }
}
R <- if (length(rev)) rbindlist(rev) else data.table()
if (nrow(R)) {
  R[, verdict := fifelse(similarity >= 0.6 | shared_prefix, "LIKELY SAME - review",
                  fifelse(similarity >= 0.3, "possible - review", "different"))]
  setorder(R, -similarity)
}
cat(sprintf("CI3  %d surname+seat groups hold more than one given name | %d pairs to triage\n",
            nrow(cand), nrow(R)))
if (nrow(R)) print(R[verdict != "different"][1:min(25, .N),
     .(seat, surname, given_a, given_b, sim = similarity, elections_a, elections_b, verdict)],
     row.names = FALSE)

# ---- 3. sanity: people who look impossible ----------------------------------
cat("\nCI4  clusters worth a second look (one NAME, many places or a long career)\n")
odd <- P[contests > 1 & (regions > 1 | seats > 3 | (last - first) > 20)]
setorder(odd, -contests)
print(head(odd[, .(surname = sur, given = giv, contests, seats, regions,
                   span = paste0(first, "-", last))], 12), row.names = FALSE)

# ---- 4. RESOLVE, and say which rule decided each one -------------------------
# A prefix or a known nickname merges. A spelling variant (similarity >= 0.85)
# merges. Unrelated names do not. Anything left is AMBIGUOUS and is merged only
# when a human says so -- never by a threshold, because "jane"/"shane" scores
# 0.60 and is two people while "sue"/"susan" scores 0.40 and is one.
NICK <- list(sue="susan", sandy="sandra", matt="matthew", mike="michael",
  dan="daniel", danny="daniel", rob="robert", bob="robert", bill="william",
  will="william", ken="kenneth", kenny="kenneth", andy="andrew", alf="alfred",
  tom="thomas", tim="timothy", jim="james", jimmy="james", nick="nicholas",
  tony="anthony", steve="stephen", dave="david", pete="peter", ricky="richard",
  dick="richard", liz="elizabeth", beth="elizabeth", kate="katherine",
  cathy="catherine", kathy="katherine", ted="edward", harry="henry",
  jack="john", chris="christopher", josh="joshua", greg="gregory",
  alex="alexandra")
nick_pair <- function(a, b) {
  f <- function(x, y) (!is.null(NICK[[x]]) && NICK[[x]] == y)
  mapply(function(x, y) f(x, y) || f(y, x), a, b)
}
# Reviewed 2026-08-27 and judged DIFFERENT people: distinct first names that
# merely score high on edit distance.
DIFFERENT <- c("foreman|jane|shane", "jelfs|beverley|bradley",
               "nasr|clint|juliat", "dobby|ian|karen")
if (nrow(R)) {
  R[, prefix := startsWith(given_a, given_b) | startsWith(given_b, given_a)]
  R[, nick := nick_pair(given_a, given_b)]
  R[, pairkey := paste(surname, pmin(given_a, given_b), pmax(given_a, given_b), sep = "|")]
  R[, resolution := fifelse(pairkey %in% DIFFERENT, "different (reviewed)",
                     fifelse(prefix | nick, "same (prefix/nickname)",
                      fifelse(similarity >= 0.85, "same (spelling variant)",
                       fifelse(similarity < 0.35, "different (unrelated)",
                               "AMBIGUOUS - unreviewed"))))]
  cat("
CI5  resolution of the review queue
")
  print(R[, .N, by = resolution][order(-N)], row.names = FALSE)
  # MERGE the confirmed-same pairs onto one id.
  M <- R[startsWith(resolution, "same")]
  if (nrow(M)) {
    for (i in seq_len(nrow(M))) {
      ids <- P[sur == M$surname[i] & giv %in% c(M$given_a[i], M$given_b[i]), candidate_id]
      if (length(ids) > 1) P[candidate_id %in% ids, candidate_id := min(ids)]
    }
    cat(sprintf("CI5  merged %d pairs onto a shared id
", nrow(M)))
  }
  amb <- R[resolution == "AMBIGUOUS - unreviewed"]
  if (nrow(amb)) {
    cat(sprintf("CI5! %d pair(s) UNREVIEWED -- left as separate people, listed so the
", nrow(amb)))
    cat("     gap is visible rather than silently decided:
")
    print(amb[, .(seat, surname, given_a, given_b, sim = similarity)], row.names = FALSE)
  }
  S <- merge(S[, -"candidate_id"], P[, .(key, candidate_id)], by = "key")
}

fwrite(P[, .(candidate_id, surname = sur, given = giv, identity, key, contests,
             elections, seats, regions, parties, first, last)], "output/candidate-ids.csv")
fwrite(S[, .(candidate_id, election, region, seat, party, pcv, surname = sur, given = giv)],
       "output/candidate-contests.csv")
if (nrow(R)) fwrite(R, "output/candidate-review.csv")
cat(sprintf("\nCI9  wrote candidate-ids.csv (%d people), candidate-contests.csv (%d rows)%s\n",
            nrow(P), nrow(S),
            if (nrow(R)) sprintf(", candidate-review.csv (%d pairs)", nrow(R)) else ""))
