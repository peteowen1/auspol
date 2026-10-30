# AUSPOL_IND_GAP_RESTAND: an IND class gap is carried only when one of the
# class's earlier candidates re-stands (docs/plans/prereg-ind-gap-restand-2026-10-25.md).
withr::local_envvar(AUSPOL_MINOR_DEFECT_CONSERVE = "0", AUSPOL_BYELECTION_MP = "0",
                    AUSPOL_BYELEC_DEPARTED = "0")

# Six seats, each one shape:
#   PV   Pascoe Vale vic2022: three e1 independents, none stands at e2, a new one does -> dropped
#   MW   Morwell: the leader leaves but a minor e1 independent stands again as IND -> kept
#   RS   the same independent stands again -> kept
#   NW   no independent at e1 at all -> kept (no earlier candidate whose vote could leave)
#   DF   the e2 independent leader stood here at e1 as ALP (own vote is the base) -> kept
#   AW   the e1 independent stands again but for another class; the IND is new -> dropped
mk_gap <- function() data.table::data.table(
  election = c(rep("e1", 12), rep("e2", 13)),
  seat = c("PV", "PV", "PV", "PV",  "MW", "MW",  "RS",  "NW", "DF", "DF",  "AW", "AW",
           "PV", "PV", "PV",  "MW", "MW",  "RS",  "NW", "NW",  "DF",  "AW", "AW", "AW", "RS"),
  party = c("IND", "IND", "IND", "ALP",  "IND", "IND",  "IND",  "ALP", "ALP", "IND",  "IND", "ALP",
            "IND", "ALP", "GRN",  "IND", "IND",  "IND",  "ALP", "IND",  "IND",  "OTH", "IND", "ALP", "ALP"),
  surname = c("YILDIZ", "KAVANAGH", "TIMPANO", "BLANDTHORN",  "NORTHE", "LUND",  "MARTIN",  "ALPA",
              "JONES", "OLD",  "SMITH", "ALPB",
              "BOLTON", "BLANDTHORN", "PANOPOULOS",  "LUND", "NEWBIE",  "MARTIN",  "ALPA", "FRESH",
              "JONES",  "SMITH", "FAY", "ALPB", "ALPC"),
  given = c("Oscar", "John", "Francesco", "Anthony",  "Russell", "Tracie",  "Clarke",  "Al",
            "Bob", "Al",  "Jane", "Bo",
            "Sue", "Anthony", "Angelica",  "Tracie", "Nat",  "Clarke",  "Al", "Fran",
            "Bob",  "Jane", "Fay", "Bo", "Cy"),
  name = NA_character_,
  pcv = c(23.5, 7.7, 1.7, 37.7,  19.6, 2.1,  8.4,  50, 30, 10,  20, 40,
          4.2, 38.8, 22.4,  2.8, 5,  6.9,  50, 3,  25,  10, 4, 40, 40),
  elected = FALSE)

test_that("class_gap_restand is FALSE only where no earlier IND candidate re-stands", {
  r <- candidate_returns("e1", "e2", mk_gap())
  g <- function(s) r$class_gap_restand[r$seat == s & r$party == "IND"]
  expect_false(g("PV"))   # Yildiz, Kavanagh, Timpano all gone; Bolton is new
  expect_true(g("MW"))    # Lund (IND both times) re-stands
  expect_true(g("RS"))    # Martin re-stands
  expect_true(g("NW"))    # no IND at e1: nothing to drop
  expect_true(g("DF"))    # Jones led IND at e2 and stood here at e1 (as ALP)
  expect_false(g("AW"))   # Smith re-stands as OTH; the IND (Fay) inherits none of it
  expect_false(anyNA(r$class_gap_restand))
})

test_that("the slope on the gap is 0 with the switch on and unchanged with it off", {
  r <- candidate_returns("e1", "e2", mk_gap())
  seats <- c("PV", "MW", "RS", "NW", "DF", "AW")
  pm <- rep(FALSE, length(seats))
  off <- screened_slopes("IND", seats, r, pm, honour_departed = TRUE)
  on  <- screened_slopes("IND", seats, r, pm, honour_departed = TRUE, gap_restand = TRUE)
  expect_identical(off, screened_slopes("IND", seats, r, pm, honour_departed = TRUE, gap_restand = FALSE))
  expect_true(all(off > 0))
  expect_equal(on[seats %in% c("PV", "AW")], c(0, 0))
  keep <- !seats %in% c("PV", "AW")
  expect_equal(on[keep], off[keep])
  # what the base does with it: PV starts from the statewide level, the gap is gone
  x <- 32.9; lvl_prev <- 6.07; lvl_now <- 6.76
  expect_equal(dev_slope(x, lvl_prev, lvl_now, on[1]), lvl_now)
  expect_gt(dev_slope(x, lvl_prev, lvl_now, off[1]), lvl_now + 5)
  # conditional_slopes (the unscreened path) applies the same rule
  c_on <- conditional_slopes("IND", seats, r, gap_restand = TRUE)
  expect_equal(c_on[seats %in% c("PV", "AW")], c(0, 0))
  expect_equal(c_on[keep], conditional_slopes("IND", seats, r)[keep])
})

test_that("a screen-permitted newcomer and a coded successor are left alone", {
  r <- candidate_returns("e1", "e2", mk_gap())
  seats <- c("PV", "AW")
  on_perm <- screened_slopes("IND", seats, r, c(TRUE, FALSE), honour_departed = TRUE, gap_restand = TRUE)
  expect_equal(on_perm, c(1, 0))
  succ <- screened_slopes("IND", seats, r, c(FALSE, FALSE), honour_departed = TRUE, gap_restand = TRUE,
                          successor_rate = c(PV = 0.51))
  expect_equal(succ, c(0.51, 0))
})

test_that("only the IND class is touched", {
  r <- candidate_returns("e1", "e2", mk_gap())
  expect_identical(ind_gap_drop("GRN", "PV", r), FALSE)
  expect_identical(ind_gap_drop("IND", c("PV", "nowhere"), r), c(TRUE, FALSE))
})

test_that("a returns table without the column is an error, not a silent no-op", {
  r <- candidate_returns("e1", "e2", mk_gap())
  r$class_gap_restand <- NULL
  expect_error(ind_gap_drop("IND", "PV", r), "class_gap_restand")
  expect_error(screened_slopes("IND", "PV", r, FALSE, gap_restand = TRUE), "class_gap_restand")
})

test_that("the switch is validated and registered as post-xgb", {
  withr::local_envvar(AUSPOL_IND_GAP_RESTAND = "yes")
  expect_error(ind_gap_restand_mode(), "must be")
  withr::local_envvar(AUSPOL_IND_GAP_RESTAND = "1")
  expect_true("AUSPOL_IND_GAP_RESTAND" %in% names(post_xgb_switches()))
  withr::local_envvar(AUSPOL_IND_GAP_RESTAND = "0")
  expect_false("AUSPOL_IND_GAP_RESTAND" %in% names(post_xgb_switches()))
})
