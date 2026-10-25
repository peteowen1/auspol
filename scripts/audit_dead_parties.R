# Which scored elections have a party that stood last time and does not stand (or stands in far fewer seats)
# this time, and what the level model gave its class. docs/plans/prereg-level-dead-party-2026-10-25.md, part 1.
#
# Run (repo root):  powershell.exe -Command 'Rscript "scripts/audit_dead_parties.R"'
#   --min=2      previous statewide share (points) a party must have held to be listed in the summary table
#   --all        also print every non-zero dead share, any size (the name-matching audit)
#
# Standing at the target = the target's candidacies with votes > 0 or pcv > 0 (the harnesses' nomination proxy;
# nominations close ~2-3 weeks before polling day, so this is knowable in advance). Party matching across
# elections is by name (R/level_dead_party.R, dead_party_same()); single-party classes are judged as a class.
# Level = output/level-pred.csv (the level model, before the recent-poll blend) except thin cycles (level-pred
# from_polls = 0, the previous result there), whose level is recomputed with thin_cycle_statewide() exactly as
# forecast_statewide_or_oracle() calls it, then adjusted as the arm adjusts it ("arm": dead_party_level() on the
# carried part, dead_class_keep() for a class standing nowhere). Prints DPA codes.
# Data.table NSE: masks are built outside [...].
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); options(width = 250)
args <- commandArgs(TRUE)
getarg <- function(nm, dflt) { a <- grep(paste0("^--", nm, "="), args, value = TRUE); if (length(a)) sub(paste0("^--", nm, "="), "", a[1]) else dflt }
MIN <- as.numeric(getarg("min", "2"))

C <- fread(out_path("candidacies.csv"), showProgress = FALSE)
LP <- fread(out_path("level-pred.csv"), showProgress = FALSE)
pairs <- vapply(all_election_pairs(), function(p) p$election, "")
pp_f <- out_path("published-predictions.csv")
if (file.exists(pp_f)) pairs <- intersect(pairs, unique(fread(pp_f, select = "pair", showProgress = FALSE)$pair))
cat(sprintf("DPA0 corpus %d candidacies / %d elections; %d scored elections; level-pred %d rows / %d pairs\n",
            nrow(C), uniqueN(C$election), length(pairs), nrow(LP), uniqueN(LP$pair)))
el_c <- C$election
share <- function(e) { m <- el_c == e & is.finite(C$votes); x <- C[m, list(v = sum(votes)), by = "party"]; setNames(100 * x$v / sum(x$v), x$party) }
cand_f <- out_path("minor-class-shares-v2.csv")
CM <- if (file.exists(cand_f)) fread(cand_f, showProgress = FALSE) else data.table(election = character(0), cls = character(0))
eds <- election_dates()

rows <- list(); allrows <- list(); targets <- list()
for (e in pairs) {
  D <- dead_party_table(e, corpus = C)
  if (inherits(D, "dp_none")) { cat(sprintf("DPA0! %s: %s\n", e, attr(D, "reason"))); next }
  reg <- sub("[0-9]{4}$", "", e); yr <- as.integer(sub("^[a-z]+", "", e))
  sa <- share(attr(D, "prior")); sb <- share(e)
  lpe <- LP[LP$pair == e]
  lvl <- setNames(lpe$level_pred, lpe$party); thin <- nrow(lpe) && all(lpe$from_polls == 0)
  arm <- lvl
  if (thin) {
    ff <- out_path(sprintf("nomzero-flows-%s.rds", e)); fl <- if (file.exists(ff)) readRDS(ff)$flows else NULL
    pt <- union(names(sa), names(sb))
    invisible(capture.output({
      th0 <- thin_cycle_statewide(reg, yr, as.Date(unname(eds[e])), pt, sa)
      th1 <- dead_party_level(th0, e, carried = 1 - attr(th0, "w_polls"), flows = fl, corpus = C, mode = "flow")
    }))
    lvl <- th0; arm <- dead_class_keep(th1, intersect(names(th1), names(sb)), flows = fl, mode = "flow")
  }
  cm_cls <- CM$cls[CM$election == e]
  for (i in which(!is.na(D$successor)))
    cat(sprintf("DPA4 %s: %s (%s, %.2f%% in %d seats) stands as \"%s\" (same candidates), %d seats\n", e, D$party[i], D$cls[i],
                D$prev_share[i], D$prev_seats[i], D$successor[i], D$tgt_seats[i]))
  for (i in seq_len(nrow(D))) {
    if (!(D$dead_share[i] > 0)) next
    cl <- D$cls[i]
    how <- if (thin) "thin cycle: previous result carried"
           else if (cl %in% c("ALP", "LNP", "GRN")) "polled"
           else if (cl %in% cm_cls) "bucket: candidate-model split"
           else "bucket/class: previous-result split"
    r <- data.table(election = e, prior = attr(D, "prior"), cls = cl, party = D$party[i], successor = D$successor[i], prev_share = D$prev_share[i],
                    seats = sprintf("%d->%d", D$prev_seats[i], D$tgt_seats[i]), dead = D$dead_share[i],
                    level = if (cl %in% names(lvl)) unname(lvl[cl]) else NA_real_,
                    arm = if (cl %in% names(arm)) unname(arm[cl]) else 0,
                    actual = if (cl %in% names(sb)) unname(sb[cl]) else 0, how = how)
    allrows[[length(allrows) + 1L]] <- r
    if (D$prev_share[i] >= MIN && D$contest[i] < 0.5) rows[[length(rows) + 1L]] <- r
  }
  # TARGET RULE (prereg): the arm can move this election's level when (a) the level is a thin cycle and some
  # previous party's share is dead, (b) a class with level > 0 stands nowhere, or (c) a class outside ALP/LNP/GRN
  # with a dead share is split by the previous result (no candidate-model row). From nominations only.
  why <- character(0)
  if (thin && any(D$dead_share > 0)) why <- c(why, "a")
  gone <- setdiff(names(lvl)[is.finite(lvl) & lvl > 0], names(sb)[sb > 0])
  if (length(gone)) why <- c(why, paste0("b:", paste(gone, collapse = "/")))
  cc <- unique(D$cls[D$dead_share > 0 & !D$cls %in% c("ALP", "LNP", "GRN") & !D$cls %in% cm_cls & D$cls %in% names(sb)])
  if (!thin && length(cc)) why <- c(why, paste0("c:", paste(cc, collapse = "/")))
  if (length(why)) targets[[e]] <- paste(why, collapse = " ")
}
cat(sprintf("\nDPA5 target elections by rule (%d): %s\n", length(targets),
            paste(sprintf("%s [%s]", names(targets), unlist(targets)), collapse = "; ")))
A <- rbindlist(rows); ALL <- rbindlist(allrows)
cat(sprintf("\nDPA1 parties >= %.1f%% at the previous election standing in under half their previous share of seats (%d rows, %d elections).\n",
            MIN, nrow(A), uniqueN(A$election)))
cat("     prev_share/dead/level/arm/actual are statewide points; level = what the level model gave the CLASS (thin: thin-cycle level\n",
    "     before the class is dropped); arm = AUSPOL_LEVEL_DEAD_PARTY=flow (thin cycles only; elsewhere '=' level); actual = class share.\n")
A[, `:=`(prev_share = round(prev_share, 1), dead = round(dead, 1), level = round(level, 1), arm = round(arm, 1), actual = round(actual, 1))]
print(A, nrows = 200, row.names = FALSE)
if ("--all" %in% args) {
  cat("\nDPA2 every non-zero dead share (name-matching audit):\n")
  ALL[, `:=`(prev_share = round(prev_share, 2), dead = round(dead, 2))]
  print(ALL[order(-dead), list(election, cls, party, successor, prev_share, seats, dead)], nrows = 500, row.names = FALSE)
}
# vic2026 against the provisional list (the live forecast does nothing until AUSPOL_NOM_LIVE=1 opens the final list)
pv <- C[el_c == "vic2026"]
if (nrow(pv)) {
  Dv <- dead_party_table("vic2026", corpus = C, standing = pv)
  cat(sprintf("\nDPA3 vic2026 against the PROVISIONAL list (%d candidacies; the live forecast ignores it until AUSPOL_NOM_LIVE=1). Parties >= 0.5%% at vic2022:\n", nrow(pv)))
  Dv[, `:=`(prev_share = round(prev_share, 2), dead = round(dead_share, 2), contest = round(contest, 2))]
  print(Dv[prev_share >= 0.5, list(cls, party, prev_share, seats = sprintf("%d->%d", prev_seats, tgt_seats), contest, dead)][order(-dead)], row.names = FALSE)
}
