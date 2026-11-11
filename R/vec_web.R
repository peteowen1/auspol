# VEC RESULTS WEBSITE -> the night model's booth table.
#
# The VEC refused the results feed (11 Nov 2026: "monitor the VEC website on election night"), so the night runner can
# read each district's two "results by voting centre" pages instead: first preferences and the two-candidate count.
# vec_web_parse() reads one page (the 2026 layout, and the 2022 one so the path can be checked against the 2022 feed);
# vec_web_booth_table() turns a set of parsed pages into exactly the list night_booth_table() makes from the feed.
# Check codes VWB1-VWB6.

.vw_cells <- function(r) {
  cc <- regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]]
  lapply(cc, function(x) {
    parts <- strsplit(gsub("(?s)<[^>]+>", "\u0001", x, perl = TRUE), "\u0001", fixed = TRUE)[[1]]
    parts <- trimws(gsub("\\s+", " ", gsub("&#39;|&rsquo;", "'", gsub("&amp;", "&", gsub("&nbsp;", " ", parts)))))
    parts[nzchar(parts)]
  })
}
.vw_num <- function(x) suppressWarnings(as.integer(gsub(",", "", x)))
.vw_decl <- c("absent votes" = "absent", "postal votes" = "postal", "provisional votes" = "provisional",
              "marked as voted votes" = "marked_as_voted", "early votes" = "early", "early votes total" = "early")

#' Parse one VEC "results by voting centre" page
#'
#' @param path Saved HTML of a district's first-preference or two-candidate "results by voting centre" page.
#' @param district District name (no " District").
#' @return `district, booth, booth_type, candidate, party, votes`: one row per candidate per voting centre
#'   (`booth_type` "ordinary"; "early" for an early voting centre row) and per declaration type (`booth` `NA`). A page
#'   with no rows yet and a total of nothing parses to zero rows. Stops (VWB1) on a truncated page or an unknown layout,
#'   and (VWB2) when the parsed rows do not sum to the page's own total.
#' @export
vec_web_parse <- function(path, district) {
  h <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!grepl("</html>", h, fixed = TRUE)) stop("VWB1! ", district, " ", basename(path), ": page truncated (no closing tag)", call. = FALSE)
  tbls <- regmatches(h, gregexpr("(?s)<table.*?</table>", h, perl = TRUE))[[1]]
  # 2022 layout: a cell that is exactly "Voting Centres" (2026 two-candidate pages carry "Early voting centres")
  vc22 <- tbls[grepl("(?i)>\\s*Voting Centres\\s*<", tbls, perl = TRUE)]
  layout <- if (length(vc22)) "2022" else if (length(tbls) == 1L) "2026" else "unknown"
  if (layout == "unknown") stop("VWB1! ", district, " ", basename(path), ": unknown page layout (", length(tbls), " tables)", call. = FALSE)
  tbl <- if (layout == "2022") vc22[1] else tbls
  cells <- lapply(regmatches(tbl, gregexpr("(?s)<tr.*?</tr>", tbl, perl = TRUE))[[1]], .vw_cells)
  first <- function(cl) if (length(cl) && length(cl[[1]])) cl[[1]][1] else ""
  if (layout == "2026") {
    hdr <- cells[[1]]
    cc <- which(vapply(hdr, function(p) length(p) >= 1 && grepl(",", p[1]), logical(1)))
    cands <- vapply(hdr[cc], function(p) p[1], ""); parties <- vapply(hdr[cc], function(p) if (length(p) >= 2) p[2] else "", "")
    body <- cells[-1]
    # the 2023 variant (Narracan supplementary) puts the parties in a second header row with an empty first cell
    r2 <- cells[[2]]
    if (!any(nzchar(parties)) && length(r2) >= max(cc) && !length(r2[[1]])) {
      parties <- vapply(r2[cc], function(p) if (length(p)) p[1] else "", ""); body <- cells[-(1:2)]
    }
  } else {
    nm <- vapply(cells[[1]], function(p) if (length(p)) p[1] else "", ""); pt <- vapply(cells[[2]], function(p) if (length(p)) p[1] else "", "")
    cc <- which(nzchar(nm)); cc <- cc[cc > 1]; cands <- nm[cc]; parties <- pt[cc]
    body <- cells[-(1:2)]
  }
  if (!length(cc)) stop("VWB1! ", district, " ", basename(path), ": no candidate columns", call. = FALSE)
  val <- function(cl) vapply(cc, function(j) if (j <= length(cl) && length(cl[[j]])) .vw_num(cl[[j]][1]) else NA_integer_, 1L)
  rec <- function(cl, booth, type) data.table::data.table(booth = booth, booth_type = type, candidate = cands, party = parties, votes = val(cl))
  section <- if (layout == "2022") "ordinary" else NA_character_; out <- list(); tot <- NULL; have_early <- FALSE; have_decl <- FALSE
  for (cl in body) {
    l <- tolower(first(cl))
    if (!nzchar(l) || grepl("^percentage|^all votes", l)) next
    if (grepl("^total first preference|^total two|^total 2cp|^total$", l)) { tot <- val(cl); next }
    # a section heading carries no numbers ("Early votes" is a heading on 2026 pages but a data row on 2022 ones)
    if (grepl("^(ordinary votes|early votes|early voting centres|declaration votes)$", l) && all(is.na(val(cl)))) { section <- sub(" .*$", "", l); next }
    if (l == "ordinary votes total") next
    if (l == "declaration votes total") {
      if (!have_decl) {   # no breakdown by type on the page (2023 variant): one unit, counted as postal (the night base type)
        message("VWB3  ", district, " ", basename(path), ": declaration votes given only as a total; counted as one postal unit")
        out[[length(out) + 1]] <- rec(cl, NA_character_, "postal")
      }
      next
    }
    if (l == "early votes total") { if (!have_early) out[[length(out) + 1]] <- rec(cl, NA_character_, "early"); next }
    if (l %in% names(.vw_decl)) { out[[length(out) + 1]] <- rec(cl, NA_character_, .vw_decl[[l]]); if (.vw_decl[[l]] != "early") have_decl <- TRUE; next }
    if (identical(section, "ordinary")) out[[length(out) + 1]] <- rec(cl, first(cl), "ordinary")
    else if (identical(section, "early")) { out[[length(out) + 1]] <- rec(cl, first(cl), "early"); have_early <- TRUE }
    else message("VWB3  ", district, " ", basename(path), ": row '", first(cl), "' outside a known section, skipped")
  }
  empty <- data.table::data.table(district = character(), booth = character(), booth_type = character(), candidate = character(),
                                  party = character(), votes = integer())
  if (is.null(tot)) stop("VWB2! ", district, " ", basename(path), ": no total row", call. = FALSE)
  if (!length(out)) {
    if (any(tot > 0, na.rm = TRUE)) stop("VWB2! ", district, " ", basename(path), ": no rows but the page total is ", paste(tot, collapse = ","), call. = FALSE)
    return(empty)
  }
  d <- data.table::rbindlist(out); d[, district := district]
  sums <- vapply(cands, function(c0) sum(d$votes[d$candidate == c0], na.rm = TRUE), numeric(1))
  if (!isTRUE(all(sums == tot, na.rm = TRUE)) || (anyNA(tot) && any(sums > 0)))
    stop("VWB2! ", district, " ", basename(path), ": parsed totals ", paste(sums, collapse = ","), " vs page ", paste(tot, collapse = ","), call. = FALSE)
  d[, list(district, booth, booth_type, candidate, party, votes)]
}

#' Night booth table from parsed VEC website pages
#'
#' The website counterpart of [night_booth_table()]: same return value, from [vec_web_parse()] output instead of the feed.
#' @param fp,tcp First-preference and two-candidate rows from [vec_web_parse()] for every district (rbind of pages).
#' @param places Optional `district, booth`: every ordinary voting centre of each district. A centre missing from `fp`
#'   gets a zero-vote placeholder (an unreported unit, so it is projected). `NULL` adds none.
#' @param include_late As in [night_booth_table()]: `FALSE` drops absent, provisional and marked-as-voted rows.
#' @return List: `live` (`district, booth, booth_type, candidate, party, votes`), `counted` (`district, unit`), `tcp`
#'   (`district, booth, vote_type, candidate, party_raw, votes`; parties from the first-preference page, VWB4),
#'   `unmapped` (always empty), `n_placeholder_booths`, `n_unlisted_booths`.
#' @export
vec_web_booth_table <- function(fp, tcp = NULL, places = NULL, include_late = FALSE) {
  fp <- data.table::as.data.table(fp)
  if (!nrow(fp)) stop("VWB5! no first-preference rows", call. = FALSE)
  live <- data.table::copy(fp)
  live[is.na(booth), booth := paste0("(district ", booth_type, ")")]
  live[is.na(votes), votes := 0L]
  n_placeholder <- 0L; n_unlisted <- 0L
  first_c <- live[!duplicated(live$district), list(district, candidate, party)]
  if (!is.null(places) && nrow(places)) {
    pl <- unique(data.table::as.data.table(places)[, list(district, booth)])
    ob <- unique(live[live$booth_type == "ordinary", list(district, booth)])
    nb <- function(x) .norm_booth(x)
    n_unlisted <- sum(!paste(ob$district, nb(ob$booth)) %in% paste(pl$district, nb(pl$booth)))
    if (n_unlisted) message("VWB5  ", n_unlisted, " website booth(s) not in the voting-centre list (no placeholder made for them)")
    pl <- pl[!paste(pl$district, nb(pl$booth)) %in% paste(live$district, nb(live$booth))]
    pl <- merge(pl, first_c, by = "district")
    if (nrow(pl)) { n_placeholder <- nrow(pl); live <- rbind(live, pl[, list(district, booth, booth_type = "ordinary", candidate, party, votes = 0L)]) }
  }
  if (!include_late) live <- live[!live$booth_type %in% .night_late_types]
  ph <- data.table::rbindlist(lapply(if (include_late) .night_unit_types else setdiff(.night_unit_types, .night_late_types), function(ty) {
    x <- first_c[!first_c$district %in% live$district[live$booth_type == ty]]
    if (!nrow(x)) NULL else x[, list(district, booth = paste0("(district ", ty, ")"), booth_type = ty, candidate, party, votes = 0L)]
  }))
  if (!is.null(ph) && nrow(ph)) live <- rbind(live, ph)
  live[, unit := data.table::fifelse(booth_type == "ordinary", booth, booth_type)]
  tot <- live[, list(tv = sum(votes)), by = c("district", "unit")]
  counted <- tot[tot$tv > 0, c("district", "unit")]
  live[, unit := NULL]
  tc <- data.table::data.table(district = character(), booth = character(), vote_type = character(), candidate = character(),
                               party_raw = character(), votes = numeric())
  if (!is.null(tcp) && nrow(tcp)) {
    t2 <- data.table::as.data.table(tcp)
    fpp <- unique(fp[, list(district, candidate, party_fp = party)])
    if (anyDuplicated(fpp[, list(district, candidate)])) stop("VWB4! a candidate name appears twice in one district's first preferences", call. = FALSE)
    t2 <- merge(t2, fpp, by = c("district", "candidate"), all.x = TRUE, sort = FALSE)
    if (anyNA(t2$party_fp)) stop("VWB4! two-candidate rows for a candidate not in that district's first preferences: ",
                                 paste(unique(paste(t2$district, t2$candidate)[is.na(t2$party_fp)]), collapse = "; "), call. = FALSE)
    bad <- unique(t2[t2$party != t2$party_fp, list(district, candidate, party, party_fp)])
    if (nrow(bad)) message("VWB4  two-candidate page party differs from the first-preference page (first-preference used): ",
                           paste(sprintf("%s %s ('%s' -> '%s')", bad$district, bad$candidate, bad$party, bad$party_fp), collapse = "; "))
    t2[is.na(booth), booth := paste0("(district ", booth_type, ")")]
    tc <- t2[, list(district, booth, vote_type = booth_type, candidate, party_raw = party_fp, votes)]
  }
  list(live = live[], counted = counted[], tcp = tc[], unmapped = character(), n_placeholder_booths = n_placeholder, n_unlisted_booths = n_unlisted)
}
