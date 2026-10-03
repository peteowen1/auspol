#' Helpers for the federal backtest's per-pair resume cache
#'
#' `scripts/backtest_candidate_fed.R` can save each pair the moment it is
#' scored and skip it on the next launch (`AUSPOL_FED_RESUME=1`, opt-in). These
#' helpers hold the decisions that must not be wrong, so they can be tested
#' without running the harness: when resuming is allowed, what the cache key is
#' made of, what a cached pair must still re-write, and that a failed write is
#' loud. All internal, no package state.
#'
#' A stale cache is the dangerous failure: it reads as a fast, successful run
#' and describes a model that no longer exists. Everything here errs towards
#' "do not resume".
#' @name fed_cache
#' @noRd
NULL

# Bumped when the shape of a cached pair changes, so an older file is refused.
FED_CACHE_SCHEMA <- 2L

#' Is the working tree clean over everything that changes a result?
#'
#' `.code_tag` (scripts/harness_defaults.R) only looks at `R/` and `scripts/`.
#' A change to `src/seat_sim_core.cpp` (the simulator) or `DESCRIPTION` moves
#' results too and was invisible to it.
#' @return `FALSE` clean, `TRUE` dirty, `NA` if git itself failed.
#' @noRd
fed_tree_dirty <- function(paths = c("R", "scripts", "src", "DESCRIPTION")) {
  out <- tryCatch(
    suppressWarnings(system2("git", c("status", "--porcelain", "--", paths),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) NULL)
  if (is.null(out) || !is.null(attr(out, "status"))) return(NA)
  length(out) > 0L
}

#' May a launch READ (and write) the per-pair cache?
#'
#' Opt-in: only `AUSPOL_FED_RESUME=1`. An empty git tag (not a checkout, so
#' nothing says which code made a cached pair) and a tag ending "x" or "?"
#' (uncommitted edits, or git failed) all refuse, as does a tree that is dirty
#' in `src/` or `DESCRIPTION`, which the tag does not see, and
#' `AUSPOL_DUMP_SHARES=1`, whose diagnostic dump files a resumed pair would
#' not rewrite.
#' @param env_value The value of `AUSPOL_FED_RESUME` ("" when unset).
#' @param code_tag The harness's `.code_tag`.
#' @param tree_dirty Result of [fed_tree_dirty()].
#' @param dump_shares The value of `AUSPOL_DUMP_SHARES` ("" when unset).
#' @return list(ok, requested, reason)
#' @noRd
fed_resume_decision <- function(env_value, code_tag, tree_dirty, dump_shares = "") {
  no <- function(why) list(ok = FALSE, requested = identical(env_value, "1"), reason = why)
  if (!identical(env_value, "1")) return(no("AUSPOL_FED_RESUME is not 1 (resume is opt-in)"))
  if (!is.character(code_tag) || length(code_tag) != 1L || is.na(code_tag) || !nzchar(code_tag))
    return(no("no git code tag (not a git checkout), so nothing says which code made a cached pair"))
  if (grepl("[x?]$", code_tag))
    return(no(sprintf("code tag %s: uncommitted edits in R/ or scripts/, or git status failed", code_tag)))
  if (!identical(tree_dirty, FALSE))
    return(no("working tree is dirty (or git failed) in R/, scripts/, src/ or DESCRIPTION"))
  if (identical(dump_shares, "1"))
    return(no("AUSPOL_DUMP_SHARES=1 writes per-pair dump files that a resumed pair would not rewrite"))
  list(ok = TRUE, requested = TRUE, reason = "committed, clean, resume requested")
}

#' The harness's CAL_TAG with the pair selection removed
#'
#' The "-p<pairs>" prefix and the AUSPOL_FED_PAIRS part of the arm fingerprint
#' both depend on which pairs one launch selected; a one-pair launch must be
#' able to reuse a pair a full launch saved. Refuses (loudly) if `cal_tag` is
#' not shaped as expected, because a wrong key is a silent wrong resume.
#' @param cal_tag The full CAL_TAG.
#' @param arm_fp The harness's `.arm_fingerprint` (the suffix before the code tag).
#' @param code_tag The harness's `.code_tag`.
#' @param pair_free_fp The fingerprint recomputed with AUSPOL_FED_PAIRS dropped.
#' @noRd
fed_pair_free_tag <- function(cal_tag, arm_fp, code_tag, pair_free_fp) {
  tail_part <- paste0(arm_fp, code_tag)
  if (!endsWith(cal_tag, tail_part))
    stop("CAL_TAG '", cal_tag, "' does not end with fingerprint+code tag '", tail_part,
         "'; refusing to derive a cache key from it")
  t0 <- sub("^-p[0-9]+", "", cal_tag)
  paste0(substr(t0, 1L, nchar(t0) - nchar(tail_part)), pair_free_fp, code_tag)
}

#' Every existing file that feeds a result, as a sorted character vector
#'
#' @param files Explicit files (missing ones are kept, so that appearance or
#'   disappearance of an input changes the stamp).
#' @param dirs Directories, listed recursively.
#' @param top Named list `dir = regex`: top-level (non-recursive) files of `dir`
#'   whose name matches.
#' @noRd
fed_input_files <- function(files = character(0), dirs = character(0), top = list()) {
  out <- as.character(files)
  for (d in dirs) {
    if (dir.exists(d)) {
      ff <- list.files(d, recursive = TRUE, full.names = TRUE, all.files = FALSE)
      ff <- ff[!grepl("(^|/)\\.git(/|$)", ff)]
      out <- c(out, ff)
    } else out <- c(out, paste0(d, "/"))   # an absent directory is itself recorded
  }
  for (d in names(top)) {
    if (dir.exists(d)) {
      ff <- list.files(d, pattern = top[[d]], full.names = TRUE)
      out <- c(out, ff[!dir.exists(ff)])
    }
  }
  sort(unique(out))
}

#' Size + mtime stamp of every input, hashed
#'
#' One md5 string over "path|size|mtime" lines, "absent" for a missing file.
#' @return A string with attribute `n` (number of inputs stamped).
#' @noRd
fed_input_stamp <- function(files = character(0), dirs = character(0), top = list()) {
  paths <- fed_input_files(files, dirs, top)
  fi <- file.info(paths)
  lines <- ifelse(is.na(fi$size), paste0(paths, "|absent"),
                  sprintf("%s|%s|%s", paths, fi$size, format(as.numeric(fi$mtime), digits = 15, nsmall = 3)))
  h <- digest::digest(lines, algo = "md5")
  structure(h, n = length(paths), n_absent = sum(is.na(fi$size)))
}

#' Is a cached pair usable by this launch?
#' @noRd
fed_cache_valid <- function(z, stamp, tag) {
  is.list(z) &&
    identical(z$schema, FED_CACHE_SCHEMA) &&
    all(c("res", "full", "share_detail", "tot", "sd_w", "wall", "scen", "stamp", "tag") %in% names(z)) &&
    identical(as.character(z$stamp), as.character(stamp)) &&
    identical(z$tag, tag)
}

#' Write a cache file atomically and FAIL LOUDLY if it did not land
#'
#' `file.rename()` returns FALSE (not an error) on failure, which is how a
#' resume cache ends up silently never written.
#' @noRd
fed_cache_save <- function(obj, file) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  tmp <- paste0(file, ".tmp")
  saveRDS(obj, tmp)
  ok <- file.rename(tmp, file)
  if (!isTRUE(ok) || !file.exists(file)) {
    stop("pair cache rename failed: ", tmp, " -> ", file,
         " (tmp exists: ", file.exists(tmp), ")")
  }
  invisible(file)
}

#' Path of a pair's final-two scenario file
#'
#' Uses the CURRENT launch's CAL_TAG, which carries the "-p" suffix and the
#' fingerprint that the cache key drops.
#' @noRd
fed_ourtcp_file <- function(to, cal_tag, dir = "output") {
  file.path(dir, sprintf("backtest-fed%d-ourtcp%s.csv", as.integer(to), cal_tag))
}

#' Re-write the side files a computed pair writes, for a resumed pair
#'
#' Currently one: the `-ourtcp` scenario CSV. (The AUSPOL_DUMP_SHARES dumps are
#' the other side files; they disable resume instead, see [fed_resume_decision()].)
#' @return The paths written (character(0) if the pair had no scenarios).
#' @noRd
fed_rewrite_side_files <- function(cached, to, cal_tag, dir = "output") {
  sc <- cached$scen
  if (is.null(sc) || !nrow(sc)) return(character(0))
  f <- fed_ourtcp_file(to, cal_tag, dir)
  data.table::fwrite(sc, f)
  if (!file.exists(f)) stop("failed to re-write ", f)
  f
}

#' Does the correlation matrix a pair is about to be simulated with belong to it?
#'
#' The 2026-10-03 loop leak (docs/reviews/party-cor-loop-leak-2026-10-03.md)
#' simulated every pair with the LAST pair's matrix while the log line said
#' otherwise. A leave-one-out source names the pair held out; that must be this
#' pair. NULL (independent draws) and the all-pairs sources name no pair.
#' @noRd
fed_check_cor_pair <- function(party_cor, to) {
  if (is.null(party_cor)) return(invisible(TRUE))
  src <- attr(party_cor, "cor_source")
  if (is.null(src) || !is.character(src) || length(src) != 1L)
    stop("fed", to, ": party correlation matrix has no cor_source attribute")
  if (grepl("held out", src, fixed = TRUE) &&
      !grepl(sprintf("(fed%d held out)", as.integer(to)), src, fixed = TRUE))
    stop("fed", to, " would be simulated with another pair's correlation matrix: ", src)
  invisible(TRUE)
}
