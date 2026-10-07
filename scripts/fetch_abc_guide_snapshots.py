#!/usr/bin/env python
"""Fetch archived (pre-election ONLY) ABC election-guide seat pages and pull candidate bios.

Leakage rule: for each (election, seat) only a Wayback Machine capture timestamped strictly
before polling day is ever requested.  The CDX query is capped with `to=`, the exact timestamp
is then fetched in raw `id_` form, and the served timestamp (final URL AND Memento-Datetime
header) is asserted to be before polling day.  The script stops (AssertionError) if an ok
row ever fails that.  The cap is 12:00 UTC on the day before polling day, which is 22:00-23:00
on that day in AEST/AEDT and 20:00 in WA, so "before polling day" holds in local time too.
vic2026 (not yet held) is fetched LIVE from abc.net.au and the fetch time recorded.

Inputs : external/reference/successors/coding-input.csv   (nothing else is read)
Outputs: external/reference/successors/abc-guide-raw/<election>_<seat>.html
         external/reference/successors/abc-guide-snapshots.csv
         external/reference/successors/abc-guide-bios.csv
Cache  : external/reference/successors/abc-guide-raw/_cache/   (listings, scanned pages)
Resumable: cells with a final status in snapshots.csv are skipped (--redo-missing re-tries
the non-ok ones).  Run:  python scripts/fetch_abc_guide_snapshots.py [--redo-missing] [--only fed2022]
"""
import csv, datetime, email.utils, gzip, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request
from bs4 import BeautifulSoup

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "external", "reference", "successors")
ROOT = os.path.normpath(ROOT)
RAW = os.path.join(ROOT, "abc-guide-raw")
CACHE = os.path.join(RAW, "_cache")
INPUT = os.path.join(ROOT, "coding-input.csv")
SNAP = os.path.join(ROOT, "abc-guide-snapshots.csv")
BIOS = os.path.join(ROOT, "abc-guide-bios.csv")
os.makedirs(CACHE, exist_ok=True)

UA = {"User-Agent": "Mozilla/5.0 (auspol-research pre-election snapshot fetcher)", "Accept-Encoding": "gzip, identity"}
LIVE_ELECTIONS = {"vic2026"}

# Guide directories (no scheme).  Several where the scheme changed within an election.
DIRS = {
    "fed2007": ["abc.net.au/elections/federal/2007/guide"],
    "fed2010": ["abc.net.au/elections/federal/2010/guide"],
    "fed2013": ["abc.net.au/news/elections/federal/2013/guide", "abc.net.au/news/federal-election-2013/guide"],
    "fed2019": ["abc.net.au/news/elections/federal/2019/guide"],
    "fed2022": ["abc.net.au/news/elections/federal/2022/guide"],
    "fed2025": ["abc.net.au/news/elections/federal/2025/guide"],
    "nsw2019": ["abc.net.au/news/elections/nsw/2019/guide"],
    "nsw2023": ["abc.net.au/news/elections/nsw/2023/guide"],
    "qld2020": ["abc.net.au/news/elections/qld/2020/guide"],
    "sa2022": ["abc.net.au/news/elections/sa/2022/guide"],
    "sa2026": ["abc.net.au/news/elections/sa/2026/guide"],
    "vic2014": ["abc.net.au/news/elections/vic/2014/guide", "abc.net.au/news/vic-election-2014/guide"],
    "vic2018": ["abc.net.au/news/elections/vic/2018/guide"],
    "vic2022": ["abc.net.au/news/elections/vic/2022/guide"],
    "vic2026": ["abc.net.au/news/elections/vic/2026/guide"],
    "wa2001": ["abc.net.au/elections/wa/2001/guide"],
    "wa2005": ["abc.net.au/elections/wa/2005/guide"],
    "wa2013": ["abc.net.au/elections/wa/2013/guide"],
    "wa2017": ["abc.net.au/news/elections/wa/2017/guide"],
    "wa2021": ["abc.net.au/news/elections/wa/2021/guide"],
    "wa2025": ["abc.net.au/news/elections/wa/2025/guide"],
}
NON_SEAT_CODES = {"amp", "embed", "candidates", "electorates", "key-seats", "lc-preview", "pendulum",
                  "preview", "retiring-mps", "antony_green", "index", "results", "guides", "master"}

# --------------------------------------------------------------------------- archive layer
def _unzip(b):
    # Wayback serves a page's original Content-Encoding on id_ captures (2019+ ABC pages are gzip).
    if b[:2] == b"\x1f\x8b":
        b = gzip.decompress(b)
    return b

def _get(url, timeout=90):
    req = urllib.request.Request(url, headers=UA)
    try:
        r = urllib.request.urlopen(req, timeout=timeout)
        return r.status, r.geturl(), dict(r.headers), _unzip(r.read())
    except urllib.error.HTTPError as e:
        return e.code, url, dict(e.headers or {}), (_unzip(e.read()) if e.fp else b"")

def offline(body):
    return b"Temporarily Offline" in body[:3000] or b"services are temporarily offline" in body[:8000]

def wb_get(url, tries=15):
    """GET from archive.org; back off (10-60 s) on the offline page, 429, 5xx and network errors."""
    delay = 10
    for _ in range(tries):
        try:
            st, fu, h, b = _get(url)
        except Exception:
            st, fu, h, b = 0, url, {}, b""
        if st in (429, 502, 503, 504, 0) or offline(b):
            time.sleep(delay); delay = min(delay * 1.6, 60); continue
        time.sleep(0.8)
        return st, fu, h, b
    raise RuntimeError("archive unavailable after retries: " + url)

def cdx(url, to=None, extra="", limit="-1"):
    q = "http://web.archive.org/cdx/search/cdx?url=%s&filter=statuscode:200&fl=timestamp,original&limit=%s%s" % (
        urllib.parse.quote(url, safe="*/:"), limit, extra)
    if to:
        q += "&to=" + to
    st, fu, h, b = wb_get(q)
    if st != 200:
        raise RuntimeError("cdx status %s %s" % (st, q))
    txt = b.decode("utf8", "replace").strip()
    return [l.split(" ") for l in txt.splitlines() if re.match(r"^\d{14} ", l)]

def cap_for(polling_date):
    d = datetime.date.fromisoformat(polling_date) - datetime.timedelta(days=1)
    return d.strftime("%Y%m%d") + "120000"

def polling_day_compact(polling_date):
    return polling_date.replace("-", "")

def fetch_exact(original, ts, polling_date):
    """Fetch the exact capture raw.  Returns (status, served_ts, memento_ts, body).  Raises
    AssertionError if the requested timestamp is not before the cap."""
    assert ts <= cap_for(polling_date), "requested ts %s not before polling day %s" % (ts, polling_date)
    st, fu, h, b = wb_get("http://web.archive.org/web/%sid_/%s" % (ts, original))
    m = re.search(r"/web/(\d{14})id_/", fu)
    served = m.group(1) if m else None
    hh = {k.lower(): v for k, v in h.items()}
    memts = None
    if hh.get("memento-datetime"):
        memts = email.utils.parsedate_to_datetime(hh["memento-datetime"]).strftime("%Y%m%d%H%M%S")
    return st, served, memts, b

def before_polling(served, memts, polling_date):
    if not served:
        return False
    pd_ = polling_day_compact(polling_date)
    ok = served[:8] < pd_
    if memts:
        ok = ok and memts[:8] < pd_
    return ok

def complete_html(b):
    return len(b) > 2000 and b"</html>" in b[-4000:].lower()

# --------------------------------------------------------------------------- listing / scanning
def norm(s):
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()

def seat_regex(seat):
    return re.compile(r"(?<![a-z])" + re.escape(norm(seat)).replace("\\ ", r"[\s\-]+") + r"(?![a-z])")

def page_heads(html):
    soup = BeautifulSoup(html, "lxml")
    t = soup.title.get_text(" ", strip=True) if soup.title else ""
    h1 = " | ".join(x.get_text(" ", strip=True) for x in soup.find_all("h1"))
    return t, h1

def code_of(original, dirpath):
    """First path segment under the guide dir, '.htm' stripped; None for non-clean URLs."""
    u = re.sub(r"^https?://", "", original)
    u = re.sub(r"^www\.", "", u)
    u = re.sub(r"^abc\.net\.au:80", "abc.net.au", u)
    base = dirpath + "/"
    if not u.lower().startswith(base):
        return None
    rest = u[len(base):]
    if "?" in rest or "#" in rest:
        return None
    rest = rest.rstrip("/")
    rest = re.sub(r"\.html?$", "", rest)
    if not rest or "/" in rest:
        return None
    return rest.lower()

def listing(election, dirpath, polling_date):
    """Every URL under the guide dir with >=1 200 capture on/before the cap: {code: [originals]}."""
    f = os.path.join(CACHE, "listing_%s_%s.json" % (election, re.sub(r"[^a-z0-9]", "_", dirpath)))
    if os.path.exists(f):
        return json.load(open(f))
    cap = cap_for(polling_date)
    rows = cdx(dirpath + "/*", to=cap, extra="&collapse=urlkey", limit="20000")
    pre = {}
    for ts, orig in rows:
        c = code_of(orig, dirpath)
        if c and c not in NON_SEAT_CODES:
            pre.setdefault(c, [])
            if orig not in pre[c]:
                pre[c].append(orig)
    allrows = cdx(dirpath + "/*", extra="&collapse=urlkey", limit="20000")  # no cap: only used to tell
    anycodes = sorted({code_of(o, dirpath) for _, o in allrows} - {None})   # 'exists but only after'
    out = {"pre": pre, "any_codes": anycodes, "n_pre_rows": len(rows), "n_any_rows": len(allrows)}
    json.dump(out, open(f, "w"))
    return out

def latest_capture(originals, polling_date):
    """All 200 captures on/before the cap across the clean URL variants of one page, newest first."""
    cap = cap_for(polling_date)
    cands = []
    for o in originals:
        for ts, orig in cdx(re.sub(r":80(?=/)", "", re.sub(r"^https?://", "", o)), to=cap):
            cands.append((ts, orig))
    return sorted(set(cands), reverse=True)

def get_page(election, key, originals, polling_date):
    """Cached pre-election fetch of one guide page.  Returns dict or None (no pre-election capture)."""
    meta_f = os.path.join(CACHE, "page_%s_%s.json" % (election, key))
    html_f = os.path.join(CACHE, "page_%s_%s.html" % (election, key))
    if os.path.exists(meta_f):
        m = json.load(open(meta_f))
        if m.get("none"):
            return None
        m["body"] = open(html_f, "rb").read()
        return m
    for ts, orig in latest_capture(originals, polling_date):
        st, served, memts, b = fetch_exact(orig, ts, polling_date)
        if st != 200 or not complete_html(b):
            continue
        if not before_polling(served, memts, polling_date) or served != ts:
            continue  # discard: Wayback served a different/later capture
        open(html_f, "wb").write(b)
        m = {"url": orig, "capture_ts": ts, "served_ts": served, "memento_ts": memts, "bytes": len(b)}
        json.dump(m, open(meta_f, "w"))
        m["body"] = b
        return m
    json.dump({"none": True}, open(meta_f, "w"))
    return None

def guess_order(seat, codes):
    s = re.sub(r"[^a-z]", "", seat.lower())
    words = [re.sub(r"[^a-z]", "", w) for w in seat.lower().replace("-", " ").split()]
    guesses = [s[:4]]
    if len(words) > 1:
        guesses += [words[0][:1] + "".join(words[1:])[:3], words[0][:2] + words[1][:2], "".join(w[:2] for w in words)[:4]]
    guesses += [s[:3], s[:5]]
    pri = {}
    for i, g in enumerate(guesses):
        pri.setdefault(g, i)
    # Seat codes are 4 letters in every era seen; other slugs (gvt-wmet, gtv_nsw_y2 ...) are not seat pages.
    four = [c for c in codes if re.fullmatch(r"[a-z]{4}", c)]
    key = lambda c: (pri.get(c, 99), c)
    return sorted(four, key=key)

def find_seat_page(election, seat, polling_date):
    """Returns (page dict, code, dir) or (None, reason, None)."""
    dirs = DIRS[election]
    lists = [(d, listing(election, d, polling_date)) for d in dirs]
    if not any(l["n_any_rows"] for _, l in lists):
        return None, "no_guide", None
    if not any(l["pre"] for _, l in lists):
        return None, "no_pre_election_capture", None
    rx = seat_regex(seat)
    order = []
    for di, (d, l) in enumerate(lists):
        for c in guess_order(seat, list(l["pre"].keys())):
            order.append((di, d, c, l["pre"][c]))
    for di, d, c, origs in order:
        pg = get_page(election, "%s@%d" % (c, di), origs, polling_date)
        if not pg:
            continue
        t, h1 = page_heads(pg["body"])
        if rx.search(norm(h1)) or (not h1 and rx.search(norm(t))):
            return pg, c, d
    # guide exists, but this seat's page may exist only after polling day
    first2 = re.sub(r"[^a-z]", "", seat.lower())[:2]
    for d, l in lists:
        late = set(l["any_codes"]) - set(l["pre"])
        if any(x.startswith(first2) for x in late if re.fullmatch(r"[a-z]{4}", x)):
            return None, "no_pre_election_capture", None
    return None, "seat_not_found", None

# --------------------------------------------------------------------------- live (vic2026)
def live_get(url):
    for i in range(4):
        try:
            st, fu, h, b = _get(url)
            return st, b
        except Exception:
            time.sleep(10 * (i + 1))
    return 0, b""

def find_live(election, seat):
    base = "https://www.abc.net.au/news/elections/vic/2026/guide/"
    cache = os.path.join(CACHE, "live_index.json")
    if os.path.exists(cache):
        codes = json.load(open(cache))
    else:
        st, b = live_get(base + "electorates")
        if st != 200:
            return None, "no_guide"
        codes = sorted(set(re.findall(r"/vic/2026/guide/([a-z]{4})\b", b.decode("utf8", "replace"))))
        json.dump(codes, open(cache, "w"))
    rx = seat_regex(seat)
    for c in guess_order(seat, codes):
        pf = os.path.join(CACHE, "live_%s.html" % c)
        if os.path.exists(pf):
            b = open(pf, "rb").read(); fetched = open(pf + ".ts").read()
        else:
            st, b = live_get(base + c)
            if st != 200 or not complete_html(b):
                continue
            fetched = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%S")
            open(pf, "wb").write(b); open(pf + ".ts", "w").write(fetched)
        t, h1 = page_heads(b)
        if rx.search(norm(h1)):
            return {"url": base + c, "capture_ts": fetched, "served_ts": fetched, "body": b, "bytes": len(b)}, c
    return None, "seat_not_found"

# --------------------------------------------------------------------------- bios
RESULT_RX = re.compile(r"\b(re-?elected|elected|result|results|counted|count|declared|winner|won|wins|swing|concede[ds]?)\b", re.I)

def surname_tokens(cand):
    # "SURNAME, Given" (sa/vic/qld rows) -- split on the comma, or the surname keeps
    # it ("DULUK,") and matches nothing on the page.
    if "," in cand:
        sn, given = [x.strip() for x in cand.split(",", 1)]
        return sn, (given.split()[0] if given else "")
    toks = cand.split()
    up = [t for t in toks if t.upper() == t and re.search(r"[A-Z]", t)]
    sn = " ".join(up) if up else toks[-1]
    given = [t for t in toks if t not in up]
    return sn, (given[0] if given else "")

def clean(s):
    return re.sub(r"\s+", " ", s).strip()

def surname_rx(sn):
    parts = [re.escape(p) for p in re.split(r"[\s\-]+", sn) if p]
    return re.compile(r"(?<![A-Za-z])" + r"[\s\-]+".join(parts) + r"(?![A-Za-z])", re.I)

def extract_bio(html, cand):
    """Return (found, on_list, text).  Verbatim profile text for one candidate, or ''."""
    sn, given = surname_tokens(cand)
    srx = surname_rx(sn)
    soup = BeautifulSoup(html, "lxml")
    for t in soup(["script", "style", "nav", "header", "footer", "noscript", "iframe", "svg"]):
        t.decompose()
    # Format A (2019+): <div class="eg-electorate-bio"> ... <h3>Name</h3> ... <p class="bio">
    blocks = soup.select("div.eg-electorate-bio")
    if blocks:
        mine = []
        for bl in blocks:
            h3 = bl.find("h3")
            name = clean(h3.get_text(" ", strip=True)) if h3 else clean(bl.get_text(" ", strip=True))[:80]
            if srx.search(name):
                mine.append((bl, name))
        if len(mine) > 1 and given:
            g = [x for x in mine if re.search(r"(?<![A-Za-z])" + re.escape(given) + r"(?![A-Za-z])", x[1], re.I)]
            mine = g or mine
        texts = []
        for bl, name in mine:
            bios = bl.select("p.bio")
            if not bios:
                # Some captures carry the profile as untagged <p> text after the
                # name and party line; a block with only "Name / Party" has none.
                bios = [p for p in bl.find_all("p") if len(clean(p.get_text(" ", strip=True))) > 60]
            texts.append(" ".join(clean(p.get_text(" ", strip=True)) for p in bios))
        text = " || ".join(t for t in texts if t)
        return bool(text), bool(mine), text
    # Format B (older prose pages): paragraphs mentioning the surname, outside tables,
    # outside History/Trivia/Result sections.
    paras, on_list = [], False
    # 2010-era pages hold each profile in a class="bio" block, often inside the
    # candidate table, so read them BEFORE the tables are removed below.
    for el in soup.select(".bio"):
        tx = clean(el.get_text(" ", strip=True))
        if tx and srx.search(tx):
            paras.append(tx)
    for tb in soup.find_all("table"):
        if srx.search(tb.get_text(" ", strip=True)):
            on_list = True
    for tb in soup.find_all("table"):
        tb.decompose()
    section = ""
    for el in soup.find_all(["h2", "h3", "h4", "p", "li"]):
        if el.name in ("h2", "h3", "h4"):
            section = clean(el.get_text(" ", strip=True)).lower(); continue
        if re.search(r"histor|trivia|result|poll|issue|assess|margin", section):
            continue
        tx = clean(el.get_text(" ", strip=True))
        if tx and srx.search(tx):
            if given and not re.search(r"(?<![A-Za-z])" + re.escape(given) + r"(?![A-Za-z])", tx, re.I) and len(tx) < 40:
                continue
            paras.append(tx)
    text = " || ".join(dict.fromkeys(paras))
    return bool(text), on_list or bool(text), text

# --------------------------------------------------------------------------- main
SNAP_COLS = ["election", "seat", "election_date", "url", "capture_ts", "served_ts", "status", "bytes", "page_warn", "warn_context"]
BIO_COLS = ["election", "seat", "candidate", "capture_ts", "found", "on_page_list", "bio_text", "warn", "warn_context"]
FINAL = {"ok", "no_guide", "no_pre_election_capture", "seat_not_found"}

WARN_PAGE_RX = re.compile(r"\b(\d+(\.\d+)?% counted|votes counted|has been elected|has won|winner|declared elected|is projected to win|called by abc)\b", re.I)

def ctx(tx, rx, n=15):
    """Hits and the n words either side of each match (so pre-election wording can be told from a result)."""
    hits, ctxs = set(), []
    for m in rx.finditer(tx):
        hits.add(m.group(0).lower())
        pre = tx[:m.start()].split()[-n:]
        post = tx[m.end():].split()[:n]
        ctxs.append("..." + " ".join(pre) + " [[" + m.group(0) + "]] " + " ".join(post) + "...")
    return ";".join(sorted(hits)), " || ".join(ctxs[:5])

def page_warn(html):
    soup = BeautifulSoup(html, "lxml")
    for t in soup(["script", "style"]):
        t.decompose()
    return ctx(clean(soup.get_text(" ", strip=True)), WARN_PAGE_RX)

def write_csv(path, cols, rows):
    tmp = path + ".tmp"
    with open(tmp, "w", newline="", encoding="utf8") as f:
        w = csv.DictWriter(f, cols); w.writeheader()
        for r in rows:
            w.writerow({c: r.get(c, "") for c in cols})
    os.replace(tmp, path)

def main():
    redo = "--redo-missing" in sys.argv
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    inp = list(csv.DictReader(open(INPUT, encoding="utf8")))
    cells = {}
    for r in inp:
        cells.setdefault((r["election"], r["seat"]), r["election_date"])
    snaps = {}
    if os.path.exists(SNAP):
        for r in csv.DictReader(open(SNAP, encoding="utf8")):
            snaps[(r["election"], r["seat"])] = r
    for (el, seat), pd_ in cells.items():
        if only and el != only:
            continue
        old = snaps.get((el, seat))
        rawf = os.path.join(RAW, "%s_%s.html" % (el, seat))
        if old and old["status"] in FINAL and ((old["status"] == "ok" and os.path.exists(rawf)) or (old["status"] != "ok" and not redo)):
            continue
        print("cell", el, seat, flush=True)
        if el in LIVE_ELECTIONS:
            pg, code = find_live(el, seat)
            reason = code
        else:
            pg, code, _ = find_seat_page(el, seat, pd_)
            reason = code
        if pg:
            if el in LIVE_ELECTIONS:
                assert pg["capture_ts"] >= "20260101", "live fetch time sanity"
            else:
                assert pg["served_ts"] and pg["served_ts"][:8] < polling_day_compact(pd_), \
                    "LEAK: served_ts %s not before polling day %s (%s %s)" % (pg["served_ts"], pd_, el, seat)
                assert pg["served_ts"] == pg["capture_ts"]
                if pg.get("memento_ts"):
                    assert pg["memento_ts"][:8] < polling_day_compact(pd_), "LEAK: memento " + pg["memento_ts"]
            open(rawf, "wb").write(pg["body"])
            snaps[(el, seat)] = {"election": el, "seat": seat, "election_date": pd_, "url": pg["url"],
                                 "capture_ts": pg["capture_ts"], "served_ts": pg["served_ts"], "status": "ok",
                                 "bytes": pg["bytes"]}
        else:
            snaps[(el, seat)] = {"election": el, "seat": seat, "election_date": pd_, "url": "", "capture_ts": "",
                                 "served_ts": "", "status": reason, "bytes": 0, "page_warn": ""}
        print("  ->", snaps[(el, seat)]["status"], snaps[(el, seat)]["capture_ts"], flush=True)
        write_csv(SNAP, SNAP_COLS, [snaps[k] for k in cells if k in snaps])

    # ---- final hard check on every ok row, then bios
    assert only or all(k in snaps for k in cells), "not every cell has a status yet"
    for (el, seat), r in snaps.items():
        if r["status"] == "ok" and el not in LIVE_ELECTIONS:
            assert r["served_ts"][:8] < polling_day_compact(r["election_date"]), "LEAK in snapshots.csv: %s %s" % (el, seat)
    for (el, seat), r in snaps.items():
        if r["status"] == "ok":
            r["page_warn"], r["warn_context"] = page_warn(open(os.path.join(RAW, "%s_%s.html" % (el, seat)), "rb").read())
    write_csv(SNAP, SNAP_COLS, [snaps[k] for k in cells if k in snaps])
    bio_rows = []
    for r in inp:
        s = snaps.get((r["election"], r["seat"]))
        row = {"election": r["election"], "seat": r["seat"], "candidate": r["candidate"],
               "capture_ts": "", "found": False, "on_page_list": False, "bio_text": "", "warn": ""}
        if s and s["status"] == "ok":
            html = open(os.path.join(RAW, "%s_%s.html" % (r["election"], r["seat"])), "rb").read()
            found, onl, text = extract_bio(html, r["candidate"])
            row.update(capture_ts=s["capture_ts"], found=found, on_page_list=onl, bio_text=text)
            row["warn"], row["warn_context"] = ctx(text, RESULT_RX)
        bio_rows.append(row)
    write_csv(BIOS, BIO_COLS, bio_rows)
    print("snapshots:", len(snaps), "bios:", len(bio_rows))

if __name__ == "__main__":
    main()
