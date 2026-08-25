import json, csv

d = json.load(open('external/reference/aef/2026sa-summary.json'))['report']
names = d['seatNames']
bands = d['seatFpBands']
pmap = {i: a for i, a in d['partyAbbr']}
actual = json.load(open('external/reference/aef/2026sa-results.json'))['results']['seats']

# ours: 2022 seat share + uniform statewide swing, the configuration the
# harness actually runs (no concentration arm)
import collections
def load(p):
    r = collections.defaultdict(dict)
    for row in csv.DictReader(open(p, encoding='utf-8-sig')):
        r[row['seat']][row['party']] = float(row['votes'])
    return r
a22 = load('external/elections/ecsa-2022-sa-firstprefs.csv')
b26 = load('external/elections/ecsa-2026-sa-firstprefs.csv')
def pct(d_):
    out = {}
    for s, pv in d_.items():
        t = sum(pv.values())
        out[s] = {k: 100*v/t for k, v in pv.items()}
    return out
A, B = pct(a22), pct(b26)
sw = {}
for p in ['ALP', 'LNP', 'ONP', 'GRN']:
    ta = sum(a22[s].get(p, 0) for s in a22); tb = sum(b26[s].get(p, 0) for s in b26)
    sa = sum(sum(v.values()) for v in a22.values()); sb = sum(sum(v.values()) for v in b26.values())
    sw[p] = 100*tb/sb - 100*ta/sa

REN = {'Ngadjuri': 'Frome'}
TGT = ['MacKillop', 'Narungga', 'Ngadjuri', 'Hammond']
PAR = ['ALP', 'LNP', 'ONP', 'GRN']

print(f"{'seat':<11}{'party':<6}{'2022':>7}{'OURS':>8}{'AEF':>8}{'ACTUAL':>8}   {'our err':>8}{'AEF err':>8}")
print('-'*72)
for s in TGT:
    i = names.index(s)
    aefp = {}
    for idx, q in bands[i]:
        ab = pmap.get(idx)
        if ab:
            aefp[ab] = q[7]          # median of the 15 quantiles
    src = REN.get(s, s)
    for p in PAR:
        base = A.get(src, {}).get(p, 0.0)
        ours = max(0.0, base + sw[p])
        act = B.get(s, {}).get(p, 0.0)
        key = 'ON' if p == 'ONP' else p
        aef = aefp.get(key)
        aef_s = f"{aef:8.1f}" if aef is not None else f"{'-':>8}"
        aef_e = f"{aef-act:+8.1f}" if aef is not None else f"{'-':>8}"
        print(f"{s:<11}{p:<6}{base:7.1f}{ours:8.1f}{aef_s}{act:8.1f}   {ours-act:+8.1f}{aef_e}")
    print()
