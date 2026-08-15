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

// Ids that legitimately stay empty in some runs, with the condition named.
// Anything not listed here MUST be written to.
const conditional = {
  datawarn: 'only when the poll data is ageing or stale',
  leadcav:  'only when a leader change is within 180 days'
};

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

const missing = [...addressed].filter(id => !written.has(id) && !(id in conditional));
const skipped = [...addressed].filter(id => !written.has(id) && (id in conditional));

console.log(`page: ${file}`);
console.log(`elements addressed: ${addressed.size}   written: ${written.size}`);
for (const id of skipped) console.log(`  - ${id}: empty (${conditional[id]})`);

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
  console.error('Each of these is a block of the page that silently did not draw.');
  process.exit(1);
}
console.log('\nOK: every addressed element received content.');
