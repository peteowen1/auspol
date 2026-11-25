# FORMER-LEADER CORRECTION, PRIMARY-VOTE ERROR FIRST (Pete, 25 Nov 2026: "surely if there's a bias here
# we can find a version that improves primary RMSE, even if it can't improve log loss?").
# Pre-registration: docs/plans/prereg-leader-former-rmse-2026-11-25.md (rounds, keep rule, metrics, split).
#
#   Rscript scripts/former_leader_variants.R --noise-only      # baseline residuals only: the noise floor
#   Rscript scripts/former_leader_variants.R                   # the rounds on TRAIN (elections before 2024)
#   Rscript scripts/former_leader_variants.R --heldout=NAME    # score one variant on 2024-2026, once
#   flags: --cache=DIR (default the newest seat_quick cache), --no-ll (skip the log-loss re-simulation),
#          --sims=N (default 20000)
#
# Works on the seat_quick cache (scripts/seat_quick.R): each election's FINAL shares as the simulator
# received them, the actual result (sharedetail.csv) and the winners (allprobs.csv). Every size is fitted
# time-forward: for a target election only former-leader seats of elections before it. A tweak acts on
# the final shares; the cut is not passed through the seat-poll blend (seat_quick.R --passthrough measured
# that at 58% in two federal seats and 95-100% elsewhere; the score here is of the cut as applied).
t0 <- Sys.time()
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
noise_only <- "--noise-only" %in% a
do_ll <- !("--no-ll" %in% a) && !noise_only
heldout_name <- flag("heldout", NA_character_)
sims <- as.integer(flag("sims", "20000"))
qd <- normalizePath(Sys.getenv("AUSPOL_QUICK_DIR", file.path(Sys.getenv("TEMP", tempdir()), "auspol-quickarm")), winslash = "/", mustWork = FALSE)
# the cache is chosen by its key, as scripts/seat_quick.R does: the current published-config baseline with
# every election (quick_check_seat_cache() in R/quick_arm.R stops naming what differs)
.src <- quick_source_dirs(normalizePath(".", winslash = "/"))
.ctx <- quick_key_context(normalizePath(".", winslash = "/"), .src$src_output, .src$src_external)
cache <- flag("cache", file.path(qd, "cache", quick_key(.ctx, as.integer(flag("cache-sims", "20000")), character(0), TRUE)))
ids <- quick_units()$id
.ck <- quick_check_seat_cache(cache, .ctx, ids)
root <- flag("root", file.path(qd, "slot1"))
if (!identical(readLines(file.path(root, "output", ".quick-sig"), warn = FALSE), .ctx$input)) stop(root, "/output is not a copy of today's inputs")
options(auspol.root = normalizePath(root, winslash = "/"))
cat(sprintf("FLV0k cache %s: published-config baseline, code %s, %s sims, %d elections\n", .ck$key, .ck$parts$code, .ck$sims, length(ids)))
yr <- function(p) as.integer(sub("^[a-z]+", "", p))
HELD <- ids[yr(ids) >= 2024]
cat(sprintf("FLV0 cache %s: %d elections; held out (scored once, at the end): %s\n", cache, length(ids), paste(HELD, collapse = " ")))

# ---- the cases -------------------------------------------------------------------------------
ST <- list(); SD <- list(); AP <- list()
for (id in ids) {
  ST[[id]] <- readRDS(file.path(cache, id, sprintf("state-%s.rds", id)))
  SD[[id]] <- fread(file.path(cache, id, "sharedetail.csv"), showProgress = FALSE)
  AP[[id]] <- fread(file.path(cache, id, "allprobs.csv"), showProgress = FALSE)
}
ls_all <- leader_seats()
cand <- fread(file.path(root, "output", "candidacies.csv"), select = c("election", "seat", "surname", "given"), showProgress = FALSE)
cand$ns <- normalise_seat(cand$seat); cand$sur <- toupper(trimws(cand$surname))
bw <- fread(file.path(pkg_root(), "external", "reference", "byelections", "byelection-winners.csv"), showProgress = FALSE)
bw$ns <- normalise_seat(bw$seat); bw$d <- as.Date(bw$date)
Lr <- read_leaders()
# polling day; an election election_dates() lacks (fed2001) falls back to 1 July of its year, as elections_before() does
ed <- function(p) as.Date(vapply(p, function(x) tryCatch(as.character(unname(election_dates(x))),
                                                         error = function(e) sprintf("%s-07-01", sub("^[a-z]+", "", x))), ""))
surname_of <- function(x) toupper(sub("^.* ", "", trimws(x)))
features <- function(fs, id) {   # contesting, by-election since, tenure: all known before polling day
  if (!nrow(fs)) return(fs)
  jur <- sub("[0-9]+$", "", id)
  fs$contest <- vapply(seq_len(nrow(fs)), function(r) {
    .e <- id; .s <- normalise_seat(fs$seat[r]); .n <- surname_of(fs$leader[r])
    any(cand$election == .e & cand$ns == .s & cand$sur == .n)
  }, NA)
  fs$byelec <- vapply(seq_len(nrow(fs)), function(r) {
    lo <- ed(fs$prev[r]); hi <- ed(id); .s <- normalise_seat(fs$seat[r])
    any(bw$region == jur & bw$ns == .s & bw$d > lo & bw$d < hi)
  }, NA)
  fs$tenure <- vapply(seq_len(nrow(fs)), function(r) {
    .l <- fs$leader[r]; e <- unique(Lr$election[Lr$leader_clean == .l & sub("[0-9]+$", "", Lr$election) == jur])
    sum(ed(e) <= ed(fs$prev[r]))
  }, 0)
  fs
}
FL <- rbindlist(lapply(ids, function(id) {
  fs <- former_leader_seats(id, ls_all)
  if (!nrow(fs)) return(NULL)
  sh <- as.matrix(ST[[id]]$args$shares)
  i <- match(normalise_seat(fs$seat), normalise_seat(rownames(sh))); j <- match(fs$party, colnames(sh))
  fs <- fs[!is.na(i) & !is.na(j)]; i <- i[!is.na(i) & !is.na(j)]
  if (!nrow(fs)) return(NULL)
  fs$seat <- rownames(sh)[i]
  sd <- SD[[id]]
  k <- match(paste(fs$seat, fs$party), paste(sd$seat, sd$party))
  fs$base <- sd$pred_share[k]; fs$actual <- sd$actual_share[k]
  # the class's median miss over every seat of this election (the election-wide part, removed from the fit target)
  med <- sd[, list(m = stats::median(actual_share - pred_share)), by = list(cls = party)]
  fs$med <- med$m[match(fs$party, med$cls)]
  fs$pair <- id
  features(fs, id)
}), fill = TRUE)
FL$r <- FL$actual - FL$base - FL$med
FL$held <- FL$pair %in% HELD
cat(sprintf("FLV1 %d former-leader seats in %d elections (train %d seats / %d elections, held out %d / %d); contesting %d, by-election since %d\n",
            nrow(FL), uniqueN(FL$pair), sum(!FL$held), uniqueN(FL$pair[!FL$held]), sum(FL$held), uniqueN(FL$pair[FL$held]),
            sum(FL$contest), sum(FL$byelec)))
print(FL[, list(pair, seat, party, role, contest, byelec, tenure, base = round(base, 2), actual = round(actual, 2), err = round(actual - base, 2), r = round(r, 2))], row.names = FALSE)

# ---- fitting helpers (shrinkage, never a cliff) ----------------------------------------------------
pool_groups <- function(r, g) {   # .role_pooled_bonus(), any grouping: groups toward the pooled mean, pooled mean toward 0
  if (length(r) < 3) return(list(mu = 0, by = stats::setNames(numeric(0), character(0))))
  mu_raw <- mean(r); mu_se <- stats::sd(r) / sqrt(length(r))
  mu <- mu_raw * mu_raw^2 / (mu_raw^2 + mu_se^2)
  gs <- unique(g)
  raw <- vapply(gs, function(x) mean(r[g == x]), 0)
  se <- vapply(gs, function(x) { v <- r[g == x]; if (length(v) > 1) stats::sd(v) / sqrt(length(v)) else NA_real_ }, 0)
  ok <- is.finite(se)
  tau2 <- if (sum(ok) >= 2) max(0, stats::var(raw[ok]) - mean(se[ok]^2)) else 0
  w <- ifelse(ok, tau2 / (tau2 + se^2), 0)
  list(mu = mu, by = stats::setNames(mu + w * (raw - mu), gs))
}
group_size <- function(col) function(tr, tg) {
  p <- pool_groups(tr$r, as.character(tr[[col]]))
  v <- p$by[as.character(tg[[col]])]; v[is.na(v)] <- p$mu; unname(v)
}
SIZES <- list(
  flat    = function(tr, tg) rep(pool_groups(tr$r, rep("all", nrow(tr)))$mu, nrow(tg)),
  role    = group_size("role"),
  contest = group_size("contest"),
  byelec  = group_size("byelec"),
  carries = function(tr, tg) {   # cut only where the base still carries the personal vote
    el <- !tr$contest & !tr$byelec
    mu <- pool_groups(tr$r[el], rep("all", sum(el)))$mu
    mu * (!tg$contest & !tg$byelec)
  },
  tenure  = function(tr, tg) {
    x <- tr$tenure; if (sum(x > 0) < 3) return(rep(0, nrow(tg)))
    b <- sum(x * tr$r) / sum(x^2); se <- sqrt(sum((tr$r - b * x)^2) / (length(x) - 1) / sum(x^2))
    (b * b^2 / (b^2 + se^2)) * tg$tenure
  })

# deltas per case, each target fitted on the seats of elections strictly before it
fit_deltas <- function(size) {
  d <- numeric(nrow(FL))
  for (tt in unique(FL$pair)) {
    tr <- FL[elections_before(FL$pair, tt)]; ix <- which(FL$pair == tt)
    d[ix] <- size(tr, FL[ix])
  }
  d
}
shift_row <- function(row, j, delta, dest) {
  if (dest == "prop") return(.shift_cell(row, j, delta))
  k <- setdiff(seq_along(row), j)[which.max(row[-j])]   # the runner-up in the baseline row
  give <- max(-row[j], min(delta, row[k]))                # cell floored at 0; the runner-up cannot go negative
  row[j] <- row[j] + give; row[k] <- row[k] - give
  row
}
# every cell of every moved seat, baseline and arm, for a set of deltas
cells_for <- function(delta, dest) {
  rbindlist(lapply(unique(FL$pair), function(tt) {
    ix <- which(FL$pair == tt & abs(delta) > 0); if (!length(ix)) return(NULL)
    sh <- as.matrix(ST[[tt]]$args$shares); arm <- sh
    for (q in ix) arm[FL$seat[q], ] <- shift_row(arm[FL$seat[q], ], match(FL$party[q], colnames(sh)), delta[q], dest)
    sd <- SD[[tt]][seat %in% FL$seat[ix]]
    inm <- sd$party %in% colnames(sh)
    sd$arm <- sd$pred_share
    sd$arm[inm] <- arm[cbind(match(sd$seat[inm], rownames(sh)), match(sd$party[inm], colnames(sh)))]
    sd$target <- paste(sd$seat, sd$party) %in% paste(FL$seat[ix], FL$party[ix])
    sd$pair <- tt
    attr(sd, "arm") <- NULL
    sd[, list(pair, seat, party, base = pred_share, arm, actual = actual_share, target)]
  }))
}
sse <- function(C, use) {   # summed squared error change, SE clustered on election, RMSE before/after
  C <- C[use]
  if (!nrow(C)) return(list(n = 0L, rmse_b = NA, rmse_a = NA, change = 0, se = NA))
  d <- (C$actual - C$arm)^2 - (C$actual - C$base)^2
  cl <- quick_clustered(d, C$pair)
  list(n = nrow(C), rmse_b = sqrt(mean((C$actual - C$base)^2)), rmse_a = sqrt(mean((C$actual - C$arm)^2)),
       change = sum(d), se = if (is.na(cl$se)) NA_real_ else cl$se * nrow(C), k = cl$clusters,
       bias_b = mean(C$actual - C$base), bias_a = mean(C$actual - C$arm))
}

# ---- noise floor (baseline residuals only) -------------------------------------------------------
tr0 <- FL[!FL$held]
e <- tr0$actual - tr0$base
cl_e <- quick_clustered(e, tr0$pair)
c_star <- mean(e)
se_dsse <- 2 * abs(c_star) * cl_e$se * nrow(tr0)   # SE of the SSE change of a constant cut of size c* (first-order)
cat(sprintf("\nFLV2 NOISE FLOOR (train, %d seats, %d elections): targeted RMSE %.2f points, mean error (actual minus predicted) %+.2f (SE %.2f, clustered on election).\n",
            nrow(tr0), uniqueN(tr0$pair), sqrt(mean(e^2)), c_star, cl_e$se))
cat(sprintf("     Best ANY constant cut can do on these seats (in-sample oracle, c = %+.2f): squared error %.0f -> %.0f (%.1f%%, RMSE %.2f -> %.2f).\n",
            c_star, sum(e^2), sum((e - c_star)^2), -100 * nrow(tr0) * c_star^2 / sum(e^2), sqrt(mean(e^2)), sqrt(mean((e - c_star)^2))))
cat(sprintf("     SE of that squared-error change, clustered on election: about %.0f; so an effect must exceed about %.0f (2 SE) to be shown, against at most %.0f available from a constant.\n",
            se_dsse, 2 * se_dsse, nrow(tr0) * c_star^2))
if (noise_only) quit(status = 0)

# ---- seat-winner log loss for a variant (seat_quick's method: one seat per call, one seed) ----------
p_base_cache <- list()
ll_for <- function(delta, dest) {
  out <- list()
  for (tt in unique(FL$pair)) {
    ix <- which(FL$pair == tt & abs(delta) > 0); if (!length(ix)) next
    st <- ST[[tt]]; sh <- as.matrix(st$args$shares); arm <- sh
    for (q in ix) arm[FL$seat[q], ] <- shift_row(arm[FL$seat[q], ], match(FL$party[q], colnames(sh)), delta[q], dest)
    act <- unique(AP[[tt]][, .(seat, actual)]); act <- stats::setNames(act$actual, act$seat)
    for (s in unique(FL$seat[ix])) {
      if (is.na(act[s])) next
      kb <- paste(tt, s)
      if (is.null(p_base_cache[[kb]])) p_base_cache[[kb]] <<- seat_state_winner_p(seat_state_resim(st, seats = s, n_sims = sims), act[s])
      pa <- seat_state_winner_p(seat_state_resim(st, shares = arm, seats = s, n_sims = sims), act[s])
      out[[kb]] <- data.frame(pair = tt, seat = s, p_base = unname(p_base_cache[[kb]]), p_arm = unname(pa))
    }
  }
  S <- do.call(rbind, out)
  ns <- vapply(ids, function(u) nrow(as.matrix(ST[[u]]$args$shares)), 0L)
  seat_state_ll(S, ns, eps = 0.5 / sims)
}

# ---- the rounds (train only) ---------------------------------------------------------------------
score <- function(name, size, dest, split = "train") {
  dl <- fit_deltas(SIZES[[size]])
  C <- cells_for(dl, dest)
  keep <- if (split == "train") !C$pair %in% HELD else C$pair %in% HELD
  t1 <- sse(C, keep & C$target); t2 <- sse(C, keep)
  ll <- NULL
  if (do_ll) { L <- ll_for(ifelse(if (split == "train") !FL$pair %in% HELD else FL$pair %in% HELD, dl, 0), dest); ll <- L }
  list(name = name, size = size, dest = dest, delta = dl, tgt = t1, all = t2, ll = ll,
       moved = sum(abs(dl[if (split == "train") !FL$held else FL$held]) > 0))
}
row_of <- function(s) data.table(variant = s$name, seats_moved = s$moved,
  tgt_n = s$tgt$n, tgt_rmse = sprintf("%.3f -> %.3f", s$tgt$rmse_b, s$tgt$rmse_a), tgt_sse_change = round(s$tgt$change, 1), tgt_se = round(s$tgt$se, 1),
  tgt_bias = sprintf("%+.2f -> %+.2f", s$tgt$bias_b, s$tgt$bias_a),
  all_n = s$all$n, all_rmse = sprintf("%.3f -> %.3f", s$all$rmse_b, s$all$rmse_a), all_sse_change = round(s$all$change, 1), all_se = round(s$all$se, 1),
  ll_touched = if (is.null(s$ll)) NA_real_ else round(s$ll$touched$mean, 4), ll_touched_se = if (is.null(s$ll)) NA_real_ else round(s$ll$touched$se, 4),
  ll_all = if (is.null(s$ll)) NA_real_ else round(s$ll$all$mean, 5), ll_all_se = if (is.null(s$ll)) NA_real_ else round(s$ll$all$se, 5))

if (!is.na(heldout_name)) {
  sp <- strsplit(heldout_name, "/")[[1]]   # size/dest, e.g. carries/runnerup
  s <- score(heldout_name, sp[1], sp[2], split = "held")
  cat("\nFLV9 HELD-OUT (2024-2026, scored once) for", heldout_name, ":\n"); print(row_of(s), row.names = FALSE)
  fwrite(row_of(s), file.path(Sys.getenv("TEMP"), "flv-heldout.csv"))
  # vic2026: the live election's former-leader seats with this rule, fitted on all 35 cached elections
  fs <- features(former_leader_seats("vic2026", ls_all), "vic2026")
  if (nrow(fs)) {
    d26 <- SIZES[[sp[1]]](FL, fs)
    cp <- current_seat_predictions(); cp <- cp[cp$election == "vic2026"]
    fs$tree_share <- cp$xgb_pred_seat[match(paste(normalise_seat(fs$seat), fs$party), paste(normalise_seat(cp$seat), cp$party))]
    fs$cut <- d26
    cat("\nFLV10 vic2026 with", heldout_name, "fitted on all 35 elections (cut in points of the former leader's party's primary; tree_share is the as-at tree prediction, before the seat-poll blend):\n")
    print(fs[, list(seat, party, leader, role, contest, byelec, tenure, tree_share = round(tree_share, 2), cut = round(cut, 2))], row.names = FALSE)
  }
  quit(status = 0)
}

R <- list()
champ <- list(size = "flat", dest = "prop")
s1 <- score("1 flat, proportional", "flat", "prop"); R[[1]] <- s1; best <- s1
better <- function(n, o) n$tgt$change < o$tgt$change && n$all$change < o$all$change
s2 <- score("2 flat, freed share to runner-up", "flat", "runnerup"); R[[2]] <- s2
if (better(s2, best)) { best <- s2; champ$dest <- "runnerup" }
for (sz in c("role", "contest", "byelec", "carries", "tenure")) {
  s <- score(sprintf("%d %s, %s", length(R) + 1L, sz, champ$dest), sz, champ$dest); R[[length(R) + 1L]] <- s
  if (better(s, best)) { best <- s; champ$size <- sz }
}
cat("\nFLV3 ROUNDS ON TRAIN (elections before 2024). tgt = the former leader's party's cell at its former-leader seats; all = every cell of the moved seats.\n")
cat("     RMSE in points (lower is better); sse_change = summed squared error, variant minus baseline (negative is better), SE clustered on election;\n")
cat("     bias = mean actual minus predicted (0 is unbiased); ll = seat-winner log-loss change vs baseline (lower is better) per touched seat and over all 2,931 seats (eps 0.5/sims).\n")
TB <- rbindlist(lapply(R, row_of)); print(TB, row.names = FALSE)
fwrite(TB, file.path(Sys.getenv("TEMP"), "flv-rounds.csv"))
# paired against the champion on the champion's cells, so "kept" has an SE
cat(sprintf("\nFLV4 champion on train: %s (size %s, freed share %s)\n", best$name, champ$size, champ$dest))
cat(sprintf("FLV9 runtime %.0f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
