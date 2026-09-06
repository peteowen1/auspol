# Score stage 1 of docs/plans/prereg-class-specific-variance.md.
#
# WRITTEN BEFORE THE ARMS WERE READ. The grid finished while this was being
# written and no output file had been opened. That ordering is the point: a
# scorer written after seeing the numbers grows a branch that favours them, and
# nothing in the result would show it.
#
# compare_arms.R does two files. This pools five harnesses, computes the PAIRED
# per-seat differences the pre-registration asks for, and applies the one-way
# ratchet on the standard error.
#
# Emits CX* codes.

options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

MAJ <- c("ALP", "LNP", "NAT")
GRID <- strsplit(Sys.getenv("AUSPOL_CV_GRID", "1,1.25,1.5,1.75,2"), ",")[[1]]

# The pre-registered bars. Hard-coded from the committed document rather than
# recomputed here, so a change to either has to be a visible edit to a file
# under version control.
# v2 (docs/plans/prereg-class-specific-variance-v2.md) splits the one bar that
# was doing two jobs. AUSPOL_CV_V2=1 selects it. v1 set an ABSOLUTE bar from
# the level_sd experiment's paired sd -- a property of THE CHANGE tested, not
# of the metric -- so it imported the wrong reference class and came out ~10x
# too high. A t-threshold cannot be mis-sized in advance; a materiality floor
# stops a t-threshold accepting an effect too small to be worth a parameter.
V2      <- identical(Sys.getenv("AUSPOL_CV_V2", "0"), "1")
T_BAR   <- 2.80   # v2 statistical: effect / its OWN se
MAT_BAR <- 0.25   # v2 materiality: ~15% of what A1 gave on this subset
BAR_PRIMARY   <- 1.171   # non-major wins, pooled n 87
BAR_CO_IND    <- 1.649   # IND wins, pooled n 55
GUARD_ALL     <- 0.096   # all seats, must not WORSEN by more than this
GUARD_MAJOR   <- 0.070   # major wins, must not WORSEN by more than this
SD_ASSUMED    <- 3.901   # federal paired sd the primary bar was sized on

ll1 <- function(p, w) {
  p <- pmin(pmax(p, 1e-9), 1 - 1e-9)
  -(w * log(p) + (1 - w) * log(1 - p))
}

# Find each harness/arm file by its arm fingerprint. CAL_TAG hashes every set
# AUSPOL_* variable, so the base and the arms differ in filename even though
# only the multiplier changed -- which is the mechanism working, and the reason
# this cannot just glob for a name pattern.
NEED <- c("seat", "actual", "pred", "pred_p")
newest <- function(pat) {
  fs <- list.files("output", pattern = pat, full.names = TRUE)
  fs <- fs[!grepl("totals|allprobs", fs)]
  if (!length(fs)) return(NA_character_)
  ok <- vapply(fs, function(f)
    all(NEED %in% names(fread(f, nrows = 1, showProgress = FALSE))), logical(1))
  fs <- fs[ok]
  if (!length(fs)) return(NA_character_)
  fs[which.max(file.info(fs)$mtime)]
}

# The five harnesses, and the file prefix each writes.
HARNESS <- c(fed = "backtest-fed-", nsw = "backtest-nsw2023-",
             vic = "backtest-vic-", sa = "backtest-sa-", wa = "backtest-wa-")

read_arm <- function(f, h) {
  d <- fread(f, showProgress = FALSE)
  if (!"pair" %in% names(d)) d[, pair := h]
  d[, won := as.integer(pred == actual)]
  d[, .(harness = h, key = paste(h, pair, seat, sep = "|"), actual,
        l = ll1(pred_p, won), p = pred_p)]
}

cat("\n=== CX: stage 1, class-specific variance ===\n")
cat("Scoring docs/plans/prereg-class-specific-variance.md\n\n")

# ---- locate every arm ------------------------------------------------------
# The run wrote five arms per harness in grid order, so the five newest files
# per harness ARE the grid. Ordered by mtime, oldest first, to match GRID.
files <- list()
for (h in names(HARNESS)) {
  fs <- list.files("output", pattern = paste0("^", HARNESS[[h]]), full.names = TRUE)
  fs <- fs[!grepl("totals|allprobs", fs)]
  ok <- vapply(fs, function(f)
    all(NEED %in% names(fread(f, nrows = 1, showProgress = FALSE))), logical(1))
  fs <- fs[ok]
  fs <- fs[order(file.info(fs)$mtime, decreasing = TRUE)][seq_len(min(5, length(fs)))]
  fs <- fs[order(file.info(fs)$mtime)]
  if (length(fs) != 5L) {
    stop("CX! ", h, ": found ", length(fs), " recent arm files, expected 5. ",
         "Refusing to score a partial grid -- a missing arm would silently ",
         "become a different comparison.")
  }
  files[[h]] <- fs
  cat(sprintf("CX1  %-4s %s\n", h, paste(basename(fs), collapse = "\n              ")))
}

# ---- assemble --------------------------------------------------------------
A <- list()
for (h in names(HARNESS)) {
  for (k in seq_along(GRID)) {
    d <- read_arm(files[[h]][k], h)
    d[, m := GRID[k]]
    A[[length(A) + 1L]] <- d
  }
}
D <- rbindlist(A)
base <- D[m == "1", .(key, harness, actual, l_base = l, p_base = p)]

cat(sprintf("\nCX2  %d seat-elections per arm, %d harnesses, %d arms\n",
            nrow(base), uniqueN(base$harness), length(GRID)))
nm_n <- base[!actual %in% MAJ, .N]
ind_n <- base[actual == "IND", .N]
cat(sprintf("CX2  %d non-major wins (bar sized at 87), %d IND wins (sized at 55)\n",
            nm_n, ind_n))
if (nm_n < 60L || ind_n < 40L) {
  cat("CX!  FEWER WINS THAN THE BAR WAS SIZED ON. The MDE is larger than the\n",
      "     pre-registered bar and the primary is weaker than advertised.\n")
}

# ---- score each arm --------------------------------------------------------
# eval() over a hard-coded local list of quote()d subset expressions, the same
# idiom compare_arms.R already uses. Nothing external reaches it: `sub` is
# defined three lines below and never built from a file, an argument or an
# environment variable, so there is no path for injected code.
sub <- list(
  primary  = quote(!actual %in% MAJ),
  co_ind   = quote(actual == "IND"),
  other_nm = quote(!actual %in% c(MAJ, "IND")),
  majors   = quote(actual %in% MAJ),
  all      = quote(rep(TRUE, .N)))

res <- rbindlist(lapply(setdiff(GRID, "1"), function(mm) {
  arm <- D[m == mm, .(key, l_arm = l)]
  M <- merge(base, arm, by = "key")
  if (nrow(M) != nrow(base)) {
    stop("CX! arm ", mm, " matched ", nrow(M), " of ", nrow(base),
         " seats. A partial match silently changes which seats are compared.")
  }
  M[, d := l_arm - l_base]
  rbindlist(lapply(names(sub), function(s) {
    x <- M[eval(sub[[s]], M)]$d
    data.table(m = mm, subset = s, n = length(x), mean = mean(x), sd = sd(x),
               se = sd(x) / sqrt(length(x)),
               p = if (length(x) > 2) stats::t.test(x)$p.value else NA_real_)
  }))
}))

cat("\nCX3  PAIRED CHANGE IN LOG LOSS vs m_IND = 1 (negative is better)\n\n")
for (s in names(sub)) {
  cat(sprintf("  %s\n", toupper(s)))
  r <- res[subset == s]
  for (i in seq_len(nrow(r))) {
    cat(sprintf("    m_IND %-5s n %4d   mean %+8.4f   sd %7.4f   p %.4f\n",
                r$m[i], r$n[i], r$mean[i], r$sd[i], r$p[i]))
  }
  cat("\n")
}

# ---- the one-way ratchet ---------------------------------------------------
# "If the observed pooled paired-difference sd comes in ABOVE 3.901, the bar is
# recomputed UPWARD at scoring time. If it comes in below, the bar STAYS."
# A surprise that makes the test easier is not allowed to.
obs_sd <- res[subset == "primary", max(sd)]
bar <- BAR_PRIMARY
if (obs_sd > SD_ASSUMED) {
  bar <- 2.80 * obs_sd / sqrt(nm_n)
  cat(sprintf("CX4  RATCHET FIRES: observed primary sd %.3f > assumed %.3f.\n",
              obs_sd, SD_ASSUMED))
  cat(sprintf("CX4  Bar raised %.3f -> %.3f.\n", BAR_PRIMARY, bar))
} else {
  cat(sprintf("CX4  Ratchet does not fire: observed primary sd %.3f <= assumed %.3f.\n",
              obs_sd, SD_ASSUMED))
  cat(sprintf("CX4  Bar STAYS at %.3f -- a lower sd does not make the test easier.\n",
              BAR_PRIMARY))
}

# ---- verdict ---------------------------------------------------------------
cat("\nCX5  VERDICT, per arm. ALL FOUR must hold.\n\n")
ok_any <- FALSE
for (mm in setdiff(GRID, "1")) {
  g <- function(s) res[m == mm & subset == s]
  tstat <- function(s) abs(g(s)$mean) / g(s)$se
  c1 <- if (V2) (g("primary")$mean < 0 && tstat("primary") >= T_BAR &&
                 abs(g("primary")$mean) >= MAT_BAR) else g("primary")$mean <= -bar
  c2 <- if (V2) (g("co_ind")$mean < 0 && tstat("co_ind") >= T_BAR &&
                 abs(g("co_ind")$mean) >= MAT_BAR) else g("co_ind")$mean <= -BAR_CO_IND
  c3 <- g("all")$mean     <=  GUARD_ALL
  c4 <- g("majors")$mean  <=  GUARD_MAJOR
  pass <- c1 && c2 && c3 && c4
  ok_any <- ok_any || pass
  cat(sprintf("  m_IND = %-5s %s\n", mm, if (pass) "** PASSES **" else "fails"))
  if (V2) {
    for (.s in c("primary", "co_ind")) {
      .t <- abs(g(.s)$mean) / g(.s)$se; .e <- abs(g(.s)$mean)
      # Printed as two SEPARATE verdicts -- v1 printed one combined
      # pass/FAIL for the whole compound condition, which read as if
      # materiality had failed when only significance had (or vice
      # versa). Both bars must pass, but which one did not is the
      # useful part of the message.
      cat(sprintf("     %-8s %+8.4f  t %5.2f (>= %.2f) %s  |eff| %.4f (>= %.2f) %s
",
                  .s, g(.s)$mean, .t, T_BAR, if (.t >= T_BAR) "pass" else "FAIL",
                  .e, MAT_BAR, if (.e >= MAT_BAR) "pass" else "FAIL"))
    }
  } else {
  cat(sprintf("     primary  %+8.4f  vs bar <= %+.4f   %s\n",
              g("primary")$mean, -bar, if (c1) "pass" else "FAIL"))
  cat(sprintf("     co-IND   %+8.4f  vs bar <= %+.4f   %s\n",
              g("co_ind")$mean, -BAR_CO_IND, if (c2) "pass" else "FAIL"))
  }
  cat(sprintf("     all-seat %+8.4f  vs guard <= %+.4f  %s\n",
              g("all")$mean, GUARD_ALL, if (c3) "pass" else "FAIL"))
  cat(sprintf("     majors   %+8.4f  vs guard <= %+.4f  %s\n",
              g("majors")$mean, GUARD_MAJOR, if (c4) "pass" else "FAIL"))
}

# ---- refusal checks that need no verdict -----------------------------------
cat("\nCX6  REFUSAL CHECKS\n")
edge <- res[subset == "primary"][which.min(mean)]$m
cat(sprintf("  best arm on the primary is m_IND = %s%s\n", edge,
            if (identical(edge, "2")) "  -- AT THE GRID EDGE: the grid was drawn too narrow, so the result is a DIRECTION, not a value. Re-register wider rather than shipping the edge." else ""))

cat("\n  per-harness primary, to catch a gain sitting in one harness:\n")
for (mm in setdiff(GRID, "1")) {
  arm <- D[m == mm, .(key, l_arm = l)]
  M <- merge(base, arm, by = "key")[, d := l_arm - l_base]
  ph <- M[!actual %in% MAJ, .(n = .N, mean = round(mean(d), 3)), by = harness][order(harness)]
  cat(sprintf("    m_IND %-5s %s\n", mm,
              paste(sprintf("%s %+.3f (n%d)", ph$harness, ph$mean, ph$n), collapse = "  ")))
}

cat("\n  leave-one-election-out on the co-primary, per the refusal clause:\n")
for (mm in setdiff(GRID, "1")) {
  arm <- D[m == mm, .(key, l_arm = l)]
  M <- merge(base, arm, by = "key")[, d := l_arm - l_base]
  I <- M[actual == "IND"]
  I[, el := sub("^([^|]*\\|[^|]*).*$", "\\1", key)]
  loo <- vapply(unique(I$el), function(e) mean(I[el != e]$d), numeric(1))
  cat(sprintf("    m_IND %-5s worst LOO %+.4f vs bar %+.4f  %s\n", mm,
              max(loo), -BAR_CO_IND,
              if (max(loo) <= -BAR_CO_IND) "robust" else "FRAGILE: one election carries it"))
}

cat(sprintf("\nCX7  %s\n", if (ok_any)
  "At least one arm passes every criterion. Stage 2 may run." else
  "NO ARM PASSES. Stage 2 does not run, per the pre-registration."))
