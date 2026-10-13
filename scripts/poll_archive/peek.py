import re,html,glob,os,sys
pass
def text(f):
    t=open(f,errors='ignore').read()
    t=re.sub(r'<(script|style).*?</\1>',' ',t,flags=re.S); t=re.sub(r'<[^>]+>',' ',t); return html.unescape(re.sub(r'\s+',' ',t)).replace('�',"'")
if __name__=='__main__':
    n=0
    for f in sorted(glob.glob('rm/*.html')):
        t=text(f); i=t.find('Finding No.'); b=t[i:]
        if re.search(r'Federal|federal',b[:900]) and re.search(r'two-party',b[:1500]) and not re.search(r'Victorian|NSW|Queensland|Western Aust|South Aust',b[:400]):
            n+=1
            if n%int(sys.argv[1])==0: print(f,b[:1800],'\n')
    print(n)
