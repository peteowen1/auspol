import re,csv,os,sys,datetime as dt
sys.path.insert(0,os.environ['ARCHIVE_SCRIPTS'])
import peek
os.chdir(os.environ['ARCHIVE_RAW'])
SRC=sys.argv[1] if len(sys.argv)>1 else 'morgan/2007-4246.html'
OUT=sys.argv[2] if len(sys.argv)>2 else '../morgan_rows.csv'
T=peek.text(SRC)
MON={m:i+1 for i,m in enumerate(['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'])}
i=T.find('FEDERAL VOTING INTENTION SUMMARY'); j=T.find('TWO-PARTY PREFERRED VOTE',i)
k=T.find('Note:',j)
prim=T[i:T.find('Note:',i)]; tpp=T[j:]
lab=re.compile(r'((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s*\d[^0-9]{0,3}?[\d/ &,\-A-Za-z]*?(?:,?\s*(?:19|20)\d\d)?)(\s*\((?:Phone|phone)[^)]*\))?\s+(?=\d|-|\^)')
def split(sec,start_marker):
    s=sec[sec.find(start_marker)+len(start_marker):]
    pos=[m for m in re.finditer(r'(?<![A-Za-z])((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*)\s?(\d{1,2})',s)]
    # a row label starts at a month name followed by a day; subsequent month names inside the label (e.g. "& Nov 6/7") are part of the label
    rows=[]; cur=None
    toks=re.split(r'\s+',s)
    return s
def parse_rows(sec,marker):
    s=sec[sec.index(marker)+len(marker):]
    s=s.replace(' ',' ')
    # label = from a month token up to the first token that is a plain number not preceded by month/slash/&/comma context.
    M=r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*'
    pat=re.compile(r'('+M+r'\s?\d{1,2}(?:\s*[/&-]\s*(?:'+M+r'\s?)?\d{1,2})*\s*,?\s*(?:(?:19|20)\d\d)?)(\s*\([Pp]hone[^)]*\))?')
    ms=list(pat.finditer(s))
    out=[]
    for a,b in zip(ms,ms[1:]+[None]):
        body=s[a.end():(b.start() if b else len(s))]
        out.append((a.group(1).strip(),bool(a.group(2)),body))
    return out
def nums(body):
    body=body.replace('^','0.25')
    body=re.sub(r'\(\s*([\d.]+)\s*\)',r' (\1) ',body)
    vals=[]
    for t in re.findall(r'\([\d.]+\)|[\d.]+|(?<![\w])-(?![\w\d])',body):
        if t.startswith('('): vals.append(('nat',float(t[1:-1])))
        elif t=='-': vals.append(('v',0.0))
        else:
            try: vals.append(('v',float(t)))
            except: pass
    return vals
def dates(label,prev_year,prev_start):
    ym=re.search(r'((?:19|20)\d\d)\s*$',label)
    y=int(ym.group(1)) if ym else None
    core=re.sub(r'(?:19|20)\d\d\s*$','',label).replace(',',' ')
    mo=None; ds=[]
    for t in re.findall(r'[A-Za-z]+|\d+',core):
        if t.isalpha():
            m=MON.get(t[:3].lower())
            if m: mo=m
        elif mo: ds.append((mo,int(t)))
    if y is None:
        y=prev_year
        if prev_start and ds and ds[0][0]<prev_start.month-5: y=prev_year+1
    out=[]
    cy=y
    prev_m=None
    for m,d in ds:
        out.append(dt.date(cy,m,d))
    # month wrap within label (Dec -> Jan): dates must be ascending
    for n in range(1,len(out)):
        if out[n]<out[n-1]: out[n]=dt.date(out[n].year+1,out[n].month,out[n].day)
    return out,y
rows=[]
py=2004; ps=None
for label,phone,body in parse_rows(prim,'MORGAN POLL'):
    v=nums(body)
    nat=[x for k,x in v if k=='nat']; vv=[x for k,x in v if k=='v']
    if len(vv)<7: print('short row',label,vv); continue
    ds,py=dates(label,py,ps)
    if not ds: print('nodate',label); continue
    ps=ds[0]
    rows.append(dict(label=label,phone=phone,start=min(ds),end=max(ds),LNP=vv[0],NAT=nat[0] if nat else '',ALP=vv[1],DEM=vv[2],GRN=vv[3],FF=vv[4],ONP=vv[5],OTH=vv[6]))
# two-party
trows=parse_rows(tpp,'Preferences distributed by how electors voted at the 2004 election')
py=2004; ps=None; tmap={}
for label,phone,body in trows:
    vv=[x for k,x in nums(body) if k=='v']
    ds,py=dates(label,py,ps)
    if not ds: continue
    ps=ds[0]
    tmap[(min(ds),max(ds))]=vv
n_t=0
for r in rows:
    vv=tmap.get((r['start'],r['end']))
    if vv and len(vv)>=4: r['tpp_alp_say']=vv[1]; r['tpp_alp_2004']=vv[3]; n_t+=1
    elif vv and len(vv)==2: r['tpp_alp_say']=vv[1]; r['tpp_alp_2004']=''
    else: r['tpp_alp_say']=''; r['tpp_alp_2004']=''
keys=['label','phone','start','end','LNP','NAT','ALP','DEM','GRN','FF','ONP','OTH','tpp_alp_say','tpp_alp_2004']
with open(OUT,'w',newline='') as fh:
    w=csv.DictWriter(fh,fieldnames=keys); w.writeheader(); w.writerows(rows)
print(len(rows),'rows with tpp',n_t,'tpp rows parsed',len(tmap))
