"""Per-party booth-pattern features from the PREVIOUS election, state and federal.

WHY. District totals are already in the model; booth results add the pattern
INSIDE a district. Two candidates, tested against v58's remaining error with
election-clustered errors (2026-10-02): the early-vote gap (a class's share among
early/pre-poll/postal votes minus its share on the day) -- One Nation t -5.4
(over-predicted where its day vote ran ahead of its early vote, 3 of 4
elections), Greens t +2.1; and the spread of a class's share across polling
places -- Labor t -1.9, negative in 11 of 12 elections.

Both come from the election BEFORE the target (time-forward by construction),
keyed by the prior district's name: a renamed district gets no value (NA).
Federal 2007 and the first election of each state series have no prior booth
data and are absent (NA) -- not zero.

State: output/booths/<election>-booth-fp.csv, classes from the corpus reconciled
to the district files (scripts/build_state_notionals.py's classify/reconcile).
Federal: external/reference/aec/booths/pp-fed<year>-<STATE>.csv (House first
preferences by polling place, OrdinaryVotes); pre-poll voting centres are the
early votes; classes from the corpus by name.

Writes output/booth-features.csv: pair, seat, party, booth_spread, early_gap.
Run from repo root: python scripts/build_booth_features.py
"""
import collections
import csv
import glob
import math
import os
import re
import statistics as st
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_state_notionals as B  # noqa: E402

EARLY = re.compile(r'(?i)pre-?poll|ppvc|early voting|evc\b|postal')
NONBOOTH = re.compile(r'(?i)special hospital|divisional office|mobile|remote|other mobile|absent|provisional|declaration')
STATE_PAIRS = [('vic', 2010, 2014), ('vic', 2014, 2018), ('vic', 2018, 2022), ('vic', 2022, 2026),
               ('nsw', 2015, 2019), ('nsw', 2019, 2023), ('qld', 2017, 2020), ('qld', 2020, 2024),
               ('sa', 2018, 2022), ('sa', 2022, 2026), ('wa', 2005, 2008), ('wa', 2008, 2013),
               ('wa', 2013, 2017), ('wa', 2017, 2021), ('wa', 2021, 2025)]
FED = [2007, 2010, 2013, 2016, 2019, 2022, 2025]
MIN_BOOTH = 100      # a polling place with fewer formal votes says little about spread


def nk(x):
    return re.sub(r'[^a-z]', '', (x or '').lower())


def features(cells):
    """cells: district -> list of (kind, Counter of class votes); kind 'day' or 'early'."""
    out = {}
    for d, rows in cells.items():
        day = [c for k, c in rows if k == 'day' and sum(c.values()) >= MIN_BOOTH]
        dt, et = collections.Counter(), collections.Counter()
        for k, c in rows:
            (dt if k == 'day' else et).update(c)
        nd, ne = sum(dt.values()), sum(et.values())
        classes = set(dt) | set(et)
        for p in classes:
            sh = [100 * c.get(p, 0) / sum(c.values()) for c in day]
            spread = st.pstdev(sh) if len(sh) >= 3 else float('nan')
            gap = (100 * et.get(p, 0) / ne - 100 * dt.get(p, 0) / nd) if ne >= 500 and nd > 0 else float('nan')
            out[(d, p)] = (spread, gap)
    return out


def state_rows(corpus):
    res = []
    for rg, fy, ty in STATE_PAIRS:
        A = B.read_booths(f'{rg}{fy}')
        if A is None:
            print(f'BFT! {rg}{fy}: no booth file -- {rg}{ty} gets NA')
            continue
        cls, miss = B.classify(A, f'{rg}{fy}', corpus)
        cls, _, _ = B.reconcile(cls, A, rg, fy)
        cells = collections.defaultdict(list)
        per = collections.defaultdict(collections.Counter)
        for r in A:
            k = 'day' if r['vote_type'] == 'ordinary' else 'early'
            per[(r['district'], r['booth'], k)][cls[(r['district'], r['candidate'], r['party_raw'])]] += int(r['votes'])
        for (d, b, k), c in per.items():
            cells[d].append((k, c))
        f = features(cells)
        for (d, p), (sp, gp) in f.items():
            res.append((f'{rg}{ty}', d, p, sp, gp))
        print(f'BFT1 {rg}{ty} (from {rg}{fy}): {len({d for d, _ in f})} districts, {len(f)} district-class cells')
    return res


def fed_rows(corpus):
    res = []
    for i, ty in enumerate(FED):
        if i == 0:
            print('BFT! fed2007: no 2004 House booth votes -- NA')
            continue
        fy = FED[i - 1]
        files = glob.glob(f'external/reference/aec/booths/pp-fed{fy}-*.csv')
        if not files:
            print(f'BFT! fed{ty}: no fed{fy} booth files -- NA')
            continue
        cands = corpus  # keyed by (election, seat_key)
        per = collections.defaultdict(collections.Counter)
        unmatched = 0
        lookup = {}
        for f in files:
            rows = list(csv.reader(open(f, encoding='utf-8', errors='replace')))
            h = rows[1]
            ix = {c: j for j, c in enumerate(h)}
            for r in rows[2:]:
                if len(r) < len(h) - 1:
                    continue
                d, pp = r[ix['DivisionNm']], r[ix['PollingPlace']]
                if NONBOOTH.search(pp):
                    continue
                k = 'early' if EARLY.search(pp) else 'day'
                key = (d, r[ix['Surname']], r[ix['GivenNm']])
                if key not in lookup:
                    cs = cands.get((f'fed{fy}', B.seat_key(d)), [])
                    sur = nk(r[ix['Surname']])
                    gv = nk((r[ix['GivenNm']].split() or [''])[0])
                    hit = [c for c in cs if nk(c['surname']) == sur] or \
                          [c for c in cs if sur and sur in nk(c['name'])]
                    if len(hit) > 1:
                        hit = [c for c in hit if gv and gv in nk(c['name'])] or hit[:1]
                    lookup[key] = hit[0]['party'] if hit else None
                p = lookup[key]
                if p is None:
                    unmatched += 1
                    continue
                v = int(r[ix['OrdinaryVotes']] or 0)
                per[(d, pp, k)][p] += v
        cells = collections.defaultdict(list)
        for (d, b, k), c in per.items():
            cells[d].append((k, c))
        f = features(cells)
        for (d, p), (sp, gp) in f.items():
            res.append((f'fed{ty}', d, p, sp, gp))
        print(f'BFT1 fed{ty} (from fed{fy}): {len({d for d, _ in f})} divisions, {len(f)} cells; booth rows with no corpus class: {unmatched}')
    return res


def main():
    corpus = B.read_corpus()
    rows = state_rows(corpus) + fed_rows(corpus)
    os.makedirs('output', exist_ok=True)
    with open('output/booth-features.csv', 'w', newline='', encoding='utf-8') as fo:
        w = csv.writer(fo)
        w.writerow(['pair', 'seat', 'party', 'booth_spread', 'early_gap'])
        for r in rows:
            w.writerow([r[0], r[1], r[2], '' if math.isnan(r[3]) else round(r[3], 4), '' if math.isnan(r[4]) else round(r[4], 4)])
    n_sp = sum(1 for r in rows if not math.isnan(r[3]))
    n_gp = sum(1 for r in rows if not math.isnan(r[4]))
    print(f'BFT9 wrote output/booth-features.csv: {len(rows)} cells, spread on {n_sp}, early gap on {n_gp}')


if __name__ == '__main__':
    main()
