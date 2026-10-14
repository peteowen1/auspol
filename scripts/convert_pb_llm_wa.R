# WA extractions (Liberal and National separate) -> the scorer's columns. load_polls("wa") keeps LIB as LNP and NAT
# apart, so coalition := liberal; a combined-only figure cannot be split and is left blank (kept in coalition_combined).
library(data.table)
for (f in list.files(Sys.getenv("AUSPOL_PB_LLM_DIR", "deciding-runs/pb-llm"), pattern = "-wa-polls\\.csv$", full.names = TRUE)) {
  x <- as.data.table(read.csv(f, colClasses = "character", na.strings = ""))
  x[, coalition := liberal]
  out <- sub("-wa-polls\\.csv$", "-polls.csv", f)
  fwrite(x, out)
  cat(basename(f), "->", basename(out), nrow(x), "rows;", sum(!is.na(x$liberal)), "with a Liberal figure;",
      sum(!is.na(x$coalition_combined) & is.na(x$liberal)), "combined only\n")
}
