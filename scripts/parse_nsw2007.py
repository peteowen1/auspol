#!/usr/bin/env python
"""Build the nsw2007 results files (previous election of the new nsw2011 pair).

SOURCES (no scriptable NSWEC source exists for 2007: pastvtr serves 2011+ only, the Parliament database is behind a
Cloudflare challenge -- scripts/fetch_official_results_2000s.R, KQ20):
  PRIMARY    Antony Green's ABC 2007 NSW election site, final per-district result pages, from web.archive.org captures
             of 2007-11 (external/reference/abc/nsw2007/<code>.htm). Primary count table: candidate, party, votes.
  CROSS-CHECK Wikipedia's results-by-district page (external/reference/wikipedia/nsw2007-results-district.wikitext).
Every district's candidate votes are compared across the two sources; any disagreement is printed (NP07!) and fails the run.

Outputs (external/elections/): nswec-2007-nsw-firstprefs.csv (seat,party,votes at class level), nswec-2007-nsw-candidates.csv
(seat,candidate,party,party_code,party_full,class,first_pref; candidate "SURNAME Given" like the NSWEC files),
nswec-2007-nsw-winners.csv (election,seat,code,winner(class),basis).
Run from repo root: python scripts/parse_nsw2007.py
"""
import csv
import glob
import html
import re
import sys

ABC = 'external/reference/abc/nsw2007/'
WIKI = 'external/reference/wikipedia/nsw2007-results-district.wikitext'
OUT = 'external/elections/'
# ABC party code -> (code used in the 2011 file, class). Classes follow classify_party() as for nswec-2011.
CLASS = {'ALP': ('ALP', 'ALP'), 'LIB': ('LP', 'LNP'), 'NAT': ('NP', 'LNP'), 'GRN': ('GNS', 'GRN'), 'IND': ('IND', 'IND'),
         '-': ('IND', 'IND'),   # ABC shows an unendorsed independent with no party code
         'CDP': ('CDP', 'OTH_RIGHT'),
         'DEM': ('AD', 'OTH'), 'UNI': ('UNI', 'OTH'), 'AFI': ('AFI', 'OTH'), 'SOS': ('SOS', 'OTH'),
         'SA': ('SA', 'OTH'), 'ORP': ('ORP', 'OTH'), 'FP': ('FP', 'OTH')}


def clean(s):
    return html.unescape(re.sub(r'<[^>]+>', '', s)).replace('\xa0', ' ').strip()


def num(s):
    return int(re.sub(r'[^0-9]', '', s))


def surname_first(name):
    """ABC gives 'Given Surname'; the NSWEC files give 'SURNAME Given'. The surname is taken as the last token, so a
    multi-word surname is split wrongly; that only affects the displayed name."""
    t = name.split()
    if len(t) < 2:
        return name.upper()
    return f'{t[-1].upper()} {" ".join(t[:-1])}'


def parse_abc():
    seats = {}
    for f in sorted(glob.glob(ABC + '*.htm')):
        t = open(f, encoding='utf-8', errors='replace').read()
        if 'electresultsprim' not in t:
            continue
        title = clean(re.findall(r'<h1>(.*?)</h1>', t, re.S)[-1])   # the district name (third h1)
        tab = re.search(r'<table[^>]*id="electresultsprim".*?</table>', t, re.S).group(0)
        rows = []
        for r in re.findall(r'<tr class="(?:odd|even)">(.*?)</tr>', tab, re.S):
            cn = re.search(r'class="cand">(.*?)</td>', r, re.S)
            pc = re.search(r'class="party">(.*?)</td>', r, re.S)
            vt = re.search(r'class="votes">(.*?)</td>', r, re.S)
            v = num(clean(vt.group(1)))
            if v:   # rows with 0 votes are the 2003 parties that did not stand ("....")
                rows.append((clean(cn.group(1)), clean(pc.group(1)), v))
        res = re.search(r'Predicted final result:\s*(.*?)</td>', t, re.S)
        seats[f] = (title, rows, clean(res.group(1)) if res else '')
    return seats


def parse_wiki():
    t = open(WIKI, encoding='utf-8').read()
    secs = re.split(r'\n=== (.+?) ===\n', t)
    out = {}
    for seat, body in zip(secs[1::2], secs[2::2]):
        seat = re.sub(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]', r'\1', seat).strip()
        fpart = body.split('{{Election box formal')[0]
        rows = []
        for blk in re.findall(r'\{\{Election box candidate[^\n]*\n(.*?)\n\}\}', fpart, re.S):
            # [ \t]* not \s*: an empty `|party =` must not swallow the next line
            f = dict((k.strip(), v.strip()) for k, v in re.findall(r'\|[ \t]*(\w+)[ \t]*=[ \t]*([^\n]*)', blk))
            if 'votes' in f:
                rows.append((f.get('party', ''), num(f['votes'])))
        out[seat] = rows
    return out


def main():
    abc = parse_abc()
    wiki = parse_wiki()
    print(f'NP07  ABC pages parsed: {len(abc)}; Wikipedia districts: {len(wiki)}')
    bad = False
    cands, wins = [], []
    unknown = set()
    for f, (title, rows, res) in abc.items():
        seat = title
        if seat not in wiki:
            print(f'NP07! {f}: district {title!r} is not a Wikipedia district name')
            bad = True
            continue
        for n, p, v in rows:
            if p not in CLASS:
                unknown.add(p)
            cands.append((seat, n, p, v))
        m = re.match(r'([A-Z]+)\s+(RETAIN|GAIN|HOLD|WIN)', res)
        if not m:
            print(f'NP07! {seat}: no winner in {res!r}')
            bad = True
        else:
            wins.append((seat, m.group(1)))
    if unknown:
        print('NP07! unmapped ABC party codes:', sorted(unknown))
        sys.exit(1)
    seats = {c[0] for c in cands}
    missing = sorted(set(wiki) - seats)
    if missing:
        print(f'NP07! {len(missing)} Wikipedia districts have no ABC page: {missing}')
        bad = True
    # vote-for-vote cross-check
    for s in sorted(seats):
        ca = sorted(v for ss, n, p, v in cands if ss == s)
        cw = sorted(v for _, v in wiki[s])
        if ca != cw:
            print(f'NP07! {s}: ABC {ca} and Wikipedia {cw} differ')
            bad = True
    with open(OUT + 'nswec-2007-nsw-candidates.csv', 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['seat', 'candidate', 'party', 'party_code', 'party_full', 'class', 'first_pref'])
        for seat, n, p, v in cands:
            w.writerow([seat, surname_first(n), p, CLASS[p][0], p, CLASS[p][1], v])
    agg = {}
    for seat, n, p, v in cands:
        agg[(seat, CLASS[p][1])] = agg.get((seat, CLASS[p][1]), 0) + v
    with open(OUT + 'nswec-2007-nsw-firstprefs.csv', 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['seat', 'party', 'votes'])
        for (seat, c), v in sorted(agg.items()):
            w.writerow([seat, c, v])
    with open(OUT + 'nswec-2007-nsw-winners.csv', 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['election', 'seat', 'code', 'winner', 'basis'])
        for seat, p in sorted(wins):
            w.writerow(['nsw2007', seat, CLASS[p][0], CLASS[p][1], 'ABC final result page'])
    tally = {}
    for _, p in wins:
        tally[CLASS[p][1]] = tally.get(CLASS[p][1], 0) + 1
    print(f'NP07  {len(seats)} districts, {len(cands)} candidates, {sum(c[3] for c in cands)} formal votes; winners {tally}')
    sys.exit(1 if bad or len(seats) != 93 else 0)


if __name__ == '__main__':
    main()
