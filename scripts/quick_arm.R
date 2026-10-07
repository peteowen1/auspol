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
# a switch no harness reads is an arm that never ran: it must be in PUBLISHED_FLAGS (which is also
# what HD1 reports). A typo stops here, before anything is copied or run.
source("scripts/published_flags.R")
quick_check_registered(c(names(arm_env), names(base_env)), names(PUBLISHED_FLAGS))
# quick_arm forces these on every run (run_unit), and a forced value silently wins over a
# named one, so naming one would be an arm that never ran. Use --sims for the sim count.
.forced <- intersect(c(names(arm_env), names(base_env)), c("AUSPOL_XGB_PRIMARY", "AUSPOL_SKIP_PAIRS", "AUSPOL_N_SIMS"))
if (length(.forced))
  stop("quick_arm: ", paste(.forced, collapse = ", "), " is set by quick_arm itself on every run and cannot be screened here",
       if ("AUSPOL_N_SIMS" %in% .forced) " (use --sims=N)" else "", call. = FALSE)

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
  r <- if (is_win) suppressWarnings(system2("cmd", c("/c", "rmdir", shQuote(gsub("/", "\\\\", link))), stdout = TRUE, stderr = TRUE)) else unlink(link)
  if (dir.exists(link) || file.exists(link))
    stop("quick_arm: could not remove link ", link, " (", paste(r, collapse = " "), "); not deleting anything under it")
  invisible()
}
LINKS <- c("R", "src", "scripts")
ALL_LINKS <- c(LINKS, "external")
clean_root <- function(root) {
  for (l in ALL_LINKS) unlink_link(file.path(root, l))
  quick_assert_no_links(root, ALL_LINKS)   # the removal above actually worked
  if (dir.exists(file.path(root, "output"))) unlink(file.path(root, "output"), recursive = TRUE)
}
if (clean_only) {
  quick_check_root(qd, create = FALSE)    # only a directory this tool made (marker file) is ever deleted
  slots_found <- list.files(qd, pattern = "^slot", full.names = TRUE)
  for (r in slots_found) clean_root(r)
  for (r in slots_found) quick_assert_no_links(r, ALL_LINKS)
  unlink(qd, recursive = TRUE)
  cat("quick_arm: removed", qd, "(junctions removed first)\n"); quit(status = 0)
}
quick_check_root(qd, create = TRUE)       # refuses a directory without the marker that is not empty

# ---- identity of the inputs and the code --------------------------------------
# EVERY top-level input the slot copy takes (same filter as the copy below), not a
# hand-picked few: with three named files, a new or refitted input elsewhere in
# output/ (e.g. departed-successor-rates.csv, 2026-10-07) was never recopied into
# the slots and never invalidated a cached baseline.
sig_files <- list.files(src_output, full.names = TRUE)
sig_files <- sort(sig_files[!dir.exists(sig_files) & !grepl("^backtest-", basename(sig_files))])
top_sig <- paste(vapply(sig_files, function(f) if (file.exists(f)) sprintf("%s:%d:%d", basename(f), file.size(f), as.integer(file.mtime(f))) else paste0(basename(f), ":absent"), ""), collapse = "|")
# The six subdirectories the slot copy takes are inputs too (a refit model under xgb-primary-*
# changes the forecast): recursive relative path, size, mtime, so a change invalidates both the
# slot copy and every cache key. A missing or unreadable one changes the key every call.
SUBDIRS <- c("booths", "cache", "shipped", "xgb-base-ref", "xgb-primary-asat", "xgb-primary-v6-models")
sub_sig <- paste(vapply(SUBDIRS, function(d) paste0(d, "=", if (dir.exists(file.path(src_output, d))) quick_tree_sig(file.path(src_output, d)) else "absent"), ""), collapse = "|")
input_sig <- quick_md5(paste(top_sig, sub_sig, sep = "##"))

# CODE: everything a harness loads or compiles (R/, scripts/, src/ -- load_all() compiles
# src/seat_sim_core.cpp -- plus DESCRIPTION and NAMESPACE), as the commit plus a digest of the
# uncommitted diff and untracked files. This tool's own two files are excluded.
CODE_PATHS <- c("R", "scripts", "src", "DESCRIPTION", "NAMESPACE")
excl <- c(":(exclude)R/quick_arm.R", ":(exclude)scripts/quick_arm.R")
sh_checked <- function(...) {   # a git call that failed is an unreadable input, never an empty one
  r <- suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = FALSE))
  if (!is.null(attr(r, "status")) && attr(r, "status") != 0L) return(NULL)
  r
}
head_sha <- sh_checked("rev-parse", "--short=7", "HEAD")[1]
diff_txt <- sh_checked("diff", "HEAD", "--", CODE_PATHS, excl)
untracked <- sh_checked("ls-files", "--others", "--exclude-standard", "--", CODE_PATHS, excl)
if (is.null(head_sha) || is.na(head_sha) || is.null(diff_txt) || is.null(untracked)) {
  cat("quick_arm: WARNING git could not describe the code; the cache is bypassed for this call\n")
  code_hash <- quick_unreadable("git")
} else {
  dirty_txt <- c(diff_txt, unlist(lapply(untracked, function(f) c(f, readLines(f, warn = FALSE)))))
  code_hash <- if (length(dirty_txt)) sprintf("%sx%s", head_sha, substr(quick_md5(paste(dirty_txt, collapse = "\n")), 1, 8)) else head_sha
}
# EXTERNAL: the polling-anchor clone (HEAD plus its working-tree state) and the reference data
# (recursive size+mtime). Anything unreadable changes the key.
anchor_dir <- file.path(src_external, "aus-polling-analyser")
external_id <- paste(c(
  if (file.exists(file.path(anchor_dir, ".git"))) {
    h <- sh_checked("-C", anchor_dir, "rev-parse", "HEAD"); st <- sh_checked("-C", anchor_dir, "status", "--porcelain")
    if (is.null(h) || is.null(st)) quick_unreadable("anchor git") else paste0("anchor=", h[1], "/", quick_md5(paste(st, collapse = "\n")))
  } else paste0("anchor-files=", quick_tree_sig(anchor_dir)),
  paste0("reference=", quick_tree_sig(file.path(src_external, "reference"))), ""), collapse = ";")
key_of <- function(env) {
  quick_md5(paste(c("keyv2", code_hash, external_id, sims, input_sig, if (length(env)) paste0(names(env)[order(names(env))], "=", env[order(names(env))])), collapse = ";"))
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
    for (d in SUBDIRS)
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
    env = if (role == "base") base_env else arm_eff, named = names(if (role == "base") base_env else arm_eff), dir = cache_dir(key, U$id[i]), est = secs_guess(U$harness[i]))
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
  chk <- quick_hd1_check(hd1, names(env), task$named)   # (also: every switch the user NAMED must be listed, i.e. applied)
  if (!chk$ok)
    return(list(id = task$id, role = task$role, ok = FALSE, secs = 0, status = -1L,
                log = paste0(logf, if (chk$no_hd1) " (no HD1 line: cannot prove what was applied)" else "",
                             if (length(chk$foreign)) paste0(" (leaked switch(es): ", paste(chk$foreign, collapse = ","), ")") else "",
                             if (length(chk$missing)) paste0(" (HD1 does not list the switch(es) you named: ", paste(chk$missing, collapse = ","), "; never applied)") else "")))
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
  list(id = task$id, role = task$role, ok = ok, secs = secs, status = status, log = logf, seen = chk$seen)
}
res <- list()
if (length(tasks)) {
  tasks <- tasks[order(-vapply(tasks, function(t) t$est, 0))]
  for (i in seq_along(tasks)) { tasks[[i]]$qd <- qd; tasks[[i]]$sims <- sims }
  cat(sprintf("quick_arm: running %d harness run(s) on %d process(es) (est %.0f s)\n", length(tasks), slots,
              sum(vapply(tasks, function(t) t$est, 0)) / slots))
  # Compile ONCE here, in the slot the workers will load from (its src/ is a junction to the real
  # src/), so the workers' load_all() finds an up-to-date DLL and none of them compiles concurrently.
  cat("quick_arm: compiling once before the workers start\n")
  pkgbuild::compile_dll(roots[1], quiet = TRUE)
  cl <- parallel::makeCluster(min(slots, length(tasks)))
  parallel::clusterCall(cl, function(f) { source(f); NULL }, file.path(repo, "R", "quick_arm.R"))   # workers need quick_hd1_check()
  parallel::clusterApply(cl, seq_along(cl), function(i) { assign("SLOT", i, envir = globalenv()); NULL })
  res <- tryCatch(parallel::clusterApplyLB(cl, tasks, run_unit), finally = parallel::stopCluster(cl))
  for (r in res) cat(sprintf("  %-9s %-4s %s %5.0f s%s\n", r$id, r$role, if (r$ok) "ok " else "FAILED", r$secs,
                             if (r$ok) "" else paste0("  -> ", r$log)))
  if (!all(vapply(res, function(r) r$ok, NA))) stop("quick_arm: a harness run failed; see the log(s) above")
  cat(sprintf("quick_arm: HD1 verified on %d run(s): every named switch is listed as applied and none leaked in (arm run saw: %s)\n", length(res),
              paste(unique(unlist(lapply(res[vapply(res, function(r) r$role == "arm", NA)], function(r) r$seen))), collapse = " ")))
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
# "byte-identical" is CHECKED, not inferred from the 0.05 tolerance: the largest absolute difference
# over EVERY cell's predicted share and EVERY party's win probability, per election, must be exactly 0.
md <- quick_max_diff(as.data.frame(B_sd), as.data.frame(A_sd), as.data.frame(B_ap), as.data.frame(A_ap))
per <- merge(per, md, by = "pair", all = TRUE)
stopifnot(!anyNA(per$max_diff))
identical_pairs <- per$max_diff == 0
touched <- per[!identical_pairs | per$changed > 0 | per$seats_changed > 0, ]
cat(sprintf("Q1  changed cells (|predicted share moved| > 0.05 percentage points; pred_share is in percent): %d of %d, in %d of %d election(s)\n",
            sum(per$changed), sum(per$cells), nrow(touched), nrow(per)))
cat(sprintf("    byte-identical to baseline (max |difference| over every cell share [points] and every party win probability [0-1] is exactly 0): %d of %d election(s)%s\n",
            sum(identical_pairs), nrow(per),
            if (all(identical_pairs)) "" else sprintf("; largest difference elsewhere: %.6g share points, %.6g win probability", max(per$max_share_diff), max(per$max_prob_diff))))
if (nrow(touched)) {
  cat("    per election (changed cells; squared-error change on them, lower is better; seat-winner log loss change, lower is better; max_share_diff in points, max_prob_diff in 0-1):\n")
  tt <- touched[order(touched$ll_change, decreasing = TRUE), ]
  print(data.frame(election = tt$pair, cells = tt$cells, changed = tt$changed, sq_err_change = round(tt$sq_err_change, 1),
                   seats = tt$seats, seats_moved = tt$seats_changed, ll_base = round(tt$ll_base, 4), ll_arm = round(tt$ll_arm, 4),
                   ll_change = round(tt$ll_change, 4), max_share_diff = signif(tt$max_share_diff, 4), max_prob_diff = signif(tt$max_prob_diff, 4)), row.names = FALSE)
}
p <- sd_res$primary
if (is.na(p$se)) {
  cat(sprintf("Q2  share-level squared error on the %d changed cell(s) in %d election(s): %s\n", p$n, p$clusters, quick_q2_verdict(p)))
} else {
  cat(sprintf("Q2  share-level squared error on %d changed cells: %.1f -> %.1f, change %+.1f (%+.0f%%), SE %.1f (clustered on election, %d elections) => %s\n",
              p$n, p$base, p$arm, p$change, 100 * p$change / p$base, p$se, p$clusters, quick_q2_verdict(p)))
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
