"""Rebuild the private Victoria 2026 Seat Odds page (claude.ai artifact) for one capture date.

The page is a single HTML file whose data sits in JS constants; the 23 Nov page was assembled by hand. This swaps
those constants for a new capture, keeping the page code, PARTIES and LAST (2022 results) as they are:
  DATA     <- output/seat-odds-vic2026.json: sources (key, label, n) and per-seat win chances p
  MARKETS  <- that file's markets (majority-markets.csv)
  BETS     <- per-seat Sportsbet/TAB prices from that file
  FC       <- our forecast as captured (ours/forecast-vic2026.json): per-seat primaries and likeliest final two,
              statewide levels, and the two-party figure passed in (statewide flows x levels; not in any file)
Dated text: the capture note (from the JSON) and the price time (--price-time).

Usage: python -I scripts/build_seat_odds_page.py --template <old page.html> --day 2026-11-27
         --tpp-alp 46.4 --price-time "11:25am Friday 27 November" --out docs/benchmarks/vic2026/<day>/seat-odds-page.html
"""
import argparse, json, re

ap = argparse.ArgumentParser()
ap.add_argument("--template", required=True); ap.add_argument("--day", required=True)
ap.add_argument("--tpp-alp", type=float, required=True); ap.add_argument("--price-time", required=True)
ap.add_argument("--json", default="output/seat-odds-vic2026.json"); ap.add_argument("--out", required=True)
a = ap.parse_args()

h = open(a.template, encoding="utf-8").read()
j = json.load(open(a.json, encoding="utf-8"))
assert j["capture"] == a.day, f"seat-odds JSON is for {j['capture']}, not {a.day}"
fc = json.load(open(f"external/reference/benchmarks/vic2026/{a.day}/ours/forecast-vic2026.json", encoding="utf-8"))
assert len(j["seats"]) == 88 and len(fc["seats"]) == 88

DATA = {"sources": [{"key": s["key"], "label": s["label"], "n": s["n"]} for s in j["sources"]],
        "seats": [{"seat": s["seat"], "region": s["region"], "mp": s["mp"], "p": s["p"]} for s in j["seats"]]}
BETS = []
for s in j["seats"]:
    for r in s["prices"]:
        pr = {b: r[b] for b in ("sportsbet", "tab") if r.get(b)}
        if pr: BETS.append({"seat": s["seat"], "cls": r["grp"], "outcome": r["outcome"], "pr": pr})
FCS = {}
for s in fc["seats"]:
    pr = {p["party"]: round(p["primary"], 1) for p in s["parties"]}
    ft = s.get("final_two") or {}
    FCS[s["seat"]] = {"pr": pr, "ft": [ft.get("leader"), ft.get("other"), round(ft.get("p_pair", 0), 2),
                                       round((ft.get("leader_tcp") or {}).get("q50", 0), 1)]}
lv = {r["party"]: r["forecast_level"] for r in fc["statewide"]}
FC = {"seats": FCS, "state": {"fp": {k: lv[k] for k in ("LNP", "ALP", "GRN", "ONP", "OTH") if k in lv},
                              "tpp": {"ALP": round(a.tpp_alp, 1), "LNP": round(100 - a.tpp_alp, 1)}, "built": fc["built_at"]}}

def clean(o):
    # Scraped names (bookmaker outcomes, candidates) are rendered by the page with innerHTML: drop < and > so no
    # string can carry markup. Real names never contain them; apostrophes (O'Brien) are kept.
    if isinstance(o, str): return o.replace("<", "").replace(">", "")
    if isinstance(o, list): return [clean(x) for x in o]
    if isinstance(o, dict): return {clean(k): clean(v) for k, v in o.items()}
    return o
def swap(name, obj):
    global h
    m = re.search(r"const " + name + r" = ", h); assert m, name
    _, end = json.JSONDecoder().raw_decode(h[m.end():])
    # ensure_ascii covers U+2028/9; escaping < > & stops any "</script>" breakout from the embedded JSON
    js = json.dumps(clean(obj), separators=(",", ":")).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
    h = h[:m.end()] + js + h[m.end() + end:]
for n, o in (("DATA", DATA), ("MARKETS", j["markets"]), ("BETS", BETS), ("FC", FC)): swap(n, o)

# dated text: the capture sentence in the header and the price time in the prices tab
n1 = len(re.findall(r"Bookmakers captured [^<]*?</p>", h)); assert n1 == 1, n1
h = re.sub(r"Bookmakers captured [^<]*?</p>", j["capture_note"].replace("\\", "") + "</p>", h)
n2 = len(re.findall(r"Prices are each bookmaker's at [^\"<]*? for its four", h)); assert n2 >= 1, n2
h = re.sub(r"Prices are each bookmaker's at [^\"<]*? for its four", f"Prices are each bookmaker's at {a.price_time} for its four", h)
open(a.out, "w", encoding="utf-8", newline="\n").write(h)
print(f"SOP1 {a.out}: {len(DATA['sources'])} sources, {len(DATA['seats'])} seats, {len(BETS)} price rows, "
      f"forecast built {fc['built_at']}, two-party ALP {a.tpp_alp}")
