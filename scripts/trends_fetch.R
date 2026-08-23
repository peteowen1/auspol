# Google Trends fetching that CANNOT report a number on a partial sample.
#
# On 2026-08-23 a state-level comparison printed "AUC national 0.850 | AUC
# state-level 0.775" from 9 of 22 candidates. Every NSW batch had been rejected
# by Google, the loop hit `next` without a counter, and the survivors were
# almost all Victorian. Allegra Spender polled 34.9% in Wentworth and was simply
# absent from the table -- which is what made it obvious something was wrong,
# and nothing in the output said so.
#
# gtrendsR surfaces a rejection as `widget$status_code == 200 is not TRUE`, an
# assertion failure carrying no status code, so a rejection is indistinguishable
# from a bug unless the caller keeps count. Two rules here:
#
#   1. every batch outcome is recorded, and
#   2. trends_require_complete() ABORTS rather than let a caller score a subset.

suppressMessages(library(gtrendsR))

TRENDS_CACHE <- file.path("external", "reference", "trends")
dir.create(TRENDS_CACHE, showWarnings = FALSE, recursive = TRUE)

.trends_log <- new.env(parent = emptyenv())
.trends_log$rows <- list()

trends_reset <- function() .trends_log$rows <- list()

.trends_note <- function(geo, keywords, status, detail = "") {
  .trends_log$rows[[length(.trends_log$rows) + 1L]] <- data.frame(
    geo = geo, n_kw = length(keywords), status = status, detail = detail,
    keywords = paste(keywords, collapse = " | "), stringsAsFactors = FALSE
  )
}

# One batch: the anchor plus up to 4 keywords, returned as mean interest per
# keyword relative to the anchor. Retries with exponential backoff, because a
# rejection is usually rate limiting and usually transient.
trends_batch <- function(keywords, geo, from, to, anchor = "Anthony Albanese",
                         tries = 4L, base_wait = 30) {
  key <- gsub("[^A-Za-z0-9]", "_",
              paste(geo, from, to, anchor, paste(keywords, collapse = "-"), sep = "-"))
  f <- file.path(TRENDS_CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) {
    .trends_note(geo, keywords, "cached")
    return(readRDS(f))
  }
  last <- ""
  for (attempt in seq_len(tries)) {
    r <- tryCatch(
      gtrends(keyword = c(anchor, keywords), geo = geo,
              time = paste(from, to), onlyInterest = TRUE),
      error = function(e) { last <<- conditionMessage(e); NULL }
    )
    if (!is.null(r) && !is.null(r$interest_over_time)) {
      d <- as.data.frame(r$interest_over_time)
      d$hits <- suppressWarnings(as.numeric(gsub("<", "", d$hits)))
      d$hits[is.na(d$hits)] <- 0
      a <- tapply(d$hits, d$keyword, mean, na.rm = TRUE)
      if (!anchor %in% names(a)) {
        .trends_note(geo, keywords, "FAILED", "anchor absent from response")
        return(NULL)
      }
      out <- a / max(a[[anchor]], 1e-9)
      saveRDS(out, f)
      .trends_note(geo, keywords, "ok",
                   if (attempt > 1L) sprintf("succeeded on attempt %d", attempt) else "")
      Sys.sleep(base_wait / 3)
      return(out)
    }
    if (attempt < tries) Sys.sleep(base_wait * 2^(attempt - 1L))
  }
  .trends_note(geo, keywords, "FAILED", sprintf("%d attempts: %s", tries, last))
  NULL
}

trends_report <- function() {
  if (!length(.trends_log$rows)) {
    cat("TRENDS: no batches attempted\n")
    return(invisible(NULL))
  }
  d <- do.call(rbind, .trends_log$rows)
  cat(sprintf("\nTRENDS %d batches: %d ok, %d cached, %d FAILED\n",
              nrow(d), sum(d$status == "ok"), sum(d$status == "cached"),
              sum(d$status == "FAILED")))
  bad <- d[d$status == "FAILED", , drop = FALSE]
  if (nrow(bad)) {
    for (i in seq_len(nrow(bad))) {
      cat(sprintf("TRENDS   FAILED %-8s %s  [%s]\n",
                  bad$geo[i], bad$keywords[i], bad$detail[i]))
    }
  }
  invisible(d)
}

# The guard. Call before computing ANY statistic over the results.
trends_require_complete <- function(expected_names, got_names, what) {
  missing <- setdiff(expected_names, got_names)
  if (length(missing)) {
    trends_report()
    stop(sprintf(paste0("%s: %d of %d keywords missing, so no statistic may be ",
                        "computed over this sample. Missing: %s"),
                 what, length(missing), length(expected_names),
                 paste(missing, collapse = ", ")), call. = FALSE)
  }
  cat(sprintf("TRENDS %s: complete, %d of %d keywords present\n",
              what, length(got_names), length(expected_names)))
  invisible(TRUE)
}
