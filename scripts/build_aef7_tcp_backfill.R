# Fill the 28-seat gap (27 vic2022, 1 nsw2023) in
# output/aef7-final-two-and-tcp-reference.csv where f1/f2/f2cp were never
# resolved -- AND null out any seat where the real top-two candidates are
# an INTRA-COALITION contest (Liberal vs National), which our own
# classify_party() collapses to a single "LNP" bucket with nothing to pair
# it against.
#
# FOUND 2026-09-18, by Pete asking why Port Macquarie (nsw2023) was the
# only excluded seat out of 660 when 125 seats have a >50%-primary winner.
# It wasn't a >50% thing at all: the ABC's own results page showed the real
# contest was Liberal (Leslie Williams, 60.8%) vs National (Peta Pinson,
# 39.2%) -- AEF's cache recording only one "LNP" entry isn't a scrape bug,
# it is the SAME collapse happening on their side. Checking the rest of the
# AEF7 corpus (via candidacies.csv's raw, pre-classification party labels)
# found two more: wa2025 Mid-West (a seat name that does not survive WA's
# redistribution into this corpus at all, a separate known gap) and wa2025
# Roe -- which was NOT excluded. Roe's reference row already carried a
# WRONG, implausible resolved pairing (f1=LNP, f2=OTH, f2cp=97.5%) from
# whichever "official"/"derived" process built it, silently sitting in the
# "good" 659 rather than flagged. That is worse than a gap: a wrong number
# nobody was looking for. Fixed by detecting every intra-Coalition top-two
# seat from the raw candidacy data and excluding all of them the same way,
# not just the one this session happened to notice by hand.
#
# WHY THIS EXISTS. Found 2026-09-18 while scoring TCP against the real
# pairing for all 660 AEF-7 seats (scripts/build_aef7_tcp_actual.R): 28
# seats had no resolved final-two at all, so they were excluded from every
# TCP metric. Assumed this meant the source data did not exist. It does:
# external/reference/aef/<code>-results.json's `results$seats[[seat]]$tcp`
# is AEF's own cache of the REAL post-election two-candidate-preferred
# result -- `list(fp=..., tcp=list(PartyA=X, PartyB=Y))` -- already on disk
# for every seat in vic2022 and nsw2023, just never read by any script.
# Same lesson CLAUDE.md already records about this repo: check what is
# actually on disk before writing "we don't have it" into a plan.
#
# f1 is whichever of the two named parties has the HIGHER tcp share (the
# winner, by definition of a two-candidate-preferred count with exactly two
# entries); f2cp is that winner's share. fsrc = "aef-cache" -- distinct from
# "official" (the federal/SA rows sourced from the AEC/SA-EC directly) and
# from a starred "derived" value (reconstructed from published preference
# flows) -- this is neither: it is AEF's own scrape of the real result, one
# step removed from the primary source, so it is labelled rather than
# folded into "official" silently.
#
# Emits ATB codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(jsonlite))

OUT <- "output"
RAW <- file.path("external", "reference", "aef")
RESULTS <- c(vic2022 = "2022vic", nsw2023 = "2023nsw")

ref <- fread(file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), showProgress = FALSE)

# ---- Detect and exclude every intra-Coalition top-two seat first, so the
# fill step below never tries to resolve one of these. ----
AEF7_ELEC <- c("fed2022","fed2025","nsw2023","qld2024","sa2026","vic2022","wa2025")
CAND <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
c7 <- CAND[election %in% AEF7_ELEC]
setorder(c7, election, seat, -pcv)
top2 <- c7[, .SD[1:min(2, .N)], by = .(election, seat)]
top2n <- top2[, .N, by = .(election, seat)]
pairs2 <- top2[top2n[N == 2], on = .(election, seat)]
intra <- pairs2[, .(n_distinct_cls = uniqueN(party)), by = .(election, seat)][n_distinct_cls == 1]
intra[, pair := election]
cat(sprintf("ATBc %d intra-Coalition (same-class top-two) seat(s) in the AEF7 corpus: %s\n",
            nrow(intra), paste(intra$seat, collapse = ", ")))
if (nrow(intra)) {
  ref[intra, on = c("pair", "seat"), `:=`(f1 = NA_character_, f2 = NA_character_,
                                            f2cp = NA_real_, fsrc = "intra-coalition-excluded")]
}
gap <- ref[is.na(f1) | is.na(f2) | f1 == "" | f2 == ""]
cat(sprintf("ATB0 %d rows to try to fill (%s)\n", nrow(gap),
            paste(names(table(gap$pair)), table(gap$pair), sep = "=", collapse = ", ")))

filled <- rbindlist(lapply(names(RESULTS), function(pr) {
  fs <- file.path(RAW, sprintf("%s-results.json", RESULTS[[pr]]))
  if (!file.exists(fs)) { cat(sprintf("ATB1! missing %s for %s\n", fs, pr)); return(NULL) }
  j <- fromJSON(fs, simplifyVector = FALSE)
  seats <- j$results$seats
  want <- gap[pair == pr]$seat
  rows <- lapply(want, function(sn) {
    s <- seats[[sn]]
    if (is.null(s) || is.null(s$tcp) || length(s$tcp) != 2) return(NULL)
    parties <- names(s$tcp)
    vals <- vapply(s$tcp, as.numeric, numeric(1))
    win_i <- which.max(vals)
    data.table(pair = pr, seat = sn, f1 = parties[win_i], f2 = parties[-win_i][1],
               f2cp = round(vals[win_i], 1), fsrc = "aef-cache")
  })
  rbindlist(rows, fill = TRUE)
}), fill = TRUE)
if (!nrow(filled)) filled <- data.table(pair = character(), seat = character(),
                                          f1 = character(), f2 = character(),
                                          f2cp = numeric(), fsrc = character())

cat(sprintf("ATB2 resolved %d of %d gap rows from the cached real results\n", nrow(filled), nrow(gap)))
still_missing <- fsetdiff(gap[, .(pair, seat)], filled[, .(pair, seat)])
if (nrow(still_missing)) {
  cat("ATB2! still unresolved (includes intra-Coalition exclusions, expected):\n"); print(still_missing)
}

# Merge the fills back into the reference table -- only the 28 target rows
# change, everything else (the 632 already-resolved rows and their existing
# aef_tcp_* columns) passes through untouched.
ref[filled, on = c("pair", "seat"), `:=`(f1 = i.f1, f2 = i.f2, f2cp = i.f2cp, fsrc = i.fsrc)]

n_resolved_now <- sum(!(is.na(ref$f1) | is.na(ref$f2) | ref$f1 == "" | ref$f2 == ""))
cat(sprintf("ATB3 reference file now has %d of %d seats with a resolved final-two\n", n_resolved_now, nrow(ref)))

fwrite(ref, file.path(OUT, "aef7-final-two-and-tcp-reference.csv"))
cat(sprintf("ATB4 wrote %s\n", file.path(OUT, "aef7-final-two-and-tcp-reference.csv")))
