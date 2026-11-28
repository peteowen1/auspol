import json,collections,re
lk=lambda x: re.sub('[^a-z]','',x.lower())
d=json.load(open('C:/night28/booths-vic2026.json',encoding='utf-8')); C=d['classes']
n=json.load(open('C:/night28/forecast-night.json',encoding='utf-8')); N={lk(s['seat']):s for s in n['seats']}
f=json.load(open('C:/Users/peteo/AppData/Local/Temp/claude/dc1a17ec65ae517e/84b0a040-f8c3-4d70-ae3c-76955732c65d/scratchpad/freeze/forecast-vic2026-final.json',encoding='utf-8')); F={lk(s['seat']):s for s in f['seats']}
r=json.load(open('C:/night28/raw-vic2026.json',encoding='utf-8'))
print('booths',d['snapshot_stamp'],'night',n['night']['snapshot_stamp'],'raw',r['snapshot_stamp'],'| seats with votes',r['seats_with_votes'],'votes',r['formal_votes'])
now=collections.Counter(); was=collections.Counter(); tot=0; metro=collections.Counter(); mwas=collections.Counter(); mt=0
REG={lk(s['seat']):s.get('region','') for s in f['seats']}
for seat,s in d['seats'].items():
    m='Metropolitan' in (REG.get(lk(seat)) or '')
    for x in s['rows']:
        if x['status']=='counted' and x['type']=='ordinary' and x.get('last_time') and x.get('fp'):
            v=x['votes']; tot+=v
            for c,a,b in zip(C,x['fp'],x['last_time']):
                now[c]+=a*v/100; was[c]+=b*v/100
                if m: metro[c]+=a*v/100; mwas[c]+=b*v/100
            if m: mt+=v
P=lambda A,B,T: {c:(round(100*A[c]/T,1),round(100*(A[c]-B[c])/T,1)) for c in C[:4]} if T else None
print('ALL matched',int(tot),'(share now, change):',P(now,was,tot)); print('METRO matched',int(mt),P(metro,mwas,mt)); print('REGIONAL matched',int(tot-mt),P(now-metro if False else collections.Counter({c:now[c]-metro[c] for c in C}),collections.Counter({c:was[c]-mwas[c] for c in C}),tot-mt))
mv=[]
for k,s in N.items():
    y=F.get(k); 
    if not y: continue
    pw={p['party']:p['win_prob'] for p in y['parties']}; 
    ch=s['favourite_prob']-pw.get(s['favourite'],0)
    mv.append((abs(ch),s['seat'],s.get('counted_pct'),y['favourite'],round(y['favourite_prob'],2),s['favourite'],round(s['favourite_prob'],2)))
print('BIGGEST MOVES (seat, counted%, morning fav, now fav):'); 
for m in sorted(mv,reverse=True)[:14]: print('  ',m[1:])
flips=[m for m in mv if m[3]!=m[5]]; print('favourite changed in',len(flips),'seats:',[(m[1],m[3],'->',m[5],m[6],m[2]) for m in sorted(flips,reverse=True)])
ch=n['chamber']; print('CHAMBER',{p:(v.get('expected'),round(v.get('p_majority') or 0,3),round(v.get('p_most_seats') or 0,3)) for p,v in ch['parties'].items() if (v.get('expected') or 0)>0.3},'hung',ch.get('p_hung'))
