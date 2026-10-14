# Preference data: federal 2001 (AEC) and Queensland 2004-2017 (ECQ)

Track A of `docs/plans/coverage-program-2026-10-13.md`. This records what was parsed from the commission files, what was checked, and what is missing. Everything comes from one script, `scripts/fetch_aec2001_ecq.R` (check codes `QA*`), and every number below was printed by a run on 2026-10-13. Nothing under `R/`, `scripts/` (other than the new script), `tests/` or `.github/` was edited, and no existing data file was changed.

Table: what each election gave and how well it checked. "Seats" is parsed against expected; "Winners vs AE" counts seats where the commission's winner is the same person as in the anchor clone's archived results (`results_<year>qld.csv`, `results_2001fed.csv`); higher is better for both columns.

| Election | Seats parsed | Formal votes per seat add up | Winners vs AE archive | Two-candidate-preferred (TCP) | Preference rounds | Output files |
|---|---|---|---|---|---|---|
| Federal 2001 | 150 of 150 | 150 of 150 (also equals `divs.txt` formal vote) | 150 of 150 | Yes, all 150, from the final count; equals the AEC's own TPP in 150 of 150 | Yes: 739 exclusions, all balanced | `aec-fed-2001-firstprefs.csv` (797 rows), `-tcp.csv` (300), `-transfers.csv` (2,807) |
| Qld 2004 | 89 of 89 | 89 of 89 | 89 of 89 | 83 of 89 seats (6 missing, see below) | None in file | `ecq-2004-qld-firstprefs.csv` (342), `ecq-2004-qld-tcp.csv` (166) |
| Qld 2006 | 89 of 89 | 89 of 89 | 89 of 89 | None in file | None | `ecq-2006-qld-firstprefs.csv` (322) |
| Qld 2009 | 89 of 89 | 89 of 89 | 89 of 89 | None in file | None | `ecq-2009-qld-firstprefs.csv` (373) |
| Qld 2012 | 89 of 89 | 89 of 89 | 89 of 89 | Yes, 89 of 89 | None | `ecq-2012-qld-firstprefs.csv` (423), `ecq-2012-qld-tcp.csv` (178) |
| Qld 2015 | 89 of 89 | 89 of 89 | 89 of 89 | None in file | None | `ecq-2015-qld-firstprefs.csv` (392) |
| Qld 2017 | 93 of 93 | 93 of 93 | 93 of 93 | None in file | None | none written: compared with existing `ecq-2017-qld-firstprefs.csv`, identical in 416 of 416 seat-party rows |

File layouts match the existing ones: the federal files have the same columns as `aec-fed-firstprefs.csv` (`seat,party,votes,election`), `aec-fed-tcp.csv` (`election,seat,party,votes`) and `aec-fed-transfers.csv` (`election,seat,round,from,to,votes`); the Queensland files match `ecq-2017-qld-firstprefs.csv` (`seat,party,votes`) and the TCP files use `seat,party,votes`. Parties are classified by `classify_party()` (ALP, LNP, GRN, ONP, OTH_RIGHT, IND, OTH).

## Federal 2001

- Source: the AEC statistics zip already on disk (`external/reference/aec/stats/aec-2001-election-statistics.zip`, 1,754 members, opens cleanly). The six import files were extracted to `external/reference/aec/raw/2001/` at the sizes the zip directory lists. Nothing was refetched.
- `hppdop.txt` contains a pseudo polling place called DIVISION SUMMARY that already totals every other row (ordinary booths plus absent, postal, pre-poll and provisional votes). Summing it together with the real places double counts everything. The script uses the summary and proves it equals the sum of the real places in 4,955 of 4,955 division-count-candidate cells.
- Count 1 reproduces `hcands.txt` first preferences in 1,039 of 1,039 candidate rows; national ALP first preference 37.84% (actual 37.8%); first preferences per division equal the official formal vote in 150 of 150.
- Every count has exactly one excluded candidate, and the votes leaving the excluded candidate equal the votes arriving in 739 of 739 exclusions (largest gap 0, which is expected under full preferential voting).
- Final count has exactly two candidates in 150 of 150, and that two-candidate total equals the AEC's ALP+Coalition figure in `divs.txt` in 150 of 150.
- Flow anchors: Greens to Labor 71.0% (band 70-92 passes, but this is the bottom of the band, consistent with 2001), One Nation to Labor 42.2% of ALP+LNP (n = 471,227 votes).
- Transfers are aggregated to party class by seat and round, same as the existing federal file. TCP rows are not aggregated (a Liberal vs National final count would give two LNP rows, as in the existing file).
- Every field is kept in `external/reference/aec/raw/2001/parsed-candidates.csv` and `parsed-division-distribution.csv` (candidate, party code, status, vote, transfer received, exhausted).

## Queensland (ECQ)

- Zips fetched 2026-10-13 from `results.ecq.qld.gov.au/elections/state/<State|state><year>/results/public.zip` at 1 request per second with a descriptive User-Agent. The capitalisation of `State` differs by year: lowercase `state` works for 2004, 2006 and 2009, capital `State` for 2012, 2015 and 2017 (the other form returns 404). Each zip opens, holds one `publicResults.xml` at the size the zip lists, and the XML ends with its closing `</election>` tag. Stored under `external/reference/ecq/raw/<year>/` with `candidates.csv` and `booths.csv` (every candidate and booth-level field, 68,148 booth-candidate rows in 2017).
- Candidate primaries sum to the district formal-vote count in every district in every year, and booth rows sum to the candidate totals in every district.
- Comparison with the anchor clone's archive: first-preference totals equal in 89 of 89 (2004, 2006, 2009, 2015), 88 of 89 (2012) and 92 of 93 (2017) seats. These are the same gaps the earlier inventory found for 2017 (Capalaba); the 2012 difference was not investigated.
- Queensland 2017: the zip downloaded today is byte-identical in size to the capture used earlier (9,626,442 bytes) and gives identical first preferences in all 416 rows. That file was not overwritten.

## Problems

1. **No preference rounds exist in any ECQ file.** As the inventory said. Queensland was optional preferential until 2017, so the distribution is the missing piece for the Queensland pairs and federal flows would still be the stand-in (decision for Pete, unchanged from the inventory).
2. **TCP exists only for 2004 and 2012, and it is partial.** The `n2cpVotes` totals are far below the AE archive's TCP totals: median 84% of the archive's total in 2004 (minimum 17%) and 73% in 2012 (minimum 29%), equal in only 3 and 2 seats. The ECQ field looks like a count of the ballots that were preference-counted at that point, not the full final two-candidate result. The winner agrees with the archive in every seat, but the vote totals should not be treated as a complete TCP. For a full TCP in those years use the AE archive's `tcp` block (not yet parsed into our files).
3. **Qld 2004: six seats carry no TCP at all** (Burnett, Fitzroy, Lockyer, Rockhampton, Surfers Paradise, Whitsunday). The first-preference leader holds over 50% in four of them. In Lockyer (34.8%) and Surfers Paradise (44.7%) there is no majority, so no winner can be derived from the ECQ file alone. The winner of those two matches the AE archive, and that is the only source for it (check QA25b is the one flagged FAIL for this reason). The 2004 file has no declared-winner attribute either, so its winners rest on the TCP leader.
4. **Generation dates and the `final` flag.** The 2004 file was generated 2006-08-01, 2006 on 2010-08-27, 2009 on 2012-03-15, 2012 on 2013-02-05, 2015 on 2015-10-23 and 2017 on 2017-12-12, all well after polling day. Districts in several files still carry `final="NO"`; I did not establish whether the commission ever updated that attribute, so it is not used as a finality test. The counts match the AE archive instead (see above).
5. **Party codes:** ZZZ ("Other Candidates") is read as independent, as the existing 2017 parser does, so small unregistered parties appear as IND. In 2004 and 2006 the Liberal and National parties are separate registered parties and both map to LNP. Katter's party maps to OTH in 2012 (the file names it "The Australian Party") but OTH_RIGHT in 2015 and 2017 (named "Katter's Australian Party"). That is the existing classifier's behaviour on the file's own names and is not changed here; a pair spanning 2012 and 2015 would see KAP change class.
6. Not done: federal 1998 (the 1993-96-98 zip was not opened), Queensland 2001 (no ECQ zip exists), and the AE archive's `tcp` blocks have not been converted into files.
