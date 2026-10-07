#!/usr/bin/env python
"""Fetch PRE-ELECTION Wikipedia revisions for the successor-flag coding (prereg Amendment 2).

Leakage rule: every page is read at its LAST REVISION STRICTLY BEFORE POLLING DAY, via the
MediaWiki API with rvdir=older and rvstart = 23:59:59 UTC on the day before polling day.
The revision timestamp is stored and ASSERTED (date part < polling day) for every saved
revision; the script stops if it ever fails.  If the page had no revision before polling day
the status is no_revision.  No title is ever searched: pages are reached only by the standard
title forms (seat article, candidates-list article) or by a wikilink found in the pre-election
text of the seat article or of the seat's row in the candidates list.

Note: the cap (23:59:59 UTC the day before) is 09:59-10:59 local on polling day in eastern
Australia (ahead of the 08:00 poll opening), as the prereg specifies; the asserted bound is the
polling DAY in UTC.

Inputs : external/reference/successors/coding-input.csv   (nothing else is read)
Outputs: external/reference/successors/wikipedia-raw/<election>_<seat>__<kind>__<title>.wikitext
         external/reference/successors/wikipedia-revisions.csv
         external/reference/successors/wikipedia-text.csv
Resumable: a cell whose rows are all in wikipedia-text.csv is skipped; CSVs are rewritten
after every cell.   Run: python scripts/fetch_wikipedia_preelection.py [--only fed2022] [--redo]
"""
import csv, datetime, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     "..", "external", "reference", "successors"))
RAW = os.path.join(ROOT, "wikipedia-raw")
INPUT = os.path.join(ROOT, "coding-input.csv")
REVS = os.path.join(ROOT, "wikipedia-revisions.csv")
TEXT = os.path.join(ROOT, "wikipedia-text.csv")
os.makedirs(RAW, exist_ok=True)

API = "https://en.wikipedia.org/w/api.php"
UA = "auspol-research (fptpost@gmail.com)"
MIN_GAP = 1.1
_last = [0.0]

REV_COLS = ["election", "seat", "election_date", "kind", "title", "candidate", "revid",
            "rev_timestamp", "status", "bytes"]
TEXT_COLS = ["election", "seat", "candidate", "seat_text", "list_text", "candidate_text",
             "sources", "warn"]

STATE = {"nsw": "New South Wales", "vic": "Victoria", "qld": "Queensland",
         "sa": "South Australia", "wa": "Western Australia"}
LIST_TITLE = {"fed": "Candidates of the {y} Australian federal election",
              "nsw": "Candidates of the {y} New South Wales state election",
              "vic": "Candidates of the {y} Victorian state election",
              "qld": "Candidates of the {y} Queensland state election",
              "sa": "Candidates of the {y} South Australian state election",
              "wa": "Candidates of the {y} Western Australian state election"}
WARN_RE = re.compile(r"\b(elected|won|defeated|results?|swing|margin)\b", re.I)


# ---------------------------------------------------------------- API
def api(params):
    params = dict(params, format="json", formatversion="2")
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(6):
        wait = MIN_GAP - (time.time() - _last[0])
        if wait > 0:
            time.sleep(wait)
        _last[0] = time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(5 * (attempt + 1))
                continue
            raise
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            time.sleep(5 * (attempt + 1))
    raise RuntimeError("API failed repeatedly: " + url)


def cap_for(election_date):
    d = datetime.date.fromisoformat(election_date) - datetime.timedelta(days=1)
    return d.isoformat() + "T23:59:59Z"


def is_dab(content):
    head = content[:3000]
    return bool(re.search(r"\{\{\s*(disambiguation|disambig|dab|geodis|hndis|set index)", head, re.I)
                or re.search(r"\bmay refer to\b", head[:600], re.I))


def fetch_rev(title, election_date, hops=0):
    """Pre-election revision of one title. Returns dict(status,title,revid,ts,content)."""
    d = api({"action": "query", "prop": "revisions", "titles": title, "rvlimit": 1,
             "rvdir": "older", "rvstart": cap_for(election_date), "rvprop": "ids|timestamp|content",
             "rvslots": "main", "redirects": 1})
    pages = d.get("query", {}).get("pages", [])
    if not pages or pages[0].get("missing") or pages[0].get("invalid"):
        return {"status": "not_found", "title": title, "revid": "", "ts": "", "content": ""}
    p = pages[0]
    revs = p.get("revisions") or []
    if not revs:
        return {"status": "no_revision", "title": p["title"], "revid": "", "ts": "", "content": ""}
    r = revs[0]
    content = r["slots"]["main"]["content"]
    ts = r["timestamp"]
    assert ts[:10] < election_date, "LEAK: revision %s of %r at %s is not before %s" % (
        r["revid"], p["title"], ts, election_date)
    m = re.match(r"\s*#redirect\s*\[\[([^\]|#]+)", content, re.I)
    if m and hops < 3:  # redirect as it stood pre-election
        return fetch_rev(m.group(1).strip(), election_date, hops + 1)
    return {"status": "ok", "title": p["title"], "revid": r["revid"], "ts": ts, "content": content}


# ---------------------------------------------------------------- wikitext -> text
def _template(m):
    inner = m.group(1)
    parts = inner.split("|")
    name = parts[0].strip().lower()
    args = [a.split("=", 1)[-1] if "=" in a and not a.strip().startswith("[[") else a for a in parts[1:]]
    if name in ("nowrap", "small", "lang", "ill", "interlanguage link", "ill-wd", "tooltip", "abbr"):
        return args[0] if args else ""
    if name in ("sortname", "sort name"):
        return " ".join(a for a in args[:2] if a)
    if name in ("age", "dts", "start date", "birth date", "birth date and age"):
        return " ".join(a for a in args if a)
    return ""


def strip_markup(wt, keep_tables=False):
    s = re.sub(r"<!--.*?-->", "", wt, flags=re.S)
    s = re.sub(r"<ref[^>/]*/>", "", s)
    s = re.sub(r"<ref[^>]*>.*?</ref>", "", s, flags=re.S)
    if not keep_tables:
        prev = None
        while prev != s:
            prev = s
            s = re.sub(r"\{\|(?:(?!\{\|).)*?\|\}", "", s, flags=re.S)
    prev = None
    while prev != s:
        prev = s
        s = re.sub(r"\{\{([^{}]*)\}\}", _template, s)
    s = re.sub(r"\[\[(?:File|Image|Category):[^\[\]]*(?:\[\[[^\]]*\]\][^\[\]]*)*\]\]", "", s, flags=re.I)
    s = re.sub(r"\[\[([^\]|]*)\|([^\]]*)\]\]", r"\2", s)
    s = re.sub(r"\[\[([^\]]*)\]\]", r"\1", s)
    s = re.sub(r"\[https?://[^\s\]]+\s*([^\]]*)\]", r"\1", s)
    s = re.sub(r"'{2,}", "", s)
    s = re.sub(r"</?[a-zA-Z][^>]*>", " ", s)
    s = re.sub(r"^=+\s*(.*?)\s*=+\s*$", r"\1.", s, flags=re.M)
    s = re.sub(r"^[*#:;]+\s*", "", s, flags=re.M)
    return s


def squash(s):
    return re.sub(r"\s+", " ", s).strip()


def row_to_text(chunk):
    """Candidates-list table row (raw wikitext) -> 'cell | cell | ...'."""
    s = strip_markup(chunk, keep_tables=True)
    s = re.sub(r"^\s*\|-.*$", "", s, flags=re.M)
    cells = re.split(r"\n\s*[|!](?!\})|\|\||!!", "\n" + s)
    out = []
    for c in cells:
        c = c.strip()
        c = re.sub(r'^(?:[A-Za-z-]+\s*=\s*(?:"[^"]*"|\S+)\s*)+\|(?!\|)', "", c).strip()
        c = squash(c)
        if c and c != "|":
            out.append(c)
    return " | ".join(out)


# ---------------------------------------------------------------- names
def name_parts(full):
    words = full.replace(",", " ").split()
    sur = [w for w in words if re.search(r"[A-Z]{2,}", w)]
    if not sur:
        sur = words[-1:]
    given = [w for w in words if w not in sur]
    return [w.lower() for w in sur], [w.lower() for w in given]


def link_matches(text, sur, given):
    t = text.lower()
    if not all(re.search(r"\b" + re.escape(x) + r"\b", t) for x in sur):
        return False
    if not given:
        return True
    toks = re.findall(r"[a-z'\-]+", t)
    for g in given:
        for tk in toks:
            if tk == g or (len(g) >= 3 and len(tk) >= 3 and (tk.startswith(g) or g.startswith(tk))):
                return True
        if re.search(r"\b" + re.escape(g[0]) + r"\.?\s", t):  # initial
            return True
    return False


LINK_RE = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]*))?\]\]")


def links_in(wt):
    out = []
    for m in LINK_RE.finditer(wt):
        tgt = m.group(1).strip()
        if re.match(r"(file|image|category|wikipedia|template|help|portal|talk|special|user):", tgt, re.I):
            continue
        out.append((tgt, (m.group(2) or tgt).strip()))
    return out


def find_candidate_link(cand, sources):
    """sources: list of raw wikitext strings in priority order. First matching link target."""
    sur, given = name_parts(cand)
    for wt in sources:
        for tgt, disp in links_in(wt):
            for t in (disp, re.sub(r"\s*\([^)]*\)\s*$", "", tgt)):
                if link_matches(t, sur, given):
                    return tgt
    return None


# ---------------------------------------------------------------- extraction
def seat_rows(list_wt, seat):
    """Raw wikitext of the seat's row(s)/section in the candidates list."""
    pat = r"\b" + re.escape(seat) + r"\b"
    rows = []
    for chunk in re.split(r"\n\|-[^\n]*", list_wt):
        chunk = re.split(r"\n\|\}", chunk, maxsplit=1)[0]  # last row of a table ends at |}
        body = chunk.lstrip("\n")
        first = re.split(r"\n\s*[|!]|\|\||!!", re.sub(r"^\s*[|!]", "", body, count=1), maxsplit=1)[0]
        first_plain = strip_markup(first, keep_tables=True)
        if re.search(pat, first_plain) and len(chunk) < 6000 and "{|" not in chunk:
            rows.append(chunk.strip())
    if rows:
        return rows
    # section fallback
    m = re.search(r"^(=+)\s*(?:\[\[[^\]]*\|)?" + re.escape(seat) + r"(?:\]\])?\s*\1\s*$", list_wt, re.M)
    if m:
        lvl = len(m.group(1))
        rest = list_wt[m.end():]
        n = re.search(r"^={1,%d}[^=].*$" % lvl, rest, re.M)
        return [rest[:n.start()] if n else rest[:4000]]
    return []


def section_texts(wt, wanted=("career", "early life", "political career")):
    """Lead + sections whose heading contains a wanted phrase (plain text)."""
    heads = list(re.finditer(r"^(=+)\s*(.*?)\s*\1\s*$", wt, re.M))
    lead = wt[:heads[0].start()] if heads else wt
    out = [squash(strip_markup(lead))]
    for i, h in enumerate(heads):
        title = h.group(2).lower()
        if any(w in title for w in wanted):
            end = len(wt)
            for h2 in heads[i + 1:]:
                if len(h2.group(1)) <= len(h.group(1)):
                    end = h2.start()
                    break
            out.append(squash(strip_markup(wt[h.end():end])))
    return " ".join(x for x in out if x)


def sentences_with(plain, names):
    sents = re.split(r"(?<=[.!?])\s+(?=[A-Z\"'])", squash(plain))
    keep = []
    for s in sents:
        low = s.lower()
        if any(re.search(r"\b" + re.escape(n) + r"\b", low) for n in names if n):
            keep.append(s)
    return " | ".join(keep)


def warn_snips(label, text, out):
    words = text.split()
    for i, w in enumerate(words):
        if WARN_RE.fullmatch(re.sub(r"^\W+|\W+$", "", w)):
            ctx = " ".join(words[max(0, i - 15): i + 16])
            out.append("%s[%s]: %s" % (label, w, ctx))


# ---------------------------------------------------------------- IO
def safe(s):
    return re.sub(r"\s+", "_", re.sub(r"[^\w\- ]", "_", s)).strip("_")


def save_raw(election, seat, kind, title, content):
    fn = "%s_%s__%s__%s.wikitext" % (election, safe(seat), kind, safe(title))
    with open(os.path.join(RAW, fn), "w", encoding="utf-8", newline="") as f:
        f.write(content)


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path, cols, rows):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    os.replace(tmp, path)


# ---------------------------------------------------------------- per cell
_cache = {}


def cached_rev(title, date):
    k = (title, date)
    if k not in _cache:
        _cache[k] = fetch_rev(title, date)
    return _cache[k]


def seat_title_forms(election, seat):
    kind = re.match(r"[a-z]+", election).group(0)
    if kind == "fed":
        return ["Division of %s" % seat, "Division of %s (Australian electoral division)" % seat]
    return ["Electoral district of %s (%s)" % (seat, STATE[kind]),
            "Electoral district of %s" % seat]


def resolve_seat(election, seat, date):
    kind = re.match(r"[a-z]+", election).group(0)
    best = None
    for t in seat_title_forms(election, seat):
        r = cached_rev(t, date)
        if r["status"] == "ok":
            head = r["content"][:4000].lower()
            if is_dab(r["content"]):
                continue
            if kind != "fed" and STATE[kind].lower() not in head:
                continue
            return r
        if r["status"] == "no_revision" and best is None:
            best = r
    return best or {"status": "not_found", "title": seat_title_forms(election, seat)[-1],
                    "revid": "", "ts": "", "content": ""}


def do_cell(election, date, seat, input_rows):
    kind = re.match(r"[a-z]+", election).group(0)
    year = re.search(r"\d{4}", election).group(0)
    rev_rows = []

    def add(kd, r, cand=""):
        rev_rows.append({"election": election, "seat": seat, "election_date": date, "kind": kd,
                         "title": r["title"], "candidate": cand, "revid": r["revid"],
                         "rev_timestamp": r["ts"], "status": r["status"],
                         "bytes": len(r["content"].encode("utf-8")) if r["status"] == "ok" else ""})
        if r["status"] == "ok":
            assert r["ts"][:10] < date
            save_raw(election, seat, kd, r["title"], r["content"])

    seat_r = resolve_seat(election, seat, date)
    add("seat", seat_r)
    list_r = cached_rev(LIST_TITLE[kind].format(y=year), date)
    add("candidates_list", list_r)

    seat_wt = seat_r["content"] if seat_r["status"] == "ok" else ""
    list_wt = list_r["content"] if list_r["status"] == "ok" else ""
    rows_raw = seat_rows(list_wt, seat) if list_wt else []
    list_row_wt = "\n".join(rows_raw)
    list_text = squash(" || ".join(row_to_text(r) for r in rows_raw))[:4000]
    seat_plain = strip_markup(seat_wt) if seat_wt else ""

    text_rows = []
    for ir in input_rows:
        cand = ir["candidate"]
        csur, _ = name_parts(cand)
        dsur, _ = name_parts(ir["departed_member"])
        seat_text = sentences_with(seat_plain, csur + dsur)
        sources = []
        if seat_r["status"] == "ok":
            sources.append("seat:%s" % seat_r["revid"])
        if list_r["status"] == "ok":
            sources.append("list:%s" % list_r["revid"])
        cand_text = ""
        tgt = find_candidate_link(cand, [seat_wt, list_row_wt])
        if tgt:
            cr = cached_rev(tgt, date)
            if cr["status"] == "ok" and is_dab(cr["content"]):
                cr = dict(cr, status="not_found", content="", revid="", ts="")
            add("candidate", cr, cand)
            if cr["status"] == "ok":
                cand_text = section_texts(cr["content"])
                sources.append("candidate:%s" % cr["revid"])
        warns = []
        warn_snips("seat_text", seat_text, warns)
        warn_snips("list_text", list_text, warns)
        warn_snips("candidate_text", cand_text, warns)
        text_rows.append({"election": election, "seat": seat, "candidate": cand,
                          "seat_text": seat_text, "list_text": list_text,
                          "candidate_text": cand_text, "sources": ";".join(sources),
                          "warn": " || ".join(warns)})
    return rev_rows, text_rows


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    redo = "--redo" in sys.argv
    inp = read_csv(INPUT)
    assert len(inp) == 143, "coding-input.csv row count %d != 143" % len(inp)
    cells = {}
    for r in inp:
        cells.setdefault((r["election"], r["seat"]), (r["election_date"], []))[1].append(r)
    revs = [] if redo else read_csv(REVS)
    texts = [] if redo else read_csv(TEXT)
    done = {(t["election"], t["seat"]) for t in texts}
    todo = [(k, v) for k, v in cells.items() if k not in done and (only is None or k[0] == only)]
    print("cells total %d, done %d, to do %d" % (len(cells), len(done), len(todo)), flush=True)
    for n, ((election, seat), (date, rows)) in enumerate(todo, 1):
        rv, tx = do_cell(election, date, seat, rows)
        revs = [r for r in revs if (r["election"], r["seat"]) != (election, seat)] + rv
        texts = [t for t in texts if (t["election"], t["seat"]) != (election, seat)] + tx
        write_csv(REVS, REV_COLS, revs)
        write_csv(TEXT, TEXT_COLS, texts)
        print("[%d/%d] %s %s: %s" % (n, len(todo), election, seat,
                                     ", ".join("%s=%s" % (r["kind"], r["status"]) for r in rv)), flush=True)
    # completeness
    nrev = {(r["election"], r["seat"]) for r in revs}
    assert all(c in nrev for c in cells) or only, "some cells have no revisions rows"
    for r in revs:
        if r["status"] == "ok":
            assert r["rev_timestamp"][:10] < r["election_date"], "LEAK in saved row: %s" % r


if __name__ == "__main__":
    main()
