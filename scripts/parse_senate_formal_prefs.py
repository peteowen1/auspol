"""Collapse an AEC Senate "formal preferences" file (one row per ballot paper) to group-order sequences.

    python -I scripts/parse_senate_formal_prefs.py <zip> <out_prefix>

Reads the zip as a stream (never the whole file in memory). For every ballot:
  * BTL counts if its below-the-line marks run 1, 2, ..., k with k >= 6 (the Senate savings rule: a below-the-line
    vote is formal with at least 1 to 6); the sequence is the groups in order of their first candidate.
  * otherwise ATL: the valid above-the-line run 1, 2, ..., k (stops at the first missing or repeated number;
    a lone tick or cross counts as 1, as the AEC does).
Writes <out_prefix>-sequences.csv.gz (kind, atl_marks, btl_marks, seq, n: seq is group letters joined by '>', the
ballot's groups in preference order) and <out_prefix>-groups.csv (letter, name, candidates).
The raw zip stays untouched beside it; this file is a derived cut, rebuildable from the raw in about a minute.
"""
import csv, gzip, io, sys, zipfile
from collections import Counter

zpath, out = sys.argv[1], sys.argv[2]
z = zipfile.ZipFile(zpath)
name = [n for n in z.namelist() if n.endswith(".csv")][0]
fh = io.TextIOWrapper(z.open(name), encoding="utf-8-sig", newline="")
r = csv.reader(fh)
hdr = next(r)
cols = hdr[6:]
# group columns come first (A:, B:, ...), then candidate columns starting again at A: (UG: for ungrouped)
ng = 0
seen = set()
for c in cols:
    L = c.split(":", 1)[0]
    if L in seen:
        break
    seen.add(L); ng += 1
gcols = cols[:ng]; ccols = cols[ng:]
glet = [c.split(":", 1)[0] for c in gcols]
gname = [c.split(":", 1)[1] for c in gcols]
clet = [c.split(":", 1)[0] for c in ccols]
ncand = Counter(clet)

def num(s):
    s = s.strip()
    if s == "":
        return None
    if s.isdigit():
        return int(s)
    return 1 if s in ("/", "*", "X", "x", "V", "v") else -1   # tick / cross = 1; anything else unusable

def run(marks):
    """positions in order of the valid run 1..k"""
    pos = {}
    dup = set()
    for i, m in enumerate(marks):
        if m is None or m < 1:
            continue
        if m in pos:
            dup.add(m)
        else:
            pos[m] = i
    k = 0; seq = []
    while (k + 1) in pos and (k + 1) not in dup:
        k += 1; seq.append(pos[k])
    return seq

cnt = Counter(); odd = Counter(); nb = 0; nbtl = 0; nunus = 0
for row in r:
    nb += 1
    vals = row[6:]
    if len(vals) < len(cols):
        vals = vals + [""] * (len(cols) - len(vals))
    a = [num(v) for v in vals[:ng]]
    b = [num(v) for v in vals[ng:]]
    for v in vals:
        v = v.strip()
        if v and not v.isdigit():
            odd[v] += 1
    bs = run(b)
    if len(bs) >= 6:
        nbtl += 1
        order = []
        for i in bs:
            g = clet[i]
            if g not in order:
                order.append(g)
        kind = "BTL"; atl = len(run(a)); btl = len(bs)
    else:
        s = run(a)
        if not s:
            nunus += 1
            continue
        order = [glet[i] for i in s]; kind = "ATL"; atl = len(s); btl = len(bs)
    cnt[(kind, atl, btl, ">".join(order))] += 1

with gzip.open(out + "-sequences.csv.gz", "wt", newline="") as f:
    w = csv.writer(f); w.writerow(["kind", "atl_marks", "btl_marks", "seq", "n"])
    for (k, a_, b_, s), n in cnt.items():
        w.writerow([k, a_, b_, s, n])
with open(out + "-groups.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f); w.writerow(["letter", "name", "candidates"])
    for L, nm in zip(glet, gname):
        w.writerow([L, nm, ncand[L]])
    if "UG" in ncand:
        w.writerow(["UG", "Ungrouped", ncand["UG"]])
print(f"ballots {nb}, BTL {nbtl}, neither usable {nunus}, distinct sequences {len(cnt)}, groups {ng}, candidates {len(ccols)}")
print("non-numeric marks:", odd.most_common(8))
