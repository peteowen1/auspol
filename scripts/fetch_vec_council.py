"""Every Victorian council general-election result the VEC's public file store holds.

WHY. The biggest individual primary misses are emergences -- a candidate with
no presence last time who wins a third of the vote (Sheed in Shepparton,
Dalton in Murray, the teals). Many were mayors or councillors first. Council
results give each such candidate a measured local vote BEFORE the state
election, which no other input has. Pete, 2026-10-01: "look into using local
elections".

Source: https://itsitecoreblobvecprd01.blob.core.windows.net/public-files
(listing cached by scripts/fetch_vec_booths.py at
external/reference/vec/blobs/container-listing.json):
  2008, 2012, 2016: historical-results/council<year>/<council>result*.html
  2020, 2024:       Council/Reports/<Council><year>*.xls (count spreadsheets)
Each council election precedes a state election (Oct 2008 -> Nov 2010, ...,
Oct 2024 -> Nov 2026), so every one is usable time-forward.

Raw files stored unedited at external/reference/vec/council/<year>/<name>.
Idempotent: a file already on disk is skipped when complete (html ends in
</html>; xls starts with the OLE2 signature). Exits non-zero on any failure or
on a year with fewer than 75 councils.

Run from repo root: python scripts/fetch_vec_council.py
"""
import collections
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

C = 'https://itsitecoreblobvecprd01.blob.core.windows.net/public-files'
LIST = 'external/reference/vec/blobs/container-listing.json'
OUT = 'external/reference/vec/council'
OLE2 = b'\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1'


def wanted(names):
    w = collections.defaultdict(list)
    for n, _ in names:
        m = re.match(r'^historical-results/council(2008|2012|2016)/([a-z0-9-]+)result(?:2008|2012|2016)?\.html$', n)
        if m:
            w[m.group(1)].append(n)
            continue
        m = re.match(r'^Council/Reports/[^/]*?(2020|2024)[^/]*\.xls$', n)
        if m:
            w[m.group(1)].append(n)
    return w


def complete(path):
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        return False
    b = open(path, 'rb').read()
    return b.rstrip().lower().endswith(b'</html>') if path.endswith('.html') else b[:8] == OLE2


def main():
    if not os.path.exists(LIST):
        print(f'VCF!  {LIST} missing -- run scripts/fetch_vec_booths.py first')
        sys.exit(1)
    names = json.load(open(LIST))
    w = wanted(names)
    bad = False
    for yr in ('2008', '2012', '2016', '2020', '2024'):
        items = w.get(yr, [])
        d = f'{OUT}/{yr}'
        os.makedirs(d, exist_ok=True)
        got = skip = fail = 0
        for n in items:
            out = f'{d}/{n.split("/")[-1]}'
            if complete(out):
                skip += 1
                continue
            try:
                body = urllib.request.urlopen(f'{C}/{urllib.parse.quote(n)}', timeout=60).read()
                open(out, 'wb').write(body)
                if not complete(out):
                    raise ValueError('incomplete (no closing </html> or not an xls)')
                got += 1
                time.sleep(0.05)
            except Exception as e:
                print(f'VCF!  {n}: {e}')
                if os.path.exists(out):
                    os.remove(out)
                fail += 1
                bad = True
        councils = len({re.sub(r'(?i)(result.*|20\d\d.*)$', '', x.split('/')[-1]).lower() for x in items})
        print(f'VCF1  {yr}: {len(items)} files from ~{councils} councils; fetched {got}, on disk {skip}, failed {fail}')
        if councils < 75:
            print(f'VCF!  {yr}: only {councils} councils listed (Victoria has 79)')
            bad = True
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
