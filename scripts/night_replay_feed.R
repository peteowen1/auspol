# REAL-NIGHT REPLAY from the AEC's archived election-night feed (review 2026-10-30: the fraction replay's order and
# clock were simulated). At each clock time T, the night model sees exactly the polling places the AEC had published
# first preferences for by T (output/night-feed/booth-returns-fed<year>.csv, scripts/parse_aec_mediafeed.py), and the
# two-candidate counts of those places only where the pair on screen at T was the final pair and not withdrawn.
#
#   Rscript scripts/night_replay_feed.R --state=<state-fed2022.rds> [--out=<dir>] [--times=18:00,...] [--surge-fade=1]
#       [--tcp-center=median] [--tcp-flow-floor=0.01] [--label=base] [--resume=1] [--stop-after=<n steps, testing>]
# Every step rewrites <out>/<night>-<label>-*.partial.csv; --resume=1 picks up a killed run (night_replay_checkpoint.R).
#
# Simplifications (say them in every result): a reported place carries its FINAL count, not its first-night figure;
# declaration votes (postal, absent, provisional, declaration pre-poll) are never counted on the night here (the AEC
# counted some postals on the night); the 11 fed2022 seats whose pair was withdrawn get no two-candidate count until
# the replacement appears; a two-candidate count is used only when the pair on screen equals the DECLARED final pair
# (names compared case-folded) and is not flagged maverick at that snapshot (known only at the end of the night: it
# can withhold a count, never supply one, because the booth 2CP file holds the final pair's counts only -- review
# 2026-10-30; compared with the declared pair, not the feed's last one, since 11 Nov). Times are Canberra time (AEST), the feed's own clock.
# Writes <out>/<label>-summary.csv (one row per time) and <out>/<label>-seats.csv (seat x time x party probability).
# Check codes NRF1-NRF4.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
st <- readRDS(flag("state")); yr <- st$to; pair_lbl <- sprintf("fed%d", yr)
out_dir <- flag("out", file.path("output", "night-feed", "replay")); dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
label <- flag("label", "base")
# defaults = the live runner's since 2026-10-31; the as-shipped-before arm is --surge-fade=0 --tcp-center=mean --tcp-flow-floor=0.01
surge_fade <- !identical(flag("surge-fade", "1"), "0"); tcp_center <- flag("tcp-center", "median")
tcp_floor <- as.numeric(flag("tcp-flow-floor", "0.01")); own_fp <- identical(flag("tcp-own-fp", "0"), "1")
pair_r <- flag("pair-r", NULL); if (!is.null(pair_r)) pair_r <- as.numeric(pair_r)   # prereg-night-pair-trust-2026-11-11
cand_ref <- local({ v <- flag("cand-ref", "0"); if (v == "1") TRUE else if (v %in% c("move", "copy")) v else if (v == "0") FALSE else stop("--cand-ref must be 0, 1, move or copy") })   # prereg-night-candidate-ref(-copy)-2026-11-11
cls_split_on <- identical(flag("class-split", "0"), "1")   # prereg-night-class-split-2026-11-14
cls_split <- if (cls_split_on) night_class_split_params(pair_lbl) else NULL
if (cls_split_on) cat(sprintf("NRCS night class split: %s\n", if (is.null(cls_split)) "NO parameters (class_split_fit gave none): off" else sprintf("sd0 %.3f, f %s", cls_split$sd0, paste(names(cls_split$f), sprintf("%.3f", cls_split$f), collapse = " "))))
pair_cal <- flag("pair-cal", NULL); if (!is.null(pair_cal)) pair_cal <- as.numeric(strsplit(pair_cal, ",")[[1]])   # c(alpha,beta), prereg-night-pair-cal-2026-11-11
day <- as.Date(c(`2022` = "2022-05-21", `2025` = "2025-05-03")[[as.character(yr)]])
tm <- strsplit(flag("times", paste(c(sprintf("%02d:%02d", rep(18:23, each = 4), c(0, 15, 30, 45)), "24:00", "25:00", "26:00", "27:00"), collapse = ",")), ",")[[1]]
at <- vapply(tm, function(x) { p <- as.integer(strsplit(x, ":")[[1]]); as.numeric(as.POSIXct(day, tz = "UTC") + p[1] * 3600 + p[2] * 60) }, numeric(1))

L  <- fread(sprintf("output/booths-fed%d.csv", yr)); R <- fread(sprintf("output/booths-fed%d.csv", st$from))
Tc <- fread(sprintf("output/booths/fed%d-booth-tcp.csv", yr))
B  <- fread(sprintf("output/night-feed/booth-returns-fed%d.csv", yr))
D  <- fread(sprintf("output/night-feed/division-progress-fed%d.csv", yr))
P  <- fread("output/published-predictions.csv"); keep_p <- P$pair == pair_lbl; P <- P[keep_p]
win <- P[P$won == TRUE, list(seat, party)]
seats <- rownames(st$shares)
tsec <- function(x) as.numeric(as.POSIXct(x, tz = "UTC"))
B[, t_fp := tsec(ifelse(!is.na(fp_exact) & fp_exact_flag == 1, fp_exact, fp_first_seen))]
B[, t_tcp := tsec(tcp_first_seen)]
pp <- B[!grepl("^declaration", classification) & !is.na(t_fp)]
cat(sprintf("NRF1 %s: %d seats in state, %d places with a night return, %d places in the booth table; %d sims; label %s (surge-fade %s, tcp-center %s, tcp-flow-floor %s)\n",
            pair_lbl, length(seats), nrow(pp), nrow(L[L$booth_type == "ordinary", list(1), by = list(district, booth)]), nrow(st$swd),
            label, surge_fade, tcp_center, tcp_floor)); cat(sprintf("NRF1 tcp-own-fp %s, cand-ref %s, pair-r %s, pair-cal %s\n", own_fp, cand_ref, if (is.null(pair_r)) "off" else format(pair_r), if (is.null(pair_cal)) "off" else paste(format(pair_cal), collapse = ",")))
miss <- setdiff(unique(pp$division), seats); if (length(miss)) cat("NRF1 feed divisions not in the state:", paste(miss, collapse = ", "), "\n")

# The pair on screen per division per snapshot. Usable while it is on screen and not flagged maverick AT THAT
# SNAPSHOT, and only when it is the DECLARED final pair: the booth two-candidate votes (Tc) exist for that pair
# alone, so a night pair the commission got wrong cannot be replayed (a data limit, not a model choice).
# Until 11 Nov this compared with the feed's LAST snapshot instead. A pair the AEC flagged maverick and blanked
# later in the night then counted as "never usable", so Monash fed2025 (Labor v Liberal on screen 6:01-8:37pm,
# the declared pair) lost its count all night, as did 15 of 151 fed2022 and 21 of 150 fed2025 divisions.
D[, ts := tsec(snapshot_time)]
# Names are compared case-folded: the feed writes "Van MANEN, Bert" and "McEWEN", the booth file "VAN MANEN, Bert"
# and "MCEWEN". Until 14 Nov a case-only difference read as a wrong pair, so 8 divisions a night (fed2022: Dobell,
# Eden-Monaro, Flinders, Lindsay, Riverina, Shortland, Swan, Wright; fed2025: Dobell, Eden-Monaro, Fairfax, Forde,
# Lindsay, McEwen, Riverina, Wright) never had their two-candidate count used (found tracing Forde, class split).
pair_key <- function(x) vapply(strsplit(ifelse(is.na(x), "", x), " v ", fixed = TRUE), function(z) paste(sort(toupper(trimws(z))), collapse = " v "), "")
pair_key_cs <- function(x) vapply(strsplit(ifelse(is.na(x), "", x), " v ", fixed = TRUE), function(z) paste(sort(trimws(z)), collapse = " v "), "")
dec <- Tc[, list(dec_pair = paste(sort(unique(toupper(trimws(candidate)))), collapse = " v "),
                 dec_pair_cs = paste(sort(unique(trimws(candidate))), collapse = " v ")), by = list(division = district)]
D <- merge(D, dec, by = "division", all.x = TRUE)
dec_cls <- unique(Tc[, list(division = district, candidate, cls = classify_party(party_raw))])[,
  list(dec_cls = paste(sort(cls), collapse = "|"), n_cand = .N), by = division]
if (any(dec_cls$n_cand != 2L)) stop("NRF5! declared pair without exactly 2 candidates: ", paste(dec_cls$division[dec_cls$n_cand != 2L], collapse = ", "))
D[, night_key := pair_key(tcp_pair)]
D[, pair_ok := nzchar(night_key) & !is.na(dec_pair) & night_key == dec_pair & !(tolower(as.character(tcp_maverick)) %in% "true")]
pk <- D[nzchar(night_key), list(ever_shown = TRUE, ever_ok = any(pair_ok)), by = division]
cs_only <- unique(D$division[D$pair_ok & pair_key_cs(D$tcp_pair) != D$dec_pair_cs])
cat(sprintf("NRF0 %s: %d divisions showed a pair; %d usable at some point; %d never (pair not the declared one); %d matched only once case is ignored%s\n",
            pair_lbl, nrow(pk), sum(pk$ever_ok), sum(!pk$ever_ok), length(cs_only),
            if (length(cs_only)) paste0(" (", paste(sort(cs_only), collapse = ", "), ")") else ""))
if (!sum(pk$ever_ok)) stop("NRF0! no division's night pair matched its declared pair: check the name formats in Tc and the feed")

source("scripts/night_replay_checkpoint.R")   # per-step partial files; --resume=1 skips the times already done
ck_prefix <- sprintf("%s-%s", pair_lbl, label); ck_kinds <- c("summary", "seats", "tcp", "pairs")
ck <- ckpt_load(out_dir, ck_prefix, ck_kinds, resume = identical(flag("resume", "0"), "1"))
summ <- ck$rows$summary; seat_rows <- ck$rows$seats; tcp_rows_out <- ck$rows$tcp; pairs_out <- ck$rows$pairs
for (k in seq_along(at)) {
  if (tm[k] %in% ck$done) next
  T0 <- at[k]
  rep_pp <- pp[pp$t_fp <= T0, list(district = division, unit = polling_place)]
  if (!nrow(rep_pp)) { cat(sprintf("NRF2 %s: nothing reported yet\n", tm[k])); next }
  dk <- D[D$ts <= T0][order(ts)][, .SD[.N], by = division]
  ok_div <- dk$division[dk$pair_ok]
  tb <- pp[pp$t_tcp <= T0 & pp$division %in% ok_div, list(district = division, booth = polling_place)]
  tcp_rows <- merge(Tc, tb, by = c("district", "booth"))
  conv <- list(live = L, counted = rep_pp, tcp = tcp_rows)
  r <- night_run_update(st, conv, R, gap_k = 5, total = "projected", use_tcp = nrow(tcp_rows) > 0,
                        surge_fade = surge_fade, tcp_center = tcp_center, tcp_flow_floor = tcp_floor, tcp_own_fp = own_fp, tcp_pair_r = pair_r, tcp_pair_cal = pair_cal, cand_ref = cand_ref, class_split = cls_split)
  tot <- r$sim$totals; alp <- tot[, "ALP"]
  oth <- tot[, setdiff(colnames(tot), "ALP"), drop = FALSE]
  wp <- as.data.table(r$sim$win_prob)
  sc <- merge(win, wp, by = c("seat", "party"), all.x = TRUE); sc[is.na(prob), prob := 0]
  cnt <- r$nu$counted[seats]; cnt[is.na(cnt)] <- 0
  summ[[length(summ) + 1]] <- data.table(time = tm[k], places = nrow(rep_pp), seats_reporting = uniqueN(rep_pp$district),
    mean_counted = round(100 * mean(cnt), 1), tcp_seats = r$n_tcp,
    alp_exp = round(mean(alp), 2), alp_lo = unname(quantile(alp, 0.05)), alp_hi = unname(quantile(alp, 0.95)),
    p_alp_majority = round(mean(alp >= 76), 4), p_alp_largest = round(mean(alp > apply(oth, 1, max)), 4),
    log_loss = round(mean(-log(pmax(sc$prob, 1e-6))), 4), right = sum(sc$prob > 0.5), n = nrow(sc),
    wentworth_ind = round(sum(wp$prob[wp$seat == "Wentworth" & wp$party == "IND"]), 4),
    wentworth_counted = round(100 * unname(cnt["Wentworth"]), 1))
  wp[, time := tm[k]]; seat_rows[[length(seat_rows) + 1]] <- wp
  nt <- attr(r$sim, "night_tcp"); if (!is.null(nt) && nrow(nt)) tcp_rows_out[[length(tcp_rows_out) + 1]] <- data.table::as.data.table(nt)[, time := tm[k]]   # per-seat pair share, prior/posterior (pair_r v2 trace)
  # EVERY pair on screen (not maverick at this snapshot), right or wrong, at the same information level: its share
  # of the draws and whether it is the declared pair. The calibration data for pair_cal (prereg-night-pair-cal-
  # 2026-11-11). The feed's tcp*_party are commission CODES, so they go through classify_party(code =); the three
  # codes it does not know take the class of their full party name. (Review 11 Nov: passed as names they all fell
  # to OTH, so a wrong ALP v LP pair read as OTH v OTH with ~0 draws.)
  on_scr <- dk[nzchar(night_key) & !(tolower(as.character(tcp_maverick)) %in% "true") & division %in% colnames(r$sim$tcp_winner)]
  if (nrow(on_scr)) {
    full <- c(KAP = "Katter's Australian Party (KAP)", CLP = "Country Liberals (NT)", XEN = "Centre Alliance")
    cls_of <- function(cd) { cd <- ifelse(is.na(cd), "", trimws(cd))
      known <- c("", "ALP", "ALP1", "LP", "LNP", "NP", "LNQ", "NAT", "NATS", "LIB", "GRN", "GVIC", "TG", "ON", "PHON", "ONP", names(full))
      bad <- setdiff(unique(cd), known); if (length(bad)) stop("NRF5! feed party code(s) with no class: ", paste(bad, collapse = ", "))
      classify_party(ifelse(cd %in% names(full), full[cd], ""), code = ifelse(cd %in% names(full), "", cd)) }
    ca <- cls_of(on_scr$tcp1_party); cb <- cls_of(on_scr$tcp2_party)
    same <- ca == cb
    if (any(same)) cat(sprintf("NRF5 %s: %d on-screen pair(s) of one class, left out of the pairs file: %s\n", tm[k], sum(same),
                               paste(on_scr$division[same], collapse = ", ")))
    pw <- vapply(seq_len(nrow(on_scr)), function(i) { tw <- r$sim$tcp_winner[, on_scr$division[i]]; tr <- r$sim$tcp_runnerup[, on_scr$division[i]]
      mean((tw == ca[i] & tr == cb[i]) | (tw == cb[i] & tr == ca[i])) }, numeric(1))
    # declared = the model's question: is this the final two BY CLASS (Bendigo 2025 counted Labor v Liberal, final two
    # Labor v Nationals: both LNP, so right for the model). declared_cand keeps the candidate-level match.
    dcl <- dec_cls$dec_cls[match(on_scr$division, dec_cls$division)]
    pairs_out[[length(pairs_out) + 1]] <- data.table(seat = on_scr$division, a = ca, b = cb, pair_share = pw,
                                                     declared = !is.na(dcl) & paste(pmin(ca, cb), pmax(ca, cb), sep = "|") == dcl,
                                                     declared_cand = !is.na(on_scr$dec_pair) & on_scr$night_key == on_scr$dec_pair, time = tm[k])[!same]
  }
  s <- summ[[length(summ)]]
  cat(sprintf("NRF3 %s places %d (%d seats, mean counted %.1f%%, 2CP %d) | ALP %.1f (%g-%g) P(maj) %.3f | log loss %.4f, right %d/%d | Wentworth IND %.3f at %.1f%%\n",
              s$time, s$places, s$seats_reporting, s$mean_counted, s$tcp_seats, s$alp_exp, s$alp_lo, s$alp_hi, s$p_alp_majority,
              s$log_loss, s$right, s$n, s$wentworth_ind, s$wentworth_counted))
  ckpt_save(out_dir, ck_prefix, list(summary = summ, seats = seat_rows, tcp = tcp_rows_out, pairs = pairs_out))
  if (!is.null(flag("stop-after")) && length(summ) >= as.integer(flag("stop-after"))) { cat("NRF7 --stop-after reached: stopping with partial files only (a kill, for testing --resume)\n"); quit(save = "no", status = 0) }
}
S <- rbindlist(summ); fwrite(S, file.path(out_dir, sprintf("%s-%s-summary.csv", pair_lbl, label)))
fwrite(rbindlist(seat_rows), file.path(out_dir, sprintf("%s-%s-seats.csv", pair_lbl, label)))
if (length(tcp_rows_out)) fwrite(rbindlist(tcp_rows_out, fill = TRUE), file.path(out_dir, sprintf("%s-%s-tcp.csv", pair_lbl, label)))
if (length(pairs_out)) { PO <- rbindlist(pairs_out)
  cat(sprintf("NRF6 pairs file: %d rows, %d seats, %d wrong (not the declared pair); median share right %.3f, wrong %.3f\n", nrow(PO),
              uniqueN(PO$seat), PO[declared == FALSE, uniqueN(seat)], median(PO$pair_share[PO$declared]), median(PO$pair_share[!PO$declared])))
  fwrite(PO, file.path(out_dir, sprintf("%s-%s-pairs.csv", pair_lbl, label))) }
ckpt_clear(out_dir, ck_prefix, ck_kinds)
call_at <- function(p) { ok <- p >= 0.99; i <- which(vapply(seq_along(ok), function(j) all(ok[j:length(ok)]), logical(1))); if (length(i)) S$time[min(i)] else "never" }
cat(sprintf("NRF4 %s %s: Labor majority called (>= 0.99 and stays) at %s | Labor largest at %s | Wentworth IND at %s\n",
            pair_lbl, label, call_at(S$p_alp_majority), call_at(S$p_alp_largest), call_at(S$wentworth_ind)))
