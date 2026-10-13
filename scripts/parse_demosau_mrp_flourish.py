# DemosAU federal MRP from its Flourish embeds (demosau.com returns 403 to scripts; the charts are hosted on
# flo.uri.sh, which does not). Fetch raw with:
#   for v in 30532149 30508517 30532135 30532169; do curl -s -A "Mozilla/5.0" -o external/reference/polls/demosau/raw/mrp/flourish-$v.html https://flo.uri.sh/visualisation/$v/embed; sleep 1; done
# (Aug-Sep 2026 release; each new release has new visualisation ids, read off the article page.) Then:
#   python -I scripts/parse_demosau_mrp_flourish.py external/reference/polls/demosau/raw/mrp
import json, re, sys, pathlib
dec = json.JSONDecoder()
def grab(h, name):
    m = re.search(r"\b" + re.escape(name) + r"\s*=\s*", h)
    if not m: return None
    obj, _ = dec.raw_decode(h, m.end())
    return obj
d = pathlib.Path(sys.argv[1])
for f in sorted(d.glob("flourish-*.html")):
    h = f.read_text(encoding="utf-8", errors="replace")
    cols = grab(h, "_Flourish_data_column_names"); data = grab(h, "_Flourish_data")
    tm = re.search(r"<title>([^<]*)</title>", h)
    print("==", f.name, "| page title:", tm.group(1) if tm else None)
    if cols: print("  columns:", json.dumps(cols)[:700])
    if data:
        for k, v in data.items():
            print(f"  dataset {k}: {len(v)} rows; first: {json.dumps(v[0])[:500] if v else None}")
        (d / (f.stem + "-data.json")).write_text(json.dumps({"columns": cols, "data": data}), encoding="utf-8")
