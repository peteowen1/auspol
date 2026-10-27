# VEC results-feed reader (R/vec_feed.R, issue #158). Synthetic XML in the 2026 feed's shape:
# the real sample lives under external/ (gitignored), which CI does not have.

vf_doc <- function(contests, root = "MediaFeed") {
  sprintf('<?xml version="1.0" encoding="utf-8"?>
<%s xmlns="http://www.vec.vic.gov.au" xmlns:eml="urn:oasis:names:tc:evs:schema:eml" Id="SE26" Created="2026-11-28T19:00:00" Phase="ElectionNight" Verbose="true">
<Election><House><Contests>%s</Contests></House></Election></%s>', root, contests, root)
}

vf_cand <- function(id, votes, types = NULL) {
  vt <- if (is.null(types)) "" else paste0("<VotesByType>",
    paste(sprintf('<Votes Type="%s">%s</Votes>', names(types), types), collapse = ""), "</VotesByType>")
  sprintf('<Candidate Independent="false"><eml:CandidateIdentifier Id="%s"><eml:CandidateName>C %s</eml:CandidateName></eml:CandidateIdentifier><BallotPosition>1</BallotPosition><Elected>false</Elected><Votes>%s</Votes>%s</Candidate>',
          id, id, votes, vt)
}

vf_contest <- function(did, name, cands, tcp = "", booths = "", returned = 1) {
  sprintf('<Contest Updated="2026-11-28T19:00:00+11:00"><eml:ContestIdentifier Id="c%s"><eml:ContestName>%s</eml:ContestName></eml:ContestIdentifier>
<PollingDistrictIdentifier Id="%s"><Name>%s</Name></PollingDistrictIdentifier><Enrolment>1000</Enrolment><Declared>false</Declared><NumberOfPositions>1</NumberOfPositions>
<FirstPreferences PollingPlacesExpected="2" PollingPlacesReturned="%s" Updated="2026-11-28T19:00:00+11:00">%s<Formal><Votes>30</Votes></Formal><Informal><Votes>2</Votes></Informal><Total><Votes>32</Votes></Total></FirstPreferences>%s<PollingPlaces>%s</PollingPlaces></Contest>',
          did, name, did, name, returned, cands, tcp, booths)
}

vf_booth <- function(id, name, cls, votes) {
  cs <- paste(sprintf('<Candidate><eml:CandidateIdentifier Id="%s"/><Votes>%s</Votes></Candidate>', names(votes), votes), collapse = "")
  sprintf('<PollingPlace Updated="2026-11-28T19:00:00+11:00"><PollingPlaceIdentifier Id="%s" Name="%s" Classification="%s"/><FirstPreferences Updated="2026-11-28T19:00:00+11:00">%s</FirstPreferences></PollingPlace>',
          id, name, cls, cs)
}

vf_write <- function(xml, dir = tempfile(), name = "SE26mediafileverboselhv2_20261128_190000.xml") {
  dir.create(dir, showWarnings = FALSE)
  writeLines(xml, file.path(dir, name))
  file.path(dir, name)
}

test_that("a two-district snapshot parses into the tidy tables", {
  tcp_ok <- '<TwoCandidatePreferred PollingPlacesExpected="2" PollingPlacesReturned="1" Updated="2026-11-28T19:10:00+11:00"><Candidate><eml:CandidateIdentifier Id="1"/><Votes>18</Votes></Candidate><Candidate><eml:CandidateIdentifier Id="2"/><Votes>12</Votes></Candidate></TwoCandidatePreferred>'
  tcp_mav <- '<TwoCandidatePreferred Maverick="true" PollingPlacesExpected="2" PollingPlacesReturned="0" Updated="2026-11-28T19:10:00+11:00"/>'
  a <- vf_contest("100", "Alpha District", paste0(vf_cand("1", 20, c(Ordinary = 15, EVCEarly = 5)), vf_cand("2", 10, c(Ordinary = 8, EVCEarly = 2))),
                  tcp = tcp_ok, booths = paste0(vf_booth("9", "Alpha North", "VotingCentre", c(`1` = 15, `2` = 8)),
                                                vf_booth("10", "Alpha EVC", "EarlyVotingCentre", c(`1` = 5, `2` = 2))))
  b <- vf_contest("200", "Beta District", paste0(vf_cand("3", 25), vf_cand("4", 5)), tcp = tcp_mav, returned = 0)
  x <- vec_feed_read_lh(vf_write(vf_doc(paste0(a, b))))

  expect_equal(nrow(x$contests), 2L)
  expect_equal(x$contests$tcp_status, c("pair", "none"))           # Maverick is no data, never zeros
  expect_equal(nrow(x$district_tcp), 2L)                           # only Alpha's pair
  expect_setequal(x$district_tcp$district_id, "100")
  expect_equal(nrow(x$booths), 4L)
  expect_equal(x$booths[booth_class == "EarlyVotingCentre", sum(votes)], 7)
  expect_equal(x$by_type[candidate_id == "1" & vote_type == "EVCEarly", votes], 5)
  # booth sums by class equal the district vote-type totals (the feed's own identity)
  expect_equal(x$booths[booth_class == "VotingCentre", sum(votes)],
               x$by_type[district_id == "100" & vote_type == "Ordinary" & !candidate_id %in% c("FORMAL", "INFORMAL"), sum(votes)])
})

test_that("a 2CP block with no update time or one candidate is no data", {
  empty_upd <- '<TwoCandidatePreferred Updated=""><Candidate><eml:CandidateIdentifier Id="1"/><Votes>0</Votes></Candidate><Candidate><eml:CandidateIdentifier Id="2"/><Votes>0</Votes></Candidate></TwoCandidatePreferred>'
  one <- '<TwoCandidatePreferred Updated="2026-11-28T19:10:00+11:00"><Candidate><eml:CandidateIdentifier Id="1"/><Votes>4</Votes></Candidate></TwoCandidatePreferred>'
  x <- vec_feed_read_lh(vf_write(vf_doc(paste0(
    vf_contest("1", "A", vf_cand("1", 3), tcp = empty_upd), vf_contest("2", "B", vf_cand("5", 3), tcp = one)))))
  expect_equal(x$contests$tcp_status, c("none", "none"))
  expect_equal(nrow(x$district_tcp), 0L)
})

test_that("broken inputs stop instead of returning plausible tables", {
  expect_error(vec_feed_read_lh(vf_write(vf_doc(vf_contest("1", "A", vf_cand("1", 3)), root = "Other"))), "VX2!")
  expect_error(vec_feed_read_lh(vf_write(vf_doc(""))), "VX3!")
  dup <- vf_contest("1", "A", paste0(vf_cand("7", 3), vf_cand("7", 4)))
  expect_error(vec_feed_read_lh(vf_write(vf_doc(dup))), "VX4!")
})

test_that("the newest snapshot is chosen by the timestamp in its name, not file order", {
  d <- tempfile(); dir.create(d)
  x <- vf_doc(vf_contest("1", "A", vf_cand("1", 3)))
  vf_write(x, d, "SE26mediafileverboselhv2_20261128_235500.xml")
  vf_write(x, d, "SE26mediafileverboselhv2_20261128_190000.xml")
  vf_write(x, d, "SE26mediafileverboseuhv2_20261129_010000.xml")   # upper house: another kind
  expect_match(basename(vec_feed_latest(d, "verboselhv2")), "20261128_235500")
  expect_true(is.na(vec_feed_latest(tempfile(), "verboselhv2")))
})
