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
    die("CSC0! unknown --target " + target)
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
    die("CSC5! no scenario outputs for %s -- run scripts/build_scenarios.R first" % target)
# Scenarios older than today's levels describe a different day's forecast.
lvl_time = os.path.getmtime(lvl_f)
stale = [k["file"] for k in keys if os.path.getmtime(os.path.join(OUT, k["file"])) < lvl_time]
if stale:
    die("CSC5! %d scenario file(s) predate today's levels, e.g. %s" % (len(stale), stale[0]))

offsets = [-10 + 2.5 * i for i in range(9)]
want = [(m, p, o) for m in ("exact", "polled") for p in ("ONP", "ALP", "LNP", "GRN")
        for o in offsets if today[p] + o >= 0.5]
have = {(k["mode"], k["party"], k["off"]) for k in keys}
missing = [w for w in want if w not in have]
print("CSC5  %s: %d scenario(s) found, %d expected, %d missing" % (target, len(keys), len(want), len(missing)))
if missing and not partial:
    die("CSC5! missing scenarios: " + ", ".join("%s %s %+.1f" % w for w in missing))

pub_f = os.path.join(OUT, "seat-probs-%s.csv" % stem)
pub_rows = read_csv(pub_f)
seat_names = sorted({r["seat"] for r in pub_rows})
seat_ix = {s: i for i, s in enumerate(seat_names)}


def num(v):
    """CSV cell to float; blank or NA (a same-class pair has no leader share) is None."""
    return None if v in ("", "NA") else float(v)


def final_two_list(fname, check_fresh=True):
    """Each seat's likeliest final two in one scenario, from fit_seats_full.R's seat-tcp-ranges file, in the
    order of `seats`; fields as build_forecast_json.R's seats[].final_two, flattened (FINAL_TWO_FIELDS). None for the
    whole scenario when the file is missing (CSC9! counts them; the slider still publishes), None for a seat
    the file lacks."""
    path = os.path.join(OUT, fname)
    if not os.path.exists(path):
        return None
    if check_fresh and os.path.getmtime(path) < lvl_time:
        die("CSC9! %s predates today's levels: it describes a different day's forecast" % fname)
    out = [None] * len(seat_names)
    for r in read_csv(path):
        if r["seat"] not in seat_ix:
            die("CSC9! %s: seat %s not in the published forecast" % (fname, r["seat"]))
        # one compact row per seat, in FINAL_TWO_FIELDS order (objects would add ~1 MB to a 154 KB file)
        out[seat_ix[r["seat"]]] = [r["leader"], r["other"]] + [num(r[c]) for c in FINAL_TWO_FIELDS[2:]]
    return out


FINAL_TWO_FIELDS = ["leader", "other", "p_pair", "p_leader_wins_pair",
                    "leader_tcp_q05", "leader_tcp_q50", "leader_tcp_q95"]


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
        die("CSC6! %s has classes %s" % (k["file"], ",".join(cls)))
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
            die("CSC6! %s: seat not in the published forecast" % k["file"])
        pm[seat_ix[r["seat"]]][ci[r["party"]]] = int(rnd(float(r["prob"]) * 1000, 0))
    ft = final_two_list(k["file"].replace("seat-sims-full", "seat-tcp-ranges", 1))
    scen.append({
        "mode": k["mode"], "party": k["party"], "offset": k["off"],
        "level": rnd(today[k["party"]] + k["off"], 2),
        "expected": {c: rnd(sum(row[j] for row in sims) / n, 2) for j, c in enumerate(cls)},
        "p_majority": {c: r4(sum(row[j] >= maj for row in sims) / n) for j, c in enumerate(cls)},
        "p_hung": r4(hung / n),
        "p_onp_balance_of_power": r4(bop / n),
        "seat_probs": pm,
        "final_two": ft})
n_ft = sum(1 for s in scen if s["final_two"] is not None)
n_gap = sum(1 for s in scen if s["final_two"] is not None for f in s["final_two"] if f is None)
ok_ft = n_ft == len(scen) and n_gap == 0
print("CSC9%s seat final-two figures in %d of %d scenarios, %d seat gap(s)" % ("" if ok_ft else "!", n_ft, len(scen), n_gap))
if not ok_ft and not partial:
    die("CSC9! seat final-two figures incomplete (a scenario's seat-tcp-ranges file is missing or short); "
        "--allow-partial publishes them as null")


# Runners differ in CPU, so floating point differs in the last bits and a few of 20,000 simulations
# land differently: on 27 Oct two offset-0 runs on separate runners differed from the published file
# (and from each other) by at most 0.0004, while the smallest real offset (2.5 points) moved some seat
# by 0.196 or more. 0.005 is 12x that noise and 40x below the smallest real change.
SAME_TOL = 0.005


def same_probs(a, b):
    """(matches, largest absolute probability gap); a row mismatch is gap infinity."""
    if len(a) != len(b):
        return False, float("inf")
    gap = 0.0
    for x, y in zip(a, b):
        if x["seat"] != y["seat"] or x["party"] != y["party"]:
            return False, float("inf")
        gap = max(gap, abs(float(x["prob"]) - float(y["prob"])))
    return gap <= SAME_TOL, gap


# The free check: polled at offset 0 forces nothing, so it IS the published run.
zero = [k for k in keys if k["mode"] == "polled" and k["off"] == 0]
if zero:
    for k in zero:
        f = os.path.join(OUT, k["file"].replace("seat-sims-full", "seat-probs", 1))
        same, gap = same_probs(pub_rows, read_csv(f))
        print("CSC7  polled %s at today's level %s the published seat probabilities (largest gap %.4f, tolerance %.3f)"
              % (k["party"], "MATCHES" if same else "DOES NOT MATCH", gap, SAME_TOL))
        if not same:
            die("CSC7! %s differs from %s: the scenarios do not describe the published forecast" % (f, pub_f))
        # Same tie for the final-two figures, when the published TCP file is here (it is not in every
        # job's inputs): same pairs, probabilities and medians within SAME_TOL (medians in points, x100).
        pub_t = os.path.join(OUT, "seat-tcp-ranges-%s.csv" % stem)
        sc_ft = next(s["final_two"] for s in scen if s["mode"] == "polled" and s["party"] == k["party"] and s["offset"] == 0)
        if os.path.exists(pub_t) and sc_ft is not None:
            pub_ft = final_two_list(os.path.basename(pub_t), check_fresh=False)
            bad = [seat_names[i] for i, (a, b) in enumerate(zip(pub_ft, sc_ft))
                   if a is None or b is None or a[:2] != b[:2]
                   or any((x is None) != (y is None) or (x is not None and abs(x - y) > (SAME_TOL if j < 4 else 100 * SAME_TOL))
                          for j, (x, y) in enumerate(zip(a, b)) if j >= 2)]
            print("CSC7  polled %s at today's level: final two differs from the published seat-tcp-ranges in %d of %d seats"
                  % (k["party"], len(bad), len(seat_names)))
            if bad:
                die("CSC7! final two differs from %s in %s" % (pub_t, ", ".join(bad[:5])))
else:
    print("CSC7! no polled offset-0 scenario, so nothing ties these scenarios to the published forecast")

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
    "today": today, "betas": betas, "classes": classes, "seats": seat_names,
    "final_two_fields": FINAL_TWO_FIELDS, "scenarios": scen}
out = os.path.join(OUT, "scenario-%s.json" % target)
with open(out, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, separators=(",", ":"))
print("CSC8  wrote %s: %d scenarios, %d seats, %.0f KB" % (out, len(scen), len(seat_names), os.path.getsize(out) / 1024))
