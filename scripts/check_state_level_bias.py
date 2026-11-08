# Per-party, per-state shrunk statewide level correction, time-forward (8 Nov 2026; DECISIONS). Reads output/statewide-forecast-audit-8nov.csv
# (scripts/audit_statewide_forecast.R with AUSPOL_AUDIT_TAG=-8nov). Result: no party improves. Kept so the check can be rerun.
import csv, collections, statistics as st, math
rows=list(csv.DictReader(open('output/statewide-forecast-audit-8nov.csv')))
reg=lambda p: ''.join(c for c in p if c.isalpha()); yr=lambda p: int(''.join(c for c in p if c.isdigit()))
M=collections.defaultdict(dict)
for r in rows: M[r['pair']][r['cls']]=float(r['miss'])
pairs=sorted(M, key=yr)
def correction(cls, target, mode):
    T=yr(target); s0=reg(target)
    hist=collections.defaultdict(list)
    for p in pairs:
        if yr(p) < T and cls in M[p]: hist[reg(p)].append(M[p][cls])
    if s0 not in hist or not hist[s0]: return 0.0, 0.0
    allm=[x for v in hist.values() for x in v]
    # within-state variance, pooled over states with 2+ elections
    resid=[x-st.mean(v) for v in hist.values() if len(v)>1 for x in v]
    dfw=sum(len(v)-1 for v in hist.values() if len(v)>1)
    sig2 = (sum(e*e for e in resid)/dfw) if dfw>0 else (st.pvariance(allm) if len(allm)>1 else 4.0)
    means={s:st.mean(v) for s,v in hist.items()}
    mu = st.mean(allm) if mode=='mu' else 0.0
    # between-state variance of the true state bias around mu (method of moments)
    tau2=max(0.0, st.mean([(m-mu)**2 - sig2/len(hist[s]) for s,m in means.items()]))
    n=len(hist[s0]); w = tau2/(tau2+sig2/n) if tau2>0 else 0.0
    return mu + w*(means[s0]-mu), w
for mode in ('zero','mu'):
    print(f"== shrink toward {'0' if mode=='zero' else 'the party mean over all earlier elections'}")
    for cls in ('LNP','ALP','GRN'):
        b=[];c=[];ws=[]
        for p in pairs:
            if cls not in M[p]: continue
            corr,w=correction(cls,p,mode)
            if corr==0 and w==0 and mode=='zero':
                # no state history: unchanged, still count it
                pass
            b.append(abs(M[p][cls])); c.append(abs(M[p][cls]-corr)); ws.append(w)
        d=[y-x for x,y in zip(b,c)]
        print(f"  {cls}: n {len(b)}, mean |miss| {st.mean(b):.3f} -> {st.mean(c):.3f} (change {st.mean(d):+.3f}, SE {st.stdev(d)/math.sqrt(len(d)):.3f}); mean state weight {st.mean(ws):.2f}")
