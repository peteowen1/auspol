"""What-if slider, step 2 of 2: gather every scenario scripts/build_scenarios.R
ran into output/scenario-<election>.json for the ITG page.

    python3 -I scripts/combine_scenarios.py [--target=vic2026] [--allow-partial]

Python, standard library only, so the publish job needs no R install (setup-r
plus packages took 5-16 minutes of that job on 2026-10-08; this step reads
CSVs and writes JSON). Replaces combine_scenarios.R line for line.

Chamber figures use build_forecast_json.R's definitions exactly (majority,
hung, One Nation balance of power), so the slider at today's level and the
headline forecast are the same numbers.

Two checks that can fail:
  - every party x mode x offset is present (unless --allow-partial);
  - the "polled" run at offset 0 forces nothing, so its seat probabilities
    must be IDENTICAL to the published run's (same seats, parties, order, and
    probabilities to 1e-8). If they differ, the scenario runs are not
    describing the forecast that was published.
"""
import csv
import json
import math
import os
import re
import subprocess
import sys
import time

CFGS = {"vic2026": {"stem": "vic-2026", "seats": 88, "majority": 45},
        "nsw2027": {"stem": "nsw-2027", "seats": 93, "majority": 47}}
OUT = "output"


def die(msg):
    sys.exit(msg)


def arg(name, default):
    for a in sys.argv[1:]:
        if a.startswith("--" + name + "="):
            return a.split("=", 1)[1]
    return default


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def rnd(x, digits):
    # Same answer as R's round() (R >= 4.0), so these numbers equal the ones
    # build_forecast_json.R publishes. Counts / 20000 land exactly on a 5 at
    # the 4th decimal often, and Python's round() disagreed with R on 6 of 8
    # test scenarios. R takes the two neighbouring candidates AS DOUBLES and
    # keeps the one nearer to x in double arithmetic; only an exact tie goes
    # to the even last digit.
    p = 10.0 ** digits
    lo = math.floor(x * p)
    c_lo, c_hi = lo / p, (lo + 1) / p
    d_lo, d_hi = x - c_lo, c_hi - x
    if d_lo < d_hi:
        return c_lo
    if d_hi < d_lo:
        return c_hi
    return c_lo if lo % 2 == 0 else c_hi


def r4(x):
    return rnd(x, 4)


target = arg("target", os.environ.get("AUSPOL_TARGET", "vic2026"))
if target not in CFGS:
    die("SC0! unknown --target " + target)
cfg = CFGS[target]
stem, maj = cfg["stem"], cfg["majority"]
assert cfg["seats"] // 2 + 1 == maj
partial = "--allow-partial" in sys.argv[1:]

lvl_f = os.path.join(OUT, "statewide-level-%s.csv" % stem)
today_rows = read_csv(lvl_f)
today = {r["party"]: float(r["level"]) for r in today_rows}
betas = [{"moved": r["moved"], "class": r["class"], "beta": float(r["beta"])}
         for r in read_csv(os.path.join(OUT, "statewide-draw-betas-%s.csv" % stem))]

pat = re.compile(r"^seat-sims-full-%s-scn-(exact|polled)-([A-Z_]+)-([+-][0-9.]+)\.csv$" % re.escape(stem))
keys = []
for f in sorted(os.listdir(OUT)):
    m = pat.match(f)
    if m:
        keys.append({"file": f, "mode": m.group(1), "party": m.group(2), "off": float(m.group(3))})
if not keys:
    die("SC5! no scenario outputs for %s -- run scripts/build_scenarios.R first" % target)
# Scenarios older than today's levels describe a different day's forecast.
lvl_time = os.path.getmtime(lvl_f)
stale = [k["file"] for k in keys if os.path.getmtime(os.path.join(OUT, k["file"])) < lvl_time]
if stale:
    die("SC5! %d scenario file(s) predate today's levels, e.g. %s" % (len(stale), stale[0]))

offsets = [-10 + 2.5 * i for i in range(9)]
want = [(m, p, o) for m in ("exact", "polled") for p in ("ONP", "ALP", "LNP", "GRN")
        for o in offsets if today[p] + o >= 0.5]
have = {(k["mode"], k["party"], k["off"]) for k in keys}
missing = [w for w in want if w not in have]
print("SC5  %s: %d scenario(s) found, %d expected, %d missing" % (target, len(keys), len(want), len(missing)))
if missing and not partial:
    die("SC5! missing scenarios: " + ", ".join("%s %s %+.1f" % w for w in missing))

pub_f = os.path.join(OUT, "seat-probs-%s.csv" % stem)
pub_rows = read_csv(pub_f)
seat_names = sorted({r["seat"] for r in pub_rows})
seat_ix = {s: i for i, s in enumerate(seat_names)}
classes = None
scen = []
n_sims = None
for k in keys:
    with open(os.path.join(OUT, k["file"]), newline="", encoding="utf-8") as fh:
        rd = csv.reader(fh)
        cls = next(rd)
        sims = [[int(float(v)) for v in row] for row in rd]
    if classes is None:
        classes, n_sims = cls, len(sims)
    if cls != classes:
        die("SC6! %s has classes %s" % (k["file"], ",".join(cls)))
    n = len(sims)
    ci = {c: i for i, c in enumerate(cls)}
    hung = bop = 0
    for row in sims:
        mx = max(row)
        a = row[ci["ALP"]] if "ALP" in ci else 0
        l = row[ci["LNP"]] if "LNP" in ci else 0
        o = row[ci["ONP"]] if "ONP" in ci else 0
        big = max(a, l)
        hung += mx < maj
        bop += big < maj and big + o >= maj and o > 0
    probs = read_csv(os.path.join(OUT, k["file"].replace("seat-sims-full", "seat-probs", 1)))
    pm = [[0] * len(cls) for _ in seat_names]
    for r in probs:
        if r["seat"] not in seat_ix:
            die("SC6! %s: seat not in the published forecast" % k["file"])
        pm[seat_ix[r["seat"]]][ci[r["party"]]] = int(rnd(float(r["prob"]) * 1000, 0))
    scen.append({
        "mode": k["mode"], "party": k["party"], "offset": k["off"],
        "level": rnd(today[k["party"]] + k["off"], 2),
        "expected": {c: rnd(sum(row[j] for row in sims) / n, 2) for j, c in enumerate(cls)},
        "p_majority": {c: r4(sum(row[j] >= maj for row in sims) / n) for j, c in enumerate(cls)},
        "p_hung": r4(hung / n),
        "p_onp_balance_of_power": r4(bop / n),
        "seat_probs": pm})


def same_probs(a, b):
    if len(a) != len(b):
        return False
    for x, y in zip(a, b):
        if x["seat"] != y["seat"] or x["party"] != y["party"]:
            return False
        if abs(float(x["prob"]) - float(y["prob"])) > 1e-8:
            return False
    return True


# The free check: polled at offset 0 forces nothing, so it IS the published run.
zero = [k for k in keys if k["mode"] == "polled" and k["off"] == 0]
if zero:
    for k in zero:
        f = os.path.join(OUT, k["file"].replace("seat-sims-full", "seat-probs", 1))
        same = same_probs(pub_rows, read_csv(f))
        print("SC7  polled %s at today's level %s the published seat probabilities"
              % (k["party"], "MATCHES" if same else "DOES NOT MATCH"))
        if not same:
            die("SC7! %s differs from %s: the scenarios do not describe the published forecast" % (f, pub_f))
else:
    print("SC7! no polled offset-0 scenario, so nothing ties these scenarios to the published forecast")

try:
    gitsha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True,
                            text=True, check=True).stdout.strip()
except Exception:
    gitsha = None
doc = {
    "election": target, "built_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "git_sha": gitsha,
    "chamber_seats": cfg["seats"], "majority": maj, "n_sims": n_sims,
    "modes": {"exact": "The party gets exactly this share of the statewide first-preference vote in every simulated election.",
              "polled": "This is where the party's vote is expected to land, with the forecast's usual uncertainty around it."},
    "today": today, "betas": betas, "classes": classes, "seats": seat_names, "scenarios": scen}
out = os.path.join(OUT, "scenario-%s.json" % target)
with open(out, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, separators=(",", ":"))
print("SC8  wrote %s: %d scenarios, %d seats, %.0f KB" % (out, len(scen), len(seat_names), os.path.getsize(out) / 1024))
