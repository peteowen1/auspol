# Dry run (no harness): the seat-swing port's fitted coefficient per target
# under every combination of the two 2026-10-05 switches.
#
#   today      AUSPOL_SEAT_SWING_PORT_WA=0, NOCLIFF=0   (what ships)
#   +WA pool   AUSPOL_SEAT_SWING_PORT_WA=1              (WA cycles join every fit)
#   WA own     AUSPOL_SEAT_SWING_PORT_WA=2              (WA cycles join WA fits only)
#   no cliff   NOCLIFF=1                                (1-2 cycle fits are shrunk, not zeroed)
#   both       WA=1 and NOCLIFF=1
#
# Prints coef (after shrinkage), unshrunk b, se, shrink weight, earlier cycles
# k and seats n. Read-only: reads the main checkout's output/ and external/ via
# AUSPOL_DATA_ROOT, and the WA table from AUSPOL_SEAT_SWING_WA_FILE.
# Run: AUSPOL_DATA_ROOT=C:/dev/auspol AUSPOL_SEAT_SWING_WA_FILE=<fed-swing-transposed-wa.csv> \
#      powershell.exe -Command 'Rscript scripts/dry_run_seat_swing_port_wa.R'
suppressMessages(devtools::load_all(quiet = TRUE))
options(auspol.root = normalizePath(Sys.getenv("AUSPOL_DATA_ROOT", ".")))
suppressMessages(library(data.table))
targets <- c("vic2018", "vic2022", "vic2026", "nsw2019", "nsw2023", "qld2020", "qld2024",
             "sa2018", "sa2022", "sa2026", "wa2008", "wa2013", "wa2017", "wa2021", "wa2025")
arms <- list(
  list(nm = "today",    wa = "0", nc = "0"),
  list(nm = "+WA pool", wa = "1", nc = "0"),
  list(nm = "WA own",   wa = "2", nc = "0"),
  list(nm = "no cliff", wa = "0", nc = "1"),
  list(nm = "both",     wa = "1", nc = "1"),
  list(nm = "mode3",    wa = "3", nc = "0"),
  list(nm = "mode3+nc", wa = "3", nc = "1"))
res <- rbindlist(lapply(arms, function(a) {
  Sys.setenv(AUSPOL_SEAT_SWING_PORT_WA = a$wa, AUSPOL_SEAT_SWING_PORT_NOCLIFF = a$nc)
  rbindlist(lapply(targets, function(tg) {
    cf <- seat_swing_port_coef(tg)
    data.table(arm = a$nm, target = tg, k = cf$k, n = cf$n, b = cf$b, se = cf$se, coef = cf$coef,
               b_own = if (is.null(cf$b_own)) NA_real_ else cf$b_own, mu = if (is.null(cf$mu)) NA_real_ else cf$mu,
               tau2 = if (is.null(cf$tau2)) NA_real_ else cf$tau2, w = if (is.null(cf$w)) NA_real_ else cf$w,
               weight = if (is.finite(cf$b) && cf$b != 0) cf$coef / cf$b else NA_real_)
  }))
}))
Sys.setenv(AUSPOL_SEAT_SWING_PORT_WA = "0", AUSPOL_SEAT_SWING_PORT_NOCLIFF = "0")
res[, (c("b", "se", "coef", "weight", "b_own", "mu", "tau2", "w")) := lapply(.SD, round, 3), .SDcols = c("b", "se", "coef", "weight", "b_own", "mu", "tau2", "w")]
for (a in arms) {
  cat(sprintf("\n== %s (WA=%s NOCLIFF=%s): coef = shrunk coefficient applied; b = unshrunk; weight = coef/b ==\n", a$nm, a$wa, a$nc))
  print(res[arm == a$nm, if (a$wa == "3") .(target, k, n, b_own, mu, tau2, w, b, se, coef) else .(target, k, n, b, se, coef, weight)], row.names = FALSE)
}
wide <- dcast(res, target ~ arm, value.var = "coef")[match(targets, target)]
cat("\n== coefficient applied, by arm (0 = port does nothing) ==\n")
print(wide[, c("target", vapply(arms, `[[`, "", "nm")), with = FALSE], row.names = FALSE)
