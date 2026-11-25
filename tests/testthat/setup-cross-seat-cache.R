# Never let a test write the cross-seat memo to output/cache/ (R/cross_seat_vote.R).
#
# A setup-*.R file, NOT a helper: testthat runs setup files only when tests run
# (test_dir, test_local, test_check), while devtools::load_all() sources every
# tests/testthat/helper*.R. Every pipeline script starts with load_all(), so as a
# helper this pointed each fit_seats_full.R process at its own fresh temp
# directory and the disk memo never survived a process (found 2026-11-25: every
# CI what-if scenario recomputed the independent person cells, ~60 s each).
# A TESTTHAT=true guard on the helper does not work either: test_local() runs
# load_all() before it sets TESTTHAT, so the redirect was skipped there.
Sys.setenv(AUSPOL_CROSS_SEAT_CACHE_DIR = tempfile("cross-seat-cache-"))
