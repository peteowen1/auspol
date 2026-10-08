# What-if slider, step 2 of 2: gather every scenario scripts/build_scenarios.R
# ran into output/scenario-<election>.json for the ITG page.
#
#   Rscript scripts/combine_scenarios.R [--target=vic2026] [--allow-partial]
#
# Chamber figures use build_forecast_json.R's definitions exactly (majority,
# hung, One Nation balance of power), so the slider at today's level and the
# headline forecast are the same numbers.
#
# Two checks that can fail:
#   - every party x mode x offset is present (unless --allow-partial);
#   - the "polled" run at offset 0 forces nothing, so its seat probabilities
#     must be IDENTICAL to the published run's. If they differ, the scenario
#     runs are not describing the forecast that was published.

suppressMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
CFGS <- list(vic2026 = list(stem = "vic-2026", seats = 88L, majority = 45L),
             nsw2027 = list(stem = "nsw-2027", seats = 93L, majority = 47L))
TARGET <- arg("target", Sys.getenv("AUSPOL_TARGET", "vic2026"))
if (!TARGET %in% names(CFGS)) stop("SC0! unknown --target ", TARGET)
CFG <- CFGS[[TARGET]]; STEM <- CFG$stem; MAJ <- CFG$majority
stopifnot(CFG$seats %/% 2L + 1L == MAJ)
PARTIAL <- "--allow-partial" %in% args

today <- fread(sprintf("output/statewide-level-%s.csv", STEM), showProgress = FALSE)
betas <- fread(sprintf("output/statewide-draw-betas-%s.csv", STEM), showProgress = FALSE)
pat <- sprintf("^seat-sims-full-%s-scn-(exact|polled)-([A-Z_]+)-([+-][0-9.]+)\\.csv$", STEM)
files <- list.files("output", pattern = pat)
if (!length(files)) stop("SC5! no scenario outputs for ", TARGET, " -- run scripts/build_scenarios.R first")
keys <- data.table(file = files,
                   mode = sub(pat, "\\1", files), party = sub(pat, "\\2", files),
                   off = as.numeric(sub(pat, "\\3", files)))
# Scenarios older than today's levels describe a different day's forecast.
lvl_time <- file.mtime(sprintf("output/statewide-level-%s.csv", STEM))
stale <- keys$file[file.mtime(file.path("output", keys$file)) < lvl_time]
if (length(stale)) stop("SC5! ", length(stale), " scenario file(s) predate today's levels, e.g. ", stale[1])

want <- CJ(mode = c("exact", "polled"), party = c("ONP", "ALP", "LNP", "GRN"),
           off = seq(-10, 10, by = 2.5))
want <- want[today$level[match(want$party, today$party)] + want$off >= 0.5]
missing <- want[!keys, on = .(mode, party, off)]
cat(sprintf("SC5  %s: %d scenario(s) found, %d expected, %d missing\n", TARGET, nrow(keys), nrow(want), nrow(missing)))
if (nrow(missing) && !PARTIAL)
  stop("SC5! missing scenarios: ", paste(sprintf("%s %s %+.1f", missing$mode, missing$party, missing$off), collapse = ", "))

pub_f <- sprintf("output/seat-probs-%s.csv", STEM)
seat_names <- sort(unique(fread(pub_f, showProgress = FALSE)$seat))
classes <- NULL
scen <- lapply(seq_len(nrow(keys)), function(i) {
  k <- keys[i]
  sims  <- fread(file.path("output", k$file), showProgress = FALSE)
  probs <- fread(sub("seat-sims-full", "seat-probs", file.path("output", k$file)), showProgress = FALSE)
  cls <- names(sims)
  if (is.null(classes)) classes <<- cls
  if (!identical(cls, classes)) stop("SC6! ", k$file, " has classes ", paste(cls, collapse = ","))
  mx <- do.call(pmax, as.list(sims))
  a <- if ("ALP" %in% cls) sims$ALP else 0; l <- if ("LNP" %in% cls) sims$LNP else 0
  o <- if ("ONP" %in% cls) sims$ONP else 0
  big <- pmax(a, l)
  # per seat x class win chance, x1000 as integers (the page divides back)
  pm <- matrix(0L, length(seat_names), length(cls), dimnames = list(seat_names, cls))
  pm[cbind(match(probs$seat, seat_names), match(probs$party, cls))] <- as.integer(round(probs$prob * 1000))
  if (anyNA(match(probs$seat, seat_names))) stop("SC6! ", k$file, ": seat not in the published forecast")
  list(mode = k$mode, party = k$party, offset = k$off,
       level = round(today$level[today$party == k$party] + k$off, 2),
       expected = as.list(round(colMeans(sims), 2)),
       p_majority = as.list(round(vapply(sims, function(v) mean(v >= MAJ), numeric(1)), 4)),
       p_hung = round(mean(mx < MAJ), 4),
       p_onp_balance_of_power = round(mean(big < MAJ & big + o >= MAJ & o > 0), 4),
       seat_probs = unname(pm))
})

# The free check: polled at offset 0 forces nothing, so it IS the published run.
z <- keys[mode == "polled" & off == 0]
if (nrow(z)) {
  pub <- fread(pub_f, showProgress = FALSE)
  for (j in seq_len(nrow(z))) {
    f <- sub("seat-sims-full", "seat-probs", file.path("output", z$file[j]))
    same <- isTRUE(all.equal(pub, fread(f, showProgress = FALSE), check.attributes = FALSE))
    cat(sprintf("SC7  polled %s at today's level %s the published seat probabilities\n",
                z$party[j], if (same) "MATCHES" else "DOES NOT MATCH"))
    if (!same) stop("SC7! ", f, " differs from ", pub_f, ": the scenarios do not describe the published forecast")
  }
} else cat("SC7! no polled offset-0 scenario, so nothing ties these scenarios to the published forecast\n")

gitsha <- tryCatch(trimws(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)), error = function(e) NA_character_)
doc <- list(
  election = TARGET, built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), git_sha = gitsha,
  chamber_seats = CFG$seats, majority = MAJ, n_sims = nrow(fread(file.path("output", keys$file[1]), showProgress = FALSE)),
  modes = list(exact = "The party gets exactly this share of the statewide first-preference vote in every simulated election.",
               polled = "This is where the party's vote is expected to land, with the forecast's usual uncertainty around it."),
  today = as.list(setNames(today$level, today$party)),
  betas = betas, classes = classes, seats = seat_names,
  scenarios = scen)
out <- sprintf("output/scenario-%s.json", TARGET)
jsonlite::write_json(doc, out, auto_unbox = TRUE, digits = NA)
cat(sprintf("SC8  wrote %s: %d scenarios, %d seats, %.0f KB\n", out, length(scen), length(seat_names), file.size(out) / 1024))
