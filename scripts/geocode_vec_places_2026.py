"""Geocode the 2026 Victorian voting centres that have no 2022 booth to take a position from (Pete, 12 Nov 2026).

The VEC refused the election-night feed (11 Nov), and with it the set-up file that carried each centre's coordinates.
The venues spreadsheet behind places-2026.csv (scripts/build_vec_places_2026.R) has addresses only. A centre whose name
matches a 2022 booth in its district takes that booth's position in the ITG booths build; the rest are looked up here,
one request per distinct address, against OpenStreetMap's Nominatim (free; 1 request a second; generic client name,
nothing personal sent).

Usage: python -I scripts/geocode_vec_places_2026.py <booths-vic2022.json> <booths-ref2018.json> <districts.geojson>
  (the three files are in C:/dev/inthegame-blog/politics/night-maps/)

Every raw reply is saved, unfiltered, to external/reference/vec/2026/voting-locations/geocode-raw/<key>.json with the
request it answered; a rerun reads those instead of asking again (resumable). Two tries per address: the structured
street address, then the venue name and suburb. A point is accepted only if it falls inside the district the venue is
in (its own district, or for a guest joint centre "JVC" the district hosting the same venue as "HJVC"); otherwise it is
written with ok = FALSE and the reason, and the booths build leaves it off the map.

Writes external/reference/vec/2026/voting-locations/places-2026-geo.csv: one row per places-2026.csv row that needed a
lookup. Codes GV0-GV4.
"""
import csv, hashlib, json, os, re, sys, time, urllib.parse, urllib.request
from shapely.geometry import shape, Point

ROOT = os.path.join('external', 'reference', 'vec', '2026', 'voting-locations')
RAW = os.path.join(ROOT, 'geocode-raw')
UA = 'auspol-geocode/1.0 (election research; one-off batch)'
if len(sys.argv) != 4: sys.exit(__doc__)
hist_f, ref_f, geo_f = sys.argv[1:4]


def norm(s):   # as build-booths-2026.py and the night runner
    s = re.sub(r'[^a-z0-9 ]', ' ', str(s).lower()); s = re.sub(r'\bmt\b', 'mount', s); s = re.sub(r'\bst\b', 'saint', s)
    return re.sub(' +', ' ', s).strip()


# Booths that can lend a position: only those WITH coordinates. booths-ref2018.json (Narracan) has none, so its
# centres are looked up too; the feed's set-up file would have carried them.
H = {}
for f in (hist_f, ref_f):
    for d, bs in json.load(open(f, encoding='utf-8'))['districts'].items():
        H.setdefault(norm(d), {norm(b['n']) for b in bs if b.get('la') is not None})
D = {norm(ft['properties']['name']): shape(ft['geometry']) for ft in json.load(open(geo_f, encoding='utf-8'))['features']}
rows = list(csv.DictReader(open(os.path.join(ROOT, 'places-2026.csv'), encoding='utf-8')))
print('GV0 %d centres, %d districts with booth history, %d district boundaries' % (len(rows), len(H), len(D)))
assert len(D) == 88, 'expected 88 district boundaries'
assert not (set(norm(r['district']) for r in rows) - set(D)), 'a places-2026 district has no boundary'

addr = lambda r: (r['Address Line 1'].strip(), r['Suburb'].strip(), r['Post Code'].strip())
host = {}   # venue address -> the district where it is a host or ordinary centre
for r in rows:
    if r['joint'] != 'JVC': host.setdefault(addr(r), norm(r['district']))
need = [r for r in rows if norm(r['booth']) not in H.get(norm(r['district']), set())]
print('GV1 %d centres have no positioned 2022/2018 booth of the same name; %d distinct addresses' % (len(need), len({addr(r) for r in need})))

os.makedirs(RAW, exist_ok=True)
last = [0.0]


def ask(params):
    q = dict(params, format='jsonv2', addressdetails=1, limit=5, countrycodes='au')
    key = hashlib.sha1(json.dumps(q, sort_keys=True).encode()).hexdigest()[:16]
    f = os.path.join(RAW, key + '.json')
    if os.path.exists(f): return json.load(open(f, encoding='utf-8'))['reply'], False
    wait = 1.1 - (time.time() - last[0])
    if wait > 0: time.sleep(wait)
    url = 'https://nominatim.openstreetmap.org/search?' + urllib.parse.urlencode(q)
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': UA}), timeout=30) as resp:
        body = resp.read().decode('utf-8')
    last[0] = time.time()
    reply = json.loads(body)
    with open(f + '.tmp', 'w', encoding='utf-8') as o:
        json.dump({'request': q, 'url': url, 'fetched': time.strftime('%Y-%m-%dT%H:%M:%S%z'), 'reply': reply}, o)
    os.replace(f + '.tmp', f)
    return reply, True


cache, fetched, out = {}, 0, []
for r in need:
    a = addr(r)
    if a not in cache:
        tries = [('street', {'street': a[0], 'city': a[1], 'postalcode': a[2], 'state': 'Victoria', 'country': 'Australia'}),
                 ('venue', {'q': '%s, %s VIC %s' % (r['Venue Name'].strip(), a[1], a[2])})]
        res = None
        for how, p in tries:
            reply, new = ask(p); fetched += new
            if reply:
                res = (how, reply); break
        cache[a] = res
    res = cache[a]
    dist_key = host.get(a, norm(r['district'])) if r['joint'] == 'JVC' else norm(r['district'])
    row = {'district': r['district'], 'booth': r['booth'], 'joint': r['joint'], 'venue': r['Venue Name'], 'address': ', '.join(a),
           'check_district': dist_key, 'method': '', 'la': '', 'lo': '', 'display_name': '', 'n_results': 0, 'ok': False, 'reason': ''}
    if res is None:
        row['reason'] = 'no result'
    else:
        how, reply = res
        row.update(method=how, n_results=len(reply))
        inside = [x for x in reply if D[dist_key].contains(Point(float(x['lon']), float(x['lat'])))] if dist_key in D else []
        best = inside[0] if inside else reply[0]
        row.update(la=round(float(best['lat']), 5), lo=round(float(best['lon']), 5), display_name=best.get('display_name', ''))
        row['ok'] = bool(inside)
        if not inside: row['reason'] = 'outside its district (%s)' % dist_key
    out.append(row)

with open(os.path.join(ROOT, 'places-2026-geo.csv') + '.tmp', 'w', encoding='utf-8', newline='') as o:
    w = csv.DictWriter(o, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
os.replace(os.path.join(ROOT, 'places-2026-geo.csv') + '.tmp', os.path.join(ROOT, 'places-2026-geo.csv'))
ok = sum(x['ok'] for x in out)
print('GV2 %d new requests this run (%d raw replies on disk)' % (fetched, len(os.listdir(RAW))))
print('GV3 %d of %d placed inside their district; %d not (by method: %s)' % (
    ok, len(out), len(out) - ok, {m: sum(1 for x in out if x['method'] == m and x['ok']) for m in ('street', 'venue')}))
for x in [x for x in out if not x['ok']][:15]: print('GV4 not placed:', x['district'], '|', x['booth'], '|', x['address'], '|', x['reason'])
print('wrote', os.path.join(ROOT, 'places-2026-geo.csv'))
