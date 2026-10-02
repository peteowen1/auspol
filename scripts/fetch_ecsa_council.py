#!/usr/bin/env python
"""Fetch South Australian local-government periodic election results (ECSA).

2022: JSON API (LGEEvents, LGEStatic, LGEChange) for the 2022 Periodic Elections.
2018: per-contest scrutiny-sheet PDFs; links come from the ECSA 2018 results
      article (view=article&id=110), saved raw alongside the PDFs.

Raw responses are stored unedited under external/reference/ecsa/council/<year>/.
Idempotent: a file is re-fetched only if absent or invalid (JSON must parse;
PDF must start with %PDF and contain %%EOF near the end). 0.3 s between requests.
Exit status is non-zero if anything failed.
"""
import json, os, re, sys, time
import requests

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "external", "reference", "ecsa", "council")
API = "https://apim-ecsa-production.azure-api.net/results-display/"
ARTICLE = ("https://ecsa.sa.gov.au/elections/past-state-election-results"
           "?view=article&id=110:2018-council-elections-results&catid=12")
PDF_URL = "https://ecsa.sa.gov.au/component/edocman/{slug}/download"
PERIODIC_2022 = "2022 Periodic Elections"
DELAY = 0.3
S = requests.Session()
S.headers["User-Agent"] = "auspol-research/1.0"
failures = []


def get(url, tries=3):
    for i in range(tries):
        time.sleep(DELAY)
        try:
            r = S.get(url, timeout=120)
            if r.status_code == 200:
                return r.content
            err = "HTTP %d" % r.status_code
        except requests.RequestException as e:
            err = str(e)
        time.sleep(2 * (i + 1))
    failures.append((url, err))
    return None


def valid_json(p):
    try:
        with open(p, "rb") as f:
            json.loads(f.read())
        return True
    except Exception:
        return False


def valid_pdf(p):
    try:
        with open(p, "rb") as f:
            b = f.read()
        return b[:4] == b"%PDF" and b"%%EOF" in b[-2048:]
    except Exception:
        return False


def fetch_file(url, path, check):
    if os.path.exists(path) and check(path):
        return "cached"
    body = get(url)
    if body is None:
        return "fail"
    tmp = path + ".part"
    with open(tmp, "wb") as f:
        f.write(body)
    if not check(tmp):
        os.remove(tmp)
        failures.append((url, "invalid content"))
        return "fail"
    os.replace(tmp, path)
    return "fetched"


def year_2022():
    d = os.path.join(OUT, "2022")
    os.makedirs(d, exist_ok=True)
    ev = os.path.join(d, "LGEEvents.json")
    fetch_file(API + "LGEEvents", ev, valid_json)
    if not valid_json(ev):
        return 0
    events = json.load(open(ev, encoding="utf-8"))
    match = [e for e in events if e["electionName"] == PERIODIC_2022]
    if len(match) != 1:
        failures.append(("LGEEvents", "expected exactly one %r, got %d" % (PERIODIC_2022, len(match))))
        return 0
    date = match[0]["electionDate"]
    n = 0
    for name in ("LGEStatic", "LGEChange"):
        r = fetch_file("%s%s/%s/0" % (API, name, date), os.path.join(d, "%s-%s.json" % (name, date)), valid_json)
        n += r != "fail"
    return n


def year_2018():
    d = os.path.join(OUT, "2018")
    os.makedirs(d, exist_ok=True)
    art = os.path.join(d, "article-id110.html")
    if not (os.path.exists(art) and os.path.getsize(art) > 50000):
        body = get(ARTICLE)
        if body is None:
            return 0
        open(art, "wb").write(body)
    html = open(art, encoding="utf-8", errors="replace").read()
    slugs = sorted(set(re.findall(r"edocman/(2018-lg-[^\"/?]+)/download", html)))
    if len(slugs) < 200:
        failures.append(("article", "only %d PDF links found" % len(slugs)))
    n = 0
    for s in slugs:
        r = fetch_file(PDF_URL.format(slug=s), os.path.join(d, s + ".pdf"), valid_pdf)
        n += r != "fail"
    print("2018: %d links in article" % len(slugs))
    return n


if __name__ == "__main__":
    for y, fn in (("2022", year_2022), ("2018", year_2018)):
        print("%s: %d files ok" % (y, fn()))
    # 2010/2014: no candidate-level source known; not fetched.
    for u, e in failures:
        print("FAILED", u, e, file=sys.stderr)
    sys.exit(1 if failures else 0)
