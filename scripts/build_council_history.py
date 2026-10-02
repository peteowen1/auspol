"""Each state candidate's council history, matched by name AND geography.

WHY. The largest single primary misses are emergences: independents and minor
candidates with no presence last time (Yildiz in Pascoe Vale 2018, Purcell in
South-West Coast). Many were mayors or councillors first, and a council vote is
a measured local following that no other input carries. First look (Victoria,
2026-10-02): independents who had been ELECTED to council beat v57's prediction
by +3.3 points (n 32), those who stood and LOST fell 2.5 short.

HOW. A state candidacy matches a council candidacy when
  1. surname and first given name agree (normalised), and
  2. the council overlaps the district contested (>= 5% of the district's area
     or >= 5% of the council's: output/lga-district-overlap.csv), and
  3. the council election came BEFORE the state election and within 10 years
     (time-forward: nothing after the state election is used).
Two different council candidates matching one state candidate is reported as
ambiguous and the match is dropped.

Reads output/council-results-<state>.csv (scripts/parse_*_council.py; a state
whose file is missing is reported, not silently skipped), output/candidacies.csv
and output/lga-district-overlap.csv (scripts/build_lga_district_overlap.R).
Writes output/council-history.csv: election, seat, name, party, plus
council_any, council_elected, council_mayor, council_pct (latest), council_quota
(latest votes / quota-equivalent), council_year, council_name, n_council_runs.
Emits CH* codes.

Run from repo root: python scripts/build_council_history.py
"""
import collections
import csv
import os
import re
import sys

STATES = ['vic', 'nsw', 'qld', 'sa', 'wa']
STOP = r'\b(city|shire|rural|borough|council|regional|municipal|municipality|town|of|the|district|aboriginal|lord)\b'


# NSW councils merged in 2016 (and Victoria's renames) -> the LGA 2021 name, so a
# pre-merger council candidacy can still be placed. A merged council overlaps the
# successor's district set, which is what the geography check needs.
SUCCESSOR = {'auburn': 'cumberland', 'bankstown': 'canterburybankstown', 'canterbury': 'canterburybankstown',
             'baulkhamhills': 'thehills', 'hills': 'thehills', 'gosford': 'centralcoast', 'wyong': 'centralcoast',
             'botanybay': 'bayside', 'rockdale': 'bayside', 'ashfield': 'innerwest', 'leichhardt': 'innerwest',
             'marrickville': 'innerwest', 'holroyd': 'cumberland', 'hurstville': 'georgesriver', 'kogarah': 'georgesriver',
             'manly': 'northernbeaches', 'pittwater': 'northernbeaches', 'warringah': 'northernbeaches',
             'cityofsydney': 'sydney', 'cooma': 'snowymonaro', 'coomamonaro': 'snowymonaro', 'bombala': 'snowymonaro',
             'snowyriver': 'snowymonaro', 'palerang': 'queanbeyanpalerang', 'queanbeyan': 'queanbeyanpalerang',
             'tumut': 'snowyvalleys', 'tumbarumba': 'snowyvalleys', 'young': 'hilltops', 'boorowa': 'hilltops',
             'harden': 'hilltops', 'gundagai': 'cootamundragundagai', 'cootamundra': 'cootamundragundagai',
             'deniliquin': 'edwardriver', 'conargo': 'edwardriver', 'jerilderie': 'murrumbidgee', 'murrumbidgee': 'murrumbidgee',
             'wakool': 'murrayriver', 'murray': 'murrayriver', 'corowa': 'federation', 'urana': 'federation',
             'greaterhumeshire': 'greaterhume', 'dubbo': 'dubboregional', 'wellington': 'dubboregional',
             'tamworth': 'tamworthregional', 'parramatta': 'parramatta', 'gloucester': 'midcoast', 'greatlakes': 'midcoast',
             'greatertaree': 'midcoast', 'goldenplains': 'goldenplains', 'armidaledumaresq': 'armidale',
             'guyra': 'armidale', 'nambucca': 'nambuccavalley'}


def nk(s):
    return re.sub(r'[^a-z]', '', (s or '').lower())


def cnorm(s):
    s = (s or '').lower().replace('merri-bek', 'moreland').replace('merribek', 'moreland').replace('&', ' and ')
    s = re.sub(r'\([^)]*\)', ' ', s)
    k = re.sub(r'[^a-z]', '', re.sub(STOP, ' ', s))
    return SUCCESSOR.get(k, k)


# Common short forms, so "Matt" on one roll and "Matthew" on the other still match.
NICK = {'matt': 'matthew', 'mat': 'matthew', 'kath': 'katherine', 'kate': 'katherine', 'cathy': 'catherine',
        'bob': 'robert', 'rob': 'robert', 'robbie': 'robert', 'bill': 'william', 'will': 'william',
        'liz': 'elizabeth', 'beth': 'elizabeth', 'jim': 'james', 'jimmy': 'james', 'tony': 'anthony',
        'mick': 'michael', 'mike': 'michael', 'steve': 'stephen', 'dave': 'david', 'pete': 'peter',
        'chris': 'christopher', 'nick': 'nicholas', 'tom': 'thomas', 'ben': 'benjamin', 'dan': 'daniel',
        'sam': 'samuel', 'sue': 'susan', 'jen': 'jennifer', 'jenny': 'jennifer', 'andy': 'andrew',
        'greg': 'gregory', 'ken': 'kenneth', 'ron': 'ronald', 'don': 'donald', 'jo': 'joanne',
        'pat': 'patrick', 'tim': 'timothy', 'phil': 'philip', 'col': 'colin', 'les': 'leslie', 'di': 'diane'}


def gkey(g):
    g = nk(g)
    return NICK.get(g, g)


def split_state(n):
    if ',' in n:
        a, b = n.split(',', 1)
        return nk(a), nk((b.split() or [''])[0])
    t = n.split()
    if len(t) == 1:                         # surname only (WA state corpus)
        return nk(t[0]), ''
    if len(t) >= 2 and t[0].isupper():     # "SURNAME Given" (NSW)
        return nk(t[0]), nk(t[1])
    return (nk(t[-1]), nk(t[0])) if t else ('', '')


EXTRA = os.environ.get('AUSPOL_COUNCIL_EXTRA', '0') == '1'


def main():
    OV = collections.defaultdict(dict)
    for r in csv.DictReader(open('output/lga-district-overlap.csv', encoding='utf-8')):
        OV[(r['election'], nk(r['district']))][cnorm(r['lga'])] = (float(r['share_of_district']), float(r['share_of_lga']))
    CR = collections.defaultdict(list)
    have = []
    for st in STATES:
        f = f'output/council-results-{st}.csv'
        if not os.path.exists(f):
            print(f'CH0! {f} missing -- {st} candidates get no council history this run')
            continue
        n = 0
        for r in csv.DictReader(open(f, encoding='utf-8')):
            r['state'] = st
            r['elected'] = 'True' if str(r['elected']).strip().lower() in ('true', '1', 'yes', 'y', 'elected') else 'False'
            gv = gkey((r['given'] or '').split()[0] if r['given'] else '')
            CR[(st, nk(r['surname']), gv)].append(r)
            CR[(st, nk(r['surname']), '*')].append(r)      # surname-only index (WA state names carry no given name)
            n += 1
        have.append(st)
        print(f'CH0  {st}: {n} council candidate rows')
        # AUSPOL_COUNCIL_EXTRA=1 (plans/prereg-council-extra-2026-10-02.md):
        # NSW councils that ran their OWN elections (Fairfield every year, 24
        # council-years) are absent from the commission's files. Added only
        # for a (year, council) the commission file lacks.
        xf = 'external/reference/council/nsw-self-run.csv'
        if st == 'nsw' and EXTRA and os.path.exists(xf):
            seen = {(c['year'], cnorm(c['council'])) for k_, rs in CR.items() if k_[0] == 'nsw' for c in rs}
            nx = 0
            for r in csv.DictReader(open(xf, encoding='utf-8')):
                if (r['year'], cnorm(r['council'])) in seen:
                    continue
                r['state'] = 'nsw'
                r['elected'] = 'True' if str(r['elected']).strip().lower() in ('true', '1', 'yes', 'y', 'elected') else 'False'
                gv = gkey((r['given'] or '').split()[0] if r['given'] else '')
                CR[('nsw', nk(r['surname']), gv)].append(r)
                CR[('nsw', nk(r['surname']), '*')].append(r)
                nx += 1
            print(f'CH0x nsw: {nx} rows added from councils that ran their own elections')
    # Federal candidates too (matched against councils in their own state), or
    # council history is a state-versus-federal label. Tas, ACT and NT councils
    # are not collected, so their federal candidates get none (reported).
    S = [r for r in csv.DictReader(open('output/candidacies.csv', encoding='utf-8'))
         if r['region'] in have or r['region'] == 'fed']   # Tas/ACT/NT federal rows kept, coverage False
    nofed = sum(1 for r in csv.DictReader(open('output/candidacies.csv', encoding='utf-8'))
                if r['region'] == 'fed' and (r['state'] or '').lower() not in have)
    print(f'CH0  federal candidacies outside the collected states (Tas/ACT/NT): {nofed}, no council history')
    # AUSPOL_COUNCIL_EXTRA=1: mayors chosen by their councillors are recorded
    # nowhere in the commission files (Regan, Northern Beaches -> Wakehurst
    # 2023, was a "councillor"). A term counts if it began in a year BEFORE the
    # election year and within 10 years, in a council overlapping the seat.
    MY = collections.defaultdict(list)
    mf = 'external/reference/council/mayors.csv'
    if EXTRA and os.path.exists(mf):
        nm = 0
        for r in csv.DictReader(open(mf, encoding='utf-8')):
            try:
                ty = int(str(r['term_start'])[:4])
            except ValueError:
                continue
            st_m = (r['state'] or '').strip().lower()
            MY[(st_m, nk(r['surname']), gkey(nk((r['given'] or '').split()[0] if r['given'] else '')))].append((ty, r['council']))
            nm += 1
        print(f'CH0m {nm} council-chosen mayor terms read from {mf}')
    elif EXTRA:
        print(f'CH0m! {mf} missing -- no council-chosen mayors this run')
    n_mayor_added = 0
    out, amb = [], 0
    # COVERAGE: which council election years exist per state. A candidacy with no
    # council election in its state inside the window has NO DATA, which is not
    # the same as "no council record found" -- council_features() makes it NA
    # rather than 0, or the zeros label old elections and Tas/ACT/NT (review).
    cyears = collections.defaultdict(set)
    for (st_, _s, _g), rows_ in CR.items():
        for c in rows_:
            cyears[st_].add(int(c['year']))
    unmatched_councils = collections.Counter()
    for r in S:
        y = int(r['year'])
        st = r['region'] if r['region'] != 'fed' else (r['state'] or '').lower()
        sur, giv = split_state(r['name'])
        # The corpus carries `surname` and `given` columns for most rows (WA's
        # `name` is a bare surname but `given` is populated for 2,841 of 2,842):
        # prefer them. A surname-only match produced 28% false WA matches
        # (Rebecca Brown -> councillor Gary Brown); review 2026-10-02.
        if (r.get('surname') or '').strip():
            sur = nk(r['surname'])
        if (r.get('given') or '').strip():
            giv = nk(r['given'].split()[0])
        hits = []
        # WA's state corpus records surnames only: match on surname, and only when
        # exactly one person of that surname stood in an overlapping council.
        pool = CR.get((st, sur, gkey(giv)), []) if giv else CR.get((st, sur, '*'), [])
        for c in pool:
            cy = int(c['year'])
            # Queensland's council elections are in March, before any Queensland
            # state (Oct) or federal (May-Sep) election of the same year.
            if not (y - 10 <= cy < y or (st == 'qld' and cy == y)):
                continue
            o = OV.get((r['election'], nk(r['seat'])), {}).get(cnorm(c['council']))
            if o is None and OV.get((r['election'], nk(r['seat']))) and not any(cnorm(c['council']) in OV[k] for k in OV if k[0] == r['election']):
                unmatched_councils[(st, c['council'])] += 1
            if o and (o[0] >= 0.05 or o[1] >= 0.05):
                hits.append(c)
        # one person per (council): different councils in one name = ambiguous;
        # surname-only (WA) also needs a single given name among the hits
        if len({cnorm(h['council']) for h in hits}) > 1 or (not giv and len({nk(h['given']) for h in hits}) > 1):
            amb += 1
            hits = []
        mterms = []
        if giv:
            for ty, mc in MY.get((st, sur, gkey(giv)), []):
                o = OV.get((r['election'], nk(r['seat'])), {}).get(cnorm(mc))
                if y - 10 <= ty < y and o and (o[0] >= 0.05 or o[1] >= 0.05):
                    mterms.append((ty, mc))
        if len({cnorm(m[1]) for m in mterms}) > 1:
            mterms = []
        cov = any((y - 10 <= cy < y) or (st == 'qld' and cy == y) for cy in cyears.get(st, ()))
        rec = dict(election=r['election'], seat=r['seat'], name=r['name'], party=r['party'], council_coverage=cov,
                   council_any=bool(hits), council_elected=any(h['elected'] == 'True' for h in hits),
                   council_mayor=any(h.get('contest') == 'mayor' and h['elected'] == 'True' for h in hits) or bool(mterms),
                   council_pct='', council_year='', council_name='', n_council_runs=len(hits))
        if mterms and not hits:
            # a mayor is an elected councillor even where the ward results are missing
            rec.update(council_any=True, council_elected=True, council_year=str(max(m[0] for m in mterms)),
                       council_name=mterms[0][1])
        if mterms and not any(h.get('contest') == 'mayor' and h['elected'] == 'True' for h in hits):
            n_mayor_added += 1
        if hits:
            last = max(hits, key=lambda h: (int(h['year']), float(h['first_pref_pct'] or 0)))
            rec.update(council_pct=last['first_pref_pct'], council_year=last['year'], council_name=last['council'])
        out.append(rec)
    with open('output/council-history.csv', 'w', newline='', encoding='utf-8') as fo:
        w = csv.DictWriter(fo, fieldnames=list(out[0].keys()))
        w.writeheader()
        w.writerows(out)
    by = collections.Counter((o['election'][:-4], o['council_any'], o['council_elected']) for o in out)
    for st in have + ['fed']:
        n = sum(v for k, v in by.items() if k[0] == st)
        a = sum(v for k, v in by.items() if k[0] == st and k[1])
        e = sum(v for k, v in by.items() if k[0] == st and k[2])
        print(f'CH1  {st}: {n} state candidacies, {a} with council history ({e} elected councillors)')
    print(f'CH2  ambiguous (one name, several councils) dropped: {amb}')
    if EXTRA:
        print(f'CH2m candidacies newly flagged mayor from council-chosen terms: {n_mayor_added}')
    if unmatched_councils:
        print(f'CH3! council names absent from the LGA overlap table (never matchable): {len(unmatched_councils)}, '
              f'e.g. {list(unmatched_councils)[:6]}')
    print('CH9  wrote output/council-history.csv')


if __name__ == '__main__':
    sys.exit(main())
