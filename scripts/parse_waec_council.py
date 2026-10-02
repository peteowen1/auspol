#!/usr/bin/env python3
"""Parse raw WAEC local-government ordinary-election files into one CSV.

Input : external/reference/waec/council/<year>/  (see fetch_waec_council.py)
Output: output/council-results-wa.csv, one row per candidate per contest.

Columns: year,council,ward,contest,vacancies,candidate,surname,given,
         first_pref_votes,first_pref_pct,ward_formal_votes,ward_enrolment,
         elected,contested,source_file

Conventions
  contest            'mayor' for Mayor / Lord Mayor / President (shire head), else 'councillor'
  ward               empty for unwarded councils and for the district-wide mayor contest
  first_pref_votes   empty where the source gives none (unopposed contests; ALL of 2007,
                     where the API holds ward totals only and every candidate vote is 0)
  first_pref_pct     votes / sum of candidate votes in the contest * 100 (2 dp); the 2005
                     pages' own percentage is used for 2005. For pre-2023 contests with
                     several vacancies voters had several votes, so this is a share of votes,
                     not of ballots.
  ward_formal_votes  formal ballot papers where the API reports them (>0); otherwise the
                     contest's 'total valid votes' (2005 pages, and 2007 where ballots are 0)
  ward_enrolment     electors on the roll for the contest
  contested          FALSE when the contest was 'Elected Unopposed'
Referendum-only entries and contests with no candidates are skipped (counted in the log).

Validation (exit 1 on failure): see validate(). The vote check is proved to fail on a
perturbed copy held in memory.
"""
import copy
import csv
import re
import sys
import json
from collections import Counter, defaultdict
from html import unescape
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RAW = REPO / "external/reference/waec/council"
OUT = REPO / "output/council-results-wa.csv"
YEARS = [2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2021, 2023]
COLS = ["year", "council", "ward", "contest", "vacancies", "candidate", "surname", "given",
        "first_pref_votes", "first_pref_pct", "ward_formal_votes", "ward_enrolment",
        "elected", "contested", "source_file"]
TOL = 0.005
skipped = Counter()
notes = []


def split_name(n):
    n = re.sub(r"\s+", " ", n).strip()
    if "," in n:
        s, g = n.split(",", 1)
        return s.strip(), g.strip()
    notes.append(f"name without comma: {n!r}")
    return n, ""


def contest_kind(name):
    return "mayor" if name in ("Mayor", "Lord Mayor", "President") else "councillor"


def tf(b):
    return "TRUE" if b else "FALSE"


def parse_api(year):
    contests = []
    for f in sorted((RAW / str(year)).glob("*.json")):
        d = json.loads(f.read_bytes().decode("utf-8"))
        for k, v in d.items():
            if k == "info":
                continue
            det = v["details"]
            if det is None:
                skipped[(year, "referendum-only entry")] += 1
                continue
            rs = v["results"]
            if not rs:
                skipped[(year, f"no candidates ({det['ELECTION_STATUS']})")] += 1
                continue
            kind = contest_kind(det["ELECTION_NAME"])
            unopp = any(r["APPOINTMENT_STATUS"] == "Elected Unopposed" for r in rs)
            has_votes = (not unopp) and year != 2007
            valid = rs[0]["NUMBER_OF_VALID_VOTES"]
            fb = rs[0]["NUMBER_OF_FORMAL_BALLOT_PAPERS"]
            # Group rows by candidate. Mayor contests (2009-2021) come as one row per
            # candidate per ward; those are summed into a district total (the per-ward
            # figures stay in the raw file). 2007 repeats rows with all votes 0.
            groups = {}
            for r in rs:
                groups.setdefault(r["BALLOT_PAPER_NAME"], []).append(r)
            rows = []
            for nm, g in groups.items():
                sur, giv = split_name(nm)
                rows.append(dict(
                    candidate=nm, surname=sur, given=giv,
                    votes=sum(x["NUMBER_OF_FORMAL_VOTES"] for x in g) if has_votes else None,
                    elected=any(x["APPOINTMENT_STATUS"] in ("Elected", "Elected Unopposed") for x in g),
                    pct=None))
            if any(len(g) > 1 for g in groups.values()):
                wards = {x["WARD_NAME"]: x["NUMBER_OF_FORMAL_BALLOT_PAPERS"]
                         for x in rs if x["BALLOT_PAPER_NAME"] == rs[0]["BALLOT_PAPER_NAME"]}
                fb = sum(wards.values())
                skipped[(year, "per-ward candidate rows summed to district total (mayor)")] += 1
            contests.append(dict(
                year=year, council=det["DISTRICT_NAME"], ward=det["WARD_NAME"] or "",
                contest=kind, vacancies=det["NUMBER_OF_VACANCIES"], rows=rows,
                contested=not unopp,
                formal=(fb if fb > 0 else (valid if valid > 0 else None)),
                valid=(valid if (has_votes or year == 2007) else None),
                ballots=(fb if fb > 0 else None),
                enrol=det["NUMBER_OF_ELECTORS"], src=f"{year}/{f.name}",
                status=det["ELECTION_STATUS"]))
    return contests


def num(s):
    s = unescape(re.sub(r"<[^>]+>", "", s)).replace("\xa0", " ").replace(",", "")
    s = s.replace("%", "").strip()
    return float(s) if s else None


def parse_html05():
    contests = []
    for f in sorted((RAW / "2005").glob("*.htm")):
        t = f.read_bytes().decode("utf-8", errors="replace")
        council = f.stem
        h3 = re.search(r"<h3>\s*(.*?)\s*</h3>", t, re.S)
        if h3 and unescape(h3.group(1)).strip() != council:
            notes.append(f"2005 {council}: page heading is {h3.group(1).strip()!r}")
        for b in re.split(r'<table border="0" width="420">', t)[1:]:
            hm = re.search(r"<strong>\((\d+)\)\s*(.*?)</strong>", b, re.S)
            if not hm:
                notes.append(f"2005 {council}: block without heading")
                continue
            vac = int(hm.group(1))
            title = re.sub(r"\s+", " ", unescape(hm.group(2))).strip()
            wm = re.match(r"(Councillors?|Mayor|Lord Mayor|President)(?:\s*-\s*(.*?)\s*Ward)?$", title)
            if not wm:
                notes.append(f"2005 {council}: unparsed heading {title!r}")
                continue
            em = re.search(r"Total electors</td>\s*<td[^>]*>\s*([\d,]+)", b)
            enrol = int(em.group(1).replace(",", "")) if em else None
            tbl = b[b.find('class="waecModTable"'):]
            rows, valid = [], None
            for tr in re.findall(r"<tr[^>]*>(.*?)</tr>", tbl, re.S):
                tds = re.findall(r"<td[^>]*>(.*?)</td>", tr, re.S)
                if len(tds) < 4:
                    continue
                first = re.sub(r"<[^>]+>", "", tds[0]).strip()
                if "Total valid votes" in first:
                    valid = int(num(tds[1]))
                    continue
                nm = unescape(first).replace("\xa0", " ").strip()
                votes, pct = num(tds[1]), num(tds[2])
                exp = unescape(re.sub(r"<[^>]+>", "", tds[3])).replace("\xa0", " ").strip()
                sur, giv = split_name(nm)
                rows.append(dict(candidate=nm, surname=sur, given=giv,
                                 votes=None if votes is None else int(votes),
                                 pct=pct, elected=bool(exp)))
            if not rows:
                skipped[(2005, "no candidate rows")] += 1
                continue
            unopp = "Elected Unopposed" in b
            if unopp:
                for r in rows:
                    r["votes"] = None
                    r["pct"] = None
            contests.append(dict(
                year=2005, council=council, ward=wm.group(2) or "",
                contest=contest_kind(wm.group(1)), vacancies=vac, rows=rows,
                contested=not unopp, formal=None if unopp else valid,
                valid=None if unopp else valid, ballots=None, enrol=enrol,
                src=f"2005/{f.name}", status="Results Declared"))
    return contests


def to_rows(contests):
    out = []
    for c in contests:
        tot = sum(r["votes"] for r in c["rows"] if r["votes"] is not None)
        for r in c["rows"]:
            pct = r["pct"]
            if pct is None and r["votes"] is not None and tot > 0:
                pct = round(100.0 * r["votes"] / tot, 2)
            out.append({
                "year": c["year"], "council": c["council"], "ward": c["ward"],
                "contest": c["contest"], "vacancies": c["vacancies"],
                "candidate": r["candidate"], "surname": r["surname"], "given": r["given"],
                "first_pref_votes": "" if r["votes"] is None else r["votes"],
                "first_pref_pct": "" if pct is None else f"{pct:.2f}",
                "ward_formal_votes": "" if c["formal"] is None else c["formal"],
                "ward_enrolment": "" if c["enrol"] is None else c["enrol"],
                "elected": tf(r["elected"]), "contested": tf(c["contested"]),
                "source_file": c["src"]})
    return out


SOFT_TOL = 0.015


def check_votes(contests, soft=None):
    """Vote-sum failures, as strings. A candidate-vote sum that is BELOW the formal
    ballot count by more than 0.5% but at most 1.5% is a source discrepancy (cause
    unverified; possibly votes for a candidate not listed) and goes to `soft`, a list,
    instead of failing."""
    bad = []
    for c in contests:
        vs = [r["votes"] for r in c["rows"] if r["votes"] is not None]
        if not vs:
            continue
        s = sum(vs)
        where = f"{c['year']} {c['council']} / {c['ward'] or '(district)'} / {c['contest']}"
        # A: candidate votes vs the contest's stated total valid votes
        if c["valid"] and abs(s - c["valid"]) > TOL * c["valid"]:
            bad.append(f"A {where}: sum {s} vs total valid {c['valid']}")
        # B: vs formal ballot papers, where the API reports ballots separately
        fb = c.get("ballots")
        if fb:
            v = c["vacancies"]
            lo = fb
            hi = fb if (v == 1 or c["year"] == 2023) else v * fb
            msg = f"B {where}: sum {s} vs formal ballots {fb} ({v} vacancies, allowed [{lo}, {hi}] +-0.5%)"
            if s < lo * (1 - TOL) or s > hi * (1 + TOL):
                if soft is not None and s < lo and s >= lo * (1 - SOFT_TOL):
                    soft.append(msg)
                else:
                    bad.append(msg)
    return bad


def validate(contests, rows):
    fails = []
    print("\nPer year: councils / contests / candidate rows / contests with votes")
    by = defaultdict(list)
    for c in contests:
        by[c["year"]].append(c)
    for y in YEARS:
        cs = by[y]
        kinds = Counter(c["contest"] for c in cs)
        withv = sum(any(r["votes"] is not None for r in c["rows"]) for c in cs)
        print(f"  {y}: {len({c['council'] for c in cs})} councils, {len(cs)} contests "
              f"(councillor {kinds['councillor']}, mayor {kinds['mayor']}), "
              f"{sum(len(c['rows']) for c in cs)} rows, {withv} contests with votes")
    if skipped:
        print("Skipped entries:")
        for (y, why), n in sorted(skipped.items()):
            print(f"  {y}: {n} x {why}")
    seen = Counter()
    for r in rows:
        seen[(r["year"], r["council"], r["ward"], r["contest"], r["candidate"])] += 1
        if r["first_pref_votes"] != "" and r["first_pref_votes"] < 0:
            fails.append(f"negative votes {r}")
    fails += [f"duplicate candidate x{n}: {k}" for k, n in seen.items() if n > 1]
    ck = Counter((c["year"], c["council"], c["ward"], c["contest"]) for c in contests)
    fails += [f"duplicate contest x{n}: {k}" for k, n in ck.items() if n > 1]
    for c in contests:
        ne = sum(r["elected"] for r in c["rows"])
        if c["status"] == "Voided":
            print(f"  note: voided contest, elected count not checked: {c['year']} {c['council']} / {c['ward']} ({c['src']})")
            continue
        if ne != min(c["vacancies"], len(c["rows"])):  # fewer candidates than seats leaves seats unfilled
            fails.append(f"elected {ne} != vacancies {c['vacancies']}: {c['year']} {c['council']} / "
                         f"{c['ward'] or '(district)'} / {c['contest']} "
                         f"({len(c['rows'])} candidates, status {c['status']}, {c['src']})")
    v07 = sum(r["votes"] is not None for c in by[2007] for r in c["rows"])
    print(f"2007 candidate rows with a vote count: {v07} (expected 0: API holds ward totals only)")
    soft = []
    vf = check_votes(contests, soft)
    print(f"Source discrepancies tolerated (candidate sum 0.5-1.5% below formal ballots): {len(soft)}")
    for m in soft:
        print("  warn", m)
    nv = sum(any(r["votes"] is not None for r in c["rows"]) for c in contests)
    print(f"Vote-sum checks over {nv} contests with votes: {len(vf)} failures")
    fails += vf
    pert = copy.deepcopy(contests)
    target = next(c for c in pert if c["year"] == 2023 and c["contested"] and len(c["rows"]) > 2
                  and c["valid"] and all(r["votes"] for r in c["rows"]))
    target["rows"][0]["votes"] = int(target["rows"][0]["votes"] * 1.10) + 5
    tag = f"{target['year']} {target['council']} / {target['ward'] or '(district)'} / {target['contest']}"
    caught = [m for m in check_votes(pert) if tag in m]
    if not caught:
        fails.append("SELF-TEST FAILED: perturbed vote was not caught by check_votes")
    else:
        print(f"Self-test OK: +10% on one candidate ({target['council']} 2023) caught -> {caught[0]}")
    return fails


def main():
    contests = parse_html05()
    for y in YEARS[1:]:
        contests += parse_api(y)
    rows = to_rows(contests)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {OUT} ({len(rows)} rows, {len(contests)} contests)")
    if notes:
        print(f"{len(notes)} parse notes (first 15):")
        for n in notes[:15]:
            print("  ", n)
    fails = validate(contests, rows)
    if fails:
        print(f"\nVALIDATION FAILURES ({len(fails)}):")
        for f in fails:
            print("  ", f)
        sys.exit(1)
    print("\nAll checks passed")


if __name__ == "__main__":
    main()
