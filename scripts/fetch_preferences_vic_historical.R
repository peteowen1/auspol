# Victorian state elections 2014 and 2018: first preferences, preference
# distributions and declared winners.
#
# WHY THIS WAS "UNAVAILABLE" AND IS NOT. docs/plans/preference-data-acquisition.md
# records Victoria 2018 as blocked after every URL variant 404'd, and the main
# VEC site is JavaScript-driven so the results never appear in its HTML. They are
# not on the main site at all: they live in an Azure blob archive linked from one
# line of the 2018 page's markup --
#
#   itsitecoreblobvecprd01.blob.core.windows.net/public-files/historical-results/state2018/
#
# and state2014 is in the same archive. state2010, state2006 and state2022 are
# not (checked). So Victoria is now testable across 2014 -> 2018 -> 2022, in the
# state the live forecast is actually for.
#
# Each district has two pages: the district page carries candidates, parties,
# first preferences and the elected member; the distribution page carries the
# exclusion sequence. Parties live only on the first, so the two are joined on
# candidate name.
#
# Emits VH* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
BASE <- "https://itsitecoreblobvecprd01.blob.core.windows.net/public-files/historical-results"
RAW <- file.path("external", "reference", "vec")
OUT <- election_data_path()
YEARS <- c(2014, 2018)

strip_tags <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", "", x)))
tables_of <- function(html) regmatches(html, gregexpr("(?s)<table.*?</table>", html, perl = TRUE))[[1]]
rows_of <- function(tb) regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]]
cells_of <- function(tr) strip_tags(regmatches(tr, gregexpr("(?s)<t[hd].*?</t[hd]>", tr, perl = TRUE))[[1]])

grab <- function(url, dest) {
  if (!file.exists(dest) || file.info(dest)$size < 500) {
    try(utils::download.file(url, dest, quiet = TRUE, headers = c("User-Agent" = UA)),
        silent = TRUE)
    Sys.sleep(0.1)
  }
  if (!file.exists(dest)) return(NULL)
  paste(readLines(dest, warn = FALSE), collapse = "\n")
}

num <- function(x) suppressWarnings(as.numeric(gsub("[^0-9]", "", x)))

for (YR in YEARS) {
  dir.create(file.path(RAW, YR), showWarnings = FALSE, recursive = TRUE)
  B <- sprintf("%s/state%d", BASE, YR)
  sm <- grab(sprintf("%s/summary.html", B), file.path(RAW, YR, "summary.html"))
  if (is.null(sm)) stop("Could not fetch the ", YR, " summary page.")
  # District NAMES come from the summary page, which links each slug with its
  # proper name ("albertparkdistrict.html" -> "Albert Park District"). The
  # district pages themselves have no heading element to read it from, and
  # un-slugging cannot recover the spacing in a multi-word name.
  # Slugs and names are pulled with regmatches rather than sub() with a
  # backreference: a "\1" replacement is fragile to write correctly here and a
  # mis-escaped one silently substitutes a control character instead of the
  # captured group, which collapses every slug to the same value.
  anchors <- regmatches(sm, gregexpr(
    "<a[^>]+href=.[a-z0-9-]+district[.]html.[^>]*>.*?</a>", sm, perl = TRUE))[[1]]
  slug_of <- function(a) {
    m <- regmatches(a, regexpr("[a-z0-9-]+district[.]html", a))
    if (!length(m)) return(NA_character_)
    sub("[.]html$", "", m)
  }
  label_of <- function(a) {
    lbl <- trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", "", a)))
    trimws(sub("District$", "", lbl))
  }
  sl <- vapply(anchors, slug_of, character(1), USE.NAMES = FALSE)
  lb <- vapply(anchors, label_of, character(1), USE.NAMES = FALSE)
  keep <- !is.na(sl) & nzchar(lb)
  d <- unique(data.table(slug = sl[keep], name = lb[keep]))
  slugs <- d$slug
  names(slugs) <- d$name
  cat(sprintf("\nVH1  %d: %d district pages listed\n", YR, length(slugs)))
  if (length(slugs) != 88L) {
    stop(YR, ": expected 88 districts, the summary lists ", length(slugs))
  }

  fp_all <- list(); tx_all <- list(); win_all <- list()
  for (sg in unname(slugs)) {
    h <- grab(sprintf("%s/%s.html", B, sg), file.path(RAW, YR, paste0(sg, ".html")))
    if (is.null(h)) next
    tb <- tables_of(h)
    # The district name and elected member sit in the page's own text; the
    # candidate table is the one whose header names a first-preference column.
    dname <- names(slugs)[match(sg, slugs)]
    if (is.na(dname) || !nzchar(dname)) {
      stop("No district name for slug ", sg, "; the summary page's link text ",
           "did not parse, and un-slugging cannot recover a multi-word name.")
    }

    cand <- NULL
    for (x in tb) {
      rr <- rows_of(x); if (!length(rr)) next
      hdr <- cells_of(rr[1])
      if (any(grepl("1st pref votes", hdr, ignore.case = TRUE))) {
        rws <- lapply(rr[-1], cells_of)
        rws <- rws[vapply(rws, function(z) length(z) >= 4, TRUE)]
        cand <- rbindlist(lapply(rws, function(z)
          data.table(candidate = z[1], party_raw = z[2], votes = num(z[3]))))
        break
      }
    }
    if (is.null(cand) || !nrow(cand)) next
    cand <- cand[is.finite(votes) & votes > 0]
    # Classified outside the brackets; an empty party name is an independent,
    # which is what the VEC prints for one.
    cand[, party := classify_party(party_raw, NULL)]
    fp_all[[length(fp_all) + 1L]] <- cand[, .(seat = dname, party, votes)]

    # The DECLARED winner, from the table the VEC titles "Elected member".
    # Not the first-preference leader: in Prahran 2018 the Greens won from
    # third on primaries, so taking the leader would record the wrong party
    # in exactly the seats a backtest most needs to get right.
    em <- regmatches(h, regexpr(
      '(?s)<table title="Elected member".*?</table>', h, perl = TRUE))
    wparty <- NA_character_
    if (length(em)) {
      sp <- regmatches(em, gregexpr("(?s)<span[^>]*>.*?</span>", em, perl = TRUE))[[1]]
      sp <- strip_tags(sp)
      if (length(sp) >= 2L) wparty <- classify_party(sp[2], NULL)
    }
    if (is.na(wparty)) {
      stop(dname, " ", YR, ": no \"Elected member\" table could be parsed. ",
           "Falling back to the first-preference leader would be wrong in every ",
           "seat won from behind, which is the interesting kind.")
    }
    win_all[[length(win_all) + 1L]] <- data.table(seat = dname, winner = wparty)

    # ---- distribution of preferences ----
    dh <- grab(sprintf("%s/distribution%s.html", B, sg),
               file.path(RAW, YR, paste0("dist-", sg, ".html")))
    if (is.null(dh)) next
    dt_tab <- NULL
    for (x in tables_of(dh)) {
      rr <- rows_of(x)
      if (length(rr) > 3 && any(grepl("first preference votes", cells_of(rr[2]),
                                      ignore.case = TRUE))) { dt_tab <- rr; break }
    }
    if (is.null(dt_tab)) next
    names_row <- cells_of(dt_tab[1])[-1]
    lut <- setNames(cand$party, cand$candidate)
    rnd <- 0L
    for (r in dt_tab[-1]) {
      cs <- cells_of(r)
      if (!length(cs) || !grepl("^Transfer of", cs[1])) next
      who <- trimws(sub(".*ballot papers of ", "", sub(" [(].*$", "", cs[1])))
      from <- unname(lut[who])
      if (is.na(from)) next
      rnd <- rnd + 1L
      vals <- num(cs[-1])
      for (k in seq_along(names_row)) {
        if (k > length(vals) || !is.finite(vals[k]) || vals[k] <= 0) next
        to <- unname(lut[names_row[k]])
        if (is.na(to) || identical(to, from)) next
        tx_all[[length(tx_all) + 1L]] <- data.table(
          election = sprintf("vic%d", YR), seat = dname, round = rnd,
          from = from, to = to, votes = vals[k])
      }
    }
  }

  fp <- rbindlist(fp_all)[, .(votes = sum(votes)), by = .(seat, party)]
  tx <- rbindlist(tx_all)[, .(votes = sum(votes)), by = .(election, seat, round, from, to)]
  cat(sprintf("VH2  %d: %d districts, %d seat-party rows, %s formal votes\n",
              YR, uniqueN(fp$seat), nrow(fp), format(sum(fp$votes), big.mark = ",")))
  sh <- fp[, .(v = sum(votes)), by = party][, .(party, pct = round(100 * v / sum(v), 2))]
  print(sh[order(-pct)])
  if (uniqueN(fp$seat) != 88L) {
    stop(YR, ": parsed ", uniqueN(fp$seat), " districts, expected 88")
  }
  a <- sh[party == "ALP", pct]
  if (!length(a) || a < 25 || a > 50) {
    stop(YR, ": ALP first preference of ", if (length(a)) round(a, 1) else "NA",
         "% is outside any plausible range; the parse or the classifier is wrong.")
  }
  cat(sprintf("VH3  %d: %d transfer rows across %d districts, %s votes moved\n",
              YR, nrow(tx), uniqueN(tx$seat), format(sum(tx$votes), big.mark = ",")))
  g <- tx[from == "GRN" & to %in% c("ALP", "LNP"), .(v = sum(votes)), by = to]
  if (nrow(g) == 2L) {
    pg <- 100 * g[to == "ALP", v] / sum(g$v)
    cat(sprintf("VH3  %d: Greens preferences to Labor %.1f%% (anchor: 70-92%%)\n", YR, pg))
    if (pg < 70 || pg > 92) stop(YR, ": Greens flow of ", round(pg, 1), "% is implausible.")
  }
  win <- rbindlist(win_all)
  stopifnot(nrow(win) == 88L, uniqueN(win$seat) == 88L)
  cat(sprintf("VH3b %d declared winners: %s
", YR,
              paste(sprintf("%s %d", names(table(win$winner)),
                            as.integer(table(win$winner))), collapse = ", ")))
  fwrite(win, file.path(OUT, sprintf("vec-%d-vic-winners.csv", YR)))
  fwrite(fp, file.path(OUT, sprintf("vec-%d-vic-firstprefs.csv", YR)))
  fwrite(tx, file.path(OUT, sprintf("vec-%d-vic-transfers.csv", YR)))
  cat(sprintf("VH4  wrote vec-%d-vic-firstprefs.csv and -transfers.csv\n", YR))
}
