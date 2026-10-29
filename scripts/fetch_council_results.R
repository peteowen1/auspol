# UPPER-HOUSE (LEGISLATIVE COUNCIL) RESULTS, VICTORIA 2022 AND 2018: first
# preferences by group, candidate and voting centre, and the published
# preference distributions. Ticket #156 (map: #148).
#
# Source: Excel downloads on the VEC's public blob container, linked from the
# per-region results pages (2022) and the archived 2018 site. Three files per
# region per year:
#   Results by Voting Centre      group-level ATL / BTL / Total for every
#                                 voting centre (2022 "<Region> Region-Results
#                                 by Voting Centre.xls"; 2018
#                                 "<region>-consolidatedrecheckresults.xls")
#   Votes Received                candidate-level first preferences by voting
#                                 centre, one wide table per district
#   Distribution of Preferences   the count-by-count distribution
# plus the Group Voting Ticket PDFs, saved raw and NOT parsed (2018 used
# tickets; the parsed tables here do not cover them).
#
# The blob names do not carry the election (2022: State/Reports/ is the
# standing report folder; the booth script found one file there overwritten by
# a later poll). So a file is accepted only when its OWN header says
# "State Election <year>" and the expected region, and it passes the sum checks
# below. Never on size alone.
#
# Raw files go to external/reference/vec/<year>/council/ exactly as received,
# one file per request, with manifest.csv (url, UTC time, HTTP status, bytes,
# sha256, accepted). Re-running skips files already on disk that still pass.
# The three extracts are NOT equally good. Votes Received and the Distribution
# agree exactly (region formal papers; every group's count-1 total) in every
# region of both years, and are treated as authoritative for region and
# district totals. Results by Voting Centre is a different snapshot that
# differs from both in every region; it is kept as the voting-centre detail.
# See extract_gaps() for the tolerance and output/council-extract-gaps-<year>.csv.
# Parsed tables:
#   output/council-fp-<year>.csv       group x voting centre: atl, btl, total
#   output/council-fp-cand-<year>.csv  candidate x voting centre, every column
#   output/council-dist-<year>.csv     distribution of preferences, long
#   output/council-district-stats-<year>.csv  per district: enrolment, formal, informal, total votes (voting-centre
#                                      file), the same from Votes Received, and the distribution's regional figures
#   output/council-extract-gaps-<year>.csv    every gap between the three extracts (region, group)
#
# Checks (any failure stops, code UH*): every voting-centre block sums to its
# own total row; voting centres sum to the "<District> Total" block; group
# totals sum to the district's stated Formal Votes and Informal Votes;
# candidate-level columns add up to group totals; district formal totals sum to
# the distribution file's regional "Formal Ballot Papers"; the first count of
# the distribution equals the same figure.
#
#   Rscript scripts/fetch_council_results.R            both years
#   AUSPOL_COUNCIL_YEARS=2022 Rscript scripts/fetch_council_results.R
#
# Set AUSPOL_COUNCIL_LIB_ONLY=1 before sourcing to load only the parsers (the
# tests do this).

BLOB <- "https://itsitecoreblobvecprd01.blob.core.windows.net/public-files"
REGIONS <- list(
  `2022` = c("Eastern Victoria", "North-Eastern Metropolitan", "Northern Metropolitan",
             "Northern Victoria", "South-Eastern Metropolitan", "Southern Metropolitan",
             "Western Metropolitan", "Western Victoria"),
  `2018` = c("Eastern Metropolitan", "Eastern Victoria", "Northern Metropolitan",
             "Northern Victoria", "South-Eastern Metropolitan", "Southern Metropolitan",
             "Western Metropolitan", "Western Victoria"))

# ---------------------------------------------------------------- helpers
uh_stop <- function(code, ...) stop(code, "! ", ..., call. = FALSE)

# Numbers arrive as "13,529" text or plain numbers; "---" and blanks are NA.
# A cell that is neither is a parse failure, not a zero.
tonum <- function(x) {
  x <- gsub(",", "", trimws(as.character(x)))
  blank <- is.na(x) | x %in% c("", "---", "-")
  out <- suppressWarnings(as.numeric(x))
  if (any(!blank & is.na(out))) uh_stop("UH1", "non-numeric cell(s): ", paste(utils::head(x[!blank & is.na(out)], 3), collapse = " | "))
  out[blank] <- NA_real_
  out
}
z <- function(x) ifelse(is.na(x), 0, x)

# Every sheet as a character matrix with at least `minc` columns.
read_sheets <- function(path, minc = 5L) {
  sh <- readxl::excel_sheets(path)
  lapply(sh, function(s) {
    d <- suppressMessages(readxl::read_excel(path, sheet = s, col_names = FALSE, .name_repair = "minimal", col_types = "text"))
    m <- as.matrix(d); mode(m) <- "character"
    if (ncol(m) < minc) m <- cbind(m, matrix(NA_character_, nrow(m), minc - ncol(m)))
    m
  })
}
cell <- function(m, i, j) { v <- if (i <= nrow(m) && j <= ncol(m)) m[i, j] else NA_character_; if (is.na(v)) NA_character_ else trimws(v) }
check_header <- function(m, year, region, title, rows) {
  if (!isTRUE(startsWith(cell(m, 1, 1), title))) uh_stop("UH2", "title is '", cell(m, 1, 1), "', expected '", title, "'")
  yr <- paste("State Election", year)
  if (!isTRUE(cell(m, rows[1], 1) == yr)) uh_stop("UH2", "row ", rows[1], " says '", cell(m, rows[1], 1), "', expected '", yr, "' (wrong election vintage?)")
  if (!isTRUE(startsWith(cell(m, rows[2], 1), paste(region, "Region")))) uh_stop("UH2", "row ", rows[2], " says '", cell(m, rows[2], 1), "', expected region '", region, "'")
}
split_vc <- function(lab) {          # "Pakenham EO - EVC - Early" -> name "Pakenham EO - EVC", type "Early"
  hit <- regexpr(" - [^-]*$", lab)
  if (hit < 0) return(c(lab, NA_character_))
  c(substr(lab, 1, hit - 1), trimws(substring(lab, hit + 3)))
}
norm_type <- function(x) {
  x <- tolower(trimws(sub("[0-9 ]+$", "", x)))
  ifelse(is.na(x), NA_character_, gsub(" +", "_", x))
}
same <- function(a, b) isTRUE(all(z(a) == z(b)))

REGION_ROW <- "[REGION]"
# ---------------------------------------------------- Results by Voting Centre
# Per sheet: a district header ("Bass District", then Enrolment / Formal /
# Informal / Total Votes lines), then blocks. A block opens with a row whose
# columns 3-5 read ATL / BTL / Total (its label is "<centre> - <vote type>"),
# followed by GROUP rows, UNGROUPED rows, Informal, and an unlabelled total
# row. "<District> Total" is the district's own block.
parse_rbvc <- function(sheets, year, region, file = NA_character_) {
  check_header(sheets[[1]], year, region, "Region Result", c(3, 4))
  rows <- list(); stats <- list()
  district <- NA_character_; vc <- NA_character_; kind <- NA_character_
  seen_total <- FALSE; k <- 0L
  num <- function(m, i) c(tonum(cell(m, i, 3)), tonum(cell(m, i, 4)), tonum(cell(m, i, 5)))
  add <- function(row_kind, group, group_name, v, s, i) {
    k <<- k + 1L
    parts <- split_vc(vc)
    rows[[k]] <<- list(year, region, district, vc, parts[1], parts[2], row_kind, kind, group, group_name, v[1], v[2], v[3], s, i)
  }
  for (s in seq_along(sheets)) {
    m <- sheets[[s]]
    for (i in seq_len(nrow(m))) {
      lab <- cell(m, i, 1)
      if (!is.na(lab) && !nzchar(lab)) lab <- NA_character_
      if (!is.na(lab) && i < nrow(m) && grepl("^Enrolment\\s*:", cell(m, i + 1, 1) %||% "")) {
        district <- lab; vc <- NA_character_
        g <- function(r) tonum(sub("^[^:]*:\\s*", "", cell(m, i + r, 1)))
        stats[[length(stats) + 1L]] <- data.frame(year = year, region = region, district = district,
          enrolment = g(1), formal = g(2), informal = g(3), total_votes = g(4), stringsAsFactors = FALSE)
        next
      }
      if (is.na(district)) next                                   # title rows above the first district
      if (!is.na(lab) && grepl("^(Enrolment|Formal Votes|Informal Votes|Total Votes)\\s*:", lab)) next
      if (!is.na(cell(m, i, 3)) && cell(m, i, 3) == "ATL" && isTRUE(cell(m, i, 5) == "Total")) {
        if (is.na(lab)) uh_stop("UH3", "sheet ", s, " row ", i, ": block header without a label")
        vc <- lab
        if (lab == paste(region, "Region Total")) district <- REGION_ROW
        kind <- if (district == REGION_ROW) "region_total" else if (grepl(" Total$", lab)) "district_total" else "voting_centre"
        if (kind == "district_total" && sub(" Total$", "", lab) != district)
          uh_stop("UH3", "sheet ", s, " row ", i, ": '", lab, "' inside district '", district, "'")
        seen_total <- FALSE
        next
      }
      if (is.na(vc)) {
        if (is.na(lab) && all(is.na(num(m, i)))) next
        uh_stop("UH3", "sheet ", s, " row ", i, ": data row '", lab, "' outside any block")
      }
      v <- num(m, i)
      if (is.na(lab)) {
        if (all(is.na(v))) next
        if (seen_total) uh_stop("UH3", "sheet ", s, " row ", i, ": second total row in block '", vc, "'")
        add("block_total", NA_character_, NA_character_, v, s, i); seen_total <- TRUE
      } else if (kind == "region_total" && lab %in% c("Total Formal Votes", "Total Informal", "Total Votes Polled")) {
        add(c(`Total Formal Votes` = "region_formal", `Total Informal` = "region_informal", `Total Votes Polled` = "region_polled")[[lab]], NA_character_, lab, v, s, i)
      } else if (grepl("^GROUP [A-Z]+( - .*)?$", lab)) {      # an unnamed group prints as "GROUP E" alone
        add("group", sub("^GROUP ([A-Z]+)( - .*)?$", "\\1", lab), if (grepl(" - ", lab)) sub("^GROUP [A-Z]+ - ", "", lab) else NA_character_, v, s, i)
      } else if (grepl("^UNGROUPED - ", lab)) {
        add("ungrouped", "UNGROUPED", sub("^UNGROUPED - ", "", lab), v, s, i)
      } else if (lab == "Informal") {
        add("informal", NA_character_, "Informal", v, s, i)
      } else uh_stop("UH3", "sheet ", s, " row ", i, ": unrecognised row '", lab, "'")
    }
  }
  if (!length(rows)) uh_stop("UH3", "no data rows parsed from ", basename(file))
  col <- function(j) unlist(lapply(rows, `[[`, j))
  out <- data.frame(year = year, region = region, district = col(3), voting_centre = col(4),
    vc_name = col(5), vote_type_raw = col(6), vote_type = norm_type(col(6)), block_kind = col(8), row_kind = col(7),
    group = col(9), group_name = col(10), atl = col(11), btl = col(12), total = col(13),
    source_file = basename(file), sheet = col(14), row = col(15), stringsAsFactors = FALSE)
  st <- do.call(rbind, stats)
  check_rbvc(out, st)
  list(data = out, stats = st)
}
`%||%` <- function(a, b) if (is.null(a) || is.na(a)) b else a

check_rbvc <- function(df, st) {
  rt <- df[df$block_kind == "region_total", ]; df <- df[df$block_kind != "region_total", ]
  cnt <- df$row_kind %in% c("group", "ungrouped")
  # a. every block adds up to its own total row; each group row to atl + btl
  key <- paste(df$district, df$voting_centre, sep = "\r")
  bt <- df[df$row_kind == "block_total", ]
  if (anyDuplicated(paste(bt$district, bt$voting_centre, sep = "\r"))) uh_stop("UH4", "a block has two total rows")
  if (!setequal(unique(key), paste(bt$district, bt$voting_centre, sep = "\r")))
    uh_stop("UH4", "blocks without a total row: ", paste(utils::head(setdiff(unique(key), paste(bt$district, bt$voting_centre, sep = "\r")), 3), collapse = " ; "))
  for (col in c("atl", "btl")) {
    got <- tapply(z(df[[col]][cnt]), key[cnt], sum)
    want <- setNames(z(bt[[col]]), paste(bt$district, bt$voting_centre, sep = "\r"))
    bad <- names(got)[got != want[names(got)]]
    if (length(bad)) uh_stop("UH4", col, " does not sum to the block total in ", length(bad), " block(s), first: ", gsub("\r", " / ", bad[1]))
  }
  tt <- df$row_kind %in% c("group", "ungrouped", "informal")
  got <- tapply(z(df$total[tt]), key[tt], sum)
  want <- setNames(z(bt$total), paste(bt$district, bt$voting_centre, sep = "\r"))
  bad <- names(got)[got != want[names(got)]]
  if (length(bad)) uh_stop("UH4", "total does not sum to the block total in ", length(bad), " block(s), first: ", gsub("\r", " / ", bad[1]))
  g <- df[cnt, ]
  if (!same(g$total, z(g$atl) + z(g$btl))) uh_stop("UH4", "a group row's total is not atl + btl")
  # b. voting centres add up to the district block; district formal/informal match the page's own figures
  for (d in setdiff(unique(df$district), REGION_ROW)) {
    dd <- df[df$district == d, ]
    dtot <- dd[dd$block_kind == "district_total" & dd$row_kind != "block_total", ]
    vcs <- dd[dd$block_kind == "voting_centre" & dd$row_kind != "block_total", ]
    if (!nrow(dtot)) uh_stop("UH5", d, ": no '<District> Total' block")
    if (!nrow(vcs)) uh_stop("UH5", d, ": no voting-centre blocks")
    id <- paste(dtot$row_kind, dtot$group, dtot$group_name); iv <- paste(vcs$row_kind, vcs$group, vcs$group_name)
    if (!setequal(id, iv)) uh_stop("UH5", d, ": group lists differ between the district block and the voting centres")
    for (col in c("atl", "btl", "total")) {
      got <- tapply(z(vcs[[col]]), iv, sum); want <- setNames(z(dtot[[col]]), id)
      bad <- names(got)[got != want[names(got)]]
      if (length(bad)) uh_stop("UH5", d, ": voting centres do not sum to the district block (", col, ") for ", bad[1])
    }
    s <- st[st$district == d, ]
    if (nrow(s) != 1L) uh_stop("UH5", d, ": ", nrow(s), " statistics headers")
    formal <- sum(z(dtot$total[dtot$row_kind %in% c("group", "ungrouped")])); inf <- sum(z(dtot$total[dtot$row_kind == "informal"]))
    if (formal != s$formal) uh_stop("UH5", d, ": group totals ", formal, " vs stated Formal Votes ", s$formal)
    if (inf != s$informal) uh_stop("UH5", d, ": informal ", inf, " vs stated Informal Votes ", s$informal)
  }
  # c. the region block (when the file has one) states formal / informal / polled for the whole region
  if (nrow(rt)) {
    rv <- function(k) { x <- rt$total[rt$row_kind == k]; if (length(x) != 1L) uh_stop("UH5", "region block lacks a single ", k, " row"); x }
    if (sum(st$formal) != rv("region_formal")) uh_stop("UH5", "district Formal Votes sum to ", sum(st$formal), " but the region block says ", rv("region_formal"))
    if (sum(st$informal) != rv("region_informal")) uh_stop("UH5", "district informal sums to ", sum(st$informal), " but the region block says ", rv("region_informal"))
    if (rv("region_formal") + rv("region_informal") != rv("region_polled")) uh_stop("UH5", "region formal + informal != Total Votes Polled")
  }
  invisible(TRUE)
}

# ------------------------------------------------------------- Votes Received
# One wide table per district: header row (column labels with embedded
# newlines: "Group A\n<party>\nATL", "Group A\n<party>\n<CANDIDATE>",
# "Group A\nTOTAL", "Ungrouped\n<CANDIDATE>", "Total ATL", ... "Total Votes"),
# ordinary voting centres, TOTAL ORDINARY VOTES, declaration-vote rows,
# TOTAL DECLARATION VOTE, DISTRICT TOTAL. A header cell that is blank above a
# column that holds numbers is a parse failure; above an empty column it is a
# spacer, recorded and skipped.
parse_header_cell <- function(txt) {
  p <- trimws(strsplit(txt, "\n", fixed = TRUE)[[1]]); p <- p[nzchar(p)]
  if (grepl("^Group [A-Z]+$", p[1])) {
    g <- sub("^Group ", "", p[1])
    if (length(p) == 2L && p[2] == "TOTAL") return(list(group = g, group_name = NA, candidate = NA, kind = "group_total"))
    if (length(p) == 2L) return(list(group = g, group_name = NA, candidate = if (p[2] == "ATL") NA else p[2], kind = if (p[2] == "ATL") "atl" else "candidate"))   # unnamed group
    if (length(p) == 3L) return(list(group = g, group_name = p[2], candidate = if (p[3] == "ATL") NA else p[3], kind = if (p[3] == "ATL") "atl" else "candidate"))
  } else if (toupper(p[1]) == "UNGROUPED" && length(p) == 2L) {
    return(list(group = "UNGROUPED", group_name = NA, candidate = p[2], kind = "candidate"))
  } else if (length(p) == 1L && grepl("^Total (ATL|BTL|Formal|Informal|Votes)$", p[1])) {
    return(list(group = NA, group_name = NA, candidate = NA, kind = paste0("total_", tolower(sub("^Total ", "", p[1])))))
  }
  uh_stop("UH6", "unrecognised column header '", gsub("\n", "~", txt), "'")
}

parse_votes <- function(sheets, year, region, file = NA_character_) {
  if (length(sheets) != 1L) uh_stop("UH6", "expected one sheet, found ", length(sheets))
  m <- sheets[[1]]
  check_header(m, year, region, "Region Votes Received", c(4, 6))
  hdr <- which(!is.na(m[, 4]) & grepl("\n", m[, 4], fixed = TRUE))
  if (!length(hdr)) uh_stop("UH6", "no district header rows")
  ends <- c(hdr[-1] - 1L, nrow(m))
  out <- list(); spacers <- 0L
  for (h in seq_along(hdr)) {
    district <- sub(" District$", "", cell(m, hdr[h], 1)); rr <- (hdr[h] + 1L):ends[h]
    is_region <- is.na(district); if (is_region) district <- REGION_ROW
    cols <- 4:ncol(m); meta <- list(); keep <- integer()
    for (j in cols) {
      t <- m[hdr[h], j]
      if (is.na(t)) {
        if (any(!is.na(m[rr, j]) & nzchar(trimws(m[rr, j])))) uh_stop("UH6", district, ": column ", j, " has no header but holds numbers")
        spacers <- spacers + 1L; next
      }
      meta[[length(meta) + 1L]] <- parse_header_cell(t); keep <- c(keep, j)
    }
    V <- vapply(keep, function(j) tonum(m[rr, j]), numeric(length(rr)))
    if (!is.matrix(V)) V <- matrix(V, nrow = length(rr))
    kinds <- vapply(meta, `[[`, "", "kind"); grp <- vapply(meta, function(x) x$group %||% NA_character_, "")
    labs <- vapply(rr, function(i) cell(m, i, 1) %||% "", "")
    phase <- "voting_centre"; rk <- rep(NA_character_, length(rr))
    for (r in seq_along(rr)) {
      l <- labs[r]
      if (!nzchar(l)) { if (any(!is.na(V[r, ]))) uh_stop("UH7", district, ": unlabelled row with numbers"); next }
      rk[r] <- if (l == "TOTAL ORDINARY VOTES") { phase <- "declaration"; "total_ordinary" }
               else if (grepl("^TOTAL DECLARATION VOTES?$", l)) "total_declaration"
               else if (l == "DISTRICT TOTAL") "district_total" else phase
    }
    if (is_region) { rk <- ifelse(labs == "REGION TOTAL", "region_total", NA_character_); phase <- "region" }
    for (need in if (is_region) "region_total" else c("total_ordinary", "total_declaration", "district_total"))
      if (sum(rk == need, na.rm = TRUE) != 1L) uh_stop("UH7", district, ": expected exactly one '", need, "' row")
    use <- !is.na(rk); Vz <- V; Vz[is.na(Vz)] <- 0
    sm <- function(rows, cl = seq_len(ncol(V))) colSums(Vz[rows & use, cl, drop = FALSE])
    ord <- sm(rk == "voting_centre"); dec <- sm(rk == "declaration")
    tot <- function(k) Vz[which(rk == k), ]
    if (!is_region) {
    if (!all(ord == tot("total_ordinary"))) uh_stop("UH7", district, ": ordinary centres do not sum to TOTAL ORDINARY VOTES (column ", which(ord != tot("total_ordinary"))[1], ")")
    if (!all(dec == tot("total_declaration"))) uh_stop("UH7", district, ": declaration rows do not sum to TOTAL DECLARATION VOTE")
    if (!all(tot("total_ordinary") + tot("total_declaration") == tot("district_total"))) uh_stop("UH7", district, ": ordinary + declaration != DISTRICT TOTAL")
    }
    # row-level: each group's total = atl + candidates; the grand columns follow from them
    for (r in which(use)) {
      v <- Vz[r, ]
      for (g in unique(grp[kinds %in% c("group_total")])) {
        inn <- grp == g & kinds %in% c("atl", "candidate"); tt <- grp == g & kinds == "group_total"
        if (sum(v[inn]) != v[tt]) uh_stop("UH7", district, " / ", labs[r], ": group ", g, " columns do not sum to its TOTAL (", sum(v[inn]), " vs ", v[tt], ")")
      }
      want <- function(k) v[kinds == k]
      if (length(want("total_atl")) && sum(v[kinds == "atl"]) != want("total_atl")) uh_stop("UH7", district, " / ", labs[r], ": ATL columns != Total ATL")
      if (length(want("total_btl")) && sum(v[kinds == "candidate"]) != want("total_btl")) uh_stop("UH7", district, " / ", labs[r], ": candidate columns != Total BTL")
      if (length(want("total_formal")) && want("total_atl") + want("total_btl") != want("total_formal")) uh_stop("UH7", district, " / ", labs[r], ": ATL + BTL != Total Formal")
      if (length(want("total_votes")) && want("total_formal") + want("total_informal") != want("total_votes")) uh_stop("UH7", district, " / ", labs[r], ": formal + informal != Total Votes")
    }
    idx <- which(use)
    for (r in idx) {
      out[[length(out) + 1L]] <- data.frame(year = year, region = region, district = district,
        voting_centre = labs[r], row_kind = rk[r],
        vote_type = if (rk[r] == "declaration") norm_type(labs[r]) else if (rk[r] == "voting_centre") "ordinary" else NA_character_,
        column_kind = kinds, group = grp,
        group_name = vapply(meta, function(x) x$group_name %||% NA_character_, ""),
        candidate = vapply(meta, function(x) x$candidate %||% NA_character_, ""),
        votes = V[r, ], source_file = basename(file), stringsAsFactors = FALSE)
    }
  }
  d <- do.call(rbind, out)
  # the REGION TOTAL row is the sum of the DISTRICT TOTAL rows, column by column
  ck <- paste(d$column_kind, d$group, d$candidate)
  dsum <- tapply(z(d$votes[d$row_kind == "district_total"]), ck[d$row_kind == "district_total"], sum)
  rsum <- setNames(z(d$votes[d$row_kind == "region_total"]), ck[d$row_kind == "region_total"])
  if (length(rsum) && (!setequal(names(dsum), names(rsum)) || any(dsum != rsum[names(dsum)])))
    uh_stop("UH7", "district totals do not sum to REGION TOTAL (first: ", names(dsum)[which(dsum != rsum[names(dsum)])[1]], ")")
  # fill each group's name onto its candidate and total columns (the header carries it only on ATL / candidate cells)
  nm <- unique(d[!is.na(d$group_name) & !is.na(d$group), c("group", "group_name")])
  nm <- nm[!duplicated(nm$group), ]
  d$group_name <- ifelse(is.na(d$group_name) & !is.na(d$group), nm$group_name[match(d$group, nm$group)], d$group_name)
  list(data = d, spacer_columns = spacers)
}

# ------------------------------------------------------- Distribution of Preferences
parse_dist <- function(sheets, year, region, file = NA_character_) {
  if (length(sheets) != 1L) uh_stop("UH8", "expected one sheet, found ", length(sheets))
  m <- sheets[[1]]
  check_header(m, year, region, "Distribution Report", c(3, 4))
  fnum <- function(i, pat) { x <- cell(m, i, 1); if (!isTRUE(grepl(pat, x))) uh_stop("UH8", "row ", i, " is '", x, "', expected ", pat); tonum(sub("^[^:]*:\\s*", "", x)) }
  seats <- as.integer(sub("^Election of ([0-9]+) Members.*$", "\\1", cell(m, 6, 1)))
  formal <- fnum(7, "^Formal Ballot Papers"); informal <- fnum(8, "^Informal Ballot Papers"); quota <- fnum(10, "^Quota")
  h <- which(grepl("^Count\\s*\n?\\s*No", m[, 1]))
  if (length(h) != 1L) uh_stop("UH8", "expected one count header row, found ", length(h))
  cj <- which(!is.na(m[h, ]) & seq_len(ncol(m)) >= 5L)
  if (any(!is.na(m[(h + 1L):nrow(m), setdiff(5:ncol(m), cj)]) & nzchar(trimws(m[(h + 1L):nrow(m), setdiff(5:ncol(m), cj)]))))
    uh_stop("UH8", "numbers under a blank column header")
  nj <- cj[grepl("^Candidates", m[h, cj])]            # trailing text column: who was elected at this count
  if (length(nj) > 1L) uh_stop("UH8", "more than one 'Candidates elected' column")
  cj <- setdiff(cj, nj)
  cand <- trimws(gsub("\n", " ", m[h, cj]))
  out <- list(); count <- NA_integer_; det <- NA_character_; tv <- NA_real_
  for (i in (h + 1L):nrow(m)) {
    c1 <- cell(m, i, 1); c4 <- cell(m, i, 4); v <- tonum(m[i, cj])
    note <- if (length(nj)) cell(m, i, nj) else NA_character_
    if (!is.na(c1) && grepl("^[0-9]+$", c1)) {
      count <- as.integer(c1); det <- cell(m, i, 2); tv <- tonum(cell(m, i, 3))
      rt <- if (is.na(c4) || !nzchar(c4)) "first_pref" else c4
    } else if (!is.na(c4) && c4 %in% c("Value", "PTotal")) { rt <- c4
    } else if ((is.na(c1) || !nzchar(c1)) && all(is.na(v))) next
    else uh_stop("UH8", "row ", i, ": unrecognised row '", c1, "' / '", c4, "'")
    if (!rt %in% c("first_pref", "BPs", "Value", "PTotal")) uh_stop("UH8", "row ", i, ": unknown row type '", rt, "'")
    out[[length(out) + 1L]] <- data.frame(year = year, region = region, count_no = count, count_details = det,
      transfer_value = tv, row_type = rt, candidate = cand, votes = v, quota = quota, seats = seats, elected_note = note,
      source_file = basename(file), stringsAsFactors = FALSE)
  }
  d <- do.call(rbind, out)
  fp <- d[d$count_no == 1L & d$row_type == "first_pref", ]
  fpc <- fp[fp$candidate != "TOTAL", ]
  if (sum(z(fpc$votes)) != formal) uh_stop("UH9", "count 1 sums to ", sum(z(fpc$votes)), " but the page says ", formal, " formal ballot papers")
  if (!identical(sum(z(fp$votes[fp$candidate == "TOTAL"])), formal)) uh_stop("UH9", "count 1 TOTAL column is not the formal ballot paper count")
  # running total: PTotal(k) = PTotal(k-1) + Value(k), per candidate column; count 1's first preferences are its
  # PTotal, so count 2 ties back to the first preferences
  pt <- d[d$row_type %in% c("PTotal", "first_pref"), ]; va <- d[d$row_type == "Value", ]
  pm <- tapply(z(pt$votes), list(pt$count_no, pt$candidate), sum)
  vm <- pm * 0; vv <- tapply(z(va$votes), list(va$count_no, va$candidate), sum); vm[rownames(vv), colnames(vv)] <- z(vv)
  if (nrow(pm) > 1L) {
    cur <- pm[-1, , drop = FALSE]; prev <- pm[-nrow(pm), , drop = FALSE] + vm[-1, , drop = FALSE]
    if (any(abs(cur - prev) > 1e-6)) {
      w <- which(abs(cur - prev) > 1e-6, arr.ind = TRUE)[1, ]
      uh_stop("UH9", "running total breaks at count ", rownames(cur)[w[1]], " for ", colnames(cur)[w[2]])
    }
  }
  list(data = d, formal = formal, informal = informal, quota = quota, seats = seats)
}

# ---------------------------------------------------------------- downloading
build_specs <- function(year) {
  yr <- as.character(year); rs <- REGIONS[[yr]]; sp <- list()
  for (r in rs) {
    if (yr == "2022") {
      base <- paste0(BLOB, "/State/Reports/")
      f <- c(rbvc = paste0(r, " Region-Results by Voting Centre.xls"), votes = paste0(r, " Region-Votes Received.xls"),
             dist = paste0(r, " Region-Distribution of Preferences.xls"),
             gvt = paste0("State Election 2022-", r, " Region-Group Voting Tickets.pdf"))
    } else {
      base <- paste0(BLOB, "/historical-results/state2018/files/")
      stem <- tolower(gsub(" ", "", r)); stem <- paste0(stem, "region")
      f <- c(rbvc = paste0(stem, "-consolidatedrecheckresults.xls"), votes = paste0(stem, "votesreceived.xls"),
             dist = paste0(stem, "distributions.xls"),
             gvt = paste0(gsub("[ -]", "", r), "RegionGroupVotingTickets2018.PDF"))
    }
    for (k in names(f)) sp[[length(sp) + 1L]] <- data.frame(year = yr, region = r, kind = k, file = f[[k]],
      url = paste0(base, utils::URLencode(f[[k]])), stringsAsFactors = FALSE)
  }
  do.call(rbind, sp)
}

# TRUE only when the file is the right thing: magic bytes, then (xls) the
# full parse and sum checks, or (pdf) a PDF header and end marker.
validate_file <- function(path, kind, year, region) {
  b <- readBin(path, "raw", min(file.size(path), 8L))
  if (kind == "gvt") {
    con <- file(path, "rb"); on.exit(close(con)); n <- file.size(path)
    seek(con, max(0, n - 2048)); tl <- readBin(con, "raw", 2048L)
    tl[tl == as.raw(0) | tl > as.raw(127)] <- as.raw(32); tail <- rawToChar(tl)
    return(identical(b[1:4], charToRaw("%PDF")) && grepl("%%EOF", tail, fixed = TRUE))
  }
  if (!identical(b[1:4], as.raw(c(0xD0, 0xCF, 0x11, 0xE0)))) return(FALSE)
  ok <- tryCatch({
    sh <- read_sheets(path)
    switch(kind, rbvc = parse_rbvc(sh, year, region, path), votes = parse_votes(sh, year, region, path),
           dist = parse_dist(sh, year, region, path))
    TRUE }, error = function(e) { message("  rejected ", basename(path), ": ", conditionMessage(e)); FALSE })
  ok
}

sha256 <- function(p) digest::digest(file = p, algo = "sha256")

fetch_year <- function(year) {
  dir <- file.path("external", "reference", "vec", year, "council"); dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  mf <- file.path(dir, "manifest.csv")
  old <- if (file.exists(mf)) utils::read.csv(mf, stringsAsFactors = FALSE) else NULL
  man <- list()
  for (r in seq_len(nrow(sp <- build_specs(year)))) {
    s <- sp[r, ]; dest <- file.path(dir, s$file)
    prev <- if (!is.null(old)) old[old$file == s$file & old$accepted, ] else NULL
    if (file.exists(dest) && !is.null(prev) && nrow(prev) == 1L && sha256(dest) == prev$sha256) {      # same bytes as the copy that passed validation
      man[[r]] <- prev; next
    }
    part <- paste0(dest, ".part")
    t0 <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    resp <- tryCatch(httr::GET(s$url, httr::write_disk(part, overwrite = TRUE), httr::user_agent("auspol-research"), httr::timeout(300)),
                     error = function(e) uh_stop("UH10", "request failed for ", s$url, ": ", conditionMessage(e)))
    status <- httr::status_code(resp); bytes <- file.size(part)
    cl <- suppressWarnings(as.numeric(httr::headers(resp)[["content-length"]]))
    ok <- status == 200L && bytes > 0 && (is.na(cl) || cl == bytes) && validate_file(part, s$kind, year, s$region)
    if (ok) file.rename(part, dest) else { file.rename(part, paste0(dest, ".rejected")); uh_stop("UH10", "not accepted: ", s$url, " (HTTP ", status, ", ", bytes, " bytes)") }
    man[[r]] <- data.frame(file = s$file, url = s$url, utc_time = t0, http_status = status, bytes = bytes,
                           sha256 = sha256(dest), accepted = TRUE, stringsAsFactors = FALSE)
    cat(sprintf("UH11 fetched %s %s %s (%d bytes)\n", year, s$region, s$kind, bytes)); Sys.sleep(0.5)
  }
  man <- do.call(rbind, man); utils::write.csv(man, mf, row.names = FALSE)
  cat(sprintf("UH11 %s: %d files accepted, manifest %s\n", year, nrow(man), mf))
  sp
}

# ---------------------------------------------------- the three extracts compared
# Votes Received and the Distribution of Preferences agree EXACTLY (region
# formal papers; every group's count-1 total; any difference stops the run).
# Results by Voting Centre is a different snapshot: it differs from both in
# every region (up to 252 votes per group; districts up to 1.1% of formal).
# So Votes Received / Distribution are authoritative for region and district
# totals, and Results by Voting Centre is kept as the voting-centre detail.
# Its region-wide formal total may differ from the authoritative figure by up
# to REGION_GAP_LIMIT (largest seen: 0.3%); beyond that the run stops. Every
# gap is returned for output/council-extract-gaps-<year>.csv.
REGION_GAP_LIMIT <- 0.005

extract_gaps <- function(a, b, cc, year, rg, limit = REGION_GAP_LIMIT) {
  bd <- b$data; ad <- a$data
  vdt <- bd[bd$row_kind == "district_total", ]
  isf <- vdt$column_kind == "total_formal"; isi <- vdt$column_kind == "total_informal"
  vf <- tapply(vdt$votes[isf], vdt$district[isf], sum); vi <- tapply(vdt$votes[isi], vdt$district[isi], sum)
  formal_vr <- sum(vf); informal_vr <- sum(vi)
  if (formal_vr != cc$formal) uh_stop("UH12", rg, ": Votes Received formal ", formal_vr, " vs Distribution file ", cc$formal, " (these two should agree exactly)")
  if (informal_vr != cc$informal) uh_stop("UH12", rg, ": Votes Received informal ", informal_vr, " vs Distribution file ", cc$informal)
  gd <- ad[ad$block_kind == "district_total" & ad$row_kind == "group", ]
  ga <- tapply(gd$total, gd$group, sum)
  vg <- vdt[vdt$column_kind == "group_total", ]; gb <- tapply(vg$votes, vg$group, sum)
  if (!setequal(names(ga), names(gb))) uh_stop("UH12", rg, ": group lists differ between Results by Voting Centre and Votes Received")
  gname <- tapply(gd$group_name, gd$group, function(x) x[1])
  fp <- cc$data[cc$data$count_no == 1L & cc$data$row_type == "first_pref" & cc$data$candidate != "TOTAL", ]
  gmap <- unique(bd[bd$column_kind == "candidate" & !is.na(bd$candidate), c("group", "candidate")])
  dcand <- trimws(fp$candidate)
  if (!all(gmap$candidate %in% dcand)) uh_stop("UH12", rg, ": candidates in Votes Received missing from the distribution: ", paste(utils::head(setdiff(gmap$candidate, dcand), 3), collapse = " ; "))
  inmap <- dcand %in% gmap$candidate
  dg <- tapply(z(fp$votes[inmap]), gmap$group[match(dcand[inmap], gmap$candidate)], sum)
  uc <- vdt[vdt$column_kind == "candidate" & vdt$group == "UNGROUPED", ]
  vu <- tapply(z(uc$votes), uc$candidate, sum)
  du <- tapply(z(fp$votes), dcand, sum)[names(vu)]
  gall <- setdiff(names(gb), "UNGROUPED")
  if (any(dg[gall] != gb[gall]) || any(z(vu) != z(du))) uh_stop("UH12", rg, ": Distribution count 1 differs from Votes Received (these two should agree exactly)")
  gap <- ga[gall] - gb[gall]
  formal_rbvc <- sum(a$stats$formal); informal_rbvc <- sum(a$stats$informal)
  rel <- (formal_rbvc - formal_vr) / formal_vr
  if (abs(rel) > limit) uh_stop("UH12", rg, ": Results by Voting Centre formal total ", formal_rbvc, " is ", round(100 * rel, 2), "% from the authoritative ", formal_vr, " (limit ", 100 * limit, "%)")
  row <- function(level, measure, group, group_name, rbvc, vr, dist) data.frame(year = year, region = rg, level = level,
    measure = measure, group = group, group_name = group_name, results_by_voting_centre = rbvc,
    votes_received = vr, distribution = dist, gap_rbvc_minus_vr = rbvc - vr, gap_pct_of_vr = 100 * (rbvc - vr) / vr, stringsAsFactors = FALSE)
  gaps <- rbind(
    row("region", "formal", NA_character_, NA_character_, formal_rbvc, formal_vr, cc$formal),
    row("region", "informal", NA_character_, NA_character_, informal_rbvc, informal_vr, cc$informal),
    row("group", "formal", names(gap), unname(gname[names(gap)]), unname(ga[names(gap)]), unname(gb[names(gap)]), unname(dg[names(gap)])))
  st <- a$stats
  dis <- data.frame(year = year, region = rg, district = st$district, enrolment = st$enrolment,
    rbvc_formal = st$formal, rbvc_informal = st$informal, rbvc_total_votes = st$total_votes,
    votes_received_formal = unname(vf[sub(" District$", "", st$district)]), votes_received_informal = unname(vi[sub(" District$", "", st$district)]),
    distribution_region_formal = cc$formal, distribution_region_informal = cc$informal, stringsAsFactors = FALSE)
  dis$formal_gap_pct <- 100 * (dis$rbvc_formal - dis$votes_received_formal) / dis$votes_received_formal
  list(gaps = gaps, district = dis, formal_vr = formal_vr, informal_vr = informal_vr, formal_rbvc = formal_rbvc,
       max_group_gap = max(abs(gap)))
}

# ------------------------------------------------------------- whole-year parse
parse_year <- function(year) {
  dir <- file.path("external", "reference", "vec", year, "council"); sp <- build_specs(year)
  A <- list(); B <- list(); C <- list(); sumry <- list(); GAPS <- list(); DST <- list()
  for (rg in unique(sp$region)) {
    f <- function(k) file.path(dir, sp$file[sp$region == rg & sp$kind == k])
    a <- parse_rbvc(read_sheets(f("rbvc")), year, rg, f("rbvc"))
    b <- parse_votes(read_sheets(f("votes")), year, rg, f("votes"))
    cc <- parse_dist(read_sheets(f("dist")), year, rg, f("dist"))
    g <- extract_gaps(a, b, cc, year, rg)
    GAPS[[rg]] <- g$gaps; DST[[rg]] <- g$district
    A[[rg]] <- a$data; B[[rg]] <- b$data; C[[rg]] <- cc$data
    sumry[[rg]] <- data.frame(year = year, region = rg, districts = nrow(a$stats),
      voting_centre_blocks = length(unique(paste(a$data$district, a$data$voting_centre)[a$data$block_kind == "voting_centre"])),
      groups = length(unique(a$data$group_name[a$data$row_kind == "group"])), formal = g$formal_vr, informal = g$informal_vr,
      rbvc_minus_vr_formal = g$formal_rbvc - g$formal_vr, rbvc_minus_vr_formal_pct = round(100 * (g$formal_rbvc - g$formal_vr) / g$formal_vr, 3),
      max_group_gap = g$max_group_gap, seats = cc$seats, spacer_columns = b$spacer_columns, stringsAsFactors = FALSE)
    cat(sprintf("UH13 %s %-28s districts %2d, voting-centre blocks %4d, groups %2d, formal %d: all sums agree\n", year, rg,
                sumry[[rg]]$districts, sumry[[rg]]$voting_centre_blocks, sumry[[rg]]$groups, sumry[[rg]]$formal))
  }
  A <- do.call(rbind, A); B <- do.call(rbind, B); C <- do.call(rbind, C)
  # coverage, not presence: the columns that must carry data
  for (cl in c("district", "voting_centre", "vc_name", "block_kind", "row_kind", "total"))
    if (all(is.na(A[[cl]]))) uh_stop("UH14", "council-fp column '", cl, "' is 100% empty")
  for (cl in c("district", "voting_centre", "column_kind", "votes")) if (all(is.na(B[[cl]]))) uh_stop("UH14", "council-fp-cand column '", cl, "' is 100% empty")
  for (cl in c("count_no", "candidate", "votes", "row_type")) if (all(is.na(C[[cl]]))) uh_stop("UH14", "council-dist column '", cl, "' is 100% empty")
  dir.create("output", showWarnings = FALSE)
  utils::write.csv(A, sprintf("output/council-fp-%s.csv", year), row.names = FALSE, na = "")
  utils::write.csv(B, sprintf("output/council-fp-cand-%s.csv", year), row.names = FALSE, na = "")
  utils::write.csv(C, sprintf("output/council-dist-%s.csv", year), row.names = FALSE, na = "")
  utils::write.csv(do.call(rbind, DST), sprintf("output/council-district-stats-%s.csv", year), row.names = FALSE, na = "")
  utils::write.csv(do.call(rbind, GAPS), sprintf("output/council-extract-gaps-%s.csv", year), row.names = FALSE, na = "")
  cat(sprintf("UH15 %s: wrote council-fp %d rows, council-fp-cand %d rows, council-dist %d rows\n", year, nrow(A), nrow(B), nrow(C)))
  do.call(rbind, sumry)
}

if (!nzchar(Sys.getenv("AUSPOL_COUNCIL_LIB_ONLY"))) {
  years <- strsplit(Sys.getenv("AUSPOL_COUNCIL_YEARS", "2022,2018"), ",")[[1]]
  for (y in years) { fetch_year(y); print(parse_year(y)) }
}
