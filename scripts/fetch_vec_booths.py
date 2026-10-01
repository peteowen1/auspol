"""Every Victorian Legislative Assembly result BY VOTING CENTRE, 2006-2018.

Source: the VEC's public Azure blob container, which holds the commission's
whole historical-results tree and is publicly listable:
  https://itsitecoreblobvecprd01.blob.core.windows.net/public-files
(found 2026-10-01 via the basedosdados au_vic_vec_elections pipeline, while the
Internet Archive was offline). For each of 2006, 2010, 2014 and 2018 it has one
first-preference page and one two-candidate page per district, 88 each.
2022 comes from scripts/fetch_booths_vic2022.R instead.

Raw pages are stored unedited, never parsed down:
  external/reference/vec/<year>/vc/<fpv|tcp>-<district>.html
and the full container listing (12,811 blobs, names and sizes) is kept at
external/reference/vec/blobs/container-listing.json so later questions (council
results, upper house, by-elections) can be answered without relisting.

Idempotent: a page already on disk and ending in </html> is skipped. Prints a
per-year tally and fails loudly on any year with fewer than 88 pages of a kind.

Run from repo root: python scripts/fetch_vec_booths.py
"""
import collections
import json
import os
import re
import sys
import time
import urllib.request

C = 'https://itsitecoreblobvecprd01.blob.core.windows.net/public-files'
LIST = 'external/reference/vec/blobs/container-listing.json'
YEARS = ['2006', '2010', '2014', '2018']
PAT = re.compile(r'^historical-results/state(\d{4})/(?:state\d{4})?(fpvbyvotingcentre|tcpbyvotingcentre|tcpbyvc)(.+?)district\.html$')


def listing():
    names, marker = [], ''
    while True:
        u = f'{C}?restype=container&comp=list&maxresults=5000' + (f'&marker={marker}' if marker else '')
        x = urllib.request.urlopen(u, timeout=60).read().decode('utf-8', 'replace')
        for b in re.findall(r'<Blob>(.*?)</Blob>', x, re.S):
            s = re.search(r'<Content-Length>(\d+)', b)
            names.append((re.search(r'<Name>(.*?)</Name>', b).group(1), int(s.group(1)) if s else 0))
        m = re.search(r'<NextMarker>(.*?)</NextMarker>', x)
        if not m or not m.group(1):
            break
        marker = m.group(1)
    os.makedirs(os.path.dirname(LIST), exist_ok=True)
    json.dump(names, open(LIST, 'w'))
    print(f'VBF0 container listing: {len(names)} blobs -> {LIST}')
    return names


def main():
    names = listing()
    want = collections.defaultdict(list)
    for n, _ in names:
        m = PAT.match(n)
        if m and m.group(1) in YEARS:
            want[(m.group(1), m.group(2)[:3])].append((n, m.group(3)))
    bad = False
    for yr in YEARS:
        got = skip = fail = 0
        for kind in ('fpv', 'tcp'):
            items = want[(yr, kind)]
            if len(items) < 88:
                print(f'VBF!  {yr} {kind}: only {len(items)} district pages listed (expected 88)')
                bad = True
            d = f'external/reference/vec/{yr}/vc'
            os.makedirs(d, exist_ok=True)
            for n, dist in items:
                out = f'{d}/{kind}-{dist}.html'
                if os.path.exists(out) and open(out, encoding='utf-8', errors='replace').read().rstrip().lower().endswith('</html>'):
                    skip += 1
                    continue
                try:
                    body = urllib.request.urlopen(f'{C}/{n}', timeout=60).read()
                    if not body.rstrip().lower().endswith(b'</html>'):
                        raise ValueError('truncated (no closing </html>)')
                    open(out, 'wb').write(body)
                    got += 1
                    time.sleep(0.1)
                except Exception as e:
                    print(f'VBF!  {n}: {e}')
                    fail += 1
                    bad = True
        print(f'VBF1  {yr}: fetched {got}, already on disk {skip}, failed {fail}')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
