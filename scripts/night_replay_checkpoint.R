# Per-step checkpoints for the night replays (night_replay_feed.R, night_replay_vec.R). Sourced, not run.
#
# A replay is 30-40 independent time steps (each step re-simulates from scratch at its own cut-off with the state's
# fixed seed), and used to write only at the end: a run killed at 90% of 18 minutes left nothing. Now every step
# rewrites <out>/<prefix>-<kind>.partial.csv (atomically: temp file, then rename), and --resume=1 reloads them and
# skips the times already done, so a resumed run writes the same files as an unbroken one. The summary partial is
# written LAST in each step and is the record of which times are done; rows of other kinds at a time missing from it
# (a kill between two renames) are dropped on load. Check codes NRC1-NRC2.
ckpt_path <- function(out_dir, prefix, kind) file.path(out_dir, sprintf("%s-%s.partial.csv", prefix, kind))

ckpt_load <- function(out_dir, prefix, kinds, resume) {
  stopifnot(kinds[1] == "summary")
  res <- stats::setNames(rep(list(list()), length(kinds)), kinds)
  if (!resume) {
    old <- file.exists(ckpt_path(out_dir, prefix, kinds))
    if (any(old)) { cat(sprintf("NRC1 %s: %d stale partial file(s) removed (no --resume=1)\n", prefix, sum(old))); unlink(ckpt_path(out_dir, prefix, kinds)) }
    return(list(rows = res, done = character(0)))
  }
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

ckpt_clear <- function(out_dir, prefix, kinds) unlink(ckpt_path(out_dir, prefix, kinds))
