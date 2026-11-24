// Runs the page's own compute code (extracted from whatif.html) on sims.json.
const fs = require('fs'), path = require('path');
const html = fs.readFileSync(path.join(__dirname, 'whatif.html'), 'utf8');
const core = html.split('/* CORE-START */')[1].split('/* CORE-END */')[0];
const sims = JSON.parse(fs.readFileSync(path.join(__dirname, 'sims.json'), 'utf8'));
const f = new Function(core + '; return {scenario, forecastNow};')();
const m = [sims.vote_means.Labor, sims.vote_means.Coalition, sims.vote_means.OneNation, sims.vote_means.Greens, sims.vote_means.Others];
const out = {
  now: f.forecastNow(sims),
  a: f.scenario(sims, m, 1.0),
  b: f.scenario(sims, [20, 31, 21, 16, 12], 1.0)
};
const pick = r => ({ coalMajority: r.coalMajority, laborMajority: r.laborMajority, hung: r.hung, ess: r.ess, meanLabor: r.mean[0], meanCoalition: r.mean[1], meanOneNation: r.mean[2], meanGreens: r.mean[3], meanOthers: r.mean[4], mostLabor: r.mostLabor, mostCoalition: r.mostCoalition, mostOneNation: r.mostOneNation });
const res = { now: pick(out.now), a: pick(out.a), b: pick(out.b) };
fs.writeFileSync(path.join(__dirname, 'check-js.json'), JSON.stringify(res, null, 1));
console.log(JSON.stringify(res, (k, v) => typeof v === 'number' ? Math.round(v * 1e4) / 1e4 : v, 1));
