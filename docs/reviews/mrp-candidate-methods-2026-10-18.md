# MRP seat-poll releases: do they model independents by name?

Written 2026-10-18. Status: PARTIAL. No release's own methodology page confirmed
candidate-level modelling. Per-seat rows: `external/reference/polls/seat-polls/mrp_candidates.csv`.
"modelled" there is an INFERENCE from column magnitudes in `seat_polls.csv`
(a large IND column with small OTH = notable independent in IND; blank IND with
large OTH = independent inside OTH), not something a pollster stated.
Sources limited to pre-election pages. The current Wikipedia revision includes
post-election data and was not used to fill gaps.

## Headline
- **No release published named-candidate columns** in the tables we hold. Names appear only in YouGov article prose.
- **YouGov 2025 (3 releases):** generic IND column. Large in teal/independent seats (Warringah 37-44, Clark 40-56, Indi 37-53, Fowler 22-45). Seats held by a minor PARTY or an independent the model files under OTH (Mayo, Kennedy) show small IND and large OTH, so IND is NOT Sharkie/Katter there.
- **YouGov 2022:** IND column blank in every sampled seat; independents sit inside OTH (Warringah OTH 45, Clark 48, Kennedy 43, Mayo 28). Pocock/Rubenstein get their own columns only in the ACT. Method per Poll Bludger: demography-driven, "would be more robust in traditional party-based contests".
- **Accent/RedBridge 2024-05 to 2025-04:** IND column blank in all sampled seats; teals and sitting independents land in OTH (Warringah 36-40, Kooyong 37-43, Indi 52-54). Methodology of the 2024-25 releases NOT read.

## Per release
- **YouGov 2022 (fieldwork end 2022-05-07).** Party columns + IND (blank) + OTH. Source: https://www.pollbludger.net/2022/05/11/yougov-mrp-poll-part-one-and-more/ (2022-05-11). Treat IND as absent; OTH holds independents.
- **YouGov (MRP) 2025-02-12.** Release: https://yougov.com/articles/51612-mrp-coming-soon (page not read; Poll Bludger 2025-02-16 https://www.pollbludger.net/2025/02/16/federal-polls-newspoll-yougov-mrp-redbridge-accent-marginal-seat-polling-open-thread/ says only teal incumbents "are reckoned to be safe"). Mayo: OTH 31.5, IND 1.9. Warringah: IND 37.
- **YouGov (MRP) 2025-03-26.** https://yougov.com/articles/51908-labor-one-seat-short-of-a-majority-in-yougovs-second-mrp-of-the-2025-australian-election (2025-03-29). Prose names Alex Dyson (Wannon) and Caz Heise (Cowper) as projected winners; says "all sitting independents are projected to retain their seats" without naming; explains the MRP only as party/characteristic modelling. Note a stray "YouGo (MRP)" row in the file, one seat, same release.
- **YouGov (MRP) 2025-04-29 (final).** https://yougov.com/articles/52098-labour-to-win-with-an-increased-majority-in-yougovs-final-mrp-of-the-election (2025-04-30). Prose names Caz Heise (Cowper), Alex Dyson (Wannon), Andrew Gee (Calare). No candidate-method text; no seat table in the text. Mayo: OTH 44.2, IND blank.
- **Accent/RedBridge (MRP) 2024-05-01, 2024-08-27, 2024-11-20, 2025-04-01.** Coverage varies (20, 150, 150, 81 seats). Poll Bludger (2024-05-29, 2024-09-08, 2024-12-07, 2025-04-17 threads) and the RedBridge media release PDF (image-only, unreadable by fetch) were located, not read for method. Poll Bludger commentary says these MRPs handle majors better than independents and minors (secondhand, UNVERIFIED). The May 2026 RedBridge/Accent MRP (https://www.accent-research.com/projects/a-fragmented-electorate) is post-dating and out of scope; its page names no candidates.

## Not established (UNVERIFIED)
- Whether any release had candidate lists as model inputs.
- The YouGov 2025 PDF/appendix seat tables (may show candidate names; not checked).
- Archive captures (web.archive.org was blocked by the fetch tool) and dated Wikipedia revisions.
- Recommended next step: open the YouGov per-seat pages and the Accent/RedBridge PDFs in a browser; if tables show names, fill `named_candidate`.
