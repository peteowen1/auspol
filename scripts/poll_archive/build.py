"""Build external/reference/polls/archive/fed_archive_polls.csv (AUSPOL_POLL_ARCHIVE layer input).

Sources, both saved raw under external/reference/polls/archive/raw/:
  * Roy Morgan: the "Federal voting intention summary" table printed at the foot of every Morgan Poll release
    (finding 4246, 19 Nov 2007) lists every face-to-face and phone poll from 30 Oct 2004 on, with fieldwork dates,
    primaries and two-party. Fetched from web.archive.org captures of roymorgan.com/news/polls/2007/4246/.
  * Newspoll: the per-poll "Fed voting intention" PDFs newspoll.com.au/image_uploads/*, via web.archive.org. Each PDF
    shows a rolling six-poll window, so only the PDFs the Wayback Machine captured are covered (gaps listed in the
    review).
Run: python scripts/poll_archive/build.py   (needs pdfplumber)
"""
import os,sys,subprocess,csv,datetime as dt,collections
root=os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..'))
raw=os.path.join(root,'external','reference','polls','archive','raw')
env=dict(os.environ,ARCHIVE_RAW=raw,ARCHIVE_SCRIPTS=os.path.dirname(os.path.abspath(__file__)))
here=os.path.dirname(os.path.abspath(__file__))
for s in('parse_np.py','parse_morgan.py'):
    r=subprocess.run([sys.executable,os.path.join(here,s)],env=env,capture_output=True,text=True)
    print(s,r.stdout.strip().splitlines()[-1:] ,r.stderr.strip()[-300:] if r.returncode else '')
    if r.returncode: sys.exit(1)
out=os.path.join(root,'external','reference','polls','archive')
def f(x): return '' if x in('',None) else x
rows=[]
for r in csv.DictReader(open(os.path.join(out,'morgan_rows.csv'))):
    rows.append(dict(region='fed',firm='Morgan Phone' if r['phone']=='True' else 'F2F Morgan',fieldwork_start=r['start'],fieldwork_end=r['end'],
        ALP=r['ALP'],LNP=r['LNP'],GRN=r['GRN'],ONP=r['ONP'],DEM=r['DEM'],FF=r['FF'],OTH=r['OTH'],tpp_alp=f(r['tpp_alp_2004']),sample='',
        source='Roy Morgan finding 4246 summary table (web.archive.org capture)'))
g=collections.OrderedDict()
for r in csv.DictReader(open(os.path.join(out,'newspoll_raw_rows.csv'))):
    k=(r['start'],r['end'])
    if k not in g or (not g[k]['tpp_alp'] and r['tpp_alp']): g[k]=r
for k,r in sorted(g.items()):
    if not r['LNP'] or not r['ALP']: continue
    rows.append(dict(region='fed',firm='Newspoll',fieldwork_start=r['start'],fieldwork_end=r['end'],ALP=r['ALP'],LNP=r['LNP'],GRN=r['GRN'],ONP='',DEM='',FF='',
        OTH=r['OTH'],tpp_alp=r['tpp_alp'],sample='',source='Newspoll PDF '+r['file'][:60]))
rows=[r for r in rows if '2004-10-10'<=r['fieldwork_start']<='2007-11-24']
rows.sort(key=lambda r:(r['fieldwork_start'],r['firm']))
with open(os.path.join(out,'fed_archive_polls.csv'),'w',newline='') as fh:
    w=csv.DictWriter(fh,fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
print(len(rows),'rows written; Newspoll',sum(r['firm']=='Newspoll' for r in rows))
