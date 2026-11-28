"""Victoria 2026 Legislative Council: turn one folder of saved VEC region pages into a raw count JSON.

Written by ITG for auspol's upper-house side loop (28 Nov 2026, election night). Standard library only.

    python -I upper_parse.py <folder of <Region-Slug>.html> <out.json>

Reads only the saved files (no network). Exit 0 and a JSON file with a non-empty "regions" array on
success; any other exit code means nothing usable was written. A region whose page cannot be parsed
is left out and named in "skipped"; the run still succeeds if at least one region parsed.

Output: { election, kind, built_at, snapshot_stamp, note, regions: [ { region, enrolment,
formal_votes, informal_votes, total_votes, counted_pct_of_enrolment, quota_votes, groups: [ { group,
party, party_class, above_line, below_line, votes, pct, quotas } ] } ], skipped: [...] }

`quotas` is the VEC's own "Indicative quota" column, not recomputed. `quota_votes` is formal/6 + 1
rounded down (five members per region), given only so a reader can see the size of a quota tonight.
Raw count only: no model, and group voting tickets are not applied.
"""
import datetime
import html
import json
import os
import re
import sys

REGIONS = {
    "Eastern-Victoria": "Eastern Victoria",
    "North-Eastern-Metropolitan": "North-Eastern Metropolitan",
    "Northern-Metropolitan": "Northern Metropolitan",
    "Northern-Victoria": "Northern Victoria",
    "South-Eastern-Metropolitan": "South-Eastern Metropolitan",
    "Southern-Metropolitan": "Southern Metropolitan",
    "Western-Metropolitan": "Western Metropolitan",
    "Western-Victoria": "Western Victoria",
}


def text(s):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", s))).replace("�", "-").strip()


def num(s):
    m = re.search(r"-?[\d,]+(?:\.\d+)?", s or "")
    if not m:
        return None
    v = m.group(0).replace(",", "")
    return float(v) if "." in v else int(v)


def party_class(name):
    # Exact names only (auspol, 28 Nov 9pm: "Libertarian (formerly Liberal Democrats)" matched a loose "liberal" test and
    # was counted as a second Coalition group in three regions). Anything not listed is OTH.
    n = re.sub(r"\s+", " ", name.strip().lower())
    exact = {
        "australian labor party": "ALP", "australian labor party - victorian branch": "ALP", "labor": "ALP",
        "liberal": "LNP", "the nationals": "LNP", "liberal / the nationals": "LNP", "liberal/the nationals": "LNP", "liberal / nationals": "LNP",
        "the greens": "GRN", "australian greens": "GRN", "the australian greens - victoria": "GRN",
        "one nation victoria": "ONP", "pauline hanson's one nation": "ONP", "one nation": "ONP",
    }
    return exact.get(n, "OTH")


def parse_region(path, region):
    t = open(path, encoding="utf-8", errors="replace").read()
    stats = {}
    for m in re.finditer(r'<p class="list-item-title">(.*?)</p>\s*<p class="list-item-body">(.*?)</p>', t, re.S):
        stats[text(m.group(1)).rstrip(":").lower()] = text(m.group(2))
    enrol = num(stats.get("total enrolled voters"))
    formal = num(stats.get("formal votes"))
    informal = num(stats.get("informal votes"))
    total = num(stats.get("total votes"))
    if enrol is None or formal is None:
        raise ValueError("no enrolment or formal votes on the page")

    i = t.find("First preference results")
    if i < 0:
        raise ValueError("no first preference table")
    body = re.search(r"<tbody>(.*?)</tbody>", t[i:], re.S)
    if not body:
        raise ValueError("first preference table has no body")
    groups = []
    for row in re.finditer(r"<tr[^>]*>(.*?)</tr>", body.group(1), re.S):
        cells = [text(c) for c in re.findall(r"<td[^>]*>(.*?)</td>", row.group(1), re.S)]
        if len(cells) < 7:
            continue
        letter, name = cells[0], cells[1]
        votes = num(cells[4])
        if votes is None or not name:
            continue
        if name.lower().startswith("total"):
            continue
        groups.append({
            "group": letter,
            "party": name,
            "party_class": party_class(name),
            "above_line": num(cells[2]),
            "below_line": num(cells[3]),
            "votes": votes,
            "pct": num(cells[5]),
            "quotas": num(cells[6]),
        })
    if not groups:
        raise ValueError("no group rows")
    groups.sort(key=lambda g: -(g["votes"] or 0))
    summed = sum(g["votes"] or 0 for g in groups)
    return {
        "region": region,
        "enrolment": enrol,
        "formal_votes": formal,
        "informal_votes": informal,
        "total_votes": total,
        "counted_pct_of_enrolment": round(100.0 * formal / enrol, 2) if enrol else None,
        "quota_votes": (formal // 6) + 1 if formal else None,
        "groups_sum": summed,
        "groups": groups,
    }


def main():
    if len(sys.argv) != 3:
        print("usage: upper_parse.py <folder> <out.json>", file=sys.stderr)
        return 2
    folder, out = sys.argv[1], sys.argv[2]
    stamp = os.path.basename(os.path.normpath(folder))
    regions, skipped = [], []
    for slug, name in REGIONS.items():
        p = os.path.join(folder, slug + ".html")
        if not os.path.isfile(p):
            skipped.append({"region": name, "why": "file missing"})
            continue
        try:
            r = parse_region(p, name)
            # the groups must add to the formal vote (the page lists every group and ungrouped candidates)
            if r["formal_votes"] and abs(r["groups_sum"] - r["formal_votes"]) > max(5, 0.01 * r["formal_votes"]):
                r["note"] = "group votes sum to %d against %d formal" % (r["groups_sum"], r["formal_votes"])
            del r["groups_sum"]
            regions.append(r)
        except Exception as e:  # one bad page must not lose the other seven
            skipped.append({"region": name, "why": str(e)})
    if not regions:
        print("no region parsed: " + json.dumps(skipped), file=sys.stderr)
        return 1
    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=11)))
    doc = {
        "election": "vic2026",
        "kind": "raw_upper_house",
        "built_at": now.strftime("%Y-%m-%dT%H:%M:%S+11:00"),
        "snapshot_stamp": stamp,
        "note": "First preferences counted so far for the Legislative Council, from the VEC's region results pages. "
                "Not a forecast: quotas are the VEC's indicative quotas on first preferences only, before any preferences are distributed.",
        "formal_votes": sum(r["formal_votes"] or 0 for r in regions),
        "regions": regions,
        "skipped": skipped,
    }
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False)
    os.replace(tmp, out)
    print("%d regions, %d formal votes, %d skipped" % (len(regions), doc["formal_votes"], len(skipped)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
