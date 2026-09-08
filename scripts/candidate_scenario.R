#' What-if tool for candidate/party tracking between elections
#'
#' Pete's ask, 2026-09-09: a tool that takes one seat's candidacy corpus at
#' the target election, lets you drop a candidate, add one, or relabel one's
#' party, and shows exactly how that changes the base inputs the seat model
#' actually uses -- own_prev_pcv, prev_party, transfer -- WITHOUT running the
#' full statewide simulation. Waite (sa2022->sa2026) and Kiama (nsw2019->
#' nsw2023) are the worked examples below.
#'
#' This does not touch statewide swing, salience or dev_slope -- it isolates
#' exactly the layer candidate_returns()/personal_prior_vote()/
#' remove_transferred_votes() (R/candidate_returns.R) control, because that
#' is the layer Pete is asking about. Every override is applied to a COPY of
#' output/candidacies.csv; the real file is never touched.
#'
#' Emits CS* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

#' Apply a set of overrides to one seat's target-election candidacy rows.
#'
#' @param corpus The full candidacies table (data.table).
#' @param want_election,want_seat Which target rows to touch.
#' @param drop Character vector of surname-ish strings; any row whose `name`
#'   contains one (case-insensitive) is removed.
#' @param add A data.frame of new rows: at minimum `party` and `name`; `pcv`
#'   defaults to 0.01 (a nominal placeholder -- these functions only use it
#'   to pick the LEADING candidate per seat/class when more than one stands,
#'   never as a real vote estimate) and `elected` to FALSE.
#' @param reparty Named character vector: `name = new_party`, relabels an
#'   existing row's `party` in place (identity match is unaffected --
#'   candidate_returns() matches on name, not label).
apply_overrides <- function(corpus, want_election, want_seat,
                             drop = character(0), add = NULL, reparty = NULL) {
  cp <- data.table::copy(corpus)
  is_target_row <- cp$election == want_election & cp$seat == want_seat
  if (length(drop)) {
    hit <- is_target_row & Reduce(`|`, lapply(drop, function(nm)
      grepl(nm, cp$name, ignore.case = TRUE)))
    if (any(hit)) cat(sprintf("CS1  dropped: %s\n", paste(cp$name[hit], collapse = "; ")))
    cp <- cp[!hit]
    is_target_row <- cp$election == want_election & cp$seat == want_seat
  }
  if (!is.null(reparty)) {
    for (nm in names(reparty)) {
      hit <- is_target_row & grepl(nm, cp$name, ignore.case = TRUE)
      if (any(hit)) {
        cat(sprintf("CS2  relabelled %s: %s -> %s\n",
                    cp$name[hit][1], cp$party[hit][1], reparty[[nm]]))
        cp[hit, party := reparty[[nm]]]
      }
    }
  }
  if (!is.null(add) && nrow(add)) {
    new_rows <- data.table::as.data.table(add)
    if (!"pcv" %in% names(new_rows)) new_rows[, pcv := 0.01]
    if (!"elected" %in% names(new_rows)) new_rows[, elected := FALSE]
    new_rows[, election := want_election]
    new_rows[, seat := want_seat]
    miss_cols <- setdiff(names(cp), names(new_rows))
    for (mc in miss_cols) new_rows[[mc]] <- NA
    extra_cols <- setdiff(names(new_rows), names(cp))
    if (length(extra_cols)) new_rows[, (extra_cols) := NULL]
    data.table::setcolorder(new_rows, names(cp))
    cat(sprintf("CS3  added: %s\n", paste(new_rows$name, collapse = "; ")))
    cp <- rbind(cp, new_rows)
  }
  cp
}

#' Run the candidate/party-tracking layer for one seat, print the result.
run_scenario <- function(label, corpus, election_from, election_to, want_seat,
                          major_discount = 0.282) {
  cr <- candidate_returns(election_from, election_to, corpus = corpus)
  cr <- cr[cr$seat == want_seat]
  pv <- tryCatch(
    personal_prior_vote(election_from, election_to, corpus = corpus, major_discount = major_discount),
    error = function(e) { cat(sprintf("CS0! personal_prior_vote() failed: %s\n", conditionMessage(e))); NULL }
  )
  if (!is.null(pv)) pv <- pv[pv$seat == want_seat]
  out <- merge(cr[, .(seat, party, same, same_mp, prior_leader_returns)],
               if (is.null(pv)) NULL else pv[, .(seat, party, own_prev_pcv, prev_party, transfer)],
               by = c("seat", "party"), all.x = TRUE)
  cat(sprintf("\n--- %s ---\n", label))
  print(out[, .(party, same, same_mp, own_prev_pcv = round(own_prev_pcv, 1),
                prev_party, transfer = round(transfer, 1))])
  invisible(out)
}

if (identical(environment(), globalenv()) || sys.nframe() == 0) {
  CORPUS <- data.table::fread("output/candidacies.csv", showProgress = FALSE)

  cat("=====================================================================\n")
  cat("WAITE (sa2022 -> sa2026) -- Duluk and Holmes-Ross both retired\n")
  cat("Actual 2026 result: ALP (Hutchesson) 50.4%, up from 26.6% in 2022.\n")
  cat("=====================================================================\n")

  run_scenario("BASELINE (real corpus -- Duluk and Holmes-Ross already gone, weak IND replacement Gargett 2.9%)",
               CORPUS, "sa2022", "sa2026", "Waite")

  scen_duluk_only <- apply_overrides(CORPUS, "sa2026", "Waite",
                                      drop = "GARGETT",
                                      add = data.frame(party = "IND", name = "DULUK, Sam", pcv = 19.7))
  run_scenario("SCENARIO: Duluk alone stands again (Holmes-Ross still out)",
               scen_duluk_only, "sa2022", "sa2026", "Waite")

  scen_both_back <- apply_overrides(CORPUS, "sa2026", "Waite",
                                     drop = "GARGETT",
                                     add = data.frame(party = "IND",
                                                       name = c("DULUK, Sam", "HOLMES-ROSS, Heather Lynn"),
                                                       pcv = c(19.7, 14.6)))
  run_scenario("SCENARIO: BOTH Duluk and Holmes-Ross stand again (two IND candidates)",
               scen_both_back, "sa2022", "sa2026", "Waite")

  cat("\n=====================================================================\n")
  cat("KIAMA (nsw2019 -> nsw2023) -- Gareth Ward, LNP -> IND\n")
  cat("Actual 2023 result: IND (Ward) 38.8%, up from an LNP 53.6% base.\n")
  cat("=====================================================================\n")

  run_scenario("BASELINE (real corpus -- Ward runs as IND in 2023)",
                CORPUS, "nsw2019", "nsw2023", "Kiama")

  scen_ward_lnp <- apply_overrides(CORPUS, "nsw2023", "Kiama", reparty = c("WARD" = "LNP"))
  run_scenario("SCENARIO: Ward relabelled back to LNP (undoes the defection)",
               scen_ward_lnp, "nsw2019", "nsw2023", "Kiama")

  scen_ward_onp <- apply_overrides(CORPUS, "nsw2023", "Kiama", reparty = c("WARD" = "ONP"))
  run_scenario("SCENARIO: Ward relabelled ONP instead of IND (same defection, different minor label)",
               scen_ward_onp, "nsw2019", "nsw2023", "Kiama")

  cat("\n--- SCENARIO: the unseen case Pete named -- a LOSING major-party MP defects to a minor party ---\n")
  scen_losing_defector <- data.table::copy(CORPUS)
  scen_losing_defector[election == "nsw2019" & seat == "Kiama" & grepl("WARD", name), elected := FALSE]
  run_scenario("Ward's 2019 row marked NOT elected (losing MP), still defects to IND in 2023",
               scen_losing_defector, "nsw2019", "nsw2023", "Kiama")
}
