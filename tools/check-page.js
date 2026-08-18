// Execute the published page's JavaScript against a stub DOM and assert that
// every block actually drew.
//
// This exists because the page shipped once with THREE OF FOUR charts silently
// not drawing. jsonlite serialises a data.table as an array of row objects and
// the template read them as column arrays; the first block to touch one threw,
// and — before the per-block guards — took out every block after it. Nothing
// caught it: `node --check` parses the file without running it, R CMD check
// never looks at HTML, and in a browser the page still renders a headline and
// a plausible amount of furniture, so it looks fine unless you know what is
// missing.
//
// The guards that now wrap each block fixed the cascade but made the failure
// QUIETER, not louder: one block can fail alone and the rest of the page still
// looks complete. So the test is not "did it throw" — it is "did every element
// the template addresses actually receive content".
//
// Run:  node tools/check-page.js output/victoria-2026.html
// Exits non-zero with a named list of empty targets.

const fs = require('fs');

const file = process.argv[2] || 'output/victoria-2026.html';
const html = fs.readFileSync(file, 'utf8');

// The template's own script is the last <script> block; take everything so a
// future second block is covered too rather than silently skipped.
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
if (scripts.length === 0) {
  console.error('FAIL: no <script> block found in ' + file);
  process.exit(1);
}

// Which ids the template addresses. Derived from the source rather than
// hardcoded, so adding an element to the page cannot quietly escape the check.
const addressed = new Set(
  [...scripts.join('\n').matchAll(/getElementById\(\s*['"]([^'"]+)['"]\s*\)/g)]
    .map(m => m[1])
);

// Ids that stay empty in SOME runs — but not in all of them, so exempting
// them outright would hide the very failure this file exists to catch, one
// level removed: "did the block draw" becomes "did the block draw when it was
// supposed to". Each carries a predicate over the page's own embedded data, so
// a conditional block that should have fired and did not is a failure, and one
// that correctly stayed quiet is not.
const conditional = {
  datawarn: {
    why: 'only when the poll data is ageing or stale',
    required: D => Boolean(D.data_status && D.data_status !== 'ok')
  },
  leadcav: {
    why: 'only when a leader change is within 180 days',
    required: D => Boolean(D.meta && D.meta.leader &&
                           D.meta.leader_days != null &&
                           D.meta.leader_days <= 180)
  },
  // The candidate-level seat forecast needs election data fetched into
  // external/elections and is skipped by --quick, so the page is built without
  // it often enough that its absence must not be an error. But when the data
  // IS there and the block still does not draw, that is exactly the silent
  // failure this file exists to catch.
  seatparty: {
    why: 'only when the candidate-level seat forecast ran',
    required: D => Array.isArray(D.seats_by_party) && D.seats_by_party.length > 0
  },
  seatplay: {
    why: 'only when the candidate-level seat forecast ran',
    required: D => Array.isArray(D.seats_in_play) && D.seats_in_play.length > 0
  },
  // Renders only when a party actually breaches the L3 poll-tracking check.
  // Required WHEN it breaches, because this note is what justifies fit_vic.R
  // reporting the breach instead of halting -- if the check fires and the page
  // stays silent, the forecast publishes with the justification missing.
  trackcav: {
    why: 'only when a party breaches the L3 poll-tracking check',
    required: D => Array.isArray(D.track) && D.track.some(r => r.breach)
  }
};

// The data the page was built with, needed to evaluate those predicates.
// Parsed from the page itself rather than taken on faith from a sibling file,
// so the check is always about the artifact that would actually be published.
let PAGE_DATA = null;
// \r?\n, not \n: the page is written from R on Windows, where the file
// connection translates line endings, so the data line ends "};\r\n". A
// \n-only pattern silently fails to match and the whole check aborts.
const dm = html.match(/const D = (\{[\s\S]*?\});\r?\n/);
if (dm) {
  try { PAGE_DATA = JSON.parse(dm[1]); } catch (e) { PAGE_DATA = null; }
}
if (!PAGE_DATA) {
  console.error('FAIL: could not parse the page\'s embedded data (const D = ...).');
  console.error('Without it the conditional blocks cannot be told apart from missing ones.');
  process.exit(1);
}

// "Written to" has to cover BOTH ways this template fills an element: the
// tables and text set .innerHTML/.textContent, while every chart is an <svg>
// built by repeated appendChild. Counting only the former reports the three
// charts as missing on a perfectly good page — which is a false alarm, and a
// check that cries wolf gets ignored exactly when it is right.
const written = new Set();
const el = (id) => ({
  get innerHTML() { return ''; },
  set innerHTML(v) { if (String(v).trim()) written.add(id); },
  get textContent() { return ''; },
  set textContent(v) { if (String(v).trim()) written.add(id); },
  set hidden(v) {},
  setAttribute() {},
  appendChild(child) { written.add(id); return child; },
  style: {},
  classList: { add() {}, remove() {} }
});

const cache = new Map();
const doc = {
  getElementById(id) {
    if (!cache.has(id)) cache.set(id, el(id));
    return cache.get(id);
  },
  documentElement: {},
  querySelector: () => null,
  querySelectorAll: () => [],
  addEventListener() {},
  createElementNS: () => ({ setAttribute() {}, appendChild() {}, style: {} }),
  createElement: () => ({ setAttribute() {}, appendChild() {}, style: {} })
};

// The template's draw() guard catches a block's exception, logs
// `console.error(name + ' failed', e)`, and replaces the element with an
// apology. Capturing that is the PRIMARY signal, and the reason this check is
// not simply "did anything get written": a block typically draws its axes
// before it touches the data, so a chart that dies mid-draw still leaves the
// element non-empty. Verified against a deliberately corrupted page — the
// written-to test alone passed it, which is precisely the silent failure the
// guards introduced when they stopped one bad block from taking out the rest.
const drawFailures = [];
const cons = {
  log: (...a) => console.log(...a),
  warn: (...a) => console.warn(...a),
  error: (...a) => {
    const msg = a.map(x => (x && x.message) ? x.message : String(x)).join(' ');
    if (/\bfailed\b/.test(msg)) drawFailures.push(msg);
    console.error('  [page] ' + msg);
  }
};

const sandbox = {
  document: doc,
  window: { addEventListener() {}, matchMedia: () => ({ matches: false, addEventListener() {} }) },
  getComputedStyle: () => ({ getPropertyValue: () => '#000000' }),
  console: cons,
  Math, Date, JSON, Number, String, Array, Object, isFinite, isNaN,
  parseFloat, parseInt
};
sandbox.globalThis = sandbox;

const vm = require('vm');
vm.createContext(sandbox);

let threw = null;
try {
  for (const s of scripts) vm.runInContext(s, sandbox, { timeout: 10000 });
} catch (e) {
  threw = e;
}

// A conditional block counts as missing when its own predicate says it should
// have rendered. Only a block whose condition is genuinely false is skipped.
const unwritten = [...addressed].filter(id => !written.has(id));
const missing = unwritten.filter(id =>
  !(id in conditional) || conditional[id].required(PAGE_DATA));
const skipped = unwritten.filter(id =>
  (id in conditional) && !conditional[id].required(PAGE_DATA));

console.log(`page: ${file}`);
console.log(`elements addressed: ${addressed.size}   written: ${written.size}`);
for (const id of skipped) console.log(`  - ${id}: empty (${conditional[id].why})`);
for (const id of Object.keys(conditional)) {
  if (written.has(id)) console.log(`  - ${id}: rendered (${conditional[id].why})`);
}

if (threw) {
  console.error('\nFAIL: the page script threw:\n' + (threw.stack || threw));
  process.exit(1);
}
if (drawFailures.length) {
  console.error('\nFAIL: ' + drawFailures.length +
    ' block(s) caught by the page\'s own draw() guard:');
  for (const f of drawFailures) console.error('  - ' + f);
  console.error('Each renders an apology in place of a chart or table.');
  process.exit(1);
}
if (missing.length) {
  console.error('\nFAIL: addressed but never written to: ' + missing.join(', '));
  for (const id of missing) {
    if (id in conditional) {
      console.error(`  ${id}: its condition HOLDS for this build (${conditional[id].why}), so it should have rendered.`);
    }
  }
  console.error('Each of these is a block of the page that silently did not draw.');
  process.exit(1);
}
console.log('\nOK: every addressed element received content.');
