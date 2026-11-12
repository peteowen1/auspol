# Per-step checkpoints for the night replays (night_replay_feed.R, night_replay_vec.R). Sourced, not run.
#
# A replay is 30-40 independent time steps (each step re-simulates from scratch at its own cut-off with the state's
# fixed seed), and used to write only at the end: a run killed at 90% of 18 minutes left nothing. Now every step
# rewrites <out>/<prefix>-<kind>.partial.csv (atomically: temp file, then rename), and --resume=1 reloads them and
# skips the times already done, so a resumed run writes the same files as an unbroken one. The summary partial is
# written LAST in each step and is the record of which times are done; rows of other kinds at a time missing from it
# (a kill between two renames) are dropped on load. Check codes NRC1-NRC3.
#
# The partial files are keyed by night and label only, so a resume with the same label and different flags would mix
# two configurations (review, 11 Nov 2026). Each run writes <prefix>.settings.txt (its arguments except --resume and
# --stop-after, and every AUSPOL_* variable) and a resume whose settings differ stops (NRC3).
ckpt_path <- function(out_dir, prefix, kind) file.path(out_dir, sprintf("%s-%s.partial.csv", prefix, kind))

ckpt_settings <- function(args = commandArgs(trailingOnly = TRUE), env = Sys.getenv()) {
  args <- sort(args[!grepl("^--(resume|stop-after)=", args)])
  ev <- env[grepl("^AUSPOL_", names(env))]; ev <- ev[order(names(ev))]
  c(paste0("arg ", args), if (length(ev)) paste0("env ", names(ev), "=", unname(ev)))
}
ckpt_settings_path <- function(out_dir, prefix) file.path(out_dir, sprintf("%s.settings.txt", prefix))

ckpt_load <- function(out_dir, prefix, kinds, resume, settings = ckpt_settings()) {
  stopifnot(kinds[1] == "summary")
  res <- stats::setNames(rep(list(list()), length(kinds)), kinds)
  sf <- ckpt_settings_path(out_dir, prefix)
  if (resume && file.exists(ckpt_path(out_dir, prefix, "summary"))) {
    if (!file.exists(sf)) stop("NRC3! --resume=1 but ", sf, " is missing: the partial files' settings are unknown; rerun without --resume")
    old <- readLines(sf)
    if (!identical(old, settings)) stop("NRC3! --resume=1 with different settings from the partial files (", prefix, "): only before: ",
                                         paste(setdiff(old, settings), collapse = "; "), " | only now: ", paste(setdiff(settings, old), collapse = "; "))
  }
  if (!resume) {
    old <- file.exists(ckpt_path(out_dir, prefix, kinds))
    if (any(old)) { cat(sprintf("NRC1 %s: %d stale partial file(s) removed (no --resume=1)\n", prefix, sum(old))); unlink(ckpt_path(out_dir, prefix, kinds)) }
    writeLines(settings, sf)   # after the stale partials are gone, so old rows never sit under new settings
    return(list(rows = res, done = character(0)))
  }
  writeLines(settings, sf)
  f <- ckpt_path(out_dir, prefix, "summary")
  if (!file.exists(f)) { cat(sprintf("NRC1 %s: --resume=1 but no partial summary, starting from the first time\n", prefix)); return(list(rows = res, done = character(0))) }
  rd <- function(k) data.table::fread(ckpt_path(out_dir, prefix, k), colClasses = list(character = "time"), showProgress = FALSE)
  S <- rd("summary"); done <- S$time
  if (anyDuplicated(done)) stop("NRC2! partial summary for ", prefix, " repeats a time: ", paste(unique(done[duplicated(done)]), collapse = ", "))
  res$summary <- list(S)
  for (k in kinds[-1]) if (file.exists(ckpt_path(out_dir, prefix, k))) {
    x <- rd(k); n0 <- nrow(x); x <- x[x$time %in% done]
    if (nrow(x) < n0) cat(sprintf("NRC1 %s: %d %s row(s) at a time not in the summary dropped (killed mid-save)\n", prefix, n0 - nrow(x), k))
    res[[k]] <- list(x)
  }
  cat(sprintf("NRC1 %s: resuming, %d time(s) already done (%s to %s)\n", prefix, length(done), done[1], done[length(done)]))
  list(rows = res, done = done)
}

ckpt_save <- function(out_dir, prefix, rows) {
  for (k in c(setdiff(names(rows), "summary"), "summary")) if (length(rows[[k]])) {
    f <- ckpt_path(out_dir, prefix, k); tmp <- paste0(f, ".tmp")
    data.table::fwrite(data.table::rbindlist(rows[[k]], fill = TRUE), tmp)
    if (!isTRUE(file.rename(tmp, f))) stop("NRC2! could not rename ", tmp, " to ", f)
  }
}

ckpt_clear <- function(out_dir, prefix, kinds) unlink(c(ckpt_path(out_dir, prefix, kinds), ckpt_settings_path(out_dir, prefix)))
