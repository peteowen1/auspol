# Do RECENCY and SIMILARITY weights improve the flow model? -- experiment
#
# WHY. Preference flows drift. Mirani qld2024's deciding transfer (ALP
# excluded, LNP vs OTH_RIGHT left) has 10 well-matched historical events in
# the corpus, and they trend steadily: Kennedy's own ALP->LNP share runs
# 19.0% (fed2013) -> 22.3% -> 29.0% -> 30.7% -> 29.7% (fed2025). The flat
# unweighted mean the model currently trains on is 26.6%; the actual Mirani
# result was 32.7%. Flat-averaging twelve years pulls the estimate ~6 points
# below where the recent trend sits, and that is most of that seat's error.
#
# Pete's proposal, 2026-09-16: weight each historical row by (1) how long ago
# it happened, and (2) how correlated that election/seat is with the one
# being predicted -- same seat highest, same state next, a state election on
# the other side of the country least. Test which weighting best improves
# held-out prediction.
#
# METHOD. This is a GENERAL change (a weighting form, applied corpus-wide),
# so per CLAUDE.md the primary metric is corpus-wide held-out RMSE and the
# named cases are secondary. Weights depend on the TARGET being predicted, so
# a single xgb.cv DMatrix cannot express them -- each fold needs its own
# weight vector. This therefore runs an explicit leave-one-election-out loop
# (same structure as fit_xgb_flows_loo.R) rather than xgb.cv, accumulating
# out-of-fold predictions per scheme and scoring them on identical rows.
#
# Reads the feature file fit_xgb_flows_v1.R writes, so there is no second
# copy of the feature code to drift. Emits XW* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(xgboost))

OUT <- "output"
feat_f <- file.path(OUT, "xgb-flows-v1-features.csv")
cols_f <- file.path(OUT, "xgb-flows-v1-final-cols.json")
if (!file.exists(feat_f) || !file.exists(cols_f))
  stop("run scripts/fit_xgb_flows_v1.R first -- need ", feat_f, " and ", cols_f)

TX <- fread(feat_f, showProgress = FALSE)
feat_cols <- jsonlite::fromJSON(readLines(cols_f))
stopifnot(all(feat_cols %in% names(TX)))

# Year and region from the election label ("fed2013", "nsw2019"). The corpus
# has no election->date table; year granularity is enough for a decay term
# measured in years, and is stated rather than silently assumed.
TX[, el_year := as.integer(sub("^[a-z]+", "", election))]
if (anyNA(TX$el_year)) stop("could not parse a year out of: ",
                            paste(unique(TX$election[is.na(TX$el_year)]), collapse = ", "))
cat(sprintf("XW1  %d rows, %d elections (%d-%d), %d regions\n", nrow(TX),
            uniqueN(TX$election), min(TX$el_year), max(TX$el_year), uniqueN(TX$region)))

X <- as.matrix(TX[, ..feat_cols])
y <- TX$y
elections <- sort(unique(TX$election))

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8, min_child_weight = 5)
NROUNDS <- as.integer(Sys.getenv("AUSPOL_FLOW_W_NROUNDS", "300"))

# ---- weighting schemes ----------------------------------------------------
# Each returns a weight per TRAINING row given the held-out target's year and
# region. All are multiplicative on a base of 1 and never zero -- a zero
# weight silently deletes evidence, which is the failure mode a hard min_n
# cliff has and that CLAUDE.md's shrinkage rule exists to avoid.
decay_w <- function(train_year, target_year, half_life) {
  gap <- pmax(0, target_year - train_year)          # future rows get no bonus
  0.5 ^ (gap / half_life)
}
# Same region is the strongest signal available here. A federal election in
# the target's own state would be stronger still, but the corpus stores
# federal seats under region "fed" with no state column, so that tier is NOT
# claimed -- stating the limit rather than faking the feature.
region_w <- function(train_region, target_region, off_region) {
  ifelse(train_region == target_region, 1, off_region)
}
# SEAT MATCHING IS REGION-QUALIFIED, and the name-only version is kept only
# to show why. 23 seat names appear in more than one jurisdiction (Murray in
# three; Bass, Parramatta, Adelaide, Melbourne, Perth...), so matching on name
# alone pulls in 8.8% cross-region rows corpus-wide -- and for sa2026, which
# is the only South Australian election in the corpus, it is 100% spurious:
# 365 "same seat" rows, none of them actually South Australian. A weight built
# on that is measuring a name collision, not a seat.
seat_w <- function(train_seat, target_seats, same_seat_boost) {
  ifelse(train_seat %in% target_seats, same_seat_boost, 1)
}
seat_region_w <- function(train_seat, train_region, target_seats, target_region, same_seat_boost) {
  ifelse(train_region == target_region & train_seat %in% target_seats, same_seat_boost, 1)
}

SCHEMES <- list(
  uniform           = function(tr, ty, trg, seats) rep(1, nrow(tr)),
  decay_hl8         = function(tr, ty, trg, seats) decay_w(tr$el_year, ty, 8),
  decay_hl4         = function(tr, ty, trg, seats) decay_w(tr$el_year, ty, 4),
  region_only       = function(tr, ty, trg, seats) region_w(tr$region, trg, 0.4),
  seat_name_only    = function(tr, ty, trg, seats) seat_w(tr$seat, seats, 3),
  seat_region_x3    = function(tr, ty, trg, seats) seat_region_w(tr$seat, tr$region, seats, trg, 3),
  seat_region_x6    = function(tr, ty, trg, seats) seat_region_w(tr$seat, tr$region, seats, trg, 6),
  decay8_region     = function(tr, ty, trg, seats) decay_w(tr$el_year, ty, 8) * region_w(tr$region, trg, 0.4),
  decay8_seatregion = function(tr, ty, trg, seats) decay_w(tr$el_year, ty, 8) * seat_region_w(tr$seat, tr$region, seats, trg, 3),
  decay8_reg_seat   = function(tr, ty, trg, seats) decay_w(tr$el_year, ty, 8) * region_w(tr$region, trg, 0.4) * seat_region_w(tr$seat, tr$region, seats, trg, 3)
)

oof <- matrix(NA_real_, nrow = nrow(TX), ncol = length(SCHEMES),
              dimnames = list(NULL, names(SCHEMES)))

for (e in elections) {
  held <- TX$election == e
  if (sum(!held) < 100L) { cat(sprintf("XW2! %s: only %d training rows -- skipped\n", e, sum(!held))); next }
  tr <- TX[!held]
  ty <- TX$el_year[held][1]
  trg <- TX$region[held][1]
  seats_held <- unique(TX$seat[held])
  for (s in names(SCHEMES)) {
    w <- SCHEMES[[s]](tr, ty, trg, seats_held)
    stopifnot(all(is.finite(w)), all(w > 0))
    set.seed(42)
    m <- xgb.train(params = params,
                   data = xgb.DMatrix(data = X[!held, , drop = FALSE], label = y[!held],
                                      weight = w, missing = NA),
                   nrounds = NROUNDS, verbose = 0)
    oof[held, s] <- pmax(0, predict(m, X[held, , drop = FALSE]))
  }
  cat(sprintf("XW2  %-9s held out %4d rows\n", e, sum(held)))
}

# ---- score: corpus-wide held-out RMSE, the PRIMARY metric -----------------
ok <- stats::complete.cases(oof)
cat(sprintf("\nXW3  scored on %d of %d rows (rows from skipped folds excluded)\n", sum(ok), nrow(TX)))
res <- data.table(scheme = names(SCHEMES),
                  rmse = vapply(names(SCHEMES), function(s) sqrt(mean((oof[ok, s] - y[ok])^2)), numeric(1)))
res[, delta_vs_uniform := rmse - res$rmse[res$scheme == "uniform"]]
setorder(res, rmse)
cat("\nXW3  held-out RMSE on transfer share (0-1 scale; LOWER is better)\n")
print(res)

# ---- named case, secondary: Mirani's deciding transfer --------------------
cat("\nXW4  named case -- Mirani qld2024, ALP excluded, LNP vs OTH_RIGHT\n")
mir <- which(TX$election == "qld2024" & TX$seat == "Mirani" & TX$from == "ALP")
if (length(mir)) {
  out <- data.table(to = TX$to[mir], actual = y[mir])
  for (s in names(SCHEMES)) out[[s]] <- round(oof[mir, s], 4)
  print(out)
} else cat("XW4! Mirani ALP-exclusion rows not in the feature file\n")

fwrite(cbind(TX[, .(election, seat, round, from, to, y)], as.data.table(oof)),
       file.path(OUT, "xgb-flows-weighted-oof.csv"))
cat(sprintf("\nXW5  wrote %s/xgb-flows-weighted-oof.csv\n", OUT))
