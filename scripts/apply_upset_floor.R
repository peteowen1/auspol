# Stage 6b: upset insurance (AUSPOL_UPSET_FLOOR, R/upset_floor.R).
#
# For each backtest pair scored by THIS rebuild's stage 6, fit eps on the EARLIER
# pairs' raw probabilities (time-forward: only elections whose polling day
# precedes the target), mix the pair's win probabilities, and rewrite its
# allprobs and win files in place, so every scorer downstream (pool_backtests.R,
# build_forecasts_table.R, the AEF-7 ledger) reads the same mixed numbers.
# Also fits the live eps on all pairs (every one precedes Victoria 2026) and
# writes output/upset-floor-eps.csv, which fit_seats_full.R and the daily run read.
#
# IDEMPOTENT: the raw files are copied to output/upset-floor-raw/ the first time
# and always read from there, so running twice never mixes twice.
# Files are this run's: allprobs and win files (no -n2000- tag) written at or
# after AUSPOL_STAGE6_START (epoch seconds; set by rebuild_forecasts.sh).
#
# Emits UF* codes. Run by scripts/rebuild_forecasts.sh after stage 6.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
source("scripts/published_flags.R"); apply_published_flags()

OUT <- "output"; RAW <- file.path(OUT, "upset-floor-raw"); dir.create(RAW, showWarnings = FALSE)
since <- as.numeric(Sys.getenv("AUSPOL_STAGE6_START", "0"))
# Without a stage-6 start time every historic allprobs file in output/ would
# match, and all of them would be rewritten and counted in the fit (review).
if (!is.finite(since) || since <= 0) stop("UF0! AUSPOL_STAGE6_START is not set -- run via rebuild_forecasts.sh, or set it to this run's stage-6 start (epoch seconds)")
ap <- list.files(OUT, pattern = "^backtest-.*-allprobs-.*[.]csv$", full.names = TRUE)
ap <- ap[!grepl("-n2000-", ap) & as.numeric(file.mtime(ap)) >= since]
if (!length(ap)) stop("UF0! no stage-6 allprobs files at or after AUSPOL_STAGE6_START -- nothing to mix")
raw_of <- function(f) { r <- file.path(RAW, basename(f)); if (!file.exists(r)) file.copy(f, r, copy.date = TRUE); r }

# every pair's raw probabilities and predicted shares
D <- rbindlist(lapply(ap, function(f) {
  a <- fread(raw_of(f), showProgress = FALSE)
  sd <- sub("-allprobs-", "-sharedetail-", f)
  if (!file.exists(sd)) stop("UF0! no sharedetail beside ", basename(f))
  s <- fread(sd, showProgress = FALSE)
  if (!"pair" %in% names(a)) {
    if (data.table::uniqueN(s$pair) != 1L) stop("UF0! ", basename(f), ": no pair column and a multi-pair sharedetail")
    a[, pair := s$pair[1]]
  }
  a[, file := f]
  a
}), fill = TRUE)
S <- rbindlist(lapply(ap, function(f) {
  s <- fread(sub("-allprobs-", "-sharedetail-", f), showProgress = FALSE)
  s[, .(pair, seat, party, share = pred_share)]
}))
S <- unique(S, by = c("pair", "seat", "party"))
cat(sprintf("UF1  %d stage-6 files, %d pairs, %d seat-elections\n", length(ap), uniqueN(D$pair), uniqueN(D[, .(pair, seat)])))

# per seat: the actual winner's raw probability and floor weight
W <- upset_floor_weights(S[, .(seat = paste(pair, seat, sep = "|"), party, share)])
act <- unique(D[, .(pair, seat, actual)])
pa <- D[party == actual, .(prob = sum(prob)), by = .(pair, seat)]
act <- merge(act, pa, by = c("pair", "seat"), all.x = TRUE)[is.na(prob), prob := 0]
act[, key := paste(pair, seat, sep = "|")]
act <- merge(act, W[, .(key = seat, actual = party, w)], by = c("key", "actual"), all.x = TRUE)[is.na(w), w := 0]
act[, has_floor := key %in% W$seat]

dates <- election_dates()
pd <- dates[unique(act$pair)]
if (anyNA(pd)) stop("UF0! no election date for: ", paste(unique(act$pair)[is.na(pd)], collapse = ", "))
eps_tab <- rbindlist(lapply(c(unique(act$pair), "vic2026"), function(tg) {
  tgd <- if (tg == "vic2026") dates[["vic2026"]] else dates[[tg]]
  ear <- names(pd)[pd < tgd]
  e <- if (length(ear) >= 2L) with(act[pair %in% ear], upset_floor_fit(prob, w, has_floor)) else 0
  data.table(pair = tg, eps = e, n_earlier_pairs = length(ear), n_seats = nrow(act[pair %in% ear]))
}))
fwrite(eps_tab, file.path(OUT, "upset-floor-eps.csv"))
print(eps_tab[order(dates[pair])])

# mix and rewrite, per file
for (f in ap) {
  a <- fread(raw_of(f), showProgress = FALSE)
  had_pair <- "pair" %in% names(a)
  if (!had_pair) a[, pair := D[file == f, pair][1]]
  out <- rbindlist(lapply(split(a, by = "pair"), function(x) {
    tg <- x$pair[1]; e <- eps_tab[pair == tg, eps]
    sh <- S[pair == tg, .(seat, party, share)]
    m <- upset_floor_mix(x[, .(seat, party, prob)], sh, e)
    m <- merge(m, unique(x[, .(seat, actual)]), by = "seat")
    m[, is_actual := party == actual][, pair := tg]
    m
  }))
  setcolorder(out, c("seat", "party", "prob", "actual", "is_actual", "pair"))
  if (!had_pair) out[, pair := NULL]
  fwrite(out, f)
  # the win file beside it: prob of the actual winner, argmax and its prob
  wf <- sub("-allprobs-", "-", f)
  if (file.exists(wf)) {
    w0 <- fread(raw_of(wf), showProgress = FALSE)
    # NSW's win files call the actual winner's probability `p`, not `prob`
    pcol <- if ("prob" %in% names(w0)) "prob" else if ("p" %in% names(w0)) "p" else stop("UF0! ", basename(wf), ": no prob/p column")
    if (pcol == "p") data.table::setnames(w0, "p", "prob")
    # the real election for single-pair files (their allprobs has no pair column
    # but the win file may: SA's does -- a placeholder here zeroed every SA seat)
    o2 <- copy(out); if (!"pair" %in% names(o2)) o2[, pair := D[file == f, pair][1]]
    best <- o2[order(-prob)][, .SD[1], by = .(pair, seat)][, .(pair, seat, pred = party, pred_p = prob)]
    pact <- o2[is_actual == TRUE, .(prob = sum(prob)), by = .(pair, seat)]
    if (!"pair" %in% names(w0)) { best[, pair := NULL]; pact[, pair := NULL]; by <- "seat" } else by <- c("pair", "seat")
    w1 <- merge(merge(w0[, setdiff(names(w0), c("prob", "pred", "pred_p")), with = FALSE], pact, by = by, all.x = TRUE), best, by = by, all.x = TRUE)
    w1[is.na(prob), prob := 0]
    setcolorder(w1, intersect(names(w0), names(w1)))
    if (pcol == "p") data.table::setnames(w1, "prob", "p")
    fwrite(w1, wf)
  }
}
cat(sprintf("UF9  mixed %d file(s); eps by pair in output/upset-floor-eps.csv (live vic2026 eps %.4f)\n",
            length(ap), eps_tab[pair == "vic2026", eps]))
