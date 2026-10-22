// Read the Global Election Simulator's per-district Victoria calls from its rendered map. Run IN CHROME, in the page
// console (or Claude in Chrome's javascript tool) on https://globalelectionsimulator.com/victoria, "2026 Polling" view
// (the default). Part of scripts/snapshot_benchmarks.R's capture; see docs/plans/external-benchmark-vic2026-2026-10-20.md.
//
// GES computes its calls in the browser and publishes no file of them, so this is the only way to get them. Each of
// the map's 88 SVG paths is one district, in the order of /victoria-districts.geojson's features (checked by
// correlating path centres with feature centroids, printed below: 0.997 and -0.981 on 21 and 22 Oct; near +1/-1 or
// the order has changed). The party is the colour class of the path's fill; the shade within a class is not decoded.
//
// Returns { check, polling_bundle, csv }. Paste `csv` below the header lines of the dated
// ges/ges-district-calls-read-from-page.csv, and save the polling bundle it names (curl it) into the same folder.
// Then rerun: Rscript scripts/snapshot_benchmarks.R  (it resumes, and derives the calls).
// The tally in `check` must equal the page's own seat panel, and must contain no UNK.
(async () => {
  const svg = [...document.querySelectorAll("svg")].find((s) => s.querySelectorAll("path").length === 88);
  if (!svg) return "no SVG with 88 paths: the page has changed shape";
  const paths = [...svg.querySelectorAll("path")];
  const gj = await fetch("/victoria-districts.geojson").then((r) => r.json());
  const cls = (r, g, b) =>
    g > 180 && r < 60 ? "GRN" :
    b > 150 && b > r ? "LIB" :
    r > 200 && g >= 70 && g <= 120 && b < 40 ? "ONP" :
    r > 190 && g < 70 ? "ALP" :
    r >= 100 && r <= 160 && g >= 125 && g <= 180 && b < 130 ? "NAT" : "UNK";
  const hex = (r, g, b) => "#" + [r, g, b].map((x) => x.toString(16).padStart(2, "0")).join("");
  const centre = (f) => { const xs = [], ys = []; const w = (a) => typeof a[0] === "number" ? (xs.push(a[0]), ys.push(a[1])) : a.forEach(w);
    w(f.geometry.coordinates); return [xs.reduce((s, v) => s + v) / xs.length, ys.reduce((s, v) => s + v) / ys.length]; };
  const cor = (a, b) => { const n = a.length, ma = a.reduce((s, v) => s + v) / n, mb = b.reduce((s, v) => s + v) / n; let ab = 0, aa = 0, bb = 0;
    for (let i = 0; i < n; i++) { ab += (a[i] - ma) * (b[i] - mb); aa += (a[i] - ma) ** 2; bb += (b[i] - mb) ** 2; } return ab / Math.sqrt(aa * bb); };
  const box = paths.map((p) => { const b = p.getBBox(); return [b.x + b.width / 2, b.y + b.height / 2]; });
  const cen = gj.features.map(centre);
  const rows = paths.map((p, i) => { const [r, g, b] = getComputedStyle(p).fill.match(/\d+/g).map(Number);
    return [JSON.stringify(gj.features[i].properties.name), cls(r, g, b), hex(r, g, b)].join(","); });
  const tally = {}; rows.forEach((r) => { const c = r.split(",")[1]; tally[c] = (tally[c] || 0) + 1; });
  const polling = performance.getEntriesByType("resource").map((e) => e.name).filter((n) => /guide-victoria-/.test(n));
  return {
    check: { features: gj.features.length, cor_x: cor(box.map((x) => x[0]), cen.map((x) => x[0])).toFixed(3),
             cor_y: cor(box.map((x) => x[1]), cen.map((x) => x[1])).toFixed(3), tally },
    polling_bundle: polling,
    csv: rows.join("\n"),
  };
})();
