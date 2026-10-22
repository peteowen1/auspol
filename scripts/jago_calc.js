// Run Alex Jago's Victorian 4PP calculator offline, on SAVED copies of his own scripts, for given statewide inputs.
//
//   node scripts/jago_calc.js <dir with his saved scripts> <Grn> <Lab> <Lnp> <Phn>
//
// Why run his code rather than port it: the benchmark (docs/plans/external-benchmark-vic2026-2026-10-20.md) scores HIS
// seat method on OUR statewide numbers. A port would score our reading of his method, and any slip in it would look
// like his error. So his calculator.js runs unmodified in a Node vm, with a stub standing in for jQuery and the page.
//
// The stub only has to satisfy what calculator.js touches: it stores input values (.val), keeps the Calculate
// button's click handler, and answers every other jQuery/DataTables call with itself. The page's default inputs,
// which calculator.js writes from his data at load, are printed as a check that his code ran: on 21 Oct the page
// showed Grn 17.55, Lab 38.72, Lnp 34.76, Phn 8.97.
//
// Prints CSV on stdout: district, winner, runner_up, then each party's projected first-round share (0-1).
// Inputs and defaults go to stderr.

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const [dir, ...nums] = process.argv.slice(2);
if (!dir || nums.length !== 4) {
  console.error("usage: node scripts/jago_calc.js <saved-scripts-dir> <Grn> <Lab> <Lnp> <Phn>");
  process.exit(2);
}
const inputs = { Grn: Number(nums[0]), Lab: Number(nums[1]), Lnp: Number(nums[2]), Phn: Number(nums[3]) };
for (const [p, v] of Object.entries(inputs)) {
  if (!Number.isFinite(v) || v <= 0) { console.error(`JC0! input ${p} is not a positive number: ${v}`); process.exit(1); }
}

const els = {};
let clickHandler = null;
function el(sel) {
  if (typeof sel === "string" && els[sel]) return els[sel];
  const st = { v: undefined };
  const p = new Proxy(function () {}, {
    get(_t, prop) {
      if (prop === "val") return (x) => (x === undefined ? st.v : ((st.v = x), p));
      if (prop === "click") return (fn) => { if (sel === "#calculate") clickHandler = fn; return p; };
      if (prop === Symbol.toPrimitive) return () => "";
      if (prop === "then") return undefined;
      return () => p;
    },
    apply() { return p; },
  });
  if (typeof sel === "string") els[sel] = p;
  return p;
}
const ctx = {
  console: { log() {}, error: console.error },
  document: {},
  // No host Math/Array/etc. here: calculator.js patches Array.prototype.max, and array literals inside the vm use
  // the vm's OWN Array, so passing in the host's would patch the wrong prototype.
};
ctx.window = ctx;
ctx.$ = el;
ctx.window.filterFourPartyGraph = () => {};
vm.createContext(ctx);

const files = ["monotone_cubic_spline.js", "2026_victoria_districts_from_2025.js", "calculator.js"];
for (const f of files) {
  const fp = path.join(dir, f);
  if (!fs.existsSync(fp)) { console.error(`JC1! missing saved script ${fp}`); process.exit(1); }
  vm.runInContext(fs.readFileSync(fp, "utf8"), ctx, { filename: f });
}
if (!clickHandler) { console.error("JC2! calculator.js registered no #calculate handler: his page changed shape"); process.exit(1); }

const parties = ["Grn", "Lab", "Lnp", "Phn"];
console.error("JC3  his defaults (from his data at load): " + parties.map((p) => `${p} ${el("#" + p + "StatewidePoll").val()}`).join(", "));
for (const p of parties) el("#" + p + "StatewidePoll").val(String(inputs[p]));
console.error("JC4  inputs given: " + parties.map((p) => `${p} ${inputs[p]}`).join(", "));
clickHandler();

const w = ctx.winners, r2 = ctx.third_elims, r1 = ctx.round_one;
const names = Object.keys(w);
if (names.length === 0) { console.error("JC5! the calculator produced no winners"); process.exit(1); }
console.log(["district", "winner", "runner_up", ...parties.map((p) => "fp_" + p)].join(","));
for (const d of names) {
  console.log([JSON.stringify(d), w[d][0], r2[d][0], ...parties.map((p) => r1[d][p].toFixed(6))].join(","));
}
const tally = {};
for (const d of names) tally[w[d][0]] = (tally[w[d][0]] || 0) + 1;
console.error(`JC6  ${names.length} districts; winners ` + Object.entries(tally).map(([k, v]) => `${k} ${v}`).join(", "));
