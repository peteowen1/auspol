#!/usr/bin/env python
"""Parse raw Victorian council general-election results (VEC) into one tidy CSV.

Inputs (never modified): external/reference/vec/council/<year>/
  2008, 2012, 2016  one HTML page per council (sections per ward or council-wide)
  2020, 2024        one Excel (.xls) distribution report per council or ward
Output: output/council-results-vic.csv  (one row per candidate per ward; uncontested
wards carry the unopposed winner with empty votes and contested=False).

Run: python scripts/parse_vec_council.py        (exits non-zero if a check fails)

Notes
- xlrd is not installed on the dev machine and nothing is installed by this script, so the
  .xls files are read by the small pure-python OLE2/BIFF8 reader embedded below
  (shared strings, numbers, RK).  It reads only the cells this parser needs.
- Melbourne City Council's Leadership Team (Lord Mayor) contest is not a councillor
  election and is skipped.  Its Councillors contest uses group tickets: ticket votes are
  not attributable to candidates, so candidate votes there are below-the-line only and
  check 2 uses the sum of GROUP TOTAL rows instead (reported separately).
- 2020/2024 .xls reports carry no enrolment, so ward_enrolment is empty for those years.
- Wards that were uncontested in 2020/2024 have no distribution report and so no rows.
"""
import csv, hashlib, re, struct, sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "external" / "reference" / "vec" / "council"
OUT = ROOT / "output" / "council-results-vic.csv"
COLS = ["year", "council", "ward", "vacancies", "candidate", "surname", "given", "first_pref_votes",
        "first_pref_pct", "ward_formal_votes", "ward_enrolment", "elected", "contested", "source_file"]

# ----------------------------------------------------------------------------- minimal .xls reader
import struct

def ole_stream(data, want="Workbook"):
    assert data[:8] == bytes.fromhex("d0cf11e0a1b11ae1"), "not OLE2"
    ss = 1 << struct.unpack_from("<H", data, 0x1E)[0]
    mss = 1 << struct.unpack_from("<H", data, 0x20)[0]
    nfat, dirstart = struct.unpack_from("<II", data, 0x2C)
    cutoff, mfstart, nmf, difstart, ndif = struct.unpack_from("<IIIII", data, 0x38)
    sect = lambda i: data[(i + 1) * ss:(i + 2) * ss]
    difat = list(struct.unpack_from("<109I", data, 0x4C))
    d = difstart
    for _ in range(ndif):
        s = sect(d); vals = struct.unpack("<%dI" % (ss // 4), s)
        difat += vals[:-1]; d = vals[-1]
    fat = []
    for i in difat[:nfat]:
        fat += struct.unpack("<%dI" % (ss // 4), sect(i))
    def chain(start):
        out = []; i = start
        while i < 0xFFFFFFFA:
            out.append(i); i = fat[i]
        return out
    dirdata = b"".join(sect(i) for i in chain(dirstart))
    ents = []
    for k in range(len(dirdata) // 128):
        e = dirdata[k * 128:(k + 1) * 128]
        nl = struct.unpack_from("<H", e, 64)[0]
        name = e[:max(nl - 2, 0)].decode("utf-16le")
        typ = e[66]; start = struct.unpack_from("<I", e, 116)[0]; size = struct.unpack_from("<I", e, 120)[0]
        ents.append((name, typ, start, size))
    root = ents[0]
    for name, typ, start, size in ents:
        if name in (want, "Book") and typ == 2:
            if size >= cutoff:
                return b"".join(sect(i) for i in chain(start))[:size]
            mini = b"".join(sect(i) for i in chain(root[2]))[:root[3]]
            mfat = []
            for i in chain(mfstart):
                mfat += struct.unpack("<%dI" % (ss // 4), sect(i))
            out = []; i = start
            while i < 0xFFFFFFFA:
                out.append(mini[i * mss:(i + 1) * mss]); i = mfat[i]
            return b"".join(out)[:size]
    raise ValueError("no Workbook stream")

def _rk(v):
    if v & 2:
        x = float(v >> 2 if v >> 31 == 0 else (v >> 2) - (1 << 30))
        x = float(struct.unpack("<i", struct.pack("<I", v))[0] >> 2)
    else:
        x = struct.unpack("<d", struct.pack("<Q", (v & 0xFFFFFFFC) << 32))[0]
    return x / 100 if v & 1 else x

def read_xls(data):
    """Return list of (sheetname, {(row,col): value}). BIFF8 only."""
    wb = ole_stream(data)
    recs = []; p = 0
    while p + 4 <= len(wb):
        t, n = struct.unpack_from("<HH", wb, p); recs.append((t, wb[p + 4:p + 4 + n])); p += 4 + n
    # shared strings
    sst = []
    for idx, (t, pl) in enumerate(recs):
        if t == 0xFC:
            chunks = [pl]; j = idx + 1
            while j < len(recs) and recs[j][0] == 0x3C:
                chunks.append(recs[j][1]); j += 1
            nuniq = struct.unpack_from("<I", pl, 4)[0]
            ci, pos = 0, 8
            def need(n_bytes):
                pass
            for _ in range(nuniq):
                cur = chunks[ci]
                if pos >= len(cur):
                    ci += 1; pos = 0; cur = chunks[ci]
                cch, fl = struct.unpack_from("<HB", cur, pos); pos += 3
                rich = 0; ext = 0
                if fl & 8: rich = struct.unpack_from("<H", cur, pos)[0]; pos += 2
                if fl & 4: ext = struct.unpack_from("<I", cur, pos)[0]; pos += 4
                wide = fl & 1; s = []; remain = cch
                while remain:
                    cur = chunks[ci]
                    if pos >= len(cur):
                        ci += 1; pos = 0; cur = chunks[ci]
                        wide = cur[0] & 1; pos = 1
                    bpc = 2 if wide else 1
                    take = min(remain, (len(cur) - pos) // bpc)
                    seg = cur[pos:pos + take * bpc]; pos += take * bpc; remain -= take
                    s.append(seg.decode("utf-16le" if wide else "latin-1"))
                skip = rich * 4 + ext
                while skip:
                    cur = chunks[ci]
                    if pos >= len(cur):
                        ci += 1; pos = 0; cur = chunks[ci]
                    k = min(skip, len(cur) - pos); pos += k; skip -= k
                sst.append("".join(s))
            break
    sheets = []; names = []
    for t, pl in recs:
        if t == 0x85:
            nl = pl[6]; fl = pl[7]
            nm = pl[8:8 + nl * (2 if fl & 1 else 1)].decode("utf-16le" if fl & 1 else "latin-1")
            names.append(nm)
    # cells per sheet: sheets are consecutive BOF..EOF substreams after globals
    cur = None; depth = 0; si = -1; out = []
    for t, pl in recs:
        if t == 0x809:
            depth += 1
            if depth == 1:
                kind = struct.unpack_from("<H", pl, 2)[0]
                cur = None
                if kind == 0x10:  # worksheet
                    si += 1; cur = {}; out.append((names[si] if si < len(names) else str(si), cur))
                elif kind == 0x05:
                    pass
            continue
        if t == 0x0A:
            depth -= 1; continue
        if cur is None or depth != 1: continue
        if t == 0xFD:
            r, c, _x, i = struct.unpack_from("<HHHI", pl); cur[(r, c)] = sst[i]
        elif t == 0x203:
            r, c, _x = struct.unpack_from("<HHH", pl); cur[(r, c)] = struct.unpack_from("<d", pl, 6)[0]
        elif t == 0x27E:
            r, c, _x, v = struct.unpack_from("<HHHI", pl); cur[(r, c)] = _rk(v)
        elif t == 0xBD:
            r, c0 = struct.unpack_from("<HH", pl); n = (len(pl) - 6) // 6
            for k in range(n):
                v = struct.unpack_from("<I", pl, 4 + k * 6 + 2)[0]; cur[(r, c0 + k)] = _rk(v)
        elif t == 0x204:
            r, c, _x, ln = struct.unpack_from("<HHHH", pl)
            fl = pl[8]; cur[(r, c)] = pl[9:9 + ln * (2 if fl & 1 else 1)].decode("utf-16le" if fl & 1 else "latin-1")
        elif t == 0x06:
            r, c, _x = struct.unpack_from("<HHH", pl)
            if pl[12:14] != b"\xff\xff": cur[(r, c)] = struct.unpack_from("<d", pl, 6)[0]
    return out


# ----------------------------------------------------------------------------- shared helpers
def norm(s):
    return re.sub(r"\s+", " ", (s or "").replace("\xa0", " ")).strip()


def key(s):
    return norm(s).casefold()


def split_name(full):
    full = norm(full)
    if ", " in full:
        sur, giv = full.split(", ", 1)
        return sur, giv
    return full, ""


def key2(s):
    return re.sub(r"\s+", "", key(s))


def to_int(s):
    s = norm(s).replace(",", "")
    return int(s) if re.fullmatch(r"\d+", s) else None


def mkrow(year, council, ward, vac, cand, formal, enrol, elected, contested, src, votes=None):
    sur, giv = split_name(cand)
    pct = round(100.0 * votes / formal, 4) if (votes is not None and formal) else None
    return dict(year=year, council=council, ward=ward, vacancies=vac, candidate=norm(cand), surname=sur,
                given=giv, first_pref_votes=votes, first_pref_pct=pct, ward_formal_votes=formal,
                ward_enrolment=enrol, elected=bool(elected), contested=bool(contested), source_file=src)


# ----------------------------------------------------------------------------- HTML (2008, 2012, 2016)
from lxml import html as LH

HEAD_RE = re.compile(
    r'(?:<h3[^>]*>|<div class="GreenModuleHeaderFW">)((?:(?!</h3>|</div>).)*?\(\s*(\d+)\s+vacanc(?:y|ies)\s*\)(?:(?!</h3>|</div>).)*)(?:</h3>|</div>)',
    re.S)
TABLE_RE = re.compile(r'<table[^>]*title="([^"]*)"[^>]*>.*?</table>', re.S)
ELECTED_SUFFIX = re.compile(r"\s*\((?:\d+(?:st|nd|rd|th)\s+elected|Unopposed)\)\s*$", re.I)


def read_html(path):
    b = path.read_bytes()
    try:
        return b.decode("utf-8")
    except UnicodeDecodeError:
        return b.decode("cp1252", errors="replace")


def parse_html(path, year, log):
    t = read_html(path)
    m = re.search(r"<h2[^>]*>(.*?)</h2>", t, re.S)
    h2 = norm(re.sub(r"<[^>]+>", "", m.group(1))) if m else ""
    council = re.sub(r"^Results for\s+", "", h2)
    council = re.sub(r"\s+(Elections?|election results)\s*(" + str(year) + r")?\s*$", "", council).strip()
    council = norm(council.replace("\ufffd", " "))
    if not re.search(r"Council|Shire|Rural City|Borough", council):
        log.append(f"{path.name}: odd council name {council!r} from h2 {h2!r}")
    heads = list(HEAD_RE.finditer(t))
    rows, secs = [], []
    if not heads:
        log.append(f"{path.name}: NO sections found")
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(t)
        chunk = t[h.end():end]
        name = norm(re.sub(r"<[^>]+>", "", h.group(1)))
        name = norm(re.sub(r"\(\s*\d+\s+vacanc(?:y|ies)\s*\)", "", name))
        vac = int(h.group(2))
        ward = "" if (key(name) == key(council) or key(name) == "councillors") else name
        elected, summ, fp, ngroup, fpcount, gt = [], {}, [], 0, 0, 0
        for tm in TABLE_RE.finditer(chunk):
            title = tm.group(1)
            tb = LH.fromstring(tm.group(0))
            if title == "Successful candidates":
                for tr in tb.xpath(".//tr"):
                    if tr.xpath("./th") and tr.xpath("./td"):
                        txt = norm(tr.xpath("./td")[0].text_content())
                        elected.append(norm(ELECTED_SUFFIX.sub("", txt)))
            elif title == "Election results summary":
                for tr in tb.xpath(".//tr"):
                    th, td = tr.xpath("./th"), tr.xpath("./td")
                    if th and td:
                        k = key(th[0].text_content()).rstrip(":")
                        mm = re.match(r"[\d,]+", norm(td[0].text_content()))
                        if mm:
                            summ[k] = int(mm.group(0).replace(",", ""))
            elif title == "First preference votes":
                fpcount += 1
                if fpcount > 1:
                    log.append(f"{path.name} [{ward or council}]: more than one first-preference table; first used")
                    continue
                for tr in tb.xpath(".//tr"):
                    tds = tr.xpath("./td")
                    if not tds:
                        continue
                    texts = [norm(td.text_content()) for td in tds]
                    if tr.xpath(".//td//b"):
                        if texts and re.fullmatch(r"GROUP TOTAL", texts[0], re.I):
                            v = [to_int(x) for x in texts if to_int(x) is not None]
                            if v:
                                gt += v[-1]; ngroup += 1
                        continue
                    nz = [j for j, x in enumerate(texts) if x]
                    if not nz:
                        continue
                    name_i = nz[0]
                    votes = None
                    for x in texts[name_i + 1:]:
                        if to_int(x) is not None:
                            votes = to_int(x); break
                    if votes is None or to_int(texts[name_i]) is not None:
                        log.append(f"{path.name} [{ward or council}]: unparsed FP row {texts}")
                        continue
                    fp.append((texts[name_i], votes))
        formal, enrol = summ.get("formal votes"), summ.get("enrolment")
        secs.append(dict(council=council, ward=ward, vac=vac, formal=formal, group_total=gt if ngroup else None,
                         n_fp=len(fp), n_elected=len(elected), src=path.name))
        if not fp:
            if not elected:
                nonom = re.search(r"no nominations were received", chunk, re.I)
                log.append(f"{path.name} [{ward or council}]: {'NO NOMINATIONS received (vacancy unfilled, no rows)' if nonom else 'no FP table and no elected candidates'}")
                secs[-1]["no_nominations"] = bool(nonom)
            for e in elected:
                rows.append(mkrow(year, council, ward, vac, e, None, None, True, False, path.name))
            continue
        ek = {key2(e) for e in elected}
        seen = set()
        for cand, votes in fp:
            seen.add(key2(cand))
            rows.append(mkrow(year, council, ward, vac, cand, formal, enrol, key2(cand) in ek, True, path.name, votes))
        for e in elected:
            if key2(e) not in seen:
                log.append(f"{path.name} [{ward or council}]: elected {e!r} not among first-preference candidates")
                rows.append(mkrow(year, council, ward, vac, e, formal, enrol, True, True, path.name))
    return rows, secs


# ----------------------------------------------------------------------------- XLS (2020, 2024)
def parse_xls(path, year, log, data=None):
    data = data if data is not None else path.read_bytes()
    sheets = read_xls(data)
    if not sheets:
        raise ValueError("no worksheet")
    c = sheets[0][1]
    rmax = max(r for r, _ in c)
    cell = lambda r, k: c.get((r, k))
    txt = lambda r, k=0: norm(cell(r, k)) if isinstance(cell(r, k), str) else ""
    if txt(1, 1).startswith("First Preference Vote Count Manual Results"):
        return parse_manual_xls(path, year, c, txt, cell, rmax, log)
    m = re.match(r"^(.*?)\s+(\d{4})$", txt(2))
    if not m or int(m.group(2)) != year:
        raise ValueError(f"row 2 {txt(2)!r} does not give council + {year}")
    council = m.group(1)
    ward_raw = txt(3)
    ward = "" if (key(ward_raw) == key(council) or key(ward_raw) == "councillors") else ward_raw
    pd = re.search(r"(\d\d/\d\d/\d{4} \d\d:\d\d:\d\d[AP]M)", txt(1))
    printed = datetime.strptime(pd.group(1), "%d/%m/%Y %I:%M:%S%p") if pd else datetime.min
    head0 = txt(0)
    if "leadership" in (ward_raw + path.name).lower():
        return None, dict(skip="leadership team", council=council, ward=ward, printed=printed)
    stated_formal = vac = None
    cands, elected_text, fp = [], [], {}
    if head0.startswith("Distribution Report"):  # multi-vacancy proportional count
        for r in range(0, 12):
            mm = re.match(r"Election of (\d+) Councillor", txt(r))
            if mm: vac = int(mm.group(1))
            mm = re.match(r"Formal Ballot Papers included in count:\s*([\d,]+)", txt(r))
            if mm: stated_formal = int(mm.group(1).replace(",", ""))
        hr = next(r for r in range(0, 30) if txt(r).startswith("Count") and txt(r, 1) == "Count Details")
        k = 5
        while True:
            h = txt(hr, k)
            if h in ("Gain/Loss", "Exhausted", "TOTAL"):
                break
            if h:
                cands.append((k, h))
            k += 1
            if k > 200: raise ValueError("no end of candidate header")
        tot_col = next(k for k in range(5, 200) if txt(hr, k) == "TOTAL")
        fr = next(r for r in range(hr, hr + 6) if txt(r, 1) == "1st Preferences")
        fp = {h: cell(fr, k) for k, h in cands}
        total = cell(fr, tot_col)
        ecol = next(k for k in range(tot_col, tot_col + 5) if "elected" in txt(hr, k).lower())
        for r in range(hr + 1, rmax + 1):
            if isinstance(cell(r, ecol), str):
                elected_text.append(cell(r, ecol))
    elif head0.startswith("Distribution of Preference Votes"):  # single-vacancy preferential count
        vac = 1
        for r in range(0, 9):
            mm = re.match(r"Total Valid first preference votes polled for all candidates\s*([\d,]+)\s*$", txt(r))
            if mm: stated_formal = int(mm.group(1).replace(",", ""))
        hr = next(r for r in range(0, 20) if txt(r).startswith("Candidates Names"))
        tot_col = next(k for k in range(1, 200) if txt(hr, k) == "TOTAL")
        cands = [(k, txt(hr, k)) for k in range(1, tot_col) if txt(hr, k)]
        fr = next(r for r in range(hr, hr + 4) if txt(r).startswith("Total first preference votes"))
        fp = {h: cell(fr, k) for k, h in cands}
        total = cell(fr, tot_col)
        for r in range(fr, rmax + 1):
            mm = re.match(r"Name of (?:Successful|Elected) Candidate:\s*(.+)$", txt(r))
            if mm: elected_text.append(mm.group(1))
    else:
        raise ValueError(f"unknown layout, row 0 = {head0!r}")
    miss = [h for h, v in fp.items() if v is None]
    if miss:
        log.append(f"{path.name}: blank first-preference cell treated as 0 for {miss}")
    votes = {h: int(round(v)) if v is not None else 0 for h, v in fp.items()}
    if len(votes) != len(cands):
        raise ValueError("duplicate candidate headers")
    formal = stated_formal if stated_formal is not None else int(round(total))
    # elected: names contain commas so the joined text cannot be split on them; match known candidates
    joined = ", ".join(norm(x) for x in elected_text)
    el = {h for _, h in cands if re.search(r"(?:^|, )" + re.escape(norm(h)) + r"(?=,\s|$)", joined)}
    rows = [mkrow(year, council, ward, vac, h, formal, None, h in el, True, path.name, votes[h]) for _, h in cands]
    sec = dict(council=council, ward=ward, vac=vac, formal=formal, group_total=None, n_fp=len(rows),
               n_elected=len(el), src=path.name, printed=printed,
               formal_src="stated" if stated_formal is not None else "TOTAL column")
    return rows, sec


def parse_manual_xls(path, year, c, txt, cell, rmax, log):
    """Pyrenees 2020: two wards counted manually; only candidate + votes, no elected list, no formal total."""
    m = re.match(r"^(.*?)\s+(\d{4})$", txt(3, 1))
    council, ward = m.group(1), txt(5, 1)
    ward = "" if key(ward) == key(council) else ward
    hr = next(r for r in range(0, 20) if txt(r, 2) == "Candidate Name")
    cands = []
    for r in range(hr + 1, rmax + 1):
        if txt(r, 2) and txt(r, 2).lower() != "total" and isinstance(cell(r, 3), float):
            cands.append((txt(r, 2), int(round(cell(r, 3)))))
    tot = next((int(cell(r, 3)) for r in range(hr + 1, rmax + 1) if txt(r, 2).lower() == "total"), None)
    top = max(v for _, v in cands)
    log.append(f"{path.name}: manual-count layout; vacancies assumed 1 and winner inferred as top vote-getter "
               f"({[n for n, v in cands if v == top]}); the file states neither")
    rows = [mkrow(year, council, ward, 1, n, tot, None, v == top, True, path.name, v) for n, v in cands]
    sec = dict(council=council, ward=ward, vac=1, formal=tot, group_total=None, n_fp=len(rows),
               n_elected=sum(1 for n, v in cands if v == top), src=path.name, printed=datetime.min, formal_src="Total row")
    return rows, sec


def parse_all_xls(year, log):
    files = sorted((SRC / str(year)).glob("*.xls"))
    byhash, kept, notes = {}, {}, []
    for f in files:
        data = f.read_bytes()
        h = hashlib.md5(data).hexdigest()
        if h in byhash:
            notes.append(f"{year}: exact duplicate skipped: {f.name} == {byhash[h]}")
            continue
        byhash[h] = f.name
        try:
            rows, sec = parse_xls(f, year, log, data)
        except Exception as e:  # reported, never swallowed
            log.append(f"{year}: UNPARSED {f.name}: {type(e).__name__}: {e}")
            continue
        if rows is None:
            notes.append(f"{year}: skipped {f.name} ({sec['skip']})")
            continue
        kept.setdefault((sec["council"], sec["ward"]), []).append((f.name, rows, sec))
    allrows, secs = [], []
    for k, lst in kept.items():
        if len(lst) > 1:
            lst.sort(key=lambda x: (("recount" in x[0].lower()), x[2]["printed"], x[0]))
            notes.append(f"{year}: {k} has {len(lst)} differing reports {[x[0] for x in lst]}; kept {lst[-1][0]} "
                         f"(recount, else latest print date)")
        n, rows, sec = lst[-1]
        allrows += rows; secs.append(sec)
    return allrows, secs, notes


# ----------------------------------------------------------------------------- checks
def check_formal(secs, tol=0.005):
    """Per ward: sum of first-pref votes vs formal votes. Returns (passes, fails, no-source)."""
    passes, fails, nosrc = [], [], []
    for s in secs:
        if s["n_fp"] == 0:
            continue
        tgt = s["formal"]
        if tgt is None:
            nosrc.append(s); continue
        got = s["group_total"] if s.get("group_total") is not None else s["sum_votes"]
        s["diff"] = abs(got - tgt) / max(tgt, 1)
        (passes if s["diff"] <= tol else fails).append(s)
    return passes, fails, nosrc


def main():
    import copy
    log, notes, allrows, allsecs = [], [], [], []
    for year in (2008, 2012, 2016):
        for f in sorted((SRC / str(year)).glob("*.html")):
            rows, secs = parse_html(f, year, log)
            for s in secs: s["year"] = year
            allrows += rows; allsecs += secs
    for year in (2020, 2024):
        rows, secs, nn = parse_all_xls(year, log)
        for s in secs: s["year"] = year
        allrows += rows; allsecs += secs; notes += nn
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS); w.writeheader()
        for r in allrows:
            w.writerow({k: ("" if r[k] is None else r[k]) for k in COLS})
    sums = {}
    for r in allrows:
        if r["first_pref_votes"] is not None:
            k = (r["year"], r["council"], r["ward"])
            sums[k] = sums.get(k, 0) + r["first_pref_votes"]
    for s in allsecs:
        s["sum_votes"] = sums.get((s["year"], s["council"], s["ward"]), 0)
    fail = False
    print(f"wrote {OUT} ({len(allrows)} rows)")
    print("\n== 1. Coverage per year")
    for y in (2008, 2012, 2016, 2020, 2024):
        rs = [r for r in allrows if r["year"] == y]; ss = [s for s in allsecs if s["year"] == y]
        print(f"  {y}: rows={len(rs)} councils={len({r['council'] for r in rs})} wards/contests={len(ss)} "
              f"(named wards={sum(1 for s in ss if s['ward'])}) uncontested={sum(1 for s in ss if s['n_fp'] == 0)}")
    print("\n== 2. Sum of first-pref votes vs ward formal votes (tolerance 0.5%)")
    for y in (2008, 2012, 2016, 2020, 2024):
        ss = [s for s in allsecs if s["year"] == y]
        p, f_, n = check_formal(ss)
        print(f"  {y}: pass={len(p)} fail={len(f_)} no-formal-total={len(n)}")
        for s in sorted(p + f_, key=lambda s: -s["diff"])[:5]:
            tgt = s["formal"]
            print(f"      worst: {s['council']} / {s['ward'] or '-'}: sum={s['group_total'] if s.get('group_total') is not None else s['sum_votes']} formal={tgt} "
                  f"diff={100 * s['diff']:.3f}%" + (" (vs group totals)" if s.get("group_total") is not None else ""))
        for s in n:
            print(f"      no formal total: {s['council']} / {s['ward'] or '-'} sum={s['sum_votes']}")
        if f_: fail = True
    test = [s for s in copy.deepcopy(allsecs) if s["n_fp"] and s["formal"] and s.get("group_total") is None]
    _, base_f, _ = check_formal(copy.deepcopy(test))
    test[0]["sum_votes"] = int(test[0]["sum_votes"] * 1.10) + 5
    _, pert_f, _ = check_formal(test)
    ok = len(pert_f) == len(base_f) + 1
    print(f"  self-test (in memory): fails before={len(base_f)}, after inflating one ward's sum 10%={len(pert_f)} "
          f"-> {'detected' if ok else 'NOT DETECTED'}")
    fail |= not ok
    print("\n== 3. Elected count vs vacancies")
    nonom = [s for s in allsecs if s.get("no_nominations")]
    bad = [s for s in allsecs if s["n_elected"] != s["vac"] and not s.get("no_nominations")]
    for s in nonom:
        print(f"  (not a mismatch) no nominations received: {s['year']} {s['council']} / {s['ward']}: vacancies={s['vac']}")
    print(f"  mismatches: {len(bad)} of {len(allsecs)}")
    for s in bad:
        print(f"      {s['year']} {s['council']} / {s['ward'] or '-'}: vacancies={s['vac']} elected={s['n_elected']} ({s['src']})")
    fail |= bool(bad)
    print("\n== 4. Negative votes / duplicate keys")
    neg = [r for r in allrows if r["first_pref_votes"] is not None and r["first_pref_votes"] < 0]
    seen, dup = set(), []
    for r in allrows:
        k = (r["year"], r["council"], r["ward"], key(r["candidate"]))
        if k in seen: dup.append(k)
        seen.add(k)
    print(f"  negative={len(neg)} duplicates={len(dup)} {dup[:5]}")
    fail |= bool(neg or dup)
    print("\n== Notes (duplicates, skips)")
    for n in notes: print("  " + n)
    print("\n== Parser log (unparsed or odd)")
    for l in log: print("  " + l)
    if not log: print("  none")
    fail |= any("UNPARSED" in l for l in log)
    print("\n== Spot check: surname SHEED")
    for r in allrows:
        if r["surname"].upper() == "SHEED":
            print(f"  {r['year']} {r['council']} / {r['ward'] or '-'}: {r['candidate']} votes={r['first_pref_votes']} "
                  f"pct={r['first_pref_pct']} elected={r['elected']}")
    print("\nRESULT:", "FAIL" if fail else "PASS")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
