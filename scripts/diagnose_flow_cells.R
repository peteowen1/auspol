options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
P <- election_data_path()

# the flow matrix the SA harness uses
tx <- fread(file.path(P, "aec-fed-transfers.csv"), showProgress = FALSE)[election == "fed2025"]
fm <- build_flow_matrix(tx, min_n = 3L)

cat("=== THE DECISIVE CELL: ALP excluded, ONP and LNP both surviving ===\n")
cat("If ALP preferences go overwhelmingly to LNP, One Nation loses Hammond\n")
cat("and Ngadjuri even while LEADING the primaries.\n\n")

show_cell <- function(from, surv) {
  key <- paste0(from, "|", paste(sort(surv), collapse = "+"))
  r <- fm$conditional[[key]]
  if (is.null(r)) {
    cat(sprintf("  %-28s NO CELL -> falls back to pooled\n", key))
    r <- fm$pooled[[from]]
    lbl <- sprintf("pooled %s", from)
  } else lbl <- key
  if (is.null(r)) { cat("   (no pooled rate either)\n"); return(invisible()) }
  r <- r[order(-r)]
  cat(sprintf("  %-34s %s\n", lbl,
              paste(sprintf("%s %.1f%%", names(r), 100*r/sum(r)), collapse = "  ")))
}

show_cell("ALP", c("ONP","LNP"))
show_cell("ALP", c("ONP","LNP","GRN"))
show_cell("GRN", c("ONP","LNP"))
show_cell("GRN", c("ONP","LNP","ALP"))
show_cell("LNP", c("ONP","ALP"))

cat("\n=== what SA 2026 ACTUALLY did (its own transfer file) ===\n")
sa <- fread(file.path(P, "ecsa-2026-sa-transfers.csv"), showProgress = FALSE)
for (f in c("ALP","GRN","LNP")) {
  o <- sa[from == f]
  if (!nrow(o)) next
  agg <- o[, .(v = sum(votes)), by = to][order(-v)]
  agg[, share := round(100*v/sum(v), 1)]
  cat(sprintf("  %-4s -> %s\n", f,
              paste(sprintf("%s %.1f%%", agg$to, agg$share), collapse = "  ")))
}

cat("\n=== ARE FLOWS TREATED AS CERTAIN? ===\n")
cat("simulate_seat_contests() takes `matrix` as a fixed object. Checking\n")
cat("whether any per-draw flow noise exists in the signature:\n")
fa <- names(formals(simulate_seat_contests))
cat("  args:", paste(fa, collapse = ", "), "\n")
cat(sprintf("  any flow-uncertainty argument? %s\n",
            if (any(grepl("flow", fa, ignore.case = TRUE))) "yes" else "NO"))
