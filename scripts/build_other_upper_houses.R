# Upper-house vs lower-house FIRST-PREFERENCE shares for NSW 2019/2023, SA 2022/2026 and WA 2021/2025.
#
# Why: Victoria abolished group voting tickets for 2026, so the right analogues for its Legislative Council are upper
# houses already counted on the voter's own preferences. The question this file answers is "how does a party's
# upper-house first-preference share relate to its lower-house share in the SAME election?" (e.g. One Nation).
#
# Inputs  (raw, exactly as received -- scripts/fetch_other_upper_houses.py; manifest.tsv beside each election):
#   <external>/reference/upper-house/<state><year>/
#   and the lower house from the per-district first-preference files already on disk
#   (<external>/elections/{nswec,ecsa,waec}-<year>-*-firstprefs.csv), which hold CLASS-level votes per district.
# Output: output/other-upper-house-fp.csv
#   election, house (upper|lower), geo_level (state|district|region), geo, party_raw, party_class, votes, total_votes,
#   source_file
#
# What each commission publishes (so what geo_level means below):
#   NSW LC  statewide group totals (ATL + BTL) on the check-count page, and group (ATL-only) votes per Legislative
#           Assembly district in the "LC Final Votes" workbook. Below-the-line votes are NOT split by group per
#           district: each district carries one extra row party_raw = "BTL (not attributed to a group)" with
#           party_class NA, so a district's rows still sum to its formal vote.
#   SA  LC  2026: votes by group for every district, polling place and declaration vote. 2022: statewide only (the
#           API returns party totals and nothing finer).
#   WA  LC  2021: six regions, each with its districts. 2025: districts only (one statewide LC region; no region
#           split is published in the file).
#   Lower-house rows carry party_raw == party_class because the stored district files are already class-level.
#
# Every statewide / district / region total is asserted against the commission's own published figure.
# Run: Rscript scripts/build_other_upper_houses.R   (from the repo root; no arrow, a few MB of memory)

suppressPackageStartupMessages({ library(data.table); library(readxl); library(jsonlite); library(xml2); library(rvest) })

args <- commandArgs(trailingOnly = FALSE)
this <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
ROOT <- if (length(this)) normalizePath(file.path(dirname(this[1]), ".."), winslash = "/") else getwd()
source(file.path(ROOT, "R", "parties.R"))
source(file.path(ROOT, "R", "wa_party.R"))

# external/ is gitignored and lives in the main checkout; a worktree has none of it.
find_external <- function() {
  cand <- c(Sys.getenv("AUSPOL_EXTERNAL", ""), file.path(ROOT, "external"),
            file.path(dirname(ROOT), "auspol", "external"))
  cand <- cand[nzchar(cand) & dir.exists(file.path(cand, "reference", "upper-house")) & dir.exists(file.path(cand, "elections"))]
  if (!length(cand)) stop("no external/reference/upper-house found; run scripts/fetch_other_upper_houses.py")
  normalizePath(cand[1], winslash = "/")
}
EXT <- find_external()
RAW <- file.path(EXT, "reference", "upper-house")
LOWER <- file.path(EXT, "elections")
OUT <- file.path(ROOT, "output", "other-upper-house-fp.csv")
dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)
cat(sprintf("external: %s\n", EXT))

num <- function(x) as.numeric(gsub("[^0-9.-]", "", as.character(x)))
chk <- function(ok, msg) { if (!isTRUE(ok)) stop("ASSERT FAILED: ", msg, call. = FALSE); cat("  ok  ", msg, "\n") }
mk <- function(election, house, geo_level, geo, party_raw, party_class, votes, total_votes, source_file) {
  data.table(election = election, house = house, geo_level = geo_level, geo = geo, party_raw = party_raw,
             party_class = party_class, votes = votes, total_votes = total_votes, source_file = source_file)
}
rel <- function(p) sub(paste0("^", EXT, "/"), "", p)
OUTS <- list()

# ---- lower house (district files already on disk) --------------------------------------------------------------------
lower <- function(election, file) {
  f <- file.path(LOWER, file); d <- fread(f)
  stopifnot(identical(names(d), c("seat", "party", "votes")), !anyNA(d$votes))
  tot <- d[, .(total = sum(votes)), by = seat]
  dist <- merge(d, tot, by = "seat")
  a <- mk(election, "lower", "district", dist$seat, dist$party, dist$party, dist$votes, dist$total, rel(f))
  s <- d[, .(votes = sum(votes)), by = party]
  b <- mk(election, "lower", "state", "state", s$party, s$party, s$votes, sum(d$votes),
          paste0("derived: sum of districts in ", rel(f)))
  cat(sprintf("  lower %s: %d districts, %s formal votes\n", election, uniqueN(d$seat), format(sum(d$votes), big.mark = ",")))
  rbind(a, b)
}

# ---- NSW Legislative Council -------------------------------------------------------------------------------------------
nsw_lc <- function(election) {
  dir <- file.path(RAW, election); yr <- sub("nsw", "", election)
  fp <- file.path(dir, "LC-fp_summary.html"); xl <- file.path(dir, sprintf("SGE %s LC Final Votes.xlsx", yr))
  cat(sprintf("\n== %s upper (NSW LC)\n", election))
  tabs <- html_elements(read_html(fp), "table")
  grp <- list(); ung <- NULL; formal <- NA
  for (t in tabs) {
    d <- as.data.table(html_table(t, header = FALSE)); d <- d[-1]
    if (any(grepl("^Formal Votes$", d$X2))) formal <- num(d$X3[d$X2 == "Formal Votes"])
    if (any(grepl("UNGROUPED", d$X2))) {   # ungrouped candidates share a table with the formal/informal footer (2019)
      u <- d[!(X2 %in% c("UNGROUPED CANDIDATES", "", "Formal Votes", "Informal", "Total Votes / Ballot Papers")) & nzchar(X3)]
      ung <- sum(num(u$X3)); next
    }
    head <- d[nzchar(X1)][1]
    grp[[head$X1]] <- data.table(letter = head$X1, name = trimws(head$X2), atl = num(head$X3),
                                 total = num(d$X3[d$X2 == "Group Total"]))
  }
  g <- rbindlist(grp); g[is.na(atl), atl := 0]
  chk(!is.na(formal), sprintf("%s published formal votes = %s", election, format(formal, big.mark = ",")))
  chk(sum(g$total) + ung == formal, "group totals (ATL+BTL) + ungrouped candidates == published formal votes")
  g[, party_raw := ifelse(nzchar(name), name, sprintf("Group %s (no party name published)", letter))]
  g[, party_class := classify_party(name)]
  stat <- rbind(g[, .(party_raw, party_class, votes = total)],
                data.table(party_raw = "UNGROUPED CANDIDATES (all, below-the-line only)", party_class = "IND", votes = ung))
  upper_state <- mk(election, "upper", "state", "state", stat$party_raw, stat$party_class, stat$votes, formal, rel(fp))

  x <- suppressMessages(read_excel(xl, sheet = "LC", col_types = "text")); x <- as.data.table(x)
  gc <- names(x)[match("Venue/Declaration Name", names(x)) + 1L:(match("ATL", names(x)) - match("Venue/Declaration Name", names(x)) - 1L)]
  for (cn in c(gc, "ATL", "BTL", "Formal", "Informal")) set(x, j = cn, value = num(x[[cn]]))
  chk(identical(gc, g$letter), sprintf("workbook group columns %s..%s match the check-count page", gc[1], tail(gc, 1)))
  chk(nrow(x[District %in% c("", NA)]) == 0, "no blank District rows in workbook")
  chk(all(abs(rowSums(x[, ..gc]) - x$ATL) < 1e-9), "per-row group columns sum to ATL")
  chk(all(x$ATL + x$BTL == x$Formal), "per-row ATL + BTL == Formal")
  chk(sum(x$Formal) == formal, sprintf("workbook formal total (%s) == check-count page formal total", format(sum(x$Formal), big.mark = ",")))
  chk(sum(x$Informal) == 278477 || election != "nsw2023", "informal total as published (nsw2023: 278,477)")
  chk(identical(unname(colSums(x[, ..gc])), g$atl), "workbook group column totals == page 'ticket' (ATL) votes per group")
  long <- melt(x[, c("District", gc), with = FALSE], id.vars = "District", variable.name = "letter", value.name = "votes")
  long <- long[, .(votes = sum(votes)), by = .(District, letter)]
  long <- merge(long, g[, .(letter, party_raw, party_class)], by = "letter")
  btl <- x[, .(votes = sum(BTL)), by = District][, `:=`(letter = "BTL", party_raw = "BTL (not attributed to a group)", party_class = NA_character_)]
  dist_tot <- x[, .(total = sum(Formal)), by = District]
  lng <- merge(rbind(long, btl, use.names = TRUE), dist_tot, by = "District")
  chk(uniqueN(lng$District) == 93, "93 Legislative Assembly districts present in the LC workbook")
  upper_dist <- mk(election, "upper", "district", lng$District, lng$party_raw, lng$party_class, lng$votes, lng$total, rel(xl))
  chk(all(upper_dist[, .(s = sum(votes), t = total_votes[1]), by = geo][, s == t]), "every district's rows sum to its formal vote")
  rbind(upper_state, upper_dist)
}

# ---- SA Legislative Council --------------------------------------------------------------------------------------------
sa_lc <- function(election, dt) {
  dir <- file.path(RAW, election); cat(sprintf("\n== %s upper (SA LC)\n", election))
  st <- fromJSON(file.path(dir, sprintf("LCStatic-%s.json", dt)), simplifyVector = FALSE)
  ch <- fromJSON(file.path(dir, sprintf("LCChange-%s-v0.json", dt)), simplifyVector = FALSE)
  src <- rel(file.path(dir, sprintf("LCChange-%s-v0.json", dt)))
  pn <- rbindlist(lapply(st$parties, function(p) data.table(id = p$id, name = p$partyName, code = p$partyId)))
  pn[, party_class := classify_party(name, code)]
  chk(ch$electionStatus == "final", sprintf("%s LC status is 'final' (last updated %s)", election, ch$lastUpdated))
  formal <- ch$totalFormalVotes
  # statewide official party totals: sa2026 stores them as parties[] {id, votes}; sa2022 as parties[] {id, votes, seats}
  sv <- rbindlist(lapply(ch$parties, function(p) data.table(id = p$id, votes = p$votes)))
  sv <- merge(sv, pn, by = "id", all.x = TRUE)
  chk(!anyNA(sv$name), "every statewide party id has a name in LCStatic")
  gap <- formal - sum(sv$votes)
  if (gap != 0) {   # the ECSA API's party list for sa2022 sums 63 votes (0.006%) short of its own totalFormalVotes
    cat(sprintf("  NOTE %s: party votes sum to %s, published totalFormalVotes is %s (gap %d, %.4f%%). Using the party sum as the denominator.
",
                election, format(sum(sv$votes), big.mark = ","), format(formal, big.mark = ","), gap, 100 * gap / formal))
    chk(abs(gap) / formal < 1e-4, "gap is under 0.01% of formal votes")
    formal <- sum(sv$votes)
  } else chk(TRUE, sprintf("statewide party votes sum (%s) == published totalFormalVotes", format(formal, big.mark = ",")))
  out <- mk(election, "upper", "state", "state", sv$name, sv$party_class, sv$votes, formal, src)
  if (!is.null(ch$districts)) {
    rows <- list()
    for (d in ch$districts) {
      acc <- c(lapply(d$pollingPlaces, function(p) p$parties), lapply(d$declarations, function(p) p$partyVotes))
      v <- rbindlist(lapply(acc, function(l) rbindlist(lapply(l, function(q) data.table(id = q$id, votes = q$votes)))))
      rows[[d$districtName]] <- v[, .(votes = sum(votes)), by = id][, geo := d$districtName]
    }
    dv <- rbindlist(rows); dv <- merge(dv, pn, by = "id", all.x = TRUE)
    chk(!anyNA(dv$name), "every district party id has a name")
    chk(uniqueN(dv$geo) == 47, "47 House of Assembly districts present in the LC data")
    # The API's district blocks hold polling-place and declaration votes only. Absent-ordinary votes (cast at a booth
    # outside the voter's own district) are PROBABLY the part that is in the statewide party totals but not attributed to a district (not stated by the ECSA), so
    # district rows cover only part of the statewide vote. Asserted below as a coverage figure, not an equality.
    sm <- dv[, .(v = sum(votes)), by = id][sv, on = "id"]
    chk(all(sm$v <= sm$votes), "district party votes never exceed the published statewide party votes")
    cov <- sum(dv$votes) / formal
    cat(sprintf("  NOTE %s: district rows cover %s of %s formal votes (%.1f%%); the remainder (probably absent-ordinary votes) has no district in the API.
",
                election, format(sum(dv$votes), big.mark = ","), format(formal, big.mark = ","), 100 * cov))
    chk(cov > 0.8 && cov < 1, "district coverage between 80% and 100% of statewide formal votes")
    cat("  per-party coverage range: ", paste(round(range(sm$v / sm$votes), 3), collapse = " .. "), "
")
    dv[, total := sum(votes), by = geo]   # district total = votes attributed to that district (see note above)
    out <- rbind(out, mk(election, "upper", "district", dv$geo, dv$name, dv$party_class, dv$votes, dv$total, src))
  } else cat("  note: no district breakdown in the LC API for this election (statewide only)\n")
  out
}

# ---- WA Legislative Council --------------------------------------------------------------------------------------------
WA_EXTRA <- c(SAP = "Sustainable Australia Party")   # LC-only code, name from the WAEC's own LCCandidateParty list
wa_names <- function(codes, lcparty) {
  nm <- WA_PARTY[codes]
  off <- setNames(lcparty$NAME, lcparty$ELECTORAL_COMMISSION_ABBREVIATION)
  miss <- is.na(nm) & codes %in% names(off); nm[miss] <- off[codes[miss]]
  miss <- is.na(nm) & codes %in% names(WA_EXTRA); nm[miss] <- WA_EXTRA[codes[miss]]
  if (anyNA(nm)) stop("WA party code(s) with no name: ", paste(codes[is.na(nm)], collapse = ", "))
  unname(nm)
}
wa_parse <- function(f, first_hdr_row) {
  # Returns long table: district, code, votes (all vote-type sections summed) plus the file's own TOTALS row.
  z <- suppressMessages(read_excel(f, sheet = 1, col_names = FALSE, col_types = "text", .name_repair = "minimal"))
  z <- as.matrix(z); hdr <- first_hdr_row
  # A block starts at every "Ticket" (2021) / "ATL" (2025) column. Its code is the party code in the header row; a
  # ticket group with no code there (WA 2021 North Metropolitan, TUCAK) is a group of independents, and the WAEC's
  # own JSON totals confirm it ("IND").
  hdr_cols <- which(!is.na(z[hdr, ]) & seq_len(ncol(z)) >= 3)
  starts <- sort(unique(c(hdr_cols, which(z[hdr + 2, ] %in% c("Ticket", "ATL") & seq_len(ncol(z)) >= 3))))
  code_row <- ifelse(is.na(z[hdr, ]), NA_character_, z[hdr, ])
  code_row[starts] <- ifelse(is.na(code_row[starts]), "IND", code_row[starts])
  vv <- which(grepl("Valid", z[hdr + 2, ]) | grepl("Valid", z[hdr + 3, ]))[1]
  chk(!is.na(vv), "found 'Total Valid Votes' column")
  ends <- c(starts[-1] - 1L, vv - 1L)
  data_rows <- which(seq_len(nrow(z)) > hdr + 2 & !is.na(z[, 2]) & z[, 2] != "Subtotal")
  tot_row <- which(z[, 1] == "TOTALS")
  v <- function(r, cols) sum(num(z[r, cols]), na.rm = TRUE)
  per <- rbindlist(lapply(data_rows, function(r)
    data.table(row = r, district = z[r, 2], code = code_row[starts], votes = mapply(function(a, b) v(r, a:b), starts, ends),
               valid = num(z[r, vv]))))
  chk(per[, sum(votes) == valid[1], by = row][, all(V1)], "every district/vote-type row: party columns sum to its 'Total Valid Votes'")
  tot <- data.table(code = code_row[starts], votes = mapply(function(a, b) v(tot_row, a:b), starts, ends))
  tot <- tot[, .(votes = sum(votes)), by = code]   # 2021 lists each independent group as its own "IND" block
  list(per = per, tot = tot, valid_total = num(z[tot_row, vv]))
}
wa_lc <- function(election) {
  dir <- file.path(RAW, election); cat(sprintf("\n== %s upper (WA LC)\n", election))
  js <- fromJSON(file.path(dir, "LCResultsByParty.json"), simplifyVector = FALSE)
  lcp <- rbindlist(lapply(js$LCCandidateParty, function(p) data.table(NAME = p$NAME, ELECTORAL_COMMISSION_ABBREVIATION = p$ELECTORAL_COMMISSION_ABBREVIATION)))
  off <- rbindlist(lapply(js$LCRegionResultsByPartyVotesCounted, function(p)
    data.table(region = p$ELECTORATE_NAME, code = p$ELECTORAL_COMMISSION_ABBREVIATION,
               votes = if (is.null(p$FORMAL_LAST_PUBLISHED_NUMBER_ENTERED)) 0L else p$FORMAL_LAST_PUBLISHED_NUMBER_ENTERED,
               total = p$TOTAL_FORMAL_LAST_PUBLISHED_NUMBER_ENTERED)))   # null votes = party did not stand in that region
  # the WAEC lists ungrouped independents as code "Other"; the first-preference workbooks fold them into "IND"
  # (2025: IND 23,253 in the workbook == IND 20,795 + Other 2,458 in the JSON)
  off[code == "Other", code := "IND"]
  off <- off[, .(votes = sum(votes), total = total[1]), by = .(region, code)]
  jsrc <- rel(file.path(dir, "LCResultsByParty.json"))
  mkclass <- function(codes) { nm <- wa_names(codes, lcp); list(nm = nm, cls = classify_party(nm, codes)) }
  out <- list()
  if (election == "wa2025") {
    f <- file.path(dir, "Whole_of_State_First_Preference_Analysis_Report_by_Candidate.xlsx")
    r <- wa_parse(f, 3L)
    r$per[district == "Plbara", district := "Pilbara"]   # typo in the commission's workbook (WAEC spells it "Plbara")
    chk(uniqueN(r$per$district) == 59, "59 Legislative Assembly districts present in the LC first-preference report")
    d <- r$per[, .(votes = sum(votes)), by = .(district, code)]
    ws <- d[, .(votes = sum(votes)), by = code]
    chk(identical(ws[order(code)]$votes, r$tot[order(code)]$votes), "district sums == the report's own TOTALS row, every party")
    o <- off[region == "Whole of State (Legislative Council)"]
    cmp <- merge(ws, o, by = "code", all = TRUE)
    if (anyNA(cmp$votes.x) || anyNA(cmp$votes.y) || any(cmp$votes.x != cmp$votes.y)) print(cmp)
    chk(!anyNA(cmp$votes.x) && !anyNA(cmp$votes.y) && all(cmp$votes.x == cmp$votes.y),
        "statewide party votes == WAEC LCResultsByParty JSON, every party (incl. same party set)")
    formal <- o$total[1]
    chk(sum(ws$votes) == formal, sprintf("sum of party votes (%s) == published formal total", format(formal, big.mark = ",")))
    chk(r$valid_total == formal, "report 'Total Valid Votes' TOTALS cell == published formal total")
    k <- mkclass(ws$code)
    out$state <- mk(election, "upper", "state", "state", k$nm, k$cls, ws$votes, formal, rel(f))
    k <- mkclass(d$code); d[, total := sum(votes), by = district]
    out$dist <- mk(election, "upper", "district", d$district, k$nm, k$cls, d$votes, d$total, rel(f))
    rg <- NULL
  } else {
    regs <- c(Agricultural = "Agricultural", EastMetro = "East Metropolitan", MiningPastoral = "Mining and Pastoral",
              NorthMetro = "North Metropolitan", SouthMetro = "South Metropolitan", SouthWest = "South West")
    dl <- list(); rl <- list(); map <- list()
    for (k in names(regs)) {
      f <- file.path(dir, sprintf("%s_FirstPreferences.xlsx", k)); r <- wa_parse(f, 2L)
      d <- r$per[, .(votes = sum(votes)), by = .(district, code)]
      rs <- d[, .(votes = sum(votes)), by = code]
      chk(identical(rs[order(code)]$votes, r$tot[order(code)]$votes), sprintf("%s: district sums == the report's own TOTALS row", k))
      # official JSON: ELECTORATE_NAME is the short region name
      jn <- off[region == k | region == regs[[k]] | region == sub(" Metro", " Metropolitan", k)]
      if (!nrow(jn)) jn <- off[tolower(gsub("[^a-z]", "", region)) == tolower(gsub("[^A-Za-z]", "", regs[[k]]))]
      chk(nrow(jn) > 0, sprintf("%s: found region in WAEC LCResultsByParty JSON ('%s')", k, jn$region[1]))
      cmp <- merge(rs[votes > 0], jn[votes > 0], by = "code", all = TRUE)
      if (anyNA(cmp$votes.x) || anyNA(cmp$votes.y) || any(cmp$votes.x != cmp$votes.y)) print(cmp[is.na(votes.x) | is.na(votes.y) | votes.x != votes.y])
      chk(!anyNA(cmp$votes.x) && !anyNA(cmp$votes.y) && all(cmp$votes.x == cmp$votes.y),
          sprintf("%s: regional party votes == WAEC JSON, every party", k))
      chk(sum(rs$votes) == jn$total[1] && r$valid_total == jn$total[1],
          sprintf("%s: formal total %s == published", k, format(jn$total[1], big.mark = ",")))
      d[, region := regs[[k]]]; dl[[k]] <- d; rl[[k]] <- rs[, region := regs[[k]]]
      rl[[k]][, total := jn$total[1]]
    }
    d <- rbindlist(dl); d[, total := sum(votes), by = district]
    chk(uniqueN(d$district) == 59, "59 districts across the six regions")
    kd <- mkclass(d$code)
    out$dist <- mk(election, "upper", "district", d$district, kd$nm, kd$cls, d$votes, d$total,
                   rel(file.path(dir, "<Region>_FirstPreferences.xlsx (six files)")))
    rg <- rbindlist(rl); kr <- mkclass(rg$code)
    out$reg <- mk(election, "upper", "region", rg$region, kr$nm, kr$cls, rg$votes, rg$total, rel(file.path(dir, "<Region>_FirstPreferences.xlsx (six files)")))
    ws <- rg[, .(votes = sum(votes)), by = code]; formal <- sum(rg[, .(t = total[1]), by = region]$t)
    chk(sum(ws$votes) == formal, sprintf("statewide (six regions) party votes sum (%s) == sum of regional published totals", format(formal, big.mark = ",")))
    ks <- mkclass(ws$code)
    out$state <- mk(election, "upper", "state", "state", ks$nm, ks$cls, ws$votes, formal, "derived: sum of the six regional files")
    # lower-house region rows for the same election (district -> region from the LC workbooks)
    attr(out, "district_region") <- unique(d[, .(district, region)])
  }
  out
}

# ---- assemble --------------------------------------------------------------------------------------------------------------
res <- list()
res[["nsw2019"]] <- rbind(nsw_lc("nsw2019"), lower("nsw2019", "nswec-2019-nsw-firstprefs.csv"))
res[["nsw2023"]] <- rbind(nsw_lc("nsw2023"), lower("nsw2023", "nswec-2023-nsw-firstprefs.csv"))
res[["sa2022"]]  <- rbind(sa_lc("sa2022", "2022-03-19"), lower("sa2022", "ecsa-2022-sa-firstprefs.csv"))
res[["sa2026"]]  <- rbind(sa_lc("sa2026", "2026-03-21"), lower("sa2026", "ecsa-2026-sa-firstprefs.csv"))
w25 <- wa_lc("wa2025"); res[["wa2025"]] <- rbind(rbindlist(w25), lower("wa2025", "waec-2025-wa-firstprefs.csv"))
w21 <- wa_lc("wa2021"); l21 <- lower("wa2021", "waec-2021-wa-firstprefs.csv")
dr <- attr(w21, "district_region")
lr <- merge(l21[geo_level == "district"], dr, by.x = "geo", by.y = "district", all.x = TRUE)
chk(!anyNA(lr$region), "every wa2021 lower-house district maps to an LC region")
lreg <- lr[, .(votes = sum(votes)), by = .(region, party_raw, party_class)]
lreg[, total := sum(votes), by = region]
lreg <- mk("wa2021", "lower", "region", lreg$region, lreg$party_raw, lreg$party_class, lreg$votes, lreg$total,
           "derived: lower-house districts summed to the LC region they belong to")
res[["wa2021"]] <- rbind(rbindlist(w21), l21, lreg)

all <- rbindlist(res, use.names = TRUE)
# coverage: every district present on both sides, and every election has both houses at state level
cat("\n== cross-house checks\n")
for (e in names(res)) {
  d <- all[election == e & geo_level == "district"]
  up <- unique(d[house == "upper", geo]); lo <- unique(d[house == "lower", geo])
  if (length(up)) {
    cat(sprintf("  %s: %d upper districts, %d lower districts, upper-only: [%s], lower-only: [%s]\n", e, length(up), length(lo),
                paste(setdiff(up, lo), collapse = ", "), paste(setdiff(lo, up), collapse = ", ")))
    if (length(setdiff(up, lo)) || length(setdiff(lo, up))) stop("district names differ between houses in ", e)
  } else cat(sprintf("  %s: upper house has no district breakdown (statewide only)\n", e))
  chk(all(c("upper", "lower") %in% all[election == e & geo_level == "state", house]), paste(e, "has statewide upper and lower"))
}
# coverage of every column (a 100% empty column should fail the build)
for (cn in c("election", "house", "geo_level", "geo", "party_raw", "votes", "total_votes", "source_file"))
  chk(!anyNA(all[[cn]]) && all(nzchar(as.character(all[[cn]]))), paste("column", cn, "fully populated"))
cat(sprintf("  party_class missing on %d rows (all must be the NSW BTL-unattributed rows): ", sum(is.na(all$party_class))))
chk(all[is.na(party_class), all(grepl("^BTL", party_raw))], "NA party_class only on 'BTL (not attributed to a group)' rows")
chk(all(all$votes >= 0) && all(all$votes == round(all$votes)), "votes are non-negative integers")
setorder(all, election, house, geo_level, geo, -votes)
fwrite(all, OUT)
cat(sprintf("\nwrote %s: %s rows\n", OUT, format(nrow(all), big.mark = ",")))

# lower-house totals as published by the NSWEC (pastvtr LA/state/formal, fetched 26 Nov 2026): 2019 4,551,886; 2023 4,701,930
for (e in c("nsw2019", "nsw2023")) {
  pub <- c(nsw2019 = 4551886, nsw2023 = 4701930)[[e]]
  chk(all[election == e & house == "lower" & geo_level == "state", total_votes[1]] == pub, sprintf("%s lower-house formal votes == NSWEC published %s", e, format(pub, big.mark = ",")))
}

# ---- party_raw -> class audit (so a wrong class is visible) -------------------------------------------------------------
cat("\n== upper-house statewide party_raw -> class (votes; check these by eye)\n")
aud <- all[house == "upper" & geo_level == "state", .(election, party_raw, party_class, votes, share = round(100 * votes / total_votes, 2))]
options(width = 200)
print(as.data.frame(aud[share >= 0.5][order(election, -votes)]), row.names = FALSE)

# ---- summary: statewide upper vs lower ---------------------------------------------------------------------------------------
cat("\n== statewide first-preference share, upper (LC) vs lower (assembly), same election\n")
cat("   share = party votes / formal votes in that house, in per cent; ratio = upper share / lower share\n")
cat("   (above 1: the party does better in the upper house). others = every class not listed.\n")
st <- all[geo_level == "state" & !is.na(party_class)]
st[, grp := fifelse(party_class %in% c("ALP", "LNP", "GRN", "ONP"), party_class, "OTHERS")]
sm <- st[, .(votes = sum(votes), total = total_votes[1]), by = .(election, house, grp)]
w <- dcast(sm, election + grp ~ house, value.var = c("votes", "total"))
# NSW upper totals include BTL votes in group totals already; the NA-class rows only exist at district level
w[, `:=`(upper_pct = round(100 * votes_upper / total_upper, 2), lower_pct = round(100 * votes_lower / total_lower, 2))]
w[, ratio := round(upper_pct / lower_pct, 2)]
w[, grp := factor(grp, c("ALP", "LNP", "GRN", "ONP", "OTHERS"))]
print(as.data.frame(w[order(election, grp), .(election, party = grp, upper_votes = votes_upper, upper_formal = total_upper, upper_pct,
                                lower_votes = votes_lower, lower_formal = total_lower, lower_pct, ratio)]), row.names = FALSE)
