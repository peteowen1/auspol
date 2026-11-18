# build_ind_split_inputs.R -- per-candidate inputs for the points-based independent split
# (AUSPOL_CLASS_SPLIT_MODE = "pts_cred" / "pts_carry", R/class_split.R; plan docs/plans/prereg-ind-split-points-2026-11-18.md).
#
#   Rscript scripts/build_ind_split_inputs.R
#
# One row per independent in every seat where two or more independents stood, every election in
# output/candidacies.csv including the live one. Every column is something knowable BEFORE that election:
#   cred            "MP" (sitting member, or elected at an earlier election), "councillor" (elected to a council
#                   before this election's year, output/council-history.csv), "prior5" (an earlier non-major vote of
#                   5%+ anywhere), else "none". Checked in that order.
#   prior_nonmajor  best earlier vote as anything but Labor or Coalition (the carried vote's base)
#   prior_same_seat TRUE when that best earlier vote was in this seat
# plus the outcome columns the fit uses for EARLIER elections only: share (this candidate's vote) and our_cls (our
# published-path forecast of the whole independent vote, output/published-predictions.csv `ours`).
# Writes output/ind-split-candidates.csv. Check codes ISI1 (counts), ISI2! (a guard failed).
suppressMessages(library(data.table))
C <- fread("output/candidacies.csv", encoding = "UTF-8",
           select = c("election", "year", "seat", "name", "party", "pcv", "elected", "historic_elected"))
cat(sprintf("ISI1 candidacies: %d rows, %d elections, years %d-%d\n", nrow(C), uniqueN(C$election),
            min(C$year, na.rm = TRUE), max(C$year, na.rm = TRUE)))
C[, key := toupper(gsub("\\s+", " ", trimws(name)))]
I <- C[party == "IND"]
I[, n_ind := .N, by = .(election, seat)]
I <- I[n_ind >= 2]
# earlier records of each person: any result before this election's year
H <- C[is.finite(pcv), .(key, h_year = year, h_seat = seat, h_pcv = pcv, h_party = party, h_el = elected %in% TRUE)]
MAJ <- c("ALP", "LNP")
rec <- H[I[, .(election, seat, key, year)], on = .(key), allow.cartesian = TRUE, nomatch = NULL][h_year < year]
nm <- rec[!h_party %in% MAJ, .SD[which.max(h_pcv)], by = .(election, seat, key)][
  , .(election, seat, key, prior_nonmajor = h_pcv, prior_same_seat = h_seat == seat)]
mp <- rec[, .(prior_mp = any(h_el)), by = .(election, seat, key)]
I <- merge(I, nm, by = c("election", "seat", "key"), all.x = TRUE)
I <- merge(I, mp, by = c("election", "seat", "key"), all.x = TRUE)
CH <- fread("output/council-history.csv", encoding = "UTF-8")[
  , .(election, seat, key = toupper(gsub("\\s+", " ", trimws(name))), council_elected, council_year)]
CH <- CH[council_elected %in% TRUE, .(council = TRUE, council_year = min(council_year, na.rm = TRUE)), by = .(election, seat, key)]
I <- merge(I, CH, by = c("election", "seat", "key"), all.x = TRUE)
I[, council_ok := council %in% TRUE & is.finite(council_year) & council_year < year]
I[, cred := fcase(historic_elected %in% TRUE | prior_mp %in% TRUE, "MP",
                  council_ok, "councillor",
                  is.finite(prior_nonmajor) & prior_nonmajor >= 5, "prior5",
                  default = "none")]
P <- fread("output/published-predictions.csv")[party == "IND", .(election = pair, seat, our_cls = ours)]
I <- merge(I, P, by = c("election", "seat"), all.x = TRUE)
out <- I[, .(election, year, seat, name, cls = "IND", share = pcv, cred, prior_nonmajor, prior_same_seat, n_ind, our_cls)]
setorder(out, election, seat, -share)
bad <- out[, .N, by = .(election, seat, name)][N > 1]
if (nrow(bad)) stop(sprintf("ISI2! %d duplicate (election, seat, name) rows, e.g. %s", nrow(bad), paste(head(bad$name, 3), collapse = ", ")))
if (!"vic2026" %in% out$election) stop("ISI2! no vic2026 rows: the live forecast would get no split")
cat(sprintf("ISI1 %d independents in %d seat-elections (%d elections); cred: %s\n", nrow(out),
            uniqueN(out[, paste(election, seat)]), uniqueN(out$election),
            paste(names(table(out$cred)), table(out$cred), sep = "=", collapse = " ")))
cat(sprintf("ISI1 our_cls present on %d of %d seat-elections with an outcome; vic2026 seats: %d\n",
            uniqueN(out[is.finite(our_cls) & is.finite(share), paste(election, seat)]),
            uniqueN(out[is.finite(share), paste(election, seat)]), uniqueN(out[election == "vic2026", seat])))
fwrite(out, "output/ind-split-candidates.csv")
cat("ISI1 wrote output/ind-split-candidates.csv\n")

# FROZEN FIT for each live election (no outcome yet), both points modes: what class_split_args() reads where the
# transfers corpus is absent (the daily forecast on GitHub; publish with the other shipped-models inputs).
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
for (el in unique(out[!is.finite(share), election])) {
  fz <- rbindlist(lapply(c("pts_cred", "pts_carry"), function(m) {
    f <- class_split_fit_pts(el, m, cand = out)
    if (!nrow(f$seats)) stop(sprintf("ISI2! %s %s: the fit gave no seats", el, m))
    pc <- function(k) if (k %in% names(f$pts)) unname(f$pts[k]) else NA_real_
    data.table(mode = m, sd_mode = Sys.getenv("AUSPOL_CLASS_SPLIT_SD", "pooled"), f$seats, n_hist = f$n_hist, b = f$b, carry_same = unname(f$carry["same"]),
               carry_other = unname(f$carry["other"]), i_none = pc("none"), i_MP = pc("MP"), i_prior5 = pc("prior5"),
               i_councillor = pc("councillor"))
  }), fill = TRUE)
  if (any(!is.finite(fz$f)) || any(!is.finite(fz$sd))) stop(sprintf("ISI2! %s: frozen fit has a missing f or sd", el))
  fn <- sprintf("output/ind-split-fit-%s.csv", el)
  fwrite(fz, fn)
  cat(sprintf("ISI1 %s: frozen fit, %d seats per mode, b %.3f, sd %.3f, f %.3f -> %s\n", el, nrow(fz) / 2, fz$b[1], fz$sd[1], fz$f[1], fn))
}
