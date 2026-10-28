# Election-night runner (R/night_runner.R, map #148). Synthetic feeds only: the real VEC sample lives under external/
# (gitignored), which CI does not have.

nu_booths <- function(alp, lnp, booths, district = "Seat A") {
  data.table::rbindlist(lapply(seq_along(booths), function(i) data.table::data.table(
    district = district, booth = booths[i], booth_type = "ordinary",
    party = c("Australian Labor Party", "Liberal"), votes = c(alp[i], lnp[i]))))
}

nr_min_xml <- function(district) sprintf('<?xml version="1.0" encoding="utf-8"?><MediaFeed xmlns="http://www.vec.vic.gov.au" xmlns:eml="urn:oasis:names:tc:evs:schema:eml"><Election><House><Contests>
<Contest><eml:ContestIdentifier Id="c1"><eml:ContestName>%s</eml:ContestName></eml:ContestIdentifier><PollingDistrictIdentifier Id="100"><Name>%s</Name></PollingDistrictIdentifier><Enrolment>1000</Enrolment><Declared>false</Declared>
<FirstPreferences PollingPlacesExpected="1" PollingPlacesReturned="0" Updated="2026-11-28T19:00:00+11:00"><Candidate Independent="no"><eml:CandidateIdentifier Id="1"><eml:CandidateName>A</eml:CandidateName></eml:CandidateIdentifier><Affiliation><eml:AffiliationIdentifier Id="5"><eml:RegisteredName>X</eml:RegisteredName></eml:AffiliationIdentifier></Affiliation><BallotPosition>1</BallotPosition><Votes>0</Votes></Candidate><Formal><Votes>0</Votes></Formal><Informal><Votes>0</Votes></Informal></FirstPreferences>
<PollingPlaces/></Contest></Contests></House></Election></MediaFeed>', district, district)

nr_setup_files <- function(dir) {
  writeLines('<EML xmlns="urn:oasis:names:tc:evs:schema:eml"><CandidateList><Election><Contest><Candidate><Affiliation><AffiliationIdentifier Id="5"><RegisteredName>Australian Labor Party</RegisteredName></AffiliationIdentifier></Affiliation></Candidate></Contest></Election></CandidateList></EML>',
             file.path(dir, "TestMediaFileCandidatesV2.xml"))
  writeLines('<PollingDistrictList xmlns="http://www.aec.gov.au/xml/schema/mediafeed" xmlns:eml="urn:oasis:names:tc:evs:schema:eml"><PollingDistrict><PollingDistrictIdentifier Id="100"><Name>Alpha District</Name></PollingDistrictIdentifier><PollingPlaces><PollingPlace><PollingPlaceIdentifier Id="9" Name="Alpha North" Classification="VotingCentre" /></PollingPlace><PollingPlace><PollingPlaceIdentifier Id="10" Name="Alpha South" Classification="VotingCentre" /></PollingPlace><PollingPlace><PollingPlaceIdentifier Id="11" Name="Alpha EVC" Classification="EarlyVotingCentre" /></PollingPlace></PollingPlaces></PollingDistrict></PollingDistrictList>',
             file.path(dir, "TestMediaFilePollingLocationsV2.xml"))
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
  cv <- night_booth_table(nr_feed(), nr_lookup(), include_late = TRUE)
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
  cv <- night_booth_table(nr_feed(), nr_lookup(), include_late = TRUE)
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
  expect_error(night_booth_table(f, nr_lookup()), "NW2!")
})

test_that("the sanity check refuses damaged snapshots", {
  expect_true(night_check_feed(nr_feed()))
  f <- nr_feed(); f$candidates[1, votes := 71]
  expect_error(night_check_feed(f), "NW1!.*formal")
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
  expect_error(night_publish_json(list(seats = list(), chamber = list(), night = list()), out), "NW4!")
  expect_error(night_publish_json(list(seats = list(list(seat = "A")), chamber = list()), out), "NW4!")   # no night block
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
  nr_setup_files(src); file.remove(file.path(src, "TestMediaFileCandidatesV2.xml"))   # polling list present, party names missing
  r <- night_cycle(list(source = src, archive = arch, setup = src, state = "unused.rds", ref = "unused.csv", out = file.path(outd, "o.json")))
  expect_identical(r$status, "failed"); expect_match(r$message, "NW3!")
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

# ---- review fixes: seat coverage, unreported booths, staleness, denominator ----

test_that("a feed district the saved state does not have (or a state seat the feed lacks) stops the cycle and publishes nothing", {
  src <- withr::local_tempdir(); arch <- withr::local_tempdir(); outd <- withr::local_tempdir()
  nr_setup_files(src)
  out <- file.path(outd, "forecast-night.json"); writeLines('{"last":"good"}', out); before <- unname(tools::md5sum(out))
  st <- list(shares = matrix(c(50, 50), 1, dimnames = list("Alpha", c("ALP", "LNP"))))
  cfg <- list(source = src, archive = arch, setup = src, state = st, ref = data.table::data.table(), out = out, cache = new.env())
  writeLines(nr_min_xml("Alpha District"), file.path(src, "SE26mediafileverboselhv2_20261128_190000.xml"))
  # the matching name gets past NW7 (it fails later on the stub state, which is not what is tested here)
  r_ok <- night_cycle(cfg); expect_false(grepl("NW7", r_ok$message))
  # a renamed district: the state's "Alpha" is not in the feed, the feed's "Alphaa" is not in the state
  file.remove(file.path(src, "SE26mediafileverboselhv2_20261128_190000.xml"))
  writeLines(nr_min_xml("Alphaa District"), file.path(src, "SE26mediafileverboselhv2_20261128_190500.xml"))
  cfg$cache <- new.env()
  r <- night_cycle(cfg)
  expect_identical(r$status, "failed"); expect_match(r$message, "NW7!.*Alpha.*Alphaa")
  expect_equal(unname(tools::md5sum(out)), before)
  expect_equal(list.files(outd), "forecast-night.json")
  expect_silent(night_check_coverage(c("A", "B"), c("A", "C"), allow = TRUE))
  expect_error(night_check_coverage(c("A", "B"), c("A", "B", "C")), "NW7!")
  expect_error(night_check_coverage(c("A", "B"), "A"), "NW7!")
  expect_silent(night_check_coverage(c("A", "B"), c("B", "A")))
})

test_that("a missing polling-locations file stops the cycle (NW6): without it every booth looks reported", {
  src <- withr::local_tempdir(); arch <- withr::local_tempdir(); outd <- withr::local_tempdir()
  nr_setup_files(src); file.remove(file.path(src, "TestMediaFilePollingLocationsV2.xml"))
  writeLines(nr_min_xml("Alpha District"), file.path(src, "SE26mediafileverboselhv2_20261128_190000.xml"))
  r <- night_cycle(list(source = src, archive = arch, setup = src, state = list(shares = matrix(1, 1, 1, dimnames = list("Alpha", "ALP"))),
                        ref = data.table::data.table(), out = file.path(outd, "o.json")))
  expect_match(r$message, "NW6!")
})

test_that("unreported booths in the polling-locations list get zero-vote rows; district-level Early is kept", {
  pl <- data.table::data.table(district_id = "100", district = "Alpha District", booth_id = c("9", "10", "11"),
                               booth = c("Alpha North", "Alpha South", "Alpha EVC"), booth_class = c("VotingCentre", "VotingCentre", "EarlyVotingCentre"))
  f <- nr_feed(); f$booths <- f$booths[f$booths$booth != "Alpha South"]       # South has not reported: no rows at all
  cv0 <- night_booth_table(f, nr_lookup())
  expect_false("Alpha South" %in% cv0$live$booth)
  cv <- night_booth_table(f, nr_lookup(), pl)
  expect_equal(cv$n_placeholder_booths, 1L)
  expect_equal(sum(cv$live$votes[cv$live$booth == "Alpha South"]), 0)
  expect_false("Alpha South" %in% cv$counted$unit); expect_true("Alpha North" %in% cv$counted$unit)
  expect_equal(sum(cv$live$votes), sum(cv0$live$votes))                       # placeholders add no votes
  # "Early" (outside-district early votes, not in any booth row) is added, not treated as a duplicate
  f$by_type[f$by_type$vote_type == "Early", votes := 5]
  cv5 <- night_booth_table(f, nr_lookup())
  expect_equal(sum(cv5$live$votes[cv5$live$booth_type == "early"]), sum(cv0$live$votes[cv0$live$booth_type == "early"]) + 15)
})

test_that("a contest with no candidate rows is refused rather than silently dropped", {
  f <- nr_feed(); extra <- data.table::copy(f$contests); extra$district_id <- "200"; extra$district <- "Beta District"
  f$contests <- rbind(f$contests, extra)
  expect_error(night_check_feed(f), "NW1!.*no candidates")
})

test_that("a snapshot older than the published one is refused; the same one is skipped", {
  d <- withr::local_tempdir(); out <- file.path(d, "o.json")
  expect_identical(night_check_fresh("20261128_190000", out), "ok")                 # nothing published yet
  writeLines('{"night":{"snapshot_stamp":"20261128_190500"}}', out)
  expect_error(night_check_fresh("20261128_190000", out), "NW8!")
  expect_identical(night_check_fresh("20261128_190500", out), "same")
  expect_identical(night_check_fresh("20261128_191000", out), "ok")
  writeLines('{"last":"good"}', out); expect_identical(night_check_fresh("20261128_190000", out), "ok")   # no night block
})

test_that("turnout comes from the previous ASSEMBLY booth table (all types; night = ordinary+early+postal), not the council count", {
  stats <- data.frame(district = c("A District", "B District"), enrolment = c(100, 200), rbvc_formal = c(999, 999))   # upper-house base must be ignored
  bp <- data.table::rbindlist(list(
    data.table::data.table(district = "A", booth = c("a1", "x", "y"), booth_type = c("ordinary", "postal", "absent"), party = "Liberal", votes = c(70, 10, 6)),
    data.table::data.table(district = "B", booth = c("b1", "x"), booth_type = c("ordinary", "early"), party = "Liberal", votes = c(100, 60))))
  pt <- night_turnout_table(stats, bp)
  expect_equal(pt$total_votes[pt$district == "A"], 86); expect_equal(pt$night_votes[pt$district == "A"], 80)
  expect_equal(pt$enrolment[pt$district == "B"], 200)
  nf <- night_expected_votes(c(A = 110, B = 200, C = 50), pt, "final")
  expect_equal(nf[["A"]], 110 * 0.86); expect_equal(nf[["B"]], 200 * 0.8)
  expect_equal(nf[["C"]], 50 * (86 + 160) / 300)                                  # statewide rate for a new seat
  nn <- night_expected_votes(c(A = 110, B = 200), pt, "night")
  expect_equal(nn[["A"]], 110 * 0.8)                                              # absent votes are not in the night base
})

test_that("the expected denominator sets counted share and rescales the uncounted remainder", {
  ref  <- nu_booths(c(50, 60, 40, 55), c(50, 40, 60, 45), booths = c("B1", "B2", "B3", "B4"))
  live <- nu_booths(c(60, 70, 0, 0), c(40, 30, 0, 0), booths = c("B1", "B2", "B3", "B4"))   # B3, B4 unreported
  rep_units <- data.table::data.table(district = "Seat A", unit = c("B1", "B2"))
  sh <- matrix(c(52, 48), 1, dimnames = list("Seat A", c("ALP", "LNP"))); psd <- matrix(4, 1, 2, dimnames = dimnames(sh))
  u <- night_booth_update(sh, psd, 0, live, ref, reported = rep_units, total = "expected", expected = c(`Seat A` = 400))
  expect_equal(unname(u$counted["Seat A"]), 200 / 400)                              # counted 200 of an expected 400
  u2 <- night_booth_update(sh, psd, 0, live, ref, reported = rep_units, total = "expected", expected = c(`Seat A` = 250))
  expect_equal(unname(u2$counted["Seat A"]), 200 / 250)
  u3 <- night_booth_update(sh, psd, 0, live, ref, reported = rep_units, total = "expected", expected = c(`Seat A` = NA_real_))
  p <- night_booth_update(sh, psd, 0, live, ref, reported = rep_units, total = "projected")
  expect_identical(u3$counted, p$counted)                                           # NA expected -> projected
  rd <- data.table::as.data.table(ref)[, list(unit = booth, booth_type, cls = classify_party(party), v = votes)]
  ld <- data.table::as.data.table(live)[, list(unit = booth, booth_type, cls = classify_party(party), v = votes)]
  pr <- project_seat_from_booths(ld, rd, c("B1", "B2"), total = "expected", expected_total = 400)
  expect_equal(sum(pr$projected), 400)                                              # counted 200 + uncounted rescaled to the 200 left
})

# ---- round 2: late types, projected fallback, polling-list coverage, unreadable JSON ----

test_that("the night base leaves absent, provisional and marked-as-voted out of the table (numerator and projected units)", {
  f <- nr_feed(); f$by_type[f$by_type$vote_type == "Absent", votes := 4]
  full <- night_booth_table(f, nr_lookup(), include_late = TRUE)
  expect_equal(sum(full$live$votes[full$live$booth_type == "absent"]), 12)
  night <- night_booth_table(f, nr_lookup())
  expect_false(any(c("absent", "provisional", "marked_as_voted") %in% night$live$booth_type))
  expect_false(any(c("absent", "provisional", "marked_as_voted") %in% night$counted$unit))
  expect_equal(sum(night$live$votes), sum(full$live$votes) - 12)
})

test_that("no turnout file stops the cycle (NW9) unless the projected denominator is explicitly allowed", {
  src <- withr::local_tempdir(); arch <- withr::local_tempdir(); outd <- withr::local_tempdir()
  nr_setup_files(src)
  out <- file.path(outd, "forecast-night.json"); writeLines('{"last":"good"}', out); before <- unname(tools::md5sum(out))
  writeLines(nr_min_xml("Alpha District"), file.path(src, "SE26mediafileverboselhv2_20261128_190000.xml"))
  st <- list(shares = matrix(c(50, 50), 1, dimnames = list("Alpha", c("ALP", "LNP"))))
  cfg <- list(source = src, archive = arch, setup = src, state = st, ref = data.table::data.table(), out = out, cache = new.env())
  r <- night_cycle(cfg)
  expect_identical(r$status, "failed"); expect_match(r$message, "NW9!")
  expect_equal(unname(tools::md5sum(out)), before); expect_equal(list.files(outd), "forecast-night.json")
  cfg$cache <- new.env(); cfg$allow_projected <- TRUE
  r2 <- night_cycle(cfg); expect_false(grepl("NW9!", r2$message))
})

test_that("a state seat with no voting centre in the polling list stops the cycle (NW10); its district Ordinary rows are kept", {
  pl <- data.table::data.table(district_id = "100", district = "Alpha District", booth_id = "9", booth = "Alpha North", booth_class = "VotingCentre")
  expect_error(night_check_places(c("Alpha", "Beta"), pl), "NW10!.*Beta")
  expect_silent(night_check_places("Alpha", pl))
  expect_silent(night_check_places(c("Alpha", "Beta"), pl, allow = TRUE))
  # a polling file listing only another district: this district's Ordinary count must not be dropped
  other <- data.table::data.table(district_id = "999", district = "Other District", booth_id = "1", booth = "Other", booth_class = "VotingCentre")
  f <- nr_feed(); f$booths <- f$booths[0]
  f$by_type[f$by_type$vote_type == "Ordinary", votes := c(20, 10, 2)]
  kept <- night_booth_table(f, nr_lookup(), other)
  expect_equal(sum(kept$live$votes[kept$live$booth_type == "ordinary"]), 32)
  listed <- night_booth_table(f, nr_lookup(), pl)
  expect_equal(sum(listed$live$votes[listed$live$booth_type == "ordinary"]), 0)       # listed: ordinary votes come from booths only
})

test_that("a booth the polling list spells differently is logged (NW11) and not duplicated by a placeholder", {
  pl <- data.table::data.table(district_id = "100", district = "Alpha District", booth_id = c("9", "10"),
                               booth = c("Mount Alpha", "Alpha South"), booth_class = "VotingCentre")
  f <- nr_feed(); f$booths$booth[f$booths$booth == "Alpha North"] <- "Mt Alpha"      # reported as "Mt Alpha", listed as "Mount Alpha"
  cv <- expect_silent(night_booth_table(f, nr_lookup(), pl))                         # normalised names match: no log, no duplicate
  expect_equal(cv$n_placeholder_booths, 0L)                                         # South already has (zero) rows; Mount Alpha matches Mt Alpha
  expect_false("Mount Alpha" %in% cv$live$booth)
  f$booths$booth[f$booths$booth == "Mt Alpha"] <- "Alfa North"                       # a genuinely unknown name
  expect_message(cv2 <- night_booth_table(f, nr_lookup(), pl), "NW11")
  expect_equal(cv2$n_unlisted_booths, 1L)
})

test_that("the per-seat fallback to the projected denominator is recorded, and a non-positive expected total is not used", {
  ref  <- nu_booths(c(50, 60, 40, 55), c(50, 40, 60, 45), booths = c("B1", "B2", "B3", "B4"))
  live <- nu_booths(c(60, 70, 0, 0), c(40, 30, 0, 0), booths = c("B1", "B2", "B3", "B4"))
  ru <- data.table::data.table(district = "Seat A", unit = c("B1", "B2"))
  sh <- matrix(c(52, 48), 1, dimnames = list("Seat A", c("ALP", "LNP"))); psd <- matrix(4, 1, 2, dimnames = dimnames(sh))
  for (ex in list(c(`Seat A` = NA_real_), c(`Seat A` = 0), c(`Seat A` = -5), c(Other = 100), NULL)) {
    u <- night_booth_update(sh, psd, 0, live, ref, reported = ru, total = "expected", expected = ex)
    expect_equal(u$fallback_projected, "Seat A")
  }
  good <- night_booth_update(sh, psd, 0, live, ref, reported = ru, total = "expected", expected = c(`Seat A` = 400))
  expect_length(good$fallback_projected, 0L)
  rd <- data.table::as.data.table(ref)[, list(unit = booth, booth_type, cls = classify_party(party), v = votes)]
  ld <- data.table::as.data.table(live)[, list(unit = booth, booth_type, cls = classify_party(party), v = votes)]
  p0 <- project_seat_from_booths(ld, rd, c("B1", "B2"), total = "expected", expected_total = 0)
  pp <- project_seat_from_booths(ld, rd, c("B1", "B2"), total = "projected")
  expect_equal(p0$counted_share[1], pp$counted_share[1])
})

test_that("a published JSON that exists but cannot be read stops the cycle instead of being overwritten", {
  d <- withr::local_tempdir(); out <- file.path(d, "o.json"); writeLines('{"night": {"snapshot_stamp": ', out)
  expect_error(night_check_fresh("20261128_190000", out), "NW8!.*cannot be read")
})

test_that("the night JSON carries seat-count histograms, the afternoon primary and the VEC 2CP (#162), and keeps its old keys", {
  sh0 <- matrix(c(50, 45, 40, 55), 2, dimnames = list(c("S1", "S2"), c("ALP", "LNP")))
  sh1 <- sh0 + 2; sdm <- matrix(3, 2, 2, dimnames = dimnames(sh0))
  tot <- cbind(ALP = c(2L, 1L, 1L, 0L), LNP = c(0L, 1L, 1L, 2L))
  sim <- list(totals = tot, win_prob = data.frame(seat = c("S1", "S2"), party = c("ALP", "LNP"), prob = c(0.75, 0.75)),
              tcp_winner = NULL, tcp_runnerup = NULL)
  attr(sim, "night_tcp") <- data.table::data.table(seat = "S1", a = "ALP", b = "LNP", pair_share = 0.9, prior_a = 0.5, post_a = 0.52, obs_a = 0.55, changed = 1L, flag = FALSE)
  res <- list(sim = sim, shares = sh1, sd = sdm, matched = c("S1", "S2"), n_updated = 2L, n_tcp = 1L,
              nu = list(counted = c(S1 = 0.4, S2 = 0.1), fallback_projected = character()), denominator = "expected", n_placeholder = 0L, n_unlisted = 0L)
  doc <- night_build_json(list(shares = sh0, pair = "t"), res, list(file = "f", stamp = "s", archived = TRUE))
  expect_equal(doc$chamber$parties$ALP$hist, c(1L, 2L, 1L))                          # draws with 0, 1, 2 ALP seats (chamber of 2)
  expect_equal(doc$chamber$parties$LNP$hist, c(1L, 2L, 1L))
  expect_equal(sum(doc$chamber$parties$ALP$hist), doc$n_sims)
  s1 <- doc$seats[[1]]
  expect_equal(vapply(s1$parties, function(x) x$primary_prior, 0)[order(vapply(s1$parties, `[[`, "", "party"))], c(50, 40))
  expect_equal(s1$vec_2cp$vec_share_a, 0.55); expect_false(s1$vec_2cp$wrong_pair)
  expect_null(doc$seats[[2]]$vec_2cp)
  expect_true(all(c("chamber", "night", "majority", "seats", "n_sims", "built_at") %in% names(doc)))
  js <- jsonlite::fromJSON(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null"), simplifyVector = FALSE)
  expect_equal(unlist(js$chamber$parties$ALP$hist), c(1, 2, 1))
})
