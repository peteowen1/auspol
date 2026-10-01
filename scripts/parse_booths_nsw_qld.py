#!/usr/bin/env python
"""Parse raw NSW and Queensland Legislative Assembly booth results into tidy CSVs.

Inputs (never modified):
  external/reference/nsw/sge<year>-la-final-votes.xlsx   (NSW 2015/2019/2023, first preferences only)
  external/reference/ecq/qld<year>.xml                   (QLD 2017/2020/2024)
Outputs in output/booths/:
  <election>-booth-fp.csv   all elections
  <election>-booth-tcp.csv  QLD 2020/2024 only (official two-candidate-preferred by booth)
Columns: election,district,booth,vote_type,candidate,party_raw,votes,lat,lon,source_file

Notes
  * Only formal votes are emitted; informal counts are printed in the summary.
  * NSW has no coordinates. QLD 2020/2024 take lat/lon from the XML venue directory by booth id.
    QLD 2017 has no directory; it borrows coordinates from the 2020 then 2024 directory when
    the normalised booth name matches a name that is unique within that directory (ids differ
    between 2017 and later files); polling booths only. These are name-matched, NOT verified.
  * QLD party_raw is the XML partyCode attribute (2017: the 'party' code), blank for independents.
  * QLD fp comes from the 'Official First Preference Count' round, tcp from the
    'Official Distribution of Preferences Count' round (2020/2024 files).
Run: python scripts/parse_booths_nsw_qld.py   (exit 1 on any validation failure)
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "output" / "booths"
COLS = ["election", "district", "booth", "vote_type", "candidate", "party_raw",
        "votes", "lat", "lon", "source_file"]
TOL = 0.005

NSW_TYPE = {"PP": "ordinary", "PR": "prepoll", "DI": "declared institution"}
QLD_TYPE = {"PB": "ordinary", "EV": "prepoll", "PO": "postal", "PP": "prepoll absent",
            "PA": "absent", "DI": "declared institution", "PR": "declaration",
            "UI": "uncertain identity", "DV1": "postal declaration",
            "DV2": "in person declaration", "AB1": "absent", "AB2": "absent early"}


def norm(s):
    return re.sub(r"[^a-z0-9]", "", str(s).lower())


# ---------------------------------------------------------------- NSW
def parse_nsw(year):
    src = f"external/reference/nsw/sge{year}-la-final-votes.xlsx"
    df = pd.read_excel(ROOT / src, sheet_name="Data")
    informal = int(df.loc[df["Formal/Informal"] != "Formal", "Final FP Votes"].sum())
    f = df[df["Formal/Informal"] == "Formal"].copy()
    unknown = sorted(set(f["Vote Type"]) - set(NSW_TYPE) - {"DV"})
    if unknown:
        raise SystemExit(f"NSW {year}: unmapped Vote Type {unknown}")
    vt = f["Vote Type"].map(NSW_TYPE)
    vt = vt.where(f["Vote Type"] != "DV", f["Vote Sub Type"].str.lower())
    out = pd.DataFrame({
        "election": f"nsw{year}", "district": f["District"], "booth": f["Venue/Declaration Name"],
        "vote_type": vt, "candidate": f["Candidate Ballot Name"],
        "party_raw": f["Party Acronym"].fillna(""), "votes": f["Final FP Votes"],
        "lat": "", "lon": "", "source_file": src})
    return out[COLS].reset_index(drop=True), informal


# ---------------------------------------------------------------- QLD
def num(el):
    return int(el.text) if el is not None and el.text is not None else 0


def venue_dir(year):
    r = ET.parse(ROOT / f"external/reference/ecq/qld{year}.xml").getroot()
    d = {}
    for b in r.find("venues"):
        la, lo = b.get("latitude"), b.get("longitude")
        if la and lo:
            d[b.get("id")] = (b.get("name"), la, lo)
    return d


def parse_qld(year, coords):
    src = f"external/reference/ecq/qld{year}.xml"
    root = ET.parse(ROOT / src).getroot()
    fp, tcp = [], []
    informal = 0
    if year == 2017:
        districts = root.find("districts")
    else:
        elec = [e for e in root.findall("election")
                if "State General" in e.get("electionName", "")]
        assert len(elec) == 1
        districts = elec[0].find("districts")

    by_name = []
    for c in coords:
        cnt = {}
        for v in c.values():
            cnt[norm(v[0])] = cnt.get(norm(v[0]), 0) + 1
        by_name.append({norm(v[0]): (v[1], v[2]) for v in c.values() if cnt[norm(v[0])] == 1})

    def ll(bid, name):
        if year == 2017:
            for m in by_name:
                if norm(name) in m:
                    return m[norm(name)]
            return "", ""
        v = coords[0].get(bid)
        return (v[1], v[2]) if v else ("", "")

    for d in districts:
        dname = d.get("name") or d.get("districtName")
        if year == 2017:
            cands = {c.get("ballotOrderNumber"): (c.get("ballotName"), c.get("party") or "")
                     for c in d.find("candidates")}
            for b in d.find("booths"):
                informal += num(b.find("informalVotes"))
                vt = QLD_TYPE[b.get("typeCode")]
                la, lo = ll(b.get("id"), b.get("name")) if b.get("typeCode") == "PB" else ("", "")
                for bc in b.find("boothCandidates"):
                    nm, pty = cands[bc.get("ballotOrderNumber")]
                    fp.append([f"qld{year}", dname, b.get("name"), vt, nm, pty,
                               num(bc.find("primaryVotes")), la, lo, src])
        else:
            cands = {c.get("ballotOrderNumber"): (c.get("ballotName"), c.get("partyCode") or "")
                     for c in d.find("candidates")}
            rounds = {cr.get("countName"): cr for cr in d.findall("countRound")}
            r1 = rounds["Official First Preference Count"]
            for b in r1.find("booths"):
                informal += num(b.find("informalVotes"))
                vt = QLD_TYPE[b.get("typeCode")]
                la, lo = ll(b.get("id"), b.get("name"))
                for c in b.find("primaryVoteResults"):
                    nm, pty = cands[c.get("ballotOrderNumber")]
                    fp.append([f"qld{year}", dname, b.get("name"), vt, nm, pty,
                               num(c.find("count")), la, lo, src])
            r4 = rounds["Official Distribution of Preferences Count"]
            for b in r4.find("booths"):
                vt = QLD_TYPE[b.get("typeCode")]
                la, lo = ll(b.get("id"), b.get("name"))
                for c in b.find("twoCandidateVotes"):
                    nm, pty = cands[c.get("ballotOrderNumber")]
                    tcp.append([f"qld{year}", dname, b.get("name"), vt, nm, pty,
                                num(c.find("count")), la, lo, src])
    for r in fp + tcp:
        if r[5] in ("IND", "Independent"):
            r[5] = ""
    mk = lambda rows: pd.DataFrame(rows, columns=COLS)
    return mk(fp), (mk(tcp) if tcp else None), informal


# ---------------------------------------------------------------- validation
def district_totals(df):
    return df.groupby("district")["votes"].sum()


def check_fp_totals(label, fp, ref_csv, report=True):
    """Return (n_ok, n_total, worst3, unmatched, failed)."""
    ref = pd.read_csv(ROOT / ref_csv)
    ref_t = ref.groupby("seat")["votes"].sum()
    rmap = {norm(k): v for k, v in ref_t.items()}
    ours = district_totals(fp)
    rows, unmatched = [], []
    for dist, v in ours.items():
        rv = rmap.get(norm(dist))
        if rv is None:
            unmatched.append(dist)
            continue
        rows.append((abs(v - rv) / rv, dist, int(v), int(rv)))
    ours_n = {norm(x) for x in ours.index}
    unmatched += [k for k in ref_t.index if norm(k) not in ours_n]
    rows.sort(reverse=True)
    ok = sum(1 for r in rows if r[0] <= TOL)
    failed = ok != len(ours) or bool(unmatched)
    if report:
        print(f"  [{label}] fp totals vs {ref_csv}: {ok}/{len(ours)} districts within {TOL:.1%}; "
              f"unmatched: {unmatched or 'none'}")
        for r in rows[:3]:
            print(f"      worst: {r[1]:<22} ours={r[2]:>7} ref={r[3]:>7} diff={r[0]:.3%}")
    return ok, len(ours), rows[:3], unmatched, failed


def validate(label, fp, tcp, n_districts, ref_csv):
    bad = False
    nd = fp["district"].nunique()
    print(f"  [{label}] districts: {nd} (expected {n_districts})")
    bad |= nd != n_districts
    bad |= check_fp_totals(label, fp, ref_csv)[4]
    for name, d in (("fp", fp), ("tcp", tcp)):
        if d is None:
            continue
        neg = int((d["votes"] < 0).sum())
        nonint = int((d["votes"] != d["votes"].round()).sum())
        print(f"  [{label}] {name}: negative={neg} non-integer={nonint} rows={len(d)}")
        bad |= neg > 0 or nonint > 0
    zero = [dist for dist, g in fp.groupby("district") if g["booth"].nunique() == 0]
    print(f"  [{label}] districts with zero booths: {zero or 'none'}")
    bad |= bool(zero)
    if tcp is not None:
        per = tcp.groupby("district")["candidate"].nunique()
        wrong = per[per != 2]
        ft = district_totals(fp)
        tt = district_totals(tcp)
        diffs = sorted(((abs(tt[k] - ft[k]) / ft[k], k, int(tt[k]), int(ft[k])) for k in ft.index),
                       reverse=True)
        n_ok = sum(1 for x in diffs if x[0] <= TOL)
        print(f"  [{label}] tcp: districts with !=2 candidates: {list(wrong.index) or 'none'}; "
              f"tcp total vs fp total within {TOL:.1%}: {n_ok}/{len(ft)}")
        for x in diffs[:3]:
            print(f"      worst: {x[1]:<22} tcp={x[2]:>7} fp={x[3]:>7} diff={x[0]:.3%}")
        bad |= len(wrong) > 0 or n_ok != len(ft) or set(tt.index) != set(ft.index)
    return bad


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bad = False
    v2020, v2024 = venue_dir(2020), venue_dir(2024)
    jobs = [("nsw", y) for y in (2015, 2019, 2023)] + [("qld", y) for y in (2017, 2020, 2024)]
    for kind, y in jobs:
        label = f"{kind}{y}"
        print(f"== {label}")
        if kind == "nsw":
            fp, informal = parse_nsw(y)
            tcp = None
            ref = f"external/elections/nswec-{y}-nsw-firstprefs.csv"
        else:
            coords = {2017: [v2020, v2024], 2020: [v2020], 2024: [v2024]}[y]
            fp, tcp, informal = parse_qld(y, coords)
            ref = f"external/elections/ecq-{y}-qld-firstprefs.csv"
        fp.to_csv(OUT / f"{label}-booth-fp.csv", index=False)
        if tcp is not None:
            tcp.to_csv(OUT / f"{label}-booth-tcp.csv", index=False)
        keys = ["district", "booth", "vote_type"]
        nb = fp.groupby(keys).ngroups
        coord_b = fp[fp["lat"] != ""].groupby(keys).ngroups
        print(f"  rows fp={len(fp)} tcp={0 if tcp is None else len(tcp)}; booths (district x booth x type)={nb}; "
              f"with coords={coord_b}; informal votes skipped={informal}; "
              f"formal votes={int(fp['votes'].sum())}")
        print(f"  vote types: {fp.groupby('vote_type')['votes'].sum().astype(int).to_dict()}")
        bad |= validate(label, fp, tcp, 93, ref)
    print("FAILED" if bad else "ALL CHECKS PASSED")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
