#!/usr/bin/env python3
"""Fetch NSW local-government election results (2008-2024) from the NSWEC
past-results site into external/reference/nsw/council/<year>/.

Raw responses are stored unedited. Re-runs are idempotent: a stored file that
passes its completeness check (HTML ends </html>, CSV has a header and rows,
PDF has %PDF ... %%EOF) is not fetched again.

Only councils whose election the NSWEC ran appear on the site; councils that
ran their own election have no data here (the parser lists them).

Usage: python scripts/fetch_nswec_council.py [year ...]   (default: all years)
Exit status is non-zero if any required file could not be fetched.
Standard library only.
"""
import os
import re
import sys
import time
import html as htmllib
import urllib.error
import urllib.parse
import urllib.request

HOST = "https://pastvtr.elections.nsw.gov.au"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "external", "reference", "nsw", "council")
ROOT = os.path.normpath(ROOT)
DELAY = 0.2
UA = "auspol-research-fetcher (peteowen1; polite, 0.2s delay)"
YEARS = [2008, 2012, 2016, 2017, 2021, 2024]

stats = {}      # year -> dict(counter)
failures = []   # (year, url, reason)


def bump(year, key, n=1):
    stats.setdefault(year, {}).setdefault(key, 0)
    stats[year][key] += n


# ---------------------------------------------------------------- validity
def valid_html(b):
    return b"</html>" in b[-400:].lower() or b"</html>" in b.lower()


def valid_csv(b):
    t = b.decode("utf-8", "replace").lstrip("﻿")
    lines = [ln for ln in t.splitlines() if ln.strip()]
    return len(lines) >= 2 and "<html" not in t[:300].lower() and "," in lines[0]


def valid_pdf(b):
    return b[:5] == b"%PDF-" and b"%%EOF" in b[-2048:]


def valid_text(b):
    return len(b) > 2 and b"<html" not in b[:300].lower()


def valid_frag(b):
    t = b.strip()
    return len(t) > 20 and t.endswith(b">") and b"<html" not in t[:300].lower()


VALID = {"frag": valid_frag, "html": valid_html, "csv": valid_csv, "pdf": valid_pdf, "txt": valid_text}


# ---------------------------------------------------------------- transport
def http_get(url, tries=6):
    """Return (status, bytes). 404 is returned, not retried. Other errors retry."""
    last = None
    for i in range(tries):
        time.sleep(DELAY)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.status, r.read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return 404, b""
            last = "HTTP %s" % e.code
        except Exception as e:  # timeouts, resets
            last = repr(e)
        time.sleep(1.5 * (i + 1))
    return 0, last.encode() if last else b"unknown"


def fetch(year, url, rel, kind, required=True):
    """Fetch url -> ROOT/year/rel. Returns 'ok' | 'cached' | 'missing' | 'fail'."""
    dest = os.path.join(ROOT, str(year), rel)
    check = VALID[kind]
    if os.path.isfile(dest):
        with open(dest, "rb") as f:
            if check(f.read()):
                bump(year, "cached")
                return "cached"
    for attempt in range(4):  # an invalid body (e.g. Cloudflare 522 page) retries
        status, body = http_get(url)
        if status == 404:
            bump(year, "missing")
            if required:
                failures.append((year, url, "404"))
            return "missing"
        if status == 200 and check(body):
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as f:
                f.write(body)
            bump(year, "fetched")
            return "ok"
        time.sleep(2 * (attempt + 1))
    bump(year, "failed")
    failures.append((year, url, "invalid/failed response"))
    return "fail"


def read(year, rel):
    p = os.path.join(ROOT, str(year), rel)
    if not os.path.isfile(p):
        return ""
    with open(p, "rb") as f:
        return f.read().decode("utf-8", "replace")


def links(text):
    return [htmllib.unescape(x) for x in re.findall(r'href="([^"]*)"', text)]


# ------------------------------------------------------------ 2021 and 2024
def fetch_lg(year):
    code = "LG%02d01" % (year % 100)
    base = "%s/%s" % (HOST, code)
    fetch(year, base + "/index", "index.html", "html")
    councils = sorted(set(re.findall(r'href="/%s/([^/"]+)/results"' % code,
                                     read(year, "index.html"))))
    print("  %d: %d councils in index" % (year, len(councils)))
    for c in councils:
        if fetch(year, "%s/%s/results" % (base, c), "%s/results.html" % c, "html") == "fail":
            continue
        contests = sorted(set(
            l for l in links(read(year, "%s/results.html" % c))
            if l.startswith("/%s/%s/" % (code, c)) and not l.endswith("/results")
            and re.search(r"/(councillor|mayoral)$", l)))
        for cu in contests:
            rel = cu[len("/%s/" % code):]            # council[/ward]/councillor
            fetch(year, HOST + cu, rel + ".html", "html")
            if rel.endswith("/mayoral"):
                fetch(year, HOST + cu + "/mayoral-fp-by-candidate",
                      rel + "/mayoral-fp-by-candidate.html", "html",
                      required="UNCONTESTED" not in read(year, rel + ".html").upper())
            else:
                parent = rel.rsplit("/", 1)[0]
                uncontested = "UNCONTESTED" in read(year, rel + ".html").upper()
                for sub in ("general-statistics", "grp-and-candidates-result"):
                    fetch(year, "%s%s/%s" % (HOST, cu, sub), "%s/%s.html" % (rel, sub), "html",
                          required=not uncontested)
                # CSV link is relative to the page URL, so it sits beside the contest dir
                # (a contest with no first-preference CSV is uncontested; handled in parser)
                fetch(year, "%s/%s/download/firstpreferencebyvenuevt.csv" % (base, parent),
                      "%s/download/firstpreferencebyvenuevt.csv" % parent, "csv", required=False)


# ------------------------------------------------------------ 2016 and 2017
def fetch_lge_static(year, index_rel):
    base = "%s/LGE%d" % (HOST, year)
    fetch(year, base + index_rel, "lge-index.html", "html")
    idx = read(year, "lge-index.html")
    pat = r'href="/LGE%d/([^/"]+)/index\.htm"' % year
    councils = sorted(set(re.findall(pat, idx)))
    print("  %d: %d councils in index" % (year, len(councils)))
    for c in councils:
        queue = ["%s/index.htm" % c]
        seen, contests = set(), []
        while queue:
            rel = queue.pop()
            if rel in seen:
                continue
            seen.add(rel)
            if fetch(year, "%s/%s" % (base, rel), rel.replace(".htm", ".html"), "html") == "fail":
                continue
            for l in links(read(year, rel.replace(".htm", ".html"))):
                l = urllib.parse.urlparse(urllib.parse.urljoin("%s/%s" % (base, rel), l)).path  # relative links
                m = re.match(r"^/LGE%d/(%s/.*)$" % (year, re.escape(c)), l)
                if not m:
                    continue
                r2 = m.group(1)
                if r2.endswith("/summary.htm") and r2 not in contests:
                    contests.append(r2)
                elif r2.endswith("/index.htm") and r2 not in seen:
                    queue.append(r2)
        for sm in contests:
            d = sm.rsplit("/", 1)[0]
            if re.search(r"/(referendum|poll)(/|$)", d):
                continue            # not candidate elections
            fetch(year, "%s/%s" % (base, sm), sm.replace(".htm", ".html"), "html")
            if d.endswith("/mayoral"):
                continue            # mayoral summary page carries the first-preference table
            for sub in ("general_statistics", "fp_by_grp_and_candidate_by_vote_type",
                        "grp_and_candidates_result"):
                fetch(year, "%s/%s/%s.htm" % (base, d, sub), "%s/%s.html" % (d, sub), "html",
                      required=("uncontested" not in read(year, sm.replace(".htm", ".html")).lower()))


# --------------------------------------------------------------------- 2012
def fetch_2012():
    year = 2012
    base = HOST + "/LGE2012"
    fetch(year, base + "/lge-index.htm", "lge-index.html", "html")
    idx = read(year, "lge-index.html")
    slugs = sorted(set(re.findall(r'href="/LGE2012/([^/"]+)/index\.htm"', idx)))
    print("  2012: %d councils in index" % len(slugs))
    for c in slugs:
        if fetch(year, "%s/data/%s/lga-json.txt" % (base, c), "data/%s/lga-json.txt" % c, "txt") == "fail":
            continue
        js = read(year, "data/%s/lga-json.txt" % c)
        wards = re.findall(r'"id":\s*"([^"]+)",\s*"realid":\s*"LG[^"]*",\s*"name"', js)
        cont = re.findall(r'"id":\s*"(councillor|mayoral)"', js)
        targets = []   # (dir, item suffix)
        for w in wards:
            targets.append(("data/%s/%s" % (c, w.replace(".", "/", 1)), "councillor"))   # site JS: id.replace(".", "/")
        for k in cont:
            targets.append(("data/%s" % c, k))
        for d, k in targets:
            for item in ("first_preference", "result", "description"):
                fetch(year, "%s/%s/%s_%s.html" % (base, d, item, k),
                      "%s/%s_%s.html" % (d, item, k), "frag")
            if k != "councillor":
                continue
            # The HTML first-preference table has surnames only; the PDF report
            # "03 - First Preferences by Group and Candidate" has full names.
            cdir = d[len("data/"):] + ("/councillor" if d.count("/") == 1 else "")   # undivided councils use /councillor/
            # site page dirs use "-" where the data dirs use "/" (e.g. Leichhardt ward ids "gadigal.annandale-leichhardt")
            cc, _, wd = cdir.partition("/")
            urldir = cc + "/" + wd.replace("/", "-") if wd else cc
            fr = "pages/%s/final-results.html" % cdir
            m = re.search(r"to be elected from\s+(\d+)\s+candidates",
                          read(year, "%s/first_preference_%s.html" % (d, k)))
            m2 = re.search(r"There are\s+(\d+)\s+Councillors", read(year, "%s/first_preference_%s.html" % (d, k)))
            uncontested = bool(m and m2 and int(m.group(1)) <= int(m2.group(1)))   # no poll: no count reports
            if fetch(year, "%s/%s/final-results/index.htm" % (base, urldir), fr, "html",
                     required=not uncontested) != "ok" and not os.path.isfile(os.path.join(ROOT, str(year), fr)):
                continue
            for l in links(read(year, fr)):
                if l.endswith(".pdf") and "First Preferences by Group and Candidate" in urllib.parse.unquote(l):
                    fetch(year, HOST + urllib.parse.quote(l, safe="/%"),
                          "pdf/%s/03_first_prefs_by_group_and_candidate.pdf" % cdir, "pdf",
                          required=not uncontested)


# --------------------------------------------------------------------- 2008
def fetch_2008():
    year = 2008
    base = HOST + "/LGE2008"
    fetch(year, base + "/lgeindex.htm", "lgeindex.html", "html")
    names = sorted(set(re.findall(r'href="result\.([^"]+)\.html"', read(year, "lgeindex.html"))))
    print("  2008: %d councils in index" % len(names))
    for n in names:
        page = "result.%s.html" % n
        if fetch(year, "%s/%s" % (base, page), "pages/%s" % page, "html") == "fail":
            continue
        txt = read(year, "pages/%s" % page)
        for l in links(txt):
            if re.match(r"^result\.[^/]+\.(council|mayoral)[0-9a-f]{0,4}\.html", l) or \
               re.match(r"^result\.[^/]+\.mayoral\.html", l):
                if "summary" in l or "electionnight" in l or "finalpublished" in l or "postelection" in l:
                    continue
                fn, _, q = l.partition("?")
                tag = re.sub(r"[^A-Za-z0-9_]", "_", q) if q else ""
                fetch(year, "%s/%s" % (base, l), "pages/%s%s" % (fn, ("__" + tag) if tag else ""), "html")
        # final first-preference PDFs per contest directory
        st, body = http_get("%s/LgeFinalCountReports/%s/" % (base, n))
        time.sleep(DELAY)
        if st != 200:
            # Uncontested and deferred elections have no count reports (and no listing).
            if st == 404 and re.search(r"Uncontested|Deferred", txt):
                bump(year, "no_reports_uncontested_or_deferred")
            else:
                failures.append((year, n, "directory listing HTTP %s" % st))
            continue
        listing = body.decode("utf-8", "replace")
        dirs = re.findall(r'HREF="/wwwroot/LGE2008/LgeFinalCountReports/%s/([^/"]+)/"' % re.escape(n),
                          listing, flags=re.I)
        for d in dirs:
            st, body = http_get("%s/LgeFinalCountReports/%s/%s/" % (base, n, d))
            if st != 200:
                failures.append((year, "%s/%s" % (n, d), "directory listing HTTP %s" % st))
                continue
            files = re.findall(r'HREF="(/wwwroot/LGE2008/LgeFinalCountReports/[^"]+\.pdf)"',
                               body.decode("utf-8", "replace"), flags=re.I)
            for f in files:
                fn = urllib.parse.unquote(f.rsplit("/", 1)[1])
                if re.match(r"0[24]_", fn) or "MAYOR" in fn.upper():
                    # 02 = first-preference summary, 04 = candidate sequence (who was elected)
                    fetch(year, base + f[len("/wwwroot/LGE2008"):],
                          "pdf/%s/%s/%s" % (n, d, fn), "pdf")


# ---------------------------------------------------------------------- main
def main(argv):
    years = [int(a) for a in argv[1:]] or YEARS
    os.makedirs(ROOT, exist_ok=True)
    for y in years:
        print("== %d" % y)
        if y in (2021, 2024):
            fetch_lg(y)
        elif y == 2016:
            fetch_lge_static(2016, "/lge-index.htm")
        elif y == 2017:
            fetch_lge_static(2017, "/results/index.htm")
        elif y == 2012:
            fetch_2012()
        elif y == 2008:
            fetch_2008()
        else:
            print("unknown year", y)
            failures.append((y, "", "unknown year"))
    print("\n2008 councils with no count reports (uncontested or deferred): %d" %
          stats.get(2008, {}).get("no_reports_uncontested_or_deferred", 0))
    print("\nPer-year file counts (fetched now / already cached / 404 / failed):")
    for y in years:
        s = stats.get(y, {})
        n_files = sum(len(fs) for _, _, fs in os.walk(os.path.join(ROOT, str(y))))
        print("  %d: fetched %d, cached %d, 404 %d, failed %d; files on disk %d" % (
            y, s.get("fetched", 0), s.get("cached", 0), s.get("missing", 0),
            s.get("failed", 0), n_files))
    if failures:
        print("\n%d FAILURES:" % len(failures))
        for y, u, why in failures[:50]:
            print("  %s %s %s" % (y, u, why))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
