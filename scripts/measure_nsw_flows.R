# Measure NSW preference flows (One Nation, Greens) from the NSWEC distribution-
# of-preferences pages cached under external/reference/nsw/dop. ANALYSIS ONLY:
# reads the cache, changes no model code, writes nothing but stdout.
#   Rscript scripts/measure_nsw_flows.R
# Every number in docs/reviews/nsw-onp-flows-measured-2026-10-07.md comes from
# this output.
#
# Why parse the HTML again rather than use nswec-nsw-transfers.csv: that file
# collapses parties to classes (OTH, OTH_RIGHT) and drops the Exhausted row, and
# exhaustion is the quantity in question.
suppressMessages(library(data.table))
RAW <- file.path("external", "reference", "nsw", "dop")
strip <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", "", x)))
num <- function(s) suppressWarnings(as.numeric(gsub("[^0-9]", "", s)))

parse_dop <- function(f, election, seat) {
  h <- paste(readLines(f, warn = FALSE), collapse = "\n")
  tb <- regmatches(h, regexpr("(?s)<table.*?</table>", h, perl = TRUE))
  if (!length(tb)) return(NULL)
  trs <- regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]]
  cells <- lapply(trs, function(tr)
    strip(regmatches(tr, gregexpr("(?s)<t[hd].*?</t[hd]>", tr, perl = TRUE))[[1]]))
  hdr <- cells[[2]]
  exc <- hdr[grepl("Excluded Candidate", hdr)]
  if (!length(exc)) return(NULL)
  # a header cell naming more than one candidate would be a bulk exclusion
  stopifnot(!any(lengths(regmatches(exc, gregexpr("Excluded Candidate", exc))) > 1))
  exc_code <- sub(".*[(]([^)]+)[)].*", "\\1", exc)
  exc_code[!grepl("[(][^)]+[)]", exc)] <- "IND"
  exc_name <- trimws(sub("\\(.*", "", exc))
  K <- length(exc)
  cand <- list(); ex_row <- NULL; tot_row <- NULL
  for (r in cells) {
    if (length(r) < 4) next
    lab <- r[1]
    if (grepl("^Exhausted", lab)) { ex_row <- r[-1]; next }
    if (grepl("^Total Votes / Ballot", lab)) { tot_row <- r[-1]; next }
    if (grepl("^(Candidates|Total|Informal|Absolute|Counts)", lab) || !nzchar(lab)) next
    cand[[length(cand) + 1L]] <- r
  }
  out <- list()
  ex_label <- rep(NA_character_, K)
  for (k in seq_len(K)) {
    i <- 2L * (k - 1L) + 2L            # index into r[-1] of VotesDistributed for exclusion k
    for (r in cand) {
      v <- r[-1]
      raw <- if (i <= length(v)) v[i] else ""
      if (raw == "EXCLUDED") ex_label[k] <- r[1]
      if (raw %in% c("", "EXCLUDED")) next
      d <- num(raw)
      if (is.na(d)) next
      out[[length(out) + 1L]] <- data.table(election = election, seat = seat, k = k,
        exc_name = exc_name[k], exc_code = exc_code[k], to_label = r[1], votes = d,
        n_cand = length(cand), total_distributed = num(tot_row[i]))
    }
    out[[length(out) + 1L]] <- data.table(election = election, seat = seat, k = k,
      exc_name = exc_name[k], exc_code = exc_code[k], to_label = "EXHAUSTED",
      votes = num(ex_row[i]), n_cand = length(cand), total_distributed = num(tot_row[i]))
  }
  d <- rbindlist(out)
  d[, K := K]
  stopifnot(!anyNA(ex_label))
  d[, ex_label := ex_label[k]]
  attr(d, "fp") <- data.table(election = election, seat = seat, label = vapply(cand, `[`, "", 1L),
                              fp = vapply(cand, function(r) num(r[2]), 0))
  d
}

files <- list.files(RAW, pattern = "^(SG1901|SG2301)-.*\\.html$", full.names = TRUE)
parsed <- lapply(files, function(f) {
  b <- sub("[.]html$", "", basename(f))
  parse_dop(f, if (startsWith(b, "SG1901")) "nsw2019" else "nsw2023", sub("^SG[0-9]+-", "", b))
})
res <- rbindlist(parsed)
cand_fp <- rbindlist(lapply(parsed, attr, "fp"))
res[, n_remaining := n_cand - k]      # candidates still standing after this exclusion
res[, last_excl := n_remaining == 2L] # this exclusion leaves exactly two: the final-two count
cat(sprintf("PARSE  %d files; %d seat-elections with an exclusion; %d rows\n",
            length(files), uniqueN(res[, paste(election, seat)]), nrow(res)))
print(res[, .(seat_elections = uniqueN(paste(election, seat))), by = election])
cat(sprintf("PARSE  last exclusion is k == K in every seat-election: %s\n",
            all(res[, .(ok = any(k == K & last_excl)), by = .(election, seat)]$ok)))

# ---- party code of each recipient ------------------------------------------
fpz <- rbindlist(lapply(c(2019, 2023), function(y) {
  d <- as.data.table(readxl::read_excel(file.path(RAW, "..", sprintf("sge%d-la-final-votes.xlsx", y)), sheet = "Data"))
  setnames(d, make.names(names(d)))
  d <- d[Formal.Informal == "Formal"]
  d[, year := y]
  d[, .(votes = sum(as.numeric(Final.FP.Votes))),
    by = .(year, seat = tolower(gsub(" ", "-", District)), cand = Candidate.Ballot.Name,
           code = toupper(trimws(Party.Acronym)))]
}))
CODES <- unique(c(res$exc_code[res$exc_code != "IND"], fpz$code[nzchar(fpz$code) & !is.na(fpz$code)]))
CODES <- CODES[order(-nchar(CODES))]
code_of <- function(lab) {
  if (lab == "EXHAUSTED") return("EXHAUSTED")
  hit <- CODES[vapply(CODES, function(k) endsWith(lab, k), logical(1))]
  if (length(hit)) hit[1] else "IND"
}
ulab <- unique(res$to_label)
map <- setNames(vapply(ulab, code_of, ""), ulab)
res[, to_code := unname(map[to_label])]
# Party acronyms differ by year: Labor is LAB in 2019 and ALP in 2023, plus Country Labor (CLP,
# 2019 only, a Labor brand in rural seats); One Nation is PHON in 2019 and ON in 2023.
LABOR <- c("ALP", "LAB", "CLP"); ONE_NATION <- c("ON", "PHON")
res[, to_grp := fifelse(to_code %in% LABOR, "ALP",
                 fifelse(to_code %in% c("LIB", "NAT"), "COALITION",
                 fifelse(to_code == "EXHAUSTED", "EXHAUSTED", "OTHER")))]
chk <- res[, .(s = sum(votes), tot = total_distributed[1]), by = .(election, seat, k)]
cat(sprintf("CHECK  candidate transfers + exhausted == printed votes distributed on %d of %d exclusions (max abs diff %g)\n",
            sum(chk$s == chk$tot, na.rm = TRUE), nrow(chk), max(abs(chk$s - chk$tot), na.rm = TRUE)))
cat("Recipient codes by group:\n")
print(res[, .(codes = paste(sort(unique(to_code)), collapse = " ")), by = to_grp])
cat("Excluded codes (count of exclusions):\n")
print(unique(res[, .(election, seat, k, exc_code)])[, .N, by = exc_code][order(-N)][1:12])

# ---- the measure -------------------------------------------------------------
flow <- function(d) {
  v <- d[, .(v = sum(votes)), by = to_grp]
  g <- function(x) { z <- v$v[v$to_grp == x]; if (length(z)) z else 0 }
  tot <- sum(v$v); nonex <- tot - g("EXHAUSTED")
  data.table(dist = tot, ALP = g("ALP"), COAL = g("COALITION"), OTH = g("OTHER"), EXH = g("EXHAUSTED"),
    ALP_all = 100 * g("ALP") / tot, COAL_all = 100 * g("COALITION") / tot,
    OTH_all = 100 * g("OTHER") / tot, EXH_all = 100 * g("EXHAUSTED") / tot,
    ALP_nonex = 100 * g("ALP") / nonex, COAL_nonex = 100 * g("COALITION") / nonex,
    OTH_nonex = 100 * g("OTHER") / nonex)
}
per_seat <- function(sub) sub[, flow(.SD), by = .(election, seat)]
pool <- function(sub, label) {
  ps <- per_seat(sub); p <- flow(sub); n <- nrow(ps)
  # SE of a pooled ratio across seats (ratio estimator, the seat as the independent unit)
  se <- function(nu, de) { r <- sum(nu) / sum(de); sqrt(sum((nu - r * de)^2) * n / (n - 1)) / sum(de) * 100 }
  p[, `:=`(label = label, seats = n,
           SE_ALP_all = if (n > 1) se(ps$ALP, ps$dist) else NA_real_,
           SE_EXH_all = if (n > 1) se(ps$EXH, ps$dist) else NA_real_,
           SE_COAL_all = if (n > 1) se(ps$COAL, ps$dist) else NA_real_,
           SE_ALP_nonex = if (n > 1) se(ps$ALP, ps$dist - ps$EXH) else NA_real_,
           seat_min_EXH = min(ps$EXH_all), seat_max_EXH = max(ps$EXH_all),
           seat_min_ALPn = min(ps$ALP_nonex, na.rm = TRUE), seat_max_ALPn = max(ps$ALP_nonex, na.rm = TRUE))]
  p
}
r1 <- function(x) round(x, 1)
options(width = 230, datatable.print.nrows = 300)

# ===== 1. ONE NATION =========================================================
cat("\n===== ONP: every exclusion of a One Nation candidate =====\n")
for (el in c("nsw2023", "nsw2019")) {
  o <- res[exc_code %in% ONE_NATION & election == el]
  cat(sprintf("\n-- %s: ONP excluded in %d seats (%d exclusions)\n", el, uniqueN(o$seat), uniqueN(o[, paste(seat, k)])))
  ps <- per_seat(o)
  rem <- o[to_code != "EXHAUSTED", .(recipients = paste(sort(unique(to_code)), collapse = "+")), by = .(election, seat)]
  fl <- o[, .(final_two = any(last_excl), n_remaining = min(n_remaining)), by = .(election, seat)]
  ps <- merge(merge(ps, rem, by = c("election", "seat"), all.x = TRUE), fl, by = c("election", "seat"))
  print(ps[order(seat), .(seat, dist, ALP_all = r1(ALP_all), COAL_all = r1(COAL_all), OTH_all = r1(OTH_all),
                          EXH_all = r1(EXH_all), ALP_nonex = r1(ALP_nonex), n_remaining, recipients, final_two)])
}
cat("\n===== ONP POOLED (sum of votes; SE = across seats) =====\n")
pl <- list()
for (el in c("nsw2023", "nsw2019")) {
  o <- res[exc_code %in% ONE_NATION & election == el]
  pl[[length(pl) + 1L]] <- pool(o, paste(el, "ONP all exclusions"))
  pl[[length(pl) + 1L]] <- pool(o[last_excl == TRUE], paste(el, "ONP final-two exclusions"))
  pl[[length(pl) + 1L]] <- pool(o[last_excl == FALSE], paste(el, "ONP excluded with others left"))
}
o2 <- res[exc_code %in% ONE_NATION]
pl[[length(pl) + 1L]] <- pool(o2, "2019+2023 ONP all exclusions")
pl[[length(pl) + 1L]] <- pool(o2[last_excl == TRUE], "2019+2023 ONP final-two")
pp <- rbindlist(pl, fill = TRUE)
print(pp[, .(label, seats, dist, ALP_all = r1(ALP_all), COAL_all = r1(COAL_all), OTH_all = r1(OTH_all),
             EXH_all = r1(EXH_all), SE_ALP_all = r1(SE_ALP_all), SE_COAL_all = r1(SE_COAL_all), SE_EXH_all = r1(SE_EXH_all))])
print(pp[, .(label, ALP_nonex = r1(ALP_nonex), COAL_nonex = r1(COAL_nonex), OTH_nonex = r1(OTH_nonex),
             SE_ALP_nonex = r1(SE_ALP_nonex), seat_min_ALPn = r1(seat_min_ALPn), seat_max_ALPn = r1(seat_max_ALPn),
             seat_min_EXH = r1(seat_min_EXH), seat_max_EXH = r1(seat_max_EXH))])

cat("\n-- ONP exclusions where the other recipients are only ALP/Coalition (no 'other' candidate received any) --\n")
oo <- res[exc_code %in% ONE_NATION][, only_major := all(to_grp %in% c("ALP", "COALITION", "EXHAUSTED")), by = .(election, seat, k)]
for (el in c("nsw2023", "nsw2019"))
  print(pool(oo[only_major == TRUE & election == el], paste(el, "ONP, only ALP/Coalition recipients"))[,
        .(label, seats, dist, ALP_all = r1(ALP_all), COAL_all = r1(COAL_all), EXH_all = r1(EXH_all), ALP_nonex = r1(ALP_nonex))])

cat("\nONP candidates standing and first-preference votes (first-preference workbooks):\n")
for (y in c(2019, 2023)) {
  on <- fpz[year == y & code %in% ONE_NATION]
  cat(sprintf("  %d: ONP stood in %d seats, %s first-pref votes; ONP excluded in DOP in %d of them\n", y,
              uniqueN(on$seat), format(sum(on$votes), big.mark = ","),
              uniqueN(res[election == paste0("nsw", y) & exc_code %in% ONE_NATION, seat])))
  cat("      ONP candidates NOT excluded (elected or one of final two):",
      paste(setdiff(on$seat, res[election == paste0("nsw", y) & exc_code %in% ONE_NATION, seat]), collapse = ", "), "\n")
}
# first-preference votes of the ONP candidates actually excluded, to size the distributed pile
cat("\nONP votes distributed (includes transfers received) vs ONP first preferences, 2023 and 2019:\n")
for (y in c(2019, 2023)) {
  o <- unique(res[exc_code %in% ONE_NATION & election == paste0("nsw", y), .(seat, k, total_distributed)])
  cat(sprintf("  %d: distributed %s across %d exclusions\n", y, format(sum(o$total_distributed), big.mark = ","), nrow(o)))
}

# ===== 2. GREENS =============================================================
cat("\n===== GREENS 2023: candidate definitions =====\n")
g <- res[election == "nsw2023" & exc_code == "GRN"]
gseats <- unique(g$seat)
g_fp <- fpz[year == 2023 & code == "GRN"]
cat(sprintf("Greens 2023: stood in %d seats (%s first-pref votes); excluded in DOP in %d seats (%d exclusions)\n",
            uniqueN(g_fp$seat), format(sum(g_fp$votes), big.mark = ","), length(gseats), uniqueN(g[, paste(seat, k)])))
# is a Greens candidate ever the LAST excluded (two left) or among the final two?
cat(sprintf("Greens 2023: final-two exclusions %d; excluded as first exclusion in seat (k=1) %d\n",
            uniqueN(g[last_excl == TRUE, paste(seat, k)]), uniqueN(g[k == 1, paste(seat)])))
defs <- list(
  "A all GRN exclusions, all seats" = g,
  "B GRN final-two exclusion only" = g[last_excl == TRUE],
  "D GRN exclusions that were not final-two" = g[last_excl == FALSE],
  "E GRN final-two, finalists exactly ALP and Coalition" = g[last_excl == TRUE][, if (!any(to_grp == "OTHER")) .SD, by = .(seat, k)]
)
gp <- rbindlist(lapply(names(defs), function(n) pool(defs[[n]], n)), fill = TRUE)
print(gp[, .(label, seats, dist, ALP_all = r1(ALP_all), COAL_all = r1(COAL_all), OTH_all = r1(OTH_all), EXH_all = r1(EXH_all),
             ALP_nonex = r1(ALP_nonex), SE_ALP = r1(SE_ALP_all), SE_EXH = r1(SE_EXH_all))])

cat("\nGreens 2023 FIRST-PREFERENCE ballots only (the votes the candidate held at count 1), apportioned by the share of the pile that flowed:\n")
cat("  (a pile at exclusion also holds transfers received from earlier exclusions; DOP does not split them)\n")
gx <- unique(g[, .(seat, k, total_distributed)])
gx <- merge(gx, g_fp[, .(seat, fp = votes)], by = "seat", all.x = TRUE)
cat(sprintf("  Greens pile distributed %s vs Greens first prefs in those seats %s (ratio %.3f); seats with an unmatched name: %d\n",
            format(sum(gx$total_distributed), big.mark = ","), format(sum(gx$fp, na.rm = TRUE), big.mark = ","),
            sum(gx$total_distributed) / sum(gx$fp, na.rm = TRUE), sum(is.na(gx$fp))))

cat("\nGreens 2023 per-seat exhaustion distribution (percent of distributed):\n")
psg <- per_seat(g); print(summary(psg$EXH_all)); print(sd(psg$EXH_all))
cat("Mean of seat shares (NOT the pooled figure):\n")
print(psg[, .(mean_ALP = r1(mean(ALP_all)), mean_COAL = r1(mean(COAL_all)), mean_EXH = r1(mean(EXH_all)))])
cat("\nGreens 2023 by seat region proxies: seats where Greens excluded with a Coalition candidate left vs not\n")
print(g[, .(has_coal = any(to_grp == "COALITION"), has_alp = any(to_grp == "ALP"), n_rem = min(n_remaining)), by = .(seat, k)][, .N, by = .(has_alp, has_coal)])

# other orderings Antony could have used: Greens ballots across ALL 93 seats where Greens stood
# (each seat's GRN pile is what it is; seat set = where a Greens candidate was excluded)
cat("\nGreens 2019 for the anchor's 2019 value:\n")
g19 <- res[election == "nsw2019" & exc_code == "GRN"]
cat("Greens final-two only, 2019 and 2023, mean of seat shares vs pooled:
")
for (el in c("nsw2019", "nsw2023")) { gb <- res[election == el & exc_code == "GRN" & last_excl == TRUE]; pb <- per_seat(gb)
  cat(sprintf("  %s: %d seats; pooled ALP %.1f COAL %.1f EXH %.1f; mean of seats ALP %.1f COAL %.1f EXH %.1f
", el, nrow(pb),
      100*sum(pb$ALP)/sum(pb$dist), 100*sum(pb$COAL)/sum(pb$dist), 100*sum(pb$EXH)/sum(pb$dist), mean(pb$ALP_all), mean(pb$COAL_all), mean(pb$EXH_all))) }
print(pool(g19, "nsw2019 GRN all exclusions")[, .(label, seats, dist, ALP_all = r1(ALP_all), COAL_all = r1(COAL_all),
        OTH_all = r1(OTH_all), EXH_all = r1(EXH_all), ALP_nonex = r1(ALP_nonex))])

# ===== 3. OTHER excluded parties, 2023, for the anchor's OTH row ============
cat("\n===== 2023 and 2019: all excluded groups (context for the anchor OTH row) =====\n")
res[, exc_grp := fifelse(exc_code %in% c("ON", "PHON", "GRN", "SFF"), exc_code, fifelse(exc_code %in% c(LABOR, "LIB", "NAT"), "MAJOR", "OTH"))]
og <- rbindlist(lapply(c("nsw2019", "nsw2023"), function(el) rbindlist(lapply(c("ON", "PHON", "GRN", "SFF", "OTH", "MAJOR"), function(gg) {
  s <- res[election == el & exc_grp == gg]; if (!nrow(s)) return(NULL); pool(s, paste(el, gg))
}), fill = TRUE)), fill = TRUE)
print(og[, .(label, seats, dist, ALP_all = r1(ALP_all), COAL_all = r1(COAL_all), OTH_all = r1(OTH_all), EXH_all = r1(EXH_all), ALP_nonex = r1(ALP_nonex))])

# ===== 4. FINAL DESTINATION of a party's first-preference ballots ===============
# A DOP page only shows where an excluded candidate's whole pile goes at that
# step; some goes to a candidate who is excluded later. Antony Green's figures
# sum to 100 with no "other", so they look like final destinations. Under the
# assumption that each candidate's pile is mixed (a ballot that arrived via a
# transfer behaves like every other ballot in that pile), the party's own first
# preferences can be followed to the end. THIS IS A MODEL, not a measurement:
# the real routing needs ballot-level data we do not hold.
trace <- function(el, codes_src) {
  rr <- res[election == el]
  fpt <- cand_fp[election == el]
  out <- list()
  for (st in unique(rr$seat)) {
    d <- rr[seat == st]
    labs <- fpt[seat == st, label]
    src <- unique(d[exc_code %in% codes_src, ex_label])      # source candidates that were excluded
    selfc <- setdiff(labs[vapply(labs, function(l) code_of(l) %in% codes_src, TRUE)], src)  # source candidates never excluded
    start <- c(setNames(fpt[seat == st & label %in% c(src, selfc), fp], fpt[seat == st & label %in% c(src, selfc), label]))
    if (!length(src)) next        # source party reached the final two (or was elected): nothing distributed
    start <- start[names(start) %in% src]
    content <- setNames(rep(0, length(labs)), labs); content[names(start)] <- start; exh <- 0
    for (kk in sort(unique(d$k))) {
      mask <- d$k == kk   # computed outside the brackets: a bare `k` inside d[...] is the column
      dk <- d[mask]; X <- dk$ex_label[1]; cx <- content[[X]]
      if (cx > 0) {
        tot <- sum(dk$votes)
        for (j in seq_len(nrow(dk))) {
          if (dk$to_label[j] == "EXHAUSTED") exh <- exh + cx * dk$votes[j] / tot
          else content[[dk$to_label[j]]] <- content[[dk$to_label[j]]] + cx * dk$votes[j] / tot
        }
        content[[X]] <- 0
      }
    }
    grp <- vapply(names(content), function(l) { cc <- code_of(l); if (cc %in% LABOR) "ALP" else if (cc %in% c("LIB", "NAT")) "COALITION" else "OTHER" }, "")
    out[[length(out) + 1L]] <- data.table(election = el, seat = st, fp = sum(start),
      ALP = sum(content[grp == "ALP"]), COAL = sum(content[grp == "COALITION"]),
      OTH = sum(content[grp == "OTHER"]), EXH = exh)
    stopifnot(abs(out[[length(out)]][, ALP + COAL + OTH + EXH - fp]) < 1e-6 * sum(start) + 1e-6)
  }
  rbindlist(out)
}
tsum <- function(t, label) {
  n <- nrow(t); tot <- sum(t$fp); ne <- tot - sum(t$EXH)
  se <- function(nu, de) { r <- sum(nu) / sum(de); sqrt(sum((nu - r * de)^2) * n / (n - 1)) / sum(de) * 100 }
  data.table(label = label, seats = n, ballots = round(tot), ALP = r1(100 * sum(t$ALP) / tot), COAL = r1(100 * sum(t$COAL) / tot),
             OTH = r1(100 * sum(t$OTH) / tot), EXH = r1(100 * sum(t$EXH) / tot), SE_ALP = r1(se(t$ALP, t$fp)), SE_EXH = r1(se(t$EXH, t$fp)),
             ALP_nonex = r1(100 * sum(t$ALP) / ne), COAL_nonex = r1(100 * sum(t$COAL) / ne), OTH_nonex = r1(100 * sum(t$OTH) / ne))
}
cat("
===== FINAL DESTINATION of first-preference ballots (proportional-mixing model) =====
")
tr <- list(
  tsum(trace("nsw2023", "GRN"), "nsw2023 Greens"),
  tsum(trace("nsw2023", "ON"), "nsw2023 ONP"),
  tsum(trace("nsw2019", "GRN"), "nsw2019 Greens"),
  tsum(trace("nsw2019", "PHON"), "nsw2019 ONP"))
print(rbindlist(tr))
cat("
ONP traced per seat 2023:
")
print(trace("nsw2023", "ON")[order(seat), .(seat, fp, ALP = r1(100 * ALP / fp), COAL = r1(100 * COAL / fp), OTH = r1(100 * OTH / fp), EXH = r1(100 * EXH / fp))])
cat("
ONP excluded count k (1 = excluded first, so the pile is pure first preferences) 2023 / 2019:
")
print(unique(res[exc_code %in% ONE_NATION, .(election, seat, k, total_distributed)])[order(election, k)][, .(election, seat, k, pile = total_distributed)])

# ===== 5. The anchor's convention: ALP share of (ALP + Coalition) ==============
# preference-estimates.csv stores "flow to ALP" and an exhaust rate, and the
# remainder of the non-exhausted share goes to the Coalition; there is no
# "other" bucket. So the like-for-like measured flow is ALP / (ALP + Coalition).
cat("
===== ONP: ALP share of (ALP + Coalition), the anchor's 'flow to ALP' convention =====
")
two <- function(sub, label) {
  ps <- per_seat(sub); n <- nrow(ps); r <- sum(ps$ALP) / sum(ps$ALP + ps$COAL)
  se <- sqrt(sum((ps$ALP - r * (ps$ALP + ps$COAL))^2) * n / (n - 1)) / sum(ps$ALP + ps$COAL) * 100
  sr <- 100 * ps$ALP / (ps$ALP + ps$COAL)
  data.table(label = label, seats = n, pooled = r1(100 * r), SE = r1(se), seat_min = r1(min(sr)), seat_median = r1(median(sr)), seat_max = r1(max(sr)),
             seat_sd = r1(sd(sr)))
}
oq <- res[exc_code %in% ONE_NATION]
print(rbindlist(list(
  two(oq[election == "nsw2023"], "nsw2023 ONP all exclusions"),
  two(oq[election == "nsw2023" & last_excl == TRUE], "nsw2023 ONP final-two"),
  two(oq[election == "nsw2019"], "nsw2019 ONP all exclusions"),
  two(oq[election == "nsw2019" & last_excl == TRUE], "nsw2019 ONP final-two"),
  two(oq, "2019+2023 ONP all exclusions"),
  two(oq[last_excl == TRUE], "2019+2023 ONP final-two"))))
cat("
Anchor 2027 ONP row, converted to shares of ALL ballots: ALP", 25.5 * 0.43, " Coalition", 74.5 * 0.43, " Exhausted 57.0
")
cat("Antony Green 2023 ONP, on the anchor's basis: ALP/(ALP+Coalition) =", round(100 * 11.7 / (11.7 + 26.1), 1),
    "; ALP of non-exhausted =", round(100 * 11.7 / 37.8, 1), "
")

# seats whose own ONP Labor/(Labor+Coalition) is at or below the anchor's 25.5
sr_all <- per_seat(oq)[, .(election, seat, r = 100 * ALP / (ALP + COAL))]
cat(sprintf("\nONP exclusions with seat Labor/(Labor+Coalition) <= 25.5: %d of %d (2023: %d of %d; 2019: %d of %d)\n",
            sum(sr_all$r <= 25.5), nrow(sr_all), sum(sr_all$r <= 25.5 & sr_all$election == "nsw2023"), sum(sr_all$election == "nsw2023"),
            sum(sr_all$r <= 25.5 & sr_all$election == "nsw2019"), sum(sr_all$election == "nsw2019")))
print(sr_all[r <= 25.5][order(r)][, .(election, seat, r = r1(r))])
