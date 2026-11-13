# Walk of paid (stakeholder) seat polls against seat results: the sponsor side's share in the poll minus its result,
# primary (polls naming ALP, LNP and GRN, scaled to 100) else two-candidate (federal AEC counts), net of independent
# direct seat polls of the same election and side. Read-only; prints tables. docs/reviews/seat-poll-paid-lean-walk-2026-11-14.md
#   powershell.exe -Command 'Rscript "scripts/walk_paid_seat_polls.R"'
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE)); suppressMessages(library(data.table))
source("scripts/published_flags.R")
for (k in names(PUBLISHED_FLAGS)) if (Sys.getenv(k) == "") do.call(Sys.setenv, setNames(list(PUBLISHED_FLAGS[[k]]), k))
pm <- fread("external/reference/polls/seat-polls/poll_methods.csv", colClasses = list(character = "fieldwork_end"))
pm[, seat0 := sub(" [(].*$", "", seat)]
cand <- fread("output/candidacies.csv", select = c("election", "seat", "party", "votes"))
cand[, votes := as.numeric(votes)]
act <- cand[, .(v = sum(votes, na.rm = TRUE)), by = .(election, seat, party)]
act[, share := 100 * v / sum(v), by = .(election, seat)]
tcp <- fread("external/elections/aec-fed-tcp.csv"); tcp[, tshare := 100 * votes / sum(votes), by = .(election, seat)]
sp <- fread("external/reference/polls/seat-polls/seat_polls.csv", colClasses = "character")
mapp <- function(x) { x <- toupper(trimws(x)); ifelse(x %in% c("LIB", "LNP", "L/NP", "NAT", "LP", "NP", "COALITION"), "LNP", ifelse(grepl("IND", x), "IND", x)) }
rows <- list()
for (el in c("fed2016", "fed2019", "fed2022", "fed2025", "nsw2023")) {
  raw <- suppressMessages(seat_poll_shares(el, .raw = TRUE))
  if (!nrow(raw)) next
  raw <- raw[raw$group %in% c("direct_stake", "direct_indep")]
  key <- unique(raw[, .(poll_id, seat, .seat0, .pollster, .fw, group, days)])
  key <- merge(key, unique(pm[pm$election == el, .(seat0, pollster, fieldwork_end, sponsor_name)], by = c("seat0", "pollster", "fieldwork_end")),
               by.x = c(".seat0", ".pollster", ".fw"), by.y = c("seat0", "pollster", "fieldwork_end"), all.x = TRUE)
  for (j in seq_len(nrow(key))) {
    k <- key[j]; pid <- k$poll_id
    b <- raw[raw$poll_id == pid & is.finite(raw$fp)]
    b <- b[, .(fp = sum(fp)), by = "class"]
    a <- act[act$election == el & act$seat == k$seat]
    complete <- all(c("ALP", "LNP", "GRN") %in% b$class)
    named <- sum(b$fp)
    b[, fps := 100 * fp / named]
    side <- if (k$group == "direct_stake") paid_poll_side(k$sponsor_name) else NA_character_
    spp <- if (!is.na(side)) .ppc_side_parties(side, b$class) else character(0)
    if (!is.na(side) && side == "IND" && !"IND" %in% b$class) spp <- character(0)   # IND side, no IND figure: not measurable
    pg <- if (complete && length(spp)) sum(b$fps[b$class %in% spp]) - sum(a$share[a$party %in% spp]) else NA_real_
    e <- merge(b[, .(class, fps)], a[, .(class = party, share)], by = "class")
    t <- sp[sp$election == el & sp$seat_name == k$.seat0 & sp$pollster == k$.pollster & sp$fieldwork_end == k$.fw & nzchar(sp$tcp_a)][1]
    tg <- NA_real_; tpair <- NA_character_
    if (nrow(t) && !is.na(t$tcp_a) && grepl("^fed", el)) {
      pa <- mapp(t$tcp_party_a); pb <- mapp(t$tcp_party_b); tpair <- paste(pa, pb, sep = " v ")
      at <- tcp[tcp$election == el & tcp$seat == k$seat]
      if (setequal(c(pa, pb), at$party)) {
        if (!is.na(side)) { s2 <- .ppc_side_parties(side, c(pa, pb))
          if (length(s2) == 1L) tg <- (if (s2 == pa) as.numeric(t$tcp_a) else 100 - as.numeric(t$tcp_a)) - at$tshare[at$party == s2]
        } else tg <- as.numeric(t$tcp_a) - at$tshare[at$party == pa]
      }
    }
    rows[[length(rows) + 1]] <- data.table(el = el, seat = k$seat, pollster = k$.pollster, group = k$group, sponsor = k$sponsor_name,
      side = side, on = paste(spp, collapse = "+"), complete = complete, named = named, prim_gap = pg, tcp_pair = tpair,
      tcp_gap = tg, days = k$days, sq_err = if (complete && nrow(e)) mean((e$fps - e$share)^2) else NA_real_)
  }
}
w <- rbindlist(rows)
fwrite(w, file.path(tempdir(), "sp_walk3.csv"))
st <- w[group == "direct_stake"]
cat(sprintf("seat polls direct: %d (paid %d, independent %d); paid with a primary gap %d, with a TCP gap %d\n",
            nrow(w), nrow(st), sum(w$group == "direct_indep"), sum(is.finite(st$prim_gap)), sum(is.finite(st$tcp_gap))))
print(st[order(side, el, seat), .(el, seat, pollster = substr(pollster, 1, 12), sponsor = substr(sponsor, 1, 24), side, on,
         named = round(named), prim_gap = round(prim_gap, 1), tcp_gap = round(tcp_gap, 1), days)], nrows = 80)
ind <- w[group == "direct_indep"]
cat(sprintf("\nIndependent direct polls: rms primary error per party %.2f points (n polls %d); TCP error mean %+.2f, rms %.2f (n %d)\n",
            sqrt(mean(ind$sq_err, na.rm = TRUE)), sum(is.finite(ind$sq_err)), mean(ind$tcp_gap, na.rm = TRUE),
            sqrt(mean(ind$tcp_gap^2, na.rm = TRUE)), sum(is.finite(ind$tcp_gap))))

# same side measured on INDEPENDENT direct polls of the same election (complete polls only)
base_rows <- list()
for (el in unique(w$el)) {
  raw <- suppressMessages(seat_poll_shares(el, .raw = TRUE)); raw <- raw[raw$group == "direct_indep" & is.finite(raw$fp)]
  for (pid in unique(raw$poll_id)) {
    b <- raw[raw$poll_id == pid, .(fp = sum(fp)), by = "class"]; if (!all(c("ALP", "LNP", "GRN") %in% b$class)) next
    b[, fps := 100 * fp / sum(fp)]; s <- raw[raw$poll_id == pid]$seat[1]
    a <- act[act$election == el & act$seat == s]
    for (sd_ in c("ALP", "ALP+GRN", "GRN", "LNP", "IND")) {
      spp <- .ppc_side_parties(sd_, b$class); if (sd_ == "IND" && !"IND" %in% b$class) next
      if (length(spp)) base_rows[[length(base_rows) + 1]] <- data.table(el = el, side = sd_, g = sum(b$fps[b$class %in% spp]) - sum(a$share[a$party %in% spp]))
    }
  }
}
bs <- rbindlist(base_rows)
cat("\nINDEPENDENT seat polls, same side measure (poll share of the side minus its result, points; positive = poll overstated it):\n")
print(bs[, .(n = .N, mean = round(mean(g), 2), se = round(sd(g) / sqrt(.N), 2)), by = .(el, side)][order(side, el)])
st[, meas := ifelse(is.finite(prim_gap), prim_gap, tcp_gap)]
st2 <- merge(st[is.finite(meas)], bs[, .(base = mean(g)), by = .(el, side)], by = c("el", "side"), all.x = TRUE)
st2[, net := meas - base]
cat("\nPAID polls net of independent polls (same election, same side), points:\n")
print(st2[, .(n = .N, raw = round(mean(meas), 2), base = round(mean(base, na.rm = TRUE), 2), net = round(mean(net, na.rm = TRUE), 2), n_net = sum(is.finite(net))), by = side])
cat(sprintf("ALL: n %d, net mean %+.2f, SE %.2f, positive %d of %d\n", sum(is.finite(st2$net)), mean(st2$net, na.rm = TRUE),
            sd(st2$net, na.rm = TRUE) / sqrt(sum(is.finite(st2$net))), sum(st2$net > 0, na.rm = TRUE), sum(is.finite(st2$net))))
