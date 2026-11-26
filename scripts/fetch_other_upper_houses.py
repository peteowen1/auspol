"""Fetch the raw upper-house (and SA lower-house) first-preference files for
NSW 2019/2023, SA 2022/2026 and WA 2021/2025.

One file per request, saved exactly as received under
external/reference/upper-house/<state><year>/ (gitignored), with a manifest.tsv
(file, url, utc_time, status, bytes, sha256) in each directory.  Idempotent: a
file already on disk with a manifest row is not fetched again.  About one
request per second.  Read by scripts/build_other_upper_houses.R.

Run: python -I scripts/fetch_other_upper_houses.py [nsw2023 sa2026 ...]
"""
import hashlib, os, sys, time, datetime, urllib.request, urllib.error

# external/ is gitignored and lives in the main checkout; set AUSPOL_EXTERNAL to override (a git worktree has none).
_repo = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
_cands = [os.environ.get("AUSPOL_EXTERNAL", ""), os.path.join(_repo, "external"),
          os.path.join(_repo, "..", "auspol", "external")]
_ext = next((c for c in _cands if c and os.path.isdir(os.path.join(c, "elections"))), _cands[1])
ROOT = os.path.join(_ext, "reference", "upper-house")
NSW = "https://pastvtr.elections.nsw.gov.au"
SA = "https://apim-ecsa-production.azure-api.net/results-display"
WA = "https://eis.waec.wa.gov.au/api/sgElections"
WAF = "https://www.elections.wa.gov.au/sites/default/files/waec/sg_elections/LCDetailedResults"

JOBS = []  # (dir, filename, url)
for d, ev, yr in (("nsw2023", "SG2301", 2023), ("nsw2019", "SG1901", 2019)):
    JOBS += [(d, "LC-results.html", f"{NSW}/{ev}/LC/results"),
             (d, "LC-fp_summary.html", f"{NSW}/{ev}/LC/state/cc/fp_summary"),
             (d, f"SGE {yr} LC Final Votes.xlsx", f"{NSW}/{ev}/LC/state/SGE%20{yr}%20LC%20Final%20Votes.xlsx")]
for d, dt in (("sa2026", "2026-03-21"), ("sa2022", "2022-03-19")):
    JOBS += [(d, f"LCStatic-{dt}.json", f"{SA}/LCStatic/{dt}"),
             (d, f"LCChange-{dt}-v0.json", f"{SA}/LCChange/{dt}/0"),
             (d, f"HAStatic-{dt}.json", f"{SA}/HAStatic/{dt}"),
             (d, f"HAChange-{dt}-v0.json", f"{SA}/HAChange/{dt}/0")]
for d, sg in (("wa2025", "sg2025"), ("wa2021", "sg2021")):
    JOBS += [(d, "LCResultsByParty.json", f"{WA}/{sg}/LCResultsByParty"),
             (d, "LCVoteSummary.json", f"{WA}/{sg}/LCVoteSummary"),
             (d, "LCPages.json", f"{WA}/{sg}/LCPages")]
JOBS += [("wa2025", "Whole_of_State_First_Preference_Analysis_Report_by_Candidate.xlsx",
          f"{WAF}/sg2025/Whole_of_State%20First_Preference_Analysis_Report_by_Candidate.xlsx"),
         ("wa2025", "LC_First_Preference_by_Polling_Place.xlsx", f"{WAF}/sg2025/LC_First_Preference_by_Polling_Place.xlsx")]
for r in ("Agricultural", "EastMetro", "MiningPastoral", "NorthMetro", "SouthMetro", "SouthWest"):
    JOBS.append(("wa2021", f"{r}_FirstPreferences.xlsx", f"{WAF}/sg2021/{r}_FirstPreferences.xlsx"))


def main(only=None):
    for d, fn, url in JOBS:
        if only and d not in only:
            continue
        dd = os.path.join(ROOT, d)
        os.makedirs(dd, exist_ok=True)
        path = os.path.join(dd, fn)
        man = os.path.join(dd, "manifest.tsv")
        if os.path.exists(path) and os.path.exists(man) and fn in open(man, encoding="utf8").read():
            continue
        req = urllib.request.Request(url, headers={"User-Agent": "auspol-research-fetch/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                body, status = r.read(), r.status
        except urllib.error.HTTPError as e:
            body, status = e.read(), e.code
        t = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        if status == 200:
            with open(path, "wb") as f:
                f.write(body)
        new = not os.path.exists(man)
        with open(man, "a", encoding="utf8") as m:
            if new:
                m.write("file\turl\tutc_time\tstatus\tbytes\tsha256\n")
            m.write(f"{fn}\t{url}\t{t}\t{status}\t{len(body)}\t{hashlib.sha256(body).hexdigest()}\n")
        print(d, fn, status, len(body), flush=True)
        time.sleep(1.0)


if __name__ == "__main__":
    main(set(sys.argv[1:]) or None)
