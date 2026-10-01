"""Notional prior results for STATE elections, on the NEXT election's boundaries.

WHY. A district redrawn or renamed by a redistribution has no prior result under
its new name, so the state harnesses skip it (vic2014 scores 73 of 88 seats,
vic2022 78, wa2008 38 of 59), and a redrawn district that keeps its name is
swung from a prior result on boundaries it no longer has. The federal harness
solved this with scripts/build_notional_baselines.R (AEC polling-place ids);
state commissions publish no stable booth id, so this matches by VENUE NAME.

HOW (Antony Green's booth-respread, the federal method):
  1. Each ordinary polling place at the PRIOR election is placed in the
     TARGET-election district where a polling place of the same normalised name
     sits. A name found in two target districts, or none, is unmatched.
  2. Matched booths carry their own party votes to their target district.
  3. Each prior district's REMAINING votes (unmatched booths plus postal,
     early, absent and other declaration votes) are spread over target
     districts in proportion to where its matched ordinary votes went.
  4. A prior district with no matched booth at all is reported and dropped.
Party classes come from output/candidacies.csv (one source of truth, the
classifier the harnesses use), matched to booth candidates by surname within
the district, falling back to the candidate's total votes.

Reads output/booths/<election>-booth-fp.csv (scripts/parse_booths_*.py).
Writes external/elections/notional/<region>-<to>-from-<from>-firstprefs.csv
with seat,party,votes (the harness prior-file shape) plus per-seat coverage in
...-coverage.csv. Self-check every run: on a pair with NO redistribution the
notional must reproduce the actual prior result (printed as NB-S rows).

Run from repo root: python scripts/build_state_notionals.py
"""
import collections
import csv
import os
import re
import sys

BOOTHS = 'output/booths'
OUT = 'external/elections/notional'
# (region, from, to): every backtest pair with booth data at both ends.
PAIRS = [('vic', 2010, 2014), ('vic', 2014, 2018), ('vic', 2018, 2022), ('vic', 2022, 2026),
         ('nsw', 2015, 2019), ('nsw', 2019, 2023),
         ('qld', 2017, 2020), ('qld', 2020, 2024),
         ('sa', 2018, 2022), ('sa', 2022, 2026),
         ('wa', 2005, 2008), ('wa', 2008, 2013), ('wa', 2013, 2017), ('wa', 2017, 2021), ('wa', 2021, 2025)]
# Pairs fought on unchanged boundaries: the notional must equal the actual prior.
SAME_BOUNDARIES = {('vic', 2014, 2018), ('vic', 2022, 2026), ('nsw', 2015, 2019),
                   ('qld', 2017, 2020), ('qld', 2020, 2024)}


def norm(s):
    s = (s or '').lower().replace('&', ' and ')
    s = re.sub(r'\b(ps|p s)\b', 'primary school', s)
    return ' '.join(re.sub(r'[^a-z0-9 ]', ' ', s).split())


def seat_key(s):
    return re.sub(r'[^a-z]', '', (s or '').lower())


EARLY = re.compile(r'(?i)pre-?poll|early voting|all-districts')
# Booth pages known to be wrong at source. The VEC's file store serves the 2014
# Brunswick contest (Garrett, Vellotti) as the 2018 page; its rows are dropped,
# and the district's votes come from the district results file instead.
BAD_PAGES = {('vic2018', 'Brunswick')}
# Districts whose general election was held late as a supplementary election and
# so have no booth rows in the general-election file. They are still target
# districts: the harness scores them from external/reference/byelections/
# (Narracan 2022: candidate died, poll held 28 January 2023).
SUPPLEMENTARY = {('vic', 2022): ['Narracan']}
DISTRICT_FILE = {'vic': 'vec-{y}-vic-firstprefs.csv', 'nsw': 'nswec-{y}-nsw-firstprefs.csv',
                 'qld': 'ecq-{y}-qld-firstprefs.csv', 'sa': 'ecsa-{y}-sa-firstprefs.csv',
                 'wa': 'waec-{y}-wa-firstprefs.csv'}


def district_file(rg, y):
    # SA 2018 has no ECSA district file; the harness reads the Wikipedia one.
    if (rg, int(y)) == ('sa', 2018):
        return 'external/elections/wikipedia-2018-sa-firstprefs.csv'
    return 'external/elections/' + DISTRICT_FILE[rg].format(y=y)


def district_table(rg, y):
    out = collections.defaultdict(collections.Counter)
    for r in csv.DictReader(open(district_file(rg, y), encoding='utf-8')):
        out[seat_key(r['seat'])][r['party']] += int(float(r['votes']))
    return out


def reconcile(cls, rows, rg, y):
    """Relabel candidates so each district's class totals equal the district
    results file the harnesses score against. The corpus and those files
    classify some parties differently (WA 2005: all 5.2% of minor-right votes
    were "other" in the corpus), and a notional whose classes disagree with the
    harness's own prior trains the xgb layer on mislabelled rows (2026-10-01:
    vic2014's as-at model moved Malvern's Coalition from 57.0 to 47.6).
    Two passes. First, every candidate whose corpus class appears in the
    district file, with room left, keeps it. Then the rest, largest first, fill
    whichever class still has the largest shortfall (WA Armadale 2005: the CDP,
    Family First and CEC candidates, "other" in the corpus, together make the
    file's 2,166 minor-right votes exactly). A one-pass greedy that sent each
    leftover to the class with the nearest remaining total relabelled the
    Greens candidate One Nation. Returns the relabelled map and the count."""
    T = district_table(rg, y)
    tot = collections.Counter()
    for r in rows:
        tot[(r['district'], r['candidate'], r['party_raw'])] += int(r['votes'])
    out, moved, unreconciled = dict(cls), 0, []
    by_d = collections.defaultdict(list)
    for k, v in tot.items():
        by_d[k[0]].append((v, k))
    for d, cands in by_d.items():
        room = collections.Counter(T.get(seat_key(d), {}))
        if not room:
            unreconciled.append(d)
            continue
        left = []
        for v, k in sorted(cands, reverse=True):
            c = cls[k]
            if c in room and room[c] >= 0.98 * v - 2:
                room[c] -= v
            else:
                left.append((v, k))
        for v, k in left:
            alt = max(room, key=lambda q: room[q])
            out[k] = alt
            room[alt] -= v
            moved += 1
    return out, moved, unreconciled


def district_classes(rg, y, district):
    f = district_file(rg, y)
    out = collections.Counter()
    for r in csv.DictReader(open(f, encoding='utf-8')):
        if seat_key(r['seat']) == seat_key(district):
            out[r['party']] += int(float(r['votes']))
    return out


def read_booths(el):
    f = f'{BOOTHS}/{el}-booth-fp.csv'
    if not os.path.exists(f):
        return None
    rows = [r for r in csv.DictReader(open(f, encoding='utf-8')) if (el, r['district']) not in BAD_PAGES]
    # Queensland 2017 files its pre-poll centres as ordinary booths; they are
    # not polling places with a home district, so treat them as declaration votes.
    for r in rows:
        if r['vote_type'] == 'ordinary' and EARLY.search(r['booth']):
            r['vote_type'] = 'early'
    return rows


def read_corpus():
    C = collections.defaultdict(list)
    for r in csv.DictReader(open('output/candidacies.csv', encoding='utf-8')):
        C[(r['election'], seat_key(r['seat']))].append(r)
    return C


def _sur(name):
    name = name or ''
    return norm(name.split(',')[0] if ',' in name else (name.split() or [''])[0])


def classify(rows, el, corpus):
    """party class per (district, candidate) from the corpus; returns map and unmatched count."""
    tot = collections.Counter()
    for r in rows:
        tot[(r['district'], r['candidate'], r['party_raw'])] += int(r['votes'])
    out, miss = {}, []
    for (d, cand, praw), v in tot.items():
        cs = corpus.get((el, seat_key(d)), [])
        # State rows carry an empty `surname`; the name is "SURNAME, Given" or
        # "SURNAME Given" in both files, so compare the full name, then the
        # surname token, and only then the vote total (which fails in a close
        # contest: Katos 18,180 v Cheeseman 18,003).
        hit = [c for c in cs if norm(c['name']) == norm(cand)]
        if len(hit) != 1:   # word order differs by source ("Andy Gilfillan" v "GILFILLAN Andy")
            hit = [c for c in cs if set(norm(c['name']).split()) == set(norm(cand).split())]
        if len(hit) != 1:
            hit = [c for c in cs if _sur(c['name']) and _sur(c['name']) == _sur(cand)]
        if len(hit) != 1:
            hit = [c for c in cs if abs(int(float(c['votes'] or 0)) - v) <= max(2, 0.01 * v)]
        if len(hit) == 1:
            out[(d, cand, praw)] = hit[0]['party']
        else:
            out[(d, cand, praw)] = 'IND' if not cs else 'OTH'
            miss.append((d, cand, v))
    return out, miss


def main():
    os.makedirs(OUT, exist_ok=True)
    corpus = read_corpus()
    bad = False
    for rg, fy, ty in PAIRS:
        A, B = read_booths(f'{rg}{fy}'), read_booths(f'{rg}{ty}')
        if A is None or B is None:
            # Only a target whose election has not happened yet may be missing.
            # Anything else is FATAL: on 2026-10-01 output/booths/ was moved aside
            # and this script skipped every pair and still exited 0.
            future = B is None and A is not None and ty >= 2026 and not os.path.exists(f'{BOOTHS}/{rg}{ty}-booth-fp.csv')
            print(f'NBS!  {rg}{fy}->{ty}: booth file missing ({"prior" if A is None else "target"}) -- '
                  + ('skipped (election not yet held)' if future else 'FATAL'))
            if not future:
                bad = True
            continue
        cls, miss = classify(A, f'{rg}{fy}', corpus)
        cls, relab, unrec = reconcile(cls, A, rg, fy)
        if unrec:
            # a prior district missing from the district file keeps corpus labels
            # that may disagree with the harness's classes -- the bug this exists for
            print(f'NBS!  {rg}{fy}: {len(unrec)} booth district(s) absent from the district file, NOT reconciled: {unrec[:5]}')
            bad = True
        mv = sum(v for *_, v in miss)
        # target venue -> districts
        tgt = collections.defaultdict(set)
        for r in B:
            # votes > 0: the Queensland files list every booth under every
            # district, most with zero votes, which would make every venue ambiguous
            if r['vote_type'] == 'ordinary' and int(r['votes']) > 0:
                tgt[norm(r['booth'])].add(r['district'])
        tdists = sorted({r['district'] for r in B} | {d for e, d in BAD_PAGES if e == f'{rg}{ty}'}
                        | set(SUPPLEMENTARY.get((rg, ty), [])))
        # A target district with no polling-place rows (a recount page with only an
        # "all votes" total: Prahran 2014, Ripon 2018) can receive nothing by venue,
        # so its same-name prior district goes to it whole.
        boothless = {seat_key(D): D for D in tdists
                     if not any(r['district'] == D and r['vote_type'] == 'ordinary' and int(r['votes']) > 0 for r in B)}
        # 1-2: matched booth votes; remaining votes per prior district
        moved = collections.defaultdict(lambda: collections.Counter())   # (d, D) -> party votes
        rest = collections.defaultdict(collections.Counter)               # d -> party votes
        byname = byname_ord = 0
        for r in A:
            p = cls[(r['district'], r['candidate'], r['party_raw'])]
            v = int(r['votes'])
            if seat_key(r['district']) in boothless:
                moved[(r['district'], boothless[seat_key(r['district'])])][p] += v
                byname += v
                byname_ord += v if r['vote_type'] == 'ordinary' else 0
                continue
            dd = tgt.get(norm(r['booth'])) if r['vote_type'] == 'ordinary' else None
            # a venue shared by two target districts (Robina: Mermaid Beach and
            # Mudgeeraba) stays in the prior district's own name if that is one of them
            if dd and len(dd) > 1:
                own = [D for D in dd if seat_key(D) == seat_key(r['district'])]
                dd = set(own) if own else dd
            if dd and len(dd) == 1:
                moved[(r['district'], next(iter(dd)))][p] += v
            else:
                rest[r['district']][p] += v
        for e, d in BAD_PAGES:
            if e == f'{rg}{fy}':
                same = [D for D in tdists if seat_key(D) == seat_key(d)]
                if same:
                    _dc = district_classes(rg, fy, d)
                    moved[(d, same[0])].update(_dc)
                    byname += sum(_dc.values())
                print(f'NBS2  {rg}{fy} {d}: booth page wrong at source; district totals sent whole to {same or "NOTHING"}')
        # 3: spread the rest by where each prior district's matched votes went
        N = collections.defaultdict(collections.Counter)
        src = collections.defaultdict(collections.Counter)                # D -> d -> votes (coverage)
        for (d, D), pv in moved.items():
            N[D].update(pv)
            src[D][d] += sum(pv.values())
        dropped = []
        for d, pv in rest.items():
            outs = {D: sum(c.values()) for (dd, D), c in moved.items() if dd == d}
            tot = sum(outs.values())
            if not tot:
                # No polling-place rows to place it by (Prahran 2014 and Ripon
                # 2018: the VEC page has only an "all votes" total after a recount).
                # Send it whole to the target district of the same name, if any.
                same = [D for D in tdists if seat_key(D) == seat_key(d)]
                dropped.append((d, sum(pv.values()), same[0] if same else None))
                if not same:
                    print(f'NBS!  {rg}{fy} {d}: no booth matched and no same-name target district -- {sum(pv.values())} votes LOST')
                    bad = True
                    continue
                outs, tot = {same[0]: 1.0}, 1.0
            for D, w in outs.items():
                for p, v in pv.items():
                    N[D][p] += v * w / tot
                src[D][d] += sum(pv.values()) * w / tot
        allv = sum(int(r['votes']) for r in A)
        ordv = sum(int(r['votes']) for r in A if r['vote_type'] == 'ordinary')
        matched = sum(sum(c.values()) for c in moved.values()) - byname
        ordv -= byname_ord
        f = f'{OUT}/{rg}-{ty}-from-{fy}-firstprefs.csv'
        with open(f, 'w', newline='') as fo:
            w = csv.writer(fo)
            w.writerow(['seat', 'party', 'votes'])
            for D in tdists:
                for p, v in sorted(N[D].items()):
                    w.writerow([D, p, round(v)])
        with open(f.replace('-firstprefs.csv', '-coverage.csv'), 'w', newline='') as fo:
            w = csv.writer(fo)
            w.writerow(['seat', 'notional_votes', 'same_name_share', 'top_source', 'top_source_share', 'n_sources'])
            for D in tdists:
                s = src[D]
                t = sum(s.values())
                top = s.most_common(1)[0] if s else ('', 0)
                same = sum(v for d, v in s.items() if seat_key(d) == seat_key(D))
                w.writerow([D, round(t), round(same / t, 4) if t else '', top[0], round(top[1] / t, 4) if t else '', len(s)])
        empty = [D for D in tdists if not N[D]]
        # The notional's statewide class shares must equal the actual prior's:
        # respreading moves votes between districts, never between classes.
        T = district_table(rg, fy)
        tA, tN = collections.Counter(), collections.Counter()
        for c in T.values():
            tA.update(c)
        for c in N.values():
            tN.update(c)
        sa, sn = sum(tA.values()), sum(tN.values())
        cdev = max(abs(100 * tA.get(q, 0) / sa - 100 * tN.get(q, 0) / sn) for q in set(tA) | set(tN))
        print(f'NBS3  {rg} {fy}->{ty}: largest statewide class-share gap, notional v district file: {cdev:.2f} pts')
        if cdev > 0.25:
            bad = True
        print(f'NBS1  {rg} {fy}->{ty}: {len(tdists)} target districts ({len(boothless)} with no booth rows, filled by name: {sorted(boothless.values())}), {len(empty)} with no notional '
              f'{empty[:5]}; ordinary votes matched to a target booth {100 * matched / ordv:.1f}% (ordinary = {100 * ordv / allv:.0f}% of all); '
              f'prior districts with no booth rows {[(d, D or 'DROPPED') for d, _, D in dropped]}; candidates unclassified {len(miss)} ({100 * mv / allv:.2f}% of votes), relabelled to the district file {relab} -> {f}')
        if empty or 100 * mv / allv > 1:
            bad = True
        # VOTE CONSERVATION: respreading moves votes, never creates or loses them.
        if abs(sn - sa) > 0.001 * sa:
            print(f'NBS!  {rg} {fy}->{ty}: notional holds {sn:.0f} votes against {sa:.0f} in the district file')
            bad = True
        if (rg, fy, ty) in SAME_BOUNDARIES:
            act = collections.defaultdict(collections.Counter)
            for r in A:
                act[r['district']][cls[(r['district'], r['candidate'], r['party_raw'])]] += int(r['votes'])
            errs = []
            for D in tdists:
                a = {k: v for k, v in act.get(D, {}).items()}
                ta, tn = sum(a.values()), sum(N[D].values())
                if not ta or not tn:
                    continue
                e = max(abs(100 * a.get(p, 0) / ta - 100 * N[D].get(p, 0) / tn) for p in set(a) | set(N[D]))
                errs.append((e, D))
            errs.sort(reverse=True)
            # A check over nothing passes: require it to have compared nearly every seat.
            if len(errs) < 0.9 * len(tdists):
                print(f'NB-S! {rg} {fy}->{ty}: compared only {len(errs)} of {len(tdists)} seats')
                bad = True
            mean = sum(e for e, _ in errs) / max(1, len(errs))
            print(f'NB-S  {rg} {fy}->{ty} (same boundaries): largest party-share error per seat over {len(errs)} seats, mean {mean:.2f} pts, '
                  f'worst {[(D, round(e, 2)) for e, D in errs[:3]]}')
            if mean > 1.0:
                bad = True
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
