# Reader for the VEC's election-night results XML feed (Victoria 2026; issue #158).
#
# The feed is a series of complete snapshots: one ZIP every ~5 minutes on the night, each
# holding one XML for every district. Rules this file follows (feed research, issue #149):
# - parse by LOCAL element name: namespaces differ between files and houses;
# - a count is per polling place OR per district vote type, never both;
# - a 2CP element that is missing, empty, `Maverick="true"` or has `Updated=""` is no data,
#   never zero;
# - counts can go down between snapshots, so nothing here assumes they only rise;
# - booth and candidate ids change every event: match to 2022 on district id + booth name.

.vf_x <- function(node, path) xml2::xml_find_all(node, path)
.vf_1 <- function(node, path) xml2::xml_find_first(node, path)
.vf_l <- function(name) sprintf("*[local-name()='%s']", name)
.vf_path <- function(...) paste(vapply(c(...), .vf_l, ""), collapse = "/")
.vf_num <- function(node, path) {
  x <- xml2::xml_text(.vf_1(node, path))
  suppressWarnings(as.numeric(x))
}
.vf_attr <- function(node, attr) {
  v <- xml2::xml_attr(node, attr)
  v[!is.na(v) & !nzchar(v)] <- NA_character_
  v
}

#' Newest snapshot in a folder of VEC feed ZIPs or extracted XMLs
#'
#' Snapshot names end `_YYYYMMDD_HHMMSS`; the newest is the one to read.
#' @param dir Folder holding the snapshots.
#' @param kind File kind in the name, e.g. `"verboselhv2"` (Assembly, verbose).
#' @return Path of the newest matching file, or `NA` when there is none.
#' @export
vec_feed_latest <- function(dir, kind = "verboselhv2") {
  f <- list.files(dir, pattern = paste0(kind, "_[0-9]{8}_[0-9]{6}\\.(xml|zip)$"),
                  full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
  if (!length(f)) return(NA_character_)
  stamp <- sub(paste0(".*", kind, "_([0-9]{8}_[0-9]{6})\\..*$"), "\\1", basename(f), ignore.case = TRUE)
  f[order(stamp, decreasing = TRUE)][1]
}

.vf_read_doc <- function(path) {
  if (grepl("\\.zip$", path, ignore.case = TRUE)) {
    inside <- utils::unzip(path, list = TRUE)$Name
    inside <- inside[grepl("\\.xml$", inside, ignore.case = TRUE)]
    if (length(inside) != 1L)
      stop("VX1! ", basename(path), " holds ", length(inside), " XML files, expected 1", call. = FALSE)
    tmp <- tempfile(); dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    utils::unzip(path, files = inside, exdir = tmp)
    return(xml2::read_xml(file.path(tmp, inside)))
  }
  xml2::read_xml(path)
}

.vf_cands <- function(fp_node) {
  cs <- .vf_x(fp_node, .vf_l("Candidate"))
  if (!length(cs)) return(data.table::data.table(candidate_id = character(), votes = numeric()))
  data.table::data.table(
    candidate_id = xml2::xml_attr(.vf_1(cs, .vf_l("CandidateIdentifier")), "Id"),
    votes = vapply(cs, function(cn) .vf_num(cn, .vf_l("Votes")), 0))
}

# A 2CP block that is really there: the element exists, is not withheld, carries an
# update time, and names two candidates with a count each. Anything else is "no data".
.vf_tcp <- function(tcp_node) {
  if (inherits(tcp_node, "xml_missing")) return(NULL)
  if (tolower(xml2::xml_attr(tcp_node, "Maverick")) %in% "true") return(NULL)
  if (is.na(.vf_attr(tcp_node, "Updated"))) return(NULL)
  d <- .vf_cands(tcp_node)
  if (nrow(d) != 2L || anyNA(d$votes)) return(NULL)
  d
}

#' Read one VEC Assembly snapshot (verbose file) into tidy tables
#'
#' @param path A `verboselhv2` XML, or the ZIP holding it.
#' @return A list of data.tables:
#'   `contests` (one row per district: id, name, enrolment, booths expected/returned,
#'   declared, formal, informal, updated, `tcp_status` "pair" / "none");
#'   `candidates` (district, candidate id, name, ballot position, affiliation id,
#'   independent flag, district first-preference votes);
#'   `by_type` (district, candidate id or "FORMAL"/"INFORMAL", vote type, votes);
#'   `booths` (district, polling place id, name, classification, candidate id, votes);
#'   `booth_tcp` and `district_tcp` (the VEC's 2CP pair where it is reported; seats
#'   with no pair have no rows, never zero rows of votes).
#' @export
vec_feed_read_lh <- function(path) {
  doc <- .vf_read_doc(path)
  root <- xml2::xml_root(doc)
  if (xml2::xml_name(root) != "MediaFeed")
    stop("VX2! ", basename(path), " root is <", xml2::xml_name(root), ">, not MediaFeed", call. = FALSE)
  contests <- .vf_x(root, paste0(".//", .vf_path("House", "Contests", "Contest")))
  if (!length(contests)) stop("VX3! no Assembly contests in ", basename(path), call. = FALSE)

  ct <- list(); cand <- list(); bt <- list(); bo <- list(); btc <- list(); dtc <- list()
  for (i in seq_along(contests)) {
    cn <- contests[[i]]
    pd <- .vf_1(cn, .vf_l("PollingDistrictIdentifier"))
    did <- xml2::xml_attr(pd, "Id")
    dname <- xml2::xml_text(.vf_1(pd, .vf_l("Name")))
    fp <- .vf_1(cn, .vf_l("FirstPreferences"))
    tcp <- .vf_tcp(.vf_1(cn, .vf_l("TwoCandidatePreferred")))
    ct[[i]] <- data.table::data.table(
      district_id = did, district = dname,
      enrolment = .vf_num(cn, .vf_l("Enrolment")),
      booths_expected = as.numeric(xml2::xml_attr(fp, "PollingPlacesExpected")),
      booths_returned = as.numeric(xml2::xml_attr(fp, "PollingPlacesReturned")),
      declared = identical(tolower(xml2::xml_text(.vf_1(cn, .vf_l("Declared")))), "true"),
      formal = .vf_num(fp, .vf_path("Formal", "Votes")),
      informal = .vf_num(fp, .vf_path("Informal", "Votes")),
      updated = .vf_attr(fp, "Updated"),
      tcp_status = if (is.null(tcp)) "none" else "pair")

    cs <- .vf_x(fp, .vf_l("Candidate"))
    if (length(cs)) {
      cand[[i]] <- data.table::data.table(
        district_id = did,
        candidate_id = xml2::xml_attr(.vf_1(cs, .vf_l("CandidateIdentifier")), "Id"),
        name = xml2::xml_text(.vf_1(cs, .vf_path("CandidateIdentifier", "CandidateName"))),
        ballot_position = as.integer(xml2::xml_text(.vf_1(cs, .vf_l("BallotPosition")))),
        affiliation_id = .vf_attr(.vf_1(cs, .vf_path("Affiliation", "AffiliationIdentifier")), "Id"),
        # the real feed writes "yes"/"no" (2026 sample: 1,608 yes); accept "true" too
        independent = tolower(xml2::xml_attr(cs, "Independent")) %in% c("yes", "true"),
        votes = vapply(cs, function(x) .vf_num(x, .vf_l("Votes")), 0))
      tv <- list()
      for (j in seq_along(cs)) {
        v <- .vf_x(cs[[j]], .vf_path("VotesByType", "Votes"))
        if (length(v)) tv[[j]] <- data.table::data.table(
          district_id = did, candidate_id = cand[[i]]$candidate_id[j],
          vote_type = xml2::xml_attr(v, "Type"), votes = as.numeric(xml2::xml_text(v)))
      }
      for (lab in c("Formal", "Informal")) {
        v <- .vf_x(fp, .vf_path(lab, "VotesByType", "Votes"))
        if (length(v)) tv[[length(tv) + 1L]] <- data.table::data.table(
          district_id = did, candidate_id = toupper(lab),
          vote_type = xml2::xml_attr(v, "Type"), votes = as.numeric(xml2::xml_text(v)))
      }
      bt[[i]] <- data.table::rbindlist(tv)
    }

    if (!is.null(tcp)) dtc[[i]] <- tcp[, district_id := did]
    pps <- .vf_x(cn, .vf_path("PollingPlaces", "PollingPlace"))
    bl <- list(); bl2 <- list()
    for (k in seq_along(pps)) {
      pid <- .vf_1(pps[[k]], .vf_l("PollingPlaceIdentifier"))
      meta <- list(district_id = did, booth_id = xml2::xml_attr(pid, "Id"),
                   booth = xml2::xml_attr(pid, "Name"), booth_class = xml2::xml_attr(pid, "Classification"))
      bf <- .vf_1(pps[[k]], .vf_l("FirstPreferences"))
      if (!inherits(bf, "xml_missing")) {
        d <- .vf_cands(bf)
        if (nrow(d)) bl[[k]] <- cbind(data.table::as.data.table(meta), d)
      }
      bt2 <- .vf_tcp(.vf_1(pps[[k]], .vf_l("TwoCandidatePreferred")))
      if (!is.null(bt2)) bl2[[k]] <- cbind(data.table::as.data.table(meta), bt2)
    }
    bo[[i]] <- data.table::rbindlist(bl)
    btc[[i]] <- data.table::rbindlist(bl2)
  }
  out <- list(contests = data.table::rbindlist(ct), candidates = data.table::rbindlist(cand),
              by_type = data.table::rbindlist(bt, fill = TRUE), booths = data.table::rbindlist(bo, fill = TRUE),
              booth_tcp = data.table::rbindlist(btc, fill = TRUE), district_tcp = data.table::rbindlist(dtc, fill = TRUE))
  # Names must be unique per district: a duplicate candidate id would double its votes in any join.
  dup <- out$candidates[, .N, by = c("district_id", "candidate_id")][N > 1L]
  if (nrow(dup)) stop("VX4! duplicate candidate ids in ", basename(path), ": ",
                      paste(dup$candidate_id, collapse = ", "), call. = FALSE)
  out
}
