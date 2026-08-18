# Was a failed pipeline stage a check firing, or the script being broken?
#
# These need different reactions. A pre-registered check failing means the model
# needs attention; a crash means the script cannot run and nothing it printed
# can be trusted. Reporting one as the other is how a broken fit_federal.R
# survived in the pipeline output labelled "CHECK FAILED" until a reviewer ran
# the script by hand.
#
# Two wrong versions preceded this one, in opposite directions:
#
#   1. "did the stage print any check line before dying?" -- fit_federal.R
#      printed FL1, then hit an undefined variable, and was called a failed
#      check.
#   2. "does the error say 'is not TRUE'?" -- that is only stopifnot(). This
#      repo's most substantive checks are bare stop() calls with hand-written
#      messages (S5 in fit_seats_full.R, G2/G3/G7 in build_page.R and
#      backtest_flows.R), so nearly every real check would have been called a
#      crash.
#
# So classify on POSITIVE evidence of each, and refuse to guess when there is
# none. "unclassified" is a worse-looking output than a confident label and a
# better one than a wrong label.

#' Classify a failed stage's error text
#'
#' @param text Error line(s) from the stage, or `character(0)`.
#' @return One of `"check"`, `"crash"`, `"unclassified"`, `"none"`.
#' @export
classify_stage_failure <- function(text) {
  text <- text[nzchar(trimws(text))]
  if (!length(text)) return("none")
  one <- paste(text, collapse = " ")

  # A crash signature is checked FIRST and wins ties. An R runtime error can
  # quote a check code in its call (`Error in check_S5(x) : object 'y' not
  # found`), so matching the code alone would call it a check. There is no
  # symmetric hazard the other way: a hand-written check message does not
  # accidentally contain "object 'x' not found".
  crash_signs <- paste(
    "object '[^']*' not found",
    "could not find function",
    "subscript out of bounds",
    "argument .* is missing, with no default",
    "non-numeric argument",
    "missing value where TRUE/FALSE needed",
    "cannot open|no such file|does not exist",
    "unused argument",
    "invalid 'times' argument",
    "attempt to select (less|more) than one element",
    "\\$ operator is invalid",
    sep = "|")
  if (grepl(crash_signs, one)) return("crash")

  # stopifnot(), and the same phrasing R uses for a vector condition.
  if (grepl("is not TRUE|are not all TRUE", one)) return("check")

  # A hand-written stop() from a pre-registered check names its code. Same
  # pattern the run summary uses to pick check lines out of stdout, anchored to
  # the start of the message rather than the line, because R prefixes the call:
  # "Error in f(x) : S5 FAILED: ...".
  if (grepl("(^|: )[A-Z]{1,2}[0-9]+[a-c]?[ :]", one)) return("check")

  "unclassified"
}

#' Human-readable label for a stage failure
#'
#' @param kind Result of [classify_stage_failure()].
#' @return A short label for the run summary.
#' @export
stage_failure_label <- function(kind) {
  switch(kind,
         check = "CHECK FAILED",
         crash = "CRASHED",
         none = "FAILED (no error text)",
         "FAILED (unclassified)")
}
