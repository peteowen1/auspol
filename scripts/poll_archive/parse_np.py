import pdfplumber,re,os,sys,csv,datetime as dt
os.chdir(os.environ['ARCHIVE_RAW'])
MON={m:i+1 for i,m in enumerate(['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'])}
# file -> (year of the LAST poll in the file)
YEAR_LAST={'20070605010352':2007,'20070605010355':2007,'20070605010349':2007,'20070816121447':2007,'20070315020751':2007,
           '20070616114632':2006,'20060719181949':2006,'20120113201216':2006}
def parse_range(s,year_hint=None):
    s=s.replace('­','-').replace('–','-')
    m=re.match(r'^(\d{1,2})(?:\s+([A-Za-z]+))?\s*-\s*(\d{1,2})\s+([A-Za-z]+)(?:\s+(\d{4}))?$',s.strip())
    if not m: return None
    d1,m1,d2,m2,y=m.groups()
    mo2=MON[m2[:3].lower()]; mo1=MON[m1[:3].lower()] if m1 else mo2
    return d1,mo1,d2,mo2,int(y) if y else None
def page_rows(p):
    ws=p.extract_words(keep_blank_chars=False)
    rows=[]
    for w in sorted(ws,key=lambda w:(round(w['top']),w['x0'])):
        if rows and abs(rows[-1][0]-w['top'])<=3: rows[-1][1].append(w)
        else: rows.append([w['top'],[w]])
    return rows
def parse(path,tag):
    pg=pdfplumber.open(path).pages[0]
    rows=page_rows(pg)
    cols={}; out=[]; tpp=[]; mode=None
    for top,ws in rows:
        txt=' '.join(w['text'] for w in ws)
        if re.search(r'PRIMARY VOTE',txt):
            mode='p'
            for w in ws:
                u=w['text'].upper()
                if u in('LIBERAL','NATIONALS','COALITION','LABOR','GREENS','OTHERS','DEMOCRATS','FAMILY'): cols[u]=(w['x0']+w['x1'])/2
            continue
        if re.search(r'TWO PARTY PREFERRED',txt):
            mode='t'; tcols={}
        if mode=='t' and re.search(r'COALITION',txt) and re.search(r'LABOR',txt):
            for w in ws:
                u=w['text'].upper()
                if u in('COALITION','LABOR'): tcols[u]=(w['x0']+w['x1'])/2
            continue
        if mode=='t' and re.search(r'TWO PARTY',txt): continue
        if re.search(r'ARE YOU SATISFIED|SATISFIED',txt) and mode: mode=None
        if mode and ws[0]['text'] in('Newspoll','Election'):
            if ws[0]['text']=='Election': continue
            thr=(cols['LIBERAL']-22) if mode=='p' else 200
            nums=[w for w in ws if w['x0']>thr and re.match(r'^\d+(\.\d+)?$',w['text'])]
            dtxt=' '.join(w['text'] for w in ws[1:] if w not in nums).replace('*','').replace('@','').strip()
            if mode=='p':
                rec={}
                for w in nums:
                    best=min(cols,key=lambda c:abs(cols[c]-(w['x0']+w['x1'])/2))
                    if abs(cols[best]-(w['x0']+w['x1'])/2)<25: rec[best]=float(w['text'])
                out.append((dtxt,rec))
            else:
                rec={}
                nn=sorted(nums,key=lambda w:w['x0'])
                if len(nn)==2: rec={'COALITION':float(nn[0]['text']),'LABOR':float(nn[1]['text'])}
                tpp.append((dtxt,rec))
    return out,tpp
def to_dates(dtxt,year_state):
    r=parse_range(dtxt)
    if not r: return None
    d1,mo1,d2,mo2,y=r
    return d1,mo1,d2,mo2,y
res=[]
for f in sorted(os.listdir('newspoll')):
    if not f.endswith('.pdf') or '_' in f[:15] and not re.match(r'^\d{14}_',f): continue
    if re.match(r'^\d{14}_',f): continue   # use the short-named copies where they exist; the cgi_lib ones below
for f in sorted(os.listdir('newspoll')):
    if not f.endswith('.pdf'): continue
    tag=f[:14]
    full=re.match(r'^\d{14}_(cgi|0701|0103|0201|0504)',f) is not None
    short=re.match(r'^\d{14}\.pdf$',f) is not None
    if not (full or short): continue
    if full and not re.search(r'Fed|fed',f): continue
    try: prim,tp=parse('newspoll/'+f,tag)
    except Exception as e: print('ERR',f,e); continue
    if not prim: print('none',f); continue
    # years
    dates=[parse_range(d) for d,_ in prim]
    if any(d is None for d in dates): print('bad date',f,[d for d,_ in prim]); continue
    ylast=YEAR_LAST.get(tag)
    ys=[d[4] for d in dates]
    if any(y is None for y in ys):
        if ylast is None: print('no year',f); continue
        y=ylast; ys2=[None]*len(dates)
        prev_m=None
        for i in range(len(dates)-1,-1,-1):
            m_end=dates[i][3]
            if prev_m is not None and m_end>prev_m: y-=1
            ys2[i]=y; prev_m=dates[i][1] if dates[i][1]<=m_end else dates[i][1]; prev_m=m_end
        ys=ys2
    tmap={}
    for (d,rec) in tp: tmap[re.sub(r'\s+',' ',d)]=rec
    for (d,rec),dd,y in zip(prim,dates,ys):
        d1,mo1,d2,mo2,_=dd
        ye=y; ys_=y if mo1<=mo2 else y-1
        start=dt.date(ys_,mo1,int(d1)); end=dt.date(ye,mo2,int(d2))
        t=tmap.get(re.sub(r'\s+',' ',d),{})
        res.append(dict(start=start,end=end,file=f,LIB=rec.get('LIBERAL'),NAT=rec.get('NATIONALS'),LNP=rec.get('COALITION'),ALP=rec.get('LABOR'),GRN=rec.get('GREENS'),OTH=rec.get('OTHERS'),tpp_lnp=t.get('COALITION'),tpp_alp=t.get('LABOR')))
res.sort(key=lambda r:(r['start'],r['file']))
with open('../newspoll_raw_rows.csv','w',newline='') as fh:
    w=csv.DictWriter(fh,fieldnames=list(res[0].keys())); w.writeheader(); w.writerows(res)
print(len(res))
