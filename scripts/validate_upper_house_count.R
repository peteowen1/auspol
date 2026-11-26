# Measure Victorian Senate preferences from the ballots and check the upper-house count against real counts.
# Plan (pre-registered before fitting): docs/plans/upper-house-count-model-2026-11-26.md.
#
#   Rscript scripts/validate_upper_house_count.R
#
# In:  external/reference/aec/senate-prefs/ (gitignored): the AEC formal-preference zips, their MANIFEST.csv, the DOP
#      zips, and derived/vic{2022,2025}-{sequences.csv.gz,groups.csv} from scripts/parse_senate_formal_prefs.py.
# Out: external/reference/aec/senate-flows/ (small, committed): vic-senate-{yr}-boxes.csv (how many boxes
#      above-the-line voters numbered), vic-senate-{yr}-flow-matrix.csv (first party class -> next class, n per cell,
#      shrunk share), vic-senate-{yr}-flows.csv.gz (the compact class sequences the forecast counts with).
#      Prints V0 / V1 / V2 (see the plan), the old count() on the same inputs, and a deliberately broken flow set.
suppressPackageStartupMessages(library(data.table))
source("R/upper_house_count.R")
RAW <- Sys.getenv("AUSPOL_SENATE_PREFS_DIR", "external/reference/aec/senate-prefs")   # a worktree can point at the main checkout's copy
DER <- file.path(RAW, "derived"); OUT <- "external/reference/aec/senate-flows"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
YEARS <- c(`2022` = "27966", `2025` = "31496")

# ---- actual results from the AEC distribution of preferences ----------------------------------------------
dop <- function(id) {
  f <- file.path(RAW, sprintf("SenateDopDownload-%s.zip", id))
  d <- as.data.table(utils::read.csv(unz(f, sprintf("SenateStateDOPDownload-%s-VIC.csv", id)), check.names = FALSE,
                                     stringsAsFactors = FALSE))
  last <- max(d$Count)
  el <- d[Status == "Elected" & Changed == "True"][order(`Order Elected`)]
  list(order = trimws(el$Ticket), formal = d$`Total Formal Papers`[1], quota = d$Quota[1],
       exhausted_final = d[Count == last & Surname == "Exhausted"]$ProgressiveVoteTotal)
}

load_year <- function(yr) {
  s <- fread(file.path(DER, sprintf("vic%s-sequences.csv.gz", yr)))
  g <- fread(file.path(DER, sprintf("vic%s-groups.csv", yr)), colClasses = list(character = c("letter", "name")))
  g[is.na(name), name := ""]
  list(s = s, g = g)
}
dat <- lapply(names(YEARS), load_year); names(dat) <- names(YEARS)
act <- lapply(YEARS, dop)
for (yr in names(YEARS)) {
  n <- sum(dat[[yr]]$s$n)
  cat(sprintf("UHC0  %s: %d ballots in the formal-preference file, %d formal in the DOP (%s); %d distinct sequences; %d groups\n",
              yr, n, act[[yr]]$formal, if (n == act[[yr]]$formal) "match" else "MISMATCH", nrow(dat[[yr]]$s), nrow(dat[[yr]]$g)))
  stopifnot(n == act[[yr]]$formal)
}

# ---- 1. boxes numbered, 2. flows ----------------------------------------------------------------------------
fits <- list()
for (yr in names(YEARS)) {
  bd <- uh_box_distribution(dat[[yr]]$s); fwrite(bd, file.path(OUT, sprintf("vic-senate-%s-boxes.csv", yr)))
  btl <- sum(dat[[yr]]$s[kind == "BTL"]$n)
  cat(sprintf("\nUHC1  %s above the line: %.1f%% numbered exactly 6 (the instruction), %.1f%% fewer (saved; %.1f%% a lone 1), %.1f%% more, %.1f%% every box (%d groups). Below the line: %.1f%% of ballots.\n",
              yr, 100 * bd[atl_marks == 6]$share, 100 * sum(bd[atl_marks < 6]$share), 100 * bd[atl_marks == 1]$share,
              100 * sum(bd[atl_marks > 6]$share), 100 * bd[atl_marks == max(atl_marks)]$share, max(bd$atl_marks),
              100 * btl / sum(dat[[yr]]$s$n)))
  f <- uh_fit_flows(dat[[yr]]$s, dat[[yr]]$g, 6L, label = paste0("vic-senate-", yr))
  fits[[yr]] <- f
  fm <- uh_flow_matrix(f); fwrite(fm, file.path(OUT, sprintf("vic-senate-%s-flow-matrix.csv", yr)))
  fc <- uh_compact_flows(f); uh_write_flows(fc, file.path(OUT, sprintf("vic-senate-%s-flows.csv.gz", yr)))
  cat(sprintf("UHC1  %s: first-preference ballots by class, and where the next preference goes (top 4, and EXH = numbers nothing else):\n", yr))
  for (k in fm[, .(n = n_first[1]), by = first][order(-n)]$first) {
    z <- fm[first == k][order(-n)]
    cat(sprintf("   %-6s n=%8d: %s | EXH %.1f%%\n", k, z$n_first[1],
                paste(sprintf("%s %.1f%%", z[nxt != "EXH"]$nxt[1:4], 100 * z[nxt != "EXH"]$share[1:4]), collapse = ", "),
                100 * sum(z[nxt == "EXH"]$share)))
  }
}

# ---- the old count() (scripts/build_upper_house_forecast.R, copied unchanged) ------------------------------
count_old <- function(v, bloc, aff, ex, transfers = TRUE, seats = 5L) {
  won <- setNames(integer(length(v)), names(v)); alive <- v > 0
  repeat {
    left <- seats - sum(won); if (left == 0L) break
    hit <- which(alive & v >= 1)
    if (length(hit)) { i <- hit[which.max(v[hit])]; won[i] <- won[i] + 1L; v[i] <- v[i] - 1; next }
    if (sum(alive) <= left) { won[alive] <- won[alive] + 1L; break }
    idx <- which(alive); lo <- idx[which.min(v[idx])]; alive[lo] <- FALSE
    rest <- which(alive)
    wt <- sqrt(pmax(v[rest], 1e-6)) * ifelse(bloc[rest] == bloc[lo] & bloc[lo] != "C", aff, ifelse(bloc[rest] == "C" | bloc[lo] == "C", 1, 1 / aff))
    v[rest] <- v[rest] + (1 - ex) * v[lo] * wt / sum(wt); v[lo] <- 0
  }
  won
}
LEFT <- "Labor|Greens|Socialist|Cannabis|Animal Justice"; RIGHT <- "Liberal|Nationals|One Nation|Family First|Libertarian|Shooters|DLP|Christian"

# ---- V0 / V1 / V2 ----------------------------------------------------------------------------------------------
show <- function(r, g) paste(g$letter[r$order], collapse = " ")
last2 <- function(r, g) {           # the two groups still in at the last decision, in quotas
  o <- order(-r$tally); o <- o[r$tally[o] > 0][1:2]
  paste(sprintf("%s %.3f", g$letter[o], r$tally[o] / r$quota), collapse = " vs ")
}
cat("\nUHC2  Recounts of the Victorian Senate (6 seats). Order = group letters in the order elected; actual from the AEC DOP.\n")
res <- list()
for (yr in names(YEARS)) {
  g <- dat[[yr]]$g; pt <- uh_ballot_patterns(dat[[yr]]$s, g$letter)
  r0 <- uh_stv(pt$votes, pt, 6L, g$candidates, trace = TRUE)
  ok <- identical(show(r0, g), paste(act[[yr]]$order, collapse = " "))
  cat(sprintf("V0  %s real ballots:        %s | actual %s | %s | exhausted at the end %.0f (actual %.0f) | last two %s\n",
              yr, show(r0, g), paste(act[[yr]]$order, collapse = " "), if (ok) "MATCH" else "MISS", r0$exhausted,
              act[[yr]]$exhausted_final, last2(r0, g)))
  res[[paste("V0", yr)]] <- ok
  for (src in names(YEARS)) {
    if (src > yr) next                                        # never fit on a later election (V2 = 2022 flows, 2025 count)
    tag <- if (src == yr) "V1" else "V2"
    for (sd in 1:3) {
      pat <- uh_region_patterns(g$name, uh_compact_flows(fits[[src]]), min_to = 6L, top = 150L, tail = 150L, seed = sd)
      r <- uh_stv(pt$votes, pat, 6L, g$candidates, trace = TRUE)
      ok <- identical(show(r, g), paste(act[[yr]]$order, collapse = " "))
      cat(sprintf("%s  %s with %s flows, seed %d: %s | %s | exhausted %.0f | last two %s\n", tag, yr, src, sd, show(r, g),
                  if (ok) "MATCH" else "MISS", r$exhausted, last2(r, g)))
      res[[paste(tag, yr, src, sd)]] <- ok
    }
  }
  # the old count on the same first preferences
  v <- pt$votes / (sum(pt$votes) / 7); names(v) <- g$letter
  bl <- ifelse(grepl(RIGHT, g$name), "R", ifelse(grepl(LEFT, g$name), "L", "C"))
  w_mid <- count_old(v, bl, 2.5, 0.175, seats = 6L)
  set.seed(20261128); hits <- 0; D <- 1000
  for (i in seq_len(D)) { w <- count_old(v, bl, exp(rnorm(1, log(2.5), 0.4)), runif(1, 0.05, 0.30), seats = 6L)
    hits <- hits + identical(sort(rep(g$letter, w)), sort(act[[yr]]$order)) }
  okm <- identical(sort(rep(g$letter, w_mid)), sort(act[[yr]]$order))
  cat(sprintf("OLD %s current count() at aff 2.5, ex 0.175: seats %s | %s | over %d draws of (aff, ex): actual seats in %.0f%%\n",
              yr, paste(sort(rep(g$letter, w_mid)), collapse = ""), if (okm) "MATCH" else "MISS", D, 100 * hits / D))
}

# ---- a deliberately broken flow set ---------------------------------------------------------------------------
# Seats by party cannot fail on these two counts (four of six seats are whole quotas), so the sharper test is
# step by step: follow the REAL count's path (V0's order of elections and exclusions) with each ballot model and
# measure, after every step, how far the groups' tallies are from the real ballots' tallies.
#   err = sum over groups |model - real| / 2, in quotas (the share of a quota sitting with the wrong group),
#   exh = |model exhausted - real exhausted|, in quotas.
# Mean over all steps and at the final step. Lower is better.
br <- fits[["2022"]]; br$seq <- copy(br$seq)     # copy: := would shuffle fits[["2022"]] by reference too
set.seed(7); cl <- unique(br$seq$first); perm <- setNames(sample(cl), cl)
br$seq[, first := perm[first]]
replay_old <- function(v, bloc, aff, ex, acts) {          # count_old() following a given path, tally after each step
  out <- matrix(NA_real_, length(acts), length(v)); exh <- numeric(length(acts)); e <- 0; alive <- v > 0
  for (k in seq_along(acts)) { a <- acts[k]
    if (a > 0) v[a] <- max(0, v[a] - 1) else { lo <- -a; alive[lo] <- FALSE; rest <- which(alive)
      wt <- sqrt(pmax(v[rest], 1e-6)) * ifelse(bloc[rest] == bloc[lo] & bloc[lo] != "C", aff, ifelse(bloc[rest] == "C" | bloc[lo] == "C", 1, 1 / aff))
      v[rest] <- v[rest] + (1 - ex) * v[lo] * wt / sum(wt); e <- e + ex * v[lo]; v[lo] <- 0 }
    out[k, ] <- v; exh[k] <- e }
  list(t = out, e = exh)
}
cat("\nUHC3  Following the real count's path step by step. err = quotas sitting with the wrong group (sum |model - real| / 2), exh = exhausted error in quotas; lower is better.\n")
for (yr in names(YEARS)) {
  g <- dat[[yr]]$g; pt <- uh_ballot_patterns(dat[[yr]]$s, g$letter)
  r0 <- uh_stv(pt$votes, pt, 6L, g$candidates, trace = TRUE); acts <- uh_replay_of(r0)
  real <- uh_stv(pt$votes, pt, 6L, g$candidates, trace = TRUE, replay = acts)
  q <- real$quota; keep <- real$steps$what != "surplus passed on"
  RT <- real$tallies[keep, , drop = FALSE] / q; RE <- real$steps$exhausted[keep] / q
  score <- function(T, E) { d <- rowSums(abs(T - RT)) / 2; x <- abs(E - RE)
    sprintf("err mean %.3f final %.3f | exh mean %.3f final %.3f", mean(d), d[length(d)], mean(x), x[length(x)]) }
  arms <- list()
  for (src in names(YEARS)) if (src <= yr) arms[[paste(src, "flows")]] <- fits[[src]]
  if (yr == "2022") arms[["2022 flows, classes SHUFFLED"]] <- br
  for (nm in names(arms)) {
    r <- uh_stv(pt$votes, uh_region_patterns(g$name, uh_compact_flows(arms[[nm]]), min_to = 6L, top = 150L, tail = 150L),
                6L, g$candidates, trace = TRUE, replay = acts)
    k2 <- r$steps$what != "surplus passed on"
    cat(sprintf("   %s, %-30s %s\n", yr, nm, score(r$tallies[k2, , drop = FALSE] / q, r$steps$exhausted[k2] / q)))
  }
  v <- pt$votes / q; bl <- ifelse(grepl(RIGHT, g$name), "R", ifelse(grepl(LEFT, g$name), "L", "C"))
  o <- replay_old(v, bl, 2.5, 0.175, acts)
  cat(sprintf("   %s, %-30s %s\n", yr, "current count() aff 2.5 ex 0.175", score(o$t, o$e)))
  if (yr == "2022") rb <- uh_stv(pt$votes, uh_region_patterns(g$name, uh_compact_flows(br), min_to = 6L, top = 150L, tail = 150L),
                                 6L, g$candidates, trace = TRUE)
}
cat(sprintf("\nBROKEN  2022 with first classes shuffled, free count: %s | %s\n", show(rb, dat[["2022"]]$g),
            if (identical(show(rb, dat[["2022"]]$g), paste(act[["2022"]]$order, collapse = " "))) "still elects the actual seats (seats by party cannot tell; see UHC3)" else "MISS"))
# ---- other upper houses (reported, not a pass condition): NSW LC 2023 (21 seats), SA LC 2026 (11 seats) --------
# Statewide first preferences by group from the sibling branch other-upper-houses (output/other-upper-house-fp.csv);
# flows are Victorian Senate ballots from the last federal election before each (2022 for NSW, 2025 for SA), mapped
# by class. Both ask for at least a 1 above the line, so Senate ballots that stopped at 6 stop at 1 (min_to = 1); the
# rest keep their length. min_to = 6 is shown too. Actual results (Wikipedia "Results of the 2023 New South Wales state
# election (Legislative Council)" and "... 2026 South Australian state election (Legislative Council)", read
# 26 Nov 2026): NSW Labor 8, Coalition 7, Greens 2, One Nation 1, Legalise Cannabis 1, Liberal Democrats 1, Shooters 1;
# SA Labor 5, One Nation 3, Liberal 2, Greens 1.
OUH <- Sys.getenv("AUSPOL_OTHER_UH_FP", "C:/dev/auspol-wt-ouh/output/other-upper-house-fp.csv")
OTHER <- list(nsw2023 = list(seats = 21L, flows = "2022", actual = c(ALP = 8L, LNP = 7L, GRN = 2L, ONP = 1L, LCA = 1L, LIBT = 1L, SFF = 1L)),
              sa2026  = list(seats = 11L, flows = "2025", actual = c(ALP = 5L, ONP = 3L, LNP = 2L, GRN = 1L)))
if (file.exists(OUH)) {
  ouh <- fread(OUH)
  for (el in names(OTHER)) {
    cfg <- OTHER[[el]]; el_ <- el
    o <- ouh[ouh$election == el_ & ouh$house == "upper" & ouh$geo_level == "state", list(votes = sum(votes)), by = "party_raw"][order(-votes)]
    cl <- uh_party_class(o$party_raw); actual <- cfg$actual
    cat(sprintf("\nUHC4  %s LC: %d groups, %.0f formal votes (%d seats). Actual: %s\n", el, nrow(o), sum(o$votes), cfg$seats,
                paste(names(actual), actual, collapse = ", ")))
    agg <- function(w) { x <- tapply(w, cl, sum); x <- x[x > 0]; paste(names(sort(-x)), sort(x, decreasing = TRUE), collapse = ", ") }
    for (mt in c(1L, 6L)) for (sd in 1:2) {
      pat <- uh_region_patterns(o$party_raw, uh_compact_flows(fits[[cfg$flows]]), min_to = mt, top = 150L, tail = 150L, seed = sd)
      r <- uh_stv(o$votes, pat, cfg$seats, trace = TRUE)
      x <- tapply(r$won, cl, sum); x <- x[x > 0]
      hit <- setequal(names(x), names(actual)) && all(x[names(actual)] == actual)
      oo <- order(-r$tally); oo <- oo[r$tally[oo] > 0][1:2]
      cat(sprintf("   model, %s flows, ballots stop at %d, seed %d: %s | %s | largest two left %s\n", cfg$flows, mt, sd, agg(r$won),
                  if (hit) "MATCH" else "MISS", paste(sprintf("%s %.3f", cl[oo], r$tally[oo] / r$quota), collapse = " vs ")))
    }
    bl <- ifelse(grepl(RIGHT, o$party_raw, ignore.case = TRUE), "R", ifelse(grepl(LEFT, o$party_raw, ignore.case = TRUE), "L", "C"))
    w <- count_old(setNames(o$votes / (sum(o$votes) / (cfg$seats + 1)), o$party_raw), bl, 2.5, 0.175, seats = cfg$seats)
    cat(sprintf("   current count() aff 2.5 ex 0.175: %s\n", agg(w)))
  }
} else cat("\nUHC4  no other-upper-house first preferences at ", OUH, ": NSW and SA checks skipped\n")

cat(sprintf("\nUHC9  passes: %d of %d (V0 %d/2)\n", sum(unlist(res)), length(res), sum(unlist(res[grep("^V0", names(res))]))))
