import json, csv, collections

rep = json.load(open('external/reference/aef/2026sa-summary.json'))['report']
names, bands, pmap = rep['seatNames'], rep['seatFpBands'], {i: a for i, a in rep['partyAbbr']}
aef_win = {}
for i, s in enumerate(names):
    aef_win[s] = {pmap.get(idx): v for idx, v in rep['seatPartyWinFrequencies'][i]}

def load(p):
    r = collections.defaultdict(dict)
    for row in csv.DictReader(open(p, encoding='utf-8-sig')):
        r[row['seat']][row['party']] = float(row['votes'])
    return r
a22, b26 = load('external/elections/ecsa-2022-sa-firstprefs.csv'), load('external/elections/ecsa-2026-sa-firstprefs.csv')
def pct(d):
    return {s: {k: 100*v/sum(pv.values()) for k, v in pv.items()} for s, pv in d.items() for pv in [d[s]]}
A, B = pct(a22), pct(b26)
tot = lambda d: sum(sum(v.values()) for v in d.values())
sw = {p: 100*sum(b26[s].get(p,0) for s in b26)/tot(b26) - 100*sum(a22[s].get(p,0) for s in a22)/tot(a22)
      for p in ['ALP','LNP','ONP','GRN','IND']}

# our win probabilities, from the shrink=0.10 run
OURS_WIN = {
 'MacKillop': {'LNP': 0.952, 'ONP': 0.047},
 'Narungga':  {'IND': 0.820, 'ONP': 0.029},
 'Ngadjuri':  {'LNP': 0.793, 'ONP': 0.031},
 'Hammond':   {'LNP': 0.729, 'ONP': 0.025},
}
REN = {'Ngadjuri': 'Frome'}

for seat in ['MacKillop', 'Narungga', 'Ngadjuri', 'Hammond']:
    i = names.index(seat)
    aefp = {}
    for idx, q in bands[i]:
        ab = pmap.get(idx)
        if ab and ab not in aefp:
            aefp[ab] = q[7]
    src = REN.get(seat, seat)
    act = B[seat]
    top3 = [p for p, _ in sorted(act.items(), key=lambda x: -x[1])[:3]]

    print(f'\n{"="*66}\n{seat.upper()}   (One Nation WON)\n{"="*66}')
    print(f'{"":<6}{"PRIMARY VOTE %":^36}   {"WIN PROBABILITY":^20}')
    print(f'{"party":<6}{"ours":>8}{"AEF":>8}{"ACTUAL":>9}{"our err":>10}   {"ours":>7}{"AEF":>7}{"real":>7}')
    print('-'*66)
    for p in top3:
        base = A.get(src, {}).get(p, 0.0)
        ours = max(0.0, base + sw.get(p, 0.0))
        a = act.get(p, 0.0)
        key = 'ON' if p == 'ONP' else p
        aef = aefp.get(key)
        aefs = f'{aef:8.1f}' if aef is not None else f'{"-":>8}'
        ow = OURS_WIN[seat].get(p, 0.0)
        aw = aef_win[seat].get(key, 0.0) / 100 if aef_win[seat].get(key) else 0.0
        real = 1.0 if p == 'ONP' else 0.0
        print(f'{p:<6}{ours:8.1f}{aefs}{a:9.1f}{ours-a:+10.1f}   {ow:7.3f}{aw:7.3f}{real:7.0f}')
