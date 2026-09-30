# Party leaders and their seats at each election, from the Wikipedia election
# article's infobox (leaderN, partyN, leaders_seatN).
#
# Why: nsw2023's worst Labor miss was Kogarah (21 points), Chris Minns's own
# seat. A "party leader's own seat" effect is knowable before any election.
# docs/plans/prereg-leader-seat-2026-09-29.md.
#
# Raw wikitext is stored under external/reference/wikipedia/leaders/ and never
# re-fetched once on disk (CLAUDE.md: store the raw response). Output:
# external/reference/leaders/leaders.csv, one row per (election, infobox slot),
# with every infobox field kept, parsed or not.
suppressMessages(library(data.table))

ELECTIONS <- c(
  fed2007 = "2007 Australian federal election", fed2010 = "2010 Australian federal election",
  fed2013 = "2013 Australian federal election", fed2016 = "2016 Australian federal election",
  fed2019 = "2019 Australian federal election", fed2022 = "2022 Australian federal election",
  fed2025 = "2025 Australian federal election",
  nsw2019 = "2019 New South Wales state election", nsw2023 = "2023 New South Wales state election",
  qld2020 = "2020 Queensland state election", qld2024 = "2024 Queensland state election",
  sa2022 = "2022 South Australian state election", sa2026 = "2026 South Australian state election",
  vic2014 = "2014 Victorian state election", vic2018 = "2018 Victorian state election",
  vic2022 = "2022 Victorian state election", vic2026 = "2026 Victorian state election",
  wa2001 = "2001 Western Australian state election", wa2005 = "2005 Western Australian state election",
  wa2008 = "2008 Western Australian state election", wa2013 = "2013 Western Australian state election",
  wa2017 = "2017 Western Australian state election", wa2021 = "2021 Western Australian state election",
  wa2025 = "2025 Western Australian state election")

raw_dir <- "external/reference/wikipedia/leaders"
out_dir <- "external/reference/leaders"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
ua <- "auspol-research/0.1 (https://github.com/peteowen1/auspol)"

failed <- character(0)
for (key in names(ELECTIONS)) {
  f <- file.path(raw_dir, paste0(key, ".wikitext"))
  if (file.exists(f) && file.size(f) > 0) next
  url <- paste0("https://en.wikipedia.org/w/index.php?action=raw&title=",
                utils::URLencode(gsub(" ", "_", ELECTIONS[[key]]), reserved = TRUE))
  ok <- tryCatch({
    download.file(url, f, method = "libcurl", headers = c(`User-Agent` = ua), quiet = TRUE); TRUE
  }, error = function(e) { message("LD0! fetch failed ", key, ": ", conditionMessage(e)); FALSE })
  if (!ok) failed <- c(failed, key)
  Sys.sleep(1)
}

strip_link <- function(x) {
  x <- gsub("<ref[^>]*/>|<ref[^>]*>.*?</ref>", "", x, perl = TRUE)
  x <- gsub("\\[\\[([^]|]*\\|)?([^]]*)\\]\\]", "\\2", x)
  # {{nowrap|[[Samantha Ratnam]]}} wraps a name: unwrap it before dropping
  # other templates. Bold ('''Colin Barnett''') marks the winner.
  x <- gsub("\\{\\{nowrap\\|(.*?)\\}\\}", "\\1", x, perl = TRUE)
  x <- gsub("\\{\\{[^}]*\\}\\}", "", x)
  x <- gsub("'{2,}", "", x)
  x <- gsub("<[^>]+>", " ", x)
  trimws(gsub("\\s+", " ", x))
}

rows <- list()
for (key in names(ELECTIONS)) {
  f <- file.path(raw_dir, paste0(key, ".wikitext"))
  if (!file.exists(f) || file.size(f) == 0) { failed <- union(failed, key); next }
  txt <- readLines(f, warn = FALSE, encoding = "UTF-8")
  # vic2018 opens a field line with a comment: "<!-- Coalition -->| leader2 = ..."
  txt <- gsub("<!--.*?-->", "", txt, perl = TRUE)
  # Infobox fields: "| name = value" lines. Keep every numbered field.
  fl <- regmatches(txt, regexec("^\\s*\\|\\s*([A-Za-z_]+?)([0-9]+)\\s*=\\s*(.*)$", txt))
  fl <- fl[lengths(fl) == 4]
  if (!length(fl)) { message("LD1! no numbered infobox fields for ", key); failed <- union(failed, key); next }
  d <- rbindlist(lapply(fl, function(m) data.table(field = m[2], slot = as.integer(m[3]), raw = m[4])))
  d <- d[!duplicated(d[, .(field, slot)])]
  w <- dcast(d, slot ~ field, value.var = "raw")
  w[, election := key]
  # Head of government going in (unnumbered): marks each leader as the sitting
  # premier / prime minister or a challenger.
  bf <- grep("^\\s*\\|\\s*before_election\\s*=", txt, value = TRUE)[1]
  w[, head_of_govt := if (is.na(bf)) NA_character_ else strip_link(sub("^[^=]*=", "", bf))]
  rows[[key]] <- w
}
L <- rbindlist(rows, fill = TRUE)
for (cn in intersect(c("leader", "party", "leaders_seat", "leader_since"), names(L)))
  set(L, j = paste0(cn, "_clean"), value = strip_link(L[[cn]]))
setcolorder(L, c("election", "slot", intersect(c("leader_clean", "party_clean", "leaders_seat_clean"), names(L))))
fwrite(L, file.path(out_dir, "leaders.csv"))
message(sprintf("LD2 wrote %d leader slots for %d elections to %s", nrow(L[!is.na(leader_clean)]),
                uniqueN(L$election), file.path(out_dir, "leaders.csv")))
if (length(failed)) message("LD0!! NOT FETCHED OR NOT PARSED: ", paste(failed, collapse = ", "))
print(L[!is.na(leader_clean) & nzchar(leader_clean), .(election, slot, leader = leader_clean,
                                                      party = party_clean, seat = leaders_seat_clean)], nrows = 200)
