# Two previous versions of this classifier were wrong in opposite directions, so
# the tests use the ACTUAL message shapes this repo produces rather than
# invented ones. Each case names where it comes from.

test_that("stopifnot failures are checks", {
  expect_equal(classify_stage_failure(
    "Error: all(abs(share_sums - 100) <= 5) is not TRUE"), "check")
  expect_equal(classify_stage_failure(
    "Error: !any(vapply(nsw_track, function(x) any(x$breach), TRUE)) is not TRUE"),
    "check")
  expect_equal(classify_stage_failure(
    "Error in f(x) : arguments are not all TRUE"), "check")
})

test_that("bare stop() checks that name their code are checks", {
  # This is the shape the SECOND wrong version missed. fit_seats_full.R's S5,
  # build_page.R's G2/G7, backtest_flows.R's G3 are all bare stop() calls with
  # hand-written messages -- the repo's most substantive checks.
  expect_equal(classify_stage_failure(
    "Error in g() : S5 FAILED: the two seat models disagree, gap 7"), "check")
  expect_equal(classify_stage_failure(
    "Error: G7 the fit being published is structurally invalid"), "check")
  expect_equal(classify_stage_failure(
    "Error in check() : NL4a max residual autocorrelation exceeded"), "check")
})

test_that("R runtime errors are crashes", {
  # The exact message that started this: fit_federal.R, 2026-08-19.
  expect_equal(classify_stage_failure(
    "Error in fit_cycle(2022) : object 'ps' not found"), "crash")
  expect_equal(classify_stage_failure(
    "Error in x() : could not find function \"refold_unfitted\""), "crash")
  expect_equal(classify_stage_failure(
    "Error in v[[9]] : subscript out of bounds"), "crash")
  expect_equal(classify_stage_failure(
    "Error in if (x) 1 : missing value where TRUE/FALSE needed"), "crash")
  expect_equal(classify_stage_failure(
    "Error in anchor_data_path(f) : Anchor data not found at ... no such file"),
    "crash")
})

test_that("a crash inside a function whose NAME carries a check code is a crash", {
  # The reason crash signatures are tested before code-matching. R prefixes the
  # call, so a crash inside a check helper quotes the code and would otherwise
  # be read as the check firing.
  expect_equal(classify_stage_failure(
    "Error in S5_compare(x) : object 'seats' not found"), "crash")
})

test_that("no error text is reported as such, not guessed at", {
  expect_equal(classify_stage_failure(character(0)), "none")
  expect_equal(classify_stage_failure(c("", "   ")), "none")
})

test_that("an unrecognised error is UNCLASSIFIED rather than guessed", {
  # The whole point. Both earlier versions guessed and were confidently wrong;
  # a label that admits ignorance is better than one that misleads.
  expect_equal(classify_stage_failure(
    "Error in weird() : something nobody anticipated"), "unclassified")
})

test_that("labels are distinct and never claim more than the classification", {
  kinds <- c("check", "crash", "none", "unclassified")
  labs <- vapply(kinds, stage_failure_label, character(1))
  expect_equal(length(unique(labs)), 4L)
  expect_match(labs[["crash"]], "CRASH")
  expect_match(labs[["check"]], "CHECK")
  expect_match(labs[["unclassified"]], "unclassified")
})
