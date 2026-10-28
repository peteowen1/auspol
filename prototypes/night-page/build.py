import re
t=open('tmpl.html',encoding='utf-8').read()
t=t.replace('__GEO__',open('vic-districts.geojson',encoding='utf-8').read().strip())
t=t.replace('__BOOTH__',open('booth-data.json',encoding='utf-8').read())
t=t.replace('__DATA__',open('../nightstate/proto-data.json',encoding='utf-8').read())
open('election-night-maps.html','w',encoding='utf-8').write(t)
m=re.findall(r'<script>(.*?)</script>',t,re.S)
open('x.js','w',encoding='utf-8').write(m[0])
