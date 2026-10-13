// Candidate-level Hare-Clark count on weighted ballot types, for simulation.
//
// Fast, not exact: the validated ACT engine (scripts/hare_clark_count.R) moves only the LAST PARCEL of a
// surplus, carries six decimal places and stages each exclusion by transfer value. This one moves EVERY
// paper an elected candidate holds at a reduced value (inclusive Gregory), with no rounding, and excludes
// a candidate in one step. It exists because the exact engine takes ~2 s a count and a forecast needs
// thousands; how much the simplification costs is measured by running both on real ballots
// (scripts/backtest_hare_clark.R --oracle reports it).
//
// seq: n_types x L matrix of 0-based candidate indices, -1 after the last preference.
// w:   ballots of each type (any non-negative real; re-weighting is the point).
// Returns the 0/1 elected flag per candidate.
#include <Rcpp.h>
#include <vector>
#include <deque>
using namespace Rcpp;

// [[Rcpp::export]]
IntegerVector hc_stv_cpp(IntegerMatrix seq, NumericVector w, int ncand, int seats) {
  const int n = seq.nrow(), L = seq.ncol();
  std::vector<int> cur(n, -1), status(ncand, 0);      // status 0 continuing, 1 elected, 2 excluded
  std::vector<double> val(n, 1.0), tally(ncand, 0.0);
  double total = 0.0;
  std::vector<std::vector<int> > hold(ncand);   // ballot types currently sitting with each candidate
  for (int t = 0; t < n; ++t) {
    int c = seq(t, 0);
    if (c < 0 || c >= ncand || w[t] <= 0) continue;
    cur[t] = 0; tally[c] += w[t]; total += w[t]; hold[c].push_back(t);
  }
  const double q = std::floor(total / (seats + 1)) + 1.0;
  int elected = 0, n_cont = ncand;
  std::deque<int> queue;
  auto next_pos = [&](int t) {
    int p = cur[t] + 1;
    while (p < L) {
      int c = seq(t, p);
      if (c < 0) return -1;
      if (status[c] == 0) return p;
      ++p;
    }
    return -1;
  };
  int guard = 0;
  while (elected < seats && n_cont > 0) {
    if (++guard > 10 * (ncand + seats) + 10) stop("hc_stv_cpp: no progress");
    // elect everyone at or above quota, largest first
    bool any = true;
    while (any && elected < seats) {
      any = false; int best = -1;
      for (int c = 0; c < ncand; ++c) if (status[c] == 0 && tally[c] >= q && (best < 0 || tally[c] > tally[best])) best = c;
      if (best >= 0) { status[best] = 1; --n_cont; ++elected; queue.push_back(best); any = true; }
    }
    if (elected >= seats) break;
    if (n_cont <= seats - elected) {
      for (int c = 0; c < ncand; ++c) if (status[c] == 0) { status[c] = 1; ++elected; }
      break;
    }
    if (!queue.empty()) {
      int e = queue.front(); queue.pop_front();
      double s = tally[e] - q;
      if (s <= 0) continue;
      double tr = 0.0;
      std::vector<int> mine; mine.swap(hold[e]);
      std::vector<int> np(mine.size(), -1);
      for (size_t i = 0; i < mine.size(); ++i) {
        np[i] = next_pos(mine[i]);
        if (np[i] >= 0) tr += w[mine[i]] * val[mine[i]];
      }
      double f = tr > 0 ? std::min(1.0, s / tr) : 0.0;
      for (size_t i = 0; i < mine.size(); ++i) {
        int t = mine[i];
        if (np[i] >= 0) { val[t] *= f; cur[t] = np[i]; int c = seq(t, cur[t]); tally[c] += w[t] * val[t]; hold[c].push_back(t); }
        else cur[t] = -1;
      }
      tally[e] = q;
      continue;
    }
    int x = -1;
    for (int c = 0; c < ncand; ++c) if (status[c] == 0 && (x < 0 || tally[c] < tally[x])) x = c;
    status[x] = 2; --n_cont;
    std::vector<int> mine; mine.swap(hold[x]);
    for (size_t i = 0; i < mine.size(); ++i) {
      int t = mine[i];
      int p = next_pos(t);
      if (p >= 0) { cur[t] = p; int c = seq(t, p); tally[c] += w[t] * val[t]; hold[c].push_back(t); } else cur[t] = -1;
    }
    tally[x] = 0.0;
  }
  IntegerVector out(ncand);
  for (int c = 0; c < ncand; ++c) out[c] = status[c] == 1 ? 1 : 0;
  return out;
}
