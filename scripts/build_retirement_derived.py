"""Derive 'the sitting member did not recontest' from output/candidacies.csv.

WHY THIS EXISTS. scripts/fit_xgb_primary_v6.R:305 takes `retirement` from
load_seats(), i.e. the external anchor clone, which only ships seat files for
recent elections. The column is therefore 0 on ELEVEN of twenty-three pairs --
every federal pair to 2016, qld2020, vic2014, vic2018 and every WA pair before
2025 -- while being ~20% populated on the rest. A column that is constant
within a subgroup is a LABEL for that subgroup and a tree will split on it,
which is the defect CLAUDE.md records costing pooled RMSE 3.8740 -> 3.9297.

candidacies.csv carries names and winners for every pair, so the quantity is
derivable everywhere. Two traps found while checking, both silent:

  1. NAME FORMAT IS NOT CONSISTENT BETWEEN ELECTIONS. sa2018 writes
     "Rachel Sanderson" and sa2022 writes "SANDERSON, Rachel". A literal string
     match makes 47 of 47 South Australian members look retired, which is a
     100% retirement rate that no check would have caught -- it is a plausible
     number for a column nobody reads.
  2. vic2010 carries ZERO `elected` flags, so vic2014 has no prior winner to
     match. Fall back to the highest primary vote in the seat.
"""
import csv, collections, re, json

PREV = {'fed2010':'fed2007','fed2013':'fed2010','fed2016':'fed2013',
        'fed2019':'fed2016','fed2022':'fed2019','fed2025':'fed2022',
        'nsw2019':'nsw2015','nsw2023':'nsw2019',
        'qld2020':'qld2017','qld2024':'qld2020',
        'sa2022':'sa2018','sa2026':'sa2022',
        'vic2014':'vic2010','vic2018':'vic2014','vic2022':'vic2018',
        'wa2005':'wa2001','wa2008':'wa2005','wa2013':'wa2008',
        'wa2017':'wa2013','wa2021':'wa2017','wa2025':'wa2021'}

PARTICLE = {'DE','DA','VAN','VON','DER','DEN','LA','LE','ST','MC','MAC','O'}


def name_key(raw):
    """(SURNAME, first-initial), robust to both orders the corpus uses.

    Returns None when the name is unusable, so the caller can count coverage
    instead of silently scoring a blank as a retirement.
    """
    s = (raw or '').strip()
    if not s:
        return None
    # "KANG Kyoung Hee (Christina)" -- a parenthesised preferred name is not
    # part of either name and differs between elections for the same person.
    s = re.sub(r'\([^)]*\)', ' ', s)
    s = re.sub(r'\s+', ' ', s.replace('.', ' ').replace('"', ' ')).strip()
    if ',' in s:
        sur, _, giv = s.partition(',')
    else:
        parts = s.split(' ')
        if len(parts) < 2:
            # WESTERN AUSTRALIA STORES THE SURNAME ALONE: wa2001 rows read
            # "PRINCE", "WATSON", "SIMPSON". Returning None here is what
            # emptied every WA pair -- and the version before that, matching
            # the raw string, was pairing EMPTY against EMPTY and calling it
            # the same person, which is why WA looked fine at 9 of 57. Both
            # failures are silent. RETURN HERE: falling through to the
            # "Given Surname" branch below would set the initial from the
            # surname's own first letter ("PRINCE" -> ("PRINCE", "P")), which
            # happens to match only because both sides of every WA pair are
            # single-token, and would silently mis-key the moment one is not.
            sur = re.sub(r'[^A-Z ]', '', parts[0].upper()).strip()
            return (sur, '') if sur else None
        # THREE comma-less orders in this corpus, and guessing one breaks the
        # others silently. NSW writes "FOLEY Luke" (surname FIRST), federal
        # writes "Alan TUDGE" (surname LAST, capitalised), South Australia
        # writes "Rachel Sanderson" (surname last, no case signal). Reading
        # NSW's order as "Given Surname" is what made Castle Hill's
        # "WILLIAMS Ray" and "WILLIAMS Raymond" two different people and
        # scored a sitting member as retired.
        first_caps = parts[0].isupper() and parts[0].isalpha()
        last_caps = parts[-1].isupper() and parts[-1].isalpha()
        if first_caps and not last_caps:
            sur, giv = parts[0], parts[-1]            # "FOLEY Luke"
        else:
            # surname last; keep a leading particle with it so "van der Berg"
            # does not become "BERG" on one side and "VAN DER BERG" on the other
            i = len(parts) - 1
            while i > 1 and parts[i - 1].upper().strip("'") in PARTICLE:
                i -= 1
            sur, giv = ' '.join(parts[i:]), parts[0]
    sur = re.sub(r'[^A-Z ]', '', sur.upper()).strip()
    giv = re.sub(r'[^A-Z]', '', giv.upper())
    if not sur:
        return None
    return (sur, giv[:1])


def load():
    C = collections.defaultdict(list)
    with open('output/candidacies.csv', encoding='utf-8', errors='replace') as f:
        for r in csv.DictReader(f):
            C[r['election']].append(r)
    return C


def winners(rows):
    """Seat -> name_key of the member elected at that election."""
    out, by_seat = {}, collections.defaultdict(list)
    for r in rows:
        by_seat[r['seat']].append(r)
        if str(r.get('elected', '')).upper() in ('TRUE', 'T'):
            k = name_key(r['name'])
            if k:
                out[r['seat']] = k
    if out:
        return out, 'elected flag'
    # vic2010 has no flags at all: fall back to the largest primary vote.
    for seat, rs in by_seat.items():
        best, bv = None, -1.0
        for r in rs:
            try:
                v = float(r['votes'] or r['pcv'] or 'nan')
            except ValueError:
                continue
            if v == v and v > bv:
                best, bv = r, v
        if best is not None:
            k = name_key(best['name'])
            if k:
                out[seat] = k
    return out, 'highest primary (no elected flag)'


def main():
    C = load()
    rows, report = [], []
    for pair, prev in sorted(PREV.items(), key=lambda kv: (kv[0][:3], kv[0])):
        pv, nw = C.get(prev, []), C.get(pair, [])
        if not pv or not nw:
            report.append((pair, prev, 0, 0, 0, 'NO DATA'))
            continue
        win, how = winners(pv)
        field = collections.defaultdict(set)
        bad = 0
        for r in nw:
            k = name_key(r['name'])
            if k is None:
                bad += 1
            else:
                field[r['seat']].add(k)
        def stood_again(w, cands):
            """Same surname, and the initials agree or one side has none.

            The one-sided blank is WA, where only surnames are stored. It makes
            two different people with one surname read as the same person, so a
            genuine retirement can register as a return -- the error is towards
            saying NOT retired, which is the conservative direction for a
            feature whose whole purpose is to mark the exception.
            """
            return any(c[0] == w[0] and (not c[1] or not w[1] or c[1] == w[1])
                       for c in cands)

        matched = [s for s in win if s in field]
        retired = [s for s in matched if not stood_again(win[s], field[s])]
        ret = set(retired)
        for s in matched:
            rows.append(dict(pair=pair, seat=s, retire_derived=int(s in ret)))
        report.append((pair, prev, len(win), len(matched), len(retired), how))
    with open('output/retirement-derived.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=['pair', 'seat', 'retire_derived'])
        w.writeheader()
        w.writerows(rows)
    print('Derived retirement for every pair. "retired %" is the share of matched seats whose')
    print('sitting member did not stand again -- 10-30% is the plausible band for an Australian')
    print('lower house; 0% or 100% means the join failed.')
    print()
    print('%-9s %-9s %8s %8s %8s %8s  %s'
          % ('pair', 'prev', 'winners', 'matched', 'retired', 'pct', 'winner source'))
    for pair, prev, nw_, nm, nr, how in report:
        pct = ('%7.1f%%' % (100 * nr / nm)) if nm else '      .'
        flag = '' if (nm and 0.02 <= nr / nm <= 0.45) else '   <-- IMPLAUSIBLE'
        print('%-9s %-9s %8d %8d %8d %s  %s%s' % (pair, prev, nw_, nm, nr, pct, how, flag))
    print()
    print('wrote output/retirement-derived.csv: %d seat-pairs' % len(rows))


if __name__ == '__main__':
    main()
