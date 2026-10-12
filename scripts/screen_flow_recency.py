"""Screen: does recency-weighting the historical flow rate predict the next election's flows better?

For each election E and each (from, surviving set, to) cell observed in E, predict E's rate from
earlier elections only (time-forward), as the cond_n-weighted mean `xgb_flow_conditional_override_for()`
builds (`R/xgb_flow_override.R:242`), times a decay 0.5 ** (years before E / half-life).
Score: vote-weighted absolute error in points, per half-life, overall and for One Nation cells.
Reads output/xgb-flows-v1-features.csv. A screen only: it cannot clear a change, only stop one.
Run: python -I scripts/screen_flow_recency.py
"""
import csv, collections, math, re

ROWS = list(csv.DictReader(open("output/xgb-flows-v1-features.csv", encoding="utf-8")))
yr = lambda e: int(re.search(r"(\d{4})", e).group(1))
els = sorted({r["election"] for r in ROWS}, key=yr)
print(f"rows {len(ROWS)} | elections {len(els)}: {els[0]}..{els[-1]}")

# actual rate per (election, cell): votes to `to` / event votes, summed over events
act = collections.defaultdict(lambda: [0.0, 0.0, set()])
for r in ROWS:
    k = (r["election"], r["from"], r["surv"], r["to"])
    a = act[k]; a[0] += float(r["votes"]); a[1] += float(r["event_votes"]); a[2].add(r["event_id"])
# history rows by cell, in the code's own weighting (per row, pmax(1, cond_n), y)
hist = collections.defaultdict(list)
for r in ROWS:
    hist[(r["from"], r["surv"], r["to"])].append((yr(r["election"]), r["election"], float(r["y"]), max(1.0, float(r["cond_n"]))))

def score(hl, only=None):
    err = wsum = 0.0; n = 0
    for (e, f, s, t), (v, tot, ev) in act.items():
        if tot <= 0 or (only and not only(f, s, t)): continue
        past = [(y_, yv, w) for (y_, e_, yv, w) in hist[(f, s, t)] if y_ < yr(e)]
        if len({p[0] for p in past}) < 1: continue
        ws = [w * (0.5 ** ((yr(e) - y_) / hl) if hl else 1.0) for (y_, yv, w) in past]
        pred = sum(w * yv for w, (_, yv, _) in zip(ws, past)) / sum(ws)
        err += tot * abs(100 * v / tot - 100 * pred); wsum += tot; n += 1
    return err / wsum, n

onp = lambda f, s, t: "ONP" in (f, t)
onp_lnp = lambda f, s, t: {f, t} == {"ONP", "LNP"}
print("\nvote-weighted absolute error of the predicted flow, points (lower is better); n = election-cells scored")
print(f"{'half-life':>10} {'all cells':>14} {'One Nation cells':>18} {'ON<->Lib cells':>16}")
for hl in [None, 16, 8, 4, 3, 2, 1.5, 1, 0.5]:
    a, na = score(hl); o, no = score(hl, onp); l, nl = score(hl, onp_lnp)
    lab = "equal" if hl is None else f"{hl} y"
    print(f"{lab:>10} {a:8.2f} ({na:4d}) {o:10.2f} ({no:4d}) {l:9.2f} ({nl:4d})")
