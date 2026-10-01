"""Federal booth -> WA state district maps WITHOUT boundary files, by venue name.

WA 2001, 2005 and 2013 were fought on district boundaries no GIS file exists for
(the ABS published no state boundaries 2012-2015 and none before 2011 here; the
WA commission publishes PDF maps only). But the WA commission's own results
(external/reference/waec/sg<year>-<code>.json) list every POLLING PLACE in every
district, by venue ("Albany Primary School"), and the AEC's polling-place files
carry each federal booth's venue (PremisesNm). Matching venue to venue places a
federal booth in its state district with no map at all.

Validated where true maps exist (scripts/build_extra_booth_maps.R): booths
matched 98.9% correct for WA 2017 and 97.6% for WA 2025 (exact venue matches
100% in both), and district Senate shares built from the matched booths agree
with the true-map ones to 0.24 / 0.64 points (correlation 0.999 / 0.994). The
two validations rerun every time this script runs.

Also converts the AEC's 1998 Senate votes by polling place (statistics archive,
raw SPPVOTE + SCANDS, booths identified by name only) and the 1998 WA polling-
place list (PPSWA.TXT) into the standard AEC file shapes, with
place_id = "<Division>::<Polling Place>".

Writes external/reference/correspondences/booths-<year>wa.csv for 2001, 2005,
2013 (district, place_id, method), plus pp-fed1998.csv and
senate/fed1998-WA-SPPVOTE.csv.

Run from repo root: python scripts/build_wa_name_maps.py
"""
import collections
import csv
import glob
import json
import re

STOP = {'the', 'of', 'and', 'hall', 'centre', 'center', 'school', 'primary', 'ps', 'community', 'memorial',
        'church', 'club', 'college', 'high', 'senior', 'district', 'sports', 'recreation', 'pavilion', 'inc',
        'uniting', 'anglican', 'catholic', 'st', 'library', 'building', 'room', 'park', 'resource', 'shire',
        'civic', 'public', 'town', 'station', 'campus', 'early', 'learning', 'kindergarten', 'oval',
        'association', 'assoc', 'rsl', 'cwa', 'scout', 'scouts', 'sport', 'citizens'}
B = 'external/reference/aec/booths'
STATS = 'external/reference/aec/stats'


def norm(s):
    return re.sub(r'[^a-z0-9 ]', ' ', (s or '').lower()).split()


def key(s):
    return ' '.join(norm(s))


def toks(s):
    return set(t for t in norm(s) if t not in STOP and len(t) > 1)


def convert_1998():
    """1998 WA polling places and Senate votes into the standard AEC shapes."""
    pps = f'{STATS}/y9398/data/geninfo/tables98/text/PPSWA.TXT'
    rows, div = [], None
    for line in open(pps, encoding='latin-1'):
        f = [x.strip() for x in line.rstrip('\n').split('\t')]
        if len(f) == 1 or (len(f) > 1 and not any(f[1:])):
            if f[0] and not f[0].startswith(('General', 'Polling Places')):
                div = f[0]
            continue
        if f[0] == 'Polling Place Name' or not div:
            continue
        rows.append(['WA', '', div, f'{div}::{f[0]}', '', f[0], f[1] if len(f) > 1 else '', f[2] if len(f) > 2 else '',
                     '', '', f[3] if len(f) > 3 else '', 'WA', ''])
    with open(f'{B}/pp-fed1998.csv', 'w', newline='', encoding='utf-8') as fo:
        fo.write('1998 Federal Election Polling Places (WA, from the AEC statistics archive PPSWA.TXT)\n')
        w = csv.writer(fo)
        w.writerow(['State', 'DivisionID', 'DivisionNm', 'PollingPlaceID', 'PollingPlaceTypeID', 'PollingPlaceNm',
                    'PremisesNm', 'PremisesAddress1', 'PremisesAddress2', 'PremisesAddress3', 'PremisesSuburb',
                    'PremisesStateAb', 'PremisesPostCode'])
        w.writerows(rows)
    # party of each (state, ticket, ballot position); position 0 = the ticket's above-the-line votes
    party, tparty = {}, {}
    for r in csv.DictReader(open(f'{STATS}/y9398/data/import/tables98/SCANDS.TXT', encoding='latin-1'), delimiter=';'):
        party[(r['State'], r['Ticket'], r['Ballot Position'])] = r['Party'] or 'Independent'
        tparty.setdefault((r['State'], r['Ticket']), r['Party'] or 'Independent')
    n = 0
    with open(f'{B}/senate/fed1998-WA-SPPVOTE.csv', 'w', newline='', encoding='utf-8') as fo:
        fo.write('1998 Federal Election Senate First Preferences By Polling Place for WA (AEC statistics archive SPPVOTE)\n')
        w = csv.writer(fo)
        w.writerow(['StateAb', 'DivisionNm', 'PollingPlaceID', 'PollingPlaceNm', 'PartyNm', 'OrdinaryVotes'])
        for r in csv.DictReader(open(f'{STATS}/y9398/data/import/tables98/SPPVOTE.TXT', encoding='latin-1'), delimiter=';'):
            if r['State'] != 'WA':
                continue
            p = tparty.get((r['State'], r['Ticket'])) if r['Ballot Position'] == '0' else party.get((r['State'], r['Ticket'], r['Ballot Position']))
            w.writerow(['WA', r['Division'], f"{r['Division']}::{r['Polling Place']}", r['Polling Place'], PARTY_1998.get(p, p or ''), r['Vote']])
            n += 1
    print(f'WNM0 1998 converted: {len(rows)} WA polling places, {n} WA Senate vote rows')


# 1998 SCANDS uses short party codes; spell out the ones classify_party() needs to see.
PARTY_1998 = {'ALP': 'Australian Labor Party', 'LP': 'Liberal', 'NP': 'National Party', 'GRN': 'The Greens',
              'GWA': 'Greens (WA)', 'AD': 'Australian Democrats', 'HAN': "Pauline Hanson's One Nation",
              'ON': "Pauline Hanson's One Nation", 'CEC': 'Citizens Electoral Council', 'DLP': 'Democratic Labor Party'}


def state_venues(yr):
    st = collections.defaultdict(set)
    for f in glob.glob(f'external/reference/waec/sg{yr}-*.json'):
        if f.endswith('-candidates.json'):
            continue
        d = json.load(open(f, encoding='utf-8'))
        ce = d.get('currentElectorate') or {}
        if ce.get('ElelctorateType') != 'District':
            continue
        for r in d.get('resultsPollingPlace', []):
            if r.get('BREAKDOWN_GROUP') == 'Polling Places' and 'Special' not in r['BREAKDOWN_NAME']:
                st[ce['ElectorateName']].add(r['BREAKDOWN_NAME'])
    return st


def match(yr, fed):
    st = state_venues(yr)
    byname = collections.defaultdict(set)
    for dist, vs in st.items():
        for v in vs:
            byname[key(v)].add(dist)
    rows = list(csv.reader(open(f'{B}/pp-fed{fed}.csv', encoding='utf-8', errors='replace')))
    h = rows[1]
    ix = {c: i for i, c in enumerate(h)}
    fb = [(r[ix['PollingPlaceID']], r[ix['PremisesNm']], r[ix['PremisesSuburb']]) for r in rows[2:]
          if len(r) >= len(h) - 2 and r[ix['State']] == 'WA']
    assign = {}
    for pid, prem, sub in fb:
        k = key(prem)
        if k in byname and len(byname[k]) == 1:
            assign[pid] = (next(iter(byname[k])), 'exact')
            continue
        tp = toks(prem) | toks(sub)
        hits = {dist for dist, vs in st.items() for v in vs if toks(v) and tp and toks(v) <= tp}
        if len(hits) == 1:
            assign[pid] = (hits.pop(), 'fuzzy')
    return st, fb, assign


def main():
    convert_1998()
    for yr, fed in [(2017, 2016), (2025, 2022)]:
        st, fb, a = match(yr, fed)
        truth = {r['place_id']: r['district'] for r in csv.DictReader(open(f'external/reference/correspondences/booths-{yr}wa.csv'))}
        ok = [a[p][0] == truth[p] for p in a if p in truth]
        print(f'WNM1 validation WA {yr}: {len(a)} of {len(fb)} federal booths matched, {100 * sum(ok) / max(1, len(ok)):.1f}% correct against the true map')
    for yr, fed in [(2001, 1998), (2005, 2004), (2013, 2010)]:
        st, fb, a = match(yr, fed)
        out = f'external/reference/correspondences/booths-{yr}wa.csv'
        with open(out, 'w', newline='') as fo:
            w = csv.writer(fo)
            w.writerow(['district', 'place_id', 'method'])
            for pid, (d, m) in sorted(a.items()):
                w.writerow([d, pid, m])
        print(f'WNM2 WA {yr} (fed {fed}): {len(st)} districts, {len(fb)} federal booths, {len(a)} matched '
              f'({sum(1 for x in a.values() if x[1] == "exact")} exact), districts reached {len({d for d, _ in a.values()})} -> {out}')


if __name__ == '__main__':
    main()
