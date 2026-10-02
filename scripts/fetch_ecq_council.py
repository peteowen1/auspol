#!/usr/bin/env python
"""Fetch Queensland local-government (quadrennial) results from the ECQ.

Raw responses are stored unedited under external/reference/ecq/council/<year>/.
Idempotent: a JSON file that parses, or an HTML file with a closing </html> tag,
is never refetched. Exit status is non-zero if anything expected is missing.

Sources
  2020, 2024  Azure blob JSON, https://resultsdata.elections.qld.gov.au/
              (stubs lga2020 and 2024QLGE): electorates, declared candidates,
              primary count per division and per mayoral contest.
  2016        HTML on results.ecq.qld.gov.au (live site). Council URL names are
              built from the 2020 electorates file; ward pages from the links on
              each council's councillor summary page.
  2012, 2008  HTML from the Wayback Machine (the live site 404s). The CDX index
              is saved as cdx.json; the LATEST archived snapshot of each page is
              fetched (older ones can be mid-count), with `id_` for raw bytes.
              manifest.json maps each stored file to its snapshot timestamp and
              original URL.

Usage: python scripts/fetch_ecq_council.py [--years 2020,2024,2016,2012,2008]
Only stdlib; no packages are installed.
"""
import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "external" / "reference" / "ecq" / "council"
BLOB = "https://resultsdata.elections.qld.gov.au"
LIVE = "https://results.ecq.qld.gov.au/elections/local"
WAYBACK = "https://web.archive.org"
UA = {"User-Agent": "Mozilla/5.0 (auspol research fetcher; polite, 1 req/s)"}
STUBS = {2020: "lga2020", 2024: "2024QLGE"}
WB_PREFIX = {2012: "LG2012", 2008: "LG2008"}

failures = []


def http_get(url, delay, tries=6):
    """GET with backoff on 429/5xx/network errors. Returns bytes or None on 404."""
    wait = 5
    for i in range(tries):
        time.sleep(delay)
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(wait)
                wait = min(wait * 2, 120)
                continue
            raise
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            time.sleep(wait)
            wait = min(wait * 2, 120)
    raise RuntimeError(f"gave up after {tries} tries: {url}")


def complete(path):
    if not path.exists() or path.stat().st_size == 0:
        return False
    raw = path.read_bytes()
    if path.suffix == ".json":
        try:
            json.loads(raw.decode("utf-8-sig"))
            return True
        except ValueError:
            return False
    return b"</html>" in raw[-400:].lower()


def save(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".part")
    tmp.write_bytes(raw)
    tmp.replace(path)


def fetch_to(url, path, delay, counts, expect_json=False):
    """Fetch url to path unless already complete. True if the file is complete."""
    if complete(path):
        counts["cached"] += 1
        return True
    raw = http_get(url, delay)
    if raw is None:
        counts["404"] += 1
        failures.append(f"404 {url}")
        return False
    save(path, raw)
    if not complete(path):
        counts["incomplete"] += 1
        failures.append(f"incomplete {url}")
        path.unlink()
        return False
    counts["fetched"] += 1
    return True


def new_counts():
    return {"fetched": 0, "cached": 0, "404": 0, "incomplete": 0}


# ---------------------------------------------------------------- 2020 / 2024
def fetch_json_year(year):
    stub = STUBS[year]
    d = OUT / str(year)
    c = new_counts()
    delay = 0.25
    fetch_to(f"{BLOB}/elections.json", d / "elections.json", delay, c)
    ok_el = fetch_to(f"{BLOB}/{stub}-electorates.json", d / f"{stub}-electorates.json", delay, c)
    fetch_to(f"{BLOB}/{stub}-declared_candidates.json", d / f"{stub}-declared_candidates.json", delay, c)
    if not ok_el:
        return c
    els = json.loads((d / f"{stub}-electorates.json").read_text(encoding="utf-8-sig"))["electorates"]
    unopposed = 0
    for e in els:
        if e["contestType"] == "Mayor":
            if e.get("candidatesMayorCount", 0) < 2:
                unopposed += 1
                continue
            name = f"{stub}-primary-count-summary-{e['areaCode']}-mayor.json"
        else:
            if e.get("candidatesCouncillorCount", 0) <= e.get("numberToElect", 1):
                unopposed += 1
                continue
            name = f"{stub}-primary-count-division-{e['areaCode']}-councillor.json"
        fetch_to(f"{BLOB}/{name}", d / name, delay, c)
    c["skipped_uncontested"] = unopposed
    return c


# ------------------------------------------------------------------------ 2016
def council_slug(lga_name):
    return re.sub(r"[^A-Za-z-]", "", lga_name) + "Council"


def lga_names():
    p = OUT / "2020" / "lga2020-electorates.json"
    if not complete(p):
        raise SystemExit("2020 electorates file needed to name councils; fetch 2020 first")
    els = json.loads(p.read_text(encoding="utf-8-sig"))["electorates"]
    return [e["lgaName"] for e in els if e["contestType"] == "Mayor"]


def fetch_2016():
    d = OUT / "2016"
    c = new_counts()
    delay = 0.4
    for name in lga_names():
        slug = council_slug(name)
        # Lockyer Valley's election was postponed to 16 April 2016 after the sitting
        # mayor died; its LG2016 pages are stubs and the results live under LV2016.
        edition = "LV2016" if slug == "LockyerValleyRegionalCouncil" else "LG2016"
        base = f"{LIVE}/{edition}/{slug}/results"
        summ = d / slug / "councillor_summary.html"
        ok = fetch_to(f"{base}/councillor/summary.html", summ, delay, c)
        mpath = d / slug / "mayoral_summary.html"
        if fetch_to(f"{base}/mayoral/summary.html", mpath, delay, c):
            mh = mpath.read_bytes().decode("cp1252", "replace")
            if "Results Summary" not in mh and "Elected Unopposed" not in mh:
                # summary page without a first-preference table (Lockyer Valley's postponed
                # election): the single undivided-council page carries the results
                fetch_to(f"{base}/mayoral/district1.html", d / slug / "mayoral_district1.html", delay, c)
        if not ok:
            continue
        html = summ.read_bytes().decode("cp1252", "replace")
        districts = sorted({int(n) for n in re.findall(r'href="district(\d+)\.html"', html)})
        if not districts and "Elected Unopposed" not in html:
            # an undivided council whose councillors were all unopposed has no ward
            # pages (the names are on the summary page); anything else is a gap
            failures.append(f"2016 {slug}: no district links on councillor summary")
        for n in districts:
            fetch_to(f"{base}/councillor/district{n}.html", d / slug / f"councillor_district{n}.html", delay, c)
    return c


# ------------------------------------------------------------- 2012 / 2008 wayback
def council_key(first_segment):
    """Archived council folder name -> comparable key (variants differ by case, %20, 'Council')."""
    s = first_segment.replace("%20", "").lower()
    return re.sub(r"council$", "", s)


def load_cdx(year, prefix, delay=1.2):
    p = OUT / str(year) / "cdx.json"
    if p.exists():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except ValueError:
            pass
    url = (f"{WAYBACK}/cdx/search/cdx?url=results.ecq.qld.gov.au/elections/local/{prefix}/*"
           "&output=json&fl=timestamp,original,statuscode,mimetype"
           "&filter=statuscode:200&filter=mimetype:text/html")
    raw = http_get(url, delay)
    if raw is None:
        raise RuntimeError("CDX 404")
    rows = json.loads(raw)
    save(p, raw)
    return rows


def plan_wayback(year, prefix, cdx):
    """Return {(council_key, kind): [(ts, original), ...] newest first}."""
    plan = {}
    for ts, orig, _sc, _mt in cdx[1:]:
        tail = re.split(r"/%s/" % prefix, orig, flags=re.I)
        if len(tail) < 2:
            continue
        parts = tail[1].split("/")
        if len(parts) < 4 or parts[1].lower() != "results":
            continue
        m = re.fullmatch(r"(summary|district(\d+))\.html", parts[3], flags=re.I)
        if not m or parts[2].lower() not in ("councillor", "mayoral"):
            continue
        if parts[2].lower() == "mayoral" and m.group(1).lower() != "summary":
            continue  # ward-level mayoral pages are not needed
        kind = f"{parts[2].lower()}_{m.group(1).lower()}"
        plan.setdefault((council_key(parts[0]), kind), []).append((ts, orig))
    for v in plan.values():
        v.sort(reverse=True)
    return plan


def fetch_wayback(year):
    prefix = WB_PREFIX[year]
    d = OUT / str(year)
    c = new_counts()
    cdx = load_cdx(year, prefix)
    plan = plan_wayback(year, prefix, cdx)
    mpath = d / "manifest.json"
    manifest = json.loads(mpath.read_text()) if mpath.exists() else {}
    councils = sorted({k for k, _ in plan})
    c["councils_in_cdx"] = len(councils)
    for (ckey, kind), snaps in sorted(plan.items()):
        rel = f"{ckey}/{kind}.html"
        path = d / rel
        if complete(path) and rel in manifest:
            c["cached"] += 1
            continue
        got = False
        for ts, orig in snaps[:4]:  # newest first; fall back if a snapshot is a stub
            raw = http_get(f"{WAYBACK}/web/{ts}id_/{orig}", 1.2)
            if raw is None or b"</html>" not in raw[-400:].lower():
                continue
            if b"Candidate" not in raw and b"unopposed" not in raw.lower():
                continue
            save(path, raw)
            manifest[rel] = {"timestamp": ts, "original": orig}
            mpath.write_text(json.dumps(manifest, indent=1, sort_keys=True))
            c["fetched"] += 1
            got = True
            break
        if not got:
            c["incomplete"] += 1
            failures.append(f"{year} wayback: no usable snapshot for {rel} (tried {len(snaps[:4])})")
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--years", default="2020,2024,2016,2012,2008")
    years = [int(y) for y in ap.parse_args().years.split(",")]
    for y in years:
        t0 = time.time()
        if y in STUBS:
            c = fetch_json_year(y)
        elif y == 2016:
            c = fetch_2016()
        elif y in WB_PREFIX:
            c = fetch_wayback(y)
        else:
            raise SystemExit(f"unknown year {y}")
        print(f"{y}: {c}  ({time.time() - t0:.0f}s)", flush=True)
    if failures:
        print(f"\n{len(failures)} FAILURES")
        for f in failures[:60]:
            print("  ", f)
        sys.exit(1)
    print("OK: no failures")


if __name__ == "__main__":
    main()
