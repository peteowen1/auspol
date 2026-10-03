# Helpers behind the federal backtest's per-pair resume cache (R/fed_cache.R).
# None of these runs the harness; each pins one way a resumed run could
# silently describe a model that no longer exists.

test_that("resume is opt-in: unset, 0 and anything but 1 refuse", {
  for (v in c("", "0", "true", "yes")) {
    d <- fed_resume_decision(v, "-gabc1234", FALSE)
    expect_false(d$ok, info = v)
  }
  expect_true(fed_resume_decision("1", "-gabc1234", FALSE)$ok)
})

test_that("an empty git tag, an x/? tag, a dirty or unknown tree and dump mode all refuse", {
  expect_false(fed_resume_decision("1", "", FALSE)$ok)           # not a git checkout
  expect_false(fed_resume_decision("1", "-gabc1234x", FALSE)$ok) # uncommitted R/ or scripts/
  expect_false(fed_resume_decision("1", "-gabc1234?", FALSE)$ok) # git status failed
  expect_false(fed_resume_decision("1", "-gabc1234", TRUE)$ok)   # dirty in src/ or DESCRIPTION
  expect_false(fed_resume_decision("1", "-gabc1234", NA)$ok)     # git failed
  expect_false(fed_resume_decision("1", "-gabc1234", FALSE, dump_shares = "1")$ok)
  expect_true(fed_resume_decision("1", "-gabc1234", FALSE, dump_shares = "0")$ok)
  expect_match(fed_resume_decision("1", "", FALSE)$reason, "no git code tag")
  expect_true(fed_resume_decision("1", "", FALSE)$requested)     # so the harness prints WHY
})

test_that("fed_tree_dirty sees src/ and DESCRIPTION, and reports NA outside a repo", {
  skip_if(!nzchar(Sys.which("git")), "git not available")
  td <- tempfile("fedrepo"); dir.create(td); on.exit(unlink(td, recursive = TRUE), add = TRUE)
  g <- function(...) system2("git", c("-C", td, "-c", "user.email=t@t", "-c", "user.name=t", ...),
                             stdout = FALSE, stderr = FALSE)
  g("init", "-q")
  for (d in c("R", "scripts", "src")) dir.create(file.path(td, d))
  writeLines("a", file.path(td, "R", "a.R")); writeLines("a", file.path(td, "scripts", "s.R"))
  writeLines("int x;", file.path(td, "src", "sim.cpp")); writeLines("Package: x", file.path(td, "DESCRIPTION"))
  g("add", "."); g("commit", "-q", "-m", "init")
  withr::with_dir(td, {
    expect_false(fed_tree_dirty())
    writeLines("int y;", file.path(td, "src", "sim.cpp"))
    expect_true(fed_tree_dirty())
    g("checkout", "--", "src/sim.cpp")
    expect_false(fed_tree_dirty())
    writeLines("Package: y", file.path(td, "DESCRIPTION"))
    expect_true(fed_tree_dirty())
  })
  nogit <- tempfile("nogit"); dir.create(nogit); on.exit(unlink(nogit, recursive = TRUE), add = TRUE)
  withr::with_dir(nogit, expect_true(is.na(fed_tree_dirty())))
})

test_that("the pair-free key is the same for a one-pair launch and a full launch", {
  full  <- "-fc-sh01-abc123-gabc1234"
  one   <- paste0("-p2022", full)
  # Same arm; the fingerprint of the full launch has no AUSPOL_FED_PAIRS in it
  # and the one-pair launch's differs, but the pair-free fingerprint is shared.
  k_full <- fed_pair_free_tag(full, "-abc123", "-gabc1234", "-zzz999")
  k_one  <- fed_pair_free_tag(one, "-abc123", "-gabc1234", "-zzz999")
  expect_identical(k_full, k_one)
  expect_identical(k_full, "-fc-sh01-zzz999-gabc1234")
  # A different code version or different arm gives a different key.
  expect_false(identical(k_full, fed_pair_free_tag(full, "-abc123", "-gabc1234", "-yyy000")))
  expect_false(identical(k_full, fed_pair_free_tag("-fc-sh01-abc123-gdef5678", "-abc123", "-gdef5678", "-zzz999")))
  # No fingerprint and no pairs at all.
  expect_identical(fed_pair_free_tag("-fc-gabc1234", "", "-gabc1234", ""), "-fc-gabc1234")
  # A tag that does not end as the harness says is refused, not guessed at.
  expect_error(fed_pair_free_tag("-fc-other", "-abc123", "-gabc1234", ""), "refusing")
})

test_that("the input stamp moves when any listed input moves, and only then", {
  td <- tempfile("fedin"); dir.create(td); on.exit(unlink(td, recursive = TRUE), add = TRUE)
  out <- file.path(td, "output"); ext <- file.path(td, "anchor", "analysis", "Data")
  asat <- file.path(out, "xgb-primary-asat"); corpus <- file.path(td, "elections")
  for (d in c(out, ext, asat, corpus)) dir.create(d, recursive = TRUE)
  wr <- function(f, x) writeLines(x, f)
  wr(file.path(corpus, "aec-fed-firstprefs.csv"), "a")
  wr(file.path(out, "xgb-primary-v6-oof-predictions.csv"), "oof")
  wr(file.path(out, "level-pred.csv"), "lp")
  wr(file.path(out, "candidacies.csv"), "c")
  wr(file.path(out, "unrelated-notes.txt"), "n")
  wr(file.path(asat, "fed2010.ubj"), "model")
  wr(file.path(ext, "poll-data-fed.csv"), "polls")
  st <- function() fed_input_stamp(
    files = file.path(corpus, "aec-fed-firstprefs.csv"),
    dirs = c(corpus, asat, ext),
    top = setNames(list("^(xgb-primary-|level-pred|candidacies)"), out))
  s0 <- st()
  expect_identical(as.character(s0), as.character(st()))           # stable
  expect_gt(attr(s0, "n"), 5L)
  bump <- function(f, new = "changed contents") {                   # size change
    wr(f, new); s <- as.character(st()); s
  }
  mt <- function(f) Sys.setFileTime(f, Sys.time() + 3600)           # mtime-only change
  cases <- list(
    oof     = file.path(out, "xgb-primary-v6-oof-predictions.csv"),
    levelp  = file.path(out, "level-pred.csv"),
    cand    = file.path(out, "candidacies.csv"),
    asat    = file.path(asat, "fed2010.ubj"),
    polls   = file.path(ext, "poll-data-fed.csv"),
    corpus  = file.path(corpus, "aec-fed-firstprefs.csv"))
  for (nm in names(cases)) {
    f <- cases[[nm]]; orig <- readLines(f)
    before <- as.character(st())
    mt(f); expect_false(identical(before, as.character(st())), info = paste("mtime", nm))
    wr(f, orig); Sys.setFileTime(f, Sys.time() - 7200)              # restore a distinct mtime
    base <- as.character(st())
    wr(f, "a much longer body than before"); expect_false(identical(base, as.character(st())), info = paste("size", nm))
    wr(f, orig); Sys.setFileTime(f, Sys.time() - 7200)
  }
  # A new file in a stamped directory, and a new matching top-level file.
  base <- as.character(st())
  wr(file.path(asat, "fed2013.ubj"), "m2"); expect_false(identical(base, as.character(st())))
  unlink(file.path(asat, "fed2013.ubj")); base <- as.character(st())
  expect_identical(base, as.character(st()))
  wr(file.path(out, "salience-v6.csv"), "x")                        # not matched by THIS pattern
  expect_identical(base, as.character(st()))
  wr(file.path(out, "xgb-primary-new.csv"), "x")                    # matched
  expect_false(identical(base, as.character(st())))
  # An unrelated top-level file changing does not invalidate the cache.
  base <- as.character(st()); wr(file.path(out, "unrelated-notes.txt"), "a different note")
  expect_identical(base, as.character(st()))
  # A listed file that is missing is recorded, and its arrival changes the stamp.
  gone <- file.path(td, "nowhere.csv")
  a <- fed_input_stamp(files = gone); wr(gone, "now here")
  expect_false(identical(as.character(a), as.character(fed_input_stamp(files = gone))))
  expect_equal(attr(a, "n_absent"), 1L)
})

test_that("a cached pair is valid only for the same stamp, tag, schema and fields", {
  z <- list(schema = FED_CACHE_SCHEMA, res = 1, full = 1, share_detail = 1, tot = 1,
            sd_w = 1, wall = 1, scen = NULL, stamp = "S", tag = "T")
  expect_true(fed_cache_valid(z, "S", "T"))
  expect_false(fed_cache_valid(z, "S2", "T"))
  expect_false(fed_cache_valid(z, "S", "T2"))
  expect_false(fed_cache_valid(NULL, "S", "T"))
  z2 <- z; z2$schema <- 1L; expect_false(fed_cache_valid(z2, "S", "T"))
  z3 <- z; z3$stamp <- NULL; expect_false(fed_cache_valid(z3, "S", "T"))
  z4 <- z; z4["scen"] <- NULL; expect_false(fed_cache_valid(z4, "S", "T"))  # field absent
  # scen = NULL must survive a save/read round trip as a PRESENT field.
  f <- tempfile(fileext = ".rds"); on.exit(unlink(f), add = TRUE)
  fed_cache_save(z, f)
  expect_true(fed_cache_valid(readRDS(f), "S", "T"))
})

test_that("a failed rename is an error, not a silent missing cache", {
  td <- tempfile("fedsave"); dir.create(td); on.exit(unlink(td, recursive = TRUE), add = TRUE)
  target <- file.path(td, "pair.rds")
  dir.create(target)                                   # a directory in the way: rename cannot succeed
  expect_error(fed_cache_save(list(a = 1), target), "rename failed")
  ok <- file.path(td, "sub", "ok.rds")
  expect_equal(fed_cache_save(list(a = 1), ok), ok)    # creates the directory
  expect_identical(readRDS(ok)$a, 1)
  expect_false(file.exists(paste0(ok, ".tmp")))
})

test_that("a resumed pair re-writes its ourtcp file under the CURRENT cal_tag", {
  td <- tempfile("fedtcp"); dir.create(td); on.exit(unlink(td, recursive = TRUE), add = TRUE)
  sc <- data.table::data.table(seat = c("A", "B"), scenario = c("ALP-LNP", "ALP-GRN"), freq = c(0.7, 0.3))
  cached <- list(scen = sc)
  f <- fed_rewrite_side_files(cached, 2022, "-p2022-fc-abc123-gabc1234", dir = td)
  expect_equal(basename(f), "backtest-fed2022-ourtcp-p2022-fc-abc123-gabc1234.csv")
  expect_true(file.exists(f))
  expect_equal(as.data.frame(data.table::fread(f)), as.data.frame(sc))
  # A different launch (full run, different suffix and fingerprint) names its own file.
  f2 <- fed_rewrite_side_files(cached, 2022, "-fc-def456-gabc1234", dir = td)
  expect_false(identical(f, f2)); expect_true(file.exists(f2))
  # No scenarios: nothing written, and the caller can tell.
  expect_identical(fed_rewrite_side_files(list(scen = NULL), 2019, "-x", dir = td), character(0))
  expect_identical(fed_rewrite_side_files(list(scen = sc[0]), 2019, "-x", dir = td), character(0))
  expect_false(file.exists(file.path(td, "backtest-fed2019-ourtcp-x.csv")))
})

test_that("a pair is refused another pair's correlation matrix", {
  m <- function(src) structure(diag(2), cor_source = src)
  expect_true(fed_check_cor_pair(NULL, 2019))
  expect_true(fed_check_cor_pair(m("leave-one-out, 14 pairs (fed2019 held out)"), 2019))
  expect_error(fed_check_cor_pair(m("leave-one-out, 14 pairs (fed2025 held out)"), 2019), "another pair")
  expect_true(fed_check_cor_pair(m("all 15 pairs (live forecast: nothing to leave out)"), 2019))
  expect_error(fed_check_cor_pair(structure(diag(2)), 2019), "no cor_source")
})

test_that("the federal harness carries PARTY_COR per pair into the simulation loop", {
  # Static check of the script text: the loop leak was two loops sharing a global.
  f <- testthat::test_path("..", "..", "scripts", "backtest_candidate_fed.R")
  skip_if(!file.exists(f), "scripts/ is not part of the built package")
  src <- readLines(f, warn = FALSE)
  src <- src[!grepl("^\\s*#", src)]
  txt <- paste(src, collapse = "\n")
  expect_match(txt, "PARTY_COR\\s*=\\s*PARTY_COR\\s*\\)")           # in the out_all payload
  loop_at <- regexpr("for \\(X in out_all\\) \\{", txt)
  expect_gt(loop_at, 0)
  body <- substr(txt, loop_at, nchar(txt))
  expect_match(body, "PARTY_COR <- X\\$PARTY_COR")                    # reset inside the simulation loop
  # ...and BEFORE the simulator call that reads the global.
  expect_lt(regexpr("PARTY_COR <- X\\$PARTY_COR", body), regexpr("party_cor = PARTY_COR", body))
})
