# Northern Territory statewide voting-intention polls, in the anchor's poll-file
# shape, so load_polls("nt") works.
#
# WHY. The anchor project (external/aus-polling-analyser) has no NT poll file,
# no NT election cycles and no NT prior results. load_polls() reads the
# anchor's poll-data-<region>.csv; for a region the anchor lacks it now falls
# back to external/reference/anchor-supplement/poll-data-<region>.csv, which
# this script writes from OUR Wikipedia scrape
# (external/reference/polls/statewide-samples/statewide_polls_wiki.csv, built by
# scripts/fetch_statewide_poll_samples.R, which already lists the NT cycles).
#
# What counts as a statewide poll: table_type "primary", row_type "poll", in a
# "Voting intention" section (not "By region", "By seat", leadership). Election
# result rows are dropped. Undecided is divided out (the anchor's convention).
# MediaReach "May-Jun 2020" is EXCLUDED and listed: its own footnote says it is
# Kevin Bonham's estimate built from MediaReach's individual seat polls, not a
# statewide sample.
#
# Classes: the CLP column is the Coalition (LNP, as classify_party() files it);
# Territory Alliance, independents, Shooters and every other party go to OTH.
#
# THE CYCLES ARE TOO THIN FOR THE TREND. trend_as_at() needs 8 polls in a cycle
# (min_polls = 8). The NT has 2 (2012-16), 4 with a fifth TPP-only (2016-20) and
# 2 (2020-24) -- printed below. So the forecast-mode NT harness skips every pair
# loudly; this file exists so that the count is visible and the path works the
# day a cycle has enough polls.
#
# Emits NP* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

src <- file.path(pkg_root(), "external", "reference", "polls", "statewide-samples", "statewide_polls_wiki.csv")
W <- fread(src, showProgress = FALSE, colClasses = "character")
W <- W[W$region == "nt" & W$table_type == "primary" & W$row_type == "poll" &
       grepl("Voting intention", W$section) & !grepl("By region|By seat|Electorate", W$section)]
pct <- function(x) suppressWarnings(as.numeric(gsub("[%,]", "", x)))
g <- function(col) if (col %in% names(W)) pct(W[[col]]) else rep(NA_real_, nrow(W))
bonham <- grepl("Estimated by Kevin Bonham", W$footnote_raw)
if (any(bonham)) cat(sprintf("NP0  excluded (seat-poll aggregate, not a statewide sample): %s %s\n",
                             W$firm_raw[bonham], W$date_raw[bonham]))
W <- W[!bonham]
alp <- g("pv_ALP"); clp <- g("pv_CLP"); grn <- g("pv_GRN")
und <- g("pv_UND"); tpp <- g("tpp_ALP")
oth_cols <- intersect(c("pv_OTH", "pv_TA", "pv_IND", "pv_SFF"), names(W))
oth <- rowSums(sapply(oth_cols, function(k) { v <- pct(W[[k]]); ifelse(is.finite(v), v, 0) }))
und[!is.finite(und)] <- 0
# Divide out undecided: the published undecided share where given, otherwise
# whatever the reported primaries leave short of 100 (MediaReach Sep 2019
# reports 29 + 39 + 22 = 90, no undecided column). Printed per poll.
tot <- ifelse(is.finite(alp), alp, 0) + ifelse(is.finite(clp), clp, 0) + ifelse(is.finite(grn), grn, 0) + oth
scale <- ifelse(und > 0, 100 / (100 - und), ifelse(tot > 0, 100 / tot, 1))
for (i in which(is.finite(alp) & abs(scale - 1) > 0.005))
  cat(sprintf("NP0u %s %s: primaries rescaled x%.3f (undecided %s)\n", W$firm_raw[i], W$date_raw[i], scale[i],
              if (und[i] > 0) sprintf("%.1f published", und[i]) else sprintf("%.1f implied by a %.1f total", 100 - tot[i], tot[i])))
fs <- as.Date(W$fieldwork_start); fe <- as.Date(W$fieldwork_end)
mid <- as.Date(as.integer(fs) + (as.integer(fe) - as.integer(fs)) %/% 2L, origin = "1970-01-01")
firm <- ifelse(nzchar(W$firm), W$firm, "Unnamed")
has_fp <- is.finite(alp) & is.finite(clp)
P <- data.table(MidDate = format(mid), Firm = firm, Brand = "",
                `@TPP` = tpp,
                `LNP FP` = ifelse(has_fp, round(clp * scale, 2), NA),
                `ALP FP` = ifelse(has_fp, round(alp * scale, 2), NA),
                `GRN FP` = ifelse(has_fp & is.finite(grn), round(grn * scale, 2), NA),
                `OTH FP` = ifelse(has_fp, round(oth * scale, 2), NA),
                Comments = sprintf("%s; Wikipedia %s (%s)", W$election, W$page_key, W$date_raw))
setorder(P, MidDate)
out_dir <- file.path(pkg_root(), "external", "reference", "anchor-supplement")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
f <- file.path(out_dir, "poll-data-nt.csv")
# the anchor's own NA token, so the same reader handles both files
fwrite(P, f, na = "#N/A")
cat(sprintf("NP1  wrote %s: %d polls (%d with first preferences)\n", f, nrow(P), sum(has_fp)))
ed <- election_dates(c("nt2012", "nt2016", "nt2020", "nt2024"))
for (k in 2:4) {
  inn <- as.Date(P$MidDate) > ed[k - 1L] & as.Date(P$MidDate) < ed[k]
  cat(sprintf("NP2  %s cycle (%s to %s): %d statewide polls, %d with first preferences (trend needs 8)\n",
              names(ed)[k], ed[k - 1L], ed[k], sum(inn), sum(inn & !is.na(P$`ALP FP`))))
}
print(P)
