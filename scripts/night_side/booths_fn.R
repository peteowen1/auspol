# BOOTH BY BOOTH for the live night (Pete via ITG, 28 Nov 2026, 6:55pm). build_booths(w, stamp) takes night_web_read()
# output and returns the document for auspol/night/booths-vic2026.json: every polling booth the VEC lists for a seat
# (counted or not) and one row per vote type, each with tonight's count, the matched reference (2022 results on tonight's
# districts), the swing, the booth's lean last time, and a SIMPLE projection (last time + the seat's swing so far on its
# matched counted booths). The simple projection is NOT the night model's per-booth guess. Plain data only; no model call.
BB_CLS <- c("ALP", "LNP", "GRN", "ONP", "IND", "OTH")
bb_lk <- function(x) gsub("[^a-z0-9]", "", tolower(x))
.bb_pc <- new.env()
bb_cls <- function(p) { u <- unique(p); m <- vapply(u, function(x) { k <- paste0("p:", x); if (is.null(.bb_pc[[k]])) .bb_pc[[k]] <- classify_party(x); .bb_pc[[k]] }, character(1), USE.NAMES = FALSE)
  o <- m[match(p, u)]; o[!o %in% BB_CLS] <- "OTH"; o }
bb_ref <- local({ R <- NULL; function() { if (is.null(R)) {
  f <- data.table::fread("output/booths-vic2026-ref.csv", encoding = "UTF-8")[booth_type != "marked_as_voted"]
  f[, `:=`(cls = bb_cls(party), dk = bb_lk(district), uk = ifelse(booth_type == "ordinary", bb_lk(booth), booth_type))]
  t2 <- tryCatch(data.table::fread("output/booths-vic2026-ref-2cp.csv", encoding = "UTF-8")[booth_type != "marked_as_voted"], error = function(e) NULL)
  if (!is.null(t2)) t2[, `:=`(cls = bb_cls(party), dk = bb_lk(district), uk = ifelse(booth_type == "ordinary", bb_lk(booth), booth_type))]
  pl <- tryCatch(data.table::fread("external/reference/vec/2026/voting-locations/places-2026.csv", encoding = "UTF-8"), error = function(e) NULL)
  if (!is.null(pl)) pl <- pl[, .(dk = bb_lk(district), uk = bb_lk(booth), name = booth, est = suppressWarnings(as.numeric(gsub(",", "", `Est. Ord Votes`))))]
  R <<- list(fp = f[, .(v = sum(votes)), by = .(dk, uk, cls)], tcp = if (is.null(t2)) NULL else t2[, .(v = sum(votes)), by = .(dk, uk, cls)],
             names = unique(f[booth_type == "ordinary", .(dk, uk, name = booth)], by = c("dk", "uk")), places = pl) }
  R } })
bb_wide <- function(D) {   # D: dk, uk, cls, v  ->  one row per dk, uk with a total and the six class percentages
  if (is.null(D) || !nrow(D)) return(NULL)
  W <- data.table::dcast(D, dk + uk ~ cls, value.var = "v", fun.aggregate = sum, fill = 0)
  for (c0 in setdiff(BB_CLS, names(W))) W[, (c0) := 0]
  W[, tot := rowSums(.SD), .SDcols = BB_CLS]; W }
bb_pct <- function(W, i) if (is.na(i) || W$tot[i] <= 0) NULL else round(100 * unlist(W[i, BB_CLS, with = FALSE], use.names = FALSE) / W$tot[i], 1)
bb_pair <- function(T2, dk0, uk0) {   # the two classes and a's share at one unit, a = alphabetically first class (stable across booths)
  x <- T2[dk == dk0 & uk == uk0 & v > 0]; if (nrow(x) < 1 || sum(x$v) <= 0) return(NULL)
  x <- x[, .(v = sum(v)), by = cls][order(cls)]; if (nrow(x) > 2) return(NULL)
  list(a = x$cls[1], b = if (nrow(x) == 2) x$cls[2] else NA, a_pct = round(100 * x$v[1] / sum(x$v), 1), votes = sum(x$v)) }
# The MODEL's own estimate for each unit still out (10:45pm, 28 Nov): read from the per-seat grids that
# model_capture.R saves from a copy of the live loop (C:/night28/modelcap/cur/<seat>.rds, stamp in STAMP). Per unit:
# projected votes by class / the unit's projected total, as percent, in BB_CLS order. NULL when there is no capture.
bb_model <- function(dir = Sys.getenv("MODELCAP_CUR", "C:/night28/modelcap/cur")) {
  fs <- list.files(dir, "[.]rds$", full.names = TRUE); if (!length(fs)) return(NULL)
  G <- data.table::rbindlist(lapply(fs, function(f) { x <- tryCatch(readRDS(f), error = function(e) NULL); if (is.null(x) || !nrow(x$grid)) return(NULL)
    g <- data.table::as.data.table(x$grid); g[, `:=`(dk = bb_lk(x$seat), uk = ifelse(booth_type == "ordinary", bb_lk(unit), booth_type), c6 = ifelse(cls %in% BB_CLS, cls, "OTH"))]
    g[, list(v = sum(proj, na.rm = TRUE)), by = c("dk", "uk", "c6")] }))
  if (is.null(G) || !nrow(G)) return(NULL)
  G[, tot := sum(v), by = c("dk", "uk")]; G <- G[tot > 0]
  st <- tryCatch(readLines(file.path(dir, "STAMP"), warn = FALSE)[1], error = function(e) NA_character_)
  list(G = G, stamp = st)
}
# Seat-level model numbers for every booth row (Pete, 10:50pm 28 Nov: "an estimate for every single booth, a per-booth
# two-candidate, and what we expected before each booth reported"). From the live night file and the frozen pre-election
# forecast: per seat, the six-class first preferences now (post) and before the count (prior), and the final pair with
# the PREFERENCE FLOW each implies: flow = (leader's two-candidate share - leader's first preference) / the others' share.
bb_six <- function(parties, field) { v <- setNames(rep(0, length(BB_CLS)), BB_CLS)
  for (p in parties) { x <- p[[field]]; if (is.null(x)) next; k <- if (p$party %in% BB_CLS) p$party else "OTH"; v[[k]] <- v[[k]] + x }
  v }
bb_flow <- function(fp6, lead, other, lead_tcp) { if (is.null(lead) || is.null(other) || !all(c(lead, other) %in% BB_CLS) || is.null(lead_tcp)) return(NULL)
  rest <- 100 - fp6[[lead]] - fp6[[other]]; if (!is.finite(rest) || rest <= 0.5) return(NULL)
  list(a = lead, b = other, flow = min(1, max(0, (lead_tcp - fp6[[lead]]) / rest))) }
bb_seat_model <- function(night = Sys.getenv("BB_NIGHT", "C:/night28/forecast-night.json"), pre = Sys.getenv("BB_PRE", "C:/night28/forecast-vic2026-final.json")) {
  n <- tryCatch(jsonlite::fromJSON(night, simplifyVector = FALSE), error = function(e) NULL); if (is.null(n)) return(NULL)
  P <- if (nzchar(pre) && file.exists(pre)) tryCatch(jsonlite::fromJSON(pre, simplifyVector = FALSE), error = function(e) NULL) else NULL
  PS <- list(); if (!is.null(P)) for (s in P$seats) PS[[bb_lk(s$seat)]] <- s
  out <- list()
  for (s in n$seats) { post <- bb_six(s$parties, "primary"); prior <- bb_six(s$parties, "primary_prior"); ft <- s$final_two
    ps <- PS[[bb_lk(s$seat)]]; pft <- if (is.null(ps)) NULL else ps$final_two
    out[[bb_lk(s$seat)]] <- list(post = post, prior = prior, flow = bb_flow(post, ft$leader, ft$other, ft$leader_tcp$q50),
                                 flow_pre = if (is.null(pft)) NULL else bb_flow(prior, pft$leader, pft$other, pft$leader_tcp$q50)) }
  list(seats = out, stamp = n$night$snapshot_stamp)
}
bb_norm <- function(v) { v <- pmax(0, v); if (sum(v) > 0) round(100 * v / sum(v), 1) else NULL }
bb_tcp_of <- function(fp6, fl) { if (is.null(fp6) || is.null(fl)) return(NULL); names(fp6) <- BB_CLS
  rest <- 100 - fp6[[fl$a]] - fp6[[fl$b]]; list(a = fl$a, b = fl$b, a_pct = round(min(100, max(0, fp6[[fl$a]] + fl$flow * rest)), 1)) }
build_booths <- function(w, stamp) {
  R <- bb_ref()
  MOD <- bb_model()
  SM <- bb_seat_model()
  fp <- data.table::as.data.table(w$fp)[!booth_type %in% c("marked_as_voted", "none")]
  fp[, `:=`(cls = bb_cls(party), dk = bb_lk(district), uk = ifelse(booth_type == "ordinary", bb_lk(booth), booth_type))]
  tc <- if (is.null(w$tcp) || !nrow(w$tcp)) NULL else { x <- data.table::as.data.table(w$tcp)[!booth_type %in% c("marked_as_voted", "none")]
    pm <- unique(fp[, .(district, candidate, cls)]); x <- merge(x, pm, by = c("district", "candidate"), all.x = TRUE); x[is.na(cls), cls := "OTH"]
    x[, `:=`(dk = bb_lk(district), uk = ifelse(booth_type == "ordinary", bb_lk(booth), booth_type))]; x[, .(v = sum(votes, na.rm = TRUE)), by = .(dk, uk, cls)] }
  NOW <- bb_wide(fp[, .(v = sum(votes, na.rm = TRUE)), by = .(dk, uk, cls)]); REF <- bb_wide(R$fp)
  nm_now <- unique(fp[booth_type == "ordinary", .(dk, uk, name = booth)], by = c("dk", "uk"))
  seats <- list()
  for (d in sort(unique(w$districts))) {
    dk0 <- bb_lk(d)
    ord <- unique(c(nm_now$uk[nm_now$dk == dk0], if (!is.null(R$places)) R$places$uk[R$places$dk == dk0], R$names$uk[R$names$dk == dk0]))
    types <- c("early", "postal", "absent", "provisional")
    # the seat's swing so far: matched counted polling booths, tonight's share minus the same booths' reference share
    nowd <- NOW[dk == dk0 & tot > 0]; refd <- REF[dk == dk0]
    mu <- intersect(nowd$uk[nowd$uk %in% ord], refd$uk)
    sw_seat <- NULL; mv <- 0
    if (length(mu)) { a <- colSums(nowd[uk %in% mu, BB_CLS, with = FALSE]); b <- colSums(refd[uk %in% mu, BB_CLS, with = FALSE]); mv <- sum(a)
      if (sum(b) > 0) sw_seat <- round(100 * a / sum(a) - 100 * b / sum(b), 1) }
    ref_seat <- if (nrow(refd) && sum(refd$tot) > 0) 100 * colSums(refd[, BB_CLS, with = FALSE]) / sum(refd$tot) else NULL
    seat_tcp_ref <- if (is.null(R$tcp)) NULL else { x <- R$tcp[dk == dk0, .(v = sum(v)), by = cls][order(cls)]; if (nrow(x) == 2 && sum(x$v) > 0) list(a = x$cls[1], b = x$cls[2], a_pct = 100 * x$v[1] / sum(x$v)) else NULL }
    sm <- if (is.null(SM)) NULL else SM$seats[[bb_lk(d)]]
    rows <- lapply(c(ord, types), function(u) {
      ty <- if (u %in% types) u else "ordinary"
      i <- match(paste(dk0, u), paste(NOW$dk, NOW$uk)); j <- match(paste(dk0, u), paste(REF$dk, REF$uk))
      v <- if (is.na(i)) 0 else NOW$tot[i]; counted <- v > 0
      f <- if (counted) bb_pct(NOW, i) else NULL; lt <- bb_pct(REF, j)
      name <- if (ty != "ordinary") ty else { h <- nm_now$name[nm_now$dk == dk0 & nm_now$uk == u]; if (!length(h) && !is.null(R$places)) h <- R$places$name[R$places$dk == dk0 & R$places$uk == u]
        if (!length(h)) h <- R$names$name[R$names$dk == dk0 & R$names$uk == u]; if (length(h)) h[1] else u }
      est <- if (ty == "ordinary" && !is.null(R$places)) { e <- R$places$est[R$places$dk == dk0 & R$places$uk == u]; if (length(e) && is.finite(e[1])) e[1] else NA } else NA
      if (is.na(est) && !is.na(j)) est <- REF$tot[j]
      t_now <- if (counted && !is.null(tc)) bb_pair(tc, dk0, u) else NULL; t_ref <- if (is.null(R$tcp)) NULL else bb_pair(R$tcp, dk0, u)
      if (!is.null(t_ref)) t_ref$votes <- NULL
      same <- !is.null(t_now) && !is.null(t_ref) && identical(t_now$a, t_ref$a) && identical(t_now$b, t_ref$b)
      ln <- if (!is.null(lt) && !is.null(ref_seat)) lt - ref_seat else NULL   # this unit's lean last time, six classes
      mfp <- NULL; msrc <- NULL
      if (!counted) {
        m <- if (is.null(MOD)) NULL else MOD$G[dk == dk0 & uk == u]
        if (!is.null(m) && nrow(m)) { mfp <- round(100 * vapply(BB_CLS, function(c0) sum(m$v[m$c6 == c0]), 0) / m$tot[1], 1); msrc <- "model" }
        else if (!is.null(sm) && !is.null(ln)) { mfp <- bb_norm(sm$post + ln); msrc <- "seat forecast plus this unit's lean last time" }
        else if (!is.null(sm)) { mfp <- bb_norm(sm$post); msrc <- "seat forecast (no 2022 result for this unit)" }
      }
      pfp <- if (is.null(sm)) NULL else if (!is.null(ln)) bb_norm(sm$prior + ln) else bb_norm(sm$prior)
      list(booth = name, type = ty, status = if (counted) "counted" else "not yet", expected_votes = if (is.na(est)) NULL else round(est), votes = if (counted) v else NULL,
           fp = f, last_time = lt, no_match = is.null(lt), swing = if (!is.null(f) && !is.null(lt)) round(f - lt, 1) else NULL,
           model_fp = mfp, model_fp_source = msrc, model_tcp = if (!counted) bb_tcp_of(mfp, if (is.null(sm)) NULL else sm$flow) else NULL,
           pre_fp = pfp, pre_tcp = bb_tcp_of(pfp, if (is.null(sm)) NULL else sm$flow_pre),
           surprise = if (counted && !is.null(f) && !is.null(pfp)) round(f - pfp, 1) else NULL,
           projected = if (!counted && !is.null(lt) && !is.null(sw_seat)) { p <- pmax(0, lt + sw_seat); round(100 * p / sum(p), 1) } else NULL,
           lean = if (!is.null(lt) && !is.null(ref_seat)) round(lt - ref_seat, 1) else NULL,
           tcp = t_now, last_tcp = t_ref, tcp_swing = if (same) round(t_now$a_pct - t_ref$a_pct, 1) else NULL,
           tcp_lean = if (!is.null(t_ref) && !is.null(seat_tcp_ref) && identical(t_ref$a, seat_tcp_ref$a) && identical(t_ref$b, seat_tcp_ref$b)) round(t_ref$a_pct - seat_tcp_ref$a_pct, 1) else NULL)
    })
    # counted first (most votes first), then the booths still out by expected size
    o <- order(vapply(rows, function(r) r$status != "counted", logical(1)), -vapply(rows, function(r) if (is.null(r$votes)) (if (is.null(r$expected_votes)) 0 else r$expected_votes) else r$votes, numeric(1)))
    seats[[d]] <- list(matched_votes = mv, swing_so_far = sw_seat, rows = rows[o])
  }
  list(election = "vic2026", kind = "booths", model_snapshot_stamp = if (is.null(MOD)) NULL else MOD$stamp, built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), snapshot_stamp = stamp, classes = BB_CLS,
       note = "Tonight's count per booth against the same booth last time (2022 results on tonight's districts). EVERY unit not yet counted has model_fp, with model_fp_source saying how: 'model' = taken from inside the forecast model; otherwise the seat's live forecast plus the unit's lean last time, or the seat's live forecast alone. model_tcp = the seat's preference flow (from the live forecast's final two) applied to model_fp. pre_fp and pre_tcp = what we expected for the unit BEFORE the count: the pre-election seat forecast plus the unit's lean last time, and the pre-election preference flow. surprise = tonight's first preferences minus pre_fp, for counted units. 'model_fp' from source 'model' is the forecast model's own estimate for a booth or vote type that has not reported (first preferences, percent, same class order; from the model run at model_snapshot_stamp; null for a seat the model treats as fully counted on the night). 'projected' is a simple projection (last time plus the seat's swing so far on matched counted booths), not the forecast model's own booth estimate. In tcp, a is the alphabetically first of the two party classes.",
       seats = seats)
}
bb_upload <- function(doc, out, key, noup = FALSE) {
  stopifnot(grepl("^auspol/night/[a-z0-9-]*booths[a-z0-9-]*\\.json$", key))
  tmp <- paste0(out, ".tmp"); writeLines(jsonlite::toJSON(doc, auto_unbox = TRUE, null = "null", na = "null", digits = NA), tmp, useBytes = TRUE); file.rename(tmp, out)
  if (noup) return("not uploaded")
  x <- suppressWarnings(system2("wrangler", c("r2", "object", "put", shQuote(paste0("inthegame-data/", key)), "--file", shQuote(out), "--content-type", "application/json",
                                             "--cache-control", shQuote("public, max-age=30"), "--remote"), stdout = TRUE, stderr = TRUE))
  if (is.null(attr(x, "status")) && any(grepl("Upload complete", x))) paste("uploaded to", key) else paste("UPLOAD FAILED:", paste(utils::tail(x, 1), collapse = " "))
}
