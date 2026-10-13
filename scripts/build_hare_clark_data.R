# build_hare_clark_data.R -- party first preferences, seats won and (ACT) ballot-level party flows for
# the Hare-Clark elections: Tasmania 2002-2025 and the ACT 2008-2024.
#
# Run from the repo root (arrow is not used, so Git Bash Rscript is fine):
#   Rscript scripts/build_hare_clark_data.R
#
# INPUTS (raw, never edited; all under external/reference/):
#   tas/raw/wikipedia/results-YYYY.wikitext  "Results of the YYYY Tasmanian state election", action=raw,
#                                             fetched 2026-10-13. Candidate first preferences per division,
#                                             with "(elected N)" markers. Cross-checked against the TEC's own
#                                             2018 first-preference workbooks (tas/raw/tec/2018/, check HCD3).
#   act/raw/YYYY/                             Elections ACT ballot-paper preference files (every formal
#                                             ballot), 2008/2012/2016 via the Wayback Machine, 2024 live.
#   elections-act/raw/2020/                   the same for 2020 (fetched for the count prototype).
#
# OUTPUTS (output/, gitignored):
#   hare-clark-units.csv        one row per (region, year, electorate, unit): a unit is a party ticket, a
#                               named group, or one ungrouped / independent candidate. votes = first
#                               preferences, ncand = candidates on the ticket, seats_won = members elected.
#   hare-clark-candidates.csv   candidate-level rows behind it (kept: within-party work will want them).
#   hare-clark-act-flows.csv    ACT, per (year, electorate, first-preference unit, first DIFFERENT unit or
#                               EXH): ballot counts. The party-level transfer rates are derived from this.
#   hare-clark-act-booths.csv   ACT 2012 and 2016 first preferences by polling place and unit (booth votes
#                               only), for the 2016 notional (the 2016 redistribution created 5 electorates
#                               from 3, so 2012 has no electorate-level result to swing from).
#
# ACT SEATS WON come from running the validated count engine (scripts/hare_clark_count.R, which reproduced
# the official 2020 count exactly) on each year's ballots, then checked against the territory totals (HCD5).
#
# CHECK CODES: HCD1 Tas parse (formal = sum of candidates), HCD2 seats per division, HCD3 Tas vs TEC 2018,
#   HCD4 ACT ballots = sum of unit first prefs, HCD5 ACT seats vs known totals, HCD6 classes assigned.

suppressPackageStartupMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/hare_clark_count.R")   # guarded by sys.nframe(); defines hc_read_act_ballots(), hc_count()

ref <- file.path("external", "reference")
dir.create("output", showWarnings = FALSE)
fails <- 0L
chk <- function(code, ok, msg) {
  cat(sprintf("%s %s  %s\n", code, if (isTRUE(ok)) "PASS" else "FAIL", msg))
  if (!isTRUE(ok)) fails <<- fails + 1L
  invisible(isTRUE(ok))
}

# ------------------------------------------------------------------ Tasmania
num <- function(x) as.numeric(gsub("[^0-9.]", "", x))
field <- function(block, name) {
  m <- regmatches(block, regexpr(sprintf("\\|\\s*%s\\s*=[^\n]*", name), block))
  if (!length(m)) return(NA_character_)
  trimws(sub(sprintf("^\\|\\s*%s\\s*=", name), "", m))
}
clean_name <- function(s) {
  s <- gsub("\\{\\{nowrap\\|", "", s)
  s <- gsub("'''?\\(elected[^)]*\\)'''?", "", s)
  s <- gsub("\\[\\[[^]|]*\\|([^]]*)\\]\\]", "\\1", s)
  s <- gsub("\\[\\[|\\]\\]|\\}\\}|'''", "", s)
  trimws(gsub("<ref.*$", "", s))
}
parse_tas_year <- function(path, year) {
  txt <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  begins <- gregexpr("\\{\\{Election box begin", txt)[[1]]
  out <- list(); formal <- list()
  for (b in begins) {
    rest <- substr(txt, b, nchar(txt))
    stop_at <- regexpr("\\{\\{Election box (party total votes|end)", rest)
    blk <- substr(rest, 1, stop_at - 1)
    div <- regmatches(blk, regexpr("Division of [A-Za-z]+", blk))
    if (!length(div)) next
    div <- sub("Division of ", "", div)
    cands <- strsplit(blk, "\\{\\{Election box candidate")[[1]][-1]
    rows <- lapply(cands, function(cb) {
      cb <- sub("\\}\\}\\s*$", "", sub("\\{\\{Election box (formal|informal|turnout|quota).*$", "", cb))
      raw_c <- field(cb, "candidate")
      data.table(party_raw = clean_name(field(cb, "party")), candidate = clean_name(raw_c),
                 votes = num(field(cb, "votes")),
                 elected = grepl("elected", raw_c))
    })
    d <- rbindlist(rows)
    fv <- regmatches(blk, regexpr("Election box formal[^}]*", blk))
    formal[[div]] <- if (length(fv)) num(field(fv, "votes")) else NA_real_
    out[[div]] <- d[, electorate := div]
  }
  d <- rbindlist(out)
  d[, `:=`(region = "tas", year = as.integer(year))]
  list(cands = d, formal = formal)
}
tas_label <- function(p) {
  p <- trimws(sub(" TAS$", "", p))
  p[p %in% c("Lambie", "JLN")] <- "Jacqui Lambie Network"
  p[p == "T4T"] <- "Tasmanians 4 Tasmania"
  p[grepl("Tasmanian Greens", p)] <- "Greens"
  p
}
tas_years <- c(2002L, 2006L, 2010L, 2014L, 2018L, 2021L, 2024L, 2025L)
wiki <- lapply(tas_years, function(y) {
  r <- parse_tas_year(file.path(ref, "tas", "raw", "wikipedia", sprintf("results-%d.wikitext", y)), y)
  d <- r$cands
  for (e in unique(d$electorate)) {
    sv <- sum(d$votes[d$electorate == e]); fv <- r$formal[[e]]
    # Tolerance 0.1% of formal: the 2002 Denison box is 20 votes short of its own formal line (a
    # transcription slip on the page). The 2025 boxes are off by up to 1,578 (2%) and are NOT used for
    # votes: 2018-2025 votes come from the TEC's workbooks below, so this check is reported for them only.
    official <- y >= 2018L
    ok <- is.finite(fv) && abs(sv - fv) <= 0.001 * fv
    msg <- sprintf("tas%d %-8s wiki candidates sum %s vs wiki formal %s (%d candidates)%s", y, e,
                   format(sv, big.mark = ","), format(fv, big.mark = ","), sum(d$electorate == e),
                   if (official) " [votes taken from TEC, not this]" else "")
    if (official) cat(sprintf("HCD1 %s  %s\n", if (ok) "PASS" else "INFO", msg)) else chk("HCD1", ok, msg)
  }
  d
})
names(wiki) <- tas_years
norm_nm <- function(s) toupper(gsub("[^A-Za-z]", "", s))

# TEC first-preference workbooks: rows are candidates ("SURNAME, First") followed by their ticket's total
# row; "ungrouped" closes the list; then "Total Formal ...". The last column is the division total.
read_tec_division <- function(path, sheet = 1) {
  x <- suppressMessages(readxl::read_excel(path, sheet = sheet, col_names = FALSE, .name_repair = "minimal"))
  lab <- trimws(as.character(x[[1]])); tot <- suppressWarnings(as.numeric(x[[ncol(x)]]))
  i_formal <- grep("^Total Formal", lab)
  stopifnot(length(i_formal) == 1L)
  rows <- list(); pend <- integer(0)
  for (i in seq_len(i_formal - 1L)) {
    if (is.na(lab[i]) || !is.finite(tot[i])) next
    # A ticket-total row is the one whose total equals the sum of the candidate rows above it. Matching the
    # name shape instead ("SURNAME, First") missed "McKIM, Nick"-style surnames and dropped 1,400 votes.
    if (!length(pend) || abs(tot[i] - sum(tot[pend])) >= 0.5) { pend <- c(pend, i); next }
    rows[[length(rows) + 1L]] <- data.table(tec_name = lab[pend], votes = tot[pend], ticket = lab[i],
                                            ticket_total = tot[i])
    pend <- integer(0)
  }
  d <- rbindlist(rows)
  d[, candidate := paste(sub("^[^,]*, ", "", tec_name), tools::toTitleCase(tolower(sub(",.*$", "", tec_name))))]
  list(d = d, formal = tot[i_formal])
}
tec_elected <- function(path) {   # 2024/2025 count export: the "Elected (Election order)" column
  x <- suppressMessages(readxl::read_excel(path, sheet = "ElectionResultScreen", col_names = FALSE,
                                           .name_repair = "minimal"))
  v <- trimws(as.character(x[[1]]))
  i0 <- which(v == "(Election order)")
  stopifnot(length(i0) == 1L)
  v <- v[(i0 + 1L):length(v)]
  v[!is.na(v) & grepl(", ", v)]
}
tec_files <- function(y, div) {
  base <- file.path(ref, "tas", "raw", "tec", y)
  if (y == 2018L) return(list(path = file.path(base, sprintf("2018-%s-first-prefs-by-polling-places.xlsx",
                                                             if (div == "Clark") "Denison" else div)), sheet = 1))
  list(path = list.files(base, pattern = "first-preferences-by-polling-places\\.xlsx$", full.names = TRUE),
       sheet = div)
}
tas_c <- rbindlist(lapply(tas_years, function(y) {
  w <- copy(wiki[[as.character(y)]])
  w[, party := tas_label(party_raw)]
  w[electorate == "Denison", electorate := "Clark"]          # renamed 2018; same division
  if (y < 2018L) return(w[, .(region, year, electorate, party_raw, party, candidate, votes, elected, source = "wikipedia")])
  rbindlist(lapply(unique(w$electorate), function(e) {
    f <- tec_files(y, e)
    t <- read_tec_division(f$path, f$sheet)
    d <- t$d
    chk("HCD3", abs(sum(d$votes) - t$formal) < 0.5,
        sprintf("tas%d %-8s TEC candidates sum %s = TEC formal %s (%d candidates; wiki formal differs by %+d)",
                y, e, format(sum(d$votes), big.mark = ","), format(t$formal, big.mark = ","), nrow(d),
                as.integer(t$formal - sum(w$votes[w$electorate == e]))))
    if (y >= 2024L) {
      ex <- list.files(file.path(ref, "tas", "raw", "tec", y), pattern = sprintf("Division of %s - Export", e),
                       full.names = TRUE)
      el <- tec_elected(ex)
      d[, elected := tec_name %in% el]
      chk("HCD3", sum(d$elected) == length(el) && length(el) == 7L,
          sprintf("tas%d %-8s %d elected per the TEC count export, all matched", y, e, sum(d$elected)))
    } else {
      key_w <- norm_nm(w$candidate[w$electorate == e & w$elected])
      d[, elected := norm_nm(candidate) %in% key_w]
      # surname fallback for names Wikipedia spells differently (nicknames, middle names)
      miss <- setdiff(key_w, norm_nm(d$candidate))
      if (length(miss)) {
        wn <- w$candidate[w$electorate == e & w$elected][key_w %in% miss]
        for (nm in wn) {
          sn <- norm_nm(sub("^.* ", "", nm))
          j <- which(norm_nm(sub(",.*$", "", d$tec_name)) == sn & !d$elected)
          if (length(j) == 1L) d$elected[j] <- TRUE
        }
      }
      chk("HCD3", sum(d$elected) == 5L, sprintf("tas%d %-8s %d of 5 Wikipedia winners matched to TEC rows",
                                                y, e, sum(d$elected)))
    }
    d[, .(region = "tas", year = y, electorate = e, party_raw = ticket,
          party = ifelse(tolower(ticket) == "ungrouped", "Independent", ticket), candidate, votes, elected,
          source = "TEC")]
  }))
}), fill = TRUE)
# A unit is the party ticket; an ungrouped candidate stands alone.
tas_c[, unit := ifelse(party == "Independent", paste0("IND: ", candidate), party)]
# "Group C" is a ballot column letter, not an identity: key it on its first candidate so a different
# group under the same letter next time is not matched to it.
tas_c[grepl("^Group", party), unit := paste0("GRP: ", candidate[1]), by = .(year, electorate, party)]
tas_c[, class := classify_party(ifelse(party == "Independent" | grepl("^Group", party), "", party))]

# ------------------------------------------------------------------ ACT
act_dirs <- c(`2008` = file.path(ref, "act", "raw", "2008"), `2012` = file.path(ref, "act", "raw", "2012"),
              `2016` = file.path(ref, "act", "raw", "2016"), `2020` = file.path(ref, "elections-act", "raw", "2020"),
              `2024` = file.path(ref, "act", "raw", "2024"))
known_act <- list(   # territory-wide seats won (2024 verified in the scoping doc; others recalled, checked here)
  `2008` = c(ALP = 7, LNP = 6, GRN = 4), `2012` = c(ALP = 8, LNP = 8, GRN = 1),
  `2016` = c(ALP = 12, LNP = 11, GRN = 2), `2020` = c(ALP = 10, LNP = 9, GRN = 6),
  `2024` = c(ALP = 10, LNP = 9, GRN = 4))
act_c <- list(); act_fl <- list(); act_bo <- list(); act_lk <- list()
for (yy in names(act_dirs)) {
  dir <- act_dirs[[yy]]; y <- as.integer(yy)
  el <- fread(file.path(dir, "Electorates.txt"))
  grp <- fread(file.path(dir, "Groups.txt"))
  cf <- list.files(dir, pattern = "^[Cc]andidates\\.txt$", full.names = TRUE)
  cand <- fread(cf)
  ppb <- if (file.exists(file.path(dir, "PollingPlaceBatchNumbers.txt")))
    fread(file.path(dir, "PollingPlaceBatchNumbers.txt")) else NULL
  for (i in seq_len(nrow(el))) {
    ec <- el$ecode[i]; en <- el$electorate[i]
    seats <- if (y < 2016 && en == "Molonglo") 7L else 5L
    cc <- cand[cand$ecode == ec, ]
    gg <- grp[grp$ecode == ec, ]
    cc <- merge(cc, gg[, .(pcode, pname, pabbrev)], by = "pcode", all.x = TRUE)
    cc[, name := sub("^(.*?), (.*)$", "\\2 \\1", cname, perl = TRUE)]
    cc[, unit := ifelse(pabbrev == "UNG" | is.na(pabbrev), paste0("UNG: ", name), pname)]
    cc[, cid := pcode * 1000L + ccode]
    d <- fread(file.path(dir, paste0(en, "Total.txt")), select = c("batch", "pindex", "pref", "pcode", "ccode"))
    d[, cid := pcode * 1000L + ccode]
    d[, unit := cc$unit[match(cid, cc$cid)]]
    stopifnot(!anyNA(d$unit))
    setorder(d, batch, pindex, pref)
    d[, bid := rleid(batch, pindex)]
    f1 <- d[pref == 1L, .(bid, batch, u1 = unit)]
    # first preference for a unit other than the first-preference unit: what leaves the ticket when it is out
    d[f1, u1 := i.u1, on = "bid"]
    nx <- d[unit != u1, .SD[1L], by = bid, .SDcols = "unit"]
    f1[nx, u2 := i.unit, on = "bid"]
    f1[is.na(u2), u2 := "EXH"]
    act_fl[[paste(yy, en)]] <- f1[, .N, by = .(u1, u2)][, `:=`(year = y, electorate = en)]
    # leakage out of the ticket at its first transfer: second preference for another unit, or none
    p2 <- d[pref == 2L, .(bid, p2 = unit)]
    f1[p2, p2 := i.p2, on = "bid"]
    act_lk[[paste(yy, en)]] <- f1[, .(n = .N, n_leave2 = sum(is.na(p2) | p2 != u1), n_exh2 = sum(is.na(p2))),
                                  by = u1][, `:=`(year = y, electorate = en)]
    if (!is.null(ppb) && y %in% c(2012L, 2016L)) {
      f1[ppb, pp := i.pollingplace, on = "batch"]
      act_bo[[paste(yy, en)]] <- f1[!is.na(pp), .N, by = .(pp, u1)][, `:=`(year = y, electorate = en)]
    }
    fp <- f1[, .(votes = .N), by = .(unit = u1)]
    # actual winners: the validated count engine on the same ballots
    bal <- hc_read_act_ballots(dir, ec, verbose = FALSE)
    res <- hc_count(bal, seats = seats)
    win <- bal$cands$name[match(res$elected$name, bal$cands$name)]
    cc[, elected := name %in% win]
    cc[, cvotes := as.numeric(d[pref == 1L, .N, by = cid]$N[match(cid, d[pref == 1L, .N, by = cid]$cid)])]
    cc[is.na(cvotes), cvotes := 0]
    chk("HCD4", sum(fp$votes) == bal$n_ballots && sum(cc$cvotes) == bal$n_ballots,
        sprintf("act%d %-12s %s ballots; %d units; %d elected of %d seats", y, en,
                format(bal$n_ballots, big.mark = ","), nrow(fp), length(win), seats))
    act_c[[paste(yy, en)]] <- cc[, .(region = "act", year = y, electorate = en, party_raw = pname,
                                     party = ifelse(is.na(pabbrev) | pabbrev == "UNG", "Independent", pname),
                                     candidate = name, votes = cvotes, elected, unit)]
    rm(d, f1, nx, bal, res); invisible(gc(verbose = FALSE))
  }
}
act_c <- rbindlist(act_c)
act_c[, class := classify_party(ifelse(party == "Independent", "", party))]

# ------------------------------------------------------------------ units
cands <- rbind(tas_c[, .(region, year, electorate, party_raw, party, candidate, votes, elected, unit, class)],
               act_c[, .(region, year, electorate, party_raw, party, candidate, votes, elected, unit, class)])
cls_tab <- unique(cands[, .(party, class)])
setorder(cls_tab, class, party)
cat("\nParty label -> class (classify_party()):\n"); print(cls_tab, nrows = 200)
chk("HCD6", !anyNA(cands$class), "every candidate has a class")
# Unit identity across elections: the three major tickets by class (TEC says "Liberal Party", Wikipedia
# "Liberal", Elections ACT "CANBERRA LIBERALS"); minor parties by a normalised name, so "Shooters, Fishers
# and Farmers" (Wikipedia) and "Shooters, Fishers, Farmers TAS" (TEC) are one party.
canon <- function(p) {
  s <- tolower(p); s <- gsub("\\b(tas|act|the|party|and|of)\\b", " ", s); s <- gsub("[^a-z]", "", s)
  s[s == "jln"] <- "jacquilambienetwork"
  s
}
# The Tasmanian Nationals (2014, 2025) ran their own ticket AGAINST the Liberals. classify_party() files them
# with the Coalition (right for the federal path), which here merged them into the Liberal ticket -- one
# bloc with the Liberals' and the Nationals' candidates. They are a separate minor-right ticket.
cands[region == "tas" & class == "LNP" & grepl("national", tolower(party)), class := "OTH_RIGHT"]
cands[, unit_raw := unit]
cands[, unit := ifelse(class %in% c("ALP", "LNP", "GRN"), class,
                       ifelse(grepl("^(IND|UNG|GRP): ", unit), unit, canon(party)))]
units <- cands[, .(votes = sum(votes), ncand = .N, seats_won = sum(elected), class = class[1]),
               by = .(region, year, electorate, unit)]
seats_e <- units[, .(seats = sum(seats_won)), by = .(region, year, electorate)]
units[seats_e, seats := i.seats, on = c("region", "year", "electorate")]
for (k in seq_len(nrow(seats_e))) {
  s <- seats_e$seats[k]; want <- if (seats_e$region[k] == "tas") (if (seats_e$year[k] >= 2024) 7L else 5L)
                                 else if (seats_e$year[k] < 2016 && seats_e$electorate[k] == "Molonglo") 7L else 5L
  chk("HCD2", s == want, sprintf("%s%d %-12s %d seats elected (expected %d)", seats_e$region[k], seats_e$year[k],
                                 seats_e$electorate[k], s, want))
}


# HCD5: ACT seats by class vs the territory totals
for (yy in names(known_act)) {
  got <- units[region == "act" & year == as.integer(yy), .(s = sum(seats_won)), by = class]
  kn <- known_act[[yy]]
  ok <- all(vapply(names(kn), function(k) isTRUE(got$s[got$class == k] == kn[[k]]), logical(1)))
  chk("HCD5", ok, sprintf("act%s seats %s (known ALP/LNP/GRN %s)", yy,
                          paste(sprintf("%s %d", got$class, got$s), collapse = ", "), paste(kn, collapse = "/")))
}

fwrite(units, "output/hare-clark-units.csv")
fwrite(cands, "output/hare-clark-candidates.csv")
umap <- unique(cands[region == "act", .(k = paste(year, electorate, unit_raw), unit, class)])
stopifnot(!anyDuplicated(umap$k))
fl <- rbindlist(act_fl)
fl[, `:=`(c1 = umap$class[match(paste(year, electorate, u1), umap$k)],
          c2 = ifelse(u2 == "EXH", "EXH", umap$class[match(paste(year, electorate, u2), umap$k)]),
          u1 = umap$unit[match(paste(year, electorate, u1), umap$k)],
          u2 = ifelse(u2 == "EXH", "EXH", umap$unit[match(paste(year, electorate, u2), umap$k)]))]
chk("HCD4", !anyNA(fl$c1) && !anyNA(fl$c2) && !anyNA(fl$u2), "every ACT flow row maps to a unit and class")
fwrite(fl[, .(year, electorate, u1, c1, u2, c2, n = N)], "output/hare-clark-act-flows.csv")
bo <- rbindlist(act_bo)
bo[, unit := umap$unit[match(paste(year, electorate, u1), umap$k)]]
fwrite(bo[, .(year, electorate, pollingplace = pp, unit, votes = N)], "output/hare-clark-act-booths.csv")
lk <- rbindlist(act_lk)
lk[, `:=`(c1 = umap$class[match(paste(year, electorate, u1), umap$k)], u1 = umap$unit[match(paste(year, electorate, u1), umap$k)])]
chk("HCD4", !anyNA(lk$c1), "every ACT leakage row maps to a unit")
fwrite(lk[, .(year, electorate, u1, c1, n, n_leave2, n_exh2)], "output/hare-clark-act-leak.csv")
cat(sprintf("\nunits %d rows (%d tas, %d act); candidates %d; flows %d; FAILS %d\n", nrow(units),
            sum(units$region == "tas"), sum(units$region == "act"), nrow(cands), nrow(fl), fails))
if (fails > 0L) quit(status = 1L)
