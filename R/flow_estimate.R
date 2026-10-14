#' Flows for a state election with no published preference distribution
#'
#' Queensland before 2020 and South Australia published no distribution of
#' preferences that we hold, so a pair whose previous election has none has no
#' event rows for `build_flow_matrix()`. `output/flows-state-blend.csv`
#' (`scripts/build_state_flow_blend.R`) holds the time-forward blend of the
#' estimate from an election's own results and the nearest earlier published
#' flows: one row per election and minor class, with `flow_alp` (percent of the
#' class's votes that end with Labor) and `exhaust` (percent that exhaust).
#' That is party-level, so it cannot enter `build_flow_matrix()` directly.
#' These two functions bridge it: take the event rows of the nearest earlier
#' published flows (the structure: which parties are alive, how the minors
#' split among themselves) and tilt only the Labor-versus-Coalition split of
#' each class toward the previous election's blended estimate.
#'
#' LEAK RULE. The row used must be the PREVIOUS election of the pair: its
#' estimate is built from its own results, which predate the target. The target's
#' own row is built from the results being predicted and must never be used;
#' `state_blend_flows()` is told which election the caller is predicting and
#' refuses a row that is not strictly earlier.
#'
#' @param election Label of the election whose blended row is wanted, e.g. "qld2012".
#' @param target Label of the election being PREDICTED; `election` must be dated
#'   strictly before it.
#' @param path Path to the blend file.
#' @return A data.table `party, a` where `a` is Labor's percent of the votes
#'   that do NOT exhaust (`flow_alp / (100 - exhaust)`). The harnesses have no
#'   exhaust path, so the conditional share is the quantity they can use.
#' @export
state_blend_flows <- function(election, target, path = file.path("output", "flows-state-blend.csv")) {
  if (!file.exists(path)) stop("state_blend_flows: ", path, " is missing; run scripts/build_state_flow_blend.R")
  dd <- election_dates(c(election, target))   # an undated label is an error
  d_el <- dd[[election]]; d_tg <- dd[[target]]
  if (!(d_el < d_tg))
    stop("state_blend_flows: LEAK -- ", election, " (", d_el, ") is not strictly before the target ", target, " (", d_tg, ")")
  el <- election
  b <- data.table::fread(path, showProgress = FALSE)
  b <- b[b$election == el, ]
  if (!nrow(b)) stop("state_blend_flows: no blended row for ", election, " in ", path)
  if (anyNA(b$flow_alp) || anyNA(b$exhaust) || any(b$exhaust >= 100))
    stop("state_blend_flows: missing or impossible flow_alp / exhaust for ", election)
  data.table::data.table(party = b$party, a = 100 * b$flow_alp / (100 - b$exhaust))
}

#' Tilt event rows so each class's Labor-versus-Coalition split matches an estimate
#'
#' For each class in `est`, the rows of `tx` leaving that class toward ALP and
#' LNP are scaled so that ALP's share of (ALP + LNP) equals `est$a / 100`.
#' Transfers toward other classes are left alone, so which minors survive and
#' how the minors feed each other is the structure of `tx`. This matches the
#' DIRECT-step split, while the estimate is a final-count share: the two differ
#' by whatever travels through a third class, and the match is therefore
#' approximate. The before and after splits are printed (check ZE1) so the size
#' of the change is visible. A class absent from `tx`, or with no ALP or no LNP
#' transfers to scale, is left unchanged and says so.
#'
#' @param tx Event rows `(election, seat, round, from, to, votes)`.
#' @param est Output of [state_blend_flows()].
#' @param code Prefix for the log lines.
#' @return `tx` with scaled `votes` (numeric, no longer integers).
#' @export
flows_tilt_to_estimate <- function(tx, est, code = "ZE1") {
  d <- data.table::copy(data.table::as.data.table(tx))
  d[, "votes" := as.numeric(get("votes"))]
  for (i in seq_len(nrow(est))) {
    k <- est$party[i]; t <- min(0.999, max(0.001, est$a[i] / 100))
    is_k <- d$from == k
    A <- sum(d$votes[is_k & d$to == "ALP"]); L <- sum(d$votes[is_k & d$to == "LNP"])
    if (!any(is_k) || A <= 0 || L <= 0) {
      cat(sprintf("%s! class %s: no ALP/LNP transfers in the base rows (ALP %.0f, LNP %.0f) -- left unchanged\n", code, k, A, L))
      next
    }
    cur <- A / (A + L)
    d[is_k & d$to == "ALP", "votes" := get("votes") * t / cur]
    d[is_k & d$to == "LNP", "votes" := get("votes") * (1 - t) / (1 - cur)]
    cat(sprintf("%s  class %-9s ALP share of ALP+LNP: base rows %5.1f%% -> estimate %5.1f%%\n", code, k, 100 * cur, 100 * t))
  }
  d
}
