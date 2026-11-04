# The booth REFERENCE for the 2026 Victorian election night: 2022 booths for 87 districts, plus Narracan's 2018
# booths.
#
# Narracan has no 2022 booths: its 2022 poll was deferred to a supplementary election on 28 Jan 2023, which had NO
# Labor and NO Nationals candidate (Liberal 16,741, Greens 4,132, IND Wolfe 4,110, DLP 2,641, Freedom 2,254, One
# Nation 2,246), so it cannot give the Labor-minus-Coalition booth swing. Pete chose the 2018 booths, matched by
# booth name (5 Nov 2026; overnight-2026-11-04.md item 1). The cost: 2018 is before the 2021 redistribution, so some
# 2026 centres will not match and count as new, and a matched one may cover a different area.
#
# booths-vic2022.csv itself is left as it is: the 2018 -> 2022 replays read it as the LIVE count, and 2018 rows there
# would read as a Narracan swing of exactly zero.
#
# Writes output/booths-vic2026-ref.csv and output/booths-vic2026-ref-2cp.csv: the columns of booths-vic2022.csv plus
# ref_year (2022, or 2018 for Narracan). The night runner takes it as --ref.
# Emits BRF* codes.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
ref_district <- "Narracan"
fp22 <- fread("output/booths-vic2022.csv"); tc22 <- fread("output/booths-vic2022-2cp.csv")
fp18 <- fread("output/booths-vic2018.csv"); tc18 <- fread("output/booths-vic2018-2cp.csv")
cat(sprintf("BRF0  2022: %d FP rows, %d districts; 2018: %d FP rows, %d districts\n",
            nrow(fp22), uniqueN(fp22$district), nrow(fp18), uniqueN(fp18$district)))
if (!identical(names(fp22), names(fp18)) || !identical(names(tc22), names(tc18))) stop("BRF1! 2018 and 2022 booth tables have different columns")
if (uniqueN(fp22$district) != 87L) stop("BRF1! expected 87 districts in booths-vic2022.csv, got ", uniqueN(fp22$district))
if (ref_district %in% fp22$district || ref_district %in% tc22$district) stop("BRF1! ", ref_district, " is already in the 2022 file: this splice is no longer needed")
add_fp <- fp18[fp18$district == ref_district]; add_tc <- tc18[tc18$district == ref_district]
if (!nrow(add_fp) || !nrow(add_tc)) stop("BRF1! no 2018 rows for ", ref_district)
# Coverage, not presence: both majors must be in the 2018 rows, or the splice cannot give a Labor-minus-Coalition swing.
cl <- unique(classify_party(add_fp$party))
if (!all(c("ALP", "LNP") %in% cl)) stop("BRF2! 2018 ", ref_district, " lacks Labor or the Coalition: classes ", paste(cl, collapse = ","))
fp <- rbind(fp22[, ref_year := 2022L], add_fp[, ref_year := 2018L])
tc <- rbind(tc22[, ref_year := 2022L], add_tc[, ref_year := 2018L])
if (uniqueN(fp$district) != 88L || uniqueN(tc$district) != 88L) stop("BRF3! expected 88 districts after the splice")
cat(sprintf("BRF3  %s 2018: %d FP rows (%d ordinary booths), %d 2CP rows; classes %s. Now 88 districts.\n",
            ref_district, nrow(add_fp), uniqueN(add_fp[booth_type == "ordinary", booth]), nrow(add_tc), paste(sort(cl), collapse = ",")))
fwrite(fp, "output/booths-vic2026-ref.csv"); fwrite(tc, "output/booths-vic2026-ref-2cp.csv")
cat("BRF4  wrote output/booths-vic2026-ref.csv and output/booths-vic2026-ref-2cp.csv\n")
