# A per-candidate model for minor parties and independents.
#
# Predicts each IND / OTH / OTH_RIGHT / ONP candidate's first-preference share
# from what is known when nominations close, then sums candidates to each
# group's statewide share -- a bottom-up split of the unpolled "others"
# bucket, which the statewide forecast currently splits by the previous
# election's mix (the largest statewide error found: 3.39 points of
# misallocation per election). Pete, 2026-09-28: engineer every feature, let
# a good CV decide what is useful.
#
# Time-forward: each target election is predicted by models fitted only on
# elections dated strictly before it. Every feature records the date of the
# election it came from and the script stops if one is not earlier than the
# target (MC2).
#
# docs/plans/prereg-minor-candidate-model-2026-09-28.md
#
# Writes output/minor-candidate-features.csv (every feature, every row),
#        output/minor-candidate-oof.csv (time-forward predictions),
#        output/minor-candidate-scores.csv (the criterion, per pair).
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
MINOR <- c("IND", "OTH", "OTH_RIGHT", "ONP")
SEED <- as.integer(Sys.getenv("AUSPOL_SEED", "42"))
ARM <- Sys.getenv("AUSPOL_MC_ARM", "resid")   # "scratch" = v1, "resid" = v2 (correction on the naive prediction)
cat(sprintf("MC0  arm: %s\n", ARM))

C <- fread("output/candidacies.csv", showProgress = FALSE)
cat(sprintf("MC0  candidacies: %d rows, %d elections\n", nrow(C), uniqueN(C$election)))
dts <- election_dates()
C[, edate := as.Date(unname(dts[election]))]
if (anyNA(C$edate)) stop("MC0! no date for: ", paste(unique(C[is.na(edate), election]), collapse = ", "))
C <- C[is.finite(votes)]
C[, share := 100 * votes / sum(votes), by = .(election, seat)]
C[, juris := region]
STATE_AB <- c(vic = "VIC", nsw = "NSW", qld = "QLD", sa = "SA", wa = "WA")
C[, st := fifelse(juris == "fed", toupper(state), STATE_AB[juris])]

# ---- keys -------------------------------------------------------------------
# Names come as "Kate ELLIS", "APLIN Greg", "ENOCH, Leeanne", and WA splits
# them across name/given. Key = the sorted set of upper-case name tokens.
name_key <- function(n, g) {
  vapply(paste(n, fifelse(is.na(g), "", g)), function(s) {
    tk <- unique(strsplit(gsub("[^A-Z]+", " ", toupper(s)), " +")[[1]])
    paste(sort(tk[nzchar(tk)]), collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}
C[, nk := name_key(name, given)]
# Party key: one name across years and spellings. Independents are each their
# own party (no party history), handled by the IND class.
party_key <- function(raw, ab, cls) {
  s <- tolower(fifelse(!is.na(raw) & nzchar(raw), raw, fifelse(is.na(ab), "", ab)))
  s <- gsub("[^a-z ]", " ", s)
  s <- gsub("\\b(party|of|the|inc|incorporated|australian?|victoria|victorian|nsw|queensland|qld|division|western|wa|south|sa|vic|state)\\b", " ", s)
  s <- gsub(" +", "", s)
  s[grepl("hanson|onenation|^pho$|^phon$|^on$", s)] <- "onenation"
  s[grepl("shooters|^sff$", s)] <- "shooters"
  s[grepl("familyfirst|^ffp$", s)] <- "familyfirst"
  s[grepl("democraticlabour|labourdlp|^dlp$", s)] <- "dlp"
  s[grepl("christiandemocrat|^cdp$", s)] <- "cdp"
  s[grepl("liberaldemocrat|^ldp$", s)] <- "libdem"
  s[grepl("palmer|unitedaustralia|^uap$|^pup$", s)] <- "palmer"
  s[grepl("animaljustice|^ajp$", s)] <- "animaljustice"
  s[grepl("legalise|cannabis|hemp", s)] <- "cannabis"
  s[grepl("sustainable|^sus$", s)] <- "sustainable"
  s[cls == "IND" | s %in% c("", "independent", "ind")] <- NA_character_
  s
}
C[, pk := party_key(party_raw, party_ab, party)]
cat(sprintf("MC1  %d minor/IND candidate rows; party keys: %d distinct (IND rows have none)\n",
            C[party %in% MINOR, .N], C[party %in% MINOR & !is.na(pk), uniqueN(pk)]))

# ---- election order within each jurisdiction -------------------------------
E <- unique(C[, .(election, juris, edate)])[order(juris, edate)]
E[, prev := shift(election), by = juris]
E[, prev_date := shift(edate), by = juris]
C <- merge(C, E[, .(election, prev, prev_date)], by = "election")

seat_tot <- C[, .(seat_votes = sum(votes)), by = .(election, seat)]
state_cls <- C[, .(v = sum(votes)), by = .(election, party)][, cls_state := 100 * v / sum(v), by = election]
state_cls <- state_cls[, .(election, cls = party, cls_state)]
cls_n <- C[, .(cls_cands = .N), by = .(election, cls = party)]
pty <- C[!is.na(pk), .(p_mean = mean(share), p_seats = uniqueN(seat)), by = .(election, pk)]
fed <- C[juris == "fed"]

# ---- features for every minor/IND row --------------------------------------
M <- C[party %in% MINOR]
M[, cls := party]
feat <- function(m) {
  el <- m$election[1]; pv <- m$prev[1]; pd <- m$prev_date[1]; ed <- m$edate[1]
  P <- if (is.na(pv)) C[0] else C[election == pv]
  prior_j <- C[juris == m$juris[1] & edate < ed]
  # candidate
  own <- P[, .(own_prev = max(share)), by = nk]
  own_s <- P[, .(own_prev_seat = max(share), held = any(elected %in% TRUE)), by = .(nk, seat)]
  runs <- prior_j[, .(n_prior = uniqueN(election)), by = nk]
  # federal history, matched on each row's OWN state (a federal target has
  # rows from every state): the candidate's latest earlier federal vote, and
  # the party's mean at the latest earlier federal election in that state
  fedp <- fed[edate < ed]
  fed_last <- if (nrow(fedp)) fedp[edate == max(edate)] else fedp
  fed_own <- fedp[, .(fed_own = share[which.max(edate)], fed_date = max(edate)), by = nk]
  # party
  pp <- pty[election == pv, .(pk, p_prev_mean = p_mean, p_prev_seats = p_seats)]
  pn <- pty[election == el, .(pk, p_now_seats = p_seats)]
  p_ever <- unique(prior_j[!is.na(pk), .(pk, p_seen = TRUE)])
  p_seat <- P[!is.na(pk), .(p_prev_seat = max(share)), by = .(pk, seat)]
  p_fed <- if (nrow(fed_last)) fed_last[!is.na(pk), .(p_fed_mean = mean(share)), by = .(pk, st)] else data.table(pk = character(), st = character(), p_fed_mean = numeric())
  # seat
  sp <- P[, .(seat_prev_minor = sum(share[party %in% MINOR]), seat_prev_n = .N), by = seat]
  spc <- P[party %in% MINOR, .(seat_prev_cls = sum(share)), by = .(seat, cls = party)]
  now <- C[election == el, .(n_minor_now = sum(party %in% MINOR), n_cands_now = .N), by = seat]
  nowc <- C[election == el & party %in% MINOR, .(n_cls_now = .N), by = .(seat, cls = party)]
  # group statewide
  gs <- state_cls[election == pv, .(cls, cls_prev_state = cls_state)]
  gn <- merge(cls_n[election == el, .(cls, cls_cands_now = cls_cands)],
              cls_n[election == pv, .(cls, cls_cands_prev = cls_cands)], by = "cls", all.x = TRUE)
  x <- copy(m)
  x <- merge(x, own, by = "nk", all.x = TRUE)
  x <- merge(x, own_s, by = c("nk", "seat"), all.x = TRUE)
  x <- merge(x, runs, by = "nk", all.x = TRUE)
  x <- merge(x, fed_own, by = "nk", all.x = TRUE)
  x <- merge(x, pp, by = "pk", all.x = TRUE)
  x <- merge(x, pn, by = "pk", all.x = TRUE)
  x <- merge(x, p_ever, by = "pk", all.x = TRUE)
  x <- merge(x, p_seat, by = c("pk", "seat"), all.x = TRUE)
  x <- merge(x, p_fed, by = c("pk", "st"), all.x = TRUE)
  x <- merge(x, sp, by = "seat", all.x = TRUE)
  x <- merge(x, spc, by = c("seat", "cls"), all.x = TRUE)
  x <- merge(x, now, by = "seat", all.x = TRUE)
  x <- merge(x, nowc, by = c("seat", "cls"), all.x = TRUE)
  x <- merge(x, gs, by = "cls", all.x = TRUE)
  x <- merge(x, gn, by = "cls", all.x = TRUE)
  # MC2: the leakage assertion. Everything above reads elections before `ed`.
  srcs <- c(P$edate, prior_j$edate, fedp$edate)
  if (length(srcs) && any(srcs >= ed)) stop("MC2! a feature for ", el, " reads an election on or after it")
  x[, `:=`(n_prior = fifelse(is.na(n_prior), 0L, n_prior), held = held %in% TRUE,
           p_new = !is.na(pk) & is.na(p_seen), ran_fed = !is.na(fed_own),
           p_seat_ratio = p_now_seats / p_prev_seats, cls_cand_ratio = cls_cands_now / cls_cands_prev,
           has_prev_election = !is.na(pv))]
  x[, c("p_seen", "fed_date") := NULL]
  x
}
Fx <- rbindlist(lapply(split(M, by = "election"), feat), fill = TRUE)
cat(sprintf("MC2  features built for %d rows over %d elections; leakage assertion passed for every election\n",
            nrow(Fx), uniqueN(Fx$election)))
FEATS <- c("own_prev", "own_prev_seat", "held", "n_prior", "fed_own", "ran_fed",
           "p_prev_mean", "p_prev_seats", "p_now_seats", "p_seat_ratio", "p_new", "p_prev_seat", "p_fed_mean",
           "seat_prev_minor", "seat_prev_n", "seat_prev_cls", "n_minor_now", "n_cands_now", "n_cls_now",
           "cls_prev_state", "cls_cands_now", "cls_cands_prev", "cls_cand_ratio", "has_prev_election")
cov <- Fx[, lapply(.SD, function(v) round(mean(!is.na(v)), 2)), .SDcols = FEATS]
cat("MC3  feature coverage (share of rows non-missing):\n"); print(melt(cov, measure.vars = FEATS)[order(value)], nrows = 40)
fwrite(Fx, "output/minor-candidate-features.csv")

# ---- the time-forward fit ----------------------------------------------------
mm <- function(d) {
  X <- as.matrix(d[, ..FEATS][, lapply(.SD, as.numeric)])
  cbind(X, IND = d$cls == "IND", OTH = d$cls == "OTH", OTH_RIGHT = d$cls == "OTH_RIGHT", ONP = d$cls == "ONP",
        fed = d$juris == "fed")
}
naive <- function(d) {
  b <- fifelse(!is.na(d$own_prev_seat), d$own_prev_seat,
       fifelse(!is.na(d$own_prev), d$own_prev,
       fifelse(!is.na(d$p_prev_mean), d$p_prev_mean,
       fifelse(!is.na(d$seat_prev_cls) & !is.na(d$n_cls_now), d$seat_prev_cls / pmax(1, d$n_cls_now), NA_real_))))
  fifelse(is.na(b), stats::median(Fx$share), b)
}
targets <- unique(Fx[, .(election, edate)])[order(edate)]
oof <- list()
for (i in seq_len(nrow(targets))) {
  el <- targets$election[i]; ed <- targets$edate[i]
  tr <- Fx[edate < ed]; te <- Fx[election == el]
  n_el <- uniqueN(tr$election)
  if (n_el < 2) { cat(sprintf("MC4  %s: %d earlier elections, not fitted\n", el, n_el)); next }
  set.seed(SEED)
  dtr <- xgboost::xgb.DMatrix(mm(tr), label = tr$share)
  # 5 folds grouped by election (per-election folds made this 9 minutes)
  el_tr <- unique(tr$election); set.seed(SEED); grp <- sample(rep_len(1:5, length(el_tr)))
  fold_of <- setNames(grp, el_tr)[tr$election]
  folds <- lapply(sort(unique(fold_of)), function(k) which(fold_of == k))
  # ARM "resid" (v2): the tree learns a correction on the naive prediction
  if (ARM == "resid") xgboost::setinfo(dtr, "base_margin", naive(tr))
  prm <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4, subsample = 0.8,
              colsample_bytree = 0.8, min_child_weight = 5)
  cv <- xgboost::xgb.cv(prm, dtr, nrounds = 1500, folds = folds, early_stopping_rounds = 50, verbose = 0)
  nr <- cv$best_iteration %||% cv$early_stop$best_iteration
  fit <- xgboost::xgb.train(prm, dtr, nrounds = nr, verbose = 0)
  dte <- xgboost::xgb.DMatrix(mm(te))
  if (ARM == "resid") xgboost::setinfo(dte, "base_margin", naive(te))
  te[, `:=`(pred_xgb = pmax(0, predict(fit, dte)), pred_naive = naive(te), n_train_el = n_el, nrounds = nr)]
  oof[[el]] <- te
  cat(sprintf("MC4  %-8s trained on %2d earlier elections (%5d rows), %4d rounds | RMSE xgb %.2f, naive %.2f\n",
              el, n_el, nrow(tr), nr, te[, sqrt(mean((pred_xgb - share)^2))], te[, sqrt(mean((pred_naive - share)^2))]))
}
O <- rbindlist(oof)
fwrite(O[, .(election, seat, name, cls, pk, share, pred_xgb, pred_naive, n_train_el, nrounds)], paste0("output/minor-candidate-oof-", ARM, ".csv"))
cat(sprintf("\nMC5  candidate-level RMSE over %d rows (points; lower is better): xgb %.3f, naive %.3f\n",
            nrow(O), O[, sqrt(mean((pred_xgb - share)^2))], O[, sqrt(mean((pred_naive - share)^2))]))

# ---- the criterion: statewide bucket-class shares ---------------------------
# Seat weights: the previous election's formal votes in that seat (known
# before the election), falling back to the median seat.
O <- merge(O, seat_tot[, .(prev = election, seat, w_prev = seat_votes)], by = c("prev", "seat"), all.x = TRUE)
O[, w := fifelse(is.na(w_prev), stats::median(w_prev, na.rm = TRUE), w_prev), by = election]
O[, w := fifelse(is.na(w), 1, w)]
seat_w <- unique(O[, .(election, seat, w)])
cls_sum <- O[, .(m_xgb = sum(pred_xgb * w), m_naive = sum(pred_naive * w)), by = .(election, cls)]
cls_sum <- merge(cls_sum, seat_w[, .(W = sum(w)), by = election], by = "election")
cls_sum[, `:=`(m_xgb = m_xgb / W, m_naive = m_naive / W)]
A <- fread("output/statewide-forecast-audit-base27sepB.csv")[in_bucket == TRUE & cls %in% MINOR]
S <- merge(A[, .(election = pair, cls, current = forecast, actual)], cls_sum, by = c("election", "cls"), all.x = TRUE)
S[is.na(m_xgb), `:=`(m_xgb = 0, m_naive = 0)]   # a class with no candidates predicts zero
P <- S[, .(cur = mean(abs(current - actual)), xgb = mean(abs(m_xgb - actual)), nai = mean(abs(m_naive - actual)),
           n_cls = .N), by = election]
P <- merge(P, unique(O[, .(election, n_train_el)]), by = "election", all.x = TRUE)
fwrite(merge(S, P[, .(election, n_train_el)], by = "election"), paste0("output/minor-candidate-scores-", ARM, ".csv"))
score <- function(P, lab) {
  d <- P$xgb - P$cur; se <- sd(d) / sqrt(nrow(P))
  cat(sprintf("%s: %d pairs | mean |statewide class share error| current %.3f, candidate model %.3f, naive %.3f | change %+.3f, paired SE %.3f (t %.2f) %s\n",
              lab, nrow(P), mean(P$cur), mean(P$xgb), mean(P$nai), mean(d), se, mean(d) / se,
              if (mean(d) <= -se) "PASS" else "FAIL"))
}
cat("\nMC6  PRIMARY (points of statewide first preference per bucket class; lower is better)\n")
P <- P[!is.na(n_train_el)]
score(P, "ALL")
worst <- P[which.max(abs(xgb - cur)), election]
score(P[election != worst], sprintf("WITHOUT largest mover %s", worst))
score(P[n_train_el >= 3], "ONLY pairs with 3+ earlier elections")
print(P[order(xgb - cur), .(election, n_train_el, current = round(cur, 2), candidate_model = round(xgb, 2), naive = round(nai, 2))], nrows = 30)

# ---- what the model used -----------------------------------------------------
set.seed(SEED)
dall <- xgboost::xgb.DMatrix(mm(Fx), label = Fx$share)
fall <- xgboost::xgb.train(list(objective = "reg:squarederror", eta = 0.05, max_depth = 4, subsample = 0.8,
                                colsample_bytree = 0.8, min_child_weight = 5), dall, nrounds = stats::median(O$nrounds))
imp <- xgboost::xgb.importance(model = fall)
cat("\nMC7  feature importance (gain, all elections; descriptive only):\n"); print(imp[1:min(20, .N), .(Feature, Gain = round(Gain, 3))])
