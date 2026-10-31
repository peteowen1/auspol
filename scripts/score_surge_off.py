"""Clause scorer for docs/plans/prereg-surge-off-2026-10-31.md, from a deciding run's per-seat cache.

Usage: python scripts/score_surge_off.py deciding-runs/<stamp>-surge-off [expected election count, default 35]
Stops (SSO2!) unless both caches hold the same elections, the expected count, the same seats and the same winners.
NB its log-loss floor is 1e-6; quick_arm's results.txt floors at 0.5/N, so the two differ for seats near zero.
Reads cache/<key>/<election>/allprobs.csv for the two keys (baseline = the one whose params match the shipped config;
told apart here by the run's log line naming each cache key). Prints: acted-seat log loss (seats whose win
probabilities move by more than 0.001) with an election-clustered SE, per-election change in SEs, the ten largest
movers each way, and the five fed2022 seats the prereg names. Log loss floor 1e-6, as everywhere in this repo.
"""
import csv, math, os, re, sys, collections

run = sys.argv[1]
log = open(os.path.join(run, "log.txt"), encoding="utf-8-sig", errors="replace").read()
m_base = re.search(r"baseline cache ([0-9a-f]{12})", log); m_arm = re.search(r"arm cache ([0-9a-f]{12})", log)
if not (m_base and m_arm):
    sys.exit("SSO1! cannot find the baseline / arm cache keys in log.txt")
keys = {"base": m_base.group(1), "arm": m_arm.group(1)}

def load(key):
    out = {}
    root = os.path.join(run, "cache", key)
    for e in sorted(os.listdir(root)):
        f = os.path.join(root, e, "allprobs.csv")
        if not os.path.exists(f):
            continue
        seats = collections.defaultdict(dict); actual = {}
        for r in csv.DictReader(open(f, encoding="utf-8")):
            seats[r["seat"]][r["party"]] = float(r["prob"]); actual[r["seat"]] = r["actual"]
        out[e] = (seats, actual)
    return out

B, A = load(keys["base"]), load(keys["arm"])
expect = int(sys.argv[2]) if len(sys.argv) > 2 else 35
if set(B) != set(A):
    sys.exit(f"SSO2! elections differ: baseline only {sorted(set(B) - set(A))}, arm only {sorted(set(A) - set(B))}")
elections = sorted(B)
print(f"SSO2 {len(elections)} elections in both (baseline {keys['base']}, arm {keys['arm']}; expected {expect})")
if len(elections) != expect:
    sys.exit(f"SSO2! scored {len(elections)} elections, expected {expect}")
for e in elections:
    if set(B[e][0]) != set(A[e][0]):
        sys.exit(f"SSO2! {e}: seat sets differ (baseline only {sorted(set(B[e][0]) - set(A[e][0]))[:5]}, arm only {sorted(set(A[e][0]) - set(B[e][0]))[:5]})")
    bad = [s for s in B[e][1] if B[e][1][s] != A[e][1].get(s)]
    if bad:
        sys.exit(f"SSO2! {e}: actual winner differs between baseline and arm in {bad[:5]}")

ll = lambda p: -math.log(max(p, 1e-6))
rows = []   # (election, seat, actual, p_base, p_arm, acted)
for e in elections:
    sb, act = B[e]; sa, _ = A[e]
    for s in sb:
        w = act[s]; pb = sb[s].get(w, 0.0); pa = sa.get(s, {}).get(w, 0.0)
        parties = set(sb[s]) | set(sa.get(s, {}))
        moved = max(abs(sb[s].get(p, 0.0) - sa.get(s, {}).get(p, 0.0)) for p in parties)
        rows.append((e, s, w, pb, pa, moved > 0.001))

def clustered(sel):
    by = collections.defaultdict(list)
    for r in sel:
        by[r[0]].append(ll(r[4]) - ll(r[3]))
    n = sum(len(v) for v in by.values())
    if not n:
        return 0, float("nan"), float("nan")
    mean = sum(sum(v) for v in by.values()) / n
    g = len(by)
    if g < 2:
        return n, mean, float("nan")
    se = math.sqrt(g / (g - 1) * sum((sum(d - mean for d in v)) ** 2 for v in by.values())) / n
    return n, mean, se

for name, sel in [("all seats", rows), ("acted seats", [r for r in rows if r[5]])]:
    n, d, se = clustered(sel)
    print(f"SSO3 {name}: n={n}, log loss change arm - base {d:+.4f} (SE {se:.4f}, clustered on election; negative = surge-off better)")

print("SSO4 per election (change in log loss over its seats; SE from that election's seats; flagged if worse by > 2 SE):")
for e in elections:
    d = [ll(r[4]) - ll(r[3]) for r in rows if r[0] == e]
    mu = sum(d) / len(d); sd = math.sqrt(sum((x - mu) ** 2 for x in d) / max(1, len(d) - 1)); se = sd / math.sqrt(len(d))
    acted = sum(1 for r in rows if r[0] == e and r[5])
    sb, sa = B[e][0], A[e][0]
    maxd = max(abs(sb[s].get(p, 0.0) - sa[s].get(p, 0.0)) for s in sb for p in set(sb[s]) | set(sa[s]))
    flag = "  <-- WORSE > 2 SE" if se > 0 and mu > 2 * se else ""
    if e.startswith("wa") and maxd > 0:
        flag += "  <-- WA MOVED: the prereg makes a pass unacceptable"
    print(f"  {e:8s} seats {len(d):3d} acted {acted:3d} max prob diff {maxd:.4f} change {mu:+.4f} (SE {se:.4f}){flag}")

# Split by contest type (prereg-flow-sd clause 4). Stand-in for the actual final pair, which exists for AEF-7 only:
# "classic" = the two largest ACTUAL primaries are ALP and LNP and one of them won (output/published-predictions.csv).
pp = collections.defaultdict(list)
for r in csv.DictReader(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "output", "published-predictions.csv"), encoding="utf-8")):
    pp[(r["pair"], r["seat"])].append((float(r["actual"] or 0), r["party"], r["won"] == "TRUE"))
def classic(e, s):
    v = sorted(pp.get((e, s), []), reverse=True)
    if len(v) < 2:
        return None
    top = {v[0][1], v[1][1]}; w = [p for _, p, won in v if won]
    return top == {"ALP", "LNP"} and bool(w) and w[0] in ("ALP", "LNP")
lab = [classic(r[0], r[1]) for r in rows]
nolab = sum(1 for x in lab if x is None)
for name, want in [("classic ALP v LNP", True), ("not ALP v LNP", False)]:
    n, d, se = clustered([r for r, x in zip(rows, lab) if x is want])
    print(f"SSO8 {name} (top two actual primaries, stand-in for the final pair): n={n}, change {d:+.4f} (SE {se:.4f})")
print(f"SSO8 seats with no contest label (not in published-predictions.csv): {nolab}")

mv = sorted(rows, key=lambda r: ll(r[4]) - ll(r[3]))
print("SSO5 ten seats most improved by surge-off (winner prob base -> arm):")
for r in mv[:10]:
    print(f"  {r[0]} {r[1]} ({r[2]}): {r[3]:.3f} -> {r[4]:.3f}")
print("SSO5 ten seats most worsened by surge-off:")
for r in mv[::-1][:10]:
    print(f"  {r[0]} {r[1]} ({r[2]}): {r[3]:.3f} -> {r[4]:.3f}")
floor = [r for r in rows if r[4] < 0.01 and r[3] >= 0.01]
print(f"SSO6 winners pushed below 0.01 by surge-off: {len(floor)}" + "".join(f"\n  {r[0]} {r[1]} ({r[2]}): {r[3]:.4f} -> {r[4]:.4f}" for r in floor))
named = [x.split(":") for x in (sys.argv[3].split(",") if len(sys.argv) > 3 else
         ["fed2022:Wentworth", "fed2022:Warringah", "fed2022:Kooyong", "fed2022:Curtin", "fed2022:Mackellar"])]
print("SSO7 named seats (actual winner's probability base -> arm):")
for e, s in named:
    if e in B and s in B[e][0]:
        w = B[e][1][s]
        print(f"  {e} {s} ({w}): {B[e][0][s].get(w, 0):.3f} -> {A[e][0][s].get(w, 0):.3f}")
