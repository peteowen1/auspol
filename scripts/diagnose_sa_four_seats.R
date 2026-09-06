options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
P <- election_data_path()

fa <- fread(file.path(P, "ecsa-2022-sa-firstprefs.csv"), showProgress = FALSE)
fb <- fread(file.path(P, "ecsa-2026-sa-firstprefs.csv"), showProgress = FALSE)
pc <- function(d){ d[, tot := sum(votes), by = seat]; d[, p := 100*votes/tot]; d }
fa <- pc(fa); fb <- pc(fb)
wa <- dcast(fa, seat ~ party, value.var = "p", fill = 0)
wb <- dcast(fb, seat ~ party, value.var = "p", fill = 0)
setnames(wa, "Frome", "Ngadjuri", skip_absent = TRUE)
wa[seat == "Frome", seat := "Ngadjuri"]

st_a <- fa[, .(v=sum(votes)), by=party][, setNames(100*v/sum(v), party)]
st_b <- fb[, .(v=sum(votes)), by=party][, setNames(100*v/sum(v), party)]

cat("=== SA statewide swing the model applies (uniform, in points) ===\n")
for (p in c("ALP","LNP","ONP","GRN")) {
  a <- if (p %in% names(st_a)) st_a[[p]] else 0
  b <- if (p %in% names(st_b)) st_b[[p]] else 0
  cat(sprintf("  %-4s %5.2f -> %5.2f   swing %+6.2f\n", p, a, b, b-a))
}

TGT <- c("MacKillop","Narungga","Ngadjuri","Hammond")
cat("\n=== the four seats: MODEL vs ACTUAL, per party ===\n")
for (s in TGT) {
  ra <- wa[seat == s]; rb <- wb[seat == s]
  if (!nrow(ra) || !nrow(rb)) { cat(sprintf("\n%s: missing\n", s)); next }
  cat(sprintf("\n--- %s ---\n", s))
  cat("  party  2022   model(2022+swing)   ACTUAL   model error\n")
  for (p in c("ALP","LNP","ONP","GRN")) {
    a22 <- if (p %in% names(ra)) ra[[p]] else 0
    act <- if (p %in% names(rb)) rb[[p]] else 0
    sw  <- (if (p %in% names(st_b)) st_b[[p]] else 0) - (if (p %in% names(st_a)) st_a[[p]] else 0)
    mod <- max(0, a22 + sw)
    cat(sprintf("  %-4s  %5.1f       %6.1f          %5.1f     %+6.1f\n",
                p, a22, mod, act, mod - act))
  }
}

cat("\n=== the per-seat uncertainty the model uses ===\n")
sp <- tryCatch(seat_swing_spread(as.data.table(load_seats(2026, "sa")),
                                 unname(st_b[["ALP"]]-st_a[["ALP"]])), error=function(e) NULL)
if (!is.null(sp)) {
  cat(sprintf("  seat_swing_spread sd_within = %.3f points\n", sp$sd_within))
} else {
  cat("  (no SA seat file; the harness falls back -- checking the backtest output)\n")
}

cat("\n=== how many SDs away was the truth? ===\n")
sd_used <- if (!is.null(sp)) sp$sd_within else 3.5
cat(sprintf("  using seat_sd = %.2f\n\n", sd_used))
for (s in TGT) {
  ra <- wa[seat == s]; rb <- wb[seat == s]
  if (!nrow(ra) || !nrow(rb)) next
  lnp22 <- if ("LNP" %in% names(ra)) ra[["LNP"]] else 0
  swl <- st_b[["LNP"]] - st_a[["LNP"]]
  modl <- max(0, lnp22 + swl)
  actl <- if ("LNP" %in% names(rb)) rb[["LNP"]] else 0
  cat(sprintf("  %-10s LNP model %5.1f vs actual %5.1f  -> %+5.2f SD\n",
              s, modl, actl, (actl - modl)/sd_used))
}
