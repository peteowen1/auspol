#!/usr/bin/env python
"""Parse ECSA South Australian council election results (2018 PDFs, 2022 API)
into output/council-results-sa.csv. Run scripts/fetch_ecsa_council.py first.

2018 source: one council-level summary PDF per council (2018-lg-<council>.pdf,
  read with `pdftotext -raw`), giving first-preference votes, formal papers and
  elected status per contest. Per-contest PDFs are used only to cross-check the
  formal-paper totals. Contests the council PDFs omit because nobody was
  opposed are taken from the unopposed lists in the saved ECSA article.
2022 source: LGEStatic (candidates) joined to LGEChange (votes) by candidate uid.
  The API gives no formal-paper total, so ward_formal_votes is left blank and the
  vote check uses the quota bounds instead (quota = floor(F/(V+1))+1).

Exits non-zero if any validation fails.
"""
import copy, csv, glob, html, json, math, os, re, subprocess, sys
from collections import Counter, defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RAW = os.path.join(ROOT, "external", "reference", "ecsa", "council")
OUT = os.path.join(ROOT, "output", "council-results-sa.csv")
COLS = ["year", "council", "ward", "contest", "vacancies", "candidate", "surname", "given",
        "first_pref_votes", "first_pref_pct", "ward_formal_votes", "ward_enrolment",
        "elected", "contested", "source_file"]
TOL = 0.005
ALIAS = {"orrorroocarrieton": "Orroroo Carrieton", "orroroocarrieton": "Orroroo Carrieton"}


def key(s):
    return re.sub(r"[^a-z0-9]", "", s.lower().replace("&", ""))


def canon_council(s):
    s = re.sub(r"\s+", " ", s).strip()
    return ALIAS.get(key(s), s)


def nice_case(w):
    # upper-case surname words -> Title Case; mixed case (McKAY, De BONDI) kept
    if not w.isupper():
        return w
    return "-".join("'".join(p.capitalize() for p in h.split("'")) for h in w.split("-"))


def split_name(ballot):
    ballot = re.sub(r"\s+", " ", ballot).strip()
    if "," in ballot:
        sur, given = [x.strip() for x in ballot.split(",", 1)]
    else:
        sur, given = ballot, ""
    sur = " ".join(nice_case(w) for w in sur.split())
    return sur, given


def row(year, council, ward, contest, vac, name, votes, formal, enrol, elected, contested, src):
    sur, given = split_name(name)
    return dict(year=year, council=council, ward=ward, contest=contest, vacancies=vac,
                candidate=(given + " " + sur).strip(), surname=sur, given=given,
                first_pref_votes=votes, first_pref_pct="", ward_formal_votes=formal,
                ward_enrolment=enrol, elected=elected, contested=contested, source_file=src)


# ---------------------------------------------------------------- 2022
def parse_2022():
    d = os.path.join(RAW, "2022")
    st = json.load(open(glob.glob(os.path.join(d, "LGEStatic-*.json"))[0], encoding="utf-8"))
    ch = json.load(open(glob.glob(os.path.join(d, "LGEChange-*.json"))[0], encoding="utf-8"))
    chg = {}
    for co in ch["councils"]:
        for e in co["elections"]:
            if e is not None:
                chg[e["uid"]] = e
    rows, unknown = [], Counter()
    for co in st["councils"]:
        cname = canon_council(co["councilName"])
        for e in co["elections"]:
            nm = e["electionName"].strip()
            if re.search(r"mayor", nm, re.I):
                ward, contest = "", "mayor"
            elif re.match(r"area councillors?$", nm, re.I):
                ward, contest = "", "councillor"
            else:
                ward, contest = nm, "councillor"
                if not re.search(r"ward", nm, re.I):
                    unknown[nm] += 1
            c = chg.get(e["uid"])
            cands = e["candidates"] or []
            src = "LGEStatic+LGEChange-2022-08-23.json"
            new = []
            if c is None:  # no count: elected unopposed (or too few candidates)
                for k in cands:
                    new.append(row(2022, cname, ward, contest, e["vacancies"], k["ballotName"], "", "", "", True, False, src))
            else:
                votes = {k["uid"]: k for k in (c["candidates"] or [])}
                for k in cands:
                    v = votes.get(k["uid"])
                    new.append(row(2022, cname, ward, contest, e["vacancies"], k["ballotName"],
                                   v["firstPrefVotes"] if v else "", "", c.get("totalEnrollment") or "",
                                   bool(v and v["isElected"]), True, src))
                for r in new:
                    r["_quota"] = c.get("quota")
            rows += new
    if unknown:
        print("2022 contest names not mayor/area/ward:", dict(unknown))
    return rows


# ---------------------------------------------------------------- 2018
def pdftext(path, *extra):
    return subprocess.run(["pdftotext", "-raw", "-enc", "UTF-8", *extra, path, "-"], capture_output=True,
                          text=True, encoding="utf-8", check=True).stdout.replace("\r", "")


def contest_of(name):
    n = key(name)
    if n in ("mayoral", "mayor", "lordmayoral", "lordmayor"):
        return "", "mayor"
    if n in ("councillor", "councillors", "areacouncillor", "areacouncillors", "councilloratlarge",
             "councillorsatlarge"):
        return "", "councillor"
    return name.strip(), "councillor"


ROW_UNOPP = re.compile(r"^(?P<name>.+?) Elected Unopposed$")
ROW_VOTE = re.compile(r"^(?P<name>\S.*?, .+?) (?P<v>\d+)(?: (?P<rest>.*))?$")
NCAND = re.compile(r"^(\d+) candidates? contesting (\d+) vacanc")


def parse_council_pdf(path, cname, year=2018):
    lines = [l.strip("\f ").strip() for l in pdftext(path).split("\n")]
    n, i, blocks = len(lines), 0, []
    while i < n:
        if lines[i] == "1st" and i + 1 < n and lines[i + 1] == "Preference":
            j = i - 1
            formal = informal = None
            if j >= 1 and re.fullmatch(r"\d+ \d+", lines[j]):
                formal = int(lines[j].split()[0])
                j -= 1
                if re.fullmatch(r"\d+", lines[j]):
                    informal = int(lines[j])
                    j -= 1
            cl = lines[j]
            k = i
            while k < n and not NCAND.match(lines[k]):
                k += 1
            m = NCAND.match(lines[k])
            ncand, vac = int(m.group(1)), int(m.group(2))
            k += 1
            while k < n and lines[k] == "Ballot Papers":
                k += 1
            if k < n and re.fullmatch(r"[\d.]+%", lines[k]):
                k += 1
            cands = []
            while k < n and len(cands) < ncand:
                l = lines[k]
                mu, mv = ROW_UNOPP.match(l), ROW_VOTE.match(l)
                if mu:
                    cands.append((mu.group("name"), None, True))
                elif mv:
                    cands.append((mv.group("name"), int(mv.group("v")), bool(re.match(r"Elected", mv.group("rest") or ""))))
                else:
                    break
                k += 1
            blocks.append((cl, informal, formal, vac, ncand, cands))
            i = k
        else:
            i += 1
    src, rows = os.path.basename(path), []
    for (cl, informal, formal, vac, ncand, cands) in blocks:
        ward, contest = contest_of(cl)
        if len(cands) != ncand:
            raise SystemExit("PARSE ERROR %s %r: %d candidates parsed, header says %d" % (src, cl, len(cands), ncand))
        unopp = all(v is None for _, v, _ in cands)
        for name, v, el in cands:
            rows.append(row(year, cname, ward, contest, vac, name, "" if v is None else v,
                            formal if formal is not None else "", "", el, not unopp, src))
    return rows


def parse_article_unopposed(path, have):
    """Unopposed contests listed only in the saved article HTML."""
    h = open(path, encoding="utf-8", errors="replace").read()
    t = re.sub(r"<br\s*/?>", "\n", h)
    t = html.unescape(re.sub(r"<[^>]+>", "\n", t)).replace("\xa0", " ")
    L = [x for x in (re.sub(r"\s+", " ", x).strip() for x in t.split("\n")) if x]
    rows, skipped, council = [], [], None
    i = next((q for q, x in enumerate(L) if x == "ADELAIDE"), 0)
    name_re = re.compile(r"^[A-Z][^,]*, .+$")
    while i < len(L):
        x = L[i]
        if x.isupper() and "," not in x and not x.startswith(("PLEASE", "2018")) and len(x) > 2:
            council = x.title()
        if re.search(r"elected unopposed", x, re.I):
            m = re.match(r"^(Mayor|Area Councillor|Ward Councillor (.+?))\s*[-–]", x)
            if m and m.group(1) == "Mayor":
                ward, contest = "", "mayor"
            elif m and m.group(1) == "Area Councillor":
                ward, contest = "", "councillor"
            elif m:
                ward, contest = re.sub(r"\s+No Election.*$", "", m.group(2)).strip(), "councillor"
            elif x.startswith(("No Area Councillor", "No Election Required")):  # unlabelled list: taken as area councillors
                ward, contest = "", "councillor"
            else:
                ward = contest = None
            names, j = [], i + 1
            while j < len(L) and name_re.match(L[j]) and not L[j].startswith("2018"):
                names.append(L[j]); j += 1
            if ward is None:
                skipped.append((council, len(names)))
            else:
                ck = canon_council(council)
                if (ck, ward, contest) not in have:
                    for nm in names:
                        rows.append(row(2018, ck, ward, contest, "", nm, "", "", "", True, False, os.path.basename(path)))
            i = j
            continue
        i += 1
    return rows, skipped


def formal_from_contest_pdf(path):
    t = pdftext(path, "-l", "3")
    m = re.search(r"Total Formal Papers:\s*([\d,]+)", t) or re.search(r"Number of formal ballot papers:\s*([\d,]+)", t)
    return int(m.group(1).replace(",", "")) if m else None


def parse_2018():
    d = os.path.join(RAW, "2018")
    slugs = {os.path.basename(p)[8:-4]: p for p in sorted(glob.glob(os.path.join(d, "2018-lg-*.pdf")))}
    council_files, contest_files = {}, {}
    for s, p in slugs.items():
        t = pdftext(p, "-l", "1")
        (contest_files if ("Scrutiny Sheet" in t[:600] or "Totals After Count" in t[:3000]) else council_files)[s] = p
    s2022 = json.load(open(glob.glob(os.path.join(RAW, "2022", "LGEStatic-*.json"))[0], encoding="utf-8"))
    names22 = {key(canon_council(c["councilName"])): canon_council(c["councilName"]) for c in s2022["councils"]}
    rows = []
    for s, p in council_files.items():
        k = key(s)
        rows += parse_council_pdf(p, names22.get(k) or ALIAS.get(k) or s.replace("-", " ").title())
    have = {(r["council"], r["ward"], r["contest"]) for r in rows}
    extra, skipped = parse_article_unopposed(os.path.join(d, "article-id110.html"), have)
    if skipped:
        print("2018 article: %d unopposed lists with no contest label skipped: %s" % (len(skipped), skipped))
    rows += extra
    contest_formal = {}
    prefixes = sorted(council_files, key=len, reverse=True)
    for s, p in contest_files.items():
        pre = next((c for c in prefixes if s.startswith(c + "-")), None)
        contest_formal[s] = (pre, s[len(pre) + 1:] if pre else s, formal_from_contest_pdf(p))
    return rows, contest_formal, names22, council_files


def xcheck_2018(rows, contest_formal):
    formal = {}
    for r in rows:
        if r["ward_formal_votes"] != "":
            formal[(key(r["council"]), key(r["ward"]), r["contest"])] = r["ward_formal_votes"]
    ok = bad = un = 0
    msgs = []
    for s, (pre, rest, f) in contest_formal.items():
        if pre is None or f is None:
            un += 1; msgs.append("no council/formal total: " + s); continue
        ck, rk = key(pre), key(re.sub(r"-ward$", "", rest))
        if rest in ("mayor", "lord-mayor"):
            kk = (ck, "", "mayor")
        elif rest in ("area-councillor", "councillor", "councillor-at-large"):
            kk = (ck, "", "councillor")
        else:
            kk = next((q for q in formal if q[0] == ck and q[2] == "councillor" and q[1] and re.sub(r"ward$", "", q[1]) == rk), None)
        if kk not in formal:
            un += 1; msgs.append("unmatched contest PDF: " + s); continue
        if abs(int(formal[kk]) - f) <= TOL * f:  # off-by-one totals (marion-woodlands: 2408 vs 2409) tolerated and listed
            ok += 1
            if int(formal[kk]) != f:
                msgs.append("formal off by %d (within 0.5%%) %s" % (f - int(formal[kk]), s))
        else:
            bad += 1; msgs.append("formal differs %s: council pdf %s vs contest pdf %s" % (s, formal[kk], f))
    return ok, bad, un, msgs


# ---------------------------------------------------------------- validation
def contests(rows):
    g = defaultdict(list)
    for r in rows:
        g[(r["year"], r["council"], r["ward"], r["contest"])].append(r)
    return g


def vote_failures(rows):
    """Contests where the candidate-vote sum is more than 0.5% from the stated formal total."""
    bad = []
    for k, rs in contests(rows).items():
        f = rs[0]["ward_formal_votes"]
        if f in ("", None) or rs[0]["first_pref_votes"] == "":
            continue
        s = sum(int(r["first_pref_votes"]) for r in rs if r["first_pref_votes"] != "")
        if int(f) and abs(s - int(f)) / int(f) > TOL:
            bad.append((k, s, f))
    return bad


def quota_failures(rows):
    """2022: sum of first prefs F must satisfy quota = floor(F/(V+1))+1."""
    bad = []
    for k, rs in contests(rows).items():
        q = rs[0].get("_quota")
        if not q or rs[0]["first_pref_votes"] == "":
            continue
        F = sum(int(r["first_pref_votes"]) for r in rs if r["first_pref_votes"] != "")
        V = int(rs[0]["vacancies"])
        if math.floor(F / (V + 1)) + 1 != q:
            bad.append((k, F, V, q))
    return bad


def validate(rows):
    fails = []
    for y in (2018, 2022):
        yr = [r for r in rows if r["year"] == y]
        print("%d: rows(candidates)=%d councils=%d contests=%d" % (y, len(yr), len({r["council"] for r in yr}), len(contests(yr))))
    c = Counter((r["year"], r["council"], r["ward"], r["contest"], r["candidate"]) for r in rows)
    d = [k for k, n in c.items() if n > 1]
    if d: fails.append("duplicate candidates: %s" % d[:5])
    neg = [r for r in rows if r["first_pref_votes"] != "" and int(r["first_pref_votes"]) < 0]
    if neg: fails.append("negative votes: %d" % len(neg))
    vf = vote_failures(rows)
    n_v = sum(1 for rs in contests(rows).values() if rs[0]["ward_formal_votes"] != "" and rs[0]["first_pref_votes"] != "")
    print("vote-sum vs formal (0.5%%): %d contests checked, %d failures" % (n_v, len(vf)))
    if vf: fails.append("vote sum vs formal: %s" % vf[:8])
    qf = quota_failures(rows)
    n_q = sum(1 for rs in contests(rows).values() if rs[0].get("_quota") and rs[0]["first_pref_votes"] != "")
    print("2022 quota consistency: %d contests checked, %d failures" % (n_q, len(qf)))
    if qf: fails.append("quota inconsistency: %s" % qf[:8])
    ef = []
    for k, rs in contests(rows).items():
        v = rs[0]["vacancies"]
        if v == "":
            continue
        ne = sum(1 for r in rs if r["elected"])
        if ne != min(int(v), len(rs)):
            ef.append((k, ne, v, len(rs)))
    print("elected vs min(vacancies, candidates): %d contests mismatch" % len(ef))
    if ef: fails.append("elected count mismatches: %s" % ef[:15])
    for col in ("candidate", "surname", "contest", "council"):
        e = sum(1 for r in rows if not r[col])
        if e: fails.append("empty %s: %d rows" % (col, e))
    return fails


def self_test(rows):
    """The vote check must fail on a deliberately broken input (in memory only)."""
    t = copy.deepcopy(rows)
    victim = next(r for r in t if r["ward_formal_votes"] != "" and r["first_pref_votes"] != "" and int(r["ward_formal_votes"]) > 1000)
    victim["first_pref_votes"] = int(victim["first_pref_votes"]) + int(0.01 * int(victim["ward_formal_votes"])) + 1
    n = len(vote_failures(t))
    assert n > len(vote_failures(rows)), "vote check missed a >1% perturbation"
    print("self-test: bumping one candidate by >1%% of formal is caught (%d failure on perturbed copy)" % n)


def main():
    rows22 = parse_2022()
    rows18, contest_formal, names22, _ = parse_2018()
    rows = rows18 + rows22
    fails = validate(rows)
    ok, bad, un, msgs = xcheck_2018(rows18, contest_formal)
    print("2018 formal total, council PDF vs per-contest PDF: %d agree, %d differ, %d unmatched (of %d contest PDFs)"
          % (ok, bad, un, len(contest_formal)))
    for m in msgs[:25]:
        print("  ", m)
    if bad:
        fails.append("council vs contest PDF formal totals differ in %d contests" % bad)
    print("2022 councils absent from 2018 output:", sorted(set(names22.values()) - {r["council"] for r in rows18}))
    self_test(rows)
    for k, rs in contests(rows).items():
        tot = sum(int(r["first_pref_votes"]) for r in rs if r["first_pref_votes"] != "")
        for r in rs:
            if r["first_pref_votes"] != "" and tot:
                r["first_pref_pct"] = round(100.0 * int(r["first_pref_votes"]) / tot, 3)
    rows.sort(key=lambda r: (r["year"], r["council"], r["contest"] != "mayor", r["ward"],
                             -(int(r["first_pref_votes"]) if r["first_pref_votes"] != "" else -1)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLS, extrasaction="ignore")
        w.writeheader(); w.writerows(rows)
    print("wrote %s (%d rows)" % (OUT, len(rows)))
    if fails:
        for m in fails: print("VALIDATION FAILED:", m, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
