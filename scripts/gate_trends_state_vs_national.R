setwd("C:/dev/auspol")
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
source("scripts/trends_fetch.R")
ANCHOR <- "Anthony Albanese"

cap1 <- function(w) gsub("(^|[- '])([a-z])", "\\1\\U\\2", tolower(w), perl = TRUE)
searchname <- function(full) {
  p <- strsplit(trimws(full), " +")[[1]]
  if (length(p) < 2) return(cap1(full))
  paste(cap1(p[1]), cap1(p[length(p)]))
}

st <- unique(fread("external/reference/aec/fed2022-firstprefs.csv",
                   showProgress = FALSE)[, .(seat = DivisionNm, StateAb)])
m <- fread("output/ind-candidacies.csv", showProgress = FALSE)[name != sitting][year == 2022]
m[, sname := vapply(name, searchname, character(1))]
m <- merge(m, st, by = "seat")
set.seed(7)
pick <- rbind(m[breakout == TRUE], m[breakout == FALSE][sample(.N, min(12, .N))])
pick <- unique(pick, by = "sname")
cat(sprintf("G6 sample: %d candidates, %d breakouts, states: %s\n",
            nrow(pick), sum(pick$breakout), paste(sort(unique(pick$StateAb)), collapse = ",")))

to <- as.Date("2022-05-20"); from <- to - 70

# National, re-fetched through the guarded path so this run is self-contained.
res_nat <- list()
for (b in split(pick$sname, ceiling(seq_len(nrow(pick)) / 4))) {
  a <- trends_batch(b, geo = "AU", from = from, to = to, anchor = ANCHOR)
  if (!is.null(a)) for (n in b) if (n %in% names(a))
    res_nat[[length(res_nat) + 1L]] <- data.table(sname = n, rel_nat = a[[n]])
}
N <- rbindlist(res_nat)
trends_require_complete(pick$sname, N$sname, "G6 national")

# State-level.
res_st <- list()
for (s in sort(unique(pick$StateAb))) {
  sub <- pick[StateAb == s]
  geo <- paste0("AU-", s)
  for (b in split(sub$sname, ceiling(seq_len(nrow(sub)) / 4))) {
    a <- trends_batch(b, geo = geo, from = from, to = to, anchor = ANCHOR)
    if (!is.null(a)) for (n in b) if (n %in% names(a))
      res_st[[length(res_st) + 1L]] <- data.table(sname = n, state = s, rel_state = a[[n]])
  }
}
S <- rbindlist(res_st)
trends_require_complete(pick$sname, S$sname, "G6 state-level")

trends_report()

R <- merge(merge(S, N, by = "sname"), unique(pick[, .(sname, seat, pct, breakout)]), by = "sname")
setorder(R, -rel_state)
cat("\nG6 full comparison, all", nrow(R), "candidates present\n")
print(R[, .(sname, seat, state, nat = round(rel_nat, 4), state_lvl = round(rel_state, 4),
            pct = round(pct, 1), breakout)], nrows = 40)

auc <- function(col) {
  a <- R[breakout == TRUE][[col]]; b <- R[breakout == FALSE][[col]]
  mean(outer(a, b, ">") + 0.5 * outer(a, b, "=="))
}
cat(sprintf("\nG6 AUC national %.3f | AUC state-level %.3f | AUC max(nat,state) %.3f\n",
            auc("rel_nat"), auc("rel_state"),
            { R[, rel_max := pmax(rel_nat, rel_state)]; auc("rel_max") }))

cat("\nG6 the three previously-missing regional cases\n")
print(R[sname %in% c("Nicolette Boele", "Rob Priestly", "Caz Heise"),
        .(sname, seat, state, nat = round(rel_nat, 4), state_lvl = round(rel_state, 4))])

fwrite(R, "output/ind-salience-state.csv")
cat("\nG6 wrote output/ind-salience-state.csv\n")
