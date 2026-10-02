#!/usr/bin/env python3
"""Parse the NSWEC local-government results stored by fetch_nswec_council.py
into output/council-results-nsw.csv (one row per candidate per contest).

Years: 2008, 2012, 2016, 2017, 2021, 2024; councillor and mayor contests.
Only councils whose election the NSWEC ran have data; the rest are listed at
the end of the run.

How above-the-line (ATL) group votes are handled
  NSW councillor elections (PR) let a voter vote for a group. Those votes are
  NOT in any candidate's own count. Each candidate row carries the candidate's
  OWN first preferences only (2021/24 CSV "Total" column; 2016/17 and 2012
  candidate rows; 2008 "1st Pref" column). ATL votes are never written to the
  CSV; they are used only by the validation (candidate + ATL vs formal votes).
  So first_pref_votes is below the true group-adjusted count for candidates in
  groups. first_pref_pct = first_pref_votes / ward_formal_votes * 100.

Sources per year
  2021, 2024  CSV firstpreferencebyvenuevt.csv (councillor); HTML (mayor)
  2016, 2017  HTML "fp_by_grp_and_candidate_by_vote_type" (group + candidate rows)
  2012        PDF report "03 First Preferences by Group and Candidate" (full
              names; the site's HTML table has surnames only); mayor from HTML
  2008        PDF "02 SummaryFirstPref" (final count, names as "SURNAME I.") joined
              by ballot order to the HTML summary page for full given names; mayor HTML

Standard library plus PyMuPDF (fitz, already installed) for the 2008/2012 PDFs.
Exit status is non-zero if validation fails.
"""
import csv
import glob
import html as htmllib
import os
import re
import sys
from collections import defaultdict, Counter

try:
    import fitz  # PyMuPDF
except ImportError:  # pragma: no cover
    fitz = None

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.normpath(os.path.join(HERE, "..", "external", "reference", "nsw", "council"))
OUT = os.path.normpath(os.path.join(HERE, "..", "output", "council-results-nsw.csv"))
COLS = ["year", "council", "ward", "contest", "vacancies", "candidate", "surname", "given",
        "first_pref_votes", "first_pref_pct", "ward_formal_votes", "ward_enrolment",
        "elected", "contested", "source_file"]
YEARS = [2008, 2012, 2016, 2017, 2021, 2024]
TOL = 0.005  # vote-sum tolerance against formal votes


# ------------------------------------------------------------------ helpers
def rd(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-8", "replace")


def rel(path):
    """Path relative to the repo root, forward slashes."""
    return os.path.relpath(path, os.path.normpath(os.path.join(HERE, ".."))).replace("\\", "/")


def num(s):
    s = (s or "").replace(",", "").replace("%", "").strip()
    try:
        return int(s)
    except ValueError:
        try:
            return float(s)
        except ValueError:
            return None


def table_rows(h):
    out = []
    for tr in re.findall(r"(?s)<tr[^>]*>(.*?)</tr>", h):
        cells = re.findall(r"(?s)<t[dh][^>]*>(.*?)</t[dh]>", tr)
        out.append([htmllib.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", c))).strip()
                    for c in cells])
    return out


def text_of(h):
    h = re.sub(r"(?s)<(script|style).*?</\1>", "", h)
    h = re.sub(r"(?s)<!--.*?-->", "", h)
    h = re.sub(r"</(tr|p|div|h\d|li)>", "\n", h)
    h = re.sub(r"</t[dh]>", " | ", h)
    h = htmllib.unescape(re.sub(r"<[^>]+>", " ", h))
    return re.sub(r"[ \t\r\xa0]+", " ", re.sub(r"\n\s*\n+", "\n", h))


UPPER = re.compile(r"^(Mc|Mac|O')?[A-Z][A-Z'’\-\.]*$")


def is_upper(tok):
    return bool(UPPER.match(tok)) and any(c.isalpha() for c in tok)


PARTICLES = {"de", "van", "von", "der", "den", "la", "le", "du", "di", "da", "del", "dos", "el"}


def split_sg(name):
    """'SURNAME Given' (no comma) -> (surname, given)."""
    toks = name.split()
    if not toks:
        return "", ""
    i = 0
    while i < len(toks) and (is_upper(toks[i]) or (
            toks[i] in PARTICLES and i + 1 < len(toks) and is_upper(toks[i + 1]))):
        i += 1                      # surname words, incl. lower-case particles: "de VIVE Suzanne"
    if i == 0:
        i = 1
    if i == len(toks) and len(toks) > 1 and len(toks[-1]) <= 2:  # "SMITH J": last is an initial
        i -= 1
    return " ".join(toks[:i]), " ".join(toks[i:])


def split_comma(name):
    if "," in name:
        s, g = name.split(",", 1)
        return s.strip(), g.strip()
    return split_sg(name)


def key(name):
    """Order-free key so 'Henk VAN DE VEN' matches 'VAN DE VEN Henk'."""
    name = re.sub(r"\([^)]*\)", " ", name)          # nicknames: "ZHOU Shuo (Simon)"
    return " ".join(sorted(re.sub(r"[^A-Z0-9 ]", "", name.upper().replace("-", " ")).split()))


def parse_elected_names(s):
    """'Victor BARTLEY (IND) Sarah BARTON Sally DAVIS' -> ['Victor BARTLEY', ...]"""
    s = re.sub(r"\([^)]*\)", " ) ", s)
    out, given, sur = [], [], []

    def flush():
        if given or sur:
            out.append(" ".join(given + sur))
        given.clear()
        sur.clear()

    for tok in s.split():
        if tok == ")":
            flush()
        elif is_upper(tok):
            sur.append(tok)
        else:
            if sur:
                flush()
            given.append(tok)
    flush()
    return out


def title_slug(slug):
    return " ".join(w.capitalize() for w in slug.split("-"))


class Contest(dict):
    """year, council, ward, contest, vacancies, enrolment, formal, source, cands, atl, elected_keys,
    elected_names, contested"""


def new_contest(year, council, ward, contest, source):
    return Contest(year=year, council=council, ward=ward, contest=contest, vacancies=None,
                   enrolment=None, formal=None, source=source, cands=[], atl=None,
                   elected_keys=[], elected_names=[], contested=True, note="")


def cand(name, surname, given, votes, elected_flag=None, group=None):
    return dict(name=name, surname=surname, given=given, votes=votes, elected=elected_flag, group=group)


# ------------------------------------------------------------- 2021 and 2024
def council_names_lg(year):
    code = "LG%02d01" % (year % 100)
    idx = rd(os.path.join(RAW, str(year), "index.html"))
    names = {}
    for title, slug, label in re.findall(r'title="([^"]*)"\s+href="/%s/([^/"]+)/results">\s*([^<]*?)\s*<' % code, idx):
        title = htmllib.unescape(title)
        names[slug] = re.sub(r"^Election results for\s+", "", title) if title.startswith("Election results for")             else htmllib.unescape(label) or title_slug(slug)
    for slug in re.findall(r'href="/%s/([^/"]+)/results"' % code, idx):
        names.setdefault(slug, title_slug(slug))
    return names


def parse_lg(year):
    base = os.path.join(RAW, str(year))
    names = council_names_lg(year)
    out = []
    pages = sorted(glob.glob(os.path.join(base, "**", "councillor.html"), recursive=True) +
                   glob.glob(os.path.join(base, "**", "mayoral.html"), recursive=True))
    for pg in pages:
        r = os.path.relpath(pg, base).replace("\\", "/")
        parts = r[:-5].split("/")           # council[/ward]/kind
        slug, kind = parts[0], parts[-1]
        ward = title_slug(parts[1]) if len(parts) == 3 else ""
        c = new_contest(year, names.get(slug, title_slug(slug)), ward,
                        "mayor" if kind == "mayoral" else "councillor", rel(pg))
        h = rd(pg)
        t = text_of(h)
        m = re.search(r"Total Number of Electors:\s*([\d,]+)", t)
        c["enrolment"] = num(m.group(1)) if m else None
        unc = "UNCONTESTED" in t.upper()
        # declared elected (page text)
        m = re.search(r"candidates were declared elected on [^:]*:(.*?)(?:Status History|Final Results|$)", t, re.S)
        if m:
            c["elected_names"] = parse_elected_names(" ".join(m.group(1).split()))
        for m in re.finditer(r"([^\n|]+?)\s+was declared elected" if kind == "mayoral" else r"(?!)", t):
            c["elected_names"].append(" ".join(re.sub(r"\([^)]*\)", "", m.group(1)).split()))
        m = re.search(r"There (?:is|are) (\d+)\s+(?:Councillors?|Mayor)", t)
        if m:
            c["vacancies"] = int(m.group(1))
        if unc:
            c["contested"] = False
            c["vacancies"] = c["vacancies"] or len(c["elected_names"])
            c["elected_keys"] = [key(n) for n in c["elected_names"]]
            for n in c["elected_names"]:  # given-first names -> candidate rows
                toks = n.split()
                j = next((i for i, tk in enumerate(toks) if is_upper(tk)), len(toks) - 1)
                c["cands"].append(cand(n, " ".join(toks[j:]), " ".join(toks[:j]), None, True))
            out.append(c)
            continue
        d = os.path.dirname(pg)
        if kind == "mayoral":
            fp = os.path.join(d, "mayoral", "mayoral-fp-by-candidate.html")
            c["vacancies"] = 1
            c["source"] = rel(fp)
            rows = table_rows(rd(fp))
            for r_ in rows:
                if len(r_) >= 3 and r_[0].upper().startswith("TOTAL FORMAL"):
                    c["formal"] = num(r_[-2] if len(r_) > 3 else r_[-1])
                elif len(r_) >= 4 and num(r_[2]) is not None and re.match(r"[A-Za-z]", r_[0]) \
                        and "%" in r_[3]:
                    sn, gv = split_sg(r_[0])
                    c["cands"].append(cand(r_[0], sn, gv, int(num(r_[2]))))
            # a "TOTAL FORMAL VOTES" row has 4 cells: label, '', total, 100%
            if c["formal"] is None:
                for r_ in rows:
                    if r_ and r_[0].upper().startswith("TOTAL FORMAL"):
                        nums = [num(x) for x in r_[1:] if num(x) is not None]
                        c["formal"] = int(nums[0]) if nums else None
            c["elected_keys"] = [key(n) for n in c["elected_names"]]
        else:
            ctx = os.path.join(d, "councillor")
            gs = text_of(rd(os.path.join(ctx, "general-statistics.html")))
            m = re.search(r"Total Formal Votes\s*\|?\s*([\d,]+)", gs)
            c["formal"] = num(m.group(1)) if m else None
            m = re.search(r"Candidates to be Elected:\s*(\d+)", gs)
            if m:
                c["vacancies"] = int(m.group(1))
            # elected: candidate-results page
            res = rd(os.path.join(ctx, "grp-and-candidates-result.html"))
            c["elected_keys"] = []
            for r_ in table_rows(res):
                for j, cell in enumerate(r_):
                    if cell.upper().startswith("ELECTED") and "/" not in cell and j > 0:
                        nm = next((x for x in r_[:j][::-1] if re.search(r"[A-Za-z]{2}", x)), "")
                        c["elected_keys"].append(key(nm))
                        break
            csvp = os.path.join(d, "download", "firstpreferencebyvenuevt.csv")
            c["source"] = rel(csvp)
            with open(csvp, "r", encoding="utf-8-sig", newline="") as f:
                rows = list(csv.reader(f))
            hdr = rows[0]
            lc = 1 if hdr[0].strip() == "Group" else 0      # label column: councils without groups have no Group column
            if hdr[-1].strip() != "Total":
                raise SystemExit("unexpected CSV header end in %s: %r" % (csvp, hdr[-1]))
            atl = 0
            grp = None
            for r_ in rows[1:]:
                if not r_ or all(not x.strip() for x in r_):
                    continue
                if lc == 1 and r_[0].strip():
                    grp = r_[0].strip()
                label, total = r_[lc].strip(), num(r_[-1])
                if not label:       # group header row with no ATL box (group letter only)
                    continue
                if label == "ATL Votes":
                    atl += int(total or 0)
                    continue
                if label.upper().startswith("TOTAL FORMAL"):
                    if c["formal"] is None:
                        c["formal"] = int(total)
                    elif c["formal"] != int(total):
                        c["note"] += " csv formal %s != stats %s" % (int(total), c["formal"])
                    continue
                if label.upper().startswith(("UNGROUPED", "TOTAL", "INFORMAL")):
                    continue
                if total is None:
                    raise SystemExit("non-numeric total in %s: %r" % (csvp, r_[:3]))
                sn, gv = split_sg(label)
                c["cands"].append(cand(label, sn, gv, int(total), group=grp))
            c["atl"] = atl
        out.append(c)
    return out


# --------------------------------------------------------------- 2016 / 2017
def council_names_static(year):
    f = os.path.join(RAW, str(year), "lge-index.html")
    idx = rd(f)
    names = {}
    for slug, label in re.findall(r'href="/LGE%d/([^/"]+)/index\.htm"[^>]*>\s*([^<]+?)\s*<' % year, idx):
        if slug not in ("results", "schedule", "status") and label.strip():
            names[slug] = htmllib.unescape(label.strip())
    return names


def parse_static(year):
    base = os.path.join(RAW, str(year))
    names = council_names_static(year)
    out = []
    for sm in sorted(glob.glob(os.path.join(base, "**", "summary.html"), recursive=True)):
        d = os.path.dirname(sm)
        r = os.path.relpath(d, base).replace("\\", "/").split("/")
        slug = r[0]
        tail = r[1:]
        if not tail:
            continue
        if tail[-1] in ("referendum", "poll"):
            continue
        is_mayor = tail[-1] == "mayoral"
        wardparts = [x for x in tail if x not in ("councillor", "mayoral")]
        ward = title_slug(wardparts[0]) if wardparts else ""
        c = new_contest(year, names.get(slug, title_slug(slug)), ward,
                        "mayor" if is_mayor else "councillor", rel(sm))
        h = rd(sm)
        t = text_of(h)
        m = re.search(r"enrolled\s+in\s+(?:this\s+)?(?:Council area|Ward|ward|council area)\s+on[^.]*?was\s+([\d,]+)", t, re.S) \
            or re.search(r"Electors[^.]*?was\s+([\d,]+)\.", t, re.S) \
            or re.search(r"Total Number of Electors[^\d]*([\d,]+)", t)
        c["enrolment"] = num(m.group(1)) if m else None
        m = re.search(r"There (?:were|was|are|is)\s+(\d+)\s+(?:Councillors?|Mayor)", t)
        if m:
            c["vacancies"] = int(m.group(1))
        c["elected_names"] = [" ".join(re.sub(r"\([^)]*\)", "", x).split())
                              for x in re.findall(r"([^\n|]+?)\s*\n\s*was declared elected", t)]
        c["elected_names"] = [x for x in c["elected_names"] if x]
        c["elected_keys"] = [key(n) for n in c["elected_names"]]
        if is_mayor:
            c["vacancies"] = 1
            for r_ in table_rows(h):
                if len(r_) >= 3 and r_[0].upper().startswith("TOTAL FORMAL"):
                    nums = [num(x) for x in r_[1:] if num(x) is not None]
                    c["formal"] = int(nums[0]) if nums else None
                elif len(r_) >= 3 and re.match(r"[A-Za-z]", r_[0]) and num(r_[2]) is not None and "FP" not in r_[2] \
                        and not r_[0].lower().startswith(("total", "informal", "candidate")):
                    sn, gv = split_sg(r_[0])
                    c["cands"].append(cand(r_[0], sn, gv, int(num(r_[2]))))
            if not c["cands"]:
                c["note"] = "no first-preference table (uncontested?)"
                c["contested"] = False
        else:
            fp = os.path.join(d, "fp_by_grp_and_candidate_by_vote_type.html")
            if not os.path.isfile(fp) or "uncontested" in t.lower():
                c["contested"] = False
                c["vacancies"] = c["vacancies"] or len(c["elected_names"])
                for n in c["elected_names"]:
                    toks = n.split()
                    j = next((i for i, tk in enumerate(toks) if is_upper(tk)), len(toks) - 1)
                    c["cands"].append(cand(n, " ".join(toks[j:]), " ".join(toks[:j]), None, True))
                out.append(c)
                continue
            c["source"] = rel(fp)
            gs = text_of(rd(os.path.join(d, "general_statistics.html")))
            m = re.search(r"Total Formal Votes\s*\|?\s*([\d,]+)", gs)
            c["formal"] = num(m.group(1)) if m else None
            m = re.search(r"Candidates to be Elected:\s*(\d+)", gs)
            if m:
                c["vacancies"] = int(m.group(1))
            # Layout: a group header row (group letter; ATL votes in the "Votes / Ballot Papers"
            # column, blank when the group got none), then its candidates, then "Group Total"
            # (= ATL + candidates). Councils without groups have no Group column at all.
            atl, grp, gatl, gsum = 0, None, 0, 0
            off = 0
            for r_ in table_rows(rd(fp)):
                if r_ and r_[0] == "Group":
                    off = 1
                    continue
                if r_ and r_[0].startswith("Candidates in Ballot Order"):
                    off = 0
                    continue
                if len(r_) < 4 + off:
                    continue
                lab = r_[off]
                v = num(r_[3 + off])
                if off and r_[0] and re.fullmatch(r"[A-Z]{1,2}", r_[0]):
                    grp, gatl, gsum = r_[0], int(v) if v is not None else 0, 0
                    atl += gatl
                    continue
                if lab.upper().startswith("UNGROUPED"):
                    grp = None
                    continue
                if lab.upper().startswith("GROUP TOTAL"):
                    if v is not None and int(v) != gatl + gsum:
                        c["note"] += " group %s total %s != ATL %s + candidates %s;" % (grp, int(v), gatl, gsum)
                    continue
                if lab.upper().startswith(("TOTAL", "INFORMAL")) or not lab:
                    continue
                if v is None:
                    raise SystemExit("non-numeric votes in %s: %r" % (fp, r_))
                sn, gv = split_sg(lab)
                c["cands"].append(cand(lab, sn, gv, int(v), group=grp))
                if grp is not None:
                    gsum += int(v)
            c["atl"] = atl
        out.append(c)
    return out


# ---------------------------------------------------------------------- PDF
def pdf_rows(path, ytol=2.0):
    """Words of every page grouped into visual rows: list of (page, [(x0, x1, text), ...], row_no).
    Rows are clustered on the vertical CENTRE of each word (label and figures of one table row share
    a centre to within ~0.5pt, whereas their bottoms can differ by a few points)."""
    doc = fitz.open(path)
    res = []
    for pi, pg in enumerate(doc):
        ws = sorted(pg.get_text("words"), key=lambda w: (w[1] + w[3]) / 2)
        cur, cy, rows = [], None, []
        for w in ws:
            yc = (w[1] + w[3]) / 2
            if cy is None or yc - cy > ytol:
                if cur:
                    rows.append(cur)
                cur, cy = [], yc
            cur.append((w[0], w[2], w[4]))
        if cur:
            rows.append(cur)
        for i, r in enumerate(rows):
            res.append((pi, sorted(r), i))
    return res


# --------------------------------------------------------------------- 2012
def parse_2012():
    year = 2012
    base = os.path.join(RAW, str(year))
    idx = rd(os.path.join(base, "lge-index.html"))
    names = {}
    for slug, label in re.findall(r'href="/LGE2012/([^/"]+)/index\.htm"[^>]*>\s*([^<]+?)\s*<', idx):
        names[slug] = htmllib.unescape(label.strip())
    out = []
    for lj in sorted(glob.glob(os.path.join(base, "data", "*", "lga-json.txt"))):
        slug = os.path.basename(os.path.dirname(lj))
        js = rd(lj)
        cname = re.search(r'"name":\s*"([^"]+)"', js).group(1)
        wards = re.findall(r'"id":\s*"([^"]+)",\s*"realid":\s*"LG[^"]*",\s*"name":\s*"([^"]+)"', js)
        conts = re.findall(r'"id":\s*"(councillor|mayoral)"', js)
        targets = [("data/%s/%s" % (slug, w.replace(".", "/", 1)), "councillor", wn, w.replace(".", "/", 1))
                   for w, wn in wards]
        targets += [("data/%s" % slug, k, "", None) for k in conts]
        for d, k, wname, wdir in targets:
            fpf = os.path.join(base, d, "first_preference_%s.html" % k)
            if not os.path.isfile(fpf):
                continue
            c = new_contest(year, cname, wname, "mayor" if k == "mayoral" else "councillor", rel(fpf))
            res = rd(os.path.join(base, d, "result_%s.html" % k)) if os.path.isfile(
                os.path.join(base, d, "result_%s.html" % k)) else ""
            c["elected_names"] = [" ".join(re.sub(r"\([^)]*\)", "", x).split())
                                  for x in re.findall(r'class="candidate_name">([^<]+)<', res)]
            c["elected_keys"] = [key(n) for n in c["elected_names"]]
            fph = rd(fpf)
            t = text_of(fph)
            m = re.search(r"enrolled in this\s+(?:council area|Ward|ward)[^.]*?was\s+([\d,]+)", t, re.S)
            c["enrolment"] = num(m.group(1)) if m else None
            m = re.search(r"There (?:are|is)\s+(\d+)\s+Councillors?", t)
            if m:
                c["vacancies"] = int(m.group(1))
            if k == "mayoral":
                c["vacancies"] = 1
                tb = re.search(r"(?s)<thead>(.*?)</thead>", fph)
                heads = re.findall(r"(?s)<th class=\"m\">(.*?)</th>", tb.group(1)) if tb else []
                heads = [htmllib.unescape(re.sub(r"<br\s*/?>", "|", x)).split("|")[0].strip() for x in heads]
                rows = table_rows(fph)
                tot = None
                sums = [0] * len(heads)
                formal_col = None
                for r_ in rows:
                    if r_ and r_[0] == "Total" and len(r_) >= len(heads) + 2:   # grand-total row
                        tot = [num(x) for x in r_[1:1 + len(heads)]]
                        formal_col = num(r_[len(heads) + 1])
                if tot is None:       # last data row of the body is the summed row in some pages
                    rows_n = [r_ for r_ in rows if len(r_) == len(heads) + 4 and num(r_[1]) is not None]
                    tot = [sum(num(r_[1 + i]) or 0 for r_ in rows_n) for i in range(len(heads))]
                c["formal"] = None
                for hd, v in zip(heads, tot):
                    c["cands"].append(cand(hd, hd, "", int(v) if v is not None else None))
                c["formal"] = int(formal_col) if formal_col is not None else None
                # the winner's full name is known from the result page (only when the surname is unique)
                for en in c["elected_names"]:
                    hits = [cd for cd in c["cands"] if cd["surname"].upper() in en.upper().split()]
                    if len(hits) == 1:
                        tk = en.split()
                        hits[0]["given"] = " ".join(x for x in tk if not is_upper(x))
                        hits[0]["name"] = (hits[0]["surname"] + " " + hits[0]["given"]).strip()
                c["note"] = "mayor surnames only except winner"
            else:
                dirc = (wdir if wdir else "councillor")
                pdf = os.path.join(base, "pdf", slug, dirc, "03_first_prefs_by_group_and_candidate.pdf")
                if not os.path.isfile(pdf):
                    # No count report: uncontested (candidates elected without a poll).
                    c["contested"] = False
                    c["note"] = "uncontested (no count report)"
                    for n in c["elected_names"]:
                        toks = n.split()
                        j = next((i for i, tk in enumerate(toks) if is_upper(tk)), len(toks) - 1)
                        c["cands"].append(cand(n, " ".join(toks[j:]), " ".join(toks[:j]), None, True))
                    out.append(c)
                    continue
                c["source"] = rel(pdf)
                parse_2012_pdf(c, pdf)
            out.append(c)
    return out


def parse_2012_pdf(c, pdf):
    grp, gtot, gsum, atl = None, 0, 0, 0
    infoot = False
    pending_formal = False
    grouped = True
    for pi, words, _ in pdf_rows(pdf):
        line = " ".join(w[2] for w in words)
        if re.search(r"Page \d+ of \d+", line) or line.startswith("Date Generated"):
            continue
        m = re.search(r"Candidates to be Elected:\s*(\d+)", line)
        if m:
            c["vacancies"] = int(m.group(1))
        m = re.search(r"Enrolment:\s*([\d,]+)", line)
        if m:
            c["enrolment"] = num(m.group(1))
        m = re.search(r"Ward:\s*(.*?)(?:\s+Candidates to be|$)", line)
        if m and not c["ward"] and m.group(1).strip().lower() != "undivided":
            c["ward"] = m.group(1).strip()
        if pending_formal and not line.startswith(("INFORMAL", "TOTAL VOTES")):
            ns = [num(w[2]) for w in words if num(w[2]) is not None]
            if ns:
                c["formal"] = int(ns[0])
                pending_formal = False
                continue
        if line.startswith("FORMAL VOTES"):
            ns = [num(w[2]) for w in words if num(w[2]) is not None]
            if ns:
                c["formal"] = int(ns[0])
            else:
                pending_formal = True     # the figure sits on the next visual row
            continue
        if line.startswith(("INFORMAL", "TOTAL VOTES")):
            continue
        # numeric columns by right edge
        label = [w for w in words if w[0] < 280]
        nums = [(w[1], num(w[2])) for w in words if w[0] >= 280 and num(w[2]) is not None]
        votes = next((int(v) for x1, v in nums if 395 <= x1 <= 450), None)
        pos = next((int(v) for x1, v in nums if 330 <= x1 < 380), None)
        if not label and not nums:
            continue
        if line.startswith("Group Candidate"):
            grouped = True
            continue
        if line.startswith("Candidate Position"):
            grouped = False        # councils with no groups: names start at the left margin
            continue
        if line.startswith(("Event:", "Work Location", "Area:", "Date of Election", "Quota:")):
            continue
        glabel = [w for w in label if w[0] < 60] if grouped else []
        namew = [w for w in label if w[0] >= 60] if grouped else label
        nm = " ".join(w[2] for w in namew)
        if nm.upper().startswith("UNGROUPED"):
            if grp is not None:
                atl += gtot - gsum
            grp = None
            continue
        if glabel and re.fullmatch(r"[A-Z]{1,2}", glabel[0][2]) and (votes is not None):
            # group header row: ATL votes (no candidate name)
            if grp is not None:
                atl += gtot - gsum
            grp, gsum, gtot = glabel[0][2], 0, 0
            c.setdefault("_atl_by_group", {})[grp] = votes
            continue
        if nm.startswith("Group Total"):
            gtot = votes or 0
            continue
        if nm and votes is not None and not nm.upper().startswith(("FORMAL", "INFORMAL", "TOTAL")):
            sn, gv = split_sg(nm)
            cd = cand(nm, sn, gv, int(votes), elected_flag=(pos is not None), group=grp)
            c["cands"].append(cd)
            if grp is not None:
                gsum += int(votes)
        elif nm and votes is None and glabel and not [w for w in words if w[0] >= 280]:
            continue  # group name continuation
    if grp is not None:
        atl += gtot - gsum
    # ATL = sum of the group-header rows (explicit); fall back to group total minus candidates
    c["atl"] = sum(c.get("_atl_by_group", {}).values()) or atl
    c.pop("_atl_by_group", None)
    c["elected_from_pdf"] = [key(x["name"]) for x in c["cands"] if x["elected"]]
    if not c["elected_keys"]:
        c["elected_keys"] = c["elected_from_pdf"]


# --------------------------------------------------------------------- 2008
deferred_2008 = []


def parse_2008():
    year = 2008
    base = os.path.join(RAW, str(year))
    idx = rd(os.path.join(base, "lgeindex.html"))
    cnames = {}
    for fn, label in re.findall(r'href="result\.([^"]+)\.html"[^>]*>\s*([^<]+?)\s*<', idx):
        if label.strip():
            cnames[fn] = htmllib.unescape(label.strip())
    out = []
    pagefiles = sorted(glob.glob(os.path.join(base, "pages", "result.*")))
    for pf in pagefiles:
        fn = os.path.basename(pf)
        m = re.match(r"result\.([^.]+)\.(.*)$", fn)
        council = m.group(1)
        rest = m.group(2)
        h = rd(pf)
        t = text_of(h)
        title = re.search(r"\n\s*([A-Z0-9' \-\.&]+?)(?: - ([A-Z0-9' \-\./]+))?\s*\n\s*SUMMARY", t)
        is_mayor = rest.startswith("mayoral")
        if not title:
            continue
        ward_name = (title.group(2) or "").strip()
        cname = cnames.get(council, council.replace("_", " "))
        c = new_contest(year, cname, re.sub(r"\b[A-Za-z][A-Za-z']*\b", lambda m_: m_.group(0).capitalize(), ward_name) if ward_name else "",
                        "mayor" if is_mayor else "councillor", rel(pf))
        m = re.search(r"enrolled on [^:]*:\s*([\d,]+)", t)
        c["enrolment"] = num(m.group(1)) if m else None
        m = re.search(r"(\d+)\s+candidates\s+contesting\s+(\d+)\s+vacanc", t)
        if m:
            c["vacancies"] = int(m.group(2))
        if "Election is Deferred" in t:
            deferred_2008.append((cname, c["ward"], c["contest"]))
            continue
        c["elected_names"] = [" ".join(x.split()) for x in
                              re.findall(r"\n\s*([A-Z][A-Z' \-\.]+?) (?:was )?declared elected", t)]
        c["elected_keys"] = [key(n) for n in c["elected_names"]]
        if is_mayor and "Uncontested" in t[:600]:
            c["vacancies"], c["contested"], c["note"] = 1, False, "uncontested"
            for r_ in table_rows(h):
                if len(r_) >= 2 and re.fullmatch(r"[A-Za-z' \-\.]+, [A-Za-z][A-Za-z' \-\.\(\)]*", r_[0]):
                    sn, gv = split_comma(r_[0])
                    c["cands"].append(cand("%s %s" % (sn, gv), sn, gv, None, True))
            out.append(c)
            continue
        if is_mayor:
            c["vacancies"] = 1
            for r_ in table_rows(h):
                if len(r_) >= 4 and r_[0].upper().startswith("TOTAL FORMAL"):
                    ns = [num(x) for x in r_[1:] if num(x) is not None]
                    c["formal"] = int(ns[-1]) if ns else None
                elif len(r_) >= 5 and re.match(r"[A-Za-z]", r_[0]) and r_[0] not in ("Candidate",) \
                        and not r_[0].lower().startswith(("informal", "total")):
                    ns = [num(x) for x in r_[2:] if num(x) is not None]
                    if len(ns) >= 2:
                        c["cands"].append(cand(r_[0], r_[0], "", int(ns[-1])))
            for en in c["elected_names"]:
                for cd in c["cands"]:
                    if cd["surname"].upper() in en.upper().split():
                        toks = en.split()
                        cd["given"] = " ".join(x for x in toks if x.upper() != cd["surname"].upper()).title()
                        cd["name"] = (cd["surname"] + " " + cd["given"]).strip()
            c["note"] = "mayor surnames only except winner"
            out.append(c)
            continue
        # PR contest. (a) "Check Count & Dec" columns on the page (no-group ballots): last FP column is
        # the final count, surnames only. (b) grouped ballots: final count only in the PDF "02"
        # report; given names from the HTML table, joined by ballot order.
        unc = "Uncontested" in t[:600] or "Uncontested" in t.split("Summary")[0]
        has_final_cols = any("Check Count & Dec" in r_ and "Election Night" in r_ for r_ in table_rows(h))
        pdfdir = ("Council" if not ward_name else re.sub(r"[ /]", "_", ward_name.title()))
        pdfs = glob.glob(os.path.join(base, "pdf", council, pdfdir, "02_*"))
        cand_html = []
        for r_ in table_rows(h):
            if len(r_) >= 2 and re.fullmatch(r"[A-Za-z' \-\.]+, [A-Za-z][A-Za-z' \-\.\(\)]*", r_[0]) \
                    and not r_[0].lower().startswith(("group", "ungrouped")):
                cand_html.append(r_[0])
        if has_final_cols:
            atl = 0
            for r_ in table_rows(h):
                if len(r_) >= 5 and r_[1:2] == ["Group Votes"]:     # ATL group-votes row
                    ns = [num(x) for x in r_[2:] if num(x) is not None]
                    if len(ns) >= 2:
                        atl += int(ns[-1])
                    continue
                if len(r_) >= 5 and r_[0].upper().startswith("TOTAL FORMAL"):
                    ns = [num(x) for x in r_[1:] if num(x) is not None]
                    c["formal"] = int(ns[-1]) if ns else None
                elif len(r_) >= 5 and re.match(r"[A-Za-z]", r_[0]) and r_[0] not in ("Candidate",) \
                        and not r_[0].lower().startswith(("informal", "total", "ungrouped")) \
                        and "Group Votes" not in r_[1:2] + r_[0:1]:
                    ns = [num(x) for x in r_[2:] if num(x) is not None]
                    if len(ns) >= 2:
                        c["cands"].append(cand(r_[0], r_[0], "", int(ns[-1])))
            for en in c["elected_names"]:
                hits = [cd for cd in c["cands"] if cd["surname"].upper() in en.upper().split() and not cd["given"]]
                if len(hits) == 1:       # two candidates sharing a surname: cannot tell which is meant
                    cd = hits[0]
                    cd["given"] = " ".join(x for x in en.split() if x.upper() != cd["surname"].upper()).title()
                    cd["name"] = (cd["surname"] + " " + cd["given"]).strip()
            c["atl"] = atl
            c["note"] = "surnames only (given name known for winners)"
            c["elected_keys"] = [key(n) for n in c["elected_names"]]
        elif pdfs:
            c["source"] = rel(pdfs[0])
            parse_2008_pdf(c, pdfs[0], cand_html)
        elif unc:
            c["contested"] = False
            c["note"] = "uncontested"
            for hn in cand_html or []:
                sn, gv = split_comma(hn)
                c["cands"].append(cand("%s %s" % (sn, gv), sn, gv, None, True))
            if not cand_html:   # surname-only list
                for r_ in table_rows(h):
                    if len(r_) >= 2 and re.match(r"[A-Z]{2}", r_[0]) and r_[0] not in ("Candidate",) and len(r_) < 4:
                        c["cands"].append(cand(r_[0], r_[0], "", None, True))
        else:
            c["note"] = "final count not in parsed sources (only a DOP PDF or election-night table)"
            for hn in cand_html:
                sn, gv = split_comma(hn)
                c["cands"].append(cand("%s %s" % (sn, gv), sn, gv, None))
            c["incomplete"] = True
        out.append(c)
    return out


def parse_2008_pdf(c, pdf, cand_html):
    rows = []
    for pi, words, _ in pdf_rows(pdf):
        rows.append(words)
    cands, grp_atl = [], 0
    sub = None
    grp = None
    for words in rows:
        line = " ".join(w[2] for w in words)
        if line.startswith("Sub Total"):
            ns = [num(w[2]) for w in words if num(w[2]) is not None]
            sub = ns
            continue
        namew = [w for w in words if 60 <= w[0] < 280]
        glabel = [w for w in words if w[0] < 60]
        nm = " ".join(w[2] for w in namew)
        if not nm or not nm.endswith("."):
            continue
        nums = [(w[1], num(w[2])) for w in words if w[0] >= 280 and num(w[2]) is not None]
        fp = next((int(v) for x1, v in nums if 300 <= x1 <= 345), None)
        gv = next((int(v) for x1, v in nums if 365 <= x1 <= 400), None)
        if glabel and re.fullmatch(r"[A-Z]{1,2}", glabel[0][2]):
            grp = glabel[0][2]
        if fp is None:
            fp = 0 if nums == [] else None
        cands.append(dict(pdfname=nm, fp=fp, gv=gv or 0, group=grp))
    if sub:
        c["formal"] = int(sub[-1])
    c["atl"] = sum(x["gv"] for x in cands)
    # join to HTML names by ballot order
    if len(cand_html) != len(cands):
        c["note"] = "PDF/HTML candidate counts differ (%d vs %d); names from PDF" % (len(cands), len(cand_html))
        cand_html = [None] * len(cands) if len(cand_html) != len(cands) else cand_html
    for i, pc in enumerate(cands):
        hn = cand_html[i] if cand_html and cand_html[i] else None
        if hn:
            sn, gv = split_comma(hn)
            ps, pi_ = pc["pdfname"].rsplit(" ", 1)
            if key(sn)[:3] != key(ps)[:3] and sn.upper().replace("-", " ").split()[0] != ps.upper().replace("-", " ").split()[0]:
                c["note"] += " name mismatch %s/%s" % (hn, pc["pdfname"])
            name = "%s %s" % (sn, gv)
        else:
            sn, gv = split_sg(pc["pdfname"].replace(".", ""))
            name = pc["pdfname"]
        c["cands"].append(cand(name, sn, gv, pc["fp"], group=pc["group"]))
    c["elected_keys"] = [key(n) for n in c["elected_names"]]


# ------------------------------------------------------------------- output
def contest_rows(c):
    """Rows for one contest. Elected is matched by order-free name key."""
    ekeys = Counter(c["elected_keys"])
    rows = []
    ckeys = []
    dupn = Counter(cd["name"] for cd in c["cands"])
    for i, cd in enumerate(c["cands"], 1):
        if dupn[cd["name"]] > 1 and "[#" not in cd["name"]:
            cd["name"] = "%s [#%d on ballot]" % (cd["name"], i)
    for cd in c["cands"]:
        ckeys.append(key("%s %s" % (cd["given"], cd["surname"])))
        cd["_elected"] = False
    # pass 1: exact order-free name match
    for cd, k in zip(c["cands"], ckeys):
        if ekeys.get(k, 0) > 0:
            ekeys[k] -= 1
            cd["_elected"] = True
    # pass 2: elected name's words all appear in a still-unmatched candidate's name
    # (middle names, "Greg" vs "Gregory" are NOT matched; only extra words on the candidate side)
    for k in [k for k, n in ekeys.items() if n > 0]:
        hits = [cd for cd, ck in zip(c["cands"], ckeys)
                if not cd["_elected"] and set(k.split()) <= set(ck.split())]
        if len(hits) == 1:
            hits[0]["_elected"] = True
            ekeys[k] -= 1
    # pass 3: surname-only candidate rows (2008/2012 mayor, 2008 no-group ballots) vs the fuller
    # elected name ("COX JOHN MICHAEL ST"): the candidate's words are all in the elected name
    for k in [k for k, n in ekeys.items() if n > 0]:
        hits = [cd for cd, ck in zip(c["cands"], ckeys)
                if not cd["_elected"] and not cd["given"] and set(ck.split()) <= set(k.split())]
        if len(hits) == 1:
            hits[0]["_elected"] = True
            ekeys[k] -= 1
        elif len(hits) > 1:
            # Two candidates share the surname and the source gives surnames only: take the one with
            # more first preferences. A guess, so it is recorded in the contest note and reported.
            best = max(hits, key=lambda cd: cd["votes"] or 0)
            best["_elected"] = True
            ekeys[k] -= 1
            c["note"] += " | same-surname winner chosen by first-preference votes (unverified)"
            c["heuristic_winner"] = True
    if not c["elected_keys"]:                      # uncontested rows carry the elected flag directly
        for cd in c["cands"]:
            if cd["elected"] is True:
                cd["_elected"] = True
    for cd in c["cands"]:
        el = cd["_elected"]
        pct = None
        if cd["votes"] is not None and c["formal"]:
            pct = round(100.0 * cd["votes"] / c["formal"], 2)
        rows.append([c["year"], c["council"], c["ward"], c["contest"], c["vacancies"], cd["name"],
                     cd["surname"], cd["given"], "" if cd["votes"] is None else cd["votes"],
                     "" if pct is None else pct, "" if c["formal"] is None else c["formal"],
                     "" if c["enrolment"] is None else c["enrolment"], "TRUE" if el else "FALSE",
                     "TRUE" if c["contested"] else "FALSE", c["source"]])
    c["_unmatched"] = [k for k, n in ekeys.items() if n > 0]
    return rows


# --------------------------------------------------------------- validation
def vote_check(c, tol=TOL):
    """Return (ok, message). Candidate votes + ATL vs formal votes."""
    if not c["contested"] or c["formal"] is None:
        return None, "no formal total"
    s = sum(x["votes"] or 0 for x in c["cands"]) + (c["atl"] or 0)
    diff = abs(s - c["formal"]) / max(c["formal"], 1)
    return diff <= tol, "sum %d vs formal %d (%.3f%%)" % (s, c["formal"], diff * 100)


def norm_council(n):
    n = n.lower()
    n = re.sub(r"\b(city|of|the|council|shire|municipal|municipality|regional|rural|district|\(.*?\))\b", " ", n)
    return re.sub(r"[^a-z]", "", n)


def no_data_councils(year, have):
    """(explained, unexplained): councils listed on the year's site but without parsed contests."""
    base = os.path.join(RAW, str(year))
    explained, unexplained = [], []

    def classify(text):
        if re.search(r"own election|Council Run|Council_Run", text, re.I):
            return "council ran its own election"
        if re.search(r"in Administration|placed in administration", text, re.I):
            return "council in administration, no election"
        if re.search(r"Deferred", text):
            return "election deferred"
        return None

    items = []   # (display name, text of the council's own page)
    if year in (2021, 2024):
        for slug, nm in council_names_lg(year).items():
            pg = os.path.join(base, slug, "results.html")
            items.append((nm, text_of(rd(pg)) if os.path.isfile(pg) else ""))
    elif year in (2016, 2017):
        for slug, nm in council_names_static(year).items():
            pg = os.path.join(base, slug, "index.html")
            if os.path.isfile(pg):
                items.append((nm, text_of(rd(pg))))
    elif year == 2012:
        for lj in glob.glob(os.path.join(base, "data", "*", "lga-json.txt")):
            js = rd(lj)
            nm = re.search(r'"name":\s*"([^"]+)"', js).group(1)
            ty = re.search(r'"type":\s*"([^"]+)"', js).group(1)
            items.append((nm, ty))
    elif year == 2008:
        idx = rd(os.path.join(base, "lgeindex.html"))
        for fn, label in re.findall(r'href="result\.([^"]+)\.html"[^>]*>\s*([^<]+?)\s*<', idx):
            if label.strip():
                items.append((htmllib.unescape(label.strip()), ""))
    for nm, text in items:
        if nm in have:
            continue
        why = classify(text)
        if year == 2008:
            why = "election deferred (every contest)" if any(d[0] == nm for d in deferred_2008) else None
        if why:
            explained.append((nm, why))
        else:
            unexplained.append(nm)
    return explained, unexplained


def main():
    all_c = []
    for y in YEARS:
        d = os.path.join(RAW, str(y))
        if not os.path.isdir(d):
            print("MISSING raw data for %d (run fetch_nswec_council.py)" % y)
            return 2
        if y in (2021, 2024):
            all_c += parse_lg(y)
        elif y in (2016, 2017):
            all_c += parse_static(y)
        elif y == 2012:
            all_c += parse_2012()
        elif y == 2008:
            all_c += parse_2008()
    rows = []
    for c in all_c:
        rows += contest_rows(c)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(COLS)
        w.writerows(rows)
    print("wrote %s (%d rows)" % (OUT, len(rows)))

    fails = []
    print("\nPer-year counts (councils with data / contests / candidate rows / elected rows):")
    for y in YEARS:
        cs = [c for c in all_c if c["year"] == y]
        rs = [r for c, r in ((c, contest_rows(c)) for c in cs) for r in r]
        print("  %d: councils %d, contests %d (councillor %d, mayor %d, uncontested %d), rows %d, elected %d" % (
            y, len({c["council"] for c in cs}), len(cs),
            sum(c["contest"] == "councillor" for c in cs), sum(c["contest"] == "mayor" for c in cs),
            sum(not c["contested"] for c in cs), len(rs), sum(r[12] == "TRUE" for r in rs)))

    # 1. vote sums
    print("\nVote check: candidate votes + ATL vs formal votes (tolerance %.1f%%)" % (TOL * 100))
    for y in YEARS:
        cs = [c for c in all_c if c["year"] == y and c["contested"]]
        res = [(c, vote_check(c)) for c in cs]
        checked = [(c, r) for c, r in res if r[0] is not None]
        bad = [(c, r) for c, r in checked if r[0] is False]
        print("  %d: checked %d of %d contested contests, %d outside tolerance" % (y, len(checked), len(cs), len(bad)))
        for c, r in bad[:8]:
            print("     %s | %s | %s | %s" % (c["council"], c["ward"], c["contest"], r[1]))
        fails += [(y, c["council"], c["ward"], "votes", r[1]) for c, r in bad]

    # 2. elected vs vacancies
    print("\nElected count vs vacancies:")
    for y in YEARS:
        cs = [c for c in all_c if c["year"] == y]
        bad, unfilled = [], []
        for c in cs:
            contest_rows(c)
            ne = sum(1 for x in c["cands"] if x.get("_elected"))
            if c["vacancies"] is not None and ne == c["vacancies"]:
                continue
            if not c["contested"] and c["vacancies"] is not None and ne == len(c["cands"]) < c["vacancies"]:
                unfilled.append(c)       # fewer nominees than vacancies: all elected, seats left vacant
                continue
            bad.append((c, ne))
        print("  %d: %d of %d contests mismatch (plus %d uncontested with fewer nominees than vacancies, "
              "all nominees elected)" % (y, len(bad), len(cs), len(unfilled)))
        for c, ne in bad[:8]:
            print("     %s | %s | %s | elected rows %d vs vacancies %s | unmatched elected %s | %s" % (
                c["council"], c["ward"], c["contest"], ne, c["vacancies"], c["_unmatched"][:3], c["note"]))
        fails += [(y, c["council"], c["ward"], "elected", "%d vs %s" % (ne, c["vacancies"])) for c, ne in bad]

    # 3. negatives, duplicates, empty
    print("\nNegatives / duplicates:")
    neg = [r for r in rows if r[8] != "" and r[8] < 0]
    dup = [k for k, n in Counter((r[0], r[1], r[2], r[3], r[5]) for r in rows).items() if n > 1]
    print("  negative vote rows: %d; duplicate (year,council,ward,contest,candidate) keys: %d" % (len(neg), len(dup)))
    for k in dup[:10]:
        print("     dup", k)
    if neg or dup:
        fails.append(("all", "", "", "negdup", "%d neg, %d dup" % (len(neg), len(dup))))
    empty = [c for c in all_c if not c["cands"]]
    print("  contests with no candidate rows: %d" % len(empty))
    for c in empty[:8]:
        print("     %s %s %s %s %s" % (c["year"], c["council"], c["ward"], c["contest"], c["note"]))
    if empty:
        fails.append(("all", "", "", "empty", "%d contests without candidates" % len(empty)))

    # 4. the vote check must fail on a perturbed value (in memory only)
    print("\nSelf-test: vote check on a perturbed copy")
    probe = next(c for c in all_c if c["contested"] and c["formal"] and vote_check(c)[0] is True and c["cands"]
                 and c["cands"][0]["votes"])
    import copy
    pc = copy.deepcopy(probe)
    ok_before = vote_check(pc)[0]
    pc["cands"][0]["votes"] += int(0.02 * pc["formal"]) + 1     # inflate by >2% of formal
    ok_after = vote_check(pc)[0]
    print("  %s %s: before perturbation ok=%s, after +2%% of formal ok=%s" % (
        probe["year"], probe["council"], ok_before, ok_after))
    if not (ok_before is True and ok_after is False):
        fails.append(("selftest", "", "", "selftest", "vote check did not flag a perturbed value"))

    print("\nDeferred 2008 contests (no election held at the time; no data): %d" % len(deferred_2008))
    print("  " + "; ".join("%s %s %s" % d for d in deferred_2008[:40]))
    unmatched_names = [c for c in all_c if c["contested"] and c["cands"] and not any(x.get("given") for x in c["cands"])]
    print("Contests where no candidate has a given name (surnames-only sources): %d (by year %s)" % (
        len(unmatched_names), dict(Counter(c["year"] for c in unmatched_names))))

    # 5. councils on a year's NSWEC site that have no candidate data, and why
    print("\nCouncils with NO data on the NSWEC site, by year (reason as stated on the site):")
    unexplained = []
    for y in YEARS:
        have = {c["council"] for c in all_c if c["year"] == y}
        nd, unx = no_data_councils(y, have)
        unexplained += [(y, n) for n in unx]
        by = defaultdict(list)
        for n, why in nd:
            by[why].append(n)
        print("  %d: %d councils on the site's list, %d with data, %d without%s" % (
            y, len(have) + len(nd) + len(unx), len(have), len(nd) + len(unx),
            "" if not (nd or unx) else ":"))
        for why, ns in sorted(by.items()):
            print("     %s (%d): %s" % (why, len(ns), "; ".join(sorted(ns))))
        if unx:
            print("     UNEXPLAINED (%d): %s" % (len(unx), "; ".join(sorted(unx))))
    if unexplained:
        fails.append(("all", "", "", "unexplained", "%d councils without data and without a stated reason" % len(unexplained)))
    hw = [c for c in all_c if c.get("heuristic_winner")]
    print("\nContests where the winner among same-surname candidates was picked by votes (unverified): %d" % len(hw))
    for c in hw:
        print("     %s %s %s %s" % (c["year"], c["council"], c["ward"], c["contest"]))

    print("\nRESULT: %s" % ("PASS" if not fails else "FAIL (%d issues)" % len(fails)))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
