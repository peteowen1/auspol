# Freeze the outside Victoria 2026 forecasts, and our own, on a benchmark date.
#
#   Rscript scripts/snapshot_benchmarks.R            # capture today (UTC date), then derive the calls files
#   Rscript scripts/snapshot_benchmarks.R --derive   # derive only, from what is already on disk for that date
#   Rscript scripts/snapshot_benchmarks.R --date=2026-10-21 --derive
#
# The pre-registration is docs/plans/external-benchmark-vic2026-2026-10-20.md: freeze dates Tue 27 Oct, 3 and 10 Nov,
# 17 Nov and 27 Nov; the 27 Nov capture of every source is the comparison of record. Run this on each of those days.
#
# TWO OUTPUTS, kept apart on purpose:
#
# 1. RAW, as received, one file per request, under external/reference/benchmarks/vic2026/<date>/<source>/, with a
#    manifest.tsv row per file (source, url, UTC time, HTTP status, bytes, sha256). Gitignored like all external data.
#    Nothing is parsed at fetch time. A file is accepted only when it parses and carries what it should (a JSON key,
#    88 seats, the script that defines the data), never on size: a truncated 65,536-byte download once passed a size
#    floor here and dropped a seat silently (CLAUDE.md). A file that fails is not written to the manifest, so a rerun
#    fetches it again; one that already passed is not refetched (the run is resumable).
#
# 2. CALLS, derived from the raw files, committed: docs/benchmarks/vic2026/<date>/<source>-calls.csv with columns
#    district, call_class, prob. Probability sources (ours, AE Forecasts) carry one row per class with prob > 0;
#    call-only sources (GES, Jago) carry one row per district with prob blank. Classes come from classify_party(),
#    the one source of truth for party classes. Every file must name all 88 districts by our spelling.
#
# SOURCES (the plan says why each is in or out):
#   ours         the published forecast-latest release assets, as the site serves them that day (not a rebuild)
#   aeforecasts  the dated REST payload. Not fetch_aeforecasts.R: that reuses its cache, which would freeze the
#                first capture silently, so this fetches fresh into the dated folder every time
#   ges          page, app bundle, the Victoria modules it imports (including guide-victoria-*, whose content-hashed
#                name changing means GES updated its polling), and the district map. Its per-district calls exist
#                only in the rendered page, so they are read in Chrome into ges/ges-district-calls-read-from-page.csv
#                (see the 21 Oct file's header); this script turns that file into calls and says loudly when it is
#                missing
#   jago         his page and the four scripts it runs. "Jago on our numbers" is his OWN calculator.js run offline
#                (scripts/jago_calc.js) on our statewide primaries for that day; see JAGO INPUTS below
#   Roy Morgan   DROPPED 21 Oct (no seat winners in finding 10346); not fetched
#   theswingison (added 24 Oct) data/vic/tap-default-result.js: 5,000-simulation win counts per seat, one entry per
#                date (a 7-day rolling buffer); the entry for DAY is the forecast of record for that date
#   sportsbet, tab, betfair (added 24 Oct) seat-winner markets via the oddsdata package (C:/dev/oddsdata). Partial
#                coverage (50, 53 and 4 of 88 on 24 Oct), so their calls files carry only the districts priced and
#                say how many. Prices become probabilities with oddsdata::implied_probs()'s power method (plan
#                amendment, 24 Oct). Fetched only when DAY is today: odds are live, there is no "as at" URL. TAB
#                is behind bot protection: it is saved from Pete's own Chrome (Claude in Chrome, or by hand) into
#                tab/Politics-Victorian-Politics.json with a manifest row (oddsdata::odds_save_raw), never automated.
#
# JAGO INPUTS (fixed 2026-10-22, before the first counting capture; plan amendment 1). His calculator takes four
# statewide shares, Greens/Labor/LNP/One Nation, and his own defaults are those four parties' Senate first
# preferences with every other vote shared among them in proportion (calculator.js, "dist_none"). So our input is the
# same quantity from our forecast: each party's mean first-preference share across the 88 districts in that day's
# seat-shares-vic-2026.csv, the four renormalised to sum to 100. Equal weight per district (Victorian districts are
# drawn within 10% of one quota), no preference flows, nothing invented.
#
# Emits VB* codes. A `!` code means the capture is not usable. (They were BM* until 2026-10-22: BM was not free,
# scripts/build_retiring_mp_cases.R prints BM1-BM9, and test-check-code-collisions.R turned CI red. Check a prefix
# with that test, not by grepping one folder.)

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages({ library(data.table); library(jsonlite) })

args <- commandArgs(trailingOnly = TRUE)
DERIVE_ONLY <- "--derive" %in% args
DAY <- sub("^--date=", "", grep("^--date=", args, value = TRUE))
if (!length(DAY)) DAY <- format(Sys.time(), "%Y-%m-%d", tz = "UTC")
if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", DAY)) stop("VB0! --date must be YYYY-MM-DD, got ", DAY)

RAW  <- file.path("external", "reference", "benchmarks", "vic2026", DAY)
OUT  <- file.path("docs", "benchmarks", "vic2026", DAY)
MAN  <- file.path(RAW, "manifest.tsv")
UA   <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
N_DISTRICTS <- 88L
cat(sprintf("VB1  vic2026 benchmark %s for %s: raw %s, calls %s\n", if (DERIVE_ONLY) "derive" else "capture", DAY, RAW, OUT))

# ---- validators: a file counts only if it is what it claims to be ------------------------------------------------
read_txt <- function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
json_key <- function(key) function(f) { j <- tryCatch(fromJSON(f, simplifyVector = FALSE), error = function(e) NULL); !is.null(j) && !is.null(j[[key]]) }
has_text <- function(pattern) function(f) grepl(pattern, read_txt(f), perl = TRUE)
ok_forecast_json <- function(f) {
  j <- tryCatch(fromJSON(f, simplifyVector = FALSE), error = function(e) NULL)
  !is.null(j) && identical(j$election, "vic2026") && length(j$seats) == N_DISTRICTS
}
ok_seat_csv <- function(f) { d <- tryCatch(fread(f), error = function(e) NULL); !is.null(d) && "seat" %in% names(d) && uniqueN(d$seat) == N_DISTRICTS }
ok_geojson <- function(f) { j <- tryCatch(fromJSON(f, simplifyVector = FALSE), error = function(e) NULL); !is.null(j) && length(j$features) == N_DISTRICTS }

# ---- fetch ---------------------------------------------------------------------------------------------------------
manifest <- if (file.exists(MAN)) fread(MAN, sep = "\t", colClasses = "character") else
  data.table(source = character(), url = character(), fetched_utc = character(), http = character(),
             bytes = character(), sha256 = character(), file = character())
fails <- character()

get <- function(source, url, name, valid) {
  rel <- file.path(source, name); dest <- file.path(RAW, rel)
  if (rel %in% manifest$file && file.exists(dest) && valid(dest)) { cat(sprintf("VB2  %-40s already captured\n", rel)); return(invisible(dest)) }
  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
  t <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  h <- curl::new_handle(useragent = UA, followlocation = TRUE, timeout = 120)
  r <- tryCatch(curl::curl_fetch_disk(url, dest, handle = h), error = function(e) e)
  code <- if (inherits(r, "error")) NA_integer_ else r$status_code
  good <- !is.na(code) && code == 200L && file.exists(dest) && isTRUE(valid(dest))
  if (!good) {
    why <- if (inherits(r, "error")) conditionMessage(r) else sprintf("HTTP %s, %s", code, if (file.exists(dest)) "content failed its check" else "no file")
    cat(sprintf("VB3! %-40s NOT captured: %s (%s)\n", rel, why, url))
    fails <<- c(fails, rel); return(invisible(NULL))
  }
  manifest <<- rbind(manifest[file != rel], data.table(
    source = source, url = url, fetched_utc = t, http = as.character(code), bytes = as.character(file.size(dest)),
    sha256 = digest::digest(file = dest, algo = "sha256"), file = rel))
  fwrite(manifest, MAN, sep = "\t")
  cat(sprintf("VB2  %-40s %9d bytes\n", rel, file.size(dest)))
  invisible(dest)
}

if (!DERIVE_ONLY) {
  dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

  # Ours: what the site published, from the public release.
  REL <- "https://github.com/peteowen1/auspol/releases/download/forecast-latest/"
  get("ours", paste0(REL, "forecast-vic2026.json"), "forecast-vic2026.json", ok_forecast_json)
  get("ours", paste0(REL, "seat-probs-vic-2026.csv"), "seat-probs-vic-2026.csv", ok_seat_csv)
  get("ours", paste0(REL, "seat-shares-vic-2026.csv"), "seat-shares-vic-2026.csv", ok_seat_csv)
  get("ours", paste0(REL, "forecast-history.csv"), "forecast-history.csv", has_text("^built_at,"))

  # AE Forecasts. "www." and "?format=json" are both required (fetch_aeforecasts.R header says why).
  AEF <- "https://www.aeforecasts.com/forecast-api/"
  get("aeforecasts", paste0(AEF, "election-summary/2026vic/regular?format=json"), "election-summary-2026vic-regular.json", json_key("report"))
  get("aeforecasts", paste0(AEF, "election-results/2026vic/?format=json"), "election-results-2026vic.json", json_key("results"))

  # Global Election Simulator: the bundle names are content hashes, so each is read from the file that links it.
  G <- "https://globalelectionsimulator.com"
  html <- get("ges", paste0(G, "/victoria"), "victoria.html", has_text("/assets/index-[A-Za-z0-9_-]+\\.js"))
  idx <- if (!is.null(html)) regmatches(read_txt(html), regexpr("/assets/index-[A-Za-z0-9_-]+\\.js", read_txt(html))) else character()
  bundle <- if (length(idx)) get("ges", paste0(G, idx), basename(idx), has_text("VictoriaApp")) else NULL
  vapp_m <- if (!is.null(bundle)) regmatches(read_txt(bundle), regexpr("assets/page-VictoriaApp-[A-Za-z0-9_-]+\\.js", read_txt(bundle))) else character()
  vapp <- if (length(vapp_m)) get("ges", paste0(G, "/", vapp_m), basename(vapp_m), has_text("import|export")) else NULL
  if (!is.null(vapp)) {
    mods <- unique(regmatches(read_txt(vapp), gregexpr("\\./data-[A-Za-z0-9_]*-[A-Za-z0-9_-]+\\.js", read_txt(vapp)))[[1]])
    mods <- sub("^\\./", "", mods[grepl("victoria|Victoria|poll|Poll", mods)])
    for (m in mods) get("ges", paste0(G, "/assets/", m), m, has_text("."))
  }
  # Its statewide polling inputs (guide-victoria-*.js) are NOT linked from any of these files: on 21 Oct, and again on
  # 22 Oct, it was visible only in Chrome's network panel. So it is saved in the Chrome step, with the calls.
  get("ges", paste0(G, "/victoria-districts.geojson"), "victoria-districts.geojson", ok_geojson)

  # Jago: the page, and the scripts jago_calc.js needs to run his calculator.
  J <- "https://abjago.net"
  get("jago", paste0(J, "/4PP-projections-from-senate-results/2026-victoria-districts"), "page.html", has_text("calculator\\.js"))
  get("jago", paste0(J, "/assets/4PP/2026_victoria_districts_from_2025.js"), "2026_victoria_districts_from_2025.js", has_text("^var district_prefs = \\{"))
  get("jago", paste0(J, "/assets/4PP/calculator.js"), "calculator.js", has_text("#calculate"))
  get("jago", paste0(J, "/assets/4PP/monotone_cubic_spline.js"), "monotone_cubic_spline.js", has_text("createInterpolant"))
  get("jago", paste0(J, "/assets/4PP/four-party-graph.js"), "four-party-graph.js", has_text("."))

  # The Swing Is On: the precomputed simulation result its page renders, and the page itself.
  TSIO <- "https://theswingison.com"
  get("theswingison", paste0(TSIO, "/track-polls/vic26"), "vic26.html", has_text("tap-default-result\\.js"))
  get("theswingison", paste0(TSIO, "/data/vic/tap-default-result.js"), "tap-default-result.js",
      has_text(sprintf('window\\.TAP_DEFAULT_RESULT = \\{"days":.*"date":"%s"', DAY)))

  # Bookmakers and the exchange, through oddsdata, which writes raw files and manifest rows itself. Last, because
  # get() rewrites the manifest from memory and would drop rows appended behind its back.
  today <- format(Sys.time(), "%Y-%m-%d", tz = "UTC")
  if (!requireNamespace("oddsdata", quietly = TRUE)) {
    cat("VB3! oddsdata not installed: no Sportsbet/TAB/Betfair capture (devtools::install('C:/dev/oddsdata'))\n")
    fails <- c(fails, "sportsbet", "tab", "betfair")
  } else if (DAY != today) {
    cat(sprintf("VB3! odds are live: cannot capture bookmakers for %s on %s\n", DAY, today))
    fails <- c(fails, "sportsbet", "tab", "betfair")
  } else {
    store <- dirname(RAW)
    book <- function(src, expr) tryCatch({ x <- expr; cat(sprintf("VB2  %-40s %d markets, %d selections\n", src,
      uniqueN(x$market_id), nrow(x))); x }, error = function(e) {
      cat(sprintf("VB3! %-40s NOT captured: %s\n", src, conditionMessage(e))); fails <<- c(fails, src); NULL })
    book("sportsbet", {
      ev <- oddsdata::sb_events(9519, store = store)          # Sportsbet's Victorian politics competition
      ev <- ev[grepl("Seat Betting", event)]
      if (nrow(ev) != 1L) stop("expected one 'Seat Betting' event in competition 9519, found ", nrow(ev))
      oddsdata::sb_markets(ev$event_id, ev$event, store = store)
    })
    book("betfair", {
      nav <- oddsdata::bf_search(2378961, store = store)      # Betfair politics
      vic <- nav[event %in% c("Australia - Victoria State Politics", "Individual Electorates")]
      if (!nrow(vic)) stop("no Victorian markets in Betfair's politics search")
      oddsdata::bf_prices(vic$market_id, store = store)
    })
    # TAB's feed is behind bot protection and is NOT automated around (no headless Chrome, no faked user agent).
    # It loads normally in Pete's own Chrome, so Claude does this step itself with Claude in Chrome (done 27 Oct):
    #   1. navigate a new tab to the URL below; it shows the JSON;
    #   2. javascript_tool in that tab: fetch(location.href) -> text; check JSON.parse(text).matches is an array;
    #      download it with a Blob + <a download="Politics-Victorian-Politics.json">.click() (lands in ~/Downloads);
    #      do not print location.href or the body: the tool blocks output carrying query strings;
    #   3. mv it from ~/Downloads to the path below, and append a manifest.tsv row (source tab, url, UTC time,
    #      200, bytes, sha256, tab/Politics-Victorian-Politics.json); then rerun this script.
    if (!length(list.files(file.path(RAW, "tab"), "^Politics-Victorian-Politics.*\\.json$"))) {
      cat(sprintf("VB4! TAB not captured: open %s in a normal browser on tab.com.au and save the response as received to %s\n",
                  "https://api.beta.tab.com.au/v1/tab-info-service/sports/Politics/competitions/Victorian%20Politics?jurisdiction=NSW",
                  file.path(RAW, "tab", "Politics-Victorian-Politics.json")))
      fails <- c(fails, "tab")
    }
    invisible(NULL)
  }
}

# ---- derive the calls files ----------------------------------------------------------------------------------------
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
raw <- function(...) file.path(RAW, ...)
written <- character()

ours_seats <- if (file.exists(raw("ours", "seat-probs-vic-2026.csv"))) unique(fread(raw("ours", "seat-probs-vic-2026.csv"))$seat) else character()
if (length(ours_seats) != N_DISTRICTS) stop(sprintf("VB4! our seat-probs for %s has %d districts, not %d: nothing can be matched", DAY, length(ours_seats), N_DISTRICTS))
canon <- setNames(ours_seats, toupper(ours_seats))

# One district name per row, by our spelling; every one of the 88 present. Returns the canonical names.
match_districts <- function(x, src, all = TRUE) {
  k <- toupper(trimws(x)); out <- unname(canon[k])
  if (anyNA(out)) stop(sprintf("VB5! %s names %d districts we do not: %s", src, sum(is.na(out)), paste(unique(x[is.na(out)]), collapse = ", ")))
  if (all && uniqueN(out) != N_DISTRICTS) stop(sprintf("VB5! %s covers %d of %d districts", src, uniqueN(out), N_DISTRICTS))
  out
}
write_calls <- function(dt, src) {
  stopifnot(identical(names(dt), c("district", "call_class", "prob")))
  if (any(is.na(dt$call_class))) stop(sprintf("VB6! %s has %d rows with no class", src, sum(is.na(dt$call_class))))
  if (!all(is.na(dt$prob))) {
    tot <- dt[, .(s = sum(prob)), by = district]
    if (any(abs(tot$s - 1) > 0.01)) stop(sprintf("VB6! %s probabilities do not sum to 1 in %d districts (worst %.3f)", src, sum(abs(tot$s - 1) > 0.01), tot$s[which.max(abs(tot$s - 1))]))
  }
  setorder(dt, district, -prob, call_class)
  f <- file.path(OUT, paste0(src, "-calls.csv")); fwrite(dt, f)
  fav <- if (all(is.na(dt$prob))) dt else dt[, .SD[1], by = district]
  cat(sprintf("VB7  %-12s %d districts; calls %s -> %s\n", src, uniqueN(dt$district),
              paste(sprintf("%s %d", names(table(fav$call_class)), table(fav$call_class)), collapse = ", "), f))
  written <<- c(written, src)
}

# Ours
sp <- fread(raw("ours", "seat-probs-vic-2026.csv"))
write_calls(sp[prob > 0, .(district = match_districts(seat, "ours"), call_class = party, prob = as.numeric(prob))], "ours")
fj <- fromJSON(raw("ours", "forecast-vic2026.json"), simplifyVector = FALSE)
cat(sprintf("VB8  ours: built %s at %s\n", fj$built_at, fj$git_sha))

# AE Forecasts: party indices through partyAbbr/partyName, classed by classify_party(); negative indices are generic
# candidates of a type and land in the same class as the named ones (score_aeforecasts.R does the same).
af <- raw("aeforecasts", "election-summary-2026vic-regular.json")
if (file.exists(af)) {
  rep <- fromJSON(af, simplifyVector = FALSE)$report
  ab <- rbindlist(lapply(rep$partyAbbr, function(p) data.table(k = as.character(p[[1]]), abbr = as.character(p[[2]]))))
  nm <- rbindlist(lapply(rep$partyName, function(p) data.table(k = as.character(p[[1]]), name = as.character(p[[2]]))))
  ab <- merge(ab, nm, by = "k", all.x = TRUE)
  ab[, cls := classify_party(name, code = abbr)]
  cat(sprintf("VB9  AE Forecasts party classes: %s (report %s)\n", paste(sprintf("%s=%s", ab$abbr, ab$cls), collapse = " "), rep$reportDate))
  seats <- unlist(rep$seatNames)
  rows <- rbindlist(lapply(seq_along(seats), function(i) {
    p <- rep$seatPartyWinFrequencies[[i]]
    data.table(seat = seats[i], k = vapply(p, function(x) as.character(x[[1]]), ""), pct = vapply(p, function(x) as.numeric(x[[2]]), 0))
  }))
  rows <- merge(rows, ab[, .(k, cls)], by = "k", all.x = TRUE)
  if (anyNA(rows$cls)) stop(sprintf("VB9! AE Forecasts uses party index %s, absent from its partyAbbr", paste(unique(rows[is.na(cls)]$k), collapse = ",")))
  aef <- rows[, .(prob = sum(pct) / 100), by = .(seat, call_class = cls)][prob > 0]
  write_calls(aef[, .(district = match_districts(seat, "aeforecasts"), call_class, prob)], "aeforecasts")
} else cat("VB4! no AE Forecasts payload for this date\n")

# GES: party codes read from the rendered map (LIB/NAT/ALP/GRN/ONP...), classed by code.
gf <- raw("ges", "ges-district-calls-read-from-page.csv")
if (file.exists(gf)) {
  g <- fread(gf, skip = "district,")
  # Only the five map colours ges_read_calls.js decodes are calls. Anything else (its UNK) would reach
  # classify_party() with a blank name and come back IND: a plausible, wrong, frozen call.
  bad <- !(g$party %in% c("LIB", "NAT", "ALP", "GRN", "ONP"))
  if (any(bad)) stop(sprintf("VB6! GES has %d district(s) with an unread map colour (%s): %s", sum(bad),
                             paste(unique(g$party[bad]), collapse = ","), paste(g$district[bad], collapse = ", ")))
  write_calls(g[, .(district = match_districts(district, "ges"), call_class = classify_party(rep("", .N), code = party), prob = NA_real_)], "ges")
} else {
  cat(sprintf("VB4! GES district calls NOT captured for %s: read the rendered map at %s/victoria in Chrome into %s (format: the 2026-10-21 file's header)\n",
              DAY, "https://globalelectionsimulator.com", gf))
  fails <- c(fails, "ges/calls")
}
# A content-hashed file name that differs from the previous capture means GES changed that file: its code
# (page-VictoriaApp) or its polling (guide-victoria). Either can move its calls.
prev_days <- sort(list.dirs(dirname(RAW), recursive = FALSE, full.names = FALSE))
prev_days <- prev_days[prev_days < DAY]
if (length(prev_days)) {
  for (pat in c("^page-VictoriaApp-.*\\.js$", "^guide-victoria-.*\\.js$")) {
    now <- list.files(raw("ges"), pat); was <- list.files(file.path(dirname(RAW), tail(prev_days, 1), "ges"), pat)
    cat(sprintf("VB10 GES %s: %s now, %s on %s -> %s\n", sub("^\\^(.*)-\\.\\*.*$", "\\1", pat),
                if (length(now)) now[1] else "not captured", if (length(was)) was[1] else "not captured", tail(prev_days, 1),
                if (!length(now) || !length(was)) "cannot compare" else if (identical(now, was)) "unchanged" else "CHANGED"))
  }
  if (!length(list.files(raw("ges"), "^guide-victoria-.*\\.js$"))) {
    cat("VB4! GES polling inputs (guide-victoria-*.js) not saved for this date: save it from Chrome's network panel with the calls\n")
    fails <- c(fails, "ges/guide-victoria")
  }
}

# Jago on our numbers: his calculator, run by scripts/jago_calc.js on our statewide four-party shares (header).
jd <- raw("jago")
if (file.exists(file.path(jd, "calculator.js"))) {
  sh <- fread(raw("ours", "seat-shares-vic-2026.csv"))
  four <- c(Grn = "GRN", Lab = "ALP", Lnp = "LNP", Phn = "ONP")
  m <- vapply(four, function(p) mean(sh[[p]]), 0)
  inp <- 100 * m / sum(m)
  cat(sprintf("VB11 Jago inputs from our %d-district mean primaries: %s (the four were %.1f%% of the vote; renormalised)\n",
              nrow(sh), paste(sprintf("%s %.2f", names(inp), inp), collapse = ", "), sum(m)))
  fwrite(data.table(party = names(inp), our_class = unname(four), our_mean_primary = round(m, 4), jago_input = round(inp, 4)),
         file.path(OUT, "jago-ours-inputs.csv"))
  tmp <- tempfile(fileext = ".csv")
  st <- system2("node", c("scripts/jago_calc.js", shQuote(jd), sprintf("%.4f", inp)), stdout = tmp, stderr = "")
  if (!identical(as.integer(st), 0L)) stop("VB12! scripts/jago_calc.js failed (exit ", st, ")")
  jc <- fread(tmp)
  fwrite(jc, file.path(OUT, "jago-ours-detail.csv"))
  write_calls(jc[, .(district = match_districts(district, "jago-ours"), call_class = unname(four[winner]), prob = NA_real_)], "jago-ours")
} else { cat("VB4! no saved Jago calculator for this date\n"); fails <- c(fails, "jago") }

# The Swing Is On: win counts out of its simulations for the entry dated DAY. Its four "Other" classes (left-leaning,
# right-leaning, unaligned) are kept apart as OTH_LEFT/OTH_RIGHT/OTH_UNALIGNED: they are its own buckets, not ours.
tf <- raw("theswingison", "tap-default-result.js")
if (file.exists(tf)) {
  js <- read_txt(tf)
  tj <- fromJSON(sub(";\\s*$", "", sub("^[\\s\\S]*?window\\.TAP_DEFAULT_RESULT = ", "", js, perl = TRUE)), simplifyVector = FALSE)
  dd <- Filter(function(d) identical(d$date, DAY), tj$days)
  if (length(dd) != 1L) stop(sprintf("VB14! The Swing Is On has %d entries dated %s", length(dd), DAY))
  swc <- dd[[1]]$mcResult$seatWinCounts
  if (is.null(swc)) stop("VB14! The Swing Is On entry has no mcResult$seatWinCounts")
  n_it <- length(dd[[1]]$mcResult$iterationCounts)
  tcls <- c("Labor" = "ALP", "Coalition" = "LNP", "Greens" = "GRN", "One Nation" = "ONP",
            "Other, Left-leaning" = "OTH_LEFT", "Other, Right-leaning" = "OTH_RIGHT", "Other, Unaligned" = "OTH_UNALIGNED")
  tl <- rbindlist(lapply(names(swc), function(s) data.table(seat = s, lab = names(swc[[s]]), n = as.numeric(unlist(swc[[s]])))))
  if (!all(tl$lab %in% names(tcls))) stop("VB14! The Swing Is On class not mapped: ", paste(setdiff(tl$lab, names(tcls)), collapse = ", "))
  tot <- tl[, .(n = sum(n)), by = seat]
  if (any(tot$n != n_it)) stop(sprintf("VB14! The Swing Is On seat win counts do not sum to its %d simulations", n_it))
  cat(sprintf("VB14 The Swing Is On %s: %d simulations, poll average %s\n", DAY, n_it,
              paste(sprintf("%s %.1f", names(dd[[1]]$avgPt), unlist(dd[[1]]$avgPt)), collapse = ", ")))
  write_calls(tl[n > 0, .(district = match_districts(seat, "theswingison"), call_class = unname(tcls[lab]), prob = n / n_it)], "theswingison")
} else { cat("VB4! no The Swing Is On result for this date\n"); fails <- c(fails, "theswingison") }

# Bookmakers and the exchange: seat-winner markets only, partial coverage. Selections are classed by name; a residual
# ("Any Other", "Other", "Any Other Result", "Any Other Party or Independent") is ANY_OTHER, which scores as the
# winner's probability when the winner is in none of the named classes. A name we cannot class stops the script.
book_class <- function(x) {
  out <- rep(NA_character_, length(x))
  out[grepl("^Labor$", x)] <- "ALP"
  out[grepl("^(Liberals?|Nationals?|Coalition|L-?NP)$", x)] <- "LNP"
  out[grepl("^Gre+ns$", x)] <- "GRN"                 # TAB spells it "Greeens" in one market (24 Oct)
  out[grepl("^One Nation$", x)] <- "ONP"
  out[grepl("^Independent", x)] <- "IND"
  out[grepl("^(Any )?Other", x)] <- "ANY_OTHER"
  if (anyNA(out)) stop("VB6! bookmaker selection(s) not classed: ", paste(unique(x[is.na(out)]), collapse = ", "))
  out
}
newest <- function(src, pat) { f <- sort(list.files(raw(src), pat, full.names = TRUE)); if (length(f)) tail(f, 1) else NA_character_ }
if (requireNamespace("oddsdata", quietly = TRUE)) {
  parsers <- list(
    sportsbet = function() { f <- newest("sportsbet", "^event-.*-markets-.*\\.json$"); if (is.na(f)) NULL else
      oddsdata::sb_parse_markets(read_txt(f), "seat-betting")[, seat := market] },
    tab = function() { f <- newest("tab", "^Politics-Victorian-Politics.*\\.json$"); if (is.na(f)) NULL else
      oddsdata::tab_parse_markets(read_txt(f))[market == "Seat Winner"][, seat := sub(" State Election$", "", event)] },
    betfair = function() { f <- newest("betfair", "^markets-.*\\.json$"); if (is.na(f)) NULL else
      oddsdata::bf_parse_prices(read_txt(f))[event == "Individual Electorates"][, seat := sub("^Seat of ", "", market)] })
  for (src in names(parsers)) {
    o <- parsers[[src]]()
    if (is.null(o) || !nrow(o)) { cat(sprintf("VB4! no %s seat markets on disk for this date\n", src)); fails <- c(fails, src); next }
    o <- oddsdata::implied_probs(o, "power")
    o <- o[!is.na(prob)]
    cat(sprintf("VB15 %s: %d seat markets, median overround %.3f (1.000 = no margin)\n", src, uniqueN(o$seat), median(o$overround)))
    write_calls(o[, .(prob = sum(prob)), by = .(district = match_districts(seat, src, all = FALSE), call_class = book_class(selection))], src)
  }
} else { cat("VB4! oddsdata not installed: bookmaker calls not derived\n"); fails <- c(fails, "sportsbet", "tab", "betfair") }

if (sum(c("sportsbet", "tab", "betfair") %in% written) >= 2L) {
  st <- system2(file.path(R.home("bin"), "Rscript"), c("scripts/compare_bookmaker_odds.R", paste0("--date=", DAY)))
  if (!identical(as.integer(st), 0L)) { cat("VB18! scripts/compare_bookmaker_odds.R failed\n"); fails <- c(fails, "bookmaker-odds") }
  # the value table and page (ours against every price, with a click-through per seat); publishing it is manual
  st <- system2(file.path(R.home("bin"), "Rscript"), c("scripts/value_odds_vic2026.R", paste0("--date=", DAY)))
  if (!identical(as.integer(st), 0L)) { cat("VB19! scripts/value_odds_vic2026.R failed\n"); fails <- c(fails, "value-odds") }
}

cat(sprintf("\nVB13 %s: calls written for %s%s\n", DAY, paste(written, collapse = ", "),
            if (length(fails)) sprintf("; NOT USABLE: %s", paste(unique(fails), collapse = ", ")) else "; every source captured"))
cat("VB13 next: commit docs/benchmarks/vic2026/", DAY, "/ and rerun scripts/build_data_registry.R\n", sep = "")
if (length(fails)) quit(status = 1)
