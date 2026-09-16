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
#
# Partisan lean does not capture it. The Coalition's own share barely separates
# these seats -- r = -0.286 with the One Nation vote across the 47 seats,
# because the Coalition polls respectably in affluent Bragg AND rural MacKillop
# -- while the Greens' prior vote separates them at -0.786. We were using a
# party's vote as a proxy for demography; this measures it directly.
#
# (An earlier version of this comment put the Coalition figure at +0.133, which
# was wrong: measured, LNP is -0.286 and it is IND that sits at +0.145. Caught
# by the review gate. The argument is unchanged -- a weak correlation and a
# wrong-signed one both fail to separate the seats -- but the number was not
# something to leave sitting in a header for a later session to reason from.)
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
  # Tot_P_P is the denominator for FIVE of the seven features, so losing it
  # quietly would NA out most of a file's contribution with nothing on screen.
  # Every other missing-column path here prints a CF0!/CF1! line; this one did
  # not, which made it the least-defended fallback in the script. Review gate.
  if (!"Tot_P_P" %in% names(d)) {
    cat("CF0! Tot_P_P absent -- born_aus, indig, over55, under35 and edu_25plus will be NA for this file\n")
    tot <- rep(NA_real_, nrow(d))
  } else {
    tot <- as.numeric(d$Tot_P_P)
  }
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
             wa2008 = "2021", wa2005 = "2021", wa2001 = "2021",
             # THE LIVE TARGET, added 2026-09-15. Victoria's boundaries have not
             # moved since the 2021 redistribution, so the reaggregation built
             # for 2022 applies exactly: all 88 vic2026 divisions appear in
             # census-sed-2016-reaggregated-to-2022.csv, and the only name that
             # differs between the two elections is Narracan, whose 2022 poll
             # was deferred rather than redistributed away.
             vic2026 = "2022")
EXACT <- c("wa2021","vic2022","sa2022","nsw2023","qld2024","wa2025","sa2026",
           "vic2026")

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
    # The !is.na() is DEFENSIVE, not a fix for a live bug, and the difference
    # matters enough to record. A review flagged that an NA final_code would
    # make the comparison NA and inject a phantom all-NA row. That is true of a
    # base R data.frame and NOT of a data.table, which drops NA from a logical
    # `i` -- tested both ways, and `d` is a data.table from fread(). The real
    # files also carry 0 NA codes in 379 rows. Kept anyway so the filter states
    # its intent and still holds if `d` ever becomes a data.frame.
    keep_rows <- !is.na(d$final_code) &
                 substr(as.character(d$final_code), 1, 1) == PREFIX[[reg]]
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

# JOIN ONTO THE SEATS BEING CONTESTED, not the seats that existed last time.
#
# This read `unique(F[, .(pair, seat)])` from xgb-primary-v6-features.csv until
# 2026-09-15. That file is keyed on the PREVIOUS election's seats, so a division
# created at a redistribution had no feature row, therefore no census row -- and
# education_residual_apply() skips an entire election rather than part-applying
# it, because correcting some seats and not others moves the statewide total.
# Four of the seven AEF pairs were disabled that way:
#
#   nsw2023   5 of 93   Badgerys Creek, Kellyville, Leppington, Wahroonga, Winston Hills
#   wa2025    9 of 59   WA redistributes hard; names do not survive between elections
#   fed2022   2 of 152  includes Hawke, created 2021
#   fed2025   3 of 152  same cause
#
# Every one of those seats was ALREADY in the reaggregated census files -- 5 of
# 5 NSW and 10 of 10 Victorian, in the 2022, 2024 and 2025 vintages. Nothing was
# missing from disk; the join was asking the wrong question. Third instance of
# the pattern CLAUDE.md records under "Before saying we don't have data".
#
# vic2026 had no rows AT ALL, which is the one that matters: it is the election
# being forecast. See the RESULT section of
# docs/plans/prereg-education-residual-correction-2026-09-15.md.
#
# candidacies.csv is the contested-seat list for every election we hold, vic2026
# included. Pairs with no census vintage are filtered out here rather than
# joined to nothing -- an all-NA pair is the constant-within-subgroup block the
# CF2 check below exists to stop. The v6 cells are UNIONED IN rather than
# replaced, so no downstream consumer loses a row it had before.
CAND <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
# Mask computed OUTSIDE the brackets and the columns pulled with `$`: `election`
# and `seat` are both column names here, and CLAUDE.md records eight bugs from a
# bare column-name symbol inside `[`.
keep_cand <- CAND$election %in% unique(SED$pair)
cand_cells <- unique(data.table(pair = CAND$election[keep_cand],
                                seat = CAND$seat[keep_cand]))

# AND THE PREVIOUS ELECTION'S DIVISIONS, filed under the CURRENT pair.
#
# A pair needs both seat sets, because the pipeline handles both. The forecast
# is made for the seats being contested; the matrix it is built from is keyed on
# the seats of the election it projects forward (`shares <- mat`,
# backtest_candidate_nsw.R:424). A redistribution breaks those two apart in both
# directions at once -- nsw2023 gains Badgerys Creek, Kellyville, Leppington,
# Wahroonga and Winston Hills, and loses Baulkham Hills, Ku-ring-gai, Lakemba,
# Mulgoa and Seven Hills -- and a census table covering only one side disables
# the election for anything that needs every seat.
#
# The predecessor is DERIVED, not hand-listed: the most recent election of the
# same region strictly before this one. A hand-maintained map here would be one
# more thing to forget when a pair is added, and CLAUDE.md records that the six
# harnesses' copied pair lists have already drifted apart once.
.el     <- unique(CAND$election)
.el_reg <- sub("[0-9]{4}$", "", .el)
.el_yr  <- suppressWarnings(as.integer(sub("^[a-z]+", "", .el)))
prev_of <- vapply(unique(SED$pair), function(p) {
  r <- sub("[0-9]{4}$", "", p)
  y <- suppressWarnings(as.integer(sub("^[a-z]+", "", p)))
  ok <- .el_reg == r & is.finite(.el_yr) & .el_yr < y
  if (!any(ok)) return(NA_character_)
  .el[ok][which.max(.el_yr[ok])]
}, character(1))
prev_cells <- rbindlist(lapply(names(prev_of), function(p) {
  pe <- prev_of[[p]]
  if (is.na(pe)) return(NULL)
  m <- CAND$election == pe
  if (!any(m)) return(NULL)
  data.table(pair = p, seat = CAND$seat[m])
}))
if (nrow(prev_cells)) cand_cells <- unique(rbindlist(list(cand_cells, prev_cells)))
cat(sprintf("CF1a predecessor election resolved for %d of %d pairs\n",
            sum(!is.na(prev_of)), length(prev_of)))
F <- fread(file.path(OUT, "xgb-primary-v6-features.csv"), showProgress = FALSE)
v6_cells <- unique(F[, .(pair, seat)])
cells <- unique(rbindlist(list(cand_cells, v6_cells)))
# PRINT WHAT THE UNION ADDED, per pair. A silent widening is indistinguishable
# from no widening, and this whole fix exists because a gap was invisible.
added <- merge(cells[, .N, by = pair], v6_cells[, .(was = .N), by = pair],
               by = "pair", all.x = TRUE)
added[is.na(was), was := 0L][, gained := N - was]
cat(sprintf("CF1b seat universe: %d cells (was %d from the v6 features file alone)\n",
            nrow(cells), nrow(v6_cells)))
if (nrow(added[gained > 0])) {
  cat("CF1b pairs that gained seats -- each one was a silently disabled election:\n")
  print(added[gained > 0][order(-gained)])
}
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
# THE UNION CAN CARRY TWO SPELLINGS OF ONE SEAT. candidacies.csv and the v6
# feature file are built by different scripts, so a division they name
# differently ("Kurri Kurri" against "Kurri-Kurri") survives the union as two
# rows that normalise to the same key -- both would then match the same census
# row and the file would ship a duplicate. Report and drop, never silently keep
# the first: which spelling wins decides whether a harness finds its seat.
cdup <- cells[, .N, by = .(pair, sn)][N > 1]
if (nrow(cdup)) {
  cat(sprintf("CF1c! %d (pair, seat) keys reached by two different spellings:\n", nrow(cdup)))
  print(merge(cells, cdup[, .(pair, sn)], by = c("pair", "sn"))[order(pair, sn)])
  cells <- cells[!duplicated(cells[, .(pair, sn)])]
}
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

# FALL BACK TO ANOTHER BOUNDARY VINTAGE FOR SEATS THE PAIR'S OWN VINTAGE LACKS.
#
# The harnesses project each seat's PREVIOUS primaries forward, so the matrix
# they hand to education_residual_apply() is keyed on the PREVIOUS election's
# divisions -- `shares <- mat` at backtest_candidate_nsw.R:424. A division
# ABOLISHED at a redistribution therefore still needs a census row, and the
# pair's own vintage is by construction built on the boundaries that abolished
# it. Widening the seat universe to the contested seats (above) does not help
# with that: it fixes the opposite end of the same redistribution.
#
# nsw2023 is the worked case. Baulkham Hills, Ku-ring-gai, Lakemba, Mulgoa and
# Seven Hills disappeared in the 2021 NSW redistribution; the 2022
# reaggregation has none of them and the 2021 reaggregation has all five.
# Without this, education_residual_apply() skips the entire election, which is
# what silently disabled four of the seven AEF pairs.
#
# NEAREST other vintage wins, earlier preferred on a tie, and the row is marked
# exact = FALSE so a consumer can tell a boundary-matched row from a borrowed
# one. Borrowing is a real approximation -- the demographics are measured on
# boundaries that differ from the ones in use -- and it is better than dropping
# the election, but only because it is visible in the data.
pool_rows <- list()
for (.v in unique(VINTAGE)) {
  .f <- file.path(CEN, sprintf("census-sed-2016-reaggregated-to-%s.csv", .v))
  if (!file.exists(.f)) next
  .d <- derive(fread(.f, showProgress = FALSE))
  if (!"final_name" %in% names(.d)) next
  .reg <- c("1" = "nsw", "2" = "vic", "3" = "qld", "4" = "sa", "5" = "wa")[
    substr(as.character(.d$final_code), 1, 1)]
  pool_rows[[.v]] <- data.table(
    region = unname(.reg), vintage = .v,
    sn = normalise_seat(.strip_region(.d$final_name)))[, (FEATS) := .d[, ..FEATS]][]
}
if (nrow(FEDC)) {
  pool_rows[["fed"]] <- data.table(
    region = "fed", vintage = FEDC$vintage,
    sn = normalise_seat(.strip_region(FEDC$seat)))[, (FEATS) := FEDC[, ..FEATS]][]
}
POOL <- rbindlist(pool_rows, fill = TRUE)
POOL <- unique(POOL[!is.na(region) & !is.na(sn)], by = c("region", "sn", "vintage"))

need <- which(!is.finite(J$yr12_pct))
if (length(need) && nrow(POOL)) {
  nd <- data.table(ri = need,
                   region = sub("[0-9]{4}$", "", J$pair[need]),
                   sn = J$sn[need],
                   yr = suppressWarnings(as.integer(sub("^[a-z]+", "", J$pair[need]))))
  cand <- merge(nd, POOL, by = c("region", "sn"), allow.cartesian = TRUE)
  if (nrow(cand)) {
    cand[, vy := suppressWarnings(as.integer(vintage))]
    cand[, gap := abs(vy - yr)]
    setorder(cand, ri, gap, vy)
    pick <- cand[!duplicated(cand$ri)]
    for (.v in FEATS) set(J, pick$ri, .v, pick[[.v]])
    set(J, pick$ri, "vintage", pick$vintage)
    set(J, pick$ri, "exact", FALSE)
    cat(sprintf("\nCF2b %d of %d unmatched cells filled from another boundary vintage:\n",
                nrow(pick), length(need)))
    print(data.table(pair = J$pair[pick$ri], vintage = pick$vintage)[, .N,
          by = .(pair, vintage)][order(-N)])
  }
}
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
#
# TESTS FOR ZERO, NOT A PERCENTAGE. The first version stopped below 50%, and
# that was a made-up number doing no work: the failure it exists to catch is a
# column that is ENTIRELY empty, and a feature legitimately varies in coverage
# with how many seats matched. Same correction as the per-pair check below.
cov <- vapply(FEATS, function(v) mean(is.finite(J[[v]])), numeric(1))
cat("CF2  per-feature coverage (share of matched cells carrying a finite value):\n")
for (v in names(cov)) cat(sprintf("CF2    %-16s %5.1f%%\n", v, 100 * cov[[v]]))
empty_feats <- names(cov)[cov == 0]
if (length(empty_feats)) {
  stop(sprintf("CF2! feature(s) at ZERO coverage: %s -- present, correctly typed and entirely empty, which is worse than an absent column because every other check passes. This is what median_mortgage did.",
               paste(empty_feats, collapse = ", ")))
}
# PER PAIR, not just per feature -- and this is the more dangerous direction.
#
# The check above pools across all 2,097 cells, so one vintage file failing to
# load takes its whole election to zero while the global average stays healthy
# and the build passes. That is not ordinary missingness: it is a CONSTANT-
# WITHIN-SUBGROUP block of NAs covering every seat of one election, exactly the
# shape CLAUDE.md records a tree learning as a label for that subgroup -- the
# mechanism that cost the state-deviation block 0.056 RMSE.
#
# NO THRESHOLD, and that is Pete's correction (2026-09-12): the first version
# stopped below 25% coverage, and he pushed back on the hard floor.
#
# He is right, and the reason is worth keeping. 25% was invented, and it is not
# what distinguishes the good case from the bad one. WA sits at 54-81% because
# its seat names genuinely do not survive redistributions, and a pair at 40%
# would be fine for the same reason -- partial matching is NORMAL here. The
# failure is categorical, not a point on a continuum: did this election
# contribute ANYTHING, or did its census file fail to load, fail to carry
# final_name, or fail the state filter and get skipped?
#
# Zero versus non-zero is a real boundary in the data. 25% was a guess about
# where a real boundary might be. So the check tests the actual event, and the
# continuous coverage stays a printed diagnostic -- visible for a human to judge
# without being a cliff that fails a build on the wrong side of a made-up number.
by_pair <- J[, .(cov = mean(is.finite(yr12_pct)), matched = sum(is.finite(yr12_pct))), by = pair]
if (any(by_pair$matched == 0)) {
  print(by_pair[matched == 0])
  stop("CF2! pair(s) matched ZERO census rows -- that election's cells become an ",
       "all-NA block a tree can key on as a jurisdiction label. Check the CF0! ",
       "lines above for a skipped vintage file, a missing final_name column, or ",
       "a state-prefix filter that removed everything.")
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
