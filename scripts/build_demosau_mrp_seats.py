# Join the three Aug-Sep 2026 MRP tables (primary, two-candidate, win probability) into
# external/reference/polls/demosau/mrp-seats.csv; prints checks against the headline (Labor 84, Coalition 34, One Nation 24, Other 8).
#   python -I scripts/build_demosau_mrp_seats.py external/reference/polls/demosau/raw/mrp
import json, csv, sys, pathlib, collections
d = pathlib.Path(sys.argv[1])
def rows(vid):
    j = json.loads((d / f"flourish-{vid}-data.json").read_text(encoding="utf-8"))
    cols = j["columns"]["rows"]["columns"]
    return cols, [r["columns"] for r in j["data"]["rows"]]
pc, pr = rows(30532149); tc, tr = rows(30532135); wc, wr = rows(30532169)
key = lambda r: (r[0], r[1])
T = {key(r): r for r in tr}; W = {key(r): r for r in wr}
parties = ["ALP", "LNP", "GRN", "ONP", "OTH"]
out = []
for r in pr:
    k = key(r); t = T.get(k); w = W.get(k)
    row = {"release": "2026-08-09 Aug-Sep 2026", "fieldwork": "August-September 2026", "state": r[0], "division": r[1]}
    for i, p in enumerate(parties): row[f"fp_{p}"] = r[2 + i]
    for i, p in enumerate(parties): row[f"tcp_{p}"] = t[2 + i] if t else None
    row["notional_leader"] = t[7] if t else None; row["safety"] = t[8] if t else None
    for i, p in enumerate(parties): row[f"win_{p}"] = w[2 + i] if w else None
    out.append(row)
f = d.parent.parent / "mrp-seats.csv"
with open(f, "w", newline="", encoding="utf-8") as fh:
    wtr = csv.DictWriter(fh, fieldnames=list(out[0].keys())); wtr.writeheader(); wtr.writerows(out)
print("wrote", f, len(out), "rows; missing tcp", sum(1 for r in out if r["notional_leader"] is None), "; missing win", sum(1 for r in out if r["win_ALP"] is None and r["win_LNP"] is None and r["win_ONP"] is None and r["win_GRN"] is None and r["win_OTH"] is None))
print("notional leader counts:", collections.Counter(r["notional_leader"] for r in out))
fav = collections.Counter(max(parties, key=lambda p: (r[f"win_{p}"] or 0)) for r in out)
print("most-likely winner counts:", fav)
exp = {p: round(sum((r[f"win_{p}"] or 0) for r in out) / 100, 1) for p in parties}
print("expected seats (sum of win %):", exp)
print("fp sums range:", min(sum((r[f"fp_{p}"] or 0) for p in parties) for r in out), max(sum((r[f"fp_{p}"] or 0) for p in parties) for r in out))
