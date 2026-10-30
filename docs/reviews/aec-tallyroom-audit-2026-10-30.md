# AEC Tally Room downloads: audit, fetch and uses (2026-10-30)

Why this matters: the AEC publishes about 45 House download types per election. We had been using five or six of them, so most of what the Tally Room says about turnout, postal and pre-poll counts, preference flows and booth locations was on a website, not in our models. All of it for the eight federal elections 2004-2025 is now on disk, raw. Written by a read-only audit plus a fetch; no model code was touched.

## Fetch log summary

- Script: `scripts/fetch_aec_tallyroom.R` (file list parsed from each election's own menu page; one request at a time, 1 s pause; originals untouched; skips what is on disk).
- Destination: `external/reference/aec/tallyroom/<eventid>/` (event ids 12246 2004, 13745 2007, 15508 2010, 17496 2013, 20499 2016, 24310 2019, 27966 2022, 31496 2025; all eight verified against the AEC site, 2004 served from `/results/` not `/Website/`).
- Result: **506 files, 180 MB** (about 464 CSV/ZIP from the menus + 8 menu pages + 34 General* files found by probing, see below + logs). Zero requests failed for anything the menus list. Per election: 2004/2007 52 data files, 2010/2013 54, 2016-2025 63 (each includes 16 ZIPs: distribution of preferences and TCP flow by polling place, one per state, each ZIP holding one CSV per division).
- **The menu pages understate what exists.** The 2004-2013 menus do not list the `General*` files (enrolment, declaration votes issued/received, party details, polling places), but the same URLs return real files for all eight elections. 34 extra files were fetched by direct probe (`tallyroom/probe-undocumented-log.csv`). Only the 2016+ menus list them. Treat any "AEC doesn't offer X for year Y" claim as unconfirmed unless the URL itself was tried.
- Genuine 404s (probed): `HouseNominationsByDivision` 2004, 2007; `HouseNonClassicDivisions` 2004, 2007; `HousePartyRepresentationLeading` 2004-2010 (older elections have `HousePartyRepresentation` instead); `HouseTppByDivisionByVoteType` 2004-2013. Everything else 200.
- Polling-place latitude/longitude: columns present 2007-2025, absent in 2004. Populated on roughly 93-99% of rows 2007-2025 (rough awk count, not a proper parse: unconfirmed).
- The `.txt` twins (same data, other delimiter) were not fetched. Senate downloads were out of scope.
- Not done by this task: the `ftp://mediafeedarchive` data (another job).

## Inventory

Cells: Y = the file type is now on disk raw under `tallyroom/<id>/` for that election (all of these are new copies; "-" = AEC returns 404, confirmed by probing). The next column says whether an older, separate copy already existed and which repo script reads it. "Used" is judged from grepping `R/` and `scripts/` for the file name or its folder, so a script that reads it under another name would be missed (unconfirmed).

| Download type | 04 | 07 | 10 | 13 | 16 | 19 | 22 | 25 | Existing copy / who uses it |
|---|---|---|---|---|---|---|---|---|---|
| HouseFirstPrefsByCandidateByVoteType | Y | Y | Y | Y | Y | Y | Y | Y | `aec/fedYYYY-firstprefs.csv`; `fetch_preferences_fed.R`, night booth builder (vote-type gaps), candidacies |
| HouseDopByDivision | Y | Y | Y | Y | Y | Y | Y | Y | `aec/fedYYYY-dop.csv`; `flow_key_reconstruction.R`, `parse_transfers_fed.R`, `analysis_pref_flows_aec.R` |
| HouseTcpByCandidateByVoteType | Y | Y | Y | Y | Y | Y | Y | Y | `aec/fedYYYY-tcp.csv`; `fetch_preferences_fed.R`, night booth builder |
| HouseStateFirstPrefsByPollingPlace (x8 states) | Y | Y | Y | Y | Y | Y | Y | Y | `aec/booths/pp-fedYYYY-STATE.csv` 2007-2025 (2004 only a merged file); night booths, notional baselines |
| HouseTcpByCandidateByPollingPlace | Y | Y | Y | Y | Y | Y | Y | Y | `booths/raw-tcp/` for 2022, 2025 only; night booth builder |
| HouseTppByDivision | Y | Y | Y | Y | Y | Y | Y | Y | `aec/raw/tppdiv/` 2007-2025; `flow_key_reconstruction.R` |
| HouseTppByPollingPlace | Y | Y | Y | Y | Y | Y | Y | Y | `aec/booths/tpp-fedYYYY.csv` 2007-2025; `transpose_fed_swing.R` |
| HouseTppFlowByStateByParty | Y | Y | Y | Y | Y | Y | Y | Y | `aec/raw/tppflow/` 2007-2025; `build_aec_tpp_flows.R` (the only AEC flow table the models read) |
| HouseTppFlowByParty | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseTcpFlowByStateByParty | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseTcpFlowByParty | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseTcpFlowByDivision | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseTcpFlowByPP (8 ZIPs) | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseDopByPP (8 ZIPs) | Y | Y | Y | Y | Y | Y | Y | Y | none; unused (ZIPs ~119 MB unzipped for NSW 2025 alone) |
| HouseTppByDivisionByVoteType | - | - | - | - | Y | Y | Y | Y | none; unused |
| HouseTppByState | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseFirstPrefsByParty | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseFirstPrefsByStateByParty | Y | Y | Y | Y | Y | Y | Y | Y | none; unused (carries vote-type shares by party and state) |
| GeneralEnrolmentByDivision / ByState | Y | Y | Y | Y | Y | Y | Y | Y | none; unused (night uses an enrolment figure from elsewhere, see `night_expected_votes()`) |
| GeneralDecVotesIssuedByDivision / ByState | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| GeneralDecVotesReceivedByDivision / ByState | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseTurnoutByDivision / ByState | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseInformalByDivision / ByState | Y | Y | Y | Y | Y | Y | Y | Y | none; unused (informal rows in the booth files are dropped) |
| HouseVotesCountedByDivision / ByState | Y | Y | Y | Y | Y | Y | Y | Y | none; unused (ordinary/absent/provisional/pre-poll/postal counts per division) |
| GeneralPollingPlaces (lat/long 2007+) | Y | Y | Y | Y | Y | Y | Y | Y | none; unused (a `lat` column read in a registry helper did not exist in its input) |
| HouseCandidates | Y | Y | Y | Y | Y | Y | Y | Y | candidate names come from `output/candidacies.csv`, built from the first-prefs file |
| HouseMembersElected | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseNominationsByDivision | - | - | Y | Y | Y | Y | Y | Y | none; unused |
| HouseNominationsByState / ByGender | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseNonClassicDivisions | - | - | Y | Y | Y | Y | Y | Y | none; unused |
| HouseSeatsWhichChangedHands | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HouseSeatsDecidedOnPrefs / OnFirstPrefs | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| HousePartyRepresentation (old name) / ...Leading | Y | Y | Y | Y | Y | Y | Y | Y | none; unused |
| GeneralPartyDetails | Y | Y | Y | Y | Y | Y | Y | Y | none; unused (party registration/abbreviation map) |

Presence of 2004 and 2007 in the HousePartyRepresentationLeading row means "one of the two names exists" (see 404 list above).

## Ranked uses

Value: high = changes a number we publish or fixes a known weakness; medium = tightens something; low = context. "Already computed?" says what in the repo overlaps.

### Top 10

1. **TCP flow by polling place (`HouseTcpFlowByPP` ZIPs), all 8 elections.** For every booth: where each party's first preferences went in the final two. Forecast: replaces the single statewide flow matrix with a booth-level panel (about 8,000 booths x 8 elections), so flow variation by seat type, final-two pair and candidate can be fitted with proper uncertainty and shrinkage (the flow-drift and key-reconstruction work is currently built on division-level tables only). Night model: the live 2CP evidence rule (`night_apply_tcp`, built on Victoria) needs a federal prior for "how much do flows vary booth to booth for a given final two", which is exactly this. Value: high for both. Already computed? Only the 2022 and 2025 booth 2CP totals (`booths/raw-tcp`) and division-level flows; no booth-level flows.
2. **Distribution of preferences by polling place and by division (`HouseDopByPP`, `HouseDopByDivision`), all 8.** Which candidates were excluded in what order and who reached the final two, counted at booth level. Night: the night model discards counted two-candidate pairs it never simulated; the full distribution says, per seat and election, how often the final two was not the first-preference top two (the cases where a night 2CP count looks surprising) and gives the 2PP-order priors for excluded minors. Forecast: calibrates the "who reaches the final two" step (emergence cases such as independents and One Nation) on about 1,100 seat-elections instead of the seven-election subset. Value: high. Already computed? `flow_key_reconstruction.R` reads the division-level DOP (`fedYYYY-dop.csv`); the by-polling-place ZIPs are new.
3. **Declaration votes issued and received, by division (`GeneralDecVotes*`), 2004-2025.** Votes issued (postal applications, pre-poll, absent, provisional) versus received. Night: this is the missing denominator, because issued minus received tells how many postal and pre-poll votes are still to arrive after the night, so "% counted" and the remaining-vote size per seat stop relying on final totals (a caveat already recorded for the Victorian replay). Forecast: expected size of the late pre-poll/postal block by seat type, which is the part that moves close seats. Value: high for night, medium for forecast. Already computed? No; `night_expected_votes()` uses enrolment x turnout only.
4. **Votes counted by vote type (`HouseVotesCountedByDivision`) plus first preferences and 2PP by vote type (`HouseTppByDivisionByVoteType`, `HouseTcpByCandidateByVoteType`, 2016+ for the 2PP file).** The postal/pre-poll/absent shares of the final vote and the party lean of each. Example: Wentworth 2022, Sharma took about 50% of postals against 39% of ordinary votes. Night: the vote-type gap in `night_booth_update(gap_k=)` is currently estimated from one Victorian election; federal vote-type gaps by seat across seven elections, with a seat-type pattern (inner-city, regional), give a real prior for the gap. Forecast: tells us how much of the final result is still to come in by lean, so a seat "leading on the night" can be projected to its final. Value: high. Already computed? The night builder reads the vote-type first-preference file; the 2PP-by-vote-type file and the share columns are unused.
5. **Enrolment by division (`GeneralEnrolmentByDivision`), with turnout and informal by division.** Night: expected total votes = enrolment x turnout is the seat's vote count; the file has close-of-rolls, the reinstatements and the final enrolment, so the expected size is known before polling day and the share counted is honest. Forecast: turnout and informal rates by seat (informal 17.3% in Werriwa 2025 against about 3% elsewhere) change formal-vote denominators and tell us where informal votes distort a primary share; informal rate is also a plausible input for the minor-party and language-community effects. Value: medium-high. Already computed? `night_expected_votes()` takes enrolment and previous turnout, but the AEC series for eight elections is not wired in (unconfirmed that no other source feeds it).
6. **Polling places with latitude and longitude (`GeneralPollingPlaces`), 2007-2025.** Booth coordinates, premises name and type (ordinary, remote, mobile, pre-poll centre). Forecast: build booth-level demographic lean (join to census areas) and a nearest-booth match across redistributions, which today needs name matching and fails when a booth renames. Night: matching 2025 booths to 2022 booths by place when names differ (the booth swing needs the match), and a fallback "nearby booths" swing for new booths. Value: medium-high. Already computed? Booth matching is by division plus name; coordinates are not used anywhere.
7. **TPP and TCP flow by party and state (`HouseTppFlowByParty`, `HouseTcpFlowByStateByParty`, `HouseTcpFlowByParty`), all 8.** Flows of every party's votes to the final two, by state. Forecast: the model reads only `HouseTppFlowByStateByParty`; the TCP versions cover the real finals (ALP v GRN, LNP v IND, and so on) not only ALP/Coalition, which is the case the shipped flow model has the least data for (non-classic divisions). Night: priors for the 2CP update in non-ALP/LNP seats. Value: medium-high. Already computed? `build_aec_tpp_flows.R` for the ALP v Coalition form only.
8. **Non-classic divisions and seats decided on preferences / changed hands (`HouseNonClassicDivisions`, `HouseSeatsDecidedOnPrefs`, `HouseSeatsDecidedOnFirstPrefs`, `HouseSeatsWhichChangedHands`), 2010+ / all.** Labelled lists of seats whose final two was not the major pair, whose winner differed from the first-preference leader, and which changed party. Forecast: a ready-made scoring set for the emergence and surge components (about 600 non-classic seat-elections, with the first-preference leader that lost), instead of reconstructing them. Night: a base rate for "leader on first preferences loses on preferences" by seat type. Value: medium. Already computed? Derived from `candidacies.csv` and the first-prefs file; no cross-check against the AEC's own lists has been run.
9. **First preferences by party and state with vote-type shares (`HouseFirstPrefsByStateByParty`, `HouseFirstPrefsByParty`), all 8.** Statewide share of each party by ordinary / absent / provisional / pre-poll / postal. Night: the first read of a statewide postal and pre-poll lean per party with no booth work; state-level swing check (`TotalSwing`). Forecast: more statewide share history for the statewide level model, and candidate-count context (Contested, Nominations, Elected). Value: medium. Already computed? Statewide shares exist in `aec-fed-firstprefs.csv` aggregated across seats; vote-type shares by party and state are not.
10. **Booth-level TPP (`HouseTppByPollingPlace`) and first preferences by booth for 2004 plus the missing earlier years, with swing columns.** The AEC's own booth swing is carried in the file. Night: a ready cross-check for our booth swing arithmetic (match the AEC's stated swing on 2025 data). Forecast: nothing new beyond what the booths already provide. Value: low-medium (mostly verification). Already computed? `transpose_fed_swing.R` and `tpp-fedYYYY.csv` already use it; this adds 2004 and a clean second copy.

### The rest

| File | Pre-election forecast | Night model | Value |
|---|---|---|---|
| HouseInformalByDivision / ByState | Informal rate by seat, 8 elections: swing in informal is a visible signal of a ballot-paper change (Werriwa 2025 +7.08 points) | Expected informal share to turn raw counts into formal | medium |
| HouseTurnoutByDivision / ByState | Turnout swing by seat; compulsory-voting turnout band for the vote-count denominator | Expected total votes | medium |
| HouseTppByState | Statewide 2PP history back to 2004 | Statewide check | low |
| HouseNominationsByDivision / ByState / ByGender | Number of candidates per seat, a measured driver of the primary vote split and of ballot-order effects; gender of candidates | Count of candidates per seat to size the "other" bucket | low-medium |
| HouseCandidates / MembersElected | Check against `candidacies.csv`: ids, the elected flag and incumbent flag, not names only | Candidate id join for the live feed | low-medium |
| GeneralPartyDetails | Party abbreviation and registered-name map across years (the repo classifies parties itself, so this is a cross-check of `classify_party()` inputs) | Same | low |
| HousePartyRepresentation(Leading) | National seat counts by party and state, a history for chamber totals | Chamber total check | low |
| HouseVotesCountedByState / DecVotes ByState | Statewide aggregates of the division files | Statewide completeness | low |
| HouseSeatsDecidedOnFirstPrefs | Seats won outright on first preferences (base rate) | Early call rule | low |

## Things to check before relying on any of this

- Rows and denominators were not parsed or loaded; this audit looked at headers and first rows only, plus a count of lines. Sanity-check `nrow`, date range and key uniqueness on first load.
- The Division page "returned" timestamps are the last return after the fresh scrutiny and are not election-night times (per the brief); nothing here gives election-night times. The mediafeed archive (another job) is the source for those.
- "Unused" was determined by grepping file names and folder paths, so a script reading these by a path built in pieces would be missed.
- The 2022 and 2025 `HouseTcpByCandidateByPollingPlace` files fetched here are the AEC's current versions; the older copies in `booths/raw-tcp/` were not diffed against them (likely identical for 2022; 2025 may have been refreshed: unconfirmed).
- Not run: any model using these files. These are inputs, ranked by reading the file contents and the model code, not by measurement. Run the registry's `quick_arm.R` screen before claiming any of these improves a score.
- Reproduce: `powershell.exe -Command 'Rscript "scripts/fetch_aec_tallyroom.R"'` (skips files on disk); `docs/DATA-REGISTRY.md` and `docs/DATA-DICTIONARY.md` regenerated 2026-10-30.
