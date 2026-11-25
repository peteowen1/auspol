# SEAT-LEVEL QUICK SCREEN: a post-tree seat tweak scored in about a minute instead of a
# 45-minute quick_arm run of every election (Pete, 25 Nov 2026).
#
#   1. Build the cache ONCE per code/input version (about 25 minutes, two processes):
#        Rscript scripts/quick_arm.R --base-only --dump --pairs=all --sims=20000
#      Every election's harness runs exactly as quick_arm runs it, and its final simulation's
#      exact inputs land in <quick dir>/cache/<key>/<pair>/state-<pair>.rds beside that run's
#      allprobs.csv and sharedetail.csv (R/seat_state.R, seat_state_sim()).
#   2. Prove the cache (re-simulate every election in full from its state, compare):
#        Rscript scripts/seat_quick.R --prove
#   3. Screen a tweak, optionally against another on the same draws:
#        Rscript scripts/seat_quick.R --tweak=former_flat
#        Rscript scripts/seat_quick.R --tweak=former_winprob --vs=former_flat
#
# Flags: --tweak=NAME   one of names(TWEAKS) below (a function of the cached shares)
#        --vs=NAME      a second tweak scored on the same seats and seeds; prints the paired difference
#        --cache=DIR    the quick_arm cache key directory (default: the newest one holding state files)
#        --root=DIR     where the tweak reads its data (output/, external/); default the slot that built it
#        --pairs=a,b    (default every election in the cache)
#        --sims=N       simulations per re-run (default 20000; at most the cache's own count)
#        --check-arm=ARMDIR,BASEDIR  a quick_arm ARM cache and its BASELINE cache: compares this tweak's
#                       shares with that arm's sharedetail cell by cell (the delta-vs-pipeline gap)
#        --passthrough=ARMDIR,BASEDIR  scale each former-leader seat's cut by the fraction the real harness
#                       carried to the final shares in that quick_arm arm (see PASS-THROUGH below)
#        --prove        full re-simulation of every election, compared with the harness's own result
#        --prove-subset=a,b  every seat of those elections re-simulated ONE SEAT PER CALL (the screen's own
#                       path) against the harness's full run, by z-score; add --break to rotate every
#                       per-seat argument by one seat first, which must FAIL
#        --out=FILE     write the per-seat table (csv)
#
# WHAT IT DOES. For each election it loads the saved state, applies the tweak to the saved
# shares (the matrix the simulator received), stops if the tweak moved any seat it does not
# declare (seat_tweak_check, code SQ7!), and re-simulates ONLY the moved seats, ONE SEAT PER
# CALL, baseline and every arm on the same seed at --sims: per seat, baseline and arm share
# their random stream until the tweak changes what is drawn (common random numbers). A
# seat's winner depends only on its own row and its own draws
# (plans/plan-correlated-seat-draws.md section 0), so untouched seats contribute exactly 0;
# results are given over the touched seats and over every seat of the elections scored, the
# latter being the number quick_arm's Q3 reports. eps = 0.5 / sims, as quick_arm.
#
# THE LIMIT (read before trusting a screen). The state is taken at the simulation, AFTER
# every post-tree step (leader-seat bonus before the seat-poll blend, the blend itself,
# salience, nomination zeroing...). A tweak here acts on the FINAL shares. That is exact for
# a change meant to act last, and an approximation for a change that acts earlier and then
# passes through later steps: a pre-blend leader-seat term in a seat with a seat poll is
# diluted by the blend in the harness and not here. --check-arm measures that gap against a
# real harness arm. Tree or feature changes, flow changes and anything that alters the
# statewide draws are out of scope: build those as a quick_arm arm.
t0 <- Sys.time()
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), a, value = TRUE)
  if (length(hit)) sub("^[^=]*=", "", hit[1]) else default
}
prove <- "--prove" %in% a
arm_names <- c(flag("tweak", ""), flag("vs", NULL))
sims <- as.integer(flag("sims", "20000"))
stopifnot(is.finite(sims), sims >= 100)

# ---- the cache -----------------------------------------------------------------------
qd <- normalizePath(Sys.getenv("AUSPOL_QUICK_DIR", file.path(Sys.getenv("TEMP", tempdir()), "auspol-quickarm")), winslash = "/", mustWork = FALSE)
cache <- flag("cache", NA_character_)
if (is.na(cache)) {
  kd <- list.dirs(file.path(qd, "cache"), recursive = FALSE)
  kd <- kd[vapply(kd, function(d) length(list.files(d, pattern = "^state-.*[.]rds$", recursive = TRUE)) > 0, NA)]
  if (!length(kd)) stop("seat_quick: no cache with state files under ", qd, "/cache; build one with quick_arm.R --base-only --dump --pairs=all --sims=20000")
  cache <- kd[which.max(file.mtime(kd))]
}
all_ids <- basename(list.dirs(cache, recursive = FALSE))
all_ids <- all_ids[file.exists(file.path(cache, all_ids, sprintf("state-%s.rds", all_ids)))]
ids <- all_ids
want <- flag("pairs", "all")
if (!identical(want, "all")) {
  w <- trimws(strsplit(want, ",")[[1]])
  if (!all(w %in% ids)) stop("seat_quick: no state for ", paste(setdiff(w, ids), collapse = ", "), " in ", cache)
  ids <- w
}
root <- flag("root", file.path(qd, "slot1"))
if (!file.exists(file.path(root, "output", "xgb-primary-asat-predictions.csv"))) stop("seat_quick: ", root, " has no output/ inputs; pass --root=")
options(auspol.root = normalizePath(root, winslash = "/"))

ld_ap <- function(id) { ap <- fread(file.path(cache, id, "allprobs.csv"), showProgress = FALSE); if (!"pair" %in% names(ap)) ap$pair <- id; ap }
ld <- function(id) {
  st <- readRDS(file.path(cache, id, sprintf("state-%s.rds", id)))
  if (!identical(st$pair, id)) stop("seat_quick: state file for ", id, " is labelled ", st$pair)
  list(st = st, ap = ld_ap(id), sd = fread(file.path(cache, id, "sharedetail.csv"), showProgress = FALSE))
}

# ---- the tweaks: function(shares, pair) -> shares with attr "targets" ------------------------
# former_winprob reads the baseline win probabilities of EVERY cached election (its fit is
# time-forward over earlier elections), built once on first use.
.wp_all <- NULL
wp_all <- function() {
  if (is.null(.wp_all)) .wp_all <<- rbindlist(lapply(all_ids, function(u) ld_ap(u)[, .(pair, seat, party, prob)]))
  .wp_all
}
# PASS-THROUGH (--passthrough=ARMDIR,BASEDIR, a quick_arm arm of the SAME cut built into the pipeline and
# its baseline): per former-leader seat, the fraction of the flat cut the real harness carried to the final
# shares, r = (arm - base) on the cut cell / intended cut, clamped to [0, 1]; 1 where the cut is under 0.2
# points (the ratio is noise there). Every former-leader tweak is then multiplied by its seat's r, so a cut
# the pipeline would dilute (a polled seat) is diluted here too. PT stays NULL without the flag.
PT <- NULL
pt_flag <- flag("passthrough", NA_character_)
if (!is.na(pt_flag)) {
  ptd <- trimws(strsplit(pt_flag, ",")[[1]]); stopifnot(length(ptd) == 2L, all(dir.exists(ptd)))
  PT <- rbindlist(lapply(all_ids, function(id) {
    x <- ld(id); b <- as.matrix(x$st$args$shares)
    lg <- attr(seat_state_with_env(x$st, seat_tweak_former_leader(b, id, "flat")), "log")
    if (!nrow(lg)) return(NULL)
    qa <- fread(file.path(ptd[1], id, "sharedetail.csv"), showProgress = FALSE); qb <- fread(file.path(ptd[2], id, "sharedetail.csv"), showProgress = FALSE)
    k <- paste(lg$seat, lg$party)
    real <- qa$pred_share[match(k, paste(qa$seat, qa$party))] - qb$pred_share[match(k, paste(qb$seat, qb$party))]
    r <- ifelse(abs(lg$delta) < 0.2 | !is.finite(real), 1, pmin(1, pmax(0, real / lg$delta)))
    data.table(pair = id, seat = lg$seat, party = lg$party, intended = lg$delta, realised = real, r = r)
  }))
  cat("SQ0p pass-through of the flat cut in the real harness arm (realised / intended; r used, 1 where the cut is under 0.2 points):\n")
  print(PT[, .(pair, seat, party, intended = round(intended, 3), realised = round(realised, 3), r = round(r, 3))], row.names = FALSE)
}
TWEAKS <- list(
  former_flat    = function(sh, pair) seat_tweak_former_leader(sh, pair, "flat", passthrough = PT),
  former_margin  = function(sh, pair) seat_tweak_former_leader(sh, pair, "scaled", former_safety_margin, passthrough = PT),
  former_winprob = function(sh, pair) seat_tweak_former_leader(sh, pair, "scaled", former_safety_winprob(wp_all()), passthrough = PT),
  # DELIBERATELY BROKEN, for the proof that seat_tweak_check catches it: the flat cut, plus a
  # one-point move on the row after the first target, which the tweak does not declare.
  broken_offbyone = function(sh, pair) {
    x <- seat_tweak_former_leader(sh, pair, "flat")
    tg <- attr(x, "targets")
    if (length(tg)) { i <- match(tg[1], rownames(x)) %% nrow(x) + 1L; x[i, ] <- .shift_cell(x[i, ], which.max(x[i, ]), -1) }
    x
  })
if (!prove && is.na(flag("prove-subset", NA_character_)) && !all(arm_names %in% names(TWEAKS)))
  stop("usage: Rscript scripts/seat_quick.R --tweak=NAME [--vs=NAME] | --prove   (tweaks: ", paste(names(TWEAKS), collapse = ", "), ")")
cat(sprintf("SQ0  cache %s: %d election(s); %s; %d sims; data root %s\n", cache, length(ids),
            if (prove) "prove" else paste("tweak", paste(arm_names, collapse = " vs ")), sims, root))

# ---- prove: the state reproduces the harness's own simulation ----------------------------
if (prove) {
  P <- rbindlist(lapply(ids, function(id) {
    x <- ld(id); st <- x$st
    t1 <- Sys.time()
    wp <- as.data.table(seat_state_resim(st))
    secs <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
    k <- function(d) paste(d$seat, d$party, sep = "\r")
    own <- as.data.table(st$win_prob)
    same_own <- nrow(wp) == nrow(own) && identical(k(wp), k(own)) && identical(wp$prob, own$prob)
    j <- match(k(x$ap), k(wp))
    d_ap <- max(abs(x$ap$prob - ifelse(is.na(j), 0, wp$prob[j])))
    sh <- as.matrix(st$args$shares)
    hit <- x$sd$seat %in% rownames(sh) & x$sd$party %in% colnames(sh)
    d_sd <- max(abs(x$sd$pred_share[hit] - sh[cbind(match(x$sd$seat[hit], rownames(sh)), match(x$sd$party[hit], colnames(sh)))]))
    cat(sprintf("SQP %-8s %3d seats %5d sims: re-run == harness's own win_prob: %s | max |diff| vs allprobs.csv %.2g | shares vs sharedetail %.2g (%.0f s)\n",
                id, nrow(sh), as.integer(st$args$n_sims), if (same_own) "IDENTICAL" else "DIFFERENT", d_ap, d_sd, secs))
    data.table(pair = id, seats = nrow(sh), identical = same_own, max_ap = d_ap, max_sd = d_sd, secs = secs)
  }))
  cat(sprintf("SQP  %d of %d elections re-simulate IDENTICALLY to the harness run; largest |diff| vs allprobs.csv %.2g, shares vs sharedetail %.2g (csv rounding); %.0f s\n",
              sum(P$identical), nrow(P), max(P$max_ap), max(P$max_sd), as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  if (!all(P$identical) || max(P$max_ap) > 1e-9 || max(P$max_sd) > 1e-9) quit(status = 1)
  quit(status = 0)
}

# ---- prove-subset: one seat per call agrees with the harness's full run, seat by seat -------
# --prove-subset=a,b re-simulates EVERY seat of those elections one seat per call at the state's
# own sim count and compares each (seat, party) probability with the harness's full run: two
# independent estimates, so z = diff / sqrt(2 pbar (1 - pbar) / n). With --break, every per-seat
# argument except the shares is rotated by one seat first (a misaligned subset), which must fail.
ps <- flag("prove-subset", NA_character_)
if (!is.na(ps)) {
  brk <- "--break" %in% a
  rot <- function(args) {
    n <- nrow(as.matrix(args$shares)); hit <- character(0)
    for (nm in setdiff(names(args), c("shares", .SEAT_STATE_NOT_PER_SEAT))) {
      v <- args[[nm]]
      if (is.matrix(v) && nrow(v) == n) { v[] <- v[c(2:n, 1L), ]; args[[nm]] <- v; hit <- c(hit, nm) }
      else if (!is.list(v) && length(v) == n && is.atomic(v)) { v[] <- v[c(2:n, 1L)]; args[[nm]] <- v; hit <- c(hit, nm) }
    }
    attr(args, "rotated") <- hit
    args
  }
  ok_all <- TRUE
  for (id in trimws(strsplit(ps, ",")[[1]])) {
    x <- ld(id); st <- x$st; n_s <- as.integer(st$args$n_sims)
    if (brk) { st$args <- rot(st$args); cat(sprintf("SQB  %s: BROKEN on purpose, rotated by one seat: %s\n", id, paste(attr(st$args, "rotated"), collapse = ", "))) }
    t1 <- Sys.time()
    seats <- rownames(as.matrix(st$args$shares))
    one <- rbindlist(lapply(seats, function(s) as.data.table(seat_state_resim(st, seats = s))))
    own <- as.data.table(st$win_prob)
    m <- merge(own[, .(seat, party, p_full = prob)], one[, .(seat, party, p_one = prob)], by = c("seat", "party"), all = TRUE)
    m[is.na(p_full), p_full := 0]; m[is.na(p_one), p_one := 0]
    m[, pbar := (p_full + p_one) / 2]
    m[, z := ifelse(pbar > 0 & pbar < 1, (p_one - p_full) / sqrt(2 * pbar * (1 - pbar) / n_s), 0)]
    act <- unique(x$ap[, .(seat, actual)])
    w <- merge(m, act, by.x = c("seat", "party"), by.y = c("seat", "actual"))
    cl <- quick_clustered(w$p_one - w$p_full, rep(id, nrow(w)))
    se_w <- stats::sd(w$p_one - w$p_full) / sqrt(nrow(w))
    pass <- max(abs(m$z)) < 5 && abs(mean(w$p_one - w$p_full)) < 3 * se_w
    ok_all <- ok_all && pass
    cat(sprintf("SQS  %s: %d seats one per call at %d sims vs the harness's full run: max |z| %.2f over %d seat-party cells (%d above 4); winner probability mean diff %+.5f (SE %.5f) => %s (%.0f s)\n",
                id, length(seats), n_s, max(abs(m$z)), nrow(m), sum(abs(m$z) > 4), cl$mean, se_w, if (pass) "PASS" else "FAIL",
                as.numeric(difftime(Sys.time(), t1, units = "secs"))))
    if (!pass) print(head(m[order(-abs(z))], 5), row.names = FALSE)
  }
  quit(status = if (ok_all) 0 else 1)
}

# ---- screen ------------------------------------------------------------------------------
eps <- 0.5 / sims
chk <- flag("check-arm", NA_character_)
if (!is.na(chk)) { chk <- trimws(strsplit(chk, ",")[[1]]); stopifnot(length(chk) == 2L, all(dir.exists(chk))) }
seat_rows <- list(); cell_rows <- list(); n_seats <- integer(0); chk_rows <- list(); logs <- list()
n_moved <- stats::setNames(integer(length(arm_names)), arm_names)
for (id in ids) {
  x <- ld(id); st <- x$st
  base <- as.matrix(st$args$shares)
  n_seats[id] <- nrow(base)
  arms <- list(); moved <- list()
  for (nm in arm_names) {
    y <- seat_state_with_env(st, TWEAKS[[nm]](base, id))
    tg <- attr(y, "targets"); if (nrow(attr(y, "log"))) logs[[paste(nm, id)]] <- cbind(tweak = nm, pair = id, attr(y, "log"))
    attributes(y) <- attributes(base)   # drop the tweak's own attributes
    moved[[nm]] <- seat_tweak_check(base, y, tg)
    n_moved[nm] <- n_moved[nm] + length(moved[[nm]])
    arms[[nm]] <- y
  }
  if (!anyNA(chk)) {   # cell-by-cell against a real harness arm and its baseline (first tweak only)
    asd <- fread(file.path(chk[1], id, "sharedetail.csv"), showProgress = FALSE)
    bsd <- fread(file.path(chk[2], id, "sharedetail.csv"), showProgress = FALSE)
    hit <- bsd$seat %in% rownames(base) & bsd$party %in% colnames(base)
    ix <- cbind(match(bsd$seat[hit], rownames(base)), match(bsd$party[hit], colnames(base)))
    q_b <- bsd$pred_share[hit]; q_a <- asd$pred_share[match(paste(bsd$seat, bsd$party)[hit], paste(asd$seat, asd$party))]
    q_moved <- unique(bsd$seat[hit][abs(q_a - q_b) > 1e-9])
    m1 <- moved[[1]]; y1 <- arms[[1]]; dd <- abs(y1[ix] - q_a)
    chk_rows[[id]] <- data.table(pair = id, base_vs_qbase = max(abs(base[ix] - q_b)),
                                 qarm_seats = length(q_moved), ours_seats = length(m1), same_seats = setequal(q_moved, m1),
                                 arm_vs_qarm_moved = if (length(union(m1, q_moved))) max(dd[bsd$seat[hit] %in% union(m1, q_moved)]) else 0,
                                 # the tweak's own move against the harness arm's move, cell by cell (immune to a baseline gap)
                                 delta_gap_moved = if (length(m1)) max(abs((y1[ix] - base[ix]) - (q_a - q_b))[bsd$seat[hit] %in% m1]) else 0,
                                 delta_gap_seat = if (length(m1)) { g <- abs((y1[ix] - base[ix]) - (q_a - q_b)); g[!bsd$seat[hit] %in% m1] <- 0; bsd$seat[hit][which.max(g)] } else "",
                                 arm_vs_qarm_other = if (any(!bsd$seat[hit] %in% union(m1, q_moved))) max(dd[!bsd$seat[hit] %in% union(m1, q_moved)]) else 0,
                                 worst_cell = if (max(dd) > 0) paste(bsd$seat[hit][which.max(dd)], bsd$party[hit][which.max(dd)]) else "")
  }
  if (uniqueN(x$ap$seat) != nrow(base)) stop("seat_quick: ", id, " allprobs has ", uniqueN(x$ap$seat), " seats, the state ", nrow(base))
  u <- unique(unlist(moved))
  if (!length(u)) next
  act <- unique(x$ap[, .(seat, actual)])
  actual <- stats::setNames(act$actual, act$seat)[u]
  # a seat with no recorded winner scores 0 in baseline and arm alike, as quick_winner_prob() gives it; listed
  no_act <- u[is.na(actual)]
  if (length(no_act)) cat(sprintf("SQ1! %s: no actual winner for %s; scored as a change of exactly 0, as quick_arm does\n", id, paste(no_act, collapse = ", ")))
  # one seat per call: each seat's baseline and arm runs start from the same seed
  p_b <- vapply(u, function(s) if (is.na(actual[s])) 0 else seat_state_winner_p(seat_state_resim(st, seats = s, n_sims = sims), actual[s]), 0)
  row <- data.table(pair = id, seat = u, winner = unname(actual), p_base = unname(p_b),
                    p_harness = unname(seat_state_winner_p(x$ap, actual)))
  for (nm in arm_names) {
    row[[paste0("p_", nm)]] <- vapply(u, function(s) if (s %in% moved[[nm]] && !is.na(actual[s]))
      seat_state_winner_p(seat_state_resim(st, shares = arms[[nm]], seats = s, n_sims = sims), actual[s]) else p_b[[s]], 0)
  }
  seat_rows[[id]] <- row
  sdm <- x$sd[x$sd$seat %in% u]
  sdm$pair <- id
  inm <- sdm$party %in% colnames(base)
  ix <- cbind(match(sdm$seat[inm], rownames(base)), match(sdm$party[inm], colnames(base)))
  for (nm in arm_names) { v <- sdm$pred_share; v[inm] <- arms[[nm]][ix]; sdm[[paste0("s_", nm)]] <- v }
  cell_rows[[id]] <- sdm
}
S <- rbindlist(seat_rows); C <- rbindlist(cell_rows); G <- rbindlist(logs, fill = TRUE)
cat(sprintf("SQ0b %d seats in the %d elections scored (quick_arm's Q3 denominator; 2,931 over all 35)\n", sum(n_seats), length(n_seats)))
cat(sprintf("SQ1  seats moved: %s; %d seats in all, in %d of %d elections (every moved seat declared by its tweak, SQ7 check)\n",
            paste(sprintf("%s %d", arm_names, n_moved[arm_names]), collapse = ", "), nrow(S), uniqueN(S$pair), length(ids)))
if (length(chk_rows)) {
  K <- rbindlist(chk_rows)
  cat("SQC  our tweak's shares against the harness arm, in points of primary share (0 = identical); base_vs_qbase: our cached baseline against that arm's own baseline:\n")
  print(K[qarm_seats > 0 | ours_seats > 0 | base_vs_qbase > 1e-9], row.names = FALSE)
  cat(sprintf("SQC  %d elections; same moved-seat set in %d; our baseline equals the arm's baseline in %d; largest gap on a moved seat %.4f points, elsewhere %.2g\n",
              nrow(K), sum(K$same_seats), sum(K$base_vs_qbase < 1e-9), max(K$arm_vs_qarm_moved), max(K$arm_vs_qarm_other)))
}
if (!nrow(S)) { cat("SQ1  nothing moved: the tweak is a no-op on these elections\n"); quit(status = 0) }
if (nrow(G)) { cat("SQ1b what each tweak did (delta in points of the named party's primary; scaled tweaks show safety and slope):\n"); print(G, row.names = FALSE) }
res <- list()
for (nm in arm_names) {
  L <- seat_state_ll(as.data.frame(S[, .(pair, seat, p_base, p_arm = get(paste0("p_", nm)))]), n_seats, eps)
  Q <- quick_share_diff(as.data.frame(C[, .(pair, seat, party, pred_share, actual_share)]),
                        as.data.frame(C[, .(pair, seat, party, pred_share = get(paste0("s_", nm)), actual_share)]))
  S[[paste0("dd_", nm)]] <- L$seats$dd
  res[[nm]] <- list(L = L, Q = Q)
  p <- Q$primary; o <- L$touched; o2 <- L$all
  cat(sprintf("\n== %s vs baseline ==\n", nm))
  cat(sprintf("SQ3  share-level squared error on %d changed cells (moved > 0.05 points; lower is better): %.1f -> %.1f, change %+.1f (%+.0f%%), SE %s (clustered on election, %d elections) => %s\n",
              p$n, p$base, p$arm, p$change, 100 * p$change / p$base, if (is.na(p$se)) "NA" else sprintf("%.1f", p$se), p$clusters, quick_q2_verdict(p)))
  cut <- C[get(paste0("s_", nm)) < pred_share - 0.05]
  if (nrow(cut)) cat(sprintf("SQ3b signed error on the %d cells it cut (actual minus predicted, points; 0 is unbiased): %+.2f -> %+.2f\n",
                             nrow(cut), mean(cut$actual_share - cut$pred_share), mean(cut$actual_share - cut[[paste0("s_", nm)]])))
  cat(sprintf("SQ4  seat-winner log loss over the %d seats any tweak moved (lower is better): %.4f -> %.4f, change %+.4f per seat (SE %.4f, clustered on election, %d elections) => %s\n",
              o$n, mean(L$seats$ll_base), mean(L$seats$ll_arm), o$mean, o$se, o$clusters, quick_word(o$mean, o$se)))
  cat(sprintf("SQ5  as quick_arm's Q3 states it, over all %d seats of the %d elections (untouched seats exactly 0): change %+.5f (SE %.5f) => %s; worst election %s %+.4f\n",
              o2$n, o2$clusters, o2$mean, o2$se, quick_word(o2$mean, o2$se),
              L$per_pair$pair[which.max(L$per_pair$ll_change_all)], max(L$per_pair$ll_change_all)))
}
if (length(arm_names) == 2L) {
  d <- S[[paste0("dd_", arm_names[1])]] - S[[paste0("dd_", arm_names[2])]]
  o <- quick_clustered(d, S$pair)
  cat(sprintf("\nSQ6  PAIRED %s minus %s, seat-winner log loss over the %d moved seats (negative = %s better): %+.4f per seat (SE %.4f, %d elections) => %s\n",
              arm_names[1], arm_names[2], o$n, arm_names[1], o$mean, o$se, o$clusters, quick_word(o$mean, o$se)))
}
cat("\nSQ2  per seat: probability given to the actual winner, all re-simulated one seat at a time at", sims, "sims on one seed (higher is better); p_harness is the cached full run; dd = log-loss change vs baseline (lower is better):\n")
show <- copy(S)
for (cc in grep("^p_|^dd_", names(show), value = TRUE)) show[[cc]] <- round(show[[cc]], if (startsWith(cc, "dd_")) 4 else 3)
print(show[order(pair, seat)], row.names = FALSE)
of <- flag("out", "")
if (nzchar(of)) { fwrite(S, of); cat("SQ8  per-seat table written to", of, "\n") }
cat(sprintf("SQ9  runtime %.0f s, %d seats, %d tweak(s), %d sims each (eps %.1e)\n",
            as.numeric(difftime(Sys.time(), t0, units = "secs")), nrow(S), length(arm_names), sims, eps))
