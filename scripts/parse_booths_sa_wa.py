"""Parse raw SA and WA lower-house booth results into tidy CSVs.

Inputs (read only):
  SA 2018  external/reference/ecsa/2018/<District>2.html  (first-pref booth
           table + "Two Candidate Preferred" booth table on the same page)
  SA 2022/2026  external/reference/ecsa/ha-<date>.json (static: candidate
           names/parties) + ha-change-<date>.json (votes)
  WA 1996-2025  external/reference/waec/sg<year>-<code>.json  (resultsPollingPlace;
           results2CP is district-level only, so WA has NO booth tcp)

Outputs in output/booths/:
  <election>-booth-fp.csv   and, where booth two-candidate data exists,
  <election>-booth-tcp.csv
  columns: election,district,booth,vote_type,candidate,party_raw,votes,lat,lon,source_file

Total rows are never emitted. Declaration votes in SA (postal, early, absent
etc. are pooled by ECSA) are emitted as vote_type 'declaration'.

Run: python scripts/parse_booths_sa_wa.py   (exit 1 if any validation fails)
"""

import csv
import glob
import html
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, "external", "reference")
ELEC = os.path.join(ROOT, "external", "elections")
OUT = os.path.join(ROOT, "output", "booths")
COLS = ["election", "district", "booth", "vote_type", "candidate",
        "party_raw", "votes", "lat", "lon", "source_file"]
TOL = 0.005


def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")


def row(election, district, booth, vtype, cand, party, votes, src):
    return [election, district, booth, vtype, cand, party, votes, "", "", src]


# ---------------------------------------------------------------- SA 2018
def _cells(tr):
    return [html.unescape(re.sub(r"<[^>]+>", "", c)).strip()
            for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", tr, re.S)]


def _num(s):
    s = s.replace(",", "").strip()
    if s in ("", "-"):
        return 0
    return int(s)


def _head_cands(thead):
    """Candidate (name, party) from header cells 'SURNAME<br>Given<br><strong>P</strong>'."""
    out = []
    for th in re.findall(r"<th[^>]*>(.*?)</th>", thead, re.S):
        if "<strong>" not in th:
            continue
        party = re.search(r"<strong>(.*?)</strong>", th, re.S).group(1).strip()
        txt = re.sub(r"<strong>.*?</strong>", "", th, flags=re.S)
        parts = [html.unescape(re.sub(r"<[^>]+>", "", p)).strip()
                 for p in re.split(r"<br\s*/?>", txt)]
        parts = [p for p in parts if p and p.lower() != "number"]
        out.append((" ".join(parts), party))
    return out


def parse_sa2018():
    fp, tcp, sums = [], [], {}
    files = sorted(f for f in glob.glob(os.path.join(REF, "ecsa", "2018", "*2.html")))
    for f in files:
        district = os.path.basename(f)[:-len("2.html")].replace("_", " ")
        src = rel(f)
        t = open(f, encoding="utf-8", errors="replace").read()
        tables = re.findall(r"<table class=\"table table-striped\">(.*?)</table>", t, re.S)
        if len(tables) != 2:
            raise SystemExit(f"{src}: expected 2 tables, found {len(tables)}")
        for ti, (tab, out) in enumerate(zip(tables, (fp, tcp))):
            thead = re.search(r"<thead>(.*?)</thead>", tab, re.S).group(1)
            cands = _head_cands(thead)
            n = len(cands)
            body = re.search(r"<tbody>(.*?)</tbody>", tab, re.S).group(1)
            foot = re.search(r"<tfoot>(.*?)</tfoot>", tab, re.S)
            items = [(r, "ordinary") for r in re.findall(r"<tr>(.*?)</tr>", body, re.S)]
            if foot:
                for r in re.findall(r"<tr>(.*?)</tr>", foot.group(1), re.S):
                    c = _cells(r)
                    if c and c[0] == "Declaration Ballot Papers":
                        items.append((r, "declaration"))
            for r, vt in items:
                c = _cells(r)
                booth = c[0]
                if ti == 0:
                    vals = c[1:1 + n]
                    formal = _num(c[1 + n])
                    if sum(_num(v) for v in vals) != formal:
                        raise SystemExit(f"{src}: {booth} candidates != Frml")
                else:  # number, %, number, % ...
                    vals = [c[1 + 2 * i] for i in range(n)]
                for (name, party), v in zip(cands, vals):
                    out.append(row("sa2018", district, booth, vt, name, party, _num(v), src))
    return fp, tcp


def _group(label):
    return re.sub(r"\s*Declaration\s*\d*$", "", label).strip()


DROPPED = []


def _clean_declarations(dn, blocks):
    """ECSA 2026 declaration blocks include correction records: a later block can
    repeat an earlier one, and a reversal is a block with NEGATIVE formal votes
    and all-zero candidate votes. Per group (label minus 'Declaration N'): sum
    the negatives, cancel the last positive block whose formal total equals
    that sum, drop the reversal blocks, then drop verbatim repeats (same
    candidate vector, formal >= 20). Every drop is logged in DROPPED."""
    keep = [True] * len(blocks)
    groups = defaultdict(list)
    for i, b in enumerate(blocks):
        groups[_group(b[0])].append(i)
    for g, idx in groups.items():
        neg = [i for i in idx if blocks[i][3] < 0]
        for i in neg:
            keep[i] = False
        tot = sum(blocks[i][3] for i in neg)
        if tot < 0:
            cand = [i for i in idx if keep[i] and blocks[i][3] == -tot]
            if cand:
                keep[cand[-1]] = False
                DROPPED.append((dn, blocks[cand[-1]][0], "reversed", -tot))
            else:
                DROPPED.append((dn, g, "UNMATCHED reversal", tot))
        seen = {}
        for i in idx:
            if not keep[i] or blocks[i][3] < 20:
                continue
            vec = tuple(cv["votes"] for cv in blocks[i][1])
            if vec in seen:
                keep[i] = False
                DROPPED.append((dn, blocks[i][0], "verbatim repeat of " + blocks[seen[vec]][0],
                                blocks[i][3]))
            else:
                seen[vec] = i
    return [b for b, k in zip(blocks, keep) if k]


# ---------------------------------------------------------------- SA 2022/2026
def parse_sa_json(year, date):
    st = json.load(open(os.path.join(REF, "ecsa", f"ha-{date}.json"), encoding="utf-8"))
    ch_path = os.path.join(REF, "ecsa", f"ha-change-{date}.json")
    ch = json.load(open(ch_path, encoding="utf-8"))
    src = rel(ch_path)
    el = f"sa{year}"
    ptype = {}
    cmap = {}
    for d in st["districts"]:
        cmap[d["districtName"]] = {c["candidateId"]: (c["candidateName"], c.get("partyId") or "")
                                   for c in d["candidates"]}
        for p in d["pollingPlaces"]:
            ptype[(d["districtName"], p["pollingPlaceName"])] = p["pollingPlaceType"] or ""
    fp, tcp = [], []
    for d in ch["districts"]:
        dn = d["districtId"]
        cm = cmap[dn]
        for p in d["pollingPlaces"]:
            booth = p["pollingPlaceName"]
            vt = "early" if "Early" in ptype.get((dn, booth), "") else "ordinary"
            for pc in p["pollingCandidates"]:
                name, party = cm[pc["candidateId"]]
                fp.append(row(el, dn, booth, vt, name, party, pc["formalVotes"], src))
                if pc.get("twoCandidatePref") is not None:
                    tcp.append(row(el, dn, booth, vt, name, party, pc["twoCandidatePref"], src))
        if "declarations" in d:
            # 2026: declaration votes broken out by type; candidates[] hold only
            # part of them, absent-ordinary votes live in absentOrdinary.
            finalists = {pc["candidateId"] for p in d["pollingPlaces"]
                         for pc in p["pollingCandidates"] if pc.get("twoCandidatePref") is not None}
            blocks = [(x["declarationType"], x["candidateVotes"], "twoCandidatePrefVoteCount",
                       x["formalVotes"]) for x in d["declarations"]]
            blocks += [(x["absentOrdinaryType"], x["candidateVotes"], "twoCandidatePrefVotes",
                        x["formalVotes"]) for x in d.get("absentOrdinary", [])]
            blocks = _clean_declarations(dn, blocks)
            for label, cvs, tk, _f in blocks:
                lab = label.lower()
                for cv in cvs:
                    name, party = cm[cv["candidateId"]]
                    fp.append(row(el, dn, label, lab, name, party, cv["votes"], src))
                    if cv["candidateId"] in finalists:
                        tcp.append(row(el, dn, label, lab, name, party, cv.get(tk) or 0, src))
        else:
            for c in d["candidates"]:
                name, party = cm[c["candidateId"]]
                fp.append(row(el, dn, "Declaration", "declaration", name, party,
                              c["declarationVotes"], src))
                if c.get("twoCandidatePrefDeclarationVotes") is not None:
                    tcp.append(row(el, dn, "Declaration", "declaration", name, party,
                                   c["twoCandidatePrefDeclarationVotes"], src))
    return fp, tcp


# ---------------------------------------------------------------- WA
def parse_wa(year):
    fp = []
    el = f"wa{year}"
    for f in sorted(glob.glob(os.path.join(REF, "waec", f"sg{year}-*.json"))):
        if f.endswith("-candidates.json"):
            continue
        d = json.load(open(f, encoding="utf-8"))
        ce = d.get("currentElectorate")
        if not ce or ce.get("ElelctorateType") != "District":
            continue
        dn = ce["ElectorateName"]
        src = rel(f)
        for r in d["resultsPollingPlace"]:
            grp, nm = r.get("BREAKDOWN_GROUP"), r.get("BREAKDOWN_NAME")
            if grp is None:  # 'Total Votes' summary row (1996, 2001)
                continue
            vt = "ordinary" if grp == "Polling Places" else f"{grp.lower()}: {nm}"
            for k, v in r.items():
                if k in ("BREAKDOWN_NAME", "BREAKDOWN_GROUP", "Informal", "Total Votes"):
                    continue
                if " - " in k:
                    cand, party = k.rsplit(" - ", 1)
                else:
                    cand, party = k, ""
                votes = int(v) if v is not None else 0
                fp.append(row(el, dn, nm, vt, cand.strip(), party.strip(), votes, src))
    return fp, []


# ---------------------------------------------------------------- validation
def norm(s):
    return re.sub(r"[^a-z0-9]", "", s.lower())


def read_ref(path, seat_col="seat"):
    tot = defaultdict(int)
    with open(path, encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            tot[norm(r[seat_col])] += int(float(r["votes"]))
    return tot


def district_sums(rows):
    s = defaultdict(int)
    names = {}
    for r in rows:
        s[norm(r[1])] += r[6]
        names[norm(r[1])] = r[1]
    return s, names


def compare(label, rows, ref):
    """Return (n_ok, n_total, worst3, unmatched_ours, unmatched_ref)."""
    s, names = district_sums(rows)
    diffs = []
    for k, v in s.items():
        if k in ref:
            diffs.append((abs(v - ref[k]) / max(ref[k], 1), names[k], v, ref[k]))
    ok = sum(1 for d in diffs if d[0] <= TOL)
    diffs.sort(reverse=True)
    return ok, len(diffs), diffs[:3], sorted(names[k] for k in s if k not in ref), \
        sorted(k for k in ref if k not in s)


def validate(election, fp, tcp, ref, expect_districts, problems):
    dists = {r[1] for r in fp}
    print(f"[{election}] districts={len(dists)} (expected {expect_districts}) booths="
          f"{len({(r[1], r[2], r[3]) for r in fp})}")
    if len(dists) != expect_districts:
        problems.append(f"{election}: {len(dists)} districts, expected {expect_districts}")
    bad = [r for r in fp + tcp if not isinstance(r[6], int) or r[6] < 0]
    if bad:
        problems.append(f"{election}: {len(bad)} negative/non-integer votes e.g. {bad[0]}")
    ordinary = defaultdict(int)
    for r in fp:
        ordinary[r[1]] += 1
    if any(v == 0 for v in ordinary.values()):
        problems.append(f"{election}: district with zero rows")
    ok, n, worst, un_o, un_r = compare(election, fp, ref)
    print(f"  fp vs district file: {ok}/{n} within {TOL:.1%}; worst3 "
          + "; ".join(f"{w[1]} ours={w[2]} ref={w[3]} ({w[0]:.2%})" for w in worst))
    if un_o or un_r:
        print(f"  unmatched ours={un_o} ref={un_r}")
        problems.append(f"{election}: unmatched district names ours={un_o} ref={un_r}")
    if ok != n:
        problems.append(f"{election}: {n - ok} districts outside tolerance")
    if tcp:
        per = defaultdict(set)
        for r in tcp:
            per[r[1]].add(r[4])
        badc = {d: len(c) for d, c in per.items() if len(c) != 2}
        fps, _ = district_sums(fp)
        tcs, names = district_sums(tcp)
        off = [(abs(v - fps[k]) / max(fps[k], 1), names[k], v, fps[k]) for k, v in tcs.items()
               if abs(v - fps[k]) / max(fps[k], 1) > TOL]
        print(f"  tcp: districts={len(per)} not-two-candidates={len(badc)} "
              f"total-vs-fp outside tol={len(off)}")
        if badc:
            problems.append(f"{election}: tcp districts without exactly 2 candidates {badc}")
        for o in sorted(off, reverse=True)[:5]:
            print(f"    tcp total mismatch {o[1]} tcp={o[2]} fp={o[3]} ({o[0]:.2%})")
        if off:
            problems.append(f"{election}: {len(off)} tcp totals outside tolerance")
        if len(per) != len(dists):
            print(f"  note: tcp covers {len(per)} of {len(dists)} districts")


def write(election, kind, rows):
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, f"{election}-booth-{kind}.csv")
    with open(p, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(COLS)
        w.writerows(rows)
    print(f"  wrote {rel(p)}: {len(rows)} rows")


def main():
    problems = []
    unavailable = []
    jobs = [("sa2018", parse_sa2018, 47, os.path.join(ELEC, "wikipedia-2018-sa-firstprefs.csv"))]
    jobs.append(("sa2022", lambda: parse_sa_json("2022", "2022-03-19"), 47,
                 os.path.join(ELEC, "ecsa-2022-sa-firstprefs.csv")))
    jobs.append(("sa2026", lambda: parse_sa_json("2026", "2026-03-21"), 47,
                 os.path.join(ELEC, "ecsa-2026-sa-firstprefs.csv")))
    for y in (1996, 2001, 2005, 2008, 2013, 2017, 2021, 2025):
        jobs.append((f"wa{y}", (lambda y=y: parse_wa(y)), 57 if y <= 2005 else 59,
                     os.path.join(ELEC, f"waec-{y}-wa-firstprefs.csv")))
    for el, fn, expect, refp in jobs:
        fp, tcp = fn()
        if fp and sum(r[6] for r in fp) == 0:
            print(f"[{el}] SOURCE HAS NO BOOTH VOTES (all {len(fp)} candidate cells are 0); "
                  f"not written, not counted as a failure")
            unavailable.append(el)
            continue
        if os.path.exists(refp):
            ref = read_ref(refp)
        else:
            ref = {}
            problems.append(f"{el}: reference file missing {refp}")
        validate(el, fp, tcp, ref, expect, problems)
        write(el, "fp", fp)
        if tcp:
            write(el, "tcp", tcp)
    if problems:
        print("\nVALIDATION FAILURES:")
        for p in problems:
            print("  -", p)
        sys.exit(1)
    print("\nAll checks passed.")


if __name__ == "__main__":
    main()
