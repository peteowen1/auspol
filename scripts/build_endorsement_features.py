"""Climate 200 / Voices endorsement per (pair, seat, party), as model inputs.

WHY. The largest block of primary misses is community independents "from
nowhere": Mackellar, Goldstein, Kooyong, Curtin, North Sydney (fed2022) and
Wakehurst (nsw2023). We had them at 9-12%; AE Forecasts at 20-28%; they got
25-40%. The visible signal before polling day is campaign backing: Climate 200
funding and local "Voices of" groups (Pete chose this, 2026-10-02).

Reads external/reference/climate200/endorsements.csv (sourced, one row per
candidate and support type) and output/candidacies.csv; matches each endorsed
candidate to their candidacy by surname + given name within the seat. Only
support announced before polling day counts (time-forward). Before Climate 200
existed (2019) the value is a true zero, not missing.

Writes output/endorsement-features.csv: pair, seat, party, c200, voices.
Prints every endorsement that did not match a candidacy (never silently
dropped) and fails if more than 10% do not.

Run from repo root: python scripts/build_endorsement_features.py
"""
import collections
import csv
import re
import sys

E = 'external/reference/climate200/endorsements.csv'


def nk(x):
    return re.sub(r'[^a-z]', '', (x or '').lower())


def split_name(n):
    if ',' in n:
        a, b = n.split(',', 1)
        return nk(a), nk((b.split() or [''])[0])
    t = n.split()
    if not t:
        return '', ''
    if t[0].isupper() and len(t) > 1:
        return nk(t[0]), nk(t[1])
    return nk(t[-1]), nk(t[0])


def main():
    dates = {}
    for m in re.finditer(r'(fed|nsw|vic|qld|sa|wa)(\d{4})\s*=\s*"(\d{4}-\d{2}-\d{2})"', open('R/election_dates.R').read()):
        dates[m.group(1) + m.group(2)] = m.group(3)
    C = collections.defaultdict(list)
    for r in csv.DictReader(open('output/candidacies.csv', encoding='utf-8')):
        C[(r['election'], nk(r['seat']))].append(r)
    feats = collections.defaultdict(lambda: {'c200': 0, 'voices': 0})
    rows = list(csv.DictReader(open(E, encoding='utf-8')))
    unmatched, late, used = [], [], 0
    for e in rows:
        el, typ = e['election'].strip(), e['support_type'].strip().lower()
        if typ not in ('climate200', 'voices'):
            continue
        ad = (e.get('announced_date') or '').strip()
        if ad and el in dates and ad[:len(dates[el][:len(ad)])] > dates[el][:len(ad)]:
            late.append((el, e['seat'], e['candidate'], ad))
            continue
        sur, giv = split_name(e['candidate'])
        cands = C.get((el, nk(e['seat'])), [])
        hit = [c for c in cands if (nk(c.get('surname')) or split_name(c['name'])[0]) == sur]
        if len(hit) > 1:
            hit = [c for c in hit if giv and giv in nk(c.get('given') or c['name'])] or hit[:1]
        if not hit:
            unmatched.append((el, e['seat'], e['candidate']))
            continue
        k = (el, hit[0]['seat'], hit[0]['party'])
        feats[k]['c200' if typ == 'climate200' else 'voices'] = 1
        used += 1
    with open('output/endorsement-features.csv', 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['pair', 'seat', 'party', 'c200', 'voices'])
        for (el, seat, party), v in sorted(feats.items()):
            w.writerow([el, seat, party, v['c200'], v['voices']])
    by = collections.Counter(k[0] for k, v in feats.items() if v['c200'])
    print(f'EN1 {len(rows)} endorsement rows; matched {used}; announced after polling day (dropped) {len(late)}; unmatched {len(unmatched)}')
    print(f'EN2 Climate 200-backed candidacies by election: {dict(sorted(by.items()))}')
    for u in unmatched:
        print(f'EN0! no candidacy matched: {u}')
    n_match_target = sum(1 for e in rows if e['election'] in dates)
    if n_match_target and len(unmatched) > 0.10 * n_match_target:
        print('EN0! more than 10% of endorsements unmatched -- fix names before using')
        sys.exit(1)


if __name__ == '__main__':
    main()
