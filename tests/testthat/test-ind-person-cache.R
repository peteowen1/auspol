# AUSPOL_IND_PERSON_CACHE: the disk memo of the person cells and the carry-fit case table
# (R/ind_person.R). Same output as no memo; any change to an input misses.

ipc_corpus <- function() {
  r <- function(e, seat, given, sur, party, pcv, state = NA_character_, el = FALSE)
    data.frame(election = e, seat = seat, name = paste(given, toupper(sur)), surname = toupper(sur), given = given,
               party = party, pcv = pcv, state = state, elected = el, stringsAsFactors = FALSE)
  maj <- function(e, seats, st = NA_character_) do.call(rbind, lapply(seats, function(s)
    rbind(r(e, s, "Al", paste0("Alp", s), "ALP", 45, st), r(e, s, "Lee", paste0("Lnp", s), "LNP", 40, st))))
  rbind(
    maj("nsw2015", c("S1", "S2")), maj("nsw2019", c("S1", "S2", "S4")), maj("nsw2023", c("S3", "S4", "S9")),
    maj("fed2016", c("F1", "F2", "F3"), "NSW"),
    r("nsw2015", "S1", "Sam", "Roe", "IND", 20),
    r("nsw2019", "S1", "Sam", "Roe", "IND", 20),
    r("fed2016", "F2", "Pat", "Lee", "IND", 20, "NSW"),
    r("nsw2019", "S2", "Pat", "Lee", "IND", 10),
    r("fed2016", "F1", "Jane", "Smith", "IND", 30, "NSW"),
    r("nsw2019", "S4", "Kit", "Ng", "IND", 8),
    r("fed2016", "F3", "Kit", "Ng", "IND", 12, "NSW"),
    r("nsw2023", "S3", "Jane", "Smith", "IND", 25),
    r("fed2016", "F3", "Dana", "Boyd", "IND", 30, "NSW"),
    r("nsw2023", "S9", "Dana", "Boyd", "IND", 4))
}
ipc_shares <- function() {
  matrix(c(30, 30, 30, 30, 30, 30, 20, 20, 20, 20, 20, 20), nrow = 3,
         dimnames = list(c("S3", "S4", "S9"), c("ALP", "LNP", "GRN", "IND")))
}
# forget everything held in this session, so the next call has only the disk
ipc_forget <- function() {
  clear_cross_seat_cache()
  rm(list = setdiff(ls(.ip_memo, all.names = TRUE), ".code"), envir = .ip_memo)
}
ipc_run <- function(C) { out <- NULL; utils::capture.output(out <- ind_person_apply(ipc_shares(), "nsw2023", "final", corpus = C)); out }
ipc_n <- function(d) length(list.files(d, pattern = "^[0-9a-f]+--.*\\.rds$"))

test_that("the memo gives the same shares as no memo, and a fresh session reads it from disk", {
  d <- withr::local_tempdir()
  withr::local_envvar(AUSPOL_CROSS_SEAT_CACHE_DIR = d, AUSPOL_IND_PERSON = "final", AUSPOL_IND_PERSON_DIR = "both",
                      AUSPOL_IND_PERSON_CARRY = "ratio", AUSPOL_IND_RETURN = "0", AUSPOL_CROSS_SEAT_VOTE = "1")
  C <- ipc_corpus()
  withr::local_envvar(AUSPOL_IND_PERSON_CACHE = "0"); ipc_forget()
  off <- ipc_run(C)
  expect_false(identical(off, ipc_shares()))          # the rule did something, so the comparison is not vacuous
  withr::local_envvar(AUSPOL_IND_PERSON_CACHE = NA)   # unset = on
  d2 <- withr::local_tempdir(); withr::local_envvar(AUSPOL_CROSS_SEAT_CACHE_DIR = d2); ipc_forget()
  cold <- ipc_run(C)
  n_cold <- ipc_n(d2)
  ipc_forget()
  warm <- ipc_run(C)
  expect_identical(cold, off)
  expect_identical(warm, off)
  expect_identical(ipc_n(d2), n_cold)                 # nothing recomputed
  # the warm call really reads the stored cells: corrupt them and the output moves
  ipc_forget()
  fs <- list.files(d2, full.names = TRUE)
  hit <- 0L
  for (f in fs) {
    e <- readRDS(f)
    if (is.data.frame(e$value) && all(c("record", "record_election", "value") %in% names(e$value))) {
      e$value$record <- e$value$record / 2; e$value$value <- e$value$value / 2; saveRDS(e, f); hit <- hit + 1L
    }
  }
  expect_gt(hit, 0L)
  expect_false(identical(ipc_run(C), off))
})

test_that("a changed corpus, by-election file or switch misses; an unrelated switch hits", {
  d <- withr::local_tempdir()
  withr::local_envvar(AUSPOL_CROSS_SEAT_CACHE_DIR = d, AUSPOL_IND_PERSON = "final", AUSPOL_IND_PERSON_DIR = "both",
                      AUSPOL_IND_PERSON_CARRY = "linear", AUSPOL_IND_RETURN = "0", AUSPOL_IND_PERSON_CACHE = "1",
                      AUSPOL_TIME_FORWARD_FITS = NA, AUSPOL_BYELECTION_RESULTS = NA)
  C <- ipc_corpus()
  ipc_forget(); base <- ipc_run(C); n0 <- ipc_n(d)
  # a what-if scenario's switches are not read by this computation: a hit
  withr::local_envvar(AUSPOL_FORCE_FP = "ALP=30", AUSPOL_FORCE_FP_RULE = "draws", AUSPOL_OUT_SUFFIX = "-x")
  ipc_forget(); expect_identical(ipc_run(C), base); expect_identical(ipc_n(d), n0)
  # the corpus: one record edited
  C2 <- C; C2$pcv[C2$name == "Jane SMITH" & C2$election == "fed2016"] <- 20
  ipc_forget(); r2 <- ipc_run(C2)
  expect_gt(ipc_n(d), n0); expect_false(identical(r2, base))
  # a switch the computation reads
  n1 <- ipc_n(d)
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = "0")
  ipc_forget(); ipc_run(C); expect_gt(ipc_n(d), n1)
  withr::local_envvar(AUSPOL_TIME_FORWARD_FITS = NA)
  # the by-election results file named by AUSPOL_BYELECTION_RESULTS: its CONTENTS are in the key
  bf <- file.path(withr::local_tempdir(), "byelection-results.csv")
  writeLines("region,seat,date,candidate,party_raw,pct", bf)
  withr::local_envvar(AUSPOL_BYELECTION_RESULTS = bf)
  ipc_forget(); ipc_run(C); n2 <- ipc_n(d)
  ipc_forget(); ipc_run(C); expect_identical(ipc_n(d), n2)     # same contents: hit
  write("nsw,S1,2020-01-01,Ann Bee,Independent,40", bf, append = TRUE)
  ipc_forget(); ipc_run(C); expect_gt(ipc_n(d), n2)            # same path, new contents: miss
})

test_that("AUSPOL_IND_PERSON_CACHE takes only 0 or 1", {
  withr::local_envvar(AUSPOL_IND_PERSON_CACHE = "yes")
  expect_error(.ip_cache_on(), "must be")
})
