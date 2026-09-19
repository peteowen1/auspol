# vic2022 two-candidate-preferred ground truth from the VEC's OWN 2CP-by-
# voting-centre pages (output/booths-vic2022-2cp.csv, scripts/
# fetch_booths_vic2022.R), replacing the ABC scrape (fsrc = "abc-scrape")
# in output/aef7-final-two-and-tcp-reference.csv. The ABC figures are kept
# in the log as a cross-check: any seat whose pairing or share disagrees is
# printed before the overwrite, because a silent replacement of a truth
# table is exactly the class of change this repo's rules forbid.
#
# f1 is the WINNER's class, f2 the other finalist, f2cp the winner's share
# of the two-candidate count (same convention as build_aef7_tcp_official.R).
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
OUT <- "output"
B <- fread(file.path(OUT, "booths-vic2022-2cp.csv"), showProgress = FALSE)
B <- B[candidate != "Mis-sorts" & !is.na(votes)]
T <- B[, .(v = sum(votes)), by = .(district, candidate, party)]
T[, cls := classify_party(party)]
T[, n := .N, by = district]
stopifnot(all(T$n == 2))
T <- T[order(district, -v)]
V <- T[, .(f1 = cls[1], f2 = cls[2], f2cp = round(100 * v[1] / sum(v), 1),
           winner_name = candidate[1], f1_raw = party[1], f2_raw = party[2]), by = district]
intra <- V[f1 == f2]
if (nrow(intra)) cat(sprintf("VVEC1! intra-class final two (excluded): %s\n", paste(intra$district, collapse = ", ")))
V <- V[f1 != f2]
ref <- fread(file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), na.strings = c("NA", ""), showProgress = FALSE)
cmp <- merge(ref[pair == "vic2022", .(seat, f1_old = f1, f2_old = f2, f2cp_old = f2cp, fsrc_old = fsrc)],
             V[, .(seat = district, f1, f2, f2cp)], by = "seat", all.x = TRUE)
cat(sprintf("VVEC2  vic2022: %d reference seats, %d with a VEC 2CP, %d without (%s)\n",
            nrow(cmp), sum(!is.na(cmp$f1)), sum(is.na(cmp$f1)), paste(cmp[is.na(f1)]$seat, collapse = ", ")))
dis <- cmp[!is.na(f1) & (f1 != f1_old | f2 != f2_old | abs(f2cp - f2cp_old) > 0.5)]
cat(sprintf("VVEC3  disagreements with the previous source (pairing or share > 0.5 pt): %d\n", nrow(dis)))
if (nrow(dis)) print(dis[, .(seat, was = sprintf("%s v %s %.1f (%s)", f1_old, f2_old, f2cp_old, fsrc_old), vec = sprintf("%s v %s %.1f", f1, f2, f2cp))])
# THE VEC PAGE'S PAIR IS ITS INDICATIVE COUNT, NOT THE DISTRIBUTION'S FINAL
# TWO. Hawthorn and Kew 2022 were counted Liberal v independent on the night
# and finished Liberal v Labor after preferences; Mulgrave the reverse. The
# truth table's f1/f2 is the final two, so a VEC row whose pairing differs
# from the existing source is NOT taken: only the share is upgraded where the
# pair agrees (the VEC share is the official count; the ABC's Shepparton
# 56.8 against the VEC's 52.7 is the kind of scrape error this replaces).
keep_old <- cmp[!is.na(f1) & (f1 != f1_old | f2 != f2_old)]
if (nrow(keep_old)) cat(sprintf("VVEC3! pairing differs from the final two, previous source KEPT: %s\n",
                                paste(sprintf("%s (VEC %s v %s; final %s v %s)", keep_old$seat, keep_old$f1, keep_old$f2, keep_old$f1_old, keep_old$f2_old), collapse = "; ")))
upd <- cmp[!is.na(f1) & f1 == f1_old & f2 == f2_old, .(pair = "vic2022", seat, f1, f2, f2cp, fsrc = "vec-official")]
ref[upd, on = c("pair", "seat"), `:=`(f1 = i.f1, f2 = i.f2, f2cp = i.f2cp, fsrc = i.fsrc)]
cat("VVEC4  fsrc breakdown after merge:\n"); print(ref[, .N, by = .(pair, fsrc)][order(pair, fsrc)])
fwrite(ref, file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), na = "NA")
cat("VVEC5  wrote output/aef7-final-two-and-tcp-reference.csv\n")
