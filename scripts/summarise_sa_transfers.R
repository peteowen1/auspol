# Preference transfer rates from all 47 SA districts, in the model's party classes.
#
# scripts/extract_sa_transfers.py pulls 294 exclusion events from the ECSA API,
# against the 97 that docs/reviews/onp-allocation-sa-2026-08-17.md could get
# from Wikipedia. But raw, those 294 land in 119 distinct (excluded party,
# survivor set) cells -- 66 of them singletons -- which is WORSE per-cell
# coverage than the review's 97-in-28, because the full district set carries
# more varied ballots.
#
# So the events only pay off once the ballot's many minor parties are collapsed
# into the classes the model actually uses. That is done with classify_party(),
# the repo's own mapping, rather than a bespoke one -- CLAUDE.md: one source of
# truth per question.
#
# ANCHOR CHECK. The review reports, from its 16 districts, that of Liberal
# preferences going to one of Labor or One Nation, 62.7% went to One Nation.
# The same quantity is computed here on 47 districts. It should be close. If it
# is not, one of the two extractions is wrong and neither should be used.
#
# Emits TR* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

f <- file.path("external", "reference", "ecsa", "sa2026-transfers.csv")
if (!file.exists(f)) stop("Run scripts/extract_sa_transfers.py first.")
tr <- fread(f, showProgress = FALSE)

# ECSA party ids -> this repo's classes. classify_party() takes a name and an
# abbreviation; the ids here are abbreviations, so the name is passed as the id
# too and the abbreviation carries the match.
ids <- unique(c(tr$excluded_party,
                unlist(strsplit(paste(tr$survivors, collapse = "|"), "|", fixed = TRUE)),
                sub("^to_", "", grep("^to_", names(tr), value = TRUE))))
ids <- sort(unique(ids[nzchar(ids)]))
cls <- setNames(classify_party(ids, ids), ids)
cat("\nTR1  ECSA party ids mapped to model classes\n")
print(data.table(id = names(cls), class = unname(cls))[order(class, id)])

to_cols <- grep("^to_", names(tr), value = TRUE)
long <- melt(tr, id.vars = c("seat", "round", "excluded_party", "survivors", "pile"),
             measure.vars = to_cols, variable.name = "to_id", value.name = "votes")
long[, to_id := sub("^to_", "", as.character(to_id))]
long <- long[votes > 0]
long[, `:=`(from_class = cls[excluded_party], to_class = cls[to_id])]

# The survivor set, also in model classes, so the conditioning has enough
# events per cell to mean something.
surv_class <- function(s) {
  vapply(strsplit(s, "|", fixed = TRUE), function(v)
    paste(sort(unique(cls[v])), collapse = "|"), character(1))
}
long[, surv := surv_class(survivors)]

ev <- long[, .(votes = sum(votes)), by = .(seat, round, from_class, surv, to_class)]
cells <- ev[, .(events = uniqueN(paste(seat, round))), by = .(from_class, surv)]
cat(sprintf("\nTR2  after collapsing to model classes: %d cells from %d events\n",
            nrow(cells), uniqueN(ev[, paste(seat, round)])))
cat(sprintf("TR2  cells with 5+ events: %d | singletons: %d\n",
            sum(cells$events >= 5), sum(cells$events == 1)))

# ---- the anchor check ------------------------------------------------------
# Liberal exclusions, restricted to what went to Labor or One Nation.
lnp <- ev[from_class == "LNP" & to_class %in% c("ALP", "ONP"),
          .(votes = sum(votes)), by = to_class]
share_onp <- 100 * lnp[to_class == "ONP", votes] / sum(lnp$votes)
cat(sprintf("\nTR3  ANCHOR -- of LNP preferences reaching Labor or One Nation, %.1f%% went to ONP\n",
            share_onp))
cat("TR3  the review reports 62.7%% from its 16 districts.\n")
if (abs(share_onp - 62.7) > 8) {
  stop("This extraction gives ", round(share_onp, 1), "% against the review's ",
       "62.7%. The two disagree by more than sampling can explain; one of them ",
       "is wrong and neither should be used.")
}
cat("TR3  consistent.\n")

# ---- the rates worth having ------------------------------------------------
rate <- ev[, .(votes = sum(votes)), by = .(from_class, surv, to_class)]
rate[, pct := 100 * votes / sum(votes), by = .(from_class, surv)]
rate <- merge(rate, cells, by = c("from_class", "surv"))
cat("\nTR4  transfer rates, cells with 5 or more events, ordered by size\n")
big <- rate[events >= 5][order(-events, from_class, surv, -pct)]
print(big[, .(from = from_class, survivors = surv, events, to = to_class,
              pct = round(pct, 1))], nrows = 40)

cat("\nTR5  what the model assumes, against what these say\n")
cat("TR5  the model applies ONE flow-to-Labor per party regardless of who else\n")
cat("TR5  is standing. Below is that quantity per survivor set, so the spread\n")
cat("TR5  is visible rather than averaged away.\n")
alp <- rate[to_class == "ALP" & events >= 3][order(from_class, -events)]
print(alp[, .(from = from_class, survivors = surv, events,
              to_ALP_pct = round(pct, 1))], nrows = 40)
fwrite(rate, file.path("output", "sa2026-transfer-rates.csv"))
cat(sprintf("\nTR6  wrote output/sa2026-transfer-rates.csv (%d rows)\n", nrow(rate)))
