suppressMessages(library(data.table))
P <- "external/elections"
fs <- c("aec-fed-transfers.csv", "ecq-qld-transfers.csv", "ecsa-2026-sa-transfers.csv", "nswec-nsw-transfers.csv",
        "vec-2010-vic-transfers.csv", "vec-2014-vic-transfers.csv", "vec-2018-vic-transfers.csv",
        "vec-2022-vic-transfers.csv", "waec-wa-transfers.csv")
tx <- rbindlist(lapply(fs, function(f) fread(file.path(P, f))[, src := f]), fill = TRUE)
cat(sprintf("rows %d | elections %d | classes in from: %s\n", nrow(tx), uniqueN(tx$election),
            paste(sort(unique(tx$from)), collapse = " ")))
# one exclusion = election, seat, round, from; survivors = the to set
ex <- tx[, .(surv = paste(sort(unique(to)), collapse = "+"), tot = sum(votes),
             alp = sum(votes[to == "ALP"]), onp = sum(votes[to == "ONP"]), lnp = sum(votes[to == "LNP"])),
         by = .(election, seat, round, frm = from)]
# head-to-head: of the votes going to the two, what share picked the second. Any contest where both survive.
h2h <- function(f, a, b) {
  x <- ex[frm == f & grepl(paste0("(^|[+])", a, "([+]|$)"), surv) & grepl(paste0("(^|[+])", b, "([+]|$)"), surv)]
  x[, `:=`(va = get(tolower(a)), vb = get(tolower(b)))]
  x <- x[va + vb > 0]
  r <- x[, .(seats = uniqueN(seat), exclusions = .N, votes_to_two = sum(va + vb),
             pct_to_b = round(100 * sum(vb) / sum(va + vb), 1),
             only_two = sum(surv == paste(sort(c(a, b)), collapse = "+")),
             pct_only_two = round(100 * sum(vb[surv == paste(sort(c(a, b)), collapse = "+")]) /
                                    sum(tot[surv == paste(sort(c(a, b)), collapse = "+")]), 1)),
         by = election][order(election)]
  r
}
cat("\n=== LIBERAL/LNP excluded, Labor and One Nation both alive: % of the two-way share going to ONE NATION ===\n")
print(h2h("LNP", "ALP", "ONP"), nrows = 100)
cat("\n=== ONE NATION excluded, Labor and Liberal both alive: % of the two-way share going to LIBERAL ===\n")
print(h2h("ONP", "ALP", "LNP"), nrows = 100)
