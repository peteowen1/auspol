options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
P <- election_data_path()
pc <- function(f) { d <- fread(file.path(P,f), showProgress=FALSE)
  d[, tot := sum(votes), by=seat]; d[, p := 100*votes/tot]; d }
a <- pc("ecsa-2022-sa-firstprefs.csv"); b <- pc("ecsa-2026-sa-firstprefs.csv")
st_a <- a[, .(v=sum(votes)), by=party][, setNames(100*v/sum(v), party)]
st_b <- b[, .(v=sum(votes)), by=party][, setNames(100*v/sum(v), party)]

m <- a[seat=="MacKillop", setNames(p, party)]
act <- b[seat=="MacKillop", setNames(p, party)]
PARTIES <- union(names(m), names(act))
g <- function(v,p) if (p %in% names(v)) v[[p]] else 0

cat("=== MacKillop, party by party ===\n")
cat(sprintf("%-10s %8s %10s %10s %10s %8s\n","party","2022","uniform","elastic","+renorm","ACTUAL"))
uni <- ela <- setNames(numeric(length(PARTIES)), PARTIES)
for (p in PARTIES) {
  d <- g(st_b,p) - g(st_a,p)
  uni[p] <- max(0, g(m,p) + d)
  ela[p] <- if (d < -2 && g(st_a,p) > 0 && g(m,p)/g(st_a,p) > 1.5)
              max(0, g(m,p) * g(st_b,p) / g(st_a,p)) else uni[p]
}
uni_n <- 100*uni/sum(uni); ela_n <- 100*ela/sum(ela)
for (p in c("LNP","ONP","ALP","GRN")) {
  cat(sprintf("%-10s %8.1f %10.1f %10.1f %10.1f %8.1f\n",
              p, g(m,p), uni_n[[p]], ela[[p]], ela_n[[p]], g(act,p)))
}
cat(sprintf("\nsum before renormalising: uniform %.1f | elastic %.1f\n", sum(uni), sum(ela)))
cat(sprintf("renormalisation scales elastic by x%.3f\n", 100/sum(ela)))
cat(sprintf("\nLNP: elasticity cuts it to %.1f, renormalisation puts it back to %.1f\n",
            ela[["LNP"]], ela_n[["LNP"]]))
cat(sprintf("     %.0f%% of the cut is undone. Actual was %.1f.\n",
            100*(ela_n[["LNP"]]-ela[["LNP"]])/(uni_n[["LNP"]]-ela[["LNP"]]), g(act,"LNP")))
