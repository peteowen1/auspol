#!/usr/bin/env Rscript
# Poll Bludger posts -> poll rows, scored against AE (the answer key, used one last time before AE is dropped).
#
# Reads only the raw day pages scripts/fetch_pollbludger.R saved, so a rule change here needs no refetch.
#
# STAGE 1, posts (lossless): every <article> on every day page becomes one row of posts.csv: post id, url,
# title, timestamp, WordPress categories, and the full body text. Nothing is summarised.
#
# STAGE 2, polls (rules, version 1): each paragraph of a post is a candidate. A candidate needs a pollster
# name (from the paragraph, else the post title) and primary votes for both Labor and the Coalition, read from
# Bowe's usual phrasings:
#   "primary votes of 40 per cent for Labor, 41 per cent for the Coalition and 12 per cent for the Greens"
#   "Labor on 39%, the Coalition on 36%, the Greens on 10.4%"     "Labor 39%, Coalition 36%"
# A paragraph about seat or marginal polling ("seat", "marginal", "electorate", "in the seats of") is typed
# scope = "seat" and kept out of the statewide set; one naming a state inside a federal post is "state".
# Sample: "sample of 1,239" / "1239 respondents". Date: the post's date (the poll ended a day or several
# before it), so matching allows a wider window than poll_layer's 4 days.
#
# Output: external/reference/polls/pollbludger/posts.csv, pollbludger_polls.csv,
#         output/pollbludger-vs-layered.csv. Check codes: PE1 posts, PE2 polls, PE3 answer-key score.

suppressPackageStartupMessages({ library(rvest); library(xml2); library(data.table) })
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))

base <- "external/reference/polls/pollbludger"
day_files <- list.files(file.path(base, "raw", "days"), pattern = "\\.html$", full.names = TRUE)

## Stage 1: posts
posts <- rbindlist(lapply(day_files, function(f) {
  h <- read_html(f); arts <- html_elements(h, "article")
  if (!length(arts)) return(NULL)
  rbindlist(lapply(arts, function(a) {
    cls <- html_attr(a, "class")
    data.table(post_id = sub("^post-", "", html_attr(a, "id")),
               url = html_attr(html_element(a, ".entry-title a"), "href"),
               title = html_text2(html_element(a, ".entry-title")),
               posted = html_attr(html_element(a, "time.entry-date"), "datetime"),
               categories = paste(sub("^category-", "", regmatches(cls, gregexpr("category-[a-z0-9-]+", cls))[[1]]), collapse = " "),
               text = html_text2(html_element(a, ".entry-content")), day_file = basename(f))
  }))
}), fill = TRUE)
posts <- unique(posts, by = "post_id")
posts[, date := as.Date(substr(posted, 1, 10), format = "%Y-%m-%d")]
cat(sprintf("PE1 posts: %d from %d day pages, %s to %s; empty text %d\n", nrow(posts), length(day_files),
            min(posts$date, na.rm = TRUE), max(posts$date, na.rm = TRUE), sum(!nzchar(posts$text) | is.na(posts$text))))
fwrite(posts, file.path(base, "posts.csv"))

## Stage 2 (rules, version 2): polls from SENTENCES. Version 1 read whole paragraphs and on the 2004-2017 pages
## matched 119 polls with 15 off by more than 2 points: paragraphs carry two polls (a Galaxy and a Patterson seat
## poll), subgroup figures (age brackets, swinging voters, "how they voted in 2010"), and state polls inside
## federal posts. Version 2 takes one sentence at a time, carries the last pollster named earlier in the paragraph
## (else the title's), sets the region from the post's categories (a sentence naming "state voting intention"
## and a state overrides it), and skips sentences about subgroups, seats, exit polls and upper houses.
## Tuned on the pages dated up to 2017-03-05 (the first half fetched); the later pages are the held-out check.
firms <- c("Newspoll", "Nielsen", "Galaxy", "YouGov", "Morgan", "Essential", "ReachTEL", "Ipsos", "Resolve",
           "RedBridge", "Redbridge", "Freshwater", "uComms", "Lonergan", "JWS", "DemosAU", "Westpoll", "Patterson",
           "Utting", "Painted Dog", "Advertiser", "Taverner", "Spectre", "Wolf", "Fox & Hedgehog", "Sweeney", "AMR",
           "Auspoll", "Crosby Textor", "Pyxis", "MediaReach", "EMRS", "Mark Textor")
firm_rx <- paste0("(", paste(firms, collapse = "|"), ")")
num <- "([0-9]{1,2}(?:\\.[0-9])?)"
pc  <- "(?:\\s?per\\s?cent|\\s?%)"
party_rx <- list(
  ALP = "Labor|the ALP|ALP",
  COA = "the Coalition|Coalition",
  QLNP = "the Liberal National Party|the LNP|LNP",
  LIB = "the Liberals|Liberals|the Liberal Party|Liberal(?! National)",
  NAT = "the Nationals|Nationals|the National Party",
  GRN = "the Greens|Greens",
  ONP = "One Nation",
  UAP = "United Australia Party|the UAP|UAP|Palmer United|the Palmer United Party",
  NXT = "Nick Xenophon Team|the Nick Xenophon Team|NXT|SA-Best|SA Best")
any_party <- "Labor|ALP|Coalition|LNP|Liberal|National|Greens|One Nation|Palmer|UAP|Xenophon|NXT|SA-Best|others|independents"
# up to 45 characters between a party and its number, with no digit and no other party name in between
gap <- paste0("(?:(?!", any_party, ")[^0-9;:])", "{0,45}?")
grab <- function(p, rx) {
  pats <- c(paste0(num, pc, "\\s(?:(?:for|to)\\s)?(?:the\\s)?(?:", rx, ")\\b"),                     # 40 per cent (for) Labor
            paste0("\\b(?:", rx, ")\\b", gap, "(?:up |down )?from [0-9.]+(?:", pc, ")? to ", num, pc),  # Labor up from 40 to 42 per cent
            paste0("\\b(?:", rx, ")\\b", gap, "(?:up|down) [0-9.]+(?: points?|", pc, ")? to ", num, pc),  # Labor up 1.5% to 34%
            paste0("\\b(?:", rx, ")\\b", gap, num, pc))                                            # Labor steady on 38%, Labor 39%
  for (pt in pats) {
    a <- regmatches(p, regexec(pt, p, perl = TRUE))[[1]]
    if (length(a)) return(as.numeric(a[2]))
  }
  NA_real_
}
skip_rx <- paste0("year-olds|aged |\\bage (?:group|bracket)|swinging|exit poll|voted (?:for|in) |remember|upper house|",
                  "Legislative Council|Senate|\\bseats?\\b|marginal|electorate|by-election|outside (?:the )?cities|",
                  "in (?:western |south-western |regional |outer |inner |rural )?(?:Sydney|Melbourne|Brisbane|Perth|Adelaide|Hobart)|",
                  "regional|metropolitan|among |men |women |respondents who|those who|not yet voted|rolling average|aggregate|BludgerTrack|",
                  "election results? of|at the (?:last|previous|[0-9]{4}) election|last election|the [0-9]{4} election|",
                  # issue and leader questions, not voting intention
                  "better to handle|best party|expect|favoured by|preferred (?:Labor |Liberal )?leader|better campaign|approv|support(?:ed)? by|",
                  "more likely|less likely|policy|",
                  # an earlier poll quoted for comparison
                  "the last [A-Za-z]* ?poll|previous [A-Za-z]* ?(?:poll|survey)|which had (?:Labor|the Coalition)")
# A paragraph that is about seats taints every sentence in it ("In Braddon the figures are ..."), as does a
# seat-margin tag such as "Wentworth (NSW, Liberal 7.9%)".
para_skip_rx <- "\\bseats?\\b|marginal|electorate|by-election|\\((?:[A-Z]{2,3}, )?(?:Labor|Liberal|National|LNP|Greens) [0-9.]+%\\)"
region_of_cats <- function(cats) {
  r <- c(fed = "federal", nsw = "new-south-wales", vic = "victorian", qld = "queensland", sa = "^sa-|south-australian",
         wa = "^wa-|western-australian", tas = "tasmanian", nt = "northern-territory", act = "capital-territory")
  hit <- names(r)[vapply(r, function(rx) any(grepl(rx, strsplit(cats, " ")[[1]])), TRUE)]
  if (length(hit) == 1L) hit else if (!length(hit)) NA_character_ else paste(hit, collapse = "+")
}
state_names <- c(nsw = "New South Wales", vic = "Victoria", qld = "Queensland", wa = "Western Australia", sa = "South Australia", tas = "Tasmania")
rows <- list()
for (i in seq_len(nrow(posts))) {
  tx <- posts$text[i]; if (is.na(tx) || !nzchar(tx)) next
  cats <- posts$categories[i]
  if (grepl("by-elections", cats) && !grepl("politics|election-[0-9]", cats)) next
  post_region <- region_of_cats(cats)
  title_firm <- regmatches(posts$title[i], regexpr(firm_rx, posts$title[i], perl = TRUE))
  paras <- unlist(strsplit(tx, "\n+"))
  for (j in seq_along(paras)) {
    if (grepl(para_skip_rx, paras[j], ignore.case = TRUE, perl = TRUE)) next
    sents <- unlist(strsplit(paras[j], "(?<=[.!?])\\s+(?=[A-Z\"“])", perl = TRUE))
    firm_now <- if (length(title_firm)) title_firm else NA_character_
    for (k in seq_along(sents)) {
      s <- sents[k]
      fm <- regmatches(s, regexpr(firm_rx, s, perl = TRUE)); if (length(fm)) firm_now <- fm
      if (!grepl("primary|per cent|%", s)) next
      if (grepl(skip_rx, s, ignore.case = TRUE, perl = TRUE)) next
      v <- vapply(party_rx, function(rx) grab(s, rx), 0)
      # Coalition: its own figure, else Queensland's LNP, else Liberal plus Nationals (WA keeps them apart, as
      # load_polls() does).
      lnp <- if (is.finite(v["COA"])) v["COA"] else if (is.finite(v["QLNP"])) v["QLNP"] else
             if (is.finite(v["LIB"]) && is.finite(v["NAT"]) && !identical(post_region, "wa")) v["LIB"] + v["NAT"] else v["LIB"]
      if (!is.finite(v["ALP"]) || !is.finite(lnp)) next
      # Region: the post's categories; a sentence about a state's own voting intention moves it to that state.
      st <- names(state_names)[vapply(state_names, function(n) grepl(n, s, fixed = TRUE), TRUE)]
      reg <- post_region; scope <- "statewide"
      if (length(st) == 1L && grepl("state voting intention|state poll|state-level|premier", s, ignore.case = TRUE)) reg <- st
      else if (length(st) && identical(post_region, "fed")) scope <- "state_breakdown"
      smp <- regmatches(paras[j], regexec("(?:sample (?:size )?of (?:about |around |nearly |over )?|from )([0-9]{1,2},?[0-9]{3})(?: respondents)?", paras[j], perl = TRUE))[[1]]
      tpp <- regmatches(s, regexec("([0-9]{2}(?:\\.[0-9])?)-([0-9]{2}(?:\\.[0-9])?)", s, perl = TRUE))[[1]]
      rows[[length(rows) + 1L]] <- data.table(post_id = posts$post_id[i], date = posts$date[i], title = posts$title[i],
        categories = cats, region_cat = reg, para = j, sent = k, firm_raw = firm_now, scope = scope,
        ALP = unname(v["ALP"]), LNP = unname(lnp), COA = unname(v["COA"]), QLNP = unname(v["QLNP"]), LIB = unname(v["LIB"]),
        NAT = unname(v["NAT"]), GRN = unname(v["GRN"]), ONP = unname(v["ONP"]), UAP = unname(v["UAP"]), NXT = unname(v["NXT"]),
        sample_n = if (length(smp)) as.numeric(gsub(",", "", smp[2])) else NA_real_,
        tpp_text = if (length(tpp)) tpp[1] else NA_character_, sentence = s)
    }
  }
}
pb <- rbindlist(rows)
# A primary pair that sums past 100 is not one poll's Labor and Coalition figures.
pb <- pb[ALP + LNP < 95 & ALP > 5 & LNP > 5]
cat(sprintf("PE2 poll sentences: %d (statewide %d, state breakdown %d); with a pollster %d; with Greens %d; with sample %d; region unknown %d\n",
            nrow(pb), sum(pb$scope == "statewide"), sum(pb$scope == "state_breakdown"),
            sum(!is.na(pb$firm_raw)), sum(is.finite(pb$GRN)), sum(is.finite(pb$sample_n)), sum(is.na(pb$region_cat))))
fwrite(pb, file.path(base, "pollbludger_polls.csv"))

## Stage 3: answer key. Match statewide rows to the layered set (firm, post date 1 day before to 10 days after the
## poll midpoint, closest numbers first). The cut-off between tuning and held-out pages is printed per row.
alias <- fread("external/reference/polls/statewide-samples/firm_alias.csv", showProgress = FALSE)
eds <- election_dates()
# Polling days election_dates() does not carry yet (coverage program 2026-10-13; from memory, to be checked against
# the commissions by track A and then moved into R/election_dates.R, the one source of truth).
extra_eds <- c(fed2001 = "2001-11-10",
  nsw2003 = "2003-03-22", nsw2007 = "2007-03-24", nsw2011 = "2011-03-26",
  vic2002 = "2002-11-30", vic2006 = "2006-11-25",
  qld2001 = "2001-02-17", qld2004 = "2004-02-07", qld2006 = "2006-09-09", qld2009 = "2009-03-21", qld2012 = "2012-03-24", qld2015 = "2015-01-31",
  sa2002 = "2002-02-09", sa2006 = "2006-03-18", sa2010 = "2010-03-20", sa2014 = "2014-03-15",
  tas2002 = "2002-07-20", tas2006 = "2006-03-18", tas2010 = "2010-03-20", tas2014 = "2014-03-15", tas2018 = "2018-03-03",
  tas2021 = "2021-05-01", tas2024 = "2024-03-23", tas2025 = "2025-07-19",
  nt2001 = "2001-08-18", nt2005 = "2005-06-18", nt2008 = "2008-08-09", nt2012 = "2012-08-25", nt2016 = "2016-08-27",
  nt2020 = "2020-08-22", nt2024 = "2024-08-24",
  act2001 = "2001-10-20", act2004 = "2004-10-16", act2008 = "2008-10-18", act2012 = "2012-10-20", act2016 = "2016-10-15",
  act2020 = "2020-10-17", act2024 = "2024-10-19")
extra_eds <- extra_eds[!names(extra_eds) %in% names(eds)]
eds <- c(eds, stats::setNames(as.Date(extra_eds), names(extra_eds)))
eds <- eds[eds >= as.Date("2004-07-01")]
# Each post belongs to the NEXT election in its region (whole cycles, since --all fetches every post; the
# coverage table below still reports each election's final 30 days).
pb[, election := NA_character_]
for (r in unique(na.omit(pb$region_cat))) {
  er <- sort(eds[sub("[0-9]+$", "", names(eds)) == r])
  if (!length(er)) next
  m <- which(pb$region_cat == r)
  k <- findInterval(as.integer(pb$date[m]), as.integer(er), left.open = TRUE) + 1L   # first polling day on or after the post
  ok <- k <= length(er)
  pb$election[m[ok]] <- names(er)[k[ok]]
}
pb[, region := sub("[0-9]+$", "", election)]
pb[, half := fifelse(date <= as.Date("2017-03-05"), "tuning", "held_out")]
S <- pb[scope == "statewide" & !is.na(firm_raw) & !is.na(region)]
S[, canon := .ps_canon(firm_raw, alias)]; S[, si := .I]
out <- list()
for (rg in intersect(c("fed", "nsw", "qld", "sa", "vic", "wa"), unique(S$region))) {
  L <- suppressMessages(load_polls(rg)); P <- attr(L, "provenance")
  L <- data.table(li = seq_len(nrow(L)), d_l = L$date, firm = L$firm, ALP_l = L$ALP, LNP_l = L$LNP, GRN_l = L$GRN, source = P$source)
  L[, canon := .ps_canon(firm, alias)]
  L <- L[is.finite(ALP_l) & is.finite(LNP_l)]; L[, li := .I]   # two-party-only rows carry no primaries to find
  B <- S[region == rg]
  cand <- B[, .(si, canon, d_p = date)][L[, .(li, canon, d_l)], on = "canon", allow.cartesian = TRUE, nomatch = NULL]
  cand <- cand[as.integer(d_p - d_l) >= -1L & as.integer(d_p - d_l) <= 10L]
  nd <- abs(S$ALP[cand$si] - L$ALP_l[cand$li]) + abs(S$LNP[cand$si] - L$LNP_l[cand$li])
  cand[, score := nd + abs(as.integer(d_p - d_l)) / 4]
  setorder(cand, score)
  us <- logical(nrow(S)); ul <- logical(nrow(L)); keep <- logical(nrow(cand))
  for (k in seq_len(nrow(cand))) { s <- cand$si[k]; l <- cand$li[k]; if (us[s] || ul[l]) next; us[s] <- ul[l] <- keep[k] <- TRUE }
  m <- cand[keep]
  out[[rg]] <- data.table(region = rg, election = S$election[m$si], post_date = S$date[m$si], poll_date = L$d_l[m$li],
                          firm = L$firm[m$li], source = L$source[m$li], ALP_pb = S$ALP[m$si], ALP_l = L$ALP_l[m$li],
                          LNP_pb = S$LNP[m$si], LNP_l = L$LNP_l[m$li], GRN_pb = S$GRN[m$si], GRN_l = L$GRN_l[m$li],
                          post_id = S$post_id[m$si], half = S$half[m$si], sentence = S$sentence[m$si])
  # Coverage: the statewide polls in each election's final 30 days, and how many the extractor found.
  for (e in unique(B$election)) {
    ed <- eds[[e]]; w30 <- L[d_l >= ed - 30 & d_l < ed]
    out[[paste0(e, "_cov")]] <- data.table(region = rg, election = e, cov = TRUE, half = if (ed <= as.Date("2017-03-05")) "tuning" else "held_out",
                                           final30 = nrow(w30), found = sum(ul[w30$li]),
                                           ae_final30 = sum(w30$source %in% c("ae_only", "ae_dispute", "ae_suspect")),
                                           ae_found = sum(ul[w30$li] & w30$source %in% c("ae_only", "ae_dispute", "ae_suspect")))
  }
}
A <- rbindlist(out, fill = TRUE)
M <- A[is.na(cov)]; C <- A[cov == TRUE]
fwrite(M, "output/pollbludger-vs-layered.csv")
M[, maxd := pmax(abs(ALP_pb - ALP_l), abs(LNP_pb - LNP_l), abs(GRN_pb - GRN_l), na.rm = TRUE)]
for (h in c("tuning", "held_out")) {
  Mh <- M[half == h]; Sh <- S[half == h]
  cat(sprintf("PE3 [%s] matched %d of %d statewide sentences with a pollster. Every party within 0.5 point: %d; within 1: %d; off by > 2: %d\n",
              h, nrow(Mh), nrow(Sh), sum(Mh$maxd <= 0.5), sum(Mh$maxd <= 1), sum(Mh$maxd > 2)))
}
cat("Agreement by half and by whose numbers the layered row carries (points; lower is closer):\n")
print(M[, .(polls = .N, ALP_mean_abs = round(mean(abs(ALP_pb - ALP_l)), 2), LNP_mean_abs = round(mean(abs(LNP_pb - LNP_l)), 2),
            GRN_mean_abs = round(mean(abs(GRN_pb - GRN_l), na.rm = TRUE), 2), off_gt2 = sum(maxd > 2)), by = .(half, source)][order(half, -polls)])
cat("\nFinal-30-day coverage: layered polls with primaries, how many the extractor found; and of those carrying AE's numbers, how many it found.\n")
print(C[order(half, region, election), .(half, election, final30, found, ae_final30, ae_found)])
print(C[, .(found = sum(found), final30 = sum(final30), ae_found = sum(ae_found), ae_final30 = sum(ae_final30)), by = half])
