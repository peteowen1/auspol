# Per-pollster pages: history, stats, and what each pollster does in the model (Pete, 11 Nov 2026: "each pollster
# should have their own page where you can see their history and stats etc - and we should say what their influence is
# in the model (do they have a weight or a bias adjustment?)").
#
# Writes output/pollster-pages.json, one entry per pollster with:
#   stats    the scorecard row (output/pollster-scorecard.csv, scripts/fit_scorecard.R): long-run Labor lean, noise,
#            final-poll error over the elections it polled
#   finals   its final poll at each election against the result (output/pollster-accuracy.csv)
#   cycles   its Labor house effect in every fitted cycle (output/pollster-lean-by-cycle.csv)
#   live     for each live election, what the PUBLISHED trend (trend_as_at(), the fit the forecast uses) does with
#            its polls: the house effect removed for each party, or pooled with other firms, or no polls
#   polls    every poll it published (fed, nsw, vic, qld), first preferences and published two-party
# plus `method`: how pollsters enter the model, in plain words. Nothing here changes the model.
#
#   Rscript scripts/build_pollster_pages.R
# Check codes PPG1-PPG4.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages({ library(data.table); library(jsonlite) })
LIVE <- c("vic2026", "nsw2027")
REGIONS <- c("fed", "nsw", "vic", "qld")
need <- c("output/pollster-scorecard.csv", "output/pollster-accuracy.csv", "output/pollster-lean-by-cycle.csv")
for (f in need) if (!file.exists(f)) stop("PPG1! missing ", f, " (run scripts/fit_scorecard.R)")
card <- fread(need[1], showProgress = FALSE); acc <- fread(need[2], showProgress = FALSE); byc <- fread(need[3], showProgress = FALSE)
cat(sprintf("PPG1 scorecard %d firms, accuracy %d final polls, lean by cycle %d rows (%d cycles)\n", nrow(card), nrow(acc),
            nrow(byc), uniqueN(byc[, list(region, year)])))

polls <- rbindlist(lapply(REGIONS, function(rg) { p <- suppressMessages(load_polls(rg))
  keep <- intersect(c("date", "firm", "tpp_published", "LNP", "ALP", "GRN", "ONP", "OTH"), names(p))
  p[, keep, with = FALSE][, region := rg] }), fill = TRUE)
polls <- polls[!is.na(polls$firm) & nzchar(trimws(polls$firm))]
cat(sprintf("PPG1 polls: %d across %s, %d firms\n", nrow(polls), paste(REGIONS, collapse = "/"), uniqueN(polls$firm)))

# what the published trend does with each pollster, per live election: the SAME call fit_seats_full.R and the page
# builders make (one fit), house effects per party from its fits
cycles <- load_election_cycles(); pri <- load_prior_results(); flows <- load_preference_flows()
live <- rbindlist(lapply(LIVE, function(el) {
  rg <- sub("[0-9]+$", "", el); yr <- as.integer(sub("^[a-z]+", "", el))
  kp <- pri$region == rg & pri$year == yr; priors <- setNames(pri$prev1[which(kp)], pri$party[which(kp)])
  now <- trend_as_at(suppressMessages(load_polls(rg)), yr, cycles, Sys.Date(), priors, flows_for(flows, yr, rg, quiet = TRUE), with_series = TRUE)
  if (is.null(now) || is.null(now$fits)) stop("PPG2! no published fit for ", el)
  he <- rbindlist(lapply(names(now$fits), function(p) { h <- now$fits[[p]]$house_effects
    if (is.null(h) || !nrow(h)) NULL else data.table(election = el, party = p, firm = h$firm, effect_pts = round(h$effect_pts, 2), n_polls = h$n_polls) }))
  cyc <- cycle_polls(suppressMessages(load_polls(rg)), yr, cycles)
  cnt <- cyc[!is.na(cyc$firm), list(n_cycle = .N), by = firm]
  pooled <- setdiff(cnt$firm, he$firm)
  cat(sprintf("PPG2 %s: %d polls this cycle, %d firms with their own house effect, %d pooled (fewer than 3 polls): %s\n", el, nrow(cyc),
              uniqueN(setdiff(he$firm, "(other firms)")), length(pooled), paste(pooled, collapse = ", ")))
  rbind(he[he$firm != "(other firms)"], if (length(pooled)) data.table(election = el, party = NA_character_, firm = pooled, effect_pts = NA_real_,
                                                                      n_polls = cnt$n_cycle[match(pooled, cnt$firm)]))
}), fill = TRUE)

elname <- function(el) { rg <- sub("[0-9]+$", "", el); yr <- sub("^[a-z]+", "", el)
  if (rg == "fed") paste("the", yr, "federal election") else paste(c(vic = "Victoria", nsw = "NSW", qld = "Queensland", sa = "South Australia", wa = "WA")[[rg]], yr) }
slug <- function(x) gsub("^-|-$", "", gsub("[^a-z0-9]+", "-", tolower(x)))
# one pollster, two spellings that differ only in punctuation ("Wolf&Smith" in the state files, "Wolf+Smith" in the
# federal one): one page, under the spelling with more polls. The model is unaffected: a cycle is one region, and the
# two spellings never meet in one (checked 11 Nov 2026).
pk <- function(x) gsub("[^a-z0-9]", "", tolower(x))
nm_all <- c(polls$firm, card$firm, acc$firm, byc$firm)
fmap <- data.table(firm = nm_all)[, list(n = .N), by = firm][, key := pk(firm)][order(key, -n)][, list(canon = firm[1], alias = firm), by = key]
al <- fmap[fmap$alias != fmap$canon]
if (nrow(al)) cat(sprintf("PPG3 merged spellings: %s\n", paste(sprintf("'%s' -> '%s'", al$alias, al$canon), collapse = "; ")))
cn <- function(x) { i <- match(x, fmap$alias); ifelse(is.na(i), x, fmap$canon[i]) }
polls[, firm := cn(firm)]; card[, firm := cn(firm)]; acc[, firm := cn(firm)]; byc[, firm := cn(firm)]; live[, firm := cn(firm)]
pname <- c(ALP = "Labor", LNP = "Coalition", GRN = "Greens", ONP = "One Nation", OTH = "others")
firms <- sort(unique(c(card$firm, acc$firm, byc$firm[byc$firm != "(other firms)"], polls$firm)))
if (anyDuplicated(slug(firms))) stop("PPG3! two pollster names give the same page address: ", paste(firms[duplicated(slug(firms))], collapse = ", "))
# One pollster under several names when its method changed (Newspoll -> Newspoll2 -> Newspoll3 in 2015 and 2023;
# ResolvePM, YouGov, Lonergan, Lighthouse; Roy Morgan's modes): link the pages and say when each name was in use.
fam <- function(x) { k <- tolower(x); k <- sub("/.*$", "", k); k <- sub(" research$", "", k); k <- sub("[0-9]+$", "", k)
  ifelse(grepl("morgan", k), "morgan", trimws(k)) }
span <- polls[, list(first = min(date), last = max(date)), by = firm]
fam_links <- function(fm) { o <- setdiff(firms[fam(firms) == fam(fm)], fm); I(if (length(o)) slug(o) else character(0)) }   # I(): a one-item list stays a list under auto_unbox
fam_note <- function(fm) {
  o <- setdiff(firms[fam(firms) == fam(fm)], fm); if (!length(o)) return(NULL)
  rng <- function(f) { i <- match(f, span$firm); if (is.na(i)) "no polls on file" else sprintf("%s to %s", format(span$first[i], "%b %Y"), format(span$last[i], "%b %Y")) }
  sprintf("The same pollster appears under other names when its method changed: %s. This page covers %s only (%s).",
          paste(sprintf("%s (%s)", o, vapply(o, rng, "")), collapse = "; "), fm, rng(fm))
}
pages <- lapply(firms, function(fm) {
  st <- card[card$firm == fm]; fi <- acc[acc$firm == fm][order(-year)]; cy <- byc[byc$firm == fm][order(-year)]
  pl <- polls[polls$firm == fm][order(-date)]; lv <- live[live$firm == fm]
  live_txt <- lapply(LIVE, function(el) {
    x <- lv[lv$election == el]
    if (!nrow(x)) return(list(election = el, status = "no polls this cycle", text = sprintf("No polls in the run-up to %s, so no effect on that forecast.", elname(el))))
    if (all(is.na(x$party))) return(list(election = el, status = "pooled", n_polls = x$n_polls[1],
      text = sprintf("%d poll(s) in the run-up to %s: fewer than 3, so they share one house effect with the other rarely-seen pollsters. Each poll counts the same as any other.", x$n_polls[1], elname(el))))
    eff <- x[order(-abs(effect_pts))]
    list(election = el, status = "own house effect", n_polls = x$n_polls[1],
         house_effects = setNames(as.list(x$effect_pts), x$party),
         text = sprintf("%d polls in the run-up to %s, each counting the same as any other poll. Compared with the other pollsters over the same months it has %s. The trend takes those differences out before it averages the polls.",
                        x$n_polls[1], elname(el), paste(sprintf("%s %.1f points %s", pname[eff$party], abs(eff$effect_pts), ifelse(eff$effect_pts >= 0, "higher", "lower")), collapse = ", ")))
  })
  list(firm = fm, slug = slug(fm),
       stats = if (nrow(st)) list(polls = st$n_polls, cycles = st$n_cycles, elections = st$elections, final_error = round(st$final_mae, 2),
                                   final_bias = round(st$final_bias, 2), lean_labor = round(st$lean_pts, 2), noise = round(st$noise_factor, 2)) else NULL,
       live = live_txt,
       finals = fi[, list(election = paste0(region, year), poll_date = as.character(poll_date), days_before, poll_tpp, actual_tpp, error)],   # an empty table serialises as [], not null
       cycles = cy[, list(election = paste0(region, year), lean_labor = effect_pts, n_polls)],
       see_also = fam_links(fm), note = fam_note(fm),
       polls = if (nrow(pl)) pl[, c(list(date = as.character(date), region = region), lapply(.SD, function(v) round(v, 1))),
                                 .SDcols = intersect(c("tpp_published", "LNP", "ALP", "GRN", "ONP", "OTH"), names(pl))] else NULL)
})
n_live <- vapply(pages, function(p) sum(vapply(p$live, function(l) l$status != "no polls this cycle", logical(1))), 0L)
out <- list(
  as_of = as.character(Sys.Date()),
  method = list(
    weight = "Every poll counts the same. Weighting pollsters by their record or by how noisy they are was tested and made the trend slightly worse on held-out elections, so it is not used.",
    house_effect = "Each pollster with 3 or more polls in a cycle gets its own house effect for each party: how far it sits from the other pollsters this cycle, held near zero by a prior (3 points) and centred so the pollsters average out. The trend removes it. Pollsters with fewer than 3 polls share one pooled house effect.",
    record = "A pollster's past final-poll error is shown on its page but does not change the forecast.",
    lean_vs_house = "'Leans' in the record table is the long-run average of the Labor house effect over every cycle since 1990; the model uses only the house effects from the run-up to the election it is forecasting, shown under each election."),
  firms = pages)
json <- toJSON(out, auto_unbox = TRUE, digits = NA, na = "null", null = "null")
json <- gsub("&", "\\u0026", gsub(">", "\\u003e", gsub("<", "\\u003c", json, fixed = TRUE), fixed = TRUE), fixed = TRUE)
writeLines(json, "output/pollster-pages.json")
cat(sprintf("PPG4 wrote output/pollster-pages.json (%.0f KB): %d pollsters, %d with scorecard stats, %d active in a live cycle\n",
            file.size("output/pollster-pages.json") / 1024, length(pages), sum(vapply(pages, function(p) !is.null(p$stats), logical(1))), sum(n_live > 0)))
d <- Filter(function(p) p$firm == "DemosAU", pages)
if (length(d)) cat("PPG4 DemosAU:", vapply(d[[1]]$live, `[[`, "", "text"), sep = "\n  ")
