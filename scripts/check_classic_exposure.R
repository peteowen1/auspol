# What does simulate_seats() assume about who can win, and what did that cost?
#
# simulate_seats() simulates only seats flagged `classic` -- a Labor-versus-
# Liberal contest -- and holds every other seat at its current incumbent with
# probability 1. So the model can return exactly two answers per simulated seat
# and exactly one answer per unsimulated one.
#
# South Australia, five months ago, is the test: 2026sa.txt flagged 44 of 47 as
# classic before the election, and the ECSA returns say what actually happened.
# This scores that assumption directly -- not "was the margin right" but "could
# the right winner have come out at all" -- and then reports Victoria 2026's
# exposure on the same terms.
#
# Emits CE* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

ECSA <- file.path("external", "reference", "ecsa", "sa2026-districts.csv")
if (!file.exists(ECSA)) stop("Run scripts/fetch_sa2026.py first.")
e <- fread(ECSA, showProgress = FALSE)
sa <- merge(as.data.table(load_seats(2026L, "sa")),
            e[, .(seat, winner, runner_up)], by = "seat")

cat(sprintf("\nCE1  South Australia 2026: %d seats, %d flagged classic before the poll\n",
            nrow(sa), sum(sa$classic)))

# ---- the sharp question: could the model have produced the right winner? ----
# For a classic seat the model can only ever return ALP or LNP. For a
# non-classic seat it returns the incumbent, always.
sa[, model_can_return := fifelse(classic, "ALP or LNP", incumbent)]
sa[, reachable := fifelse(classic, winner %in% c("ALP", "LIB"),
                          winner == incumbent)]
cat(sprintf("CE2  seats whose ACTUAL winner the model could not have produced: %d of %d\n",
            sum(!sa$reachable), nrow(sa)))
print(sa[reachable == FALSE,
         .(seat, classic, incumbent, margin, winner, runner_up)][order(seat)])

cat(sprintf("\nCE3  of the %d flagged classic, %d were won by neither major\n",
            sum(sa$classic), nrow(sa[classic == TRUE & !winner %in% c("ALP", "LIB")])))
cat(sprintf("CE3  of the %d flagged non-classic, %d changed hands\n",
            sum(!sa$classic), nrow(sa[classic == FALSE & winner != incumbent])))
if (nrow(sa[classic == FALSE])) {
  print(sa[classic == FALSE, .(seat, incumbent, winner,
                               held = winner == incumbent)])
}

# A weaker check, and the one that flatters the model: even where the winner was
# reachable, was the CONTEST the one assumed? A seat where Labor beat One Nation
# is a Labor win the model gets right for the wrong reason.
cat(sprintf("\nCE4  seats where the right winner emerged from the WRONG contest: %d\n",
            nrow(sa[reachable == TRUE & classic == TRUE &
                      !(winner %in% c("ALP", "LIB") & runner_up %in% c("ALP", "LIB"))])))
cat("CE4  these are correct answers reached by assuming a two-party race that\n")
cat("CE4  did not happen, so they are not evidence the assumption held.\n")

# ---- Victoria 2026 exposure -------------------------------------------------
vic <- as.data.table(load_seats(2026L, "vic"))
cat(sprintf("\nCE5  Victoria 2026: %d seats, %d classic, %d held aside at their incumbent\n",
            nrow(vic), sum(vic$classic), sum(!vic$classic)))
if (sum(!vic$classic)) {
  cat("CE5  the seats returned with certainty, whatever the polls do:\n")
  print(vic[classic == FALSE, .(seat, incumbent, challenger, margin)])
}
cat(sprintf("CE5  Labor's floor from those: %d seats\n",
            sum(vic$incumbent == "ALP" & !vic$classic)))

# The SA rate is NOT a forecast for Victoria -- different state, different
# party system, different One Nation base. It is a magnitude: how far a
# pre-election classic flag was from the outcome in the nearest comparable
# election.
rate <- nrow(sa[classic == TRUE & !winner %in% c("ALP", "LIB")]) / sum(sa$classic)
cat(sprintf("\nCE6  SA rate of flagged-classic seats won by neither major: %.1f%%\n",
            100 * rate))
cat(sprintf("CE6  applied to Victoria's %d classic seats that would be %.1f seats\n",
            sum(vic$classic), rate * sum(vic$classic)))
cat("CE6  THIS IS A MAGNITUDE, NOT A FORECAST. It assumes Victoria behaves like\n")
cat("CE6  South Australia, which is the thing nobody knows. It is here to show\n")
cat("CE6  whether the exposure is worth attention, not to predict anything.\n")
