# Leader ratings: preferred PM/premier and satisfaction, per poll, for every election whose archived Wikipedia
# page has a leadership table, plus AE's government-leader approve/disapprove series. Pete, 2026-10-12: track
# leader trends on the site and test them as a forecast input (docs/PETE-ASKED-FOR.md).
# Writes output/leader-ratings.csv (long: one row per poll x leader x measure). Read-only otherwise. LR* codes
# are taken (R/level_recent.R prints LR0), so this emits LK* codes.
#
# Measures: preferred (share naming this leader as preferred PM/premier), pref_undecided, satisfied,
# dissatisfied, sat_dk, net_sat (satisfied - dissatisfied, recomputed), approve / disapprove (AE files).
# Columns a page labels "Net" are dropped and recomputed, so every net uses one definition.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
# Daily refresh (forecast.yaml): AUSPOL_LEADER_SRC is a fresh parse of the live pages only, AUSPOL_LEADER_KEEP the
# published full table, whose Wikipedia rows for every OTHER election are kept; AUSPOL_LEADER_OUT where to write.
SRC <- Sys.getenv("AUSPOL_LEADER_SRC", file.path("external", "reference", "polls", "statewide-samples", "statewide_polls_wiki.csv"))
KEEP <- Sys.getenv("AUSPOL_LEADER_KEEP", "")
OUT <- Sys.getenv("AUSPOL_LEADER_OUT", out_path("leader-ratings.csv"))
w <- fread(SRC, showProgress = FALSE)
cat(sprintf("LK0 source %s (%d rows, pages %s)%s\n", SRC, nrow(w), paste(sort(unique(w$page_key)), collapse = ","),
            if (nzchar(KEEP)) paste0("; keeping other elections from ", KEEP) else ""))

# Party of every leader named in the tables. Fixed facts; Pickering checked against the archived vic2026 page
# ("Warren Pickering becomes state leader of One Nation"). Speirs_Tarzia_Hurn is one column for three
# successive SA Liberal leaders.
PARTY <- c(Albanese = "ALP", Allan = "ALP", Andrews = "ALP", Carroll = "ALP", Cook = "ALP", Gillard = "ALP",
           Keneally = "ALP", Malinauskas = "ALP", McGowan = "ALP", Miles = "ALP", Minns = "ALP", Palaszczuk = "ALP",
           Rudd = "ALP", Shorten = "ALP", Weatherill = "ALP",
           Abbott = "LNP", Battin = "LNP", Crisafulli = "LNP", Dutton = "LNP", Frecklington = "LNP", Guy = "LNP",
           Kirkup = "LNP", Marshall = "LNP", Mettam = "LNP", Morrison = "LNP", Napthine = "LNP", Newman = "LNP",
           Nicholls = "LNP", O_Farrell = "LNP", Perrottet = "LNP", Pesutto = "LNP", Sloane = "LNP",
           Speirs_Tarzia_Hurn = "LNP", Tarzia_Hurn = "LNP", Turnbull = "LNP", Wilson = "LNP",
           Taylor = "LNP", Ley = "LNP", Hanson = "ON", Waters = "GRN",
           Pickering = "ON",
           # Tasmania and the NT (pages added 2026-10-13; CLP counts as the Coalition class)
           Bartlett = "ALP", Giddings = "ALP", Green = "ALP", White = "ALP", Winter = "ALP", Gunner = "ALP", Fyles = "ALP",
           Lawler = "ALP", Hodgman = "LNP", Gutwein = "LNP", Rockliff = "LNP", Finocchiaro = "LNP", Mills = "LNP",
           Higgins = "LNP")
# Party in government going into each election (the cycle the page's polls belong to).
GOVT <- c(fed2013 = "ALP", fed2016 = "LNP", fed2019 = "LNP", fed2022 = "LNP", fed2025 = "ALP", fed2028 = "ALP",
          nsw2011 = "ALP", nsw2019 = "LNP", nsw2023 = "LNP", nsw2027 = "ALP",
          qld2015 = "LNP", qld2017 = "ALP", qld2020 = "ALP", qld2024 = "ALP", qld2028 = "LNP",
          sa2018 = "ALP", sa2022 = "LNP", sa2026 = "ALP",
          vic2014 = "LNP", vic2018 = "ALP", vic2022 = "ALP", vic2026 = "ALP",
          wa2017 = "LNP", wa2021 = "ALP", wa2025 = "ALP",
          # added 2026-10-13 with the Tasmanian and NT pages (Bartlett ALP; Rockliff Liberal; Gunner ALP)
          tas2010 = "ALP", tas2014 = "ALP", tas2018 = "LNP", tas2021 = "LNP", tas2024 = "LNP", tas2025 = "LNP",
          nt2016 = "LNP", nt2020 = "ALP", nt2024 = "ALP")
# Audit GOVT against leaders.csv's head of government wherever it names one (local builds; the CI runner has no
# external/ folder, and the tables it audits are the same committed ones).
LDF <- file.path("external", "reference", "leaders", "leaders.csv")
if (!file.exists(LDF)) { cat("LK0 leaders.csv not here (CI): GOVT audit skipped; it runs on every local build\n"); ld <- data.table(election = character(), head_of_govt = character()) } else
ld <- fread(LDF, showProgress = FALSE)
hg <- unique(ld[nzchar(ld$head_of_govt) & ld$election %in% names(GOVT), .(election, head_of_govt)])
hg[, surname := sub("^.* ", "", head_of_govt)][, surname := gsub("'", "_", surname)]
hg[surname == "Farrell", surname := "O_Farrell"]
chk <- hg[surname %in% names(PARTY)]
chk[, ok := PARTY[surname] == GOVT[election]]
cat(sprintf("LK0 GOVT audited against leaders.csv head of government: %d elections checked, %d disagree%s\n", nrow(chk), sum(!chk$ok),
            if (any(!chk$ok)) paste0(": ", paste(chk$election[!chk$ok], collapse = ", ")) else ""))
if (any(!chk$ok)) stop("LK0! government party table disagrees with leaders.csv")

LEAD_SEC <- "Preferred|premier|approval|satisf|leadership|Better Prime"
s <- w[grepl(LEAD_SEC, w$section, ignore.case = TRUE) & !grepl("Three-party|Two party|Hypothetical|seat|Subpop|Party approval", w$section, ignore.case = TRUE) & w$row_type == "poll"]
pct <- function(x) suppressWarnings(as.numeric(gsub("[%,]", "", as.character(x))))
PREF_RX <- "^x_(Better_Premier|Better_premier|Better_PM|Preferred_prime_minister|Preferred_Prime_Minister|Preferred_Premier|Party_leaders)_(.+)$"
SAT_RX1 <- "^x_(.+)_(Satisfied|Dissatisfied|Pos_|Neg_|DK|Don_t_Know|Don_t_know|Undecided)$"
SAT_RX2 <- "^x_(Satisfied|Dissatisfied)_(.+)$"
SAT_MEAS <- c(Satisfied = "satisfied", Pos_ = "satisfied", Dissatisfied = "dissatisfied", Neg_ = "dissatisfied",
              DK = "sat_dk", Don_t_Know = "sat_dk", Don_t_know = "sat_dk", Undecided = "sat_dk")
UNDEC <- c("Don_t_know", "Don_t_Know", "Undecided", "Unsure")
fs <- as.Date(s$fieldwork_start); fe <- as.Date(s$fieldwork_end)
s$mid <- as.Date(ifelse(is.finite(fs) & is.finite(fe) & fs <= fe, as.integer(fs) + (as.integer(fe) - as.integer(fs)) %/% 2L, as.integer(fe)), origin = "1970-01-01")
rows <- list(); skipped <- character(0)
# How many leaders the preferred-PM/premier question on each row named (2 = head to head, 3 = with a minor
# leader): the same poll can carry both, e.g. Newspoll Oct 2026 Albanese 44 v Taylor 39, and Albanese 45 /
# Hanson 30 / Taylor 25. A chart must not join the two.
pref_cols <- grep(PREF_RX, grep("^x_", names(s), value = TRUE), value = TRUE)
pref_cols <- pref_cols[!sub(PREF_RX, "\\2", pref_cols) %in% c(UNDEC, "Net", "Unsure")]
s$n_named <- if (length(pref_cols)) rowSums(vapply(pref_cols, function(cc) is.finite(pct(s[[cc]])), logical(nrow(s)))) else 0L
for (cc in grep("^x_", names(s), value = TRUE)) {
  v <- pct(s[[cc]]); has <- which(is.finite(v)); if (!length(has)) next
  meas <- NA_character_; who <- NA_character_
  if (grepl(PREF_RX, cc)) { who <- sub(PREF_RX, "\\2", cc); meas <- if (who %in% UNDEC) "pref_undecided" else if (who == "Net") NA else "preferred" }
  else if (grepl(SAT_RX2, cc)) { who <- sub(SAT_RX2, "\\2", cc); meas <- SAT_MEAS[[sub(SAT_RX2, "\\1", cc)]] }
  else if (grepl(SAT_RX1, cc)) { who <- sub(SAT_RX1, "\\1", cc); meas <- SAT_MEAS[[sub(SAT_RX1, "\\2", cc)]] }
  if (is.na(meas)) { skipped <- c(skipped, sub("^x_", "", cc)); next }
  if (meas == "pref_undecided") who <- "(undecided)"
  else if (!who %in% names(PARTY)) { skipped <- c(skipped, sub("^x_", "", cc)); next }
  rows[[length(rows) + 1L]] <- data.table(election = s$election[has], region = s$region[has], page_key = s$page_key[has],
    section = s$section[has], date = s$mid[has], end = fe[has], firm = s$firm[has], sample_n = s$sample_n[has],
    leader = who, measure = meas, value = v[has], source = "wikipedia",
    n_named = if (meas %in% c("preferred", "pref_undecided")) s$n_named[has] else NA_integer_)
}
L <- rbindlist(rows)
L <- L[is.finite(L$date)]
L[, party := ifelse(leader %in% names(PARTY), PARTY[leader], NA_character_)]
L[, role := ifelse(is.na(party), NA_character_, ifelse(party == GOVT[election], "gov", ifelse(party %in% c("ALP", "LNP"), "opp", "minor")))]
if (anyNA(GOVT[unique(L$election)])) stop("LK1! no government party for: ", paste(setdiff(unique(L$election), names(GOVT)), collapse = ", "))
# net satisfaction, recomputed from the two sides of the same poll row
key <- c("election", "page_key", "section", "date", "end", "firm", "leader")
sd <- dcast(L[L$measure %in% c("satisfied", "dissatisfied")], as.formula(paste(paste(key, collapse = "+"), "~ measure")), value.var = "value", fun.aggregate = mean)
sd <- sd[is.finite(sd$satisfied) & is.finite(sd$dissatisfied)]
net <- merge(sd[, c(key, "satisfied", "dissatisfied"), with = FALSE], unique(L[, c(key, "region", "sample_n", "party", "role"), with = FALSE]), by = key)
net <- net[, c(list(measure = "net_sat", value = satisfied - dissatisfied, source = "wikipedia"), .SD), .SDcols = c(key, "region", "sample_n", "party", "role")]
L <- rbind(L, net, use.names = TRUE, fill = TRUE)
# AE's government-leader approve / disapprove, by election cycle
cycles <- load_election_cycles()
ae <- rbindlist(lapply(c("fed", "nsw", "qld", "sa", "vic", "wa"), function(rg) {
  p <- data.table::as.data.table(suppressMessages(load_polls(rg)))
  if (!"gl_approve" %in% names(p)) return(NULL)
  p <- p[is.finite(p$gl_approve)]
  if (!nrow(p)) return(NULL)
  cy <- cycles[cycles$region == rg]
  el <- vapply(p$date, function(d) { j <- which(cy$start < d & cy$end >= d); if (length(j)) paste0(rg, cy$year[j[1]]) else NA_character_ }, "")
  rbind(data.table(election = el, region = rg, date = p$date, end = p$date, firm = p$firm, leader = "(government leader)", measure = "approve", value = p$gl_approve),
        data.table(election = el, region = rg, date = p$date, end = p$date, firm = p$firm, leader = "(government leader)", measure = "disapprove", value = p$gl_disapprove))
}))
ae <- ae[is.finite(ae$value)]
ae[, `:=`(source = "ae", role = "gov", party = NA_character_, page_key = NA_character_, section = NA_character_, sample_n = NA_real_)]
L <- rbind(L, ae, use.names = TRUE, fill = TRUE)
if (nzchar(KEEP)) {
  # Live refresh: fresh Wikipedia rows for the elections just parsed, the published rows for every other
  # election. AE rows are always rebuilt here from the anchor files, so drop the published copies of them.
  K <- fread(KEEP, showProgress = FALSE)
  fresh <- unique(L$election[L$source == "wikipedia"])
  kk <- K[K$source == "wikipedia" & !(K$election %in% fresh)]
  for (cc in c("date", "end")) if (cc %in% names(kk)) kk[[cc]] <- as.Date(kk[[cc]])
  L <- rbind(L, kk, use.names = TRUE, fill = TRUE)
  cat(sprintf("LK1k refreshed %s from the live pages; kept %d published rows for %d other elections\n",
              paste(sort(fresh), collapse = ","), nrow(kk), uniqueN(kk$election)))
}
setorder(L, region, election, date, leader, measure)

cat(sprintf("LK2 %d rows: %d from Wikipedia leadership tables (%d pages), %d from AE approve/disapprove\n",
            nrow(L), sum(L$source == "wikipedia"), uniqueN(L$page_key[L$source == "wikipedia"]), sum(L$source == "ae")))
cat("LK3 columns not used (party names, page 'Net' columns, unlabelled):", paste(sort(unique(skipped)), collapse = ", "), "\n")
cov <- L[, .(polls = uniqueN(paste(date, firm)), from = min(date), to = max(date),
             pref = sum(measure == "preferred"), sat = sum(measure == "satisfied"), ae = sum(source == "ae")), by = election][order(election)]
print(cov, nrows = 100)
# Coverage, not presence
if (!all(c("gov", "opp") %in% L$role[L$source == "wikipedia"])) stop("LK4! roles missing")
if (any(L$value < 0 & L$measure != "net_sat") || any(L$value > 100)) stop("LK4! a share outside 0-100")
fwrite(L, OUT)
cat(sprintf("LK5 wrote %s\n", OUT))
