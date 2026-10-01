# Do state notionals (scripts/build_state_notionals.py) beat the raw prior result?
# For every redistribution pair: mean absolute error of ALP/LNP/GRN seat shares
# after a uniform statewide swing, raw prior v notional, plus the renamed seats
# only the notional can score. Run from repo root: python scripts/eval_state_notionals.py
import csv, collections, re, statistics as st
sk = lambda s: re.sub(r'[^a-z]', '', s.lower())
DF = {'vic': 'vec-{y}-vic-firstprefs.csv', 'nsw': 'nswec-{y}-nsw-firstprefs.csv', 'qld': 'ecq-{y}-qld-firstprefs.csv',
      'sa': 'ecsa-{y}-sa-firstprefs.csv', 'wa': 'waec-{y}-wa-firstprefs.csv'}
def load(f):
    d = collections.defaultdict(collections.Counter)
    for r in csv.DictReader(open(f, encoding='utf-8')):
        d[sk(r['seat'])][r['party']] += float(r['votes'])
    return {s: {p: 100 * v / sum(c.values()) for p, v in c.items()} for s, c in d.items() if sum(c.values())}
def state(d):
    t = collections.Counter()
    for c in d.values(): t.update(c)
    n = len(d); return {p: v / n for p, v in t.items()}
MAJ = ['ALP', 'LNP', 'GRN']
print("Mean absolute error of each major party's seat share after statewide swing (points, lower is better)")
print(f"{'pair':<14}{'renamed':>8}{'same-name':>10}  {'raw prior':>9}{'notional':>9}  {'renamed: notional':>18}")
for rg, fy, ty in [('vic',2010,2014),('vic',2018,2022),('nsw',2019,2023),('sa',2018,2022),('sa',2022,2026),
                   ('wa',2005,2008),('wa',2008,2013),('wa',2013,2017),('wa',2017,2021),('wa',2021,2025)]:
    try:
        A = load('external/elections/' + DF[rg].format(y=fy)); T = load('external/elections/' + DF[rg].format(y=ty))
    except FileNotFoundError as e:
        print(rg, fy, ty, 'missing', e.filename); continue
    N = load(f'external/elections/notional/{rg}-{ty}-from-{fy}-firstprefs.csv')
    sA, sT, sN = state(A), state(T), state(N)
    def err(prior, sp, s):
        return st.mean(abs(T[s].get(p, 0) - (prior.get(p, 0) + sT.get(p, 0) - sp.get(p, 0))) for p in MAJ)
    same = [s for s in T if s in A and s in N]; ren = [s for s in T if s not in A and s in N]
    eA = st.mean(err(A[s], sA, s) for s in same); eN = st.mean(err(N[s], sN, s) for s in same)
    eR = st.mean(err(N[s], sN, s) for s in ren) if ren else float('nan')
    print(f"{rg}{fy}->{ty:<6}{len(ren):>8}{len(same):>10}  {eA:9.2f}{eN:9.2f}  {eR:18.2f}")
