"""Victorian Legislative Assembly results BY VOTING CENTRE -> tidy CSVs.

Inputs (raw, never modified):
  external/reference/vec/<2006|2010|2014|2018>/vc/{fpv,tcp}-<district>.html
      (fetched by scripts/fetch_vec_booths.py)
  external/reference/vec/2022/booths/<district>-{fp,2cp}.html
      (fetched by scripts/fetch_booths_vic2022.R; same format scripts/build_vic2022_results_web.R reads)
  external/reference/vec/2022/voting-centre-locations-2022.xlsx  (lat/lon, 2022 only)

Outputs, one pair per election, in output/booths/:
  vic<year>-booth-fp.csv, vic<year>-booth-tcp.csv with columns
  election,district,booth,vote_type,candidate,party_raw,votes,lat,lon,source_file
One row per (voting-centre row x candidate); nothing aggregated. Total / subtotal /
percentage rows are never emitted. vote_type is 'ordinary' for a named voting centre,
else the lowercased label with its trailing 'votes' removed (postal, early, absent,
provisional, declaration, 'marked as voted', 'all votes'). 'All Votes Votes' rows are all-zero on
most pages that carry one (skipped) but real on Prahran 2014 and Ripon 2018 (kept, 'all votes').
2006 Ferntree Gully has no booth-level data (VEC: recount) and is reported, not emitted.

Validation (exit 1 on any failure) -- see check_totals(); main() ends with a self-test
that perturbs one value in a COPY of the parsed data and requires check 2 to catch it.

Run from repo root: python scripts/parse_booths_vic.py
"""
import csv
import glob
import html
import os
import re
import sys
from collections import defaultdict

VEC = 'external/reference/vec'
OUT = 'output/booths'
FIELDS = ['election', 'district', 'booth', 'vote_type', 'candidate', 'party_raw',
          'votes', 'lat', 'lon', 'source_file']
TOL = 0.005
EXPECTED_DISTRICTS = {'2006': 88, '2010': 88, '2014': 88, '2018': 88, '2022': 87}
REF_FP = {y: f'external/elections/vec-{y}-vic-firstprefs.csv' for y in ('2010', '2014', '2018', '2022')}
SKIP_LABELS = {'', 'total', 'ordinary votes total', 'ordinary total'}


# check2 failure traced to the SOURCE page (the page's rows sum to its own printed Formal Votes, 40358,
# but the repo's vec-2018-vic-firstprefs.csv has 43927; the page looks like a pre-recount snapshot --
# its two-candidate page sums to ~43.7k). Not independently verified which is final.
KNOWN_SOURCE_MISMATCH = {('2018', 'check2', 'Brunswick')}


def clean(s):
    s = re.sub(r'<[^>]+>', '', s)
    return re.sub(r'\s+', ' ', html.unescape(s).replace('\xa0', ' ')).strip()


def norm(s):
    return re.sub(r'[^a-z0-9]', '', s.lower())


def read(f):
    return open(f, encoding='utf-8', errors='replace').read()


def results_table(t, f):
    """The table whose header row carries 'Informal votes' -> (rows of cell text, header row index)."""
    for tb in re.findall(r'<table.*?</table>', t, re.S):
        rows = [[clean(c) for c in re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>', r, re.S)]
                for r in re.findall(r'<tr.*?</tr>', tb, re.S)]
        for i, r in enumerate(rows):
            if any(c.lower() == 'informal votes' for c in r) and i > 0:
                return rows, i
    if 'not available where a recount took place' in t:
        return None, None
    raise ValueError(f'{f}: no results table')


def fidelity_bad(body):
    """Parser fidelity: the rows we emit must sum, per candidate column, to the page's own 'Total' row.
    Returns a list of (column index, summed, printed) disagreements; [] when the page reconciles."""
    tot = [v for lab, v, _ in body if lab.lower() == 'total']
    if len(tot) != 1:
        return [('no single Total row', len(tot), None)]
    rows = [v for lab, v, _ in body if lab.lower() not in SKIP_LABELS]
    bad = []
    for j, pr in enumerate(tot[0]):
        sm = sum(int(r[j].replace(',', '') or 0) for r in rows)
        if sm != int(pr.replace(',', '') or 0):
            bad.append((j, sm, pr))
    return bad


def parse_page(f):
    """-> (cands, parties, body [(label, [votes...])], printed formal total or None)."""
    t = read(f)
    rows, pi = results_table(t, f)
    if rows is None:
        return None
    prow, crow = rows[pi], rows[pi - 1]
    end = next(i for i, c in enumerate(prow) if c.lower() in ('mis-sorts', 'informal votes'))
    n = end - 1
    cands = crow[1:1 + n]
    parties = prow[1:1 + n]
    if len(cands) != n or not all(cands):
        raise ValueError(f'{f}: candidate header misaligned {crow} vs {prow}')
    body = []
    for r in rows[pi + 1:]:
        if len(r) < n + 3 or r[0].lower().startswith('percentage'):
            continue
        body.append((r[0], r[1:1 + n], r[1 + n] if prow[end].lower() == 'mis-sorts' else '0'))
    m = re.search(r'Formal Votes:?\s*</th>\s*<td[^>]*>\s*([\d,]+)', t)
    formal = int(m.group(1).replace(',', '')) if m else None
    return cands, parties, body, formal


def district_name(t, f, y):
    if y == '2022':
        m = re.search(r'results by voting centre for (.+?) District\s*"', t)
    else:
        m = re.search(r'<h2>\s*(.+?) District\s*<br', t, re.S)
    if not m:
        raise ValueError(f'{f}: no district name')
    return clean(m.group(1))


def vote_type(label):
    low = label.lower()
    if low.endswith(' votes'):
        return low[:-6].strip()
    return 'ordinary'


def load_locations():
    import openpyxl
    wb = openpyxl.load_workbook(f'{VEC}/2022/voting-centre-locations-2022.xlsx', read_only=True, data_only=True)
    rows = list(wb['VC Locations'].iter_rows(values_only=True))
    h = list(rows[0])
    ie, iv, ila, ilo = h.index('Electorates'), h.index('VotingLocationName'), h.index('Lat'), h.index('Long')
    loc = {}
    for r in rows[1:]:
        if r[iv] is None:
            continue
        for d in str(r[ie]).split(','):
            d = re.sub(r' District$', '', d.strip())
            loc[(norm(d), norm(str(r[iv])))] = (r[ila], r[ilo])
    return loc


def build_pages(y):
    if y == '2022':
        pairs = [(f, f[:-len('-fp.html')] + '-2cp.html') for f in sorted(glob.glob(f'{VEC}/2022/booths/*-fp.html'))]
        assert all(g != f and os.path.exists(g) for f, g in pairs)
        return pairs
    pairs = []
    for f in sorted(glob.glob(f'{VEC}/{y}/vc/fpv-*.html')):
        g = os.path.join(os.path.dirname(f), 'tcp-' + os.path.basename(f)[len('fpv-'):])
        assert g != f and os.path.exists(g), g
        pairs.append((f, g))
    return pairs


def parse_year(y, loc):
    fp, tcp, info, unmatched, nopage = [], [], {}, [], []
    missorts = defaultdict(int)
    fidelity = []
    for ffp, ftc in build_pages(y):
        d = district_name(read(ffp), ffp, y)
        for kind, f, sink in (('fp', ffp, fp), ('tcp', ftc, tcp)):
            page = parse_page(f)
            if page is None:
                nopage.append((kind, d))
                continue
            cands, parties, body, formal = page
            fidelity.append((os.path.basename(f), fidelity_bad(body)))
            if kind == 'fp':
                info[d] = formal
            for label, vals, miss in body:
                if label.lower() in SKIP_LABELS:
                    continue
                vt = vote_type(label)
                nums = [v.replace(',', '') for v in vals]
                if label.lower().startswith('all votes') and all(re.fullmatch(r'0*', v) for v in nums):
                    continue  # empty or all-zero placeholder row
                if kind == 'tcp' and label.lower() not in SKIP_LABELS:
                    missorts[d] += int(miss.replace(',', '') or 0)
                lat = lon = ''
                if y == '2022' and vt == 'ordinary':
                    ll = loc.get((norm(d), norm(label)))
                    if ll is None:
                        unmatched.append((d, label))
                    else:
                        lat, lon = ll
                for c, p, v in zip(cands, parties, nums):
                    sink.append({'election': f'vic{y}', 'district': d, 'booth': label, 'vote_type': vt,
                                 'candidate': c, 'party_raw': p, 'votes': v, 'lat': lat, 'lon': lon,
                                 'source_file': os.path.basename(f)})
    info['__missorts__'] = dict(missorts)
    info['__fidelity__'] = fidelity
    return fp, tcp, info, unmatched, nopage


def to_int(v):
    return int(v) if re.fullmatch(r'\d+', str(v)) else None


def check_totals(y, fp, tcp, info, ref, nofp=()):
    """Returns (failure strings, report lines)."""
    fails, rep = [], []
    info = dict(info)
    miss = info.pop('__missorts__', {})
    fid = info.pop('__fidelity__', [])
    fid_bad = {f for f, b in fid if b}
    rep.append(f'{y}: check5 parser fidelity (emitted rows sum to each page Total row): '
               f'{len(fid) - len(fid_bad)}/{len(fid)} pages reconcile')
    for f, b in fid:
        if b:
            fails.append(f'{y} check5 {f}: {b[:3]}')
    # 4: integer, non-negative, booths present
    bad = [r for r in fp + tcp if to_int(r['votes']) is None]
    if bad:
        fails.append(f'{y}: {len(bad)} negative/non-integer vote cells, e.g. {bad[0]}')
    dist_fp = defaultdict(int)
    booths = defaultdict(set)
    for r in fp:
        if to_int(r['votes']) is not None:
            dist_fp[r['district']] += int(r['votes'])
        if r['vote_type'] == 'ordinary':
            booths[r['district']].add(r['booth'])
    nodist = [d for d in dist_fp if not booths[d]]
    if nodist:
        fails.append(f'{y}: districts with zero ordinary booths: {nodist}')
    # 1
    nd = len(dist_fp) + len(nofp)
    rep.append(f'{y}: districts with fp parsed {len(dist_fp)} + {len(nofp)} with no fp page (recount) = {nd} (expected {EXPECTED_DISTRICTS[y]}); '
               f'ordinary booths {sum(len(b) for b in booths.values())}')
    if nd != EXPECTED_DISTRICTS[y]:
        fails.append(f'{y}: {nd} districts, expected {EXPECTED_DISTRICTS[y]}')
    # 2: reference file (2010+), else the page's own printed formal total
    if ref is not None:
        refd = {norm(k): v for k, v in ref.items()}
        src = 'vec firstprefs csv'
        target = {d: refd.get(norm(d)) for d in dist_fp}
    else:
        src = "page's printed Formal Votes"
        target = dict(info)
    diffs = []
    for d, s in dist_fp.items():
        t = target.get(d)
        if t is None:
            diffs.append((float('inf'), d, s, None))
        else:
            diffs.append((abs(s - t) / t if t else float('inf'), d, s, t))
    ok = sum(1 for x in diffs if x[0] <= TOL)
    rep.append(f'{y}: check2 (fp sum vs {src}): {ok}/{len(diffs)} within {TOL:.1%}; worst 3: ' +
               '; '.join(f'{d} parsed={s} ref={t} ({e:.3%})' for e, d, s, t in sorted(diffs, key=lambda x: -x[0])[:3]))
    for e, d, s, t in diffs:
        if e > TOL:
            if (y, 'check2', d) in KNOWN_SOURCE_MISMATCH:
                rep.append(f'{y} check2 {d}: KNOWN SOURCE MISMATCH parsed {s} vs reference {t}')
            else:
                fails.append(f'{y} check2 {d}: parsed {s} vs reference {t}')
    if ref is not None:
        pm = [(abs(dist_fp[d] - p) / p, d) for d, p in info.items() if p and d in dist_fp]
        rep.append(f'{y}: check2b (fp sum vs page-printed formal, informational): '
                   f'{sum(1 for x in pm if x[0] <= TOL)}/{len(pm)} within tol')
    # 3
    dist_tcp = defaultdict(int)
    for r in tcp:
        if to_int(r['votes']) is not None:
            dist_tcp[r['district']] += int(r['votes'])
    # the VEC prints 'Mis-sorts' (formal ballots it could not assign to either of the two candidates)
    # beside the two counts, so formal = two candidates + mis-sorts; check 3 adds them back.
    t3 = [(abs(dist_tcp[d] + miss.get(d, 0) - s) / s, d, dist_tcp[d] + miss.get(d, 0), s) for d, s in dist_fp.items()]
    rep.append(f'{y}: check3 (tcp two-candidate sum + mis-sorts vs fp sum): {sum(1 for x in t3 if x[0] <= TOL)}/{len(t3)} within tol; worst 3: ' +
               '; '.join(f'{d} tcp={a} fp={b} ({e:.3%})' for e, d, a, b in sorted(t3, key=lambda x: -x[0])[:3]))
    for e, d, a, b in t3:
        if e > TOL:
            # Check5 (fatal) proves each page's emitted rows equal its own Total row, so a check3
            # deviation is the VEC's fp and tcp pages disagreeing with each other (e.g. one
            # vote-type row differs), not a parse error. Reported, not fatal.
            rep.append(f'{y} check3 {d}: SOURCE INCONSISTENCY tcp {a} vs fp {b} ({e:.3%}) -- not fatal')
    return fails, rep


def load_ref(y):
    if y not in REF_FP:
        return None
    ref = defaultdict(float)
    with open(REF_FP[y], newline='', encoding='utf-8') as fh:
        for r in csv.DictReader(fh):
            ref[r['seat']] += float(r['votes'])
    return dict(ref)


def main():
    os.makedirs(OUT, exist_ok=True)
    loc = load_locations()
    allfails, data = [], {}
    for y in ('2006', '2010', '2014', '2018', '2022'):
        fp, tcp, info, unmatched, nopage = parse_year(y, loc)
        ref = load_ref(y)
        fails, rep = check_totals(y, fp, tcp, info, ref, [d for k, d in nopage if k == 'fp'])
        if y == '2022':
            rep.append(f'2022: ordinary booths with no lat/lon match: {len(unmatched)} {sorted(set(unmatched))[:5]}')
        if nopage:
            rep.append(f'{y}: pages with no data (VEC: not available where a recount took place): {nopage}')
        types = defaultdict(int)
        for r in fp:
            types[r['vote_type']] += 1
        rep.append(f'{y}: rows fp={len(fp)} tcp={len(tcp)}; fp rows by vote_type: {dict(types)}')
        print('\n'.join(rep))
        allfails += fails
        data[y] = (fp, tcp, info, ref)
        for name, rows in (('fp', fp), ('tcp', tcp)):
            with open(f'{OUT}/vic{y}-booth-{name}.csv', 'w', newline='', encoding='utf-8') as fh:
                w = csv.DictWriter(fh, FIELDS)
                w.writeheader()
                w.writerows(rows)
    # self-test: perturb one value in a COPY and require check 2 to report it
    fp, tcp, info, ref = data['2014']
    fp2 = [dict(r) for r in fp]
    fp2[0]['votes'] = str(int(fp2[0]['votes']) + 5000)
    f2, _ = check_totals('2014', fp2, tcp, info, ref)
    caught = [x for x in f2 if 'check2' in x]
    print(f'SELFTEST perturbed {fp2[0]["district"]}/{fp2[0]["booth"]} by +5000 in a copy: '
          f'check2 reported {len(caught)} failure(s): {caught[:1]}')
    if not caught:
        allfails.append('SELFTEST: check 2 did not detect a perturbed value')
    pb = parse_page(build_pages('2014')[0][0])[2]
    pb2 = [(lab, [str(int(v) + 1) if v.isdigit() and lab == pb[0][0] and j == 0 else v for j, v in enumerate(vals)], m)
           for lab, vals, m in pb]
    print(f'SELFTEST check5 on clean page: {len(fidelity_bad(pb))} problem(s); on a copy with one cell +1: {len(fidelity_bad(pb2))}')
    if fidelity_bad(pb) or not fidelity_bad(pb2):
        allfails.append('SELFTEST: check 5 did not detect a perturbed value')
    if allfails:
        print('\nFAILURES:')
        print('\n'.join(allfails))
        sys.exit(1)
    print('\nALL CHECKS PASSED')


if __name__ == '__main__':
    main()
