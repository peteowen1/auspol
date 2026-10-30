# Proves scripts/fetch_vec_candidates.R on a list whose answer is known: the VEC's 2022 Candidates set-up file
# against candidacies.csv's vic2022 rows (built from the declared results). Run after the fetcher has written
# vec-candidates-2022.csv:
#   Rscript scripts/check_vec_candidates_vic2022.R [--vec=<path to vec-candidates-2022.csv>]
# Every candidate in either list is accounted for: matched (same district + surname + first initial), with the
# party class from classify_party() compared; or listed as in one list only, with the reason where it is known.
devtools::load_all(".", quiet = TRUE)
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
vf <- sub("^--vec=", "", a[startsWith(a, "--vec=")]); if (!length(vf)) vf <- "external/reference/vec/2022/vec-candidates-2022.csv"
V <- fread(vf, showProgress = FALSE)
C <- fread("output/candidacies.csv", showProgress = FALSE)[election == "vic2022"]
cat(sprintf("VCC0 VEC 2022 list %d rows, %d districts | candidacies.csv vic2022 %d rows, %d seats\n",
            nrow(V), uniqueN(V$district), nrow(C), uniqueN(C$seat)))
V[, cls := classify_party(ifelse(independent == "yes", "Independent", registered_name))]
# "SURNAME, Given" on both sides: surname before the comma, first letter of the given name, letters only
key <- function(seat, name) {
  sur <- gsub("[^a-z]", "", tolower(sub(",.*$", "", name)))
  giv <- substr(gsub("[^a-z]", "", tolower(sub("^[^,]*,", "", name))), 1, 1)
  paste(normalise_seat(seat), sur, giv)
}
V[, .k := key(district, name)]; C[, .k := key(seat, name)]
if (anyDuplicated(V$.k) || anyDuplicated(C$.k)) cat("VCC1! duplicate keys: VEC", sum(duplicated(V$.k)), "corpus", sum(duplicated(C$.k)), "\n")
m <- merge(V[, .(.k, district, vname = name, vcls = cls, vpos = ballot_position, reg = registered_name)],
           C[, .(.k, seat, cname = name, ccls = party, cpos = ballot_position)], by = ".k", all = TRUE)
both <- m[!is.na(vname) & !is.na(cname)]
cat(sprintf("VCC2 matched %d | VEC only %d | corpus only %d\n", nrow(both), m[is.na(cname), .N], m[is.na(vname), .N]))
cat(sprintf("VCC3 party class agrees on %d of %d matched (%.1f%%)\n", sum(both$vcls == both$ccls), nrow(both), 100 * mean(both$vcls == both$ccls)))
if (both[vcls != ccls, .N]) { cat("VCC3 disagreements (VEC registered name -> class, corpus class):\n"); print(both[vcls != ccls, .(district, vname, reg, vcls, ccls)], nrow = 50) }
if ("cpos" %in% names(both) && any(!is.na(both$cpos))) cat(sprintf("VCC4 ballot position agrees on %d of %d with a corpus position\n", both[!is.na(cpos) & vpos == cpos, .N], both[!is.na(cpos), .N]))
cat("\nVCC5 in the VEC list only:\n"); print(m[is.na(cname), .(district, vname, reg)], nrow = 40)
cat("\nVCC5 in the corpus only:\n"); print(m[is.na(vname), .(seat, cname, ccls)], nrow = 40)
cat("\nVCC6 class counts, VEC vs corpus:\n")
print(merge(V[, .(vec = .N), by = .(class = cls)], C[, .(corpus = .N), by = .(class = party)], by = "class", all = TRUE))
