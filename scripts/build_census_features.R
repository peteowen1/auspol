# Demographics as model features. Asked for in August, still NOT DONE, and the
# request came with "if you leave any vars out let me know dont just silently do
# it" -- which is exactly what happened.
#
# WHY NOW. One Nation in South Australia is the single biggest contributor to our
# gap against AE Forecasts: RMSE 8.55 against their 5.58, and sa2026 alone is
# +0.186 of seat log loss behind. The reason is visible in the seats:
#
#   seat        ONP actual   character
#   Narungga        37.5     rural, Yorke Peninsula
#   MacKillop       35.3     rural, south-east
#   Chaffey         33.9     Riverland
#   Elizabeth       33.3     outer-suburban, working class
#   Bragg            9.1     affluent inner-eastern Adelaide
#   Unley            9.4     affluent inner-south
#
# That is a class and urbanity split, and the model has NO feature for either.
# Partisan lean does not capture it -- the Coalition polls well in affluent Bragg
# AND rural MacKillop (r = +0.133 with the One Nation vote), while the Greens'
# prior vote separates them at -0.786. We were using a party's vote as a proxy
# for demography; this measures it directly.
#
# The same feature should serve the other half of the gap. Our worst Greens
# misses in fed2022 were Ryan, Brisbane and Griffith -- all inner-Brisbane.
#
# WHAT IS ON DISK, and it needed no fetching. The reaggregated census files
# already carry `final_name`, the SEAT NAME, so the join everyone assumed was
# missing has been available all along:
#
#   census-sed-2016-reaggregated-to-{2021,2022,2024,2025}.csv   state divisions
#   census-ced-2021.csv / census-ced-2016.csv                   federal divisions
#
# FEATURES, chosen to be about the PEOPLE rather than the politics:
#   yr12_pct        share of adults whose highest schooling is Year 12
#   born_aus_pct    share born in Australia
#   indig_pct       share identifying as Aboriginal or Torres Strait Islander
#   over55_pct      share aged 55+
#   under35_pct     share aged 15-34
#   median_mortgage monthly repayment, the closest thing to an income proxy here
#
# NO LEAKAGE: the census predates every election it is attached to, and these are
# properties of a place, not of a result.
#
# Emits CF* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"; CEN <- "external/reference/census"

# Column sums computed OUTSIDE the data.table brackets on a plain matrix.
# `get(x)` inside lapply() does not resolve against data.table's scope -- the
# first version failed with "object 'High_yr_schl_comp_Yr_12_eq_P' not found"
# even though the `all(... %in% names(d))` guard immediately above had passed.
# Same family as the NSE traps in CLAUDE.md: work on plain vectors, not symbols.
.sum_cols <- function(d, cols) {
  if (!all(cols %in% names(d))) return(rep(NA_real_, nrow(d)))
  rowSums(as.matrix(d[, cols, with = FALSE]), na.rm = TRUE)
}
derive <- function(d) {
  d <- data.table::copy(d)
  sch <- c("High_yr_schl_comp_Yr_12_eq_P", "High_yr_schl_comp_Yr_11_eq_P",
           "High_yr_schl_comp_Yr_10_eq_P", "High_yr_schl_comp_Yr_9_eq_P",
           "High_yr_schl_comp_Yr_8_belw_P")
  tot <- if ("Tot_P_P" %in% names(d)) as.numeric(d$Tot_P_P) else rep(NA_real_, nrow(d))
  d[, yr12_pct := 100 * .sum_cols(d, sch[1]) / .sum_cols(d, sch)]
  d[, born_aus_pct := 100 * .sum_cols(d, "Birthplace_Australia_P") / tot]
  d[, indig_pct := 100 * .sum_cols(d, "Indigenous_P_Tot_P") / tot]
  d[, over55_pct := 100 * .sum_cols(d, c("Age_55_64_yr_P", "Age_65_74_yr_P",
                                         "Age_75_84_yr_P")) / tot]
  d[, under35_pct := 100 * .sum_cols(d, c("Age_15_19_yr_P", "Age_20_24_yr_P",
                                          "Age_25_34_yr_P")) / tot]
  # The two file families spell this one differently for the same quantity:
  # SED says Lang_spoken_home_*, CED says Lang_used_home_*. Taking whichever is
  # present rather than hardcoding one, which would give a 100% empty column on
  # half the corpus.
  lang <- intersect(c("Lang_spoken_home_Oth_Lang_P", "Lang_used_home_Oth_Lang_P"),
                    names(d))
  d[, lang_other_pct := if (length(lang)) 100 * .sum_cols(d, lang[1]) / tot else NA_real_]
  d[, edu_25plus_pct := 100 * .sum_cols(d, "Age_psns_att_edu_inst_25_ov_P") / tot]
  d
}
# NO INCOME FEATURE, and that is a deliberate refusal rather than an oversight.
#
# The federal CED files carry six income and housing medians -- personal, family
# and household weekly income, mortgage, rent, household size. The state SED
# reaggregations carry NONE of them: they are ABS table G01 only, 110 columns of
# age, birthplace, ancestry, language and schooling.
#
# So an income feature would be populated for the 7 federal pairs and empty for
# the 15 state pairs -- which is EXACTLY the shape that sank the state-deviation
# block tonight. A column that is real in one jurisdiction and filler in another
# stops being a measurement and becomes a jurisdiction label, and xgboost splits
# on it as one. v7i (pooled) scored 3.9297 against v7c's 3.8740, and v7j
# (jurisdiction-split) was worse on BOTH halves.
#
# It also would not serve the case this file exists for. sa2026 One Nation is a
# STATE election, so income would be absent for exactly the seats it was meant
# to separate. Year 12 completion does the job there at r = -0.922 anyway.
#
# TO REVISIT: reaggregating ABS table G02 (the medians) to state boundaries
# needs the 2016 SA1 medians plus the same correspondence weights the G01
# reaggregation already used. That is a data-build task, not a modelling one,
# and it would make income available everywhere rather than half the corpus.
FEATS <- c("yr12_pct", "born_aus_pct", "indig_pct", "over55_pct",
           "under35_pct", "lang_other_pct", "edu_25plus_pct")

# Which census vintage serves which election. The reaggregations are BUILT for a
# boundary year, so each is used where its boundaries apply; a pair with no
# reaggregation of its own takes the nearest earlier one and that is stated
# rather than silently substituted.
VINTAGE <- c(wa2021 = "2021", vic2022 = "2022", sa2022 = "2022", sa2026 = "2025",
             nsw2023 = "2022", qld2024 = "2024", wa2025 = "2025",
             vic2018 = "2021", vic2014 = "2021", nsw2019 = "2021",
             qld2020 = "2021", wa2017 = "2021", wa2013 = "2021",
             wa2008 = "2021", wa2005 = "2021", wa2001 = "2021")
EXACT <- c("wa2021","vic2022","sa2022","nsw2023","qld2024","wa2025","sa2026")

sed_rows <- list()
for (el in names(VINTAGE)) {
  f <- file.path(CEN, sprintf("census-sed-2016-reaggregated-to-%s.csv", VINTAGE[[el]]))
  if (!file.exists(f)) { cat(sprintf("CF0! %s: no census vintage %s\n", el, VINTAGE[[el]])); next }
  d <- derive(fread(f, showProgress = FALSE))
  if (!"final_name" %in% names(d)) { cat(sprintf("CF0! %s: no final_name column\n", el)); next }
  # FILTER TO THE PAIR'S OWN STATE. Each reaggregated file covers all five
  # states (95 NSW, 90 VIC, 95 QLD, 49 SA, 50-58 WA), and seat names repeat
  # across them -- Murray exists in NSW and Victoria, Albert Park in Victoria
  # and South Australia. Joining the whole file to every pair duplicated rows
  # and tripped the row-count assertion below, which is what it is for.
  # The leading digit of final_code is the state: 1 NSW, 2 VIC, 3 QLD, 4 SA, 5 WA.
  PREFIX <- c(nsw = "1", vic = "2", qld = "3", sa = "4", wa = "5")
  reg <- sub("[0-9]{4}$", "", el)
  if (reg %in% names(PREFIX)) {
    keep_rows <- substr(as.character(d$final_code), 1, 1) == PREFIX[[reg]]
    if (!any(keep_rows)) {
      cat(sprintf("CF0! %s: no census rows with state prefix %s -- skipped\n", el, PREFIX[[reg]]))
      next
    }
    d <- d[keep_rows]
  }
  sed_rows[[el]] <- data.table(pair = el, seat = d$final_name,
                               vintage = VINTAGE[[el]],
                               exact = el %in% EXACT)[, (FEATS) := d[, ..FEATS]][]
}
SED <- rbindlist(sed_rows, fill = TRUE)

# Federal divisions from the CED files.
fed_rows <- list()
for (v in c("2021", "2016")) {
  f <- file.path(CEN, sprintf("census-ced-%s.csv", v))
  if (!file.exists(f)) next
  d <- derive(fread(f, showProgress = FALSE))
  nm <- intersect(c("ced_name", "final_name", "seat"), names(d))
  if (!length(nm)) { cat(sprintf("CF0! census-ced-%s.csv has no seat-name column (%s)\n",
                                 v, paste(head(names(d), 3), collapse = ", "))); next }
  fed_rows[[v]] <- data.table(vintage = v, seat = d[[nm[1]]])[, (FEATS) := d[, ..FEATS]][]
}
FEDC <- rbindlist(fed_rows, fill = TRUE)
cat(sprintf("CF1  state divisions: %d rows over %d pairs | federal: %d rows\n",
            nrow(SED), uniqueN(SED$pair), nrow(FEDC)))

FED_PAIRS <- c("fed2007","fed2010","fed2013","fed2016","fed2019","fed2022","fed2025")
if (nrow(FEDC)) {
  fv <- c(fed2007="2016", fed2010="2016", fed2013="2016", fed2016="2016",
          fed2019="2021", fed2022="2021", fed2025="2021")
  fed_rows2 <- lapply(names(fv), function(el) {
    d <- FEDC[FEDC$vintage == fv[[el]]]
    if (!nrow(d)) return(NULL)
    data.table(pair = el, seat = d$seat, vintage = fv[[el]],
               exact = fv[[el]] == "2021")[, (FEATS) := d[, ..FEATS]][]
  })
  SED <- rbindlist(c(list(SED), fed_rows2), fill = TRUE)
}

# Join onto the cells the model actually scores.
F <- fread(file.path(OUT, "xgb-primary-v6-features.csv"), showProgress = FALSE)
cells <- unique(F[, .(pair, seat)])
# VICTORIAN CENSUS NAMES CARRY A REGION SUFFIX. The census calls it
# "Albert Park (Southern Metropolitan)" and we call it "Albert Park", so the
# join matched 2 of 78 vic2022 seats -- 90 Victorian rows were present and
# unusable. Strip a trailing parenthesised region before normalising.
#
# Only Victoria does this (its upper-house regions are part of the official
# division name), but the strip is applied everywhere: a seat whose real name
# ends in brackets does not exist in any jurisdiction here, and a rule that
# fires only on one state is a rule that breaks when another adopts the format.
.strip_region <- function(x) trimws(sub("\\s*\\([^)]*\\)\\s*$", "", x))
SED[, sn := normalise_seat(.strip_region(seat))]
cells[, sn := normalise_seat(seat)]
# Whatever survives the strip must still be one row per (pair, seat), or the
# merge below multiplies cells. Print what collided rather than quietly taking
# the first -- a silent narrowing here would corrupt every feature downstream.
dup <- SED[, .N, by = .(pair, sn)][N > 1]
if (nrow(dup)) {
  cat(sprintf("CF1! %d duplicate (pair, seat) keys after the region strip -- keeping the first of each:\n", nrow(dup)))
  print(head(dup[order(-N)], 20))
  SED <- SED[!duplicated(SED[, .(pair, sn)])]
}
J <- merge(cells, SED[, c("pair", "sn", "vintage", "exact", ..FEATS)],
           by = c("pair", "sn"), all.x = TRUE)
stopifnot(nrow(J) == nrow(cells))
cat(sprintf("\nCF2  %d seat-pairs | %d matched a census row (%.0f%%)\n",
            nrow(J), sum(!is.na(J$yr12_pct)), 100 * mean(!is.na(J$yr12_pct))))
# COVERAGE PER FEATURE, NOT JUST PER ROW. median_mortgage shipped in the first
# version of this file as a column that was present, correctly typed, and 100%
# NA -- the reaggregated state files simply do not contain it, and .sum_cols()'s
# missing-column fallback turned "this does not exist" into "this is unknown"
# without saying so. Every check above it passed. CLAUDE.md's rule is to assert
# coverage rather than presence after a join; this is that assertion, and it
# fails the build rather than warning, because a 100% empty feature is never
# what anyone intended.
cov <- vapply(FEATS, function(v) mean(is.finite(J[[v]])), numeric(1))
cat("CF2  per-feature coverage (share of matched cells carrying a finite value):\n")
for (v in names(cov)) cat(sprintf("CF2    %-16s %5.1f%%\n", v, 100 * cov[[v]]))
if (any(cov < 0.5)) {
  stop(sprintf("CF2! feature(s) below 50%% coverage: %s -- a column that is present and empty is worse than an absent one",
               paste(names(cov)[cov < 0.5], collapse = ", ")))
}
cat("CF2  coverage by pair -- an unmatched pair contributes nothing and must be visible:\n")
print(J[, .(seats = .N, matched = sum(!is.na(yr12_pct)),
            pct = sprintf("%.0f%%", 100 * mean(!is.na(yr12_pct))),
            vintage = paste(unique(stats::na.omit(vintage)), collapse = "/")),
        by = pair][order(pct)])

cat("\nCF3  DOES IT SEPARATE THE CASE IT WAS BUILT FOR? sa2026 One Nation.\n")
E <- fread(file.path(OUT, "primary-errors-by-class.csv"), showProgress = FALSE)
S <- merge(E[pair == "sa2026" & party == "ONP", .(seat, actual, pred, err)],
           J[pair == "sa2026", c("seat", ..FEATS)], by = "seat")
if (nrow(S) > 10) {
  for (v in FEATS) {
    z <- S[[v]]; ok <- is.finite(z)
    if (sum(ok) > 10) cat(sprintf("CF3   r(%-16s, ONP vote) = %+.3f\n", v, cor(z[ok], S$actual[ok])))
  }
  cat("\nCF3  the seats it must tell apart:\n")
  print(S[seat %in% c("Narungga","MacKillop","Chaffey","Bragg","Unley","Elizabeth"),
          .(seat, onp = round(actual, 1), ours = round(pred, 1),
            yr12 = round(yr12_pct), lang_oth = round(lang_other_pct),
            edu25 = round(edu_25plus_pct, 1),
            over55 = round(over55_pct), born_aus = round(born_aus_pct))][order(-onp)])
}
fwrite(J[, c("pair", "seat", "vintage", "exact", ..FEATS)],
       file.path(OUT, "census-features.csv"))
cat(sprintf("\nCF4  wrote %s/census-features.csv\n", OUT))
