# Primary-vote model v7: fix the salience scale, add candidate-level features.
# Pete, 2026-09-12: "replace for one model and add both for another see how
# xgboost does?"
#
# THREE ARMS, same folds, same params, same everything else:
#   v6   what ships today -- raw `jump`
#   v7a  raw `jump` REPLACED by `jump_pctile`
#   v7b  v7a PLUS candidate-level features
#
# WHY v7a. Each Google Trends batch anchors on a different first query, so raw
# `jump` is on a different scale in every election: fed2022's whole range tops
# out at 0.16 while qld2020 reaches 20.06, a 125x difference. xgboost learns
# THRESHOLDS, so a split like "jump > 2" learned from qld2020 is unreachable by
# any fed2022 row, and Allegra Spender's genuinely 98th-percentile salience
# lands in the model's "no salience" bucket and contributes -0.015 points.
# Forcing her jump to the corpus max moves her prediction 11.5 -> 20.3, so the
# signal is there and worth ~9 points; the VALUES are what cannot reach it.
#
# R/salience_surge.R:54 already says this in as many words -- "raw jump is not
# comparable across elections" -- and the surge model has used `jump_pctile`
# all along. It was simply never applied to the primary model.
#
# WHY v7b. The model shrinks a departing independent's vote by a flat retention
# of 0.44 (99 cells where an IND class polled >=15 and the MP did not return:
# 25.6 -> 11.3). That average is two populations mashed together: seats where
# nobody serious replaced the retiring member and the vote collapses, and seats
# where someone like Spender took over and it grew. 33 x 0.44 = 14.5, which is
# where her 14.4 comes from.
#
# Candidate features alone CANNOT separate those two -- both look like "all
# candidates are first-timers". It is the INTERACTION with salience that does:
#   all-new field + high salience percentile  -> a Spender
#   all-new field + no salience               -> a collapse
# which is exactly why this arm needs both and why v7b should beat v7a.
#
# Emits X7* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
FE <- fread(file.path(OUT, "xgb-primary-v6-features.csv"), showProgress = FALSE)
base_feat <- setdiff(names(FE), c("pair", "seat", "party", "actual_share"))
cat(sprintf("X71  v6 feature matrix: %d rows, %d features\n", nrow(FE), length(base_feat)))

PAIRS <- list(
  list(election="fed2007",prev="fed2004",region="fed"), list(election="fed2010",prev="fed2007",region="fed"),
  list(election="fed2013",prev="fed2010",region="fed"), list(election="fed2016",prev="fed2013",region="fed"),
  list(election="fed2019",prev="fed2016",region="fed"), list(election="fed2022",prev="fed2019",region="fed"),
  list(election="fed2025",prev="fed2022",region="fed"), list(election="nsw2019",prev="nsw2015",region="nsw"),
  list(election="nsw2023",prev="nsw2019",region="nsw"), list(election="qld2020",prev="qld2017",region="qld"),
  list(election="qld2024",prev="qld2020",region="qld"), list(election="sa2026", prev="sa2022", region="sa"),
  list(election="vic2014",prev="vic2010",region="vic"), list(election="vic2018",prev="vic2014",region="vic"),
  list(election="vic2022",prev="vic2018",region="vic"), list(election="wa2001", prev="wa1996", region="wa"),
  list(election="wa2005", prev="wa2001", region="wa"),  list(election="wa2008", prev="wa2005", region="wa"),
  list(election="wa2013", prev="wa2008", region="wa"),  list(election="wa2017", prev="wa2013", region="wa"),
  list(election="wa2021", prev="wa2017", region="wa"),  list(election="wa2025", prev="wa2021", region="wa")
)
# No seat-level salience corpus exists for WA. Kept as its own list rather than
# silently extending to WA with data that is not there.
SAL_PAIRS <- Filter(function(p) p$region != "wa", PAIRS)

# ---- jump_pctile, computed the way the surge model computes it -------------
# rank within the GOVERNED population of each election, matching
# salience_surge.R:92 exactly. Not a rank over all cells: the denominator has
# to be the same population the surge model uses, or the two models disagree
# about what "the 98th percentile" means.
# RANKED AMONG NON-ZERO ONLY. This is a correction to how salience_surge.R:92
# does it, not a copy of it.
#
# Between 51% and 81% of every governed field has `jump` EXACTLY zero -- 447 of
# fed2007's 552 candidates, with only 62 distinct values across the whole field.
# Ranking over all of them puts that tied block at percentile 0.55 and hands
# ANY non-zero value a percentile above 0.8 automatically. Tony Kane (Page 2007)
# scored 0.9846 on a raw jump of 0.0220, which is noise; Norm Ramsay (Cowan
# 2007) has the identical raw value and the identical percentile. Both polled
# under 3%.
#
# That is why salience and outcome correlate at -0.096 INSIDE the top bin: it
# mixes real campaigns with candidates whose only distinction is a non-zero
# reading. Ranking within the non-zero set makes the percentile mean "among
# candidates with any search signal, how strong", and a zero stays a zero.
sal_rows <- list()
for (pr in SAL_PAIRS) {
  s <- tryCatch(governed_population(pr$election, pr$prev, pr$region), error = function(e) NULL)
  if (is.null(s) || !nrow(s)) { cat(sprintf("X71! %s: no governed population\n", pr$election)); next }
  s <- data.table::copy(s)
  nz <- which(is.finite(s$jump) & s$jump > 0)
  s[, jump_pctile := 0]
  if (length(nz) >= 10) {
    set(s, nz, "jump_pctile", rank(s$jump[nz], ties.method = "average") / length(nz))
  } else {
    cat(sprintf("X71! %s: only %d non-zero jumps -- percentile left at 0 for the pair\n",
                pr$election, length(nz)))
  }
  cat(sprintf("X71  %s: %d governed, %d non-zero (%.0f%%)\n",
              pr$election, nrow(s), length(nz), 100 * length(nz) / nrow(s)))
  sal_rows[[pr$election]] <- s[, .(pair = pr$election, seat, party, jump_pctile)]
}
SALP <- rbindlist(sal_rows, fill = TRUE)
# governed_population() is one row per NAMED CANDIDATE; FE is one row per
# (pair, seat, party). Collapse BEFORE merging, with a row-count assertion --
# an uncontrolled merge here silently multiplies rows.
SALP <- SALP[, .(jump_pctile = max(jump_pctile, na.rm = TRUE)), by = .(pair, seat, party)]
n0 <- nrow(FE)
FE <- merge(FE, SALP, by = c("pair", "seat", "party"), all.x = TRUE)
stopifnot(nrow(FE) == n0)
# A cell with no governed candidate is making NO salience claim, so it sits at
# the bottom of the scale. 0, not NA: NA would let xgboost split on
# missingness and learn "WA has no salience data" as if it were a fact about WA.
FE[, jump_pctile := ifelse(is.finite(jump_pctile), jump_pctile, 0)]
cat(sprintf("X71  jump_pctile: %d of %d cells have a governed claim (%.0f%%)\n",
            sum(FE$jump_pctile > 0), nrow(FE), 100 * mean(FE$jump_pctile > 0)))

# ---- candidate-level features ---------------------------------------------
# Aggregated to (pair, seat, party) from the candidate corpus, using the same
# person-key the emergence work uses: surname plus given initial, because
# commissions are inconsistent about middle names between elections.
C <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
C[, cls := party]        # already our own classify_party() output -- see
                         # build_emergence_cases_v2.R for why re-deriving it
                         # here breaks vic2022.
C[, sn := normalise_seat(seat)]
C[, pk := match_key(surname_of(surname, name), given_of(given, name), "initial")]
PREV <- setNames(vapply(PAIRS, function(p) p$prev, ""), vapply(PAIRS, function(p) p$election, ""))

cand_rows <- list()
for (el in names(PREV)) {
  now <- C[C$election == el & nzchar(pk)]
  prv <- C[C$election == PREV[[el]] & nzchar(pk)]
  if (!nrow(now) || !nrow(prv)) { cat(sprintf("X72! %s: no candidate rows\n", el)); next }
  idx <- match(paste(now$sn, now$pk), paste(prv$sn, prv$pk))
  now[, own_prev := ifelse(is.na(idx), 0, prv$pcv[idx])]
  now[, stood_before := as.integer(!is.na(idx))]
  # `by` cannot mix a length-1 constant with columns, so the pair label is
  # attached after the grouping rather than inside it.
  g <- now[, .(
    # What the strongest RETURNING person of this class polled here last time.
    # Zero when nobody in the field has stood here before.
    cand_best_own_prev = max(own_prev, na.rm = TRUE),
    # Is the whole field new? This is the flag that, crossed with salience,
    # tells a Spender apart from a collapse.
    cand_all_new = as.integer(all(stood_before == 0)),
    cand_n_returning = sum(stood_before),
    cand_n = .N
  ), by = .(seat, party = cls)]
  g[, pair := el]
  cand_rows[[el]] <- g
}
CF <- rbindlist(cand_rows, fill = TRUE)
n0 <- nrow(FE)
FE <- merge(FE, CF, by = c("pair", "seat", "party"), all.x = TRUE)
stopifnot(nrow(FE) == n0)
# A cell with no candidate row is a class not standing here: no returning
# person, no field.
FE[is.na(cand_n), `:=`(cand_best_own_prev = 0, cand_all_new = 1L,
                       cand_n_returning = 0L, cand_n = 0L)]
cand_feat <- c("cand_best_own_prev", "cand_all_new", "cand_n_returning", "cand_n")
cat(sprintf("X72  candidate features on %d of %d cells (%.0f%%)\n",
            sum(FE$cand_n > 0), nrow(FE), 100 * mean(FE$cand_n > 0)))
cat("X72  the two populations this is meant to separate, IND cells where the class\n")
cat("X72  polled >=15 last time and no-one is returning -- split by salience:\n")
SPL <- FE[party == "IND" & x >= 15 & cand_all_new == 1L]
SPL[, sal_band := ifelse(jump_pctile >= 0.95, "salience >=95th", "salience <95th")]
print(SPL[, .(cells = .N, polled_last_time = round(mean(x), 1),
              polled_this_time = round(mean(actual_share), 1),
              retention = round(mean(actual_share / x), 2)), by = sal_band])

# ---- prior strength as a RATIO, not a difference -------------------------
# The existing features encode a seat's prior strength ADDITIVELY: dev_prev is
# x - level_prev. That does not survive the party's statewide level moving.
#
# sa2026 One Nation is the worked example. level_prev 2.6, level_now 19.9 -- an
# eight-fold rise. The model anchors seats with history to their small absolute
# prior share and lets seats with NO history float to the statewide level, so
# MacKillop's 8.1 points of 2022 vote dragged it DOWN to 16.7 in a year the
# party polled 20% statewide. Measured: seats where ONP stood in 2022 averaged
# 27.4 and were predicted 19.0; seats where they did not averaged 20.3 and were
# predicted 22.0. The prediction correlates with prior vote at -0.706 where the
# truth is +0.562, and the OLD non-xgb model gets the order right (+0.549) --
# so the xgb inverts a correctly-ordered input.
#
# Trees cannot extrapolate beyond their training range, and the corpus has no
# example of One Nation at a 19.9 statewide level.
#
#   x_rel     how many times the party's own statewide share this seat was
#   x_scaled  that ratio applied to THIS election's level -- the prediction you
#             get if the seat pattern is stable and only the level moved
#
# x_scaled is handed over pre-multiplied for the same reason ret_exp was: a tree
# adds, it cannot multiply, so it needs a split on x AND on level AND a separate
# leaf for every combination to express this.
.lvfloor <- 0.5   # level_prev is a statewide share; below half a point the
                  # ratio is noise dividing by noise
FE[, x_rel := ifelse(is.finite(x) & is.finite(level_prev),
                     x / pmax(level_prev, .lvfloor), 0)]
FE[, x_scaled := ifelse(is.finite(level_now), x_rel * level_now, 0)]
cat(sprintf("\nX72b x_rel: median %.2f, p90 %.2f, max %.2f | x_scaled median %.1f\n",
            median(FE$x_rel), quantile(FE$x_rel, 0.9), max(FE$x_rel), median(FE$x_scaled)))
cat("X72b does it order sa2026 ONP correctly? (the case it was built for)\n")
.s <- FE[pair == "sa2026" & party == "ONP"]
if (nrow(.s) > 10) {
  cat(sprintf("X72b   r(x_scaled, actual) = %+.3f | r(x, actual) = %+.3f | r(dev_prev, actual) = %+.3f\n",
              cor(.s$x_scaled, .s$actual_share), cor(.s$x, .s$actual_share),
              cor(.s$dev_prev, .s$actual_share)))
}

# ---- CROSS-CLASS prior shares --------------------------------------------
# Every feature so far is about the cell's OWN class. A One Nation row knows
# what One Nation polled here last time and nothing about anyone else, because
# the model is fitted per (seat, class). That makes an entire axis invisible.
#
# The evidence, measured on South Australia across two elections:
#
#   2022 seat variable   r with ONP 2022   r with ONP 2026
#   GRN                      -0.385            -0.777
#   LNP                      -0.055            -0.243
#
# The Greens' vote is by far the best non-trivial predictor of the One Nation
# vote and holds its sign in both elections; the Coalition's is near-useless.
# That is not a left-right axis -- the Coalition polls well in affluent Bragg
# (ONP 9.1) AND rural MacKillop (ONP 35.3), so it cannot separate them, while
# the Greens poll 12-19 in the first and 0 in the second. It is an
# education/urbanity axis, and the Greens' vote is the proxy we already hold.
#
# Census would measure it directly and is on disk, but carries sed_code with no
# seat name, so it needs scripts/build_census_correspondence.R run first. This
# is the cheap version of the same signal.
#
# NOT a leak: these are all PREVIOUS-election shares, known before polling day.
.wide <- dcast(FE, pair + seat ~ party, value.var = "x")
.cls <- setdiff(names(.wide), c("pair", "seat"))
setnames(.wide, .cls, paste0("oth_prev_", .cls))
n0 <- nrow(FE)
FE <- merge(FE, .wide, by = c("pair", "seat"), all.x = TRUE)
stopifnot(nrow(FE) == n0)
xcls <- paste0("oth_prev_", .cls)
for (j in xcls) set(FE, which(!is.finite(FE[[j]])), j, 0)
cat(sprintf("\nX72c cross-class prior shares: %d columns (%s)\n",
            length(xcls), paste(.cls, collapse = "/")))
.s <- FE[pair == "sa2026" & party == "ONP"]
if (nrow(.s) > 10 && "oth_prev_GRN" %in% names(.s))
  cat(sprintf("X72c sa2026 ONP check: r(oth_prev_GRN, actual) = %+.3f (expect about -0.78)\n",
              cor(.s$oth_prev_GRN, .s$actual_share)))

# The fold unit for every model and every fitted feature below: one election
# pair. Defined here because the engineered features are fitted leave-one-pair-
# out too, and they must use the SAME folds as the models that consume them --
# a feature fitted on a different split would leak the target pair in through
# the feature even though the model itself never saw it.
pairs_all <- sort(unique(FE$pair))

# ---- v7c: a dedicated salience -> primary curve, as ONE input --------------
# Pete, 2026-09-12: "can we build an IND only salience based primary prediction
# xgboost (or GAM?) and use this as an input in the model?"
#
# The motivation is in the band table: independents at the 0.99-0.995 percentile
# average 28.7 points and at 0.995+ average 31.3, EXCLUDING fed2022 entirely.
# A three-line lookup on those bands beats the 39-feature model on all six
# teals, because the big model dilutes a sharp tail signal across everything
# else it is fitting.
#
# ON LEAKAGE, which Pete flagged: this is fitted leave-one-PAIR-out, the same
# clustering unit as every other model here, so fed2022's curve never sees a
# teal. No pre-2022 cutoff is needed and none is used -- a cutoff would also
# throw away nsw2019/nsw2023/fed2025, which carry most of the tail.
#
# A SMOOTH, NOT BANDS. The percentile is uniform by construction, so a linear
# term IN the percentile cannot bend where all the signal is. Fitting on
# log(1 - pctile) puts the tail on a scale where two parameters can track it --
# this is the same transform salience_surge.R:217 uses, and for the same reason.
GOV <- rbindlist(lapply(SAL_PAIRS, function(p) {
  s <- tryCatch(governed_population(p$election, p$prev, p$region), error = function(e) NULL)
  if (is.null(s) || !nrow(s)) return(NULL)
  s <- data.table::copy(s)
  s[, jump_pctile := rank(jump, ties.method = "average") / .N]
  s[, pair := p$election]
  s[, .(pair, seat, party, pcv, jump_pctile)]
}), fill = TRUE)
GI <- GOV[party == "IND" & is.finite(pcv) & is.finite(jump_pctile)]
cat(sprintf("\nX73c salience curve trained on %d governed IND candidates over %d elections\n",
            nrow(GI), uniqueN(GI$pair)))
# ISOTONIC, NOT A LINEAR FIT ON log(1 - pctile).
#
# The linear version was measurably wrong in the tail, which is the only place
# this feature matters. Fitted against the raw band means:
#
#   band          curve said   truth
#   0.98-0.99        16.8      25.8
#   0.99-0.995       19.4      31.1     <- Wentworth sits here
#   0.995-1.0        31.9      32.6
#
# An 11.7-point under-call in Wentworth's band. The cause is least squares
# serving the mass: about 800 of the 844 cells are low-salience independents
# polling ~5, and 13 are in the 0.99-0.995 band, so one linear term is dragged
# flat by the bulk and only escapes it past 0.995.
#
# Isotonic regression is the right shape: monotone (more salience never predicts
# less vote) but otherwise free, so it can be flat across the bottom 80% and
# steep in the tail without one region distorting the other. Same tool, and the
# same reason, as the surge-hazard calibration.
FE[, sal_exp := 0]
for (pr in pairs_all) {
  tr <- GI[GI$pair != pr]
  if (nrow(tr) < 50) next
  o <- order(tr$jump_pctile)
  ir <- isoreg(tr$jump_pctile[o], tr$pcv[o])
  te <- which(FE$pair == pr & FE$party == "IND" & FE$jump_pctile > 0)
  if (!length(te)) next
  # rule = 2 clamps beyond the training range rather than returning NA, so a
  # held-out candidate more salient than anything seen keeps the top fitted
  # value instead of dropping out of the feature entirely.
  set(FE, te, "sal_exp",
      pmax(0, approx(ir$x, ir$yf, xout = FE$jump_pctile[te],
                     rule = 2, ties = "ordered")$y))
}
cat("X73c curve vs truth by band -- these two columns should now track:\n")
.chk <- FE[party == "IND" & jump_pctile > 0]
.chk[, .b := cut(jump_pctile, c(0, .5, .9, .95, .98, .99, .995, 1.01))]
print(.chk[, .(cells = .N, curve_says = round(mean(sal_exp), 1),
               actual = round(mean(actual_share), 1)), by = .b][order(.b)])
cat("X73c what the curve predicts for the teals, fitted WITHOUT fed2022:\n")
print(FE[pair == "fed2022" & party == "IND" & seat %in%
         c("Wentworth","Mackellar","Kooyong","Curtin","North Sydney","Goldstein"),
         .(seat, jump_pctile = round(jump_pctile, 4), sal_exp = round(sal_exp, 1),
           actual = round(actual_share, 1))][order(-actual)])
cat(sprintf("X73c across all IND cells with a salience claim: n=%d, mean curve %.1f, mean actual %.1f\n",
            sum(FE$sal_exp > 0), mean(FE$sal_exp[FE$sal_exp > 0]),
            mean(FE$actual_share[FE$sal_exp > 0])))

# ---- v7d: the RETENTION split, as a feature -------------------------------
# Pete, 2026-09-12, on the 0.25-vs-0.90 table: "can we use this somehow?"
#
# The finding: among IND cells where the class polled >=15 last time and nobody
# is returning, salience below the 95th percentile retains 0.25 of the old vote
# and salience at 95th+ retains 0.90. The 0.44 average the model actually uses
# is those two mashed together.
#
# WHY THIS IS A SEPARATE FEATURE FROM sal_exp. They answer different questions.
# sal_exp says "a candidate this salient polls about 29" and ignores the seat.
# ret_exp says "this SEAT had 33 points of independent vote and a candidate this
# salient keeps about 90% of it". For Wentworth those give ~29 and ~30; for a
# seat with no independent history they diverge completely, and the model gets
# to learn which to trust where.
#
# It is a RATIO, which is the thing a tree cannot express in levels: to encode
# "keep 90% of x" a tree needs a split on x and a split on salience and then a
# separate leaf value for every combination. Handing it the product directly is
# what makes the structure learnable at this sample size.
#
# Fitted leave-one-pair-out on cells with x >= 5, because retention on a base of
# 0.4 points is a meaningless ratio that would dominate the fit.
# NO MIN-X CLIFF. The first version of this fitted only on cells with x >= 5 and
# left every other cell at zero. That threw away Goldstein (x = 1.4) and North
# Sydney (x = 4.4) -- two of the six seats this feature exists for -- and it is
# the hard-threshold anti-pattern CLAUDE.md bans outright: a seat at 5.1 trusted
# completely, one at 4.9 discarded completely.
#
# The real problem is not that small-x cells are unusable, it is that a RATIO on
# a small base is noisy. So weight the regression by x: a cell with 33 points of
# prior vote informs the fit thirty times as much as one with 1, and every cell
# still gets a prediction. That is the same precision-weighting idea as the
# shrinkage rule, applied to a regression instead of a cell mean.
FE[, ret_exp := 0]
RB <- FE[party == "IND" & x >= 1 & is.finite(actual_share)]
RB[, retention := pmin(3, actual_share / x)]   # capped: a 0-to-30 rise on a
                                               # base of 1 is a ratio of 30 and
                                               # would swamp any linear fit
cat(sprintf("\nX73d retention curve trained on %d IND cells with >=1 point of prior vote\n", nrow(RB)))
cat("X73d weighted by x, so a 33-point base counts 33x a 1-point base.\n")
for (pr in pairs_all) {
  tr <- RB[RB$pair != pr]
  if (nrow(tr) < 50) next
  # Two predictors, matching the two things that actually separated the groups:
  # is anybody returning, and how salient is the field.
  fm <- lm(retention ~ cand_all_new + jump_pctile, data = tr, weights = tr$x)
  te <- which(FE$pair == pr & FE$party == "IND" & FE$x >= 1)
  if (!length(te)) next
  rh <- pmax(0, pmin(3, predict(fm, newdata = FE[te])))
  set(FE, te, "ret_exp", FE$x[te] * rh)
}
cat("X73d what the retention feature says for the teals (x * predicted retention):\n")
print(FE[pair == "fed2022" & party == "IND" & seat %in%
         c("Wentworth","Mackellar","Kooyong","Curtin","North Sydney","Goldstein"),
         .(seat, x = round(x, 1), jump_pctile = round(jump_pctile, 3),
           sal_exp = round(sal_exp, 1), ret_exp = round(ret_exp, 1),
           actual = round(actual_share, 1))][order(-actual)])

# ---- five arms -------------------------------------------------------------
ARMS <- list(
  v6  = base_feat,
  v7a = c(setdiff(base_feat, "jump"), "jump_pctile"),
  v7b = c(setdiff(base_feat, "jump"), "jump_pctile", cand_feat),
  v7c = c(setdiff(base_feat, "jump"), "jump_pctile", "sal_exp"),
  v7d = c(setdiff(base_feat, "jump"), "jump_pctile", "sal_exp", "ret_exp", cand_feat),
  # v7f: ret_exp WITHOUT the candidate features. v7d bundled the two, and the
  # candidate features were already known to hurt (v7b lost to v7a), so v7d
  # losing to v7c said nothing about ret_exp on its own. This is the clean test,
  # and it is the one that answers whether the collapse penalty should be
  # CONDITIONAL rather than removed: dev_prev is right for 67 of the 74 cells
  # it fires on, so the fix is to tell the model when it does not apply.
  v7f = c(setdiff(base_feat, "jump"), "jump_pctile", "sal_exp", "ret_exp"),
  # v7g: the winning set PLUS prior strength as a ratio. Targets the sign flip
  # on sa2026 One Nation without touching anything else.
  v7g = c(setdiff(base_feat, "jump"), "jump_pctile", "sal_exp", "x_rel", "x_scaled"),
  # v7h: the winning set PLUS what the OTHER classes polled in this seat last
  # time. One small change, targeting an axis the per-cell fit cannot see.
  v7h = c(setdiff(base_feat, "jump"), "jump_pctile", "sal_exp", xcls)
)
fold_id <- match(FE$pair, pairs_all)   # pairs_all defined above, with the
                                       # engineered features that share its folds
folds <- split(seq_len(nrow(FE)), fold_id)
params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
y <- FE$actual_share

# AUSPOL_V7_ARMS picks which arms to run, comma-separated. Five xgb.cv runs at
# 2000 rounds over 22 folds on 13,352 x 45 held simultaneously exhausted memory
# and the run was killed after two arms, so the default is the two that decide
# the question and the rest are opt-in.
.want <- Sys.getenv("AUSPOL_V7_ARMS", "v6,v7c,v7e")
keep <- trimws(strsplit(.want, ",")[[1]])
# "none" builds the feature matrix and writes it without fitting anything --
# for SHAP work and diagnostics that need the columns but not another 20 minutes
# of cross-validation.
if (identical(.want, "none")) keep <- character(0)
unknown <- setdiff(setdiff(keep, "v7e"), names(ARMS))
if (length(unknown)) stop("AUSPOL_V7_ARMS names no such arm: ", paste(unknown, collapse = ", "))
cat(sprintf("\nX73  running arms: %s\n",
            if (length(keep)) paste(keep, collapse = ", ") else "none (feature build only)"))

# THE FULL FEATURE MATRIX, always. Written before any fitting so a diagnostic
# never has to re-run the arms to get at the columns -- the same reason
# fit_xgb_primary_v6.R persists its own matrix.
FULL <- unique(c(base_feat, "jump_pctile", "sal_exp", "ret_exp", "x_rel", "x_scaled", xcls, cand_feat))
fwrite(FE[, c("pair", "seat", "party", "actual_share", FULL), with = FALSE],
       file.path(OUT, "xgb-primary-v7-features.csv"))
cat(sprintf("X73  wrote %s/xgb-primary-v7-features.csv (%d rows, %d features)\n",
            OUT, nrow(FE), length(FULL)))
if (!length(keep)) { cat("X73  no arms requested -- stopping after the feature build\n"); quit(save = "no") }

res <- list()
for (nm in intersect(names(ARMS), keep)) {
  M <- as.matrix(FE[, ARMS[[nm]], with = FALSE])
  set.seed(42)
  cv <- xgb.cv(params = params, data = xgb.DMatrix(M, label = y, missing = NA),
               nrounds = 2000, folds = folds, early_stopping_rounds = 30,
               prediction = TRUE, verbose = 0)
  p <- cv$cv_predict$pred[, 1]
  FE[[paste0("pred_", nm)]] <- p
  res[[nm]] <- data.table(arm = nm, features = length(ARMS[[nm]]),
                          nrounds = cv$early_stop$best_iteration,
                          rmse = sqrt(mean((p - y)^2)),
                          mae = mean(abs(p - y)))
  cat(sprintf("X73  %s: %d features, %d rounds, out-of-fold RMSE %.4f\n",
              nm, length(ARMS[[nm]]), cv$early_stop$best_iteration, sqrt(mean((p - y)^2))))
  # The cv object holds every fold's booster and a full prediction matrix. Drop
  # it before the next arm allocates its own, or peak memory is the sum of all
  # arms rather than the largest one.
  rm(cv, M, p); invisible(gc(verbose = FALSE))
}

# ---- v7e: TWO models, split by how the vote is generated -------------------
# Pete, 2026-09-12: "maybe we predict IND primary with a different xgboost from
# other parties?"
#
# The mechanism. The objective is squared error in POINTS OF VOTE. Labor and
# Liberal residuals run about 5 points; most independent cells sit near zero. A
# single model minimising POOLED squared error therefore spends its capacity
# where the variance is, and the minor-party cells get whatever tree budget is
# left. The party one-hots let it specialise in principle, but at max_depth 4
# every split spent separating parties is a split not spent on signal.
#
# WHERE THE LINE GOES, and it is not majors-versus-rest. One Nation and the
# Greens contest nearly everywhere under a brand with a statewide poll behind
# it, so their seat share is a poll number distributed down. An independent's
# vote is generated by a person. That is the same split Pete made for emergence
# earlier today, applied to the same question one level up.
# WHERE ONP GOES IS AN OPEN QUESTION, so it is a switch rather than a guess.
# The first run put it in poll_anchored on the reasoning above, and it was the
# ONLY class that got worse: RMSE 2.922 -> 3.014 while every other class
# improved. That is evidence the reasoning was wrong for One Nation, whose vote
# is far more concentrated and candidate-dependent than a national poll number
# distributed down. AUSPOL_V7_ONP: "poll" (original), "cand", or "own".
# DEFAULT IS "poll", which is where Pete said One Nation belongs and where the
# per-class numbers agree. It was briefly moved to "cand" because that lowered
# POOLED RMSE by 0.0045 -- noise on 13,352 cells -- while raising ONP's own RMSE
# from 3.014 to 3.032 and then 3.051. Optimising a noise-level aggregate against
# a real per-class regression is exactly backwards.
.onp <- Sys.getenv("AUSPOL_V7_ONP", "poll")
if (!.onp %in% c("poll", "cand", "own")) stop("AUSPOL_V7_ONP must be poll, cand or own")
POLL_ANCHORED <- c("ALP", "LNP", "NAT", "GRN", if (identical(.onp, "poll")) "ONP")
FE[, grp := ifelse(party %in% POLL_ANCHORED, "poll_anchored", "candidate_driven")]
# "own" gives One Nation its own model -- 1,506 cells, thin but not absurd, and
# it is the only way to find out whether it is sui generis rather than a bad fit
# for either group.
if (identical(.onp, "own")) FE[party == "ONP", grp := "onp_only"]
cat(sprintf("X73e ONP placement: %s\n", .onp))
cat(sprintf("\nX73e split: %d poll-anchored cells (%s), %d candidate-driven (%s)\n",
            sum(FE$grp == "poll_anchored"), paste(POLL_ANCHORED, collapse = "/"),
            sum(FE$grp == "candidate_driven"), "IND/OTH/OTH_RIGHT"))
best <- ARMS[[Sys.getenv("AUSPOL_V7_SPLIT_BASE", "v7c")]]   # the winning single-model feature set, so the ONLY thing
                   # changing here is one model versus two
# AUSPOL_V7_IND_FEAT=small gives the candidate-driven group a REDUCED feature
# set. On a single held-out fed2022 fold, 9 features beat 41 on that population
# -- RMSE 3.336 vs 3.753, and Wentworth 30.6 vs 19.1 against an actual 35.8 --
# because most of the majors' features are noise for a vote generated by a
# person. This runs it under proper leave-one-pair-out CV, since one fold at
# fixed rounds is not evidence of an 11% gain.
IND_SMALL <- c("sal_exp", "jump_pctile", "x", "ret_exp", "cand_all_new",
               "n_cand_now", "party_IND", "party_OTH", "party_OTH_RIGHT")
# WHY "small" LOSES UNDER PROPER CV, despite winning on a single fed2022 fold:
# it omits `pred_share`, the existing model's own prediction and the largest
# single SHAP contributor at +11.9 points. That is survivable for six seats
# where salience dominates and ruinous for the other 7,000 cells -- pooled RMSE
# 4.2569 against 3.8710, with every candidate-driven class worse.
#
# "medium" is the ablation result instead: every feature EXCEPT the six the SHAP
# showed actively dragging Spender down. On the fed2022 fold that reached
# Wentworth 24.1 AND improved RMSE to 3.567, i.e. it helped in both directions
# at once, which is what a genuinely harmful feature looks like when removed.
IND_DROP <- c("ballot_pos_min", "n_cand_now", "cand_best_own_prev",
              "own_prev_pcv", "jump", "soph_cand_i")
.indf <- Sys.getenv("AUSPOL_V7_IND_FEAT", "full")
if (!.indf %in% c("full", "small", "medium"))
  stop("AUSPOL_V7_IND_FEAT must be full, small or medium")
cat(sprintf("X73e candidate-driven feature set: %s\n", .indf))
FE[, pred_v7e := NA_real_]
if ("v7e" %in% keep) {
for (g in unique(FE$grp)) {
  gi <- which(FE$grp == g)
  gfeat <- if (g != "candidate_driven") best
           else switch(.indf,
                       small  = intersect(IND_SMALL, names(FE)),
                       medium = setdiff(best, IND_DROP),
                       best)
  Mg <- as.matrix(FE[gi, gfeat, with = FALSE])
  # Folds must still be the election pair, and only the pairs present in this
  # group -- match() against the global list would leave empty folds that
  # xgb.cv silently treats as a fold with no rows.
  gp <- sort(unique(FE$pair[gi]))
  gfolds <- split(seq_along(gi), match(FE$pair[gi], gp))
  set.seed(42)
  cvg <- xgb.cv(params = params,
                data = xgb.DMatrix(Mg, label = y[gi], missing = NA),
                nrounds = 2000, folds = gfolds, early_stopping_rounds = 30,
                prediction = TRUE, verbose = 0)
  set(FE, gi, "pred_v7e", cvg$cv_predict$pred[, 1])
  cat(sprintf("X73e   %s: %d cells, %d rounds, within-group RMSE %.4f\n",
              sprintf("%s [%d feat]", g, length(gfeat)), length(gi), cvg$early_stop$best_iteration,
              sqrt(mean((cvg$cv_predict$pred[, 1] - y[gi])^2))))
  # xgb.cv holds one booster per fold plus a full prediction matrix, so peak
  # memory scales with arms x folds. Free each group before the next allocates.
  rm(cvg, Mg); invisible(gc(verbose = FALSE))
}
  stopifnot(all(is.finite(FE$pred_v7e)))
  res[["v7e"]] <- data.table(arm = "v7e", features = length(best), nrounds = NA_integer_,
                             rmse = sqrt(mean((FE$pred_v7e - y)^2)),
                             mae = mean(abs(FE$pred_v7e - y)))
  cat(sprintf("X73e  v7e pooled over both models: RMSE %.4f\n",
              sqrt(mean((FE$pred_v7e - y)^2))))
}
cat("\nX73  ALL ARMS. RMSE and MAE are points of primary vote, LOWER IS BETTER.\n")
print(rbindlist(res)[, .(arm, features, nrounds, rmse = round(rmse, 4), mae = round(mae, 4))])

cat("\nX74  RMSE by class, lower is better. This is where a change should show up:\n")
ran <- intersect(paste0("pred_", c("v6","v7a","v7b","v7c","v7d","v7e","v7f","v7g","v7h")), names(FE))
ran <- ran[vapply(ran, function(k) any(is.finite(FE[[k]])), TRUE)]
rm_ <- function(k) sqrt(mean((FE[[k]] - FE$actual_share)^2))
by_cls <- FE[, c(list(cells = .N),
                 setNames(lapply(ran, function(k)
                   round(sqrt(mean((get(k) - actual_share)^2)), 3)),
                   sub("^pred_", "", ran))), by = party]
print(by_cls)

cat("\nX75  THE TARGETS. fed2022 teal seats, predicted IND primary in points.\n")
TEALS <- c("Wentworth", "Mackellar", "Kooyong", "Curtin", "North Sydney", "Goldstein")
print(FE[pair == "fed2022" & party == "IND" & seat %in% TEALS,
         c(list(seat = seat, actual = round(actual_share, 1)),
           setNames(lapply(ran, function(k) round(get(k), 1)), sub("^pred_", "", ran)),
           list(sal_exp = round(sal_exp, 1), ret_exp = round(ret_exp, 1)))][order(-actual)])

cat("\nX76  THE DO-NO-HARM CHECK -- genuine collapses must stay low.\n")
cat("X76  IND cells that polled >=15 last time, nobody returning, LOW salience.\n")
cat("X76  These should NOT be lifted by the change.\n")
COL <- FE[party == "IND" & x >= 15 & cand_all_new == 1L & jump_pctile < 0.95]
print(COL[, c(list(cells = .N, polled_last = round(mean(x), 1),
              actual = round(mean(actual_share), 1)),
              setNames(lapply(ran, function(k) round(mean(get(k)), 1)), sub("^pred_", "", ran)))])
cat("X76  and the real emergences -- same shape but HIGH salience:\n")
EMG <- FE[party == "IND" & cand_all_new == 1L & jump_pctile >= 0.95]
print(EMG[, c(list(cells = .N, polled_last = round(mean(x), 1),
              actual = round(mean(actual_share), 1)),
              setNames(lapply(ran, function(k) round(mean(get(k)), 1)), sub("^pred_", "", ran)))])

# THE FILE THE HARNESS READS. R/xgb_primary_override.R takes
# AUSPOL_XGB_PRIMARY_OOF and expects (pair, seat, party, xgb_pred), so the
# winning arm is written in exactly that shape and the harness needs no change:
#   AUSPOL_XGB_PRIMARY_OOF=output/xgb-primary-v7-oof-predictions.csv
# Which arm counts as winning is explicit rather than inferred -- AUSPOL_V7_SHIP
# names it, and it must be one that actually ran this invocation.
.ship <- Sys.getenv("AUSPOL_V7_SHIP", if ("pred_v7e" %in% ran) "v7e" else sub("^pred_", "", ran[1]))
if (length(ran) && paste0("pred_", .ship) %in% ran) {
  SHIP <- FE[, .(pair, seat, party, pred_share, actual_share)]
  SHIP[, xgb_pred := FE[[paste0("pred_", .ship)]]]
  fwrite(SHIP, file.path(OUT, "xgb-primary-v7-oof-predictions.csv"))
  cat(sprintf("\nX77  wrote %s/xgb-primary-v7-oof-predictions.csv from arm %s (%d rows)\n",
              OUT, .ship, nrow(SHIP)))
  cat("X77  point the harness at it with AUSPOL_XGB_PRIMARY_OOF=output/xgb-primary-v7-oof-predictions.csv\n")
} else {
  cat(sprintf("\nX77! arm %s did not run -- no harness file written\n", .ship))
}

fwrite(FE[, c("pair", "seat", "party", "actual_share", "jump_pctile", "sal_exp",
              "ret_exp", cand_feat, ran), with = FALSE],
       file.path(OUT, "xgb-primary-v7-arms.csv"))
cat(sprintf("\nX77  wrote %s/xgb-primary-v7-arms.csv\n", OUT))
