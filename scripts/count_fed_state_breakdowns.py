# Count federal polls' state breakdowns per STATE election cycle, per source, and compare the last 90 days of them
# with the state's own polls and the result. Read-only; writes nothing. Data inspection for
# docs/plans/prereg-fed-breakdowns-in-trend-2026-10-26.md (no model code).
#
#   python scripts/count_fed_state_breakdowns.py [ROOT]
#
# ROOT is a checkout that holds external/reference/polls/ and output/ (default "."; a worktree without the
# gitignored data can point at the main checkout read-only). Sources read:
#   output/fed-state-breakdowns.csv                     what the shipped blend reads (Wikipedia; ALP, LNP, GRN)
#   external/reference/polls/statewide-samples/statewide_polls_wiki.csv   the Wikipedia tables it is built from
#   external/reference/polls/state-federal/state-federal-polls.csv        scope == "state" (hand-verified)
#   external/reference/polls/newspoll-quarterly/breakdowns.csv            dimension == "state"
#   external/reference/polls/pollbludger/bludgertrack_polls.csv           section "federal", state scopes
#   output/level-recent.csv                             state polls' 28-day mean and the result
# The union counts a poll once per (state, firm, fieldwork end within 3 days); firm names are compared on their
# first six letters, so the union is approximate. Results rows (firm "Election") are dropped.
import csv, collections, datetime as dt, re, sys
csv.field_size_limit(10**9)
R = (sys.argv[1] if len(sys.argv) > 1 else '.').replace(chr(92), '/').rstrip('/') + '/'
P = R + 'external/reference/polls/'
D = lambda s: dt.date.fromisoformat(s[:10]) if s and re.match(r'^\d{4}-\d{2}-\d{2}', s) else None
def num(x):
    try: return float(str(x).replace('%', '').strip())
    except: return None

# ---- election cycles ---------------------------------------------------------------------------
eds = list(csv.DictReader(open(P + 'statewide-samples/election_dates.csv')))
cyc = collections.defaultdict(list)
for e in eds: cyc[e['region']].append((D(e['election_date']), e['election']))
for k in cyc: cyc[k].sort()
TODAY = dt.date.today()   # live cycles are counted up to today
def cycle_of(st, end):
    lst = cyc.get(st, [])
    for i in range(1, len(lst)):
        if lst[i-1][0] < end <= lst[i][0] or (lst[i][0] > TODAY and lst[i-1][0] < end): return lst[i][1], lst[i][0]
    return None, None

STN = {"New South Wales": "nsw", "Victoria": "vic", "Queensland": "qld", "Western Australia": "wa",
       "South Australia": "sa", "Tasmania": "tas"}
rows = []   # dict(src, st, end, mid, firm, ALP, LNP, GRN, ONP, n)

# ---- W: Wikipedia federal "Sub-national polling" tables (the source fed_state_breakdowns_parse reads) ----
w = csv.DictReader(open(P + 'statewide-samples/statewide_polls_wiki.csv', encoding='utf-8'))
nw = collections.Counter()
for r in w:
    if r['region'] != 'fed' or not r['section'].startswith('Sub-national polling > ') : continue
    nw[r['row_type']] += 1
    if r['row_type'] != 'poll': continue
    st = STN.get(re.sub(r' >.*', '', r['section'][len('Sub-national polling > '):]))
    fe, fs = D(r['fieldwork_end']), D(r['fieldwork_start'])
    if st is None or fe is None or num(r['alp_fp']) is None: continue
    mid = fs + (fe - fs) // 2 if fs and fs <= fe else fe
    lnp = num(r['lnp_fp'])
    if lnp is None and (num(r['lib_fp']) is not None or num(r['nat_fp']) is not None):
        lnp = (num(r['lib_fp']) or 0) + (num(r['nat_fp']) or 0)
    grn = max([v for v in (num(r.get(c)) for c in ('pv_Grn', 'pv_GRN', 'pv_Green', 'pv_Gre')) if v is not None], default=None)
    onp = max([v for v in (num(r.get(c)) for c in ('pv_ONP', 'pv_ON')) if v is not None], default=None)
    rows.append(dict(src='wiki', st=st, end=fe, mid=mid, firm=r['firm'] or r['firm_raw'], ALP=num(r['alp_fp']),
                     LNP=lnp, GRN=grn, ONP=onp, n=num(r['sample_n'])))
print('WIKI sub-national row types', dict(nw))

# ---- S: state-federal-polls.csv, scope == state ------------------------------------------------
for r in csv.DictReader(open(P + 'state-federal/state-federal-polls.csv', encoding='utf-8')):
    if r['scope'] != 'state': continue
    fe, fs = D(r['fieldwork_end']), D(r['fieldwork_start'])
    if fe is None: continue
    onp = None
    m = re.search(r'ONP=([\d.]+)', r['extra_fp'] or '')
    if m: onp = float(m.group(1))
    rows.append(dict(src='statefed', st=r['state'], end=fe, mid=fs + (fe - fs) // 2 if fs and fs <= fe else fe,
                     firm=r['pollster'], ALP=num(r['alp_fp']), LNP=num(r['lnp_fp']), GRN=num(r['grn_fp']), ONP=onp,
                     n=num(r['sample_n'])))

# ---- N: Newspoll quarterly state breakdowns -----------------------------------------------------
nq = collections.defaultdict(dict)
for r in csv.DictReader(open(P + 'newspoll-quarterly/breakdowns.csv', encoding='utf-8')):
    if r['dimension'] != 'state': continue
    st = r['group'].lower()
    if st not in ('nsw', 'vic', 'qld', 'wa', 'sa', 'tas'): continue
    key = (st, r['period_start'], r['period_end'], r['published'])
    nq[key]['n'] = num(r['sample_n'])
    nq[key][r['party']] = num(r['fp'])
    nq[key].setdefault('tpp', num(r['tpp_alp']))
for (st, ps, pe, pub), v in nq.items():
    fe = D(pe) or D(pub); fs = D(ps)
    rows.append(dict(src='newspollq', st=st, end=fe, mid=fs + (fe - fs) // 2 if fs and fs <= fe else fe, firm='Newspoll',
                     ALP=v.get('ALP'), LNP=v.get('LNP'), GRN=v.get('GRN'), ONP=v.get('ONP'), n=v.get('n')))

# ---- BT: BludgerTrack federal tables, state scopes ---------------------------------------------
for r in csv.DictReader(open(P + 'pollbludger/bludgertrack_polls.csv', encoding='utf-8')):
    if r['section'] != 'federal' or r['scope'] not in ('VIC', 'NSW', 'QLD', 'WA', 'SA', 'TAS'): continue
    fe, fs = D(r['end_date'] or r['end']), D(r['start_date'] or r['start'])
    if fe is None: continue
    onp = num(r['ONP']) if num(r['ONP']) is not None else num(r['PHON'])
    rows.append(dict(src='bludgertrack', st=r['scope'].lower(), end=fe, mid=fs + (fe - fs) // 2 if fs and fs <= fe else fe,
                     firm=r['pollster'], ALP=num(r['ALP']), LNP=num(r['LNC']), GRN=num(r['GRN']), ONP=onp, n=num(r['sample'])))

# ---- the shipped file the blend reads ----------------------------------------------------------
for r in csv.DictReader(open(R + 'output/fed-state-breakdowns.csv')):
    rows.append(dict(src='shipped', st=r['st'], end=D(r['end']), mid=D(r['date']), firm=r['firm'], ALP=num(r['ALP']),
                     LNP=num(r['LNP']), GRN=num(r['GRN']), ONP=None, n=None))

# ---- per state cycle ---------------------------------------------------------------------------
fk = lambda f: re.sub(r'[^a-z]', '', (f or '').lower())[:6]
by = collections.defaultdict(list)
for r in rows:
    if r['end'] is None or r['ALP'] is None and r['LNP'] is None: continue
    if (r['firm'] or '').strip().lower() in ('election', 'result', 'federal election'): continue  # results, not polls
    e, edate = cycle_of(r['st'], r['end'])
    if e is None: continue
    r['e'] = e; r['edate'] = edate
    by[e].append(r)

srcs = ['shipped', 'wiki', 'statefed', 'newspollq', 'bludgertrack']
print('\nFederal breakdown polls per STATE cycle (fieldwork end after the previous state election, up to polling day).')
print('Columns: rows per source; UNION = distinct polls across all five (state, firm, end date within 3 days);')
print('last365/180/90/28 = union polls whose fieldwork ended that many days before polling day (live: before today);')
print('ONP = union polls with a One Nation figure; n = with a sample size; first/last = fieldwork end range.\n')
hdr = ['cycle'] + srcs + ['UNION', 'last365', 'last180', 'last90', 'last28', 'ONP', 'n', 'first', 'last']
print('|' + '|'.join(hdr) + '|'); print('|' + '|'.join(['---'] * len(hdr)) + '|')
order = sorted(by, key=lambda e: (re.sub(r'\d', '', e), e))
def union(lst):
    pref = {'statefed': 0, 'bludgertrack': 1, 'wiki': 2, 'shipped': 3, 'newspollq': 4}
    out = []
    for r in sorted(lst, key=lambda r: pref[r['src']]):
        dup = None
        for u in out:
            if fk(u['firm']) == fk(r['firm']) and abs((u['end'] - r['end']).days) <= 3: dup = u; break
        if dup is None: out.append(dict(r))
        else:
            for k in ('ONP', 'n', 'LNP', 'GRN'):
                if dup.get(k) is None and r.get(k) is not None: dup[k] = r[k]
    return out
tot = collections.Counter()
for e in order:
    if e.startswith('fed'): continue
    lst = by[e]
    c = collections.Counter(r['src'] for r in lst)
    u = union(lst)
    ref = min(by[e][0]['edate'], TODAY)
    l90 = sum(1 for r in u if (ref - r['end']).days <= 90)
    l28 = sum(1 for r in u if (ref - r['end']).days <= 28)
    l180 = sum(1 for r in u if (ref - r['end']).days <= 180); l365 = sum(1 for r in u if (ref - r['end']).days <= 365)
    onp = sum(1 for r in u if r.get('ONP') is not None)
    nn = sum(1 for r in u if r.get('n') is not None)
    first = min(r['end'] for r in u); last = max(r['end'] for r in u)
    print('|' + '|'.join([e] + [str(c.get(s, 0)) for s in srcs] + [str(len(u)), str(l365), str(l180), str(l90), str(l28), str(onp), str(nn), str(first), str(last)]) + '|')
    tot['UNION'] += len(u)
print('\nstate cycles with ZERO federal breakdowns are absent from the table.')
# firms per cycle in the union
print('\nFirms per cycle (union):')
for e in order:
    if e.startswith('fed'): continue
    u = union(by[e])
    print(e, dict(collections.Counter(r['firm'] for r in u).most_common(8)))
# earliest breakdown of any source, by state
print('\nEarliest breakdown by state, any source:', {s: str(min(r['end'] for r in rows if r['st'] == s and r['end'])) for s in sorted(set(r['st'] for r in rows))})

# ---- is the federal-to-state offset zero? last-90-day breakdown mean vs state polls (28-day) vs result ----
lr = collections.defaultdict(dict)
for r in csv.DictReader(open(R + 'output/level-recent.csv')):
    lr[r['election']][r['cls']] = (float(r['actual']), float(r['avg28']) if r['avg28'] not in ('', 'NA') else None, r['n28'])
print('\nOffset check, points. fed90 = mean of federal breakdowns ending in the 90 days before polling day (union);')
print('st28 = mean of the state\'s own polls in the last 28 days (output/level-recent.csv); act = state result.')
print('|cycle|party|n fed90|fed90|st28|act|fed90 - act|st28 - act|')
print('|---|---|---|---|---|---|---|---|')
for e in ['vic2022', 'nsw2023', 'qld2024', 'wa2025', 'sa2026', 'qld2020', 'sa2022', 'wa2021']:
    if e not in by: continue
    u = union(by[e]); ref = by[e][0]['edate']
    u90 = [r for r in u if (ref - r['end']).days <= 90]
    for k in ('ALP', 'LNP', 'GRN'):
        v = [r[k] for r in u90 if r.get(k) is not None]
        a = lr.get(e, {}).get(k)
        if a is None: continue
        f = sum(v) / len(v) if v else None
        fs = f'{f:.1f}' if f is not None else '-'
        s28 = f'{a[1]:.1f}' if a[1] is not None else '-'
        d1 = f'{f - a[0]:+.1f}' if f is not None else '-'
        d2 = f'{a[1] - a[0]:+.1f}' if a[1] is not None else '-'
        print(f'|{e}|{k}|{len(v)}|{fs}|{s28}|{a[0]:.1f}|{d1}|{d2}|')
