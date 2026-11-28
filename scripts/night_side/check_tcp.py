"""Election-night guard (28 Nov 2026, 8:40pm): compare the model's projected two-candidate share in each seat with the
VEC's own seat-level two-candidate count, read from each district result page. This is the check that would have caught
tonight's preference-flow bug at 7pm. One polite pass over the 88 district pages (one at a time, 0.4 s apart), saved raw.

  python -I check_tcp.py <night json> <out dir>

Prints seats where the counted leader differs from the model's leader, and where the gap is large, and writes
<out dir>/tcp-seat-totals.json (seat -> candidates, votes, pct) for the site."""
import json, re, sys, os, time, subprocess, html

night = json.load(open(sys.argv[1], encoding="utf-8")); out = sys.argv[2]; os.makedirs(os.path.join(out, "district-pages"), exist_ok=True)
UA = "auspol election-night reader (personal, non-commercial)"
B = "https://www.vec.vic.gov.au/results/2026-results/district-election-page/results-by-district/"
lk = lambda x: re.sub("[^a-z]", "", x.lower())
def cls(p):
    p = p.upper()
    return ("ALP" if "LABOR PARTY" in p else "LNP" if p.strip() == "LIBERAL" or "NATIONALS" in p else "GRN" if "GREENS" in p
            else "ONP" if "ONE NATION" in p else "IND" if p.strip() == "" else "OTH")
res = {}; fails = []
for s in night["seats"]:
    seat = s["seat"]; slug = seat.replace(" ", "-") + "-District-results"
    if seat == "South West Coast": slug = "South-West-Coast-District-results"
    f = os.path.join(out, "district-pages", lk(seat) + ".html")
    code = subprocess.run(["curl", "-s", "-o", f, "-w", "%{http_code}", "--max-time", "40", "-A", UA, B + slug], capture_output=True, text=True).stdout
    time.sleep(0.4)
    if code != "200": fails.append((seat, code)); continue
    t = open(f, encoding="utf-8", errors="replace").read()
    t = re.sub(r"(?s)<script.*?</script>|<style.*?</style>", "", t); t = html.unescape(re.sub(r"<[^>]+>", " ", t)); t = re.sub(r"\s+", " ", t)
    m = re.search(r"Two candidate preferred results .*?Preferred votes % preferred votes (.*?) Two candidate preferred results by voting centre", t)
    if not m: continue
    rows = re.findall(r"(.*?) ([A-Z][A-Z'\- ]+, [A-Za-z'\- ]+?) ([\d,]+) ([\d.]+)%", m.group(1))
    if len(rows) == 2:
        res[seat] = [{"party": r[0].strip(), "party_class": cls(r[0]), "candidate": r[1].strip(), "votes": int(r[2].replace(",", "")), "pct": float(r[3])} for r in rows]
json.dump({"built_at": time.strftime("%Y-%m-%dT%H:%M:%S+1100"), "source": "VEC district result pages, seat-level two-candidate count", "seats": res},
          open(os.path.join(out, "tcp-seat-totals.json"), "w", encoding="utf-8"))
print(f"district pages read: {len(night['seats']) - len(fails)} of {len(night['seats'])}; with a two-candidate count: {len(res)}; failed: {fails[:6]}")
rows = []
for s in night["seats"]:
    c = res.get(s["seat"])
    if not c or sum(x["votes"] for x in c) < 500: continue
    ft = s["final_two"]; lead = ft["leader"]; q = ft["leader_tcp"]["q50"]
    cc = {x["party_class"]: x for x in c}
    if lead not in cc or ft["other"] not in cc: rows.append((999, s["seat"], "DIFFERENT PAIR", lead + " v " + ft["other"], [x["party_class"] for x in c], s.get("counted_pct"))); continue
    rows.append((round(cc[lead]["pct"] - q, 1), s["seat"], lead + " v " + ft["other"], "counted %.1f" % cc[lead]["pct"], "model %.1f" % q, "votes %d" % sum(x["votes"] for x in c),
                 "fav %s %.2f" % (s["favourite"], s["favourite_prob"]), "counted %s%%" % s.get("counted_pct"),
                 "LEADER DIFFERS" if (cc[lead]["pct"] < 50) != (q < 50) else ""))
print("seat-level two-candidate count vs the model's projected final share for the model's leader (counted minus model, points):")
for r in sorted(rows, key=lambda x: -abs(x[0])): print("  ", r)
d = [r[0] for r in rows if r[0] != 999]
print(f"seats compared {len(d)}; mean gap {sum(d)/len(d):+.1f}; mean absolute gap {sum(abs(x) for x in d)/len(d):.1f}; leader differs in {sum(1 for r in rows if r[-1] == 'LEADER DIFFERS')}")
