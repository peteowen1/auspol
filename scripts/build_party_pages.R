# One page per party and jurisdiction for the ITG site (Pete, 11 Nov 2026: "can we have party pages as well? see how
# each party did in each election (state parties are different so its NSW labor, SA labor, Federal Labor etc)").
# auspol builds the data; ITG builds politics/party.qmd from it (same split as scripts/build_pollster_pages.R).
#
#   Rscript scripts/build_party_pages.R
#
# Reads output/candidacies.csv (every candidate's votes and whether they won, 44 elections), load_eventual_results()
# (the statewide two-party-preferred result), election_dates() (polling day), output/published-predictions.csv
# (our backtest, 35 elections), and for the live elections output/forecast-vic2026.json (seat totals, when present)
# plus output/vic-page-data.json and output/nsw2027-page-data.json (first-preference trend). Writes
# output/party-pages.json.
#
# Party: the commission's own party name, grouped into Labor, Liberal, Nationals, LNP (Qld), Country Liberal (NT),
# Greens and One Nation (classify_party()'s LNP class split by that name). A party gets a page in a jurisdiction if
# it ever won a seat there or 2% of the first preferences. Everything else is "Others" (the method note says so).
# Formed government: the side (Labor, or Liberal/National/LNP/CLP) with a majority of seats; the hung parliaments are
# set by hand in HUNG below, one line each.
# Check codes PTY1-PTY5.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
LIVE_EL <- c("vic2026", "nsw2027")

c0 <- fread("output/candidacies.csv", showProgress = FALSE)
need <- c("election", "region", "year", "seat", "name", "party", "party_raw", "votes", "elected", "tot")
if (!all(need %in% names(c0))) stop("PTY1! output/candidacies.csv lacks ", paste(setdiff(need, names(c0)), collapse = ", "))
done <- c0[!election %in% LIVE_EL]
if (anyNA(done$elected)) stop("PTY1! ", sum(is.na(done$elected)), " finished-election candidacies with no elected flag")
w1 <- done[, .(nw = sum(elected)), by = .(election, seat)]
if (any(w1$nw != 1L)) stop("PTY1! seats without exactly one winner: ", paste(head(w1[nw != 1, paste(election, seat)], 6), collapse = ", "))
cat(sprintf("PTY1 candidacies: %d finished elections, %d seat-elections, %d candidates\n", uniqueN(done$election), nrow(w1), nrow(done)))

fam_of <- function(cls, raw) {
  r <- tolower(ifelse(is.na(raw), "", raw))
  out <- rep("others", length(cls))
  out[cls == "ALP"] <- "labor"; out[cls == "GRN"] <- "greens"; out[cls == "ONP"] <- "one-nation"
  l <- cls == "LNP"
  out[l] <- "liberal"
  out[l & grepl("national|^nat|^np$|^nats$", r)] <- "nationals"
  out[l & grepl("liberal national|^lnp$|^lnq$", r)] <- "lnp"
  # The CLP's federal labels vary by year: "CLP-The Territory Party" (fed2004), "C.L.P." (fed2007),
  # "Country Liberals (NT)" (fed2010-19), "NT CLP" (fed2022-25). PTY2 checks every one lands here.
  out[l & grepl("country liberal|c\\.l\\.p|\\bclp\\b", r)] <- "clp"
  out
}
FAM <- data.table(fam = c("labor", "liberal", "nationals", "lnp", "clp", "greens", "one-nation"),
                  fname = c("Labor", "Liberal", "Nationals", "LNP", "Country Liberal", "Greens", "One Nation"),
                  code = c("ALP", "LNP", "LNP", "LNP", "LNP", "GRN", "ONP"),
                  colour = c("ALP", "LIB", "NAT", "LNP", "LNP", "GRN", "ONP"))
JUR <- data.table(region = c("fed", "nsw", "vic", "qld", "sa", "wa", "nt"),
                  jname = c("Federal", "New South Wales", "Victoria", "Queensland", "South Australia", "Western Australia", "Northern Territory"),
                  prefix = c("Federal", "NSW", "Victorian", "Queensland", "SA", "WA", "NT"))
done[, fam := fam_of(party, party_raw)]
cat("PTY2 LNP-class candidates by party name:\n"); print(done[party == "LNP", .N, by = fam])
# The Coalition side in the Northern Territory is the CLP and nowhere else is: a label the regex misses
# silently files a CLP member as a Liberal (Solomon fed2004 did, review 12 Nov).
nt_seat <- done$region == "nt" | (done$region == "fed" & done$seat %in% c("Solomon", "Lingiari", "Northern Territory"))
lnp_cls <- done$party == "LNP"
is_clp <- done$fam == "clp"
mis_nt <- done[lnp_cls & nt_seat & !is_clp]
mis_out <- done[is_clp & !nt_seat]
cat(sprintf("PTY2 CLP: %d Northern Territory Coalition candidacies, %d not filed as CLP, %d CLP outside the Territory\n",
            sum(lnp_cls & nt_seat), nrow(mis_nt), nrow(mis_out)))
if (nrow(mis_nt) || nrow(mis_out)) stop("PTY2! CLP filing wrong: ", paste(head(c(mis_nt[, paste(election, seat, party_raw)], mis_out[, paste(election, seat, party_raw)]), 6), collapse = "; "))

# ---- per election and party: first preferences and seats --------------------------------------------------------
el <- done[, .(region = region[1], year = year[1], seats_total = uniqueN(seat), formal = sum(votes)), by = election]
pe <- done[, .(votes = sum(votes), seats_won = sum(elected), seats_contested = uniqueN(seat)), by = .(election, fam)]
pe <- merge(pe, el, by = "election"); pe[, fp_pct := round(100 * votes / formal, 2)]
# anchor check: our Labor share against the commission's statewide figure
ev <- as.data.table(load_eventual_results())
chk <- merge(pe[fam == "labor", .(region, year, fp_pct)], ev[party == "ALP", .(region, year, actual)], by = c("region", "year"))
# The anchor's NSW 2007 Labor/Coalition swap (found by this check, 11 Nov 2026) is corrected in
# load_eventual_results() since 12 Nov (EVR1), so every election is checked.
if (!nrow(chk)) stop("PTY2! no election joined to the statewide results")
chk[, el := paste0(region, year)]
gap <- abs(chk$fp_pct - chk$actual)
cat(sprintf("PTY2 Labor first preferences vs the commission's statewide figure: %d elections, largest gap %.2f points (%s)\n",
            nrow(chk), max(gap), chk$el[which.max(gap)]))
if (max(gap) > 0.5) stop("PTY2! summed first preferences disagree with the statewide result by more than 0.5 points: ", paste(chk$el[gap > 0.5], collapse = ", "))
tpp <- ev[party == "@TPP", .(region, year, alp_tpp = actual)]
pe <- merge(pe, tpp, by = c("region", "year"), all.x = TRUE)
ed <- election_dates(); pe[, date := as.character(ed[election])]
if (anyNA(pe$date)) stop("PTY2! no polling day for ", paste(unique(pe[is.na(date), election]), collapse = ", "))
setorder(pe, region, fam, year)
pe[, fp_change := round(fp_pct - shift(fp_pct), 2), by = .(region, fam)]
# the previous covered election had this party absent: change from nothing is not a swing, so null
prev_el <- el[order(region, year)][, .(election, prev = shift(election)), by = region]
pe <- merge(pe, prev_el[, .(election, prev)], by = "election")
pe[, ran_prev := paste(prev, fam) %in% paste(pe$election, pe$fam)]; pe[ran_prev == FALSE, fp_change := NA_real_]

# Seats decided at a supplementary election after a candidate died, so absent from the general election's count
# (candidacies.csv): counted in the seats, not in the first preferences, and every party's row says so.
# Narracan: VEC page external/reference/vec/2022/booths/narracan-supp2023-2cp.html (FARNHAM, Wayne, Liberal).
SUPP <- data.table(election = "vic2022", seat = "Narracan", fam = "liberal",
                   note = "Seats include Narracan, decided at a supplementary election on 28 January 2023 (a Liberal win) after a candidate died; its votes are not in the first-preference figures.")
if (any(paste(SUPP$election, SUPP$seat) %in% paste(done$election, done$seat))) stop("PTY3! a SUPP seat is already in the general count")
pe[SUPP, on = c("election", "fam"), seats_won := seats_won + 1L]
n_supp <- SUPP[, .(n_s = .N), by = election]
pe[n_supp, on = "election", seats_total := seats_total + i.n_s]
pe <- merge(pe, SUPP[, .(supp_note = note[1]), by = election], by = "election", all.x = TRUE)

# ---- government --------------------------------------------------------------------------------------------------
coal <- c("liberal", "nationals", "lnp", "clp")
side <- pe[, .(alp = sum(seats_won[fam == "labor"]), coal = sum(seats_won[fam %in% coal])), by = .(election, seats_total)]
side[, gov := fifelse(alp > seats_total / 2, "labor", fifelse(coal > seats_total / 2, "coalition", NA_character_))]
# Hung parliaments: who formed government, set by hand (one line each; checked against the majority rule above, which
# prints every election it cannot decide).
HUNG <- data.table(election = c("fed2010", "nsw2023", "qld2015", "sa2014", "wa2008"),
                   gov = c("labor", "labor", "labor", "labor", "coalition"),
                   note = c("Labor minority government with Greens and independent support",
                            "Labor minority government (45 of 93 seats) with crossbench support",
                            "Labor minority government with independent support",
                            "Labor minority government with two independents",
                            "Liberal minority government with the Nationals and independents"))
undecided <- side[is.na(gov), election]
cat("PTY3 elections with no majority:", paste(undecided, collapse = ", "), "\n")
if (!setequal(undecided, HUNG$election)) stop("PTY3! hung parliaments ", paste(undecided, collapse = ","), " but HUNG lists ", paste(HUNG$election, collapse = ","))
side <- merge(side, HUNG, by = "election", all.x = TRUE, suffixes = c("", ".h")); side[is.na(gov), gov := gov.h]
pe <- merge(pe, side[, .(election, gov, gov_note = note)], by = "election")
# the Nationals govern with the Liberals in a formal Coalition federally and in NSW and Victoria, and held cabinet
# posts in WA 2008-2017; in SA they sit apart
nat_in <- function(region, year) region %in% c("fed", "nsw", "vic") | (region == "wa" & year %in% c(2008, 2013))
pe[, formed_government := fifelse(fam == "labor", gov == "labor",
                         fifelse(fam %in% c("liberal", "lnp", "clp"), gov == "coalition",
                         fifelse(fam == "nationals", gov == "coalition" & nat_in(region, year), FALSE)))]
pe[fam == "nationals" & gov == "coalition" & !nat_in(region, year), gov_note := "the Liberals governed; the Nationals sat apart"]
pe[, tpp_pct := fifelse(fam == "labor", alp_tpp, fifelse(fam %in% c("liberal", "lnp", "clp"), round(100 - alp_tpp, 2), NA_real_))]

# ---- backtest forecast -------------------------------------------------------------------------------------------
pp <- fread("output/published-predictions.csv", showProgress = FALSE)
pp <- pp[pair %in% el$election]
cand <- done[, .(election, seat, name, cls = party, fam)]
# a three-cornered contest is one pooled row in the backtest ("Patrick SECKER +1": the Coalition's candidates as one); it
# counts toward the named lead candidate's party
pp[, cand_key := sub("\\s*\\+[0-9]+$", "", candidate)]
# two candidates of one seat can share a name (WA 2001 lists surnames only, "WATSON" twice in Albany): one row per key,
# the party only where the namesakes agree, so the merge cannot duplicate a prediction row
cand_u <- cand[, .(fam_n = if (uniqueN(fam) == 1L) fam[1] else NA_character_), by = .(pair = election, seat, cand_key = name)]
n_pp <- nrow(pp)
pp <- merge(pp, cand_u, by = c("pair", "seat", "cand_key"), all.x = TRUE)
if (nrow(pp) != n_pp) stop("PTY4! the candidate merge changed the backtest row count (", n_pp, " -> ", nrow(pp), ")")
one <- cand[cls == "LNP", .(n = .N, fam1 = fam[1]), by = .(pair = election, seat)][n == 1L]
pp <- merge(pp, one[, .(pair, seat, fam1)], by = c("pair", "seat"), all.x = TRUE)
pp[, fam := fifelse(!is.na(fam_n), fam_n, fifelse(party == "LNP" & !is.na(fam1), fam1, fam_of(party, "")))]
unl <- pp[party == "LNP" & is.na(fam_n) & is.na(fam1)]
cat(sprintf("PTY4 backtest rows %d over %d elections; Liberal/National-class rows labelled by name %d, by the seat's only Coalition candidate %d, unresolved (counted Liberal) %d\n",
            nrow(pp), uniqueN(pp$pair), sum(pp$party == "LNP" & !is.na(pp$fam_n)), sum(pp$party == "LNP" & is.na(pp$fam_n) & !is.na(pp$fam1)), nrow(unl)))
st <- unique(done[, .(pair = election, seat, tot)])
pp <- merge(pp, st, by = c("pair", "seat"), all.x = TRUE)
tot_el <- st[, .(T = sum(tot)), by = pair]
bt <- pp[, .(fc_fp = sum(ours / 100 * tot, na.rm = TRUE), fc_seats = round(sum(p_win), 2)), by = .(pair, fam)]
bt <- merge(bt, tot_el, by = "pair"); bt[, fc_fp := round(100 * fc_fp / T, 2)]
pe <- merge(pe, bt[, .(election = pair, fam, fc_fp, fc_seats)], by = c("election", "fam"), all.x = TRUE)

# ---- which pages -------------------------------------------------------------------------------------------------
pe <- pe[fam != "others"]
keep <- pe[, .(any_seat = any(seats_won > 0), max_fp = max(fp_pct)), by = .(region, fam)][any_seat | max_fp >= 2]
pe <- merge(pe, keep[, .(region, fam)], by = c("region", "fam"))
keep <- merge(merge(keep, JUR, by = "region"), FAM, by = "fam")
keep[, slug := paste(region, fam, sep = "-")][, name := paste(prefix, fname)]

# ---- live elections ----------------------------------------------------------------------------------------------
live_of <- function(region, fam) {
  e <- LIVE_EL[startsWith(LIVE_EL, region)]; if (!length(e)) return(NULL)
  pg <- sprintf("output/%s-page-data.json", if (e == "vic2026") "vic" else e)
  if (!file.exists(pg)) return(NULL)
  d <- jsonlite::fromJSON(pg, simplifyVector = TRUE)
  cls <- FAM$code[FAM$fam == fam]
  fp <- d$fp_now[d$fp_now$party == cls, ]
  fj <- sprintf("output/forecast-%s.json", e); ch <- NULL
  if (file.exists(fj)) { f <- jsonlite::fromJSON(fj, simplifyVector = FALSE)
    ch <- Filter(function(x) identical(x$party, cls), f$chamber$parties); ch <- if (length(ch)) ch[[1]] else NULL }
  list(election = e, page = paste0("/politics/", sub("[0-9]+$", "", e)), as_of = d$meta$as_of,
       class_note = if (cls == "LNP") "the forecast models the Coalition as one (Liberal, National, LNP)" else NA,
       fp_trend_pct = if (nrow(fp)) round(fp$m[1], 1) else NA,
       expected_seats = if (!is.null(ch)) ch$expected else NA, p_most_seats = if (!is.null(ch)) ch$p_most_seats else NA)
}

nn <- function(x) if (length(x) != 1L || is.na(x)) NULL else x
parties <- lapply(seq_len(nrow(keep)), function(i) {
  k <- keep[i]; rows <- pe[region == k$region & fam == k$fam][order(-year)]
  els <- lapply(seq_len(nrow(rows)), function(j) { r <- rows[j]
    list(election = r$election, date = r$date, fp_pct = r$fp_pct, fp_change = nn(r$fp_change), seats_won = r$seats_won,
         seats_contested = r$seats_contested, seats_total = r$seats_total, tpp_pct = nn(r$tpp_pct),
         formed_government = isTRUE(r$formed_government), government_note = nn(r$gov_note), note = nn(r$supp_note),
         forecast = if (is.na(r$fc_seats)) NULL else list(kind = "backtest", fp_pct = r$fc_fp, expected_seats = r$fc_seats)) })
  rel <- keep[fam == k$fam & region != k$region, slug]
  list(slug = k$slug, name = k$name, jurisdiction = k$region, code = k$code, colour = k$colour, family = k$fam,
       related = I(rel), elections = els, live = live_of(k$region, k$fam))
})
if (anyDuplicated(keep$slug)) stop("PTY5! duplicate slugs")
doc <- list(
  built = format(Sys.time(), "%Y-%m-%d %H:%M %Z"),
  method = list(
    elections_covered = sort(unique(pe$election)),
    sources = "Every candidate's first-preference votes and the winner of each seat from the electoral commissions' results (AEC and each state and territory commission), as compiled in auspol's output/candidacies.csv; the statewide two-party-preferred result from the same commissions; polling day from the election calendar.",
    coalition = "Split by the party name the commission prints: Liberal and Nationals have their own pages; Queensland's LNP (since 2008) and the NT's Country Liberals are their own parties. Two-party-preferred sits on the Labor page and on the Liberal, LNP or Country Liberal page as the Coalition side.",
    others = "A party gets a page in a jurisdiction if it ever won a seat or 2% of the first preferences there. Every other party and every independent is counted in the totals but has no page.",
    forecast_note = "A backtest is our current seat model re-run on what was known before that election, not a forecast published at the time. Expected seats is the sum of the seat win probabilities; the first-preference figure is our predicted share weighted by each seat's formal vote. Where our forecast models the Coalition as one, a Liberal or National figure comes from that party's own candidates; in a three-cornered contest the backtest pools the Coalition's candidates, and that seat counts toward the named lead candidate's party.",
    government_note = "Formed government: the side with a majority of seats; in the five hung parliaments (fed2010, nsw2023, qld2015, sa2014, wa2008) the party that formed government, set by hand. The Nationals count as in government federally and in NSW and Victoria when the Coalition governed, and in WA 2008 and 2013 (cabinet posts)."),
  jurisdictions = lapply(seq_len(nrow(JUR)), function(i) list(code = JUR$region[i], name = JUR$jname[i])),
  parties = parties)
dir.create("output", showWarnings = FALSE)
tmp <- "output/party-pages.json.tmp"
writeLines(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null", na = "null", digits = NA, pretty = FALSE), tmp)
chk <- jsonlite::fromJSON(tmp, simplifyVector = FALSE)
if (length(chk$parties) != nrow(keep)) stop("PTY5! the written file does not read back")
invisible(file.rename(tmp, "output/party-pages.json"))
cat(sprintf("PTY5 wrote output/party-pages.json: %d party pages over %d jurisdictions, %d party-elections, %d with a backtest, %d with live data\n",
            length(parties), uniqueN(keep$region), nrow(pe), sum(!is.na(pe$fc_seats)), sum(vapply(parties, function(p) !is.null(p$live), logical(1)))))
