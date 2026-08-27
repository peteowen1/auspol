#' Which seats have the SAME candidate standing again for a class
#'
#' The seat model is party-class based, so a returning independent and a
#' stranger are projected identically. Measured across 17 election pairs that is
#' the largest single effect available: a seat polling 30% for an independent
#' projects to 30.3% if the same person stands and 12.1% if they do not.
#'
#' \tabular{lrrr}{
#'   class \tab same person \tab person gone \tab t \cr
#'   IND \tab 0.907 \tab 0.326 \tab 12.3 \cr
#'   OTH_RIGHT \tab 0.891 \tab 0.325 \tab 15.4 \cr
#'   GRN \tab 0.994 \tab 0.880 \tab 4.5 \cr
#'   ONP \tab 0.610 \tab 0.545 \tab 0.7
#' }
#'
#' Matching is on SURNAME plus first initial within the seat and class, via
#' [match_key()]. Surname alone wrongly joins two people sharing one; a full
#' first name wrongly splits Bob from Robert. Neither error is symmetric —
#' splitting turns a returning member into a fabricated emergence, which is what
#' four NSW seats did when the emergence definition keyed on party class.
#'
#' Western Australia publishes bare surnames with no given name, so matching
#' there falls back to surname within seat. That is stated rather than hidden:
#' two different candidates sharing a surname in one WA seat would read as
#' persistence, and WA is 7 of the 17 pairs.
#'
#' @param election_from,election_to Election labels as they appear in the
#'   corpus, e.g. `"fed2019"` and `"fed2022"`.
#' @param corpus Optional pre-read candidacy table; read from
#'   `output/candidacies.csv` when `NULL`.
#' @return A `data.table` of `seat`, `party`, `same` covering every seat/class
#'   present at `election_to`. `same` is `FALSE` where nobody of that class stood
#'   before, which is the correct reading: there is no one to return.
#' @export
candidate_returns <- function(election_from, election_to, corpus = NULL) {
  C <- corpus
  if (is.null(C)) {
    f <- file.path("output", "candidacies.csv")
    if (!file.exists(f)) {
      stop("candidate_returns() needs output/candidacies.csv; run ",
           "scripts/build_candidacies.R", call. = FALSE)
    }
    C <- data.table::fread(f, showProgress = FALSE)
  }
  C <- data.table::as.data.table(C)
  need <- c("election", "seat", "party")
  miss <- setdiff(need, names(C))
  if (length(miss)) stop("corpus lacks: ", paste(miss, collapse = ", "), call. = FALSE)

  # NOT `now`/`prev` as names: those collide with columns built below, and a bare
  # symbol inside dt[...] binds to the column. Six instances in this repo.
  NOWT  <- C[C$election == election_to]
  PREVT <- C[C$election == election_from]
  if (!nrow(NOWT)) stop("no rows for election ", election_to, call. = FALSE)
  if (!nrow(PREVT)) stop("no rows for election ", election_from, call. = FALSE)

  kf <- function(d) {
    sur <- surname_of(if ("surname" %in% names(d)) d$surname else NA_character_,
                      if ("name" %in% names(d)) d$name else NA_character_)
    giv <- given_of(if ("given" %in% names(d)) d$given else NA_character_,
                    if ("name" %in% names(d)) d$name else NA_character_)
    match_key(sur, giv, "initial")
  }
  NOWT  <- data.table::copy(NOWT)[,  .k := kf(.SD), .SDcols = names(NOWT)]
  PREVT <- data.table::copy(PREVT)[, .k := kf(.SD), .SDcols = names(PREVT)]

  # JOIN ON A NORMALISED SEAT KEY. The corpus is not internally consistent:
  # vic2014 and vic2018 store seats as "albertpark" while vic2022 stores
  # "Albert Park", so an exact join between them matched ZERO of 508 seat-classes
  # and reported that no Victorian candidate had ever re-stood. That reads as a
  # real answer -- some elections genuinely have few returners -- and Victoria is
  # the live target. Caught only because every other pair ran 15-26%.
  #
  # Normalising here rather than in the corpus keeps this fix at the point of
  # use; the corpus inconsistency is a separate defect and is recorded as one.
  ns <- function(x) gsub("[^a-z0-9]", "", tolower(x))
  NOWT[,  .s := ns(seat)]
  PREVT[, .s := ns(seat)]
  # MATCH THE PERSON ACROSS THE SEAT, NOT WITHIN THE PARTY CLASS.
  #
  # Philip Donato held Orange with 49.1% as a Shooter in 2019 and 53.1% as an
  # independent in 2023. Matching within (seat, party) called him a NEW
  # independent, so a sitting member with a five-year incumbency counted as an
  # emergence -- and as the single failure of the salience screen in an election
  # where it otherwise had none. Every party-switcher had the same fault, which
  # is the NSW Shooters-to-independent trap CLAUDE.md already records in another
  # form.
  #
  # A returning candidate is the same PERSON in the same SEAT. Which label they
  # stand under is a separate question and belongs to the party swing.
  prev_keys <- PREVT[nzchar(PREVT$.k), list(.s, .k)]
  out <- unique(NOWT[nzchar(NOWT$.k), list(seat, .s, party, .k)])
  out <- merge(out, unique(prev_keys)[, `:=`(hit = TRUE)],
               by = c(".s", ".k"), all.x = TRUE)
  out[is.na(hit), hit := FALSE]
  res <- out[, list(same = any(hit)), by = list(seat, party)]  # target's own names
  # Every seat/class at the target election, so a caller can index without
  # worrying about which ones had a match at all.
  full <- unique(NOWT[, list(seat, party)])
  res <- merge(full, res, by = c("seat", "party"), all.x = TRUE)
  res[is.na(same), same := FALSE][]
}
