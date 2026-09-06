// The per-draw core of simulate_seat_contests(), ported from R on 2026-09-07.
//
// THE CONTRACT IS BYTE-IDENTICAL OUTPUT. Every random number is drawn from R's
// own generator, in the same order the R loop drew it (R::rnorm, R::runif,
// R_unif_index), every sum is accumulated in long double exactly as R's sum()
// does, and every arithmetic expression keeps the R evaluation order (so
// `v[others] * (pool_v - add) / pool_v` is (v * (pool_v - add)) / pool_v, not
// v * ((pool_v - add) / pool_v)). tests/testthat/test-seat-sim.R asserts
// identical() against the R engine with every mechanism switched on, and a
// full federal run was compared byte for byte before this shipped.
//
// Anything the R loop does that this does not is handled by the R engine:
// `party_draws`, and a party count too large for the dense cell tables.
#include <Rcpp.h>
using namespace Rcpp;

static inline double ld_sum(const std::vector<double>& x, const std::vector<int>& idx) {
  long double s = 0.0L;
  for (size_t t = 0; t < idx.size(); ++t) s += x[idx[t]];
  return (double) s;
}

// [[Rcpp::export]]
List seat_sim_core(NumericMatrix shares, int n_sims, int shift_mode,
                   NumericMatrix shift_mat, NumericVector sd_vec, NumericMatrix chol_t,
                   NumericVector seat_sd_vec, bool has_level, NumericMatrix sd_cell_pre,
                   NumericVector surge_h, IntegerVector surge_party_idx, IntegerVector surge_idx,
                   double surge_floor, double surge_mu, double surge_sd,
                   bool surge_from_zero,
                   NumericMatrix cell_mat, LogicalVector cell_has,
                   NumericMatrix ss_mat, LogicalVector ss_has,
                   NumericMatrix pool_mat, bool has_pw, NumericMatrix pw_mat,
                   NumericVector flow_sd_by, double smooth, double fallback_smooth,
                   NumericVector shrink) {
  const int nseat = shares.nrow(), K = shares.ncol();
  IntegerMatrix wins(nseat, K), totals(n_sims, K);
  IntegerMatrix tcp_w(n_sims, nseat), tcp_r(n_sims, nseat);
  NumericMatrix tcp_share(n_sims, nseat);
  std::fill(tcp_w.begin(), tcp_w.end(), NA_INTEGER);
  std::fill(tcp_r.begin(), tcp_r.end(), NA_INTEGER);
  std::fill(tcp_share.begin(), tcp_share.end(), NA_REAL);
  long long n_fb = 0, n_tx = 0, n_recipient_fb_draw = 0;
  const double pow2K = std::ldexp(1.0, K);   // 2^K, exact
  const int n_surge = surge_idx.size();
  const bool surge_any = n_surge > 0;

  std::vector<double> shift(K), z(K), v(K), base(K), sdc(K), p, w;
  std::vector<int> alive, cand;
  alive.reserve(K); cand.reserve(K); p.reserve(K); w.reserve(K);

  RNGScope scope;
  Function matprod("%*%");
  for (int s = 0; s < n_sims; ++s) {
    // ---- statewide shift for this draw, in the R loop's RNG order ----
    if (shift_mode == 0) {
      for (int k = 0; k < K; ++k) shift[k] = shift_mat(s, k);
    } else if (shift_mode == 1) {
      for (int k = 0; k < K; ++k) shift[k] = R::rnorm(0.0, sd_vec[k]);
    } else {
      // The R loop does `as.vector(chol_t %*% rnorm(K)) * sd_vec`. The product
      // is R's own `%*%`, i.e. whatever BLAS this R links to -- a hand-written
      // accumulation matched reference BLAS on Windows and NOT the Linux CI
      // runner's BLAS (last-bit differences, 2026-09-07). So the product is
      // delegated to R's `%*%` itself, which makes the identity hold on any
      // platform by construction. 20,000 calls cost well under a second.
      NumericVector zz(K);
      for (int k = 0; k < K; ++k) zz[k] = R::rnorm(0.0, 1.0);
      NumericVector y = matprod(chol_t, zz);
      for (int k = 0; k < K; ++k) shift[k] = y[k] * sd_vec[k];
    }
    for (int i = 0; i < nseat; ++i) {
      for (int k = 0; k < K; ++k) base[k] = shares(i, k);
      if (!has_level) { for (int k = 0; k < K; ++k) sdc[k] = seat_sd_vec[k]; }
      else { for (int k = 0; k < K; ++k) sdc[k] = sd_cell_pre(i, k); }
      for (int k = 0; k < K; ++k) {
        const double e = R::rnorm(0.0, sdc[k]);
        v[k] = base[k] + shift[k] + e;
        if (v[k] < 0) v[k] = 0;
      }
      // ---- insurgency surge ----
      if (surge_h[i] > 0 && surge_any) {
        int j0 = surge_party_idx[i];              // 1-based or NA
        if (j0 != NA_INTEGER && v[j0 - 1] <= 0 && !surge_from_zero) { j0 = NA_INTEGER; ++n_recipient_fb_draw; }
        cand.clear();
        if (j0 != NA_INTEGER) cand.push_back(j0 - 1);
        else for (int t = 0; t < n_surge; ++t) { const int c = surge_idx[t] - 1; if (v[c] >= surge_floor) cand.push_back(c); }
        if (!cand.empty() && R::runif(0.0, 1.0) < surge_h[i]) {
          int j;
          if (j0 != NA_INTEGER) j = j0 - 1;
          else { j = cand[0]; for (size_t t = 1; t < cand.size(); ++t) if (v[cand[t]] > v[j]) j = cand[t]; }
          const double add = R::rnorm(surge_mu, surge_sd);
          if (add > 0) {
            long double pv = 0.0L;
            for (int k = 0; k < K; ++k) if (k != j) pv += v[k];
            const double pool_v = (double) pv;
            if (pool_v > add) {
              for (int k = 0; k < K; ++k) if (k != j) v[k] = (v[k] * (pool_v - add)) / pool_v;
              v[j] = v[j] + add;
            }
          }
        }
      }
      // ---- eliminations ----
      alive.clear();
      for (int k = 0; k < K; ++k) if (v[k] > 0) alive.push_back(k);
      while (alive.size() > 2) {
        int from_pos = 0;
        for (size_t t = 1; t < alive.size(); ++t) if (v[alive[t]] < v[alive[from_pos]]) from_pos = t;
        const int from = alive[from_pos];
        const double pot = v[from];
        alive.erase(alive.begin() + from_pos);
        double mask = 0.0;
        for (size_t t = 0; t < alive.size(); ++t) mask += std::ldexp(1.0, alive[t]);
        const double key = (from + 1) * pow2K + mask;   // R's from is 1-based
        const int ki = (int) key;                       // exact: key < (K+1) * 2^K
        const double* row;
        bool got_cell = cell_has[ki];
        if (got_cell) row = &cell_mat(ki, 0);
        else {
          ++n_fb;
          if (ss_has[ki]) row = &ss_mat(ki, 0);
          else if (has_pw) row = &pw_mat(from, 0);
          else row = &pool_mat(from, 0);
        }
        ++n_tx;
        const size_t na = alive.size();
        w.resize(na); p.resize(na);
        // Rcpp matrices are column-major: the element for party k on this row
        // sits `k * nrow` doubles past the row's first element.
        const int stride = got_cell ? cell_mat.nrow() : (ss_has[ki] ? ss_mat.nrow() : (has_pw ? pw_mat.nrow() : pool_mat.nrow()));
        long double ts = 0.0L;
        for (size_t t = 0; t < na; ++t) { w[t] = row[(size_t) alive[t] * stride]; ts += w[t]; }
        const double tot = (double) ts;
        const double u = 1.0 / (double) na;
        const double sm = (!got_cell) ? std::max(smooth, fallback_smooth) : smooth;
        if (tot <= 0) { for (size_t t = 0; t < na; ++t) p[t] = u; }
        else { for (size_t t = 0; t < na; ++t) p[t] = (1.0 - sm) * (w[t] / tot) + sm * u; }
        const double fsd = flow_sd_by[from];
        if (fsd > 0 && na > 1) {
          for (size_t t = 0; t < na; ++t) { const double e = R::rnorm(0.0, fsd / 100.0); const double q = p[t] + e; p[t] = q > 0 ? q : 0; }
          long double ps = 0.0L;
          for (size_t t = 0; t < na; ++t) ps += p[t];
          const double psd = (double) ps;
          if (psd > 0) { for (size_t t = 0; t < na; ++t) p[t] = p[t] / psd; }
          else { for (size_t t = 0; t < na; ++t) p[t] = u; }
        }
        for (size_t t = 0; t < na; ++t) v[alive[t]] = v[alive[t]] + pot * p[t];
        v[from] = 0;
      }
      // ---- winner, TCP, shrink ----
      // Every party at or below zero after noise leaves nothing alive. The R
      // loop credits nobody for that seat-draw (an integer(0) index is a
      // no-op on `wins`/`totals`, TCP is not written, and the shrink toss
      // short-circuits before its runif), so this does the same: no write,
      // no random number. Found by review 2026-09-07 -- alive[0] on an empty
      // vector was undefined behaviour and mis-credited a party.
      if (alive.empty()) continue;
      int wpos = 0;
      for (size_t t = 1; t < alive.size(); ++t) if (v[alive[t]] > v[alive[wpos]]) wpos = t;
      int wk = alive[wpos];
      if (alive.size() == 2) {
        tcp_w(s, i) = wk + 1;
        tcp_r(s, i) = alive[1 - wpos] + 1;
        tcp_share(s, i) = v[wk] / ld_sum(v, alive);
      }
      if (shrink[i] > 0 && alive.size() > 1 && R::runif(0.0, 1.0) < shrink[i]) {
        const int pick = (int) R_unif_index((double) alive.size());
        wk = alive[pick];
      }
      wins(i, wk) += 1;
      totals(s, wk) += 1;
    }
  }
  return List::create(_["wins"] = wins, _["totals"] = totals, _["tcp_w"] = tcp_w,
                      _["tcp_r"] = tcp_r, _["tcp_share"] = tcp_share,
                      _["n_fb"] = (double) n_fb, _["n_tx"] = (double) n_tx,
                      _["n_recipient_fb_draw"] = (double) n_recipient_fb_draw);
}
