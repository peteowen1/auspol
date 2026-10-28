# Election-night runner (R/night_runner.R, map #148). Synthetic feeds only: the real VEC sample lives under external/
# (gitignored), which CI does not have.

nu_booths <- function(alp, lnp, booths, district = "Seat A") {
  data.table::rbindlist(lapply(seq_along(booths), function(i) data.table::data.table(
    district = district, booth = booths[i], booth_type = "ordinary",
    party = c("Australian Labor Party", "Liberal"), votes = c(alp[i], lnp[i]))))
}

nr_cand <- function(did, ids, aff, indep, votes) data.table::data.table(
  district_id = did, candidate_id = ids, name = paste("C", ids), ballot_position = seq_along(ids),
  affiliation_id = aff, independent = indep, votes = votes)

# A parsed-snapshot list shaped like vec_feed_read_lh() output: one district (Alpha) with two ordinary booths, one
# early voting centre, one mobile team, postal at district level only; one booth (Alpha South) has not reported.
nr_feed <- function() {
  cands <- nr_cand("100", c("1", "2", "3"), c("5", "8", NA), c(FALSE, FALSE, TRUE), c(70, 60, 10))
  bo <- data.table::rbindlist(list(
    data.table::data.table(district_id = "100", booth_id = "9", booth = "Alpha North", booth_class = "VotingCentre", candidate_id = c("1", "2", "3"), votes = c(20, 10, 2)),
    data.table::data.table(district_id = "100", booth_id = "10", booth = "Alpha South", booth_class = "VotingCentre", candidate_id = c("1", "2", "3"), votes = c(0, 0, 0)),
    data.table::data.table(district_id = "100", booth_id = "11", booth = "Alpha EVC", booth_class = "EarlyVotingCentre", candidate_id = c("1", "2", "3"), votes = c(30, 30, 4)),
    data.table::data.table(district_id = "100", booth_id = "12", booth = "Alpha Mobile", booth_class = "MobileVoting", candidate_id = c("1", "2", "3"), votes = c(5, 4, 1))))
  bty <- data.table::rbindlist(lapply(c("1", "2", "3"), function(cid) data.table::data.table(
    district_id = "100", candidate_id = cid,
    vote_type = c("Ordinary", "EVCEarly", "MobileVotingEarly", "Postal", "Early", "Absent"),
    votes = c(c(`1` = 20, `2` = 10, `3` = 2)[[cid]], c(`1` = 30, `2` = 30, `3` = 4)[[cid]], c(`1` = 5, `2` = 4, `3` = 1)[[cid]],
              c(`1` = 15, `2` = 16, `3` = 3)[[cid]], 0, 0))))
  contests <- data.table::data.table(district_id = "100", district = "Alpha District", enrolment = 1000, booths_expected = 4, booths_returned = 3,
                                     declared = FALSE, formal = 140, informal = 3, updated = "x", tcp_status = "none")
  cands[, votes := c(70, 60, 10)]
  list(contests = contests, candidates = cands, by_type = bty, booths = bo,
       booth_tcp = data.table::data.table(district_id = character(), booth_id = character(), booth = character(), booth_class = character(), candidate_id = character(), votes = numeric()),
       district_tcp = data.table::data.table())
}
nr_lookup <- function() data.table::data.table(affiliation_id = c("5", "8"), registered_name = c("Australian Labor Party - Victorian Branch", "Liberal Party of Australia - Victorian Division"))

test_that("conversion gives the booth table shape: types, names, parties, no double counting", {
  # the district counts by type repeat the booths' votes for ordinary / EVC / mobile: only one of the two may be used
  cv <- night_booth_table(nr_feed(), nr_lookup())
  L <- cv$live
  expect_named(L, c("district", "booth", "booth_type", "party", "votes"))
  expect_setequal(unique(L$district), "Alpha")                               # " District" suffix gone
  expect_setequal(unique(L$booth_type), c("ordinary", "early", "postal", "absent", "provisional", "marked_as_voted"))
  expect_equal(sum(L$votes[L$booth_type == "ordinary"]), 32)                  # booths only, not Ordinary by type as well
  expect_equal(sum(L$votes[L$booth_type == "early"]), 64 + 10)                # EVC + mobile = early; the district Early (0) adds nothing
  expect_equal(sum(L$votes[L$booth_type == "postal"]), 34)                    # postal exists only at district level
  expect_equal(sum(L$votes), 140)                                             # equals the formal total: nothing counted twice
  expect_setequal(unique(L$party), c("Australian Labor Party - Victorian Branch", "Liberal Party of Australia - Victorian Division", "Independent"))
  expect_equal(classify_party("Independent"), "IND")
})

test_that("a unit with no votes is not counted, and every district-level type exists as a unit", {
  cv <- night_booth_table(nr_feed(), nr_lookup())
  expect_false("Alpha South" %in% cv$counted$unit)                            # reported zero everywhere
  expect_true(all(c("Alpha North", "early", "postal") %in% cv$counted$unit))
  expect_false("absent" %in% cv$counted$unit)
  expect_true(all(c("absent", "provisional", "marked_as_voted") %in% cv$live$booth_type))
  expect_true("Alpha South" %in% cv$live$booth)                                # listed, so it can be projected
})

test_that("an unmapped affiliation is reported and stubbed, never silently dropped", {
  cv <- night_booth_table(nr_feed(), nr_lookup()[affiliation_id == "5"])
  expect_equal(cv$unmapped, "8")
  expect_true("UNMAPPED" %in% cv$live$party)
  stub <- night_affiliation_stub(c("5", "8", NA))
  expect_equal(stub$registered_name, c("UNMAPPED", "UNMAPPED"))
})

test_that("a booth vote for a candidate the district does not list is refused", {
  f <- nr_feed(); f$booths[1, candidate_id := "99"]
  expect_error(night_booth_table(f, nr_lookup()), "NR2!")
})

test_that("the sanity check refuses damaged snapshots", {
  expect_true(night_check_feed(nr_feed()))
  f <- nr_feed(); f$candidates[1, votes := 71]
  expect_error(night_check_feed(f), "NR1!.*formal")
  f <- nr_feed(); f$booths[2, votes := -1]
  expect_error(night_check_feed(f), "negative")
  f <- nr_feed(); f$booths[2, votes := NA_real_]
  expect_error(night_check_feed(f), "missing or negative")
  f <- nr_feed(); f$contests <- f$contests[0]
  expect_error(night_check_feed(f), "no contests")
})

test_that("archiving keeps every raw snapshot, byte for byte, and never overwrites", {
  src <- withr::local_tempdir(); arch <- withr::local_tempdir()
  f <- file.path(src, "SE26mediafileverboselhv2_20261128_190500.zip"); writeBin(as.raw(1:50), f)
  a1 <- night_archive_snapshot(f, arch)
  expect_true(a1$new); expect_true(file.exists(file.path(arch, "2026-11-28", basename(f))))
  expect_false(night_archive_snapshot(f, arch)$new)                           # same bytes: left alone
  writeBin(as.raw(51:90), f)                                                  # same name, different bytes
  a3 <- night_archive_snapshot(f, arch)
  expect_true(a3$new); expect_match(basename(a3$path), "\\.v2$")
  expect_equal(length(list.files(file.path(arch, "2026-11-28"))), 2L)
})

test_that("publishing is atomic: a document that does not read back as a full one leaves the old file alone", {
  d <- withr::local_tempdir(); out <- file.path(d, "forecast-night.json")
  good <- list(seats = list(list(seat = "A")), chamber = list(parties = list()), night = list(snapshot = "s"))
  night_publish_json(good, out)
  before <- unname(tools::md5sum(out))
  expect_error(night_publish_json(list(seats = list(), chamber = list(), night = list()), out), "NR4!")
  expect_error(night_publish_json(list(seats = list(list(seat = "A")), chamber = list()), out), "NR4!")   # no night block
  expect_equal(unname(tools::md5sum(out)), before)
  expect_equal(list.files(d), "forecast-night.json")                          # no temp file left behind
  good$seats <- list(list(seat = "A"), list(seat = "B"))
  night_publish_json(good, out)
  expect_equal(length(jsonlite::fromJSON(out, simplifyVector = FALSE)$seats), 2L)
})

nr_write_zip <- function(dir, stamp, xml_text) {
  x <- file.path(dir, sprintf("SE26mediafileverboselhv2_%s.xml", stamp)); writeLines(xml_text, x)
  z <- sub("\\.xml$", ".zip", x); utils::zip(z, basename(x), flags = "-j -q", extras = "", zip = Sys.getenv("R_ZIPCMD", "zip")); z
}

test_that("a broken snapshot does not publish: archived raw, cycle fails, last good JSON untouched", {
  src <- withr::local_tempdir(); arch <- withr::local_tempdir(); outd <- withr::local_tempdir()
  out <- file.path(outd, "forecast-night.json")
  writeLines('{"last":"good"}', out); before <- unname(tools::md5sum(out))
  bad <- file.path(src, "SE26mediafileverboselhv2_20261128_191000.zip"); writeBin(as.raw(c(0x50, 0x4b, 3, 4, rep(7, 40))), bad)   # a ZIP cut off mid-download
  cfg <- list(source = src, archive = arch, setup = src, state = "unused.rds", ref = "unused.csv", out = out)
  r <- night_cycle(cfg)
  expect_identical(r$status, "failed"); expect_match(r$summary, "FAILED 20261128_191000")
  expect_equal(unname(tools::md5sum(out)), before)                            # the last good JSON is still there, byte for byte
  expect_true(file.exists(file.path(arch, "2026-11-28", basename(bad))))      # and the raw file was kept before parsing
  expect_equal(list.files(outd), "forecast-night.json")
  # XML that parses but is not a feed
  junk <- file.path(src, "SE26mediafileverboselhv2_20261128_191500.xml"); writeLines("<Other><a/></Other>", junk)
  r2 <- night_cycle(cfg); expect_identical(r2$status, "failed"); expect_match(r2$message, "VX2!|VX3!")
  expect_equal(unname(tools::md5sum(out)), before)
})

test_that("the cycle stops loudly when the set-up affiliation file is missing, unless the stub is allowed", {
  skip_if_not(nzchar(Sys.which("zip")) || nzchar(Sys.getenv("R_ZIPCMD")), "no zip tool to build a test ZIP")
  src <- withr::local_tempdir(); arch <- withr::local_tempdir(); outd <- withr::local_tempdir()
  f <- nr_feed()
  xml <- '<?xml version="1.0" encoding="utf-8"?><MediaFeed xmlns="http://www.vec.vic.gov.au" xmlns:eml="urn:oasis:names:tc:evs:schema:eml"><Election><House><Contests>
<Contest><eml:ContestIdentifier Id="c1"><eml:ContestName>Alpha District</eml:ContestName></eml:ContestIdentifier><PollingDistrictIdentifier Id="100"><Name>Alpha District</Name></PollingDistrictIdentifier><Enrolment>1000</Enrolment><Declared>false</Declared>
<FirstPreferences PollingPlacesExpected="1" PollingPlacesReturned="0" Updated="2026-11-28T19:00:00+11:00"><Candidate Independent="no"><eml:CandidateIdentifier Id="1"><eml:CandidateName>A</eml:CandidateName></eml:CandidateIdentifier><Affiliation><eml:AffiliationIdentifier Id="5"><eml:RegisteredName>X</eml:RegisteredName></eml:AffiliationIdentifier></Affiliation><BallotPosition>1</BallotPosition><Votes>0</Votes></Candidate><Formal><Votes>0</Votes></Formal><Informal><Votes>0</Votes></Informal></FirstPreferences>
<PollingPlaces/></Contest></Contests></House></Election></MediaFeed>'
  nr_write_zip(src, "20261128_190000", xml)
  r <- night_cycle(list(source = src, archive = arch, setup = src, state = "unused.rds", ref = "unused.csv", out = file.path(outd, "o.json")))
  expect_identical(r$status, "failed"); expect_match(r$message, "NR3!")
  expect_false(file.exists(file.path(outd, "o.json")))
  r_same <- night_cycle(list(source = src, archive = arch, setup = src, state = "unused.rds", ref = "unused.csv", out = file.path(outd, "o.json"), last_stamp = "20261128_190000"))
  expect_identical(r_same$status, "no_new")
})

test_that("live mode (a list of reported units) equals the replay when the same units are counted", {
  ref  <- nu_booths(c(50, 60, 40, 55), c(50, 40, 60, 45), booths = c("B1", "B2", "B3", "B4"))
  live <- nu_booths(c(60, 70, 50, 62), c(40, 30, 50, 38), booths = c("B1", "B2", "B3", "B4"))
  sh <- matrix(c(52, 48), 1, dimnames = list("Seat A", c("ALP", "LNP"))); psd <- matrix(4, 1, 2, dimnames = dimnames(sh))
  rp <- night_booth_update(sh, psd, 0.5, live, ref)
  rep_units <- data.table::data.table(district = "Seat A", unit = rp$units[["Seat A"]])
  expect_gt(nrow(rep_units), 0L); expect_lt(nrow(rep_units), 4L)
  lv <- night_booth_update(sh, psd, 0.123, live, ref, reported = rep_units, total = "table")   # frac is ignored in live mode
  expect_identical(lv$shares, rp$shares); expect_identical(lv$sd, rp$sd); expect_identical(lv$counted, rp$counted)
  # the live denominator is projected from the uncounted booths' reference size, and is a proper share
  lp <- night_booth_update(sh, psd, 0, live, ref, reported = rep_units, total = "projected")
  expect_true(lp$counted["Seat A"] > 0 && lp$counted["Seat A"] < 1)
  # no reported units -> the prior, untouched
  l0 <- night_booth_update(sh, psd, 1, live, ref, reported = data.table::data.table(district = character(), unit = character()))
  expect_identical(l0$shares, sh); expect_identical(l0$n_updated, 0L)
})
