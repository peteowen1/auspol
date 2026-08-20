# Three mechanisms for the independent vote, not one.
#
# Against docs/plans/prereg-independent-two-mechanism.md, committed before this
# ran. The routing rule, the structure and refusals E1-E5, G1 and H1-H3 are
# there and are NOT restated here.
#
# Routing uses the seat's OWN previous first preferences. It does NOT use the
# seat file's `incumbent` field, which records the current holder, is
# contaminated by by-elections (Bega, Kiama, Pittwater) and files the Shooters,
# Fishers and Farmers as IND where classify_party() maps them to OTH_RIGHT.
#
# Nothing numeric is taken from any other model. The idea of separating
# recontest from emergence is the anchor's; every number below is fitted here.
#
# Emits TM* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
SITTING_CUT <- 15      # pre-registered, NOT tuned; 10 and 20 reported below

share_of <- function(f) {
  d <- fread(file.path(P, f))[, .(v = sum(votes)), by = .(seat, party)]
  d[, pct := 100 * v / sum(v), by = seat]
  d[, .(seat, party, pct)]
}
wide <- function(x, sfx) {
  a <- dcast(x, seat ~ party, value.var = "pct", fill = 0)
  setnames(a, setdiff(names(a), "seat"), paste0(setdiff(names(a), "seat"), sfx))
  a
}
d <- merge(wide(share_of("nswec-2019-nsw-firstprefs.csv"), "_prev"),
           wide(share_of("nswec-2023-nsw-firstprefs.csv"), "_now"), by = "seat")
s <- as.data.table(load_seats(2023, "nsw"))[, .(seat, margin, incumbent)]
d <- merge(d, s, by = "seat")

d[, `:=`(other_nonmajor_prev = OTH_prev + OTH_RIGHT_prev,
         ind_prev = IND_prev, ind_now = IND_now,
         abs_margin = abs(margin),
         coalition_held = as.integer(incumbent %in% c("LNP", "LIB", "NAT")))]
d[, sitting := ind_prev >= SITTING_CUT]

cat(sprintf("\nTM1  %d seats; %d routed as SITTING independent (>= %d%%), %d as emergence\n",
            nrow(d), sum(d$sitting), SITTING_CUT, sum(!d$sitting)))
cat("TM1  sensitivity of the routing count to the cut-off (pre-registered, not tuned)\n")
for (k in c(10, 15, 20)) {
  cat(sprintf("     cut %2d%%: %d sitting\n", k, sum(d$ind_prev >= k)))
}

# ---- route 1: sitting independents -----------------------------------------
sit <- d[sitting == TRUE][order(-ind_prev)]
cat(sprintf("\nTM2  the %d sitting-independent seats\n", nrow(sit)))
print(sit[, .(seat, ind_2019 = round(ind_prev, 1), ind_2023 = round(ind_now, 1),
              recontested = ind_now >= 5)])

# H2: the recontest rate is ESTIMATED, not chosen. "Did not recontest" is read
# as the independent vote collapsing to near nothing.
n_re <- sum(sit$ind_now >= 5); n_tot <- nrow(sit)
recontest <- n_re / n_tot
cat(sprintf("TM2  recontest rate: %d of %d = %.3f\n", n_re, n_tot, recontest))
cat(sprintf("TM2  Jeffreys 95%% interval: %.3f to %.3f  <- %d seats is very little\n",
            stats::qbeta(0.025, n_re + 0.5, n_tot - n_re + 0.5),
            stats::qbeta(0.975, n_re + 0.5, n_tot - n_re + 0.5), n_tot))

# H1: the coefficient on log1p(previous) is FITTED, not fixed at 1.
re <- sit[ind_now >= 5]
fit1 <- if (nrow(re) >= 4) {
  m <- stats::lm(log1p(ind_now) ~ log1p(ind_prev), data = re)
  cf <- stats::coef(m); se <- summary(m)$coefficients[2, 2]
  cat(sprintf("\nTM3  route 1 fitted on %d recontesting seats\n", nrow(re)))
  cat(sprintf("TM3  log1p(next) = %.3f + %.3f * log1p(previous)\n", cf[1], cf[2]))
  cat(sprintf("TM3  slope %.3f +/- %.3f; distance from 1 is %.2f SE  (H1: fitted, not assumed)\n",
              cf[2], se, abs(cf[2] - 1) / se))
  cat(sprintf("TM3  residual sd on the log1p scale: %.4f\n", summary(m)$sigma))
  list(a = cf[1], b = cf[2], s = summary(m)$sigma, n = nrow(re))
} else {
  cat("\nTM3  too few recontesting seats to fit; route 1 unfittable\n"); NULL
}

# ---- route 2: emergence, exactly the v2 model on non-sitting seats ----------
em <- d[sitting == FALSE]
FEAT <- c("other_nonmajor_prev", "ind_prev", "abs_margin", "coalition_held")
FORM <- stats::as.formula(paste("y ~", paste(FEAT, collapse = " + ")))
em[, y := log1p(ind_now)]
fit_t <- function(train) {
  X <- stats::model.matrix(FORM, data = train); yv <- train$y; k <- ncol(X)
  nll <- function(par) {
    b <- par[1:k]; g <- par[(k + 1):(2 * k)]; nu <- exp(par[2 * k + 1]) + 2.01
    mu <- as.vector(X %*% b); sg <- exp(pmin(as.vector(X %*% g), 5))
    if (any(!is.finite(sg)) || any(sg <= 0)) return(1e10)
    -sum(stats::dt((yv - mu) / sg, df = nu, log = TRUE) - log(sg))
  }
  st <- c(stats::coef(stats::lm(FORM, data = train)), rep(0, k), log(5))
  st[is.na(st)] <- 0
  o <- stats::optim(st, nll, method = "BFGS", control = list(maxit = 2000, reltol = 1e-10))
  list(b = o$par[1:k], g = o$par[(k + 1):(2 * k)], nu = exp(o$par[2 * k + 1]) + 2.01)
}
fit2 <- fit_t(em)
cat(sprintf("\nTM4  route 2 fitted on %d non-sitting seats\n", nrow(em)))
print(data.table(term = colnames(stats::model.matrix(FORM, data = em)),
                 location = round(fit2$b, 4), log_spread = round(fit2$g, 4)))
cat(sprintf("TM4  estimated degrees of freedom %.1f\n", fit2$nu))

saveRDS(list(cut = SITTING_CUT, recontest = recontest, route1 = fit1,
             route2 = fit2, form = FORM),
        "output/independent-two-mechanism-fit.rds")
cat("\nTM5  wrote output/independent-two-mechanism-fit.rds\n")
