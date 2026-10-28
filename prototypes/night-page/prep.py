import csv,json,re,collections
B='C:/dev/auspol/output/booths/'
def cls(p):
    p=p.strip().lower()
    if p.startswith('australian labor'): return 'A'
    if p in('liberal','the nationals') or p.startswith('liberal party') or p.startswith('national party'): return 'L'
    if p=='australian greens': return 'G'
    return 'O'
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def load(y):
    return list(csv.DictReader(open(B+f'vic{y}-booth-fp.csv',encoding='utf-8')))
r18,r22=load('2018'),load('2022')
def booths(rows):
    d=collections.OrderedDict()
    for x in rows:
        if x['vote_type']!='ordinary': continue
        k=(x['district'],x['booth'])
        e=d.setdefault(k,{'A':0,'L':0,'G':0,'O':0,'lat':x['lat'],'lon':x['lon']})
        e[cls(x['party_raw'])]+=int(x['votes'] or 0)
    return d
def dtot(rows):
    d={};al={}
    for x in rows:
        if x['vote_type']=='all votes':
            e=al.setdefault(x['district'],{'A':0,'L':0,'G':0,'O':0});e[cls(x['party_raw'])]+=int(x['votes'] or 0)
        if x['vote_type'] in('all votes','marked as voted'): continue
        e=d.setdefault(x['district'],{'A':0,'L':0,'G':0,'O':0})
        e[cls(x['party_raw'])]+=int(x['votes'] or 0)
    for k,v in al.items():
        if k not in d: d[k]=v
    return d
b18,b22=booths(r18),booths(r22)
i18={(norm(k[0]),norm(k[1])):v for k,v in b18.items()}
def gap(e):
    t=sum(e[c] for c in 'ALGO'); return (e['A']-e['L'])/t*100 if t else None
out={};matched=tot=0
for (dist,name),e in b22.items():
    t=sum(e[c] for c in 'ALGO')
    if t==0 or not e['lat']: continue
    tot+=1
    o=i18.get((norm(dist),norm(name)));sw=None
    if o and sum(o[c] for c in 'ALGO')>0:
        sw=round(gap(e)-gap(o),2);matched+=1
    lead=max('ALGO',key=lambda c:e[c])
    out.setdefault(dist,[]).append([name,round(float(e['lat']),5),round(float(e['lon']),5),t,lead,[e[c] for c in 'ALGO'],sw])
t18,t22=dtot(r18),dtot(r22);ds={}
for d,e in t22.items():
    o=next((v for k,v in t18.items() if norm(k)==norm(d)),None)
    ds[d]=round(gap(e)-gap(o),2) if (o and gap(o) is not None and gap(e) is not None) else None
print('booths',tot,'matched',matched,'districts',len(out),'dswing none:',[d for d,v in ds.items() if v is None])
json.dump({'booths':out,'dswing':ds,'bstats':[tot,matched]},open('booth-data.json','w'),separators=(',',':'))
