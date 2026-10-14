#!/usr/bin/env python
"""Parse the NSWEC 2011 general election first-preference pages into booth rows and a district file.

Inputs (never modified): external/reference/nswec/raw/2011/fp/<District>.htm (93 pages, one per district;
each has a polling-place table with one column per candidate, then declaration-vote rows and a Grand Total),
and external/elections/nswec-2011-nsw-candidates.csv (full names + party classes for 92 districts).

Outputs:
  output/booths/nsw2011-booth-fp.csv     same columns as scripts/parse_booths_nsw_qld.py (NSW 2015/2019/2023)
  external/elections/nswec-2011-nsw-firstprefs.csv   seat,party,votes at CLASS level (the nswec-2015 shape)
  external/elections/nswec-2011-nsw-winners.csv      election,seat,code,winner(class),basis
  external/elections/nswec-2011-nsw-candidates-supplement.csv  candidates of districts the candidates file lacks (Penrith)

Candidate names: the pages carry only the surname; the candidates file carries "SURNAME Given". The booth
candidate is the candidates-file name when its surname matches exactly one candidate of that district,
otherwise the bare surname. A district absent from the candidates file (Penrith) uses surname only and its
party class comes from the party-code map below, which every other district's codes are checked against.

Validation (exit 1 on failure): per district, the Grand Total row equals the sum of all booth and
declaration rows for every candidate; when the candidates file has the district, Grand Totals equal its
first_pref per candidate.
Run from repo root: python scripts/parse_booths_nsw2011.py
"""
import csv
import html
import os
import re
import sys

RAW = 'external/reference/nswec/raw/2011/fp/'
CAND = 'external/elections/nswec-2011-nsw-candidates.csv'
OUT_BOOTH = 'output/booths/nsw2011-booth-fp.csv'
CHECKS = 'external/elections/nswec-2011-nsw-checks.csv'
OUT_WIN = 'external/elections/nswec-2011-nsw-winners.csv'
OUT_SUPP = 'external/elections/nswec-2011-nsw-candidates-supplement.csv'
OUT_FP = 'external/elections/nswec-2011-nsw-firstprefs.csv'
CLASS = {'AD': 'OTH', 'CDP': 'OTH_RIGHT', 'IND': 'IND', '': 'IND', 'LP': 'LNP', 'GNS': 'GRN', 'ALP': 'ALP',
         'FF': 'OTH_RIGHT', 'NP': 'LNP', 'CL': 'ALP', 'SOS': 'OTH', 'FP': 'OTH', 'SA': 'OTH', 'ORP': 'OTH',
         'SFP': 'OTH_RIGHT'}
DECL = ('Postal', 'Declared', 'Absent', 'Provisional', 'Enrolment', 'Pre-poll', 'Total Dec')
STOP = ('Total Ordinary', 'Grand Total', '% of Total')


def cells(row):
    return [html.unescape(re.sub(r'<[^>]+>', '', c)).replace('\xa0', ' ').strip()
            for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, flags=re.S)]


def num(s):
    s = s.replace(',', '').strip()
    return int(s) if re.fullmatch(r'\d+', s) else None


def parse(path):
    t = open(path, encoding='utf-8', errors='replace').read()
    tabs = re.findall(r'<table.*?</table>', t, flags=re.S)
    top = [cells(r) for r in re.findall(r'<tr.*?</tr>', tabs[0], flags=re.S)]
    cands = []   # (surname, party_code)
    for c in top:
        if len(c) >= 3 and num(c[2]) is not None and c[0] not in ('Candidate',):
            cands.append((re.sub(r'[+†]+$', '', c[0]).strip(), c[1].replace('+', '').strip()))
    pp = [cells(r) for r in re.findall(r'<tr.*?</tr>', tabs[1], flags=re.S)]
    rows, grand = [], None
    n = len(cands)
    for c in pp:
        if len(c) < n + 1:
            continue
        label = c[0]
        vals = [num(x) for x in c[1:1 + n]]
        if None in vals:
            continue
        if label.startswith('Grand Total'):
            grand = vals
        elif label.startswith(STOP) or label.startswith('Total'):
            continue
        else:
            rows.append((label, vals))
    return cands, rows, grand


def main():
    names = {}
    for r in csv.DictReader(open(CAND, encoding='utf-8')):
        names.setdefault(r['seat'], []).append(r)
    bad = False
    booth, fp = [], []
    pages = sorted(f for f in os.listdir(RAW) if f.endswith('.htm'))
    for f in pages:
        seat = f[:-4].replace('_', ' ')
        cands, rows, grand = parse(RAW + f)
        if not cands or grand is None or not rows:
            print(f'NB11! {seat}: parse failed (cands {len(cands)}, rows {len(rows)}, grand {grand})')
            bad = True
            continue
        full, full_sur = [], []
        for sur, code in cands:
            hit = [r for r in names.get(seat, []) if (r['candidate'].upper() + ' ').startswith(sur.upper() + ' ')]
            # two candidates sharing a surname (Epping SMITH, Hawkesbury WILLIAMS): the candidates file
            # is in page (ballot) order, so take the k-th hit for the k-th page occurrence
            k = sum(1 for q in full_sur if q == sur.upper())
            full_sur.append(sur.upper())
            full.append(hit[k]['candidate'] if len(hit) > k else (hit[0]['candidate'] if len(hit) == 1 else sur))
            if code not in CLASS:
                print(f'NB11! {seat}: unknown party code {code!r}')
                bad = True
        tot = [0] * len(cands)
        for label, vals in rows:
            vt = 'ordinary' if not label.startswith(DECL) else (
                'prepoll' if label.startswith('Pre-poll') else 'declaration')
            for i, v in enumerate(vals):
                tot[i] += v
                if v:
                    booth.append(['nsw2011', seat, label, vt, full[i], cands[i][1], v, '', '',
                                  'external/reference/nswec/raw/2011/fp/' + f])
        if tot != grand:
            print(f'NB11! {seat}: rows sum {tot} != Grand Total {grand}')
            bad = True
        if seat in names:
            fpref = {r['candidate'].upper(): int(r['first_pref']) for r in names[seat]}
            got = {n.upper(): g for n, g in zip(full, grand)}
            if fpref != got:
                print(f'NB11! {seat}: Grand Totals differ from candidates file {got} v {fpref}')
                bad = True
        agg = {}
        for (sur, code), g in zip(cands, grand):
            agg[CLASS[code]] = agg.get(CLASS[code], 0) + g
        for k, v in sorted(agg.items()):
            fp.append([seat, k, v])
    # Winners: the NSWEC's own ELECTED cell (nswec-2011-nsw-checks.csv) for the 92 districts it covers; a
    # district it lacks (Penrith) takes its top first-preference candidate, and the file says so in `basis`.
    chk = {r['seat']: r['elected'] for r in csv.DictReader(open(CHECKS, encoding='utf-8'))}
    cls_of = {(r['seat'], r['candidate']): (r['class'], r['party_code']) for rs in names.values() for r in rs}
    win, supp = [], []
    for seat in sorted({b[1] for b in booth}):
        tot = {}
        for b in booth:
            if b[1] == seat:
                tot[(b[4], b[5])] = tot.get((b[4], b[5]), 0) + b[6]
        if seat in chk:
            cn = chk[seat]
            code = cls_of[(seat, cn)]
            win.append(['nsw2011', seat, code[1], code[0], 'nsw-checks-elected'])
        else:
            (cn, pc), v = max(tot.items(), key=lambda kv: kv[1])
            win.append(['nsw2011', seat, pc, CLASS[pc], 'top-first-pref (district not in the NSWEC checks file)'])
            for (n, pc2), v2 in sorted(tot.items(), key=lambda kv: -kv[1]):
                supp.append([seat, n, pc2, CLASS[pc2], v2])
    with open(OUT_WIN, 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['election', 'seat', 'code', 'winner', 'basis'])
        w.writerows(win)
    with open(OUT_SUPP, 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['seat', 'candidate', 'party_code', 'class', 'first_pref'])
        w.writerows(supp)
    os.makedirs(os.path.dirname(OUT_BOOTH), exist_ok=True)
    with open(OUT_BOOTH, 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['election', 'district', 'booth', 'vote_type', 'candidate', 'party_raw', 'votes', 'lat', 'lon', 'source_file'])
        w.writerows(booth)
    with open(OUT_FP, 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['seat', 'party', 'votes'])
        w.writerows(fp)
    print(f'NB11  {len(pages)} pages, {len({b[1] for b in booth})} districts, {len(booth)} booth rows, '
          f'{sum(b[6] for b in booth)} formal votes -> {OUT_BOOTH}, {OUT_FP}')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
