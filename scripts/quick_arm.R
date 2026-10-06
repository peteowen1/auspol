# FAST SCREEN for a model tweak: answers in minutes what a full 20,000-simulation
# arm answers in 10-40. Screen with this; run the full arm only for the SHIPPING decision.
#
#   Rscript scripts/quick_arm.R "AUSPOL_X=1 AUSPOL_Y=0"
#   Rscript scripts/quick_arm.R "AUSPOL_NEW_IND_SHRINK=0" --pairs=vic2022,vic2018
#   Rscript scripts/quick_arm.R "AUSPOL_DEFECTOR_STATE=1" --base="AUSPOL_FOO=1" --sims=2000
#
# Flags: --pairs=a,b (default all 22 elections; names like vic2022, fed2019, wa2017)
#        --sims=N    (default 1000; baseline and arm run the SAME seed at the SAME N)
#        --base="ENV" extra switches for the BASELINE (default: the shipped configuration)
#        --slots=N   concurrent harness processes (default 2, the machine's limit)
#        --clean     delete the scratch directory (junctions first) and exit
#
# HOW IT WORKS (and why it is built this way: R/quick_arm.R header has the profile).
#  1. One harness run per ELECTION (the harnesses already take a pair selector), so an
#     arm that touches one pair pays for one pair. Runs happen in scratch roots with
#     junctions to this checkout's R/, src/, scripts/ and external/ and a COPY of the
#     inputs from output/; nothing is ever written to output/ itself.
#  2. Baseline and arm use the identical seed and simulation count (common random
#     numbers): a pair the arm does not touch is byte-identical and scores exactly 0,
#     and a touched pair differs only by what the arm changed.
#  3. The baseline is CACHED, keyed on (git commit + uncommitted R/scripts diff,
#     baseline switches, N, input files), and shared by every arm. Arms are cached too.
#  4. Scored from the harness's own sharedetail (point predictions) and allprobs
#     (seat win probabilities); the numbers are paired and clustered like
#     scripts/score_arm.R (SA2, SA5/SA6, SA3).
#
# THE LIMIT. It measures the arm at N simulations against a baseline at N, not against
# the 20k snapshot. Seats whose winner has a probability under ~1/N are floored (eps =
# 0.5/N), so a change that moves a 0.01% winner to 0.001% is invisible here and large
# in the full run. A screen that says "within 1 SE" has not cleared a change that works
# in the far tails; one that says WORSE is a reason to stop.
t_start <- Sys.time()
suppressMessages(library(data.table))
source("R/quick_arm.R")

# ---- arguments ---------------------------------------------------------------
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), a, value = TRUE)
  if (length(hit)) sub("^[^=]*=", "", hit[1]) else default
}
pos <- a[!grepl("^--", a)]
clean_only <- "--clean" %in% a
arm_env <- quick_parse_env(paste(pos, collapse = " "))
base_env <- quick_parse_env(flag("base", ""))
sims <- as.integer(flag("sims", "1000")); slots <- as.integer(flag("slots", "2"))
stopifnot(is.finite(sims), sims >= 100, slots >= 1, slots <= 2)  # two R processes at once is the machine's limit
if (!clean_only && !length(arm_env)) stop("usage: Rscript scripts/quick_arm.R \"AUSPOL_X=1 AUSPOL_Y=0\" [--pairs=..] [--sims=N] [--base=\"ENV\"]")
# the arm and the baseline must differ, or this compares a run with itself
arm_eff <- c(base_env[setdiff(names(base_env), names(arm_env))], arm_env)

# ---- where things live -------------------------------------------------------
sh <- function(...) suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = FALSE))
repo <- normalizePath(".", winslash = "/")
stopifnot(file.exists(file.path(repo, "DESCRIPTION")))
common <- tryCatch(normalizePath(sh("rev-parse", "--git-common-dir")[1], winslash = "/"), error = function(e) NA_character_)
main_checkout <- if (!is.na(common)) dirname(common) else repo
pick <- function(sub, probe) {
  for (b in unique(c(repo, main_checkout))) if (file.exists(file.path(b, sub, probe))) return(file.path(b, sub))
  stop("quick_arm: cannot find ", sub, "/", probe, " in ", repo, " or ", main_checkout)
}
src_output <- Sys.getenv("AUSPOL_QUICK_SRC_OUTPUT", pick("output", "xgb-primary-asat-predictions.csv"))
src_external <- pick("external", "elections")
qd <- normalizePath(Sys.getenv("AUSPOL_QUICK_DIR", file.path(Sys.getenv("TEMP", tempdir()), "auspol-quickarm")), winslash = "/", mustWork = FALSE)
# never inside a real output/ directory or the source of the inputs
for (bad in c(src_output, file.path(repo, "output"), file.path(main_checkout, "output")))
  if (startsWith(tolower(qd), tolower(normalizePath(bad, winslash = "/", mustWork = FALSE))))
    stop("quick_arm: scratch dir ", qd, " is inside ", bad, "; refusing to write there")

is_win <- .Platform$OS.type == "windows"
link_dir <- function(link, target) {
  if (is_win) {
    r <- suppressWarnings(system2("cmd", c("/c", "mklink", "/J", shQuote(gsub("/", "\\\\", link)), shQuote(gsub("/", "\\\\", target))), stdout = TRUE, stderr = TRUE))
  } else r <- file.symlink(target, link)
  if (!dir.exists(link)) stop("quick_arm: could not link ", link, " -> ", target, "\n", paste(r, collapse = "\n"))
}
unlink_link <- function(link) {  # removes the junction only, never what it points at
  if (!dir.exists(link) && !file.exists(link)) return(invisible())
  if (is_win) suppressWarnings(system2("cmd", c("/c", "rmdir", shQuote(gsub("/", "\\\\", link))), stdout = FALSE, stderr = FALSE)) else unlink(link)
}
LINKS <- c("R", "src", "scripts")
clean_root <- function(root) {
  for (l in c(LINKS, "external")) unlink_link(file.path(root, l))
  if (dir.exists(file.path(root, "output"))) unlink(file.path(root, "output"), recursive = TRUE)
}
if (clean_only) {
  for (r in list.files(qd, pattern = "^slot", full.names = TRUE)) clean_root(r)
  unlink(qd, recursive = TRUE)
  cat("quick_arm: removed", qd, "(junctions removed first)\n"); quit(status = 0)
}
dir.create(qd, recursive = TRUE, showWarnings = FALSE)

# ---- identity of the inputs and the code --------------------------------------
sig_files <- file.path(src_output, c("xgb-primary-asat-predictions.csv", "xgb-primary-v6-features.csv", "candidacies.csv"))
input_sig <- paste(vapply(sig_files, function(f) if (file.exists(f)) sprintf("%s:%d:%d", basename(f), file.size(f), as.integer(file.mtime(f))) else paste0(basename(f), ":absent"), ""), collapse = "|")
excl <- c(":(exclude)R/quick_arm.R", ":(exclude)scripts/quick_arm.R")
head_sha <- sh("rev-parse", "--short=7", "HEAD")[1]
dirty_txt <- c(sh("diff", "HEAD", "--", "R", "scripts", excl),
               unlist(lapply(setdiff(sh("ls-files", "--others", "--exclude-standard", "--", "R", "scripts", excl), character(0)),
                             function(f) c(f, readLines(f, warn = FALSE)))))
code_hash <- if (length(dirty_txt)) { tf <- tempfile(); writeLines(dirty_txt, tf); sprintf("%sx%s", head_sha, substr(unname(tools::md5sum(tf)), 1, 8)) } else head_sha
key_of <- function(env) {
  s <- paste(c(code_hash, sims, input_sig, if (length(env)) paste0(names(env)[order(names(env))], "=", env[order(names(env))])), collapse = ";")
  tf <- tempfile(); writeLines(s, tf); substr(unname(tools::md5sum(tf)), 1, 12)
}
key_base <- key_of(base_env); key_arm <- key_of(arm_eff)
if (identical(key_base, key_arm)) stop("quick_arm: the arm sets nothing different from the baseline; there is nothing to compare")

# ---- scratch roots (one per concurrent process) --------------------------------
ensure_root <- function(i) {
  root <- file.path(qd, paste0("slot", i)); dir.create(root, showWarnings = FALSE)
  stamp <- file.path(root, ".repo")
  if (!file.exists(stamp) || !identical(readLines(stamp, warn = FALSE), repo) ||
      !all(dir.exists(file.path(root, c(LINKS, "external"))))) {   # linked to another checkout: relink
    clean_root(root)
    for (l in LINKS) link_dir(file.path(root, l), file.path(repo, l))
    link_dir(file.path(root, "external"), src_external)
    writeLines(repo, stamp)
  }
  file.copy(file.path(repo, c("DESCRIPTION", "NAMESPACE")), root, overwrite = TRUE)
  out <- file.path(root, "output"); sigf <- file.path(out, ".quick-sig")
  if (!file.exists(sigf) || !identical(readLines(sigf, warn = FALSE), input_sig)) {
    if (dir.exists(out)) unlink(out, recursive = TRUE)
    dir.create(out, recursive = TRUE)
    fs <- list.files(src_output, full.names = TRUE)
    fs <- fs[!dir.exists(fs) & !grepl("^backtest-", basename(fs))]
    file.copy(fs, out, copy.date = TRUE)
    for (d in c("booths", "cache", "shipped", "xgb-base-ref", "xgb-primary-asat", "xgb-primary-v6-models"))
      if (dir.exists(file.path(src_output, d))) file.copy(file.path(src_output, d), out, recursive = TRUE, copy.date = TRUE)
    writeLines(input_sig, sigf)
    cat(sprintf("quick_arm: slot%d inputs copied from %s (%d files)\n", i, src_output, length(fs)))
  }
  root
}
roots <- vapply(seq_len(slots), ensure_root, "")

# ---- which runs are needed -----------------------------------------------------
U <- quick_units()
want <- flag("pairs", "")
if (nzchar(want)) {
  w <- trimws(strsplit(want, ",")[[1]])
  if (!all(w %in% U$id)) stop("quick_arm: unknown pair(s): ", paste(setdiff(w, U$id), collapse = ", "), " (valid: ", paste(U$id, collapse = " "), ")")
  U <- U[U$id %in% w, ]
}
cache_dir <- function(key, id) file.path(qd, "cache", key, id)
have <- function(key, id) file.exists(file.path(cache_dir(key, id), "meta.rds"))
secs_guess <- function(h) if (h == "fed") 70 else if (h == "wa") 60 else 45
tasks <- list()
for (i in seq_len(nrow(U))) for (role in c("base", "arm")) {
  key <- if (role == "base") key_base else key_arm
  if (!have(key, U$id[i])) tasks[[length(tasks) + 1L]] <- list(
    id = U$id[i], role = role, key = key, harness = U$harness[i], var = U$var[i], val = U$val[i],
    env = if (role == "base") base_env else arm_eff, dir = cache_dir(key, U$id[i]), est = secs_guess(U$harness[i]))
}
cat(sprintf("quick_arm: arm {%s} vs baseline {%s} at %d simulations, %d election(s), code %s\n",
            paste(paste0(names(arm_env), "=", arm_env), collapse = " "),
            if (length(base_env)) paste(paste0(names(base_env), "=", base_env), collapse = " ") else "shipped",
            sims, nrow(U), code_hash))
cat(sprintf("quick_arm: baseline cache %s: %d of %d elections cached | arm cache %s: %d of %d cached\n",
            key_base, sum(vapply(U$id, function(u) have(key_base, u), NA)), nrow(U),
            key_arm, sum(vapply(U$id, function(u) have(key_arm, u), NA)), nrow(U)))

# ---- run ----------------------------------------------------------------------
run_unit <- function(task) {
  root <- file.path(task$qd, paste0("slot", get("SLOT", envir = globalenv())))
  out <- file.path(root, "output")
  t0 <- Sys.time(); dir.create(task$dir, recursive = TRUE, showWarnings = FALSE)
  logf <- file.path(task$dir, "run.log")
  env <- c(task$env, AUSPOL_XGB_PRIMARY = "1", AUSPOL_SKIP_PAIRS = "wa2021", AUSPOL_N_SIMS = as.character(task$sims))
  env[task$var] <- task$val
  old_wd <- setwd(root)
  # A CLEAN SLATE EVERY RUN: this worker process runs many tasks in turn and a child
  # inherits its environment, so a switch left over from an earlier (arm) task made the
  # next BASELINE run silently carry it (found 2026-10-07: a baseline vic2018 ran with
  # AUSPOL_NEW_IND_SHRINK=0). Every AUSPOL_* variable is dropped, then only this task's set.
  clear_auspol <- function() { cur <- names(Sys.getenv()); drop <- cur[grepl("^AUSPOL_", cur)]; if (length(drop)) Sys.unsetenv(drop) }
  clear_auspol()
  do.call(Sys.setenv, as.list(env))
  status <- tryCatch(system2(file.path(R.home("bin"), "Rscript"), paste0("scripts/backtest_candidate_", task$harness, ".R"),
                             stdout = logf, stderr = logf), finally = { clear_auspol(); setwd(old_wd) })
  # ...and PROVE it: the harness logs every switch the caller set (HD1); any name there that
  # this task did not set means another arm leaked into this one, and the run is refused.
  hd1 <- grep("^HD1 ", readLines(logf, warn = FALSE), value = TRUE)[1]
  seen <- if (is.na(hd1)) character(0) else regmatches(hd1, gregexpr("AUSPOL_[A-Z0-9_]+(?==)", hd1, perl = TRUE))[[1]]
  foreign <- setdiff(seen, names(env))
  if (is.na(hd1) || length(foreign))
    return(list(id = task$id, role = task$role, ok = FALSE, secs = 0, status = -1L,
                log = paste0(logf, if (is.na(hd1)) " (no HD1 line: cannot prove what was applied)" else paste(" (leaked switch(es):", paste(foreign, collapse = ","), ")"))))
  new <- list.files(out, pattern = "^backtest-", full.names = TRUE)
  new <- new[file.mtime(new) >= t0 - 2]
  pick1 <- function(pat) { f <- new[grepl(pat, basename(new))]; if (length(f) != 1L) NA_character_ else f }
  sd_f <- pick1("-sharedetail"); ap_f <- pick1("-allprobs")
  ok <- identical(as.integer(status), 0L) && !is.na(sd_f) && !is.na(ap_f)
  if (ok) {
    file.copy(sd_f, file.path(task$dir, "sharedetail.csv"), overwrite = TRUE)
    file.copy(ap_f, file.path(task$dir, "allprobs.csv"), overwrite = TRUE)
  }
  unlink(new)   # the scratch output stays small and a later run cannot pick up this one's files
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (ok) saveRDS(list(secs = secs, harness = task$harness), file.path(task$dir, "meta.rds"))
  list(id = task$id, role = task$role, ok = ok, secs = secs, status = status, log = logf)
}
res <- list()
if (length(tasks)) {
  tasks <- tasks[order(-vapply(tasks, function(t) t$est, 0))]
  for (i in seq_along(tasks)) { tasks[[i]]$qd <- qd; tasks[[i]]$sims <- sims }
  cat(sprintf("quick_arm: running %d harness run(s) on %d process(es) (est %.0f s)\n", length(tasks), slots,
              sum(vapply(tasks, function(t) t$est, 0)) / slots))
  cl <- parallel::makeCluster(min(slots, length(tasks)))
  parallel::clusterApply(cl, seq_along(cl), function(i) { assign("SLOT", i, envir = globalenv()); NULL })
  res <- tryCatch(parallel::clusterApplyLB(cl, tasks, run_unit), finally = parallel::stopCluster(cl))
  for (r in res) cat(sprintf("  %-9s %-4s %s %5.0f s%s\n", r$id, r$role, if (r$ok) "ok " else "FAILED", r$secs,
                             if (r$ok) "" else paste0("  -> ", r$log)))
  if (!all(vapply(res, function(r) r$ok, NA))) stop("quick_arm: a harness run failed; see the log(s) above")
}

# ---- score --------------------------------------------------------------------
rd <- function(key, file) rbindlist(lapply(U$id, function(u) {
  d <- fread(file.path(cache_dir(key, u), file), showProgress = FALSE)
  # nsw/qld/sa write no pair column in allprobs (one pair per run): the unit IS the pair.
  # A pair label that disagrees with the unit would mean the wrong file was cached.
  if (!"pair" %in% names(d)) d$pair <- u
  if (!all(d$pair == u)) stop("quick_arm: ", file, " for ", u, " carries pair label(s) ", paste(unique(d$pair), collapse = ","))
  d
}), fill = TRUE)
B_sd <- rd(key_base, "sharedetail.csv"); A_sd <- rd(key_arm, "sharedetail.csv")
B_ap <- rd(key_base, "allprobs.csv");    A_ap <- rd(key_arm, "allprobs.csv")
cat(sprintf("\nQ0  scored %d cells and %d seats in %d election(s): %s\n", nrow(B_sd), uniqueN(B_ap[, .(pair, seat)]), uniqueN(B_sd$pair),
            paste(sort(unique(B_sd$pair)), collapse = " ")))
stopifnot(setequal(unique(B_sd$pair), unique(A_sd$pair)), nrow(B_sd) > 0)
eps_q <- 0.5 / sims
sd_res <- quick_share_diff(as.data.frame(B_sd), as.data.frame(A_sd))
ll_res <- quick_seat_ll(as.data.frame(B_ap), as.data.frame(A_ap), eps = eps_q)
per <- merge(sd_res$per_pair, ll_res$per_pair[, c("pair", "seats", "seats_changed", "ll_base", "ll_arm", "change")], by = "pair", all = TRUE)
names(per)[names(per) == "change"] <- "ll_change"
stopifnot(!anyNA(per$cells), !anyNA(per$seats))   # every election scored on both levels
touched <- per[per$changed > 0 | per$seats_changed > 0, ]
cat(sprintf("Q1  changed cells (|prediction moved| > 0.05): %d of %d, in %d of %d election(s); %d election(s) byte-identical to baseline\n",
            sum(per$changed), sum(per$cells), nrow(touched), nrow(per), nrow(per) - nrow(touched)))
if (nrow(touched)) {
  cat("    per election (changed cells; squared-error change on them, lower is better; seat-winner log loss change, lower is better):\n")
  tt <- touched[order(touched$ll_change, decreasing = TRUE), ]
  print(data.frame(election = tt$pair, cells = tt$cells, changed = tt$changed, sq_err_change = round(tt$sq_err_change, 1),
                   seats = tt$seats, seats_moved = tt$seats_changed, ll_base = round(tt$ll_base, 4), ll_arm = round(tt$ll_arm, 4),
                   ll_change = round(tt$ll_change, 4)), row.names = FALSE)
}
p <- sd_res$primary
if (is.na(p$se)) {
  cat(sprintf("Q2  share-level squared error on the %d changed cell(s): NOT ASSESSABLE (fewer than 2)\n", p$n))
} else {
  cat(sprintf("Q2  share-level squared error on %d changed cells: %.1f -> %.1f, change %+.1f (%+.0f%%), SE %.1f (cells as units) => %s\n",
              p$n, p$base, p$arm, p$change, 100 * p$change / p$base, p$se,
              if (p$change < -2 * p$se && p$change < -0.1 * p$base) "PASS (< -2 SE and < -10%)" else if (p$change > 2 * p$se) "WORSE by more than 2 SE" else "FAIL / not clear"))
}
o <- ll_res$overall
cat(sprintf("Q3  seat-winner log loss (lower is better), %d seats in %d election(s): %.4f -> %.4f, change %+.4f (SE %.4f, clustered on election) => %s\n",
            o$n, o$clusters, ll_res$ll_base, ll_res$ll_arm, o$mean, o$se, quick_word(o$mean, o$se)))
lg <- tryCatch(fread(file.path(src_output, "aef-comparison-full.csv"), select = c("pair", "seat"), showProgress = FALSE), error = function(e) NULL)
if (!is.null(lg)) {
  L <- quick_ledger_ll(ll_res, as.data.frame(lg))
  if (L$n == 0) cat("Q4  AEF-7 ledger: none of its seats are in the elections scored here\n") else
    cat(sprintf("Q4  AEF-7 ledger subset: %d of %d ledger seats scored, log loss %.4f -> %.4f, change %+.4f (SE %.4f) => %s\n",
                L$n, L$rows, L$ll_base, L$ll_arm, L$overall$mean, L$overall$se, quick_word(L$overall$mean, L$overall$se)))
}
cat(sprintf("\nQ9  runtime %.0f s (%d harness run(s) this call; cached baseline/arm runs cost nothing). Floor eps = %.1e for %d sims.\n",
            as.numeric(difftime(Sys.time(), t_start, units = "secs")), length(res), eps_q, sims))
