# Allocation-only test of the One Nation ORDERING: federal House rank (shipped)
# against federal Senate rank (AUSPOL_ONP_ORDER=senate_rank), same spread.
# docs/plans/prereg-onp-senate-rank-2026-10-25.md, step 1.
#
# For each One-Nation-heavy election (sa2026, qld2017, qld2020, qld2024,
# nsw2023), over the seats One Nation contested, every rule is given the
# election's TRUE One Nation mean so only the geography is scored:
#   uniform        -- the mean everywhere
#   house / senate -- a spread handed out by rank on the House or Senate One
#                     Nation vote of the most recent federal election before
#                     polling day. Two spreads:
#                       pooled: the other four elections' sorted ratios,
#                               averaged on a quantile grid, forced to CV 0.365
#                               as the live script does (leave-one-out, NOT
#                               time-forward, but the SAME spread for both
#                               orderings, so the ordering comparison is fair)
#                       oracle: the target's own sorted actual shares (isolates
#                               the ordering completely: a perfect ordering
#                               scores RMSE 0)
# Spearman with the actual shares needs no spread.
#
# House One Nation by district is rebuilt from the AEC House booth files
# (external/reference/aec/booths/fed<year>-<STATE>.csv) through the same booth
# maps the Senate table uses, and checked against
# external/elections/federal-transposed-to-state.csv where that file covers the
# election (sa2026, nsw2023).
#
# Run: powershell.exe -Command 'Rscript scripts/onp_order_loo.R [data_root] [out_csv]'
#   data_root defaults to "." (a checkout with output/ and external/ populated).
args <- commandArgs(trailingOnly = TRUE)
ROOT <- if (length(args) >= 1) args[1] else "."
OUTF <- if (length(args) >= 2) args[2] else file.path(ROOT, "output", "onp-order-loo.csv")
suppressMessages(devtools::load_all(".", quiet = TRUE))
options(auspol.root = normalizePath(ROOT))
suppressMessages(library(data.table))

ELS <- c("sa2026", "qld2017", "qld2020", "qld2024", "nsw2023")
CV <- 0.365
cand <- fread(out_path("candidacies.csv"), showProgress = FALSE)
bm <- fread(election_data_path("fed-booth-map.csv"), showProgress = FALSE, colClasses = list(character = "place_id"))
q17 <- fread(file.path(ROOT, "external", "reference", "correspondences", "booths-2017qld.csv"), showProgress = FALSE,
             colClasses = list(character = "place_id"))
bm <- rbind(bm[, .(region, cycle, fed, district, place_id)], q17[, .(region = "qld", cycle = 2017L, fed = 2016L, district, place_id)])
ftr <- fread(election_data_path("federal-transposed-to-state.csv"), showProgress = FALSE)

house_onp <- function(rg, cy, fy) {
  f <- file.path(ROOT, "external", "reference", "aec", "booths", sprintf("fed%d-%s.csv", fy, toupper(rg)))
  x <- fread(f, skip = 1, showProgress = FALSE, colClasses = list(character = "PollingPlaceID"))
  x[, onp := grepl("One Nation", PartyNm, ignore.case = TRUE)]
  b <- x[, .(onp = sum(OrdinaryVotes[onp]), tot = sum(OrdinaryVotes)), by = .(place_id = PollingPlaceID)]
  keep <- bm$region == rg & bm$cycle == cy & bm$fed == fy
  m <- merge(b, unique(bm[keep, .(district, place_id)]), by = "place_id")
  m[, .(house = 100 * sum(onp) / sum(tot)), by = .(k = normalise_seat(district))]
}

panel <- rbindlist(lapply(ELS, function(el) {
  rg <- sub("[0-9]{4}$", "", el); cy <- as.integer(sub("^[a-z]+", "", el))
  ke <- cand$election == el & cand$party == "ONP" & cand$pcv > 0
  act <- cand[ke, .(actual = sum(pcv)), by = .(seat)]
  act[, k := normalise_seat(seat)]
  sk <- onp_senate_key(act$seat, el)                    # errors if the Senate table is not before polling day
  act[, senate := as.numeric(sk)]
  fy <- attr(sk, "fed")
  h <- house_onp(rg, cy, fy)
  act <- merge(act, h, by = "k", all.x = TRUE)
  cat(sprintf("OL0  %s: %d contested seats, Senate fed%d matched %d, House fed%d matched %d, One Nation mean %.2f\n",
              el, nrow(act), fy, sum(!is.na(act$senate)), fy, sum(!is.na(act$house)), mean(act$actual)))
  # Anchor: the House build against the committed transposition, where it has the cycle.
  .rg <- rg; .cy <- cy
  tr <- ftr[ftr$region == .rg & ftr$cycle == .cy & ftr$party == "ONP", .(k = normalise_seat(seat), tr = pct)]
  if (nrow(tr)) {
    j <- merge(act, tr, by = "k")
    cat(sprintf("OL0a %s: House build v federal-transposed-to-state.csv over %d seats: r %.4f, max abs diff %.2f\n",
                el, nrow(j), stats::cor(j$house, j$tr), max(abs(j$house - j$tr))))
  }
  act[, `:=`(el = el, fed = fy)]
  act[!is.na(senate) & !is.na(house)]
}))
stopifnot(nrow(panel) > 0, all(ELS %in% panel$el))

ratio_shape <- function(x, n) {   # sorted ratios on an n-point quantile grid
  r <- sort(x / mean(x)); stats::approx(seq(0, 1, length.out = length(r)), r, xout = seq(0, 1, length.out = n))$y
}
force_cv <- function(r) { cur <- stats::sd(r) / mean(r); pmax(1 + (CV / cur) * (r - 1), 0.02) }

rows <- list(); seats <- list()
for (tg in ELS) {
  # Mask computed OUTSIDE the brackets, under a name that is not a column:
  # panel[panel$el == el] binds `el` to the column and keeps every row
  # (CLAUDE.md, data.table NSE -- and it did, on this script's first run).
  msk <- panel$el == tg
  d <- panel[msk]; n <- nrow(d); L <- mean(d$actual)
  stopifnot(n > 0, all(d$el == tg))
  pooled <- force_cv(rowMeans(sapply(setdiff(ELS, tg), function(e) ratio_shape(panel$actual[panel$el == e], n))))
  oracle <- sort(d$actual)
  alloc <- function(shape_vals, key) { out <- numeric(n); out[order(key, runif(n))] <- sort(shape_vals); out }
  set.seed(1)   # ties (House share 0 where One Nation stood no House candidate) broken at random
  pr <- list(uniform = rep(L, n),
             house_pooled = alloc(L * pooled / mean(pooled), d$house),
             senate_pooled = alloc(L * pooled / mean(pooled), d$senate),
             house_oracle = alloc(oracle, d$house),
             senate_oracle = alloc(oracle, d$senate))
  for (r in names(pr)) {
    e <- pr[[r]] - d$actual
    rows[[length(rows) + 1]] <- data.table(el = tg, rule = r, n = n, rmse = sqrt(mean(e^2)),
                                           spearman = if (r == "uniform") NA_real_ else
                                             stats::cor(rank(pr[[r]]), rank(d$actual)))
  }
  rows[[length(rows) + 1]] <- data.table(el = tg, rule = "rank_corr_house_v_senate", n = n, rmse = NA_real_,
                                         spearman = stats::cor(d$house, d$senate, method = "spearman"))
  seats[[tg]] <- data.table(el = tg, seat = d$seat, actual = d$actual, house = d$house, senate = d$senate,
                            house_pooled = pr$house_pooled, senate_pooled = pr$senate_pooled)
}
R <- rbindlist(rows)
fwrite(R, OUTF)
fwrite(rbindlist(seats), sub("\\.csv$", "-seats.csv", OUTF))
print(dcast(R, el ~ rule, value.var = "rmse")[, .(el, uniform, house_pooled, senate_pooled, house_oracle, senate_oracle)], digits = 3)
print(dcast(R[R$rule != "uniform"], el ~ rule, value.var = "spearman"), digits = 3)

# Senate minus House, per election, SE clustered on election (n = 5).
for (sp in c("pooled", "oracle")) {
  w <- dcast(R[R$rule %in% paste0(c("house_", "senate_"), sp)], el ~ rule, value.var = "rmse")
  dd <- w[[paste0("senate_", sp)]] - w[[paste0("house_", sp)]]
  cat(sprintf("OL1  %s spread: RMSE senate - house per election: %s | mean %+.3f, SE %.3f (clustered on election, n %d), %d of %d elections better\n",
              sp, paste(sprintf("%s %+.2f", w$el, dd), collapse = ", "), mean(dd), stats::sd(dd) / sqrt(length(dd)),
              length(dd), sum(dd < 0), length(dd)))
}
ws <- dcast(R[R$rule %in% c("house_oracle", "senate_oracle")], el ~ rule, value.var = "spearman")
ds <- ws$senate_oracle - ws$house_oracle
cat(sprintf("OL2  Spearman senate - house: mean %+.3f, SE %.3f, %d of %d elections higher\n",
            mean(ds), stats::sd(ds) / sqrt(length(ds)), sum(ds > 0), length(ds)))
cat(sprintf("OL3  wrote %s and %s\n", OUTF, sub("\\.csv$", "-seats.csv", OUTF)))
