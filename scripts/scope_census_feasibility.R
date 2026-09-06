options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# DESCRIPTIVE SCOPING ONLY. No model is fitted and no improvement is claimed.
# The question is whether seat-level Census demographics carry any association
# with vote at all -- if they do not, Path A is not worth pre-registering.
cen <- fread("external/reference/census/census-sed-2021.csv", showProgress = FALSE)
cat("census columns available (first 25):\n")
print(head(names(cen), 25))
cat(sprintf("\nrows %d | Victorian %d\n", nrow(cen), cen[ste == "Victoria", .N]))

vic <- cen[ste == "Victoria"]
# Median age / income / rent style variables live in G02
g2 <- grep("Median|Average", names(vic), value = TRUE)
cat("\nG02-style summary variables:\n"); print(g2)

# 2022 Victorian result, the outcome
PREF <- election_data_path()
fp <- fread(file.path(PREF, "vec-2022-vic-firstprefs.csv"), showProgress = FALSE)
fp[, tot := sum(votes), by = seat]; fp[, p := 100 * votes / tot]
w <- dcast(fp, seat ~ party, value.var = "p", fill = 0)

m <- merge(w, vic, by = "seat")
cat(sprintf("\njoined seats: %d of %d Victorian seats with a 2022 result\n",
            nrow(m), nrow(w)))

if (nrow(m) >= 40 && length(g2)) {
  cat("\n=== DESCRIPTIVE: correlation of each party's 2022 vote with demographics ===\n")
  cat("(scoping only -- association, not prediction, and not out of sample)\n\n")
  for (v in intersect(g2, names(m))) {
    x <- suppressWarnings(as.numeric(m[[v]]))
    if (sum(is.finite(x)) < 40 || stats::sd(x, na.rm = TRUE) == 0) next
    cs <- sapply(c("ALP", "LNP", "GRN", "OTH_RIGHT"), function(p) {
      if (!p %in% names(m)) return(NA_real_)
      suppressWarnings(cor(x, m[[p]], use = "complete.obs"))
    })
    cat(sprintf("  %-32s ALP %+5.2f  LNP %+5.2f  GRN %+5.2f  OTH_RIGHT %+5.2f\n",
                substr(v, 1, 32), cs[1], cs[2], cs[3], cs[4]))
  }
}
