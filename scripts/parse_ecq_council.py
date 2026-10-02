#!/usr/bin/env python
"""Parse the raw ECQ local-government results into output/council-results-qld.csv.

Input:  external/reference/ecq/council/<year>/  (see fetch_ecq_council.py)
Output: output/council-results-qld.csv, one row per candidate per contest:
  year,council,ward,contest,vacancies,candidate,surname,given,first_pref_votes,
  first_pref_pct,ward_formal_votes,ward_enrolment,elected,contested,source_file

Conventions
  council   2020 lgaName (the 2024 rename "Moreton Bay City" is mapped back to
            "Moreton Bay Regional" so the key is stable across years).
  ward      division/ward name with the council-name prefix removed; "Undivided"
            for an undivided council's councillor contest; "Council-wide" for mayor.
  contest   councillor | mayor.
  candidate ballot name as printed, "SURNAME, Given"; surname/given split on the
            first comma of that same ballot name (so the preferred first name
            is comparable across years).
  votes     first-preference votes. For a multi-member contest ward_formal_votes
            is votes (ballots x seats), so candidate votes sum to it.
  vacancies 2020/2024: numberToElect / 1 for mayor from the electorates file.
            2008/2012/2016: the number of ticked (elected) candidates on the
            page, because the HTML does not print the seat count; blank when no
            candidate is ticked (undeclared count). The elected-vs-vacancies
            check is therefore only independent for 2020/2024.
  contested FALSE when the contest had no more candidates than seats (no vote
            was held); votes/pct/formal are then blank and elected is TRUE.
  ward_enrolment  electors at close of roll; for old-year mayor rows it is the
            sum over the council's ward pages (blank if any ward is missing).

Exit status is non-zero if any validation fails. Stdlib only.
Usage: python scripts/parse_ecq_council.py [--include-2008]   (2008 is partial; see main()).
"""
import copy
import csv
import html as htmllib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "external" / "reference" / "ecq" / "council"
OUT = ROOT / "output" / "council-results-qld.csv"
STUBS = {2020: "lga2020", 2024: "2024QLGE"}
COLS = ["year", "council", "ward", "contest", "vacancies", "candidate", "surname", "given",
        "first_pref_votes", "first_pref_pct", "ward_formal_votes", "ward_enrolment",
        "elected", "contested", "source_file"]
ALIAS = {"Moreton Bay City": "Moreton Bay Regional"}
EXPECTED_COUNCILS = {2024: 77, 2020: 77, 2016: 77, 2012: 73, 2008: 73}
# 2012/2008: 73 councils. Douglas, Livingstone, Mareeba and Noosa were created by
# de-amalgamation (2013/2014), so they have no 2012 or 2008 election.
KNOWN_GAPS = {(2012, "Aurukun Shire"): "The 2012 mayoral election was postponed to 16 June 2012 and every "
              "archived copy of the ECQ page is the 'postponed' notice; no results page was captured."}
TOL = 0.005  # candidate-vote sum vs formal total, relative

warnings = []


def num(s):
    s = (s or "").replace(",", "").strip()
    if s in ("", "-"):
        return None
    return float(s) if "." in s else int(s)


def pct(s):
    return float(s.replace("%", "").strip()) if s not in (None, "") else None


def split_name(ballot):
    ballot = re.sub(r"\s+", " ", ballot).strip()
    if "," in ballot:
        sur, given = ballot.split(",", 1)
        return sur.strip(), given.strip()
    return ballot, ""


def row(year, council, ward, contest, vac, cand, votes, pc, formal, enrol, elected, contested, src):
    sur, given = split_name(cand)
    return {"year": year, "council": council, "ward": ward, "contest": contest, "vacancies": vac,
            "candidate": re.sub(r"\s+", " ", cand).strip(), "surname": sur, "given": given,
            "first_pref_votes": votes, "first_pref_pct": pc, "ward_formal_votes": formal,
            "ward_enrolment": enrol, "elected": elected, "contested": contested, "source_file": src}


def read_json(p):
    return json.loads(p.read_text(encoding="utf-8-sig"))


# ------------------------------------------------------------------ 2020 / 2024
def parse_json_year(year):
    stub = STUBS[year]
    d = RAW / str(year)
    els = read_json(d / f"{stub}-electorates.json")["electorates"]
    decl = read_json(d / f"{stub}-declared_candidates.json")["declaredCandidates"]
    winners = defaultdict(set)  # (areaCode, contest) -> ballot orders
    for x in decl:
        lst = x.get("declaredCandidates") or [x]
        for c in lst:
            winners[(x["areaCode"], x["contest"].lower())].add(c["declaredCandidateBallotOrder"])
    mayors = {e["areaCode"]: e for e in els if e["contestType"] == "Mayor"}
    rows = []
    for e in els:
        ac = e["areaCode"]
        parent = mayors[ac[:3]]
        council = ALIAS.get(parent["lgaName"], parent["lgaName"])
        if e["contestType"] == "Mayor":
            contest, ward, vac, cands = "mayor", "Council-wide", 1, e.get("candidatesMayor") or []
            fname = f"{stub}-primary-count-summary-{ac}-mayor.json"
            enrol = e.get("enrolment")
        else:
            contest, vac, cands = "councillor", e["numberToElect"], e.get("candidatesCouncillor") or []
            enrol = e.get("enrolment")
            if parent["electorateType"] == "Council - Undivided":
                ward = "Undivided"
            else:
                ward = e["electorateName"]
                if ward.startswith(parent["lgaName"] + " "):
                    ward = ward[len(parent["lgaName"]) + 1:]
            fname = f"{stub}-primary-count-division-{ac}-councillor.json"
        won = winners.get((ac, contest), set())
        f = d / fname
        if f.exists():
            cnt = read_json(f)
            formal = cnt.get("formalVotes")
            for c in cnt["candidates"]:
                rows.append(row(year, council, ward, contest, vac, c["ballotName"], c["count"],
                                pct(c.get("percentage")), formal, enrol,
                                c["ballotOrderNumber"] in won, True, f"{year}/{fname}"))
        else:
            if len(cands) > vac:
                warnings.append(f"{year} {council} {ward} {contest}: contested but no count file")
            for c in cands:
                rows.append(row(year, council, ward, contest, vac, c["ballotName"], None, None, None,
                                enrol, c["ballotOrderNumber"] in won, False,
                                f"{year}/{stub}-electorates.json"))
    return rows


# ------------------------------------------------------------ 2016 / 2012 / 2008
def read_html(p):
    raw = p.read_bytes()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252", "replace")


def textify(h):
    t = re.sub(r"<script.*?</script>|<style.*?</style>", "", h, flags=re.S | re.I)
    t = re.sub(r"<[^>]+>", " ", t)
    return re.sub(r"\s+", " ", htmllib.unescape(t))


def parse_page(h):
    """Parse one ECQ results page. Returns dict, or None when there is no results table."""
    m = re.search(r"columnHeading[^>]*>\s*(?:<[^>]+>\s*)*Candidate", h)
    if not m:
        # unopposed pages without a table: "<td>SURNAME, Given elected unopposed</td>"
        names = [re.sub(r"\s+", " ", htmllib.unescape(x)).strip()
                 for x in re.findall(r"<td>\s*([^<>]+?)\s+elected unopposed\s*</td>", h)]
        if not names:
            return None
        return {"cands": [{"name": n, "votes": None, "pct": None, "elected": True} for n in names],
                "formal": None, "enrol": None, "booths": None, "unopposed": True, "ward": None}
    if "Results Summary" not in h[max(0, m.start() - 1500):m.start()]:
        return None  # a later table (e.g. two-candidate-preferred), not the first-preference one
    end = h.find("Total Formal Votes", m.end())
    if end < 0:
        return None
    seg = h[m.end():end]
    cands = []
    for chunk in re.split(r'<tr class="contentRow(?:Odd|Even)">', seg)[1:]:
        nums = re.findall(r'class="rightAlign">\s*([\d,.]+)\s*</td>', chunk)
        tds = re.findall(r"<td[^>]*>(.*?)</td>", chunk, flags=re.S)
        if len(nums) < 2 or not tds:
            continue  # legend / separator rows
        name = re.sub(r"\s+", " ", htmllib.unescape(re.sub(r"<[^>]+>", " ", tds[0]))).strip()
        if not name:
            continue
        cands.append({"name": name, "votes": num(nums[0]), "pct": pct(nums[1]),
                      "elected": "tick.gif" in chunk})
    txt = textify(h)
    fm = re.search(r"Total Formal Votes\s*([\d,]+)", txt)
    em = re.search(r"Electors at Close of Roll:\s*([\d,]+)", txt)
    bm = re.search(r"Booths In:\s*(\d+)\s*of\s*(\d+)", txt)
    title = re.sub(r"\s+", " ", (re.search(r"<title>(.*?)</title>", h, re.S) or [None, ""])[1]).strip()
    tm = re.search(r"Councillor Election - (.+) - [^-]*Summary\s*$", title)
    ward = tm.group(1).strip() if tm else None
    if "Undivided Council Profile" in txt:
        ward = "Undivided"
    return {"cands": cands, "formal": num(fm.group(1)) if fm else None,
            "enrol": num(em.group(1)) if em else None,
            "booths": (int(bm.group(1)), int(bm.group(2))) if bm else None,
            "unopposed": "Elected Unopposed" in h, "ward": ward}


def natkey(p):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", p.name)]


def parse_html_year(year, names):
    """names: dict slug-key -> canonical council name."""
    d = RAW / str(year)
    rows, councils, unmatched = [], set(), []
    incomplete = []
    for cdir in sorted(p for p in d.iterdir() if p.is_dir()):
        key = re.sub(r"[^a-z]", "", cdir.name.lower())
        key = re.sub(r"council$", "", key)
        council = names.get(key)
        if council is None:
            unmatched.append(cdir.name)
            council = cdir.name
        ward_enrol, ward_missing = 0, False
        pages = []
        for f in sorted(cdir.glob("councillor_district*.html"), key=natkey):
            pages.append(("councillor", f))
        cs_path = cdir / "councillor_summary.html"
        if not pages and cs_path.exists():
            # undivided council, every councillor unopposed: names are only on the summary page
            um = re.search(r"Elected Unopposed.*?<td><p>(.*?)</p></td>", read_html(cs_path), flags=re.S)
            if um:
                names_ = [re.sub(r"\s+", " ", htmllib.unescape(x)).strip()
                          for x in re.split(r"<br\s*/?>", um.group(1))]
                names_ = [x for x in names_ if x and x.lower() != "elected unopposed"]
                src = f"{year}/{cdir.name}/councillor_summary.html"
                councils.add(council)
                for n_ in names_:
                    rows.append(row(year, council, "Undivided", "councillor", len(names_), n_, None, None,
                                    None, None, True, False, src))
                ward_missing = True
            else:
                warnings.append(f"{year}/{cdir.name}: no councillor ward pages and no unopposed list")
        mf = cdir / "mayoral_summary.html"
        md = cdir / "mayoral_district1.html"
        if md.exists():  # fallback written by the fetcher when the summary has no first-pref table
            mf = md
        if mf.exists():
            pages.append(("mayor", mf))
        for contest, f in pages:
            pg = parse_page(read_html(f))
            src = f"{year}/{cdir.name}/{f.name}"
            if pg is None:
                warnings.append(f"{src}: no results table (page skipped)")
                if contest == "councillor":
                    ward_missing = True
                continue
            ticks = sum(c["elected"] for c in pg["cands"])
            vac = ticks if ticks else None
            contested = not pg["unopposed"]
            if contest == "mayor":
                ward = "Council-wide"
            else:
                ward = pg["ward"] or f.stem.replace("councillor_district", "District ")
                if ward.startswith(council + " "):
                    ward = ward[len(council) + 1:]
                if pg["enrol"] is None:
                    ward_missing = True
                else:
                    ward_enrol += pg["enrol"]
            if (pg["booths"] and contested and pg["booths"][0] < pg["booths"][1]
                    and not re.search(r">\s*Declared\s*<", read_html(f))):
                incomplete.append(f"{src} booths {pg['booths'][0]}/{pg['booths'][1]}")
            councils.add(council)
            for c in pg["cands"]:
                rows.append(row(year, council, ward, contest, vac, c["name"],
                                c["votes"] if contested else None,
                                c["pct"] if contested else None,
                                pg["formal"] if contested else None,
                                pg["enrol"] if contest == "councillor" else "MAYOR_ENROL",
                                c["elected"], contested, src))
        # mayor enrolment = sum of this council's ward enrolments (blank if any missing)
        for r in rows:
            if r["ward_enrolment"] == "MAYOR_ENROL" and r["council"] == council and r["year"] == year:
                r["ward_enrolment"] = None if ward_missing or not ward_enrol else ward_enrol
    if unmatched:
        warnings.append(f"{year}: folders not matched to a 2020 council name: {unmatched}")
    if incomplete:
        warnings.append(f"{year}: {len(incomplete)} contested pages with booths-in < booths-total and NOT marked Declared "
                        f"(count may not be final in the snapshot): " + "; ".join(incomplete[:8])
                        + (" ..." if len(incomplete) > 8 else ""))
    return rows


def council_names():
    els = read_json(RAW / "2020" / "lga2020-electorates.json")["electorates"]
    out = {}
    for e in els:
        if e["contestType"] == "Mayor":
            k = re.sub(r"[^a-z]", "", e["lgaName"].lower())
            out[k] = e["lgaName"]
    return out


# ------------------------------------------------------------------- validation
def contests_of(rows):
    g = defaultdict(list)
    for r in rows:
        g[(r["year"], r["council"], r["ward"], r["contest"])].append(r)
    return g


def vote_check(rows):
    """Return list of contests whose candidate-vote sum differs from the formal total by > TOL."""
    bad = []
    for k, rs in contests_of(rows).items():
        if not rs[0]["contested"] or rs[0]["ward_formal_votes"] in (None, 0):
            continue
        s = sum(r["first_pref_votes"] or 0 for r in rs)
        f = rs[0]["ward_formal_votes"]
        if abs(s - f) / f > TOL:
            bad.append((k, s, f))
    return bad


def validate(rows):
    fails = []
    # 1. coverage per year
    print("\n== per year (rows / councils / contests: councillor+mayor / candidates)")
    by_year = defaultdict(list)
    for r in rows:
        by_year[r["year"]].append(r)
    for y in sorted(by_year):
        rs = by_year[y]
        cs = contests_of(rs)
        ncl = {k[1] for k in cs}
        nc = sum(1 for k in cs if k[3] == "councillor")
        nm = sum(1 for k in cs if k[3] == "mayor")
        print(f"{y}: rows={len(rs)} councils={len(ncl)} contests={nc}+{nm} "
              f"candidates={len({(r['council'], r['ward'], r['contest'], r['candidate']) for r in rs})} "
              f"uncontested_contests={sum(1 for k, v in cs.items() if not v[0]['contested'])}")
        if len(ncl) != EXPECTED_COUNCILS.get(y, 0):
            fails.append(f"{y}: {len(ncl)} councils, expected {EXPECTED_COUNCILS.get(y)}")
        mayor_councils = {k[1] for k in cs if k[3] == "mayor"}
        for c_ in sorted(ncl - mayor_councils):
            if (y, c_) in KNOWN_GAPS:
                warnings.append(f"{y} {c_}: mayoral contest absent. {KNOWN_GAPS[(y, c_)]}")
            else:
                fails.append(f"{y}: mayoral contest missing for {c_}")
    # 2. vote sums vs formal totals
    bad = vote_check(rows)
    n_checked = sum(1 for v in contests_of(rows).values()
                    if v[0]["contested"] and v[0]["ward_formal_votes"])
    print(f"\n== candidate-vote sum vs formal total (tolerance {TOL:.1%}): "
          f"{n_checked} contests checked, {len(bad)} outside tolerance")
    for k, s, f in bad[:25]:
        fails.append(f"vote sum {k}: candidates {s} vs formal {f}")
    # contested contests with no formal total at all
    no_formal = [k for k, v in contests_of(rows).items()
                 if v[0]["contested"] and not v[0]["ward_formal_votes"]]
    print(f"   contested contests with no formal total to check against: {len(no_formal)}")
    # 3. elected vs vacancies
    print("\n== elected vs vacancies")
    for y in sorted(by_year):
        cs = {k: v for k, v in contests_of(by_year[y]).items()}
        if y in STUBS:
            wrong = [(k, sum(r["elected"] for r in v), v[0]["vacancies"]) for k, v in cs.items()
                     if sum(r["elected"] for r in v) != v[0]["vacancies"]]
            print(f"{y}: independent check (numberToElect): {len(wrong)} of {len(cs)} contests differ")
            for k, e, vac in wrong[:25]:
                fails.append(f"{y} elected {e} != vacancies {vac} in {k[1:]}")
        else:
            badm = [k for k, v in cs.items() if k[3] == "mayor" and sum(r["elected"] for r in v) != 1]
            print(f"{y}: mayoral contests with elected != 1 (independent: a mayor is always one seat): {len(badm)}")
            for k in badm[:25]:
                fails.append(f"{y} mayor elected count != 1 in {k[1]}")
            none = [k for k, v in cs.items() if not any(r["elected"] for r in v)]
            print(f"{y}: vacancies = ticks (circular); contests with nobody elected: {len(none)} of {len(cs)}")
            for k in none[:25]:
                warnings.append(f"{y} no elected candidate on page: {k[1:]}")
    # 4. sanity
    neg = [r for r in rows if any((r[c] is not None and r[c] < 0) for c in
                                  ("first_pref_votes", "first_pref_pct", "ward_formal_votes", "ward_enrolment"))]
    print(f"\n== negative values: {len(neg)}")
    fails += [f"negative value {r['year']} {r['council']} {r['ward']} {r['candidate']}" for r in neg[:10]]
    keys = Counter((r["year"], r["council"], r["ward"], r["contest"], r["candidate"]) for r in rows)
    dup = [k for k, v in keys.items() if v > 1]
    print(f"== duplicate (year,council,ward,contest,candidate): {len(dup)}")
    fails += [f"duplicate {k}" for k in dup[:10]]
    # 5. coverage of key columns (not just presence)
    print("\n== column coverage (share non-blank) by year")
    for y in sorted(by_year):
        rs = by_year[y]
        cov = {c: sum(1 for r in rs if r[c] not in (None, "")) / len(rs)
               for c in ("surname", "given", "first_pref_votes", "first_pref_pct", "ward_formal_votes",
                         "ward_enrolment", "vacancies")}
        print(y, " ".join(f"{c}={v:.0%}" for c, v in cov.items()))
    return fails


def self_test_vote_check(rows):
    """Prove the vote check can fail: perturb one value in a copy; it must be flagged."""
    base = vote_check(rows)
    victim = next(r for r in rows if r["contested"] and r["ward_formal_votes"] and r["first_pref_votes"])
    t = copy.deepcopy(rows)
    for r in t:
        if (r["year"], r["council"], r["ward"], r["contest"], r["candidate"]) == \
           (victim["year"], victim["council"], victim["ward"], victim["contest"], victim["candidate"]):
            r["first_pref_votes"] = int(r["first_pref_votes"] * 1.05) + 50
    after = vote_check(t)
    ok = len(after) == len(base) + 1
    print(f"\n== self-test: perturbing one candidate's votes by +5% "
          f"flagged {len(after) - len(base)} extra contest(s): {'PASS' if ok else 'FAIL'}")
    return ok


def main():
    names = council_names()
    rows = []
    # 2008 is excluded by default: the Wayback capture holds mayoral pages for most councils
    # but almost no ward-level councillor pages, and its old council set (e.g. Dalby Regional)
    # does not map to the 2020 names. Pass --include-2008 to parse what exists anyway.
    years = (2008, 2012, 2016, 2020, 2024) if "--include-2008" in sys.argv else (2012, 2016, 2020, 2024)
    for y in years:
        d = RAW / str(y)
        if not d.exists():
            print(f"{y}: no raw data directory, skipped")
            continue
        r = parse_json_year(y) if y in STUBS else parse_html_year(y, names)
        print(f"{y}: parsed {len(r)} rows")
        rows += r
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS)
        w.writeheader()
        for r in rows:
            r = dict(r)
            r["elected"] = "TRUE" if r["elected"] else "FALSE"
            r["contested"] = "TRUE" if r["contested"] else "FALSE"
            w.writerow({c: ("" if r[c] is None else r[c]) for c in COLS})
    print(f"wrote {OUT} ({len(rows)} rows)")
    fails = validate(rows)
    if not self_test_vote_check(rows):
        fails.append("vote-check self-test did not detect a perturbed value")
    print(f"\n== {len(warnings)} warnings")
    for w_ in warnings[:80]:
        print("  WARN", w_)
    if fails:
        print(f"\n{len(fails)} VALIDATION FAILURES")
        for f in fails[:80]:
            print("  FAIL", f)
        sys.exit(1)
    print("\nAll validation checks passed")


if __name__ == "__main__":
    main()
