"""Legislative Assembly candidates (vic2026 default; nsw2027 as argv[2]) -> tidy (seat, name,
party_raw, sitting) rows for scripts/build_candidacies.R to classify.

Emits the party NAME, not a class. classify_party() in R/parties.R is this
repo's single source of truth for party classification -- CLAUDE.md records a
silent corruption caused by trusting someone else's party field -- so the
mapping from "(FF)" to a class happens there, not here.

Column -> party name, and the (X) codes used in the Other column.
"""
import re, json, csv, sys, collections

OUT = sys.argv[1]
# Which election: the second argument, default vic2026 (unchanged behaviour).
ELECTION = sys.argv[2] if len(sys.argv) > 2 else "vic2026"
SRC = f"external/reference/wikipedia/{ELECTION}-candidates.wikitext"
# Named-party columns by position (0 = electorate, 1 = held by, 3 = Coalition,
# 7 = Other), per election, because each page orders its party columns
# differently: NSW 2027 has Family First and Libertarian where Victoria has
# One Nation and the Socialists.
NAMED_COLS = {
    "vic2026": (("ALP", 2), ("GRN", 4), ("ONP", 5), ("SOC", 6)),
    "nsw2027": (("ALP", 2), ("GRN", 4), ("FF", 5), ("LBT", 6)),
}[ELECTION]

COLNAME = {
    "ALP": "Australian Labor Party",
    "GRN": "Australian Greens",
    "ONP": "One Nation",
    "SOC": "Victorian Socialists",
    "FF": "Family First",
    "LBT": "Libertarian Party",
}
# Codes seen in the Other column and in the Coalition column.
CODE = {
    "L": "Liberal", "N": "National",
    "Ind": "Independent", "IND": "Independent",
    "FF": "Family First", "SA": "Socialist Alliance",
    "AJP": "Animal Justice Party", "LC": "Legalise Cannabis",
    "SFF": "Shooters, Fishers and Farmers", "UAP": "United Australia Party",
    "LDP": "Liberal Democrats", "DLP": "Democratic Labour Party",
    "SPP": "Sustainable Australia", "TOP": "The Others Party",
    "AC": "Australian Christians", "LIB": "Liberal",
    # Both real parties, found by checking the raw cell rather than assuming a
    # 2-4 letter code in parentheses was a parse artefact: "(West)" is The West
    # Party (thewestparty.org.au), running 7 western-suburbs seats, and "LBT"
    # is the Libertarian Party.
    "West": "The West Party", "LBT": "Libertarian Party",
    # NSW 2027 page codes.
    "SAP": "Sustainable Australia", "SAll": "Socialist Alliance",
    "Dem": "Australian Democrats", "ONP": "One Nation",
}

txt = open(SRC, encoding="utf-8").read()
# Headings may carry spaces ("== Legislative Assembly ==" on the NSW page).
m0 = re.search(r"==\s*Legislative Assembly\s*==", txt)
if m0 is None:
    raise SystemExit("no Legislative Assembly heading in " + SRC)
start = m0.start()
m1 = re.search(r"==\s*(Legislative Council|References)\s*==", txt[start + 5:])
end = start + 5 + m1.start() if m1 else len(txt)
sec = txt[start:end]
table = sec[sec.index("{|"):sec.index("|}", sec.index("{|"))]


def strip_templates(c):
    """Remove {{...}} including NESTED braces, which a single regex cannot do
    and which left a raw '{{cite web|title=...' inside the Ashwood cell."""
    out, depth = [], 0
    i = 0
    while i < len(c):
        if c.startswith("{{", i):
            depth += 1; i += 2; continue
        if c.startswith("}}", i):
            depth = max(0, depth - 1); i += 2; continue
        if depth == 0:
            out.append(c[i])
        i += 1
    return "".join(out)


def clean(cell):
    c = re.sub(r"<ref[^>]*/>", "", cell)
    c = re.sub(r"<ref.*?</ref>", "", c, flags=re.S)
    c = strip_templates(c)
    bold = "'''" in c
    c = c.replace("'''", "").replace("''", "")
    c = re.sub(r"\[\[[^\]|]*\|([^\]]*)\]\]", r"\1", c)
    c = re.sub(r"\[\[([^\]]*)\]\]", r"\1", c)
    c = re.sub(r"<[^>]+>", "", c).replace("&nbsp;", " ")
    return re.sub(r"\s+", " ", c).strip(), bold


rows, seen, rejected = [], set(), []
for r in table.split("\n|-"):
    # A NEW CELL ONLY WHEN NOT INSIDE A TEMPLATE OR A REF. Sydenham carries
    #
    #   |Nathalie Moussi ([[Victorian Liberal Party|L]])<ref>{{Cite web
    #   |url=https://vicliberal.org.au/... |website=... |title=...
    #
    # and that continuation line starts with "|", so a naive splitter reads it
    # as the next column and shifts every candidate after it -- Sydenham lost
    # its Greens candidate and gained two rows of citation markup. Any seat
    # with a multi-line citation would be mis-assigned the same way, silently.
    cells, buf, depth, inref = [], None, 0, False
    for ln in r.split("\n"):
        opens = ln.count("{{") + len(re.findall(r"<ref(?![^>]*/>)", ln))
        closes = ln.count("}}") + ln.count("</ref>")
        starts_cell = ln.startswith("|") and not ln.startswith("|}") \
            and depth <= 0 and not inref
        if starts_cell:
            if buf is not None:
                cells.append(buf)
            buf = ln[1:]
        elif buf is not None:
            buf += "\n" + ln
        depth += ln.count("{{") - ln.count("}}")
        inref = inref or bool(re.search(r"<ref(?![^>]*/>)", ln))
        if "</ref>" in ln:
            inref = False
        if depth < 0:
            depth = 0
    if buf is not None:
        cells.append(buf)
    if len(cells) < 2:
        continue
    cells = (cells + [""] * 8)[:8]
    vals = [clean(c) for c in cells]
    seat = vals[0][0].lstrip("|").strip()
    if not seat or seat.startswith("!") or "style=" in seat or seat in seen:
        continue
    seen.add(seat)

    def add(name, party_raw, sitting):
        name = name.strip().strip("|").strip()
        if not name:
            return
        # A "name" carrying a URL, an = or a pipe is leaked citation markup,
        # not a person -- an unbalanced brace in a template defeats the
        # depth-tracking stripper. REJECTED AND COUNTED, never silently
        # dropped: a filter that quietly discards rows is indistinguishable
        # from a parser that never saw them.
        if re.search(r"http|=|\||\{|\}", name) or len(name) > 45:
            rejected.append({"seat": seat, "party_raw": party_raw, "name": name})
            return
        rows.append({"seat": seat, "name": name, "party_raw": party_raw,
                     "sitting": "TRUE" if sitting else "FALSE"})

    for key, idx in NAMED_COLS:
        nm, bold = vals[idx]
        add(re.sub(r"\s*\([^)]*\)\s*$", "", nm), COLNAME[key], bold)

    # Coalition: "Brad Battin (L)" / "Andrew Lethlean (N)"
    nm, bold = vals[3]
    m = re.match(r"^(.*?)\s*\(([LN])\)\s*$", nm)
    if m:
        add(m.group(1), CODE[m.group(2)], bold)
    elif nm:
        add(nm, "Liberal", bold)

    # Other: "Hitendra Joshi (Ind)Mike Fruery (AJP)" -- names run together, so
    # split on the closing paren of each code rather than on whitespace.
    oth, obold = vals[7]
    for m in re.finditer(r"([^()]+?)\s*\(([A-Za-z]{1,4})\)", oth):
        add(m.group(1), CODE.get(m.group(2), m.group(2)), obold)

w = csv.DictWriter(open(OUT, "w", newline="", encoding="utf-8"),
                   fieldnames=["seat", "name", "party_raw", "sitting"])
w.writeheader()
w.writerows(rows)

print(f"seats: {len(seen)}   candidate rows: {len(rows)}")
print(f"sitting members: {sum(1 for r in rows if r['sitting'] == 'TRUE')}")
c = collections.Counter(r["party_raw"] for r in rows)
for k, v in c.most_common():
    print(f"  {k:<32} {v:>3}")
print(f"\nREJECTED as leaked markup rather than a person: {len(rejected)}")
for r in rejected:
    print("  ", r["seat"], "|", r["party_raw"], "|", r["name"][:60])
print(f"\nwrote {OUT}")

# RETIRING MEMBERS ("The following members announced that they will not be
# contesting"), written beside the candidates as <election>-retiring.csv so the
# presumed-sitting layer in build_candidacies.R can leave them out.
mr = re.search(r"==\s*Retiring members\s*==(.*?)\n==\s*[A-Z]", txt, re.S)
ret = []
if mr:
    for ln in mr.group(1).splitlines():
        m = re.match(r"^\*\s*\[\[(?:[^|\]]*\|)?([^\]]+)\]\].*?Electoral district of ([^|\]]+)", ln)
        if m:
            ret.append({"seat": m.group(2).strip(), "name": m.group(1).strip()})
rout = OUT.replace("-candidates.csv", "-retiring.csv")
if rout != OUT:
    rw = csv.DictWriter(open(rout, "w", newline="", encoding="utf-8"), fieldnames=["seat", "name"])
    rw.writeheader()
    rw.writerows(ret)
    print(f"retiring members: {len(ret)} -> {rout}")
