#!/usr/bin/env python3
"""Fetch WA local-government ORDINARY election results, 2005-2023.

Sources (no key):
  API   https://eis.waec.wa.gov.au/api/localElections/...
        ordinaryList/{eventGUID}          councils in an ordinary event
        council/{Name}                    a council's elections (with GUIDs)
        council/{Name}/{eventGUID}        results (2007-2023)
  HTML  elections.wa.gov.au .../OldHTML/2005 Ordinary Election/{Council}.htm
        (the API returns only an empty 'info' block for 2005)

Everything is stored raw and unedited under external/reference/waec/council/:
  lists/ordinary-list-<year>.json   council list per year
  lists/council-<Name>.json         each council's election list
  <year>/<Name>.json (or .htm)      results
Idempotent: a complete file (valid JSON / plausible 2005 page) is skipped.
Polite: 0.2 s between requests, one retry. Exits non-zero on any failure.
HTTP 404 on a 2005 page means the council had no page and is recorded, not
treated as a failure.
"""
import json, re, sys, time, urllib.parse, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "external/reference/waec/council"
API = "https://eis.waec.wa.gov.au/api/localElections"
HTML05 = ("https://www.elections.wa.gov.au/sites/default/files/waec/lg_elections/"
          "OldHTML/2005%20Ordinary%20Election/{}.htm")
YEARS = [2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2021, 2023]
DELAY = 0.2
_last = [0.0]
failures = []


def get(url):
    """Return bytes; raises HTTPError on non-2xx after one retry (404 not retried)."""
    for attempt in (1, 2):
        wait = DELAY - (time.time() - _last[0])
        if wait > 0:
            time.sleep(wait)
        _last[0] = time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "auspol-research/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 404 or attempt == 2:
                raise
        except Exception:
            if attempt == 2:
                raise
        time.sleep(1.5)


def valid_json(p):
    try:
        json.loads(p.read_bytes().decode("utf-8"))
        return True
    except Exception:
        return False


def fetch_json(url, path):
    if path.exists() and valid_json(path):
        return json.loads(path.read_bytes().decode("utf-8")), False
    b = get(url)
    json.loads(b.decode("utf-8"))  # validate before writing
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b)
    return json.loads(b.decode("utf-8")), True


def q(name):
    return urllib.parse.quote(name, safe="")


def main():
    lists = ROOT / "lists"
    # Albany has every ordinary election since 1999: use it to find event GUIDs.
    alb, _ = fetch_json(f"{API}/council/Albany", lists / "council-Albany.json")
    guid = {}
    for e in alb:
        m = re.fullmatch(r"(\d{4}) Ordinary Election", e["NAME"])
        if m:
            guid[int(m.group(1))] = e["ELECTION_EVENT_GUID"]
    missing = [y for y in YEARS if y not in guid]
    if missing:
        sys.exit(f"no Albany event GUID for {missing}")

    councils = {}
    for y in YEARS:
        d, _ = fetch_json(f"{API}/ordinaryList/{guid[y]}", lists / f"ordinary-list-{y}.json")
        councils[y] = [x["DISTRICT_NAME"] for x in d]
    union = sorted({n for y in YEARS for n in councils[y]})
    print("event GUIDs:", {y: guid[y] for y in YEARS})

    summary = {}
    for y in YEARS:
        got = new = nores = 0
        if y == 2005:
            # Static pages; the API list for 2005 plus every council seen in any
            # year, since a page is cheap to probe and 404 is recorded.
            names = sorted(set(councils[2005]) | set(union))
            absent = []
            for n in names:
                p = ROOT / "2005" / f"{n}.htm"
                if p.exists() and p.stat().st_size > 500 and b"Date of Election" in p.read_bytes():
                    got += 1
                    continue
                try:
                    b = get(HTML05.format(q(n)))
                except urllib.error.HTTPError as e:
                    if e.code == 404:
                        absent.append(n)
                        continue
                    failures.append((y, n, str(e)))
                    continue
                except Exception as e:
                    failures.append((y, n, str(e)))
                    continue
                if b"Date of Election" not in b or len(b) < 500:
                    failures.append((y, n, "page looks incomplete"))
                    continue
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(b)
                got += 1
                new += 1
            (ROOT / "2005").mkdir(parents=True, exist_ok=True)
            (ROOT / "2005" / "_no_page_404.json").write_text(json.dumps(absent))
            summary[y] = f"{got} pages ({new} new); 404 for {len(absent)} of {len(names)} names probed"
            continue
        for n in councils[y]:
            try:
                cl, _ = fetch_json(f"{API}/council/{q(n)}", lists / f"council-{n}.json")
                ev = [e for e in cl
                      if re.fullmatch(rf"{y} Ordinary Election", e["NAME"])]
                if not ev:
                    nores += 1
                    failures.append((y, n, "council list has no ordinary event for year"))
                    continue
                _, fresh = fetch_json(f"{API}/council/{q(n)}/{ev[0]['ELECTION_EVENT_GUID']}",
                                      ROOT / str(y) / f"{n}.json")
                got += 1
                new += fresh
            except Exception as e:
                failures.append((y, n, str(e)))
        summary[y] = f"{got} of {len(councils[y])} councils ({new} new)"
    print("per-year:")
    for y in YEARS:
        print(f"  {y}: {summary[y]}")
    if failures:
        print(f"FAILURES ({len(failures)}):")
        for f in failures:
            print("  ", f)
        sys.exit(1)


if __name__ == "__main__":
    main()
