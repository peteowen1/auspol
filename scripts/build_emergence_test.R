# The narrow test: can Google Trends separate a non-major who WON a seat we
# called hopeless from one who did not?
#
# WHY THIS AND NOT THE AUC. The full-corpus salience AUC came back 0.560 --
# barely above chance, and below chance in Victoria and Queensland. But that
# measured "predicts >= 20% of first preferences" across every non-major
# candidacy, which is not the job. The anchor check on known seats says the
# model handles sitting independents well (0.75-0.95) and fails only on
# TRANSITIONS: North Sydney, Fowler and Goldstein 2022 all came in at 0.0000.
# So the question worth asking is much narrower -- can the signal separate the
# ~7 seats per wave election that the model cannot see at all?
#
# GROUP A: a non-major won and our model gave the winner under 5%.
# GROUP B: a non-major stood and did not win, from the same elections.
#
# ANCHOR: the RE-CONTESTING INCUMBENT, per Pete's preference -- the person the
# challenger is actually running against, which is the comparison a voter makes.
# Where the incumbent is not re-contesting (a retirement, which is exactly when
# these seats fall) there is no such person, so those rows are marked for a
# fallback anchor rather than silently dropped.
#
# NO LEAKAGE: the query window ends the day BEFORE polling day and spans the
# preceding week only. Nothing from the count can reach it.
#
# Emits EM* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

MAJ <- c("ALP", "LNP", "NAT")
C <- fread("output/candidacies.csv", showProgress = FALSE)

# Our predicted probability for the party that actually won, per seat-election.
ARM <- "output/backtest-fed-sh10-fb60-fsd365-n5000-sh10.csv"
if (!file.exists(ARM)) stop("need ", ARM)
P <- fread(ARM, showProgress = FALSE)[, .(election = pair, seat, actual,
                                          gave_winner = prob)]

# Federal only: it is the only region with an `elected` flag per candidate, so
# it is the only one where the winner's NAME -- and therefore whether the
# incumbent re-contested -- is known without another join.
F <- C[region == "fed"]
setorder(F, year, seat)

# Who won each seat, by name, per election.
WIN <- F[elected == TRUE, .(winner_name = name[1], winner_party = party[1],
                            winner_given = given[1], winner_surname = surname[1]),
         by = .(year, seat)]
YRS <- sort(unique(F$year))
nxt <- data.table(year = YRS[-length(YRS)], to = YRS[-1])
prev <- merge(WIN, nxt, by = "year")[, .(year = to, seat,
                                         inc_name = winner_name,
                                         inc_given = winner_given,
                                         inc_surname = winner_surname,
                                         inc_party = winner_party)]

D <- merge(F, prev, by = c("year", "seat"), all.x = TRUE)
D[, election := sprintf("fed%d", year)]
# Is the sitting member on this ballot?
D[, inc_running := !is.na(inc_name) & inc_name %in% name, by = .(election, seat)]

D <- merge(D, P, by = c("election", "seat"), all.x = TRUE)
D[, won := elected == TRUE]

nm <- D[!party %in% MAJ & !is.na(inc_name)]
cat(sprintf("EM1  %d non-major candidacies with a known prior incumbent\n", nrow(nm)))

# ---- GROUP A: won, and we gave the winning party under 5% -------------------
A <- nm[won == TRUE & is.finite(gave_winner) & gave_winner < 0.05]
cat(sprintf("EM2  GROUP A -- won but we said under 5%%: %d\n", nrow(A)))
print(A[order(-pcv), .(election, seat, name, party, pct = round(pcv, 1),
                       our_p = round(gave_winner, 4),
                       incumbent = inc_name, inc_running)], row.names = FALSE)

# ---- GROUP B: stood, did not win -------------------------------------------
# Drawn from the SAME elections as group A, and from the stronger half of the
# field, so the comparison is not "famous winner versus no-hoper" -- which any
# signal would pass. Seeded.
set.seed(20260826L)
B <- nm[won == FALSE & election %in% unique(A$election) & pcv >= 5]
B <- B[sample(.N, min(.N, 2L * nrow(A)))]
cat(sprintf("\nEM3  GROUP B -- stood, lost, polled >= 5%%: %d\n", nrow(B)))
print(B[order(-pcv), .(election, seat, name, party, pct = round(pcv, 1),
                       incumbent = inc_name, inc_running)][1:min(20, nrow(B))],
      row.names = FALSE)

A[, hand_added := FALSE]

# HAND-ADDED, AND FLAGGED AS SUCH. Pete asked for Allegra Spender's first win
# (Wentworth 2022) as a case he knows well enough to check the output against.
# She does NOT meet the automatic criterion: the model gave her 0.396, not under
# 0.05, because Kerryn Phelps had already run there and the seat's independent
# history was visible. So she is a useful sanity case but NOT a model failure,
# and counting her among the failures would flatter the signal -- an emergence
# the model already half-saw is easier to detect. Every result below is reported
# with and without the hand-added rows for that reason.
HAND <- nm[election == "fed2022" & seat == "Wentworth" & won == TRUE &
             !party %in% MAJ]
if (nrow(HAND)) {
  HAND[, hand_added := TRUE]
  cat(sprintf("\nEM2h hand-added %d row(s): %s (%s, %.1f%%, our_p %.4f)\n",
              nrow(HAND), HAND$name[1], HAND$seat[1], HAND$pcv[1],
              HAND$gave_winner[1]))
  A <- rbind(A, HAND[!name %in% A$name], fill = TRUE)
} else cat("\nEM2h hand-add FAILED: no Wentworth 2022 non-major winner found\n")

B[, hand_added := FALSE]
S <- rbind(A[, grp := "A_won"], B[, grp := "B_lost"], fill = TRUE)
# CARRY given/surname SO THE QUERY CAN DROP MIDDLE NAMES. Google is searched
# for "Kylea Tink", not the AEC's legal "Kylea Jane Tink", and querying the
# legal form returned 0.000 for both her and Clive Frederick Palmer -- two of
# the most searched names in the sample. plan-wire-salience-into-forecast.md
# already recorded that fixing exactly this lifted the 2022 AUC from 0.830 to
# 0.854, and the raw name was used anyway.
#
# The two fields are used rather than a first-word/last-word heuristic because
# that heuristic turns "Dominic WY KANAK" into "Dominic Kanak".
S <- S[, .(grp, election, year, seat, name, given, surname, party, pcv, won,
           our_p = gave_winner, inc_name, inc_given, inc_surname, inc_running,
           hand_added)]
fwrite(S, "output/emergence-test.csv")
cat(sprintf("\nEM9  wrote output/emergence-test.csv: %d rows (%d won, %d lost)\n",
            nrow(S), sum(S$grp == "A_won"), sum(S$grp == "B_lost")))
cat(sprintf("EM9  incumbent re-contesting in %d of %d rows; the rest need a fallback anchor\n",
            sum(S$inc_running), nrow(S)))
