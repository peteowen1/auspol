"""Fetch what the state electoral commissions publish for lower-house elections, raw and unmodified.

Companion to docs/reviews/state-commissions-audit-2026-10-30.md. One request at a time, 1 s pause, browser-like
user agent. Nothing is parsed; every response is written byte for byte under external/reference/<commission>/...
Files already on disk are skipped. Every request (including 404s) is appended to
external/reference/state-commissions-fetch-log.csv (url, path, status, bytes, note).
Nothing behind a login or form is attempted; a 403 is logged and left alone.

Usage: python scripts/fetch_state_commissions.py [vec nswec ecq ecsa waec]
"""
import csv, html, json, os, re, sys, time, urllib.parse, urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "external", "reference")
ROOT = os.path.abspath(ROOT)
LOG = os.path.join(ROOT, "state-commissions-fetch-log.csv")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/130.0 Safari/537.36")


def log(url, path, status, n, note=""):
    new = not os.path.exists(LOG)
    with open(LOG, "a", newline="", encoding="utf8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["url", "path", "status", "bytes", "note"])
        w.writerow([url, os.path.relpath(path, ROOT) if path else "", status, n, note])


def http(url, to=120):
    time.sleep(1)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=to) as f:
            return f.status, f.read()
    except urllib.error.HTTPError as e:
        return e.code, b""
    except Exception as e:  # network trouble: logged, not fatal
        return 0, str(e).encode()


def fetch(url, rel, note=""):
    """Save url to ROOT/rel unless it is already there. Returns bytes or None."""
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and os.path.getsize(path) > 0:
        with open(path, "rb") as f:
            return f.read()
    s, d = http(url)
    log(url, path if s == 200 else "", s, len(d), note)
    if s == 200 and d:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(d)
        return d
    return None


def links(t):
    return [(html.unescape(h), re.sub(r"\s+", " ", html.unescape(re.sub("<[^>]+>", "", x))).strip())
            for h, x in re.findall(r'<a [^>]*href="([^"]+)"[^>]*>(.*?)</a>', t, re.S)]


# ---------------------------------------------------------------- VEC
def vec():
    B = "https://www.vec.vic.gov.au"
    BLOB = "https://itsitecoreblobvecprd01.blob.core.windows.net/public-files/"
    pages = ["results/state-election-results", "results/state-election-results/2022-state-election-results",
             "results/state-election-results/2018-state-election", "results/state-election-results/2014-state-election",
             "results/state-election-results/2010-state-election", "results/state-election-results/2006-state-election",
             "results/state-election-results/state-by-elections-timeline",
             "results/electoral-statistics/state-election-statistics",
             "results/electoral-statistics/state-election-statistics/full-preference-distributions",
             "about-us/media/2026-results-data-feed"]
    for p in pages:
        fetch(f"{B}/{p}", f"vec/state-pages/{p.replace('/', '_')}.html")
    # 2022 two-party-preferred all districts (linked from the 2022 results page)
    t = fetch(f"{B}/results/state-election-results/2022-state-election-results", "vec/state-pages/results_state-election-results_2022-state-election-results.html")
    if t:
        for a, x in links(t.decode("utf8", "replace")):
            if a.startswith("/-/media/") and "wo-party" in x.lower().replace("-", "-"):
                fetch(B + a, f"vec/2022/files/{os.path.basename(a)}", x)
    # full preference distributions 2022 (39 districts)
    t = fetch(f"{B}/results/electoral-statistics/state-election-statistics/full-preference-distributions",
              "vec/state-pages/results_electoral-statistics_state-election-statistics_full-preference-distributions.html")
    if t:
        for a, x in links(t.decode("utf8", "replace")):
            if a.startswith("/-/media/") and "distribution" in x.lower():
                ext = os.path.splitext(a)[1]
                fetch(B + a, f"vec/2022/full-preference-distributions/{os.path.basename(a)}", x)
    # blob container listing from an earlier session (names+sizes of the public container)
    lst = json.load(open(os.path.join(ROOT, "vec", "blobs", "container-listing.json"), encoding="utf8"))
    names = [n for n, s in lst]
    lower = lambda n: not re.search(r"region|GroupVotingTicket|upper", n, re.I)
    sets = {
        "vec/2022/state-reports": [n for n in names if n.startswith("State/Reports/") and lower(n)],
        "vec/2018/files": [n for n in names if n.startswith("historical-results/state2018/files/") and lower(n)],
        "vec/2014/files": [n for n in names if n.startswith("historical-results/state2014/files/") and lower(n)],
        "vec/historical-files": [n for n in names if n.startswith("historical-results/files/") and lower(n)],
    }
    for dest, ns in sets.items():
        for n in ns:
            fetch(BLOB + urllib.parse.quote(n), f"{dest}/{os.path.basename(n)}")


# ---------------------------------------------------------------- NSWEC
def nswec():
    B = "https://pastvtr.elections.nsw.gov.au"
    # 2023 and 2019 (same layout), 2015 (old layout)
    for ev in ("SG2301", "SG1901"):
        t = fetch(f"{B}/{ev}/LA/results", f"nswec/{ev}/LA-results.html")
        if not t:
            continue
        t = t.decode("utf8", "replace")
        for page in ("elected", "formal", "turnout"):
            fetch(f"{B}/{ev}/LA/state/{page}", f"nswec/{ev}/LA-state-{page}.html")
        fetch(f"{B}/{ev}/LA/status", f"nswec/{ev}/LA-status.html")
        slugs = sorted(set(re.findall(rf"/{ev}/LA/([a-z0-9-]+)/preferences", t, re.I)))
        print(ev, len(slugs), "districts")
        for sl in slugs:
            fetch(f"{B}/{ev}/LA/{sl}/TCP", f"nswec/{ev}/tcp/{sl}.html")
            pg = fetch(f"{B}/{ev}/LA/{sl}/preferences", f"nswec/{ev}/preferences-pages/{sl}.html")
            if pg:
                for a, x in links(pg.decode("utf8", "replace")):
                    if a.lower().endswith(".zip"):
                        url = urllib.parse.urljoin(f"{B}/{ev}/LA/{sl}/preferences", urllib.parse.quote(a, safe="/:%"))
                        # the zip sits one level above the 'preferences' page
                        nm = urllib.parse.unquote(os.path.basename(a))  # the href is already percent-encoded
                        url = f"{B}/{ev}/LA/{sl}/" + urllib.parse.quote(nm)
                        fetch(url, f"nswec/{ev}/preferences/{nm}", "ballot-level preference markings")
    # 2015
    t = fetch(f"{B}/SGE2015/la-home.htm", "nswec/SGE2015/la-home.htm")
    if t:
        t = t.decode("utf8", "replace")
        for page in ("formal", "turnout", "tpp", "tcp"):
            fetch(f"{B}/SGE2015/la/state/{page}/index.htm", f"nswec/SGE2015/la-state-{page}.htm")
        fetch(f"{B}/SGE2015/la/state/data/index.htm", "nswec/SGE2015/la-state-data.htm")
        slugs = sorted(set(re.findall(r"/SGE2015/la/([a-z0-9-]+)/preferences/index.htm", t, re.I)))
        print("SGE2015", len(slugs), "districts")
        for sl in slugs:
            pg = fetch(f"{B}/SGE2015/la/{sl}/preferences/index.htm", f"nswec/SGE2015/preferences-pages/{sl}.htm")
            if pg:
                for a, x in links(pg.decode("utf8", "replace")):
                    if a.lower().endswith(".zip"):
                        url = B + urllib.parse.quote(a, safe="/:%")
                        fetch(url, f"nswec/SGE2015/preferences/{os.path.basename(a)}", "ballot-level preference markings")
    # venue lists and the media-feed documents
    P = "https://elections.nsw.gov.au"
    for u, f in [("/getmedia/71fd047c-442c-4320-98ef-448ff34f4481/votingcentres-sge2023.xlsx", "SG2301/votingcentres-sge2023.xlsx"),
                 ("/getmedia/622acdb8-4a24-46f1-90a0-1b0579b18237/earlyvotingcentres-sge2023.xlsx", "SG2301/earlyvotingcentres-sge2023.xlsx"),
                 ("/getmedia/266db23b-e13f-4f27-b427-c73bd9d73f0f/declaredfacilties-sge2023.xlsx", "SG2301/declaredfacilties-sge2023.xlsx"),
                 ("/getmedia/b158f4cd-547d-4580-ba2c-e74aa259c21c/nswec-state-and-local-election-media-feeds.pdf", "media-feed/nswec-state-and-local-election-media-feeds.pdf"),
                 ("/media/election-results-feed", "media-feed/election-results-feed.html"),
                 ("/elections/past-results/state-election-results/2023-nsw-state-election-results", "state-pages/2023-nsw-state-election-results.html"),
                 ("/elections/past-results/state-election-results/2019-nsw-state-election-results", "state-pages/2019-nsw-state-election-results.html"),
                 ("/elections/past-results/state-election-results/2015-nsw-state-election-results", "state-pages/2015-nsw-state-election-results.html"),
                 ("/getmedia/e2dbefc9-6977-466d-bf6e-b1010ead66fc/2023-state-election-report-part-1.pdf", "SG2301/2023-state-election-report-part-1.pdf")]:
        fetch(P + u, f"nswec/{f}")


# ---------------------------------------------------------------- ECQ
def ecq():
    BASE = "https://resultsdata.elections.qld.gov.au"
    d = fetch(f"{BASE}/elections.json", "ecq/state-fetch/elections.json")
    if not d:
        return
    ev = json.loads(d)["elections"]
    for e in ev:
        if "State General" in e.get("electionType", "") or "State General" in e.get("electionName", ""):
            yr = str(e.get("electionDay", ""))[:4]
            if yr in ("2017", "2020", "2024"):
                st = e["stub"]
                print("ECQ", st, e["electionName"], e.get("archiveXML"))
                for k in ("electorates", "boundaryVenues"):
                    if e.get(k):
                        fetch(f"{BASE}/{e[k]}", f"ecq/state-fetch/{yr}/{e[k]}")
                if e.get("archiveXML"):
                    fetch(e["archiveXML"], f"ecq/state-fetch/{yr}/{os.path.basename(e['archiveXML'])}", "archive XML (final)")
    # 2017 stub is not in elections.json: the public.zip already on disk is the same file
    fetch("https://www.ecq.qld.gov.au/elections/state-and-local-elections/election-results", "ecq/state-fetch/ecq-results-page.html")


# ---------------------------------------------------------------- ECSA
def ecsa():
    A = "https://apim-ecsa-production.azure-api.net/results-display/"
    for date in ("2022-03-19", "2026-03-21"):
        fetch(A + f"HAStatic/{date}", f"ecsa/state-fetch/{date}/HAStatic-{date}.json")
        fetch(A + f"HAChange/{date}/0", f"ecsa/state-fetch/{date}/HAChange-{date}-v0.json", "data version in file; no history endpoint")
    for date in ("2018-03-17", "2014-03-15"):  # logged as 204 No Content: API holds no data for them
        fetch(A + f"HAChange/{date}/0", f"ecsa/state-fetch/{date}/HAChange-{date}-v0.json")
    S = "https://www.ecsa.sa.gov.au"
    for u, f in [("/se2026-daily-tally", "se2026-daily-tally.html"),
                 ("/elections/past-state-election-results", "past-state-election-results.html"),
                 ("/elections/2026-state-election", "2026-state-election.html"),
                 ("/enrolment/enrolment-statistics", "enrolment-statistics.html"),
                 ("/images/Roll-Data/Enrolment_by_age_27_March_2026.csv", "Enrolment_by_age_27_March_2026.csv"),
                 ("/images/Roll-Data/Enrolment_by_age_27_February_2026.csv", "Enrolment_by_age_27_February_2026.csv")]:
        fetch(S + u, f"ecsa/state-fetch/{f}")


# ---------------------------------------------------------------- WAEC
def waec():
    A = "https://eis.waec.wa.gov.au/api/sgElections/"
    for sg in ("sg2008", "sg2013", "sg2017", "sg2021", "sg2025"):
        for ep in ("STATE/statistics", "pollingPlacesEarly", "pollingPlacesEarlyOther", "LAVoteSummary",
                   "LAResultsByParty", "timeline", "LAElectedMembers", "list"):
            fetch(A + f"{sg}/{ep}", f"waec/state-fetch/{sg}/api/{ep.replace('/', '_')}.json")
        d = fetch(A + f"{sg}/LAElectedMembers", f"waec/state-fetch/{sg}/api/LAElectedMembers.json")
        if d:
            codes = [e["ElectorateCode"] for e in json.loads(d).get("electorates", []) if e.get("ElelctorateType") == "District"]
            for c in codes:
                fetch(A + f"{sg}/{c}/pollingPlaces", f"waec/state-fetch/{sg}/api/pollingPlaces/{c}.json")
    W = "https://www.elections.wa.gov.au"
    for p, f in [("/voterstatistics", "voterstatistics.html"), ("/2025-state-general-election", "2025-state-general-election.html"),
                 ("/elections/state/past-elections", "past-elections.html"),
                 ("/enrol/enrolment-statistics/state-enrolment-reports", "state-enrolment-reports.html")]:
        t = fetch(W + p, f"waec/state-fetch/pages/{f}")
        if t and f in ("voterstatistics.html", "2025-state-general-election.html"):
            for a, x in links(t.decode("utf8", "replace")):
                if "/sites/default/files/" in a and a.lower().endswith((".pdf", ".xlsx", ".xls", ".csv")):
                    url = ("https:" + a) if a.startswith("//") else (W + a if a.startswith("/") else a)
                    parts = urllib.parse.urlsplit(url)
                    url = urllib.parse.urlunsplit((parts.scheme, parts.netloc, urllib.parse.quote(parts.path), "", ""))
                    sub = "2021" if "SGE 2021" in a else "2025"
                    fetch(url, f"waec/state-fetch/{sub}-stats/{os.path.basename(a)}", x)


if __name__ == "__main__":
    which = sys.argv[1:] or ["vec", "nswec", "ecq", "ecsa", "waec"]
    for w in which:
        print("==", w, flush=True)
        globals()[w]()
    print("done")
