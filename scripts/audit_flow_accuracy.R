options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet=TRUE)); suppressMessages(library(data.table))
TX <- fread(file.path(election_data_path(),"aec-fed-transfers.csv"), showProgress=FALSE)
PRIORS <- strsplit(Sys.getenv("AUD_PRIORS","fed2022"), ",")[[1]]
fm <- build_flow_matrix(TX[election %in% PRIORS], min_n=3L)
cat("matrix built from:", paste(PRIORS, collapse="+"), "
")
A  <- TX[election=="fed2025"]
key <- A[, .(surv = paste(sort(unique(to)), collapse="+"), tot = sum(votes)),
         by=.(seat, round, from)]
A2 <- merge(A, key, by=c("seat","round","from"))
act <- A2[, .(votes=sum(votes), tot=tot[1], surv=surv[1]), by=.(seat, round, from, to)]
act[, actual := 100*votes/tot]

pred_for <- function(from, surv) {
  al <- sort(unique(strsplit(surv, "+", fixed=TRUE)[[1]]))
  src <- "pooled"
  r <- fm$conditional[[paste0(from,"|",paste(al, collapse="+"))]]
  if (!is.null(r)) src <- "exact"
  if (is.null(r) && !is.null(fm$superset)) {
    r <- fm$superset[[paste0(from,"|",paste(al, collapse="+"))]]
    if (!is.null(r)) src <- "superset"
  }
  if (is.null(r) && !is.null(fm$pairwise)) { r <- fm$pairwise[[from]]; if (!is.null(r)) src <- "pairwise" }
  if (is.null(r)) r <- fm$pooled[[from]]
  r <- r[intersect(names(r), al)]
  if (!length(r) || sum(r) <= 0) return(NULL)
  data.table(to=names(r), pred=100*as.numeric(r)/sum(r), src=src)
}
combos <- unique(act[, .(from, surv)])
P <- rbindlist(lapply(seq_len(nrow(combos)), function(i) {
  x <- pred_for(combos$from[i], combos$surv[i]); if (is.null(x)) return(NULL)
  x[, `:=`(from=combos$from[i], surv=combos$surv[i])][] }), fill=TRUE)
M <- merge(act, P, by=c("from","surv","to"), all.x=TRUE)
M[is.na(pred), pred := 0]
M[, err := pred - actual]
M[, wt := tot]
cat(sprintf("exclusion-destination rows: %d | vote-weighted MAE %.2f pts\n",
            nrow(M), sum(abs(M$err)*M$wt)/sum(M$wt)))
cat("\nBY FALLBACK SOURCE (vote-weighted):\n")
print(M[, .(rows=.N, votes=sum(wt), wMAE=round(sum(abs(err)*wt)/sum(wt),2)), by=src][order(-votes)])
cat("\nWORST (from -> to) FLOWS, vote-weighted:\n")
agg <- M[, .(votes=sum(wt), wMAE=round(sum(abs(err)*wt)/sum(wt),2),
             mean_actual=round(sum(actual*wt)/sum(wt),1),
             mean_pred=round(sum(pred*wt)/sum(wt),1)), by=.(from,to)]
agg[, bias := round(mean_pred-mean_actual,1)]
print(agg[order(-abs(bias)*votes)][1:15])

