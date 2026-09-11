# Is the xgb primary model badly calibrated for IND/GRN/ONP IN GENERAL, or
# only for EMERGENT ones? And does anything we already compute predict which
# is which?
#
# Pete's questions, 2026-09-11, in order:
#   1. is xgb well calibrated for IND/GRN/ONP in general but not for emergent
#      candidates?
#   2. do we have a prediction of emergence at all -- salience, anything else?
#   3. how does it calibrate for those three groups at different levels of
#      predicted emergence?
#
# The v6 out-of-fold file already carries the emergence features the model was
# given: `jump` (the salience-derived campaign rise), `governed` (is this
# candidate in the governed population), `permit` (the nomination gate),
# `surge_h` (the per-seat emergence hazard from the salience corpus) and
# `is_recipient` (was this class picked as the seat's surge recipient). So
# question 2 is answerable from disk, and question 3 is a bucketed calibration
# against surge_h.
#
# Every number here is out-of-fold (leave-one-pair-out), so this is what the
# model does on elections it did not see.
#
# Emits EC* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

OUT <- "output"
X <- fread(file.path(OUT, "xgb-primary-v6-oof-predictions.csv"), showProgress = FALSE)
E <- fread(file.path(OUT, "emergence-cases.csv"), showProgress = FALSE)
X[, emergent := paste(pair, seat, party) %in% paste(E$pair, E$seat, E$party)]
FOCUS <- c("IND", "GRN", "ONP", "OTH_RIGHT")
cat(sprintf("EC1  %d rows, %d flagged emergent (%d in the focus classes)\n",
            nrow(X), sum(X$emergent), sum(X$emergent & X$party %in% FOCUS)))

bias <- function(d) mean(d$xgb_pred - d$actual_share)
rmse <- function(d) sqrt(mean((d$xgb_pred - d$actual_share)^2))

# ---- Q1: general vs emergent -----------------------------------------------
cat("\nEC2  CALIBRATION BY CLASS, split by whether the case is an emergence.\n")
cat("     bias = mean(predicted - actual) in percentage points. NEGATIVE = we under-predict them.\n")
cat("     n is the raw row count, not a rate.\n")
B <- X[party %in% FOCUS, .(n = .N, bias = bias(.SD), rmse = rmse(.SD),
                            mean_actual = mean(actual_share)),
       by = .(party, emergent), .SDcols = c("xgb_pred", "actual_share")]
setorder(B, party, emergent)
print(B[, .(party, emergent, n, mean_actual = round(mean_actual, 1),
            bias = round(bias, 2), rmse = round(rmse, 2))])
cat("\nEC2  the same for the majors, as the reference point\n")
M <- X[party %in% c("ALP","LNP"), .(n = .N, bias = bias(.SD), rmse = rmse(.SD)),
       by = .(party), .SDcols = c("xgb_pred","actual_share")]
print(M[, .(party, n, bias = round(bias, 2), rmse = round(rmse, 2))])

# ---- Q2: do we have any emergence signal at all? ---------------------------
# The honest test is DISCRIMINATION, not correlation: among the rows of one
# class, is the feature higher for the ones that actually emerged? Reported as
# AUC, which is just "probability a random emergent row scores above a random
# non-emergent one" -- 0.5 is no signal.
auc <- function(score, lab) {
  if (length(unique(lab)) < 2L) return(NA_real_)
  r <- rank(score)
  n1 <- sum(lab); n0 <- sum(!lab)
  (sum(r[lab]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
cat("\nEC3  DOES ANYTHING PREDICT EMERGENCE? AUC within each class; 0.50 = no signal, 1.00 = perfect.\n")
feats <- c("jump", "surge_h", "governed", "permit", "is_recipient", "pred_share")
A <- rbindlist(lapply(FOCUS, function(p) {
  d <- X[party == p]
  if (!sum(d$emergent)) return(NULL)
  as.data.table(c(list(party = p, n = nrow(d), n_emerge = sum(d$emergent)),
                  setNames(lapply(feats, function(f) round(auc(d[[f]], d$emergent), 3)), feats)))
}), fill = TRUE)
print(A)
cat("EC3  pred_share is the SHIPPED model's own point estimate, included as the baseline to beat.\n")

# ---- Q3: calibration by predicted-emergence level --------------------------
cat("\nEC4  CALIBRATION BY surge_h, the salience emergence hazard. Focus classes only.\n")
cat("     If surge_h worked, bias should be near zero in every band, not just the bottom one.\n")
F <- X[party %in% FOCUS]
F[, band := cut(surge_h, breaks = c(-Inf, 0, 0.05, 0.15, 0.35, Inf),
                labels = c("0 (no hazard)", "0-0.05", "0.05-0.15", "0.15-0.35", "0.35+"))]
S <- F[, .(n = .N, emergent = sum(emergent),
           mean_pred = mean(xgb_pred), mean_actual = mean(actual_share),
           bias = bias(.SD), rmse = rmse(.SD)),
       by = band, .SDcols = c("xgb_pred","actual_share")]
setorder(S, band)
print(S[, .(band, n, emergent, mean_pred = round(mean_pred, 1),
            mean_actual = round(mean_actual, 1), bias = round(bias, 2), rmse = round(rmse, 2))])

cat("\nEC5  the same, but banded on what the MODEL ITSELF predicted (xgb_pred).\n")
cat("     This separates 'cannot see it coming' from 'sees it and shrinks it'.\n")
F[, pband := cut(xgb_pred, breaks = c(-Inf, 2, 5, 10, 20, 35, Inf),
                 labels = c("<2", "2-5", "5-10", "10-20", "20-35", "35+"))]
P <- F[, .(n = .N, emergent = sum(emergent),
           mean_pred = mean(xgb_pred), mean_actual = mean(actual_share),
           bias = bias(.SD)), by = pband, .SDcols = c("xgb_pred","actual_share")]
setorder(P, pband)
print(P[, .(pband, n, emergent, mean_pred = round(mean_pred, 1),
            mean_actual = round(mean_actual, 1), bias = round(bias, 2))])

# ---- the ceiling question --------------------------------------------------
# The single most useful number for deciding what to build: what is the HIGHEST
# the model ever predicts for these classes, and how often does reality go
# above it? A model that structurally cannot say "30%" needs a different fix
# from one that can but usually does not.
cat("\nEC6  THE CEILING. How high does the model ever go for these classes, and how often is reality higher?\n")
C <- X[party %in% FOCUS, .(n = .N,
                            max_pred = max(xgb_pred), p99_pred = quantile(xgb_pred, 0.99),
                            max_actual = max(actual_share),
                            actual_over_25 = sum(actual_share > 25),
                            pred_over_25 = sum(xgb_pred > 25)), by = party]
print(C[, .(party, n, p99_pred = round(p99_pred, 1), max_pred = round(max_pred, 1),
            max_actual = round(max_actual, 1), actual_over_25, pred_over_25)])
