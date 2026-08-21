# Does seat type add anything to fed_swing, on 441 seats rather than 180?
#
# Against docs/plans/prereg-seat-type-441.md, committed before this ran. The
# decision rule and refusals R1-R5 are there and are NOT restated.
#
# The one thing that shapes the code: the independent observation is the
# ELECTION, not the seat. Every seat is scored against its own cycle's statewide
# swing, so seat errors within a cycle are not independent and n = 5. Every
# standard error here is clustered on the election.
#
# Emits ST* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

P <- election_data_path()
fs <- fread(file.path(P, "fed-swing-transposed.csv"), showProgress = FALSE)

TYPE_LABEL <- c("0" = "inner-metro", "1" = "outer-metro",
                "2" = "provincial", "3" = "rural")
st <- fread(file.path("external", "aus-polling-analyser", "analysis", "Data",
                      "seat-types.csv"), header = FALSE, showProgress = FALSE,
            col.names = c("seat", "region", "type_code"))
st[, stype := factor(TYPE_LABEL[as.character(type_code)],
                     levels = unname(TYPE_LABEL))]
if (anyNA(st$stype)) {
  stop("seat-types.csv holds a type code outside 0-3: ",
       paste(unique(st[is.na(stype), type_code]), collapse = ", "))
}

# (state cycle being predicted, region, the seat file holding its actual swing)
CYCLES <- list(list(2018L, "vic", 2022L), list(2019L, "nsw", 2023L),
               list(2020L, "qld", 2024L), list(2022L, "vic", 2026L),
               list(2023L, "nsw", 2027L))

d <- rbindlist(lapply(CYCLES, function(k) {
  yr <- k[[1]]; rg <- k[[2]]; nxt <- k[[3]]
  after <- as.data.table(load_seats(nxt, rg))[, .(seat, actual = prev_swing)]
  tra <- fs[region == rg & cycle == yr, .(seat, fed = fed_swing)]
  m <- merge(after[is.finite(actual)], tra, by = "seat")
  m[, `:=`(election = sprintf("%s%d", rg, yr), region = rg)][]
}))
d <- merge(d, st[, .(seat, region, stype)], by = c("seat", "region"))
# Centred WITHIN election, because the question is deviation from the statewide
# swing and every cycle has its own.
d[, `:=`(dev = actual - mean(actual), fed_c = fed - mean(fed)), by = election]

cat(sprintf("\nST1  %d seats across %d elections\n", nrow(d), uniqueN(d$election)))
print(d[, .(seats = .N, baseline_mae = round(mean(abs(dev)), 3)), by = election])
cat("\nST1  seat type on its own, pooled across all five elections\n")
print(d[, .(seats = .N, mean_dev = round(mean(dev), 2),
            sd = round(stats::sd(dev), 2)), by = stype][order(stype)])

# ---- leave-one-election-out over the three arms -----------------------------
ARMS <- c(A = "dev ~ fed_c", B = "dev ~ fed_c + stype", C = "dev ~ stype")
per_seat <- rbindlist(lapply(unique(d$election), function(e) {
  tr <- d[election != e]; te <- d[election == e]
  out <- data.table(election = e, seat = te$seat, dev = te$dev,
                    uniform = abs(te$dev))
  for (nm in names(ARMS)) {
    f <- stats::lm(stats::as.formula(ARMS[[nm]]), data = tr)
    set(out, j = nm, value = abs(te$dev - stats::predict(f, newdata = te)))
  }
  out[]
}))

by_el <- per_seat[, lapply(.SD, mean), by = election,
                  .SDcols = c("uniform", names(ARMS))]
cat("\nST2  leave-one-election-out MAE\n")
print(by_el[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 4) else x)])
pooled <- per_seat[, lapply(.SD, mean), .SDcols = c("uniform", names(ARMS))]
cat(sprintf("ST2  pooled: uniform %.4f | A %.4f | B %.4f | C %.4f\n",
            pooled$uniform, pooled$A, pooled$B, pooled$C))

# ---- the comparison, clustered on the election ------------------------------
# The paired per-seat difference is averaged WITHIN each election first, and the
# standard error taken across those five numbers. Taking it across 441 seats
# would understate it by treating one cycle's seats as independent draws.
diffs <- by_el$B - by_el$A
se <- stats::sd(diffs) / sqrt(length(diffs))
z <- mean(diffs) / se
cat(sprintf("\nST3  B minus A per election: %s\n",
            paste(sprintf("%+.4f", diffs), collapse = ", ")))
cat(sprintf("ST3  mean %+.4f, clustered SE %.4f -> %+.2f SE (negative = B better)\n",
            mean(diffs), se, z))
cat(sprintf("ST3  the 2 SE bar set in advance was 0.28 MAE; this run's own bar is %.4f\n",
            2 * se))

# ---- R1: does the result rest on one election? ------------------------------
cat("\nST4  R1 -- drop each election in turn and re-read the gain\n")
r1 <- rbindlist(lapply(seq_along(diffs), function(i) {
  dd <- diffs[-i]
  data.table(dropped = by_el$election[i], mean = mean(dd),
             se = stats::sd(dd) / sqrt(length(dd)))
}))
r1[, z := mean / se]
print(r1[, .(dropped, mean = round(mean, 4), se = round(se, 4), z = round(z, 2))])

# ---- R2: do the seat-type coefficients hold their sign? ---------------------
cat("\nST5  R2 -- seat-type coefficients per held-out fold (arm B)\n")
co <- rbindlist(lapply(unique(d$election), function(e) {
  f <- stats::lm(dev ~ fed_c + stype, data = d[election != e])
  cf <- stats::coef(f)
  as.data.table(c(list(held_out = e), as.list(round(cf[grepl("^stype", names(cf))], 3))))
}))
print(co)
sign_stable <- all(vapply(co[, -1], function(x) all(x > 0) || all(x < 0), logical(1)))
cat(sprintf("ST5  every coefficient holds its sign across all five folds: %s\n",
            sign_stable))

# ---- R4: is a gain really the low-dispersion election doing the work? -------
cat("\nST6  R4 -- gain against each election's own baseline dispersion\n")
print(data.table(election = by_el$election,
                 baseline = round(by_el$uniform, 3),
                 gain_B_over_A = round(-diffs, 4))[order(baseline)])

# ---- R5: can this even be applied to Victoria 2026? ------------------------
v26 <- as.data.table(load_seats(2026L, "vic"))[, .(seat)]
v26 <- merge(v26, st[region == "vic", .(seat, stype)], by = "seat", all.x = TRUE)
missing <- v26[is.na(stype), seat]
cat(sprintf("\nST7  R5 -- Victoria 2026: %d of %d seats have a type%s\n",
            sum(!is.na(v26$stype)), nrow(v26),
            if (length(missing)) sprintf(", MISSING: %s",
                                         paste(missing, collapse = ", ")) else ""))

# ---- verdict ----------------------------------------------------------------
adopt <- z < -2 && all(r1$z < -2) && sign_stable && length(missing) == 0L
cat(sprintf("\nST8  verdict: %s\n", if (adopt) {
  "ADOPT B -- clears 2 SE, survives dropping any election, signs stable, 2026 covered"
} else if (z < -2 && length(missing) > 0L) {
  "REFUSED on R5 -- clears the bar but cannot be applied to Victoria 2026"
} else if (z < -2 && !all(r1$z < -2)) {
  "REFUSED on R1 -- the gain rests on a single election"
} else if (z < -2 && !sign_stable) {
  "REFUSED on R2 -- a seat-type coefficient changes sign across folds"
} else {
  sprintf("KEEP A -- B is %+.2f SE, short of the -2 SE bar. This rules out an effect larger than %.0f%% of baseline error and says NOTHING about a smaller one.",
          z, 100 * 2 * se / pooled$uniform)
}))
fwrite(by_el, file.path("output", "seat-type-441.csv"))
