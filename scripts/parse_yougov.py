"""Extract YouGov's 88-seat MRP table from their published PDF.

Their report is a PDF; `pdftotext -layout` gets close but wraps long seat names
onto a following line and misaligns the percentage columns above each row. Only
the fields this repo actually compares are taken: seat, projected winner,
projected runner-up, the two-party margin between those two, and seat status.

Output goes to external/reference/, which is GITIGNORED. YouGov's numbers are
not committed to this repo -- the same treatment the VEC and anchor data get.
Only the comparison's own output is committed.

    curl -sL -o external/reference/yougov-vic-mrp-2026.pdf \
      https://actionnetwork.org/user_files/user_files/000/146/615/original/yougov-vic-mrp-treaty-report-state-voting-intetion-treaty-support.pdf
    pdftotext -layout external/reference/yougov-vic-mrp-2026.pdf external/reference/yougov.txt
    python scripts/parse_yougov.py

scripts/compare_yougov_seats.R re-checks the result against totals YouGov state
in prose (39/29/17/3) and refuses to go on if they disagree, so a silent parse
regression cannot reach a comparison.
"""
import csv
import io
import re
import sys

SRC = "external/reference/yougov.txt"
OUT = "external/reference/yougov-seats.csv"
PAGES = (29, 30, 31, 32)          # "Detailed MRP projection of results in each seat"
PARTY = r"(Labor|Liberal|National|Coalition|Greens|One Nation|Independent|Ind)"
ROW = re.compile(
    r"^(?P<seat>.+?)\s{2,}.*?\s" + PARTY + r"\s{2,}" + PARTY +
    r"\s{2,}(?P<tpp>\d{1,2}\.\d)%\s*(?P<status>.*)$")
# A wrapped seat name continues as a bare word on the next line: "Narre Warren"
# / "North", "South-West" / "Coast". Without this, three seats are lost and two
# collide under one name -- which reads as a complete table one row short.
CONT = {"North", "South", "East", "West", "Coast", "Valley", "Plains"}


def main() -> int:
    text = io.open(SRC, encoding="utf-8", errors="replace").read()
    pages = text.split("\f")
    seats = {}
    for pn in PAGES:
        lines = pages[pn - 1].split("\n")
        for i, line in enumerate(lines):
            if "%" not in line:
                continue
            m = ROW.match(line.rstrip())
            if not m:
                continue
            seat = re.sub(r"\s*\d{1,3}%.*$", "", m.group("seat")).strip()
            if not seat or seat.startswith("SED"):
                continue
            if i + 1 < len(lines):
                nxt = lines[i + 1].strip()
                first = nxt.split()[0] if nxt else ""
                if first in CONT and not re.match(r"^\d", nxt):
                    seat = seat + ("-" if seat.endswith("South-West") else " ") + first
                    seat = seat.replace("South-West-Coast", "South-West Coast")
            seats[seat] = dict(seat=seat, winner=m.group(2), runner_up=m.group(3),
                               tpp=float(m.group("tpp")),
                               status=m.group("status").strip())
    if len(seats) != 88:
        print(f"ERROR: parsed {len(seats)} seats, expected 88. "
              "Check the wrapped-name handling before trusting this.",
              file=sys.stderr)
        return 1
    with io.open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["seat", "winner", "runner_up", "tpp", "status"])
        w.writeheader()
        for k in sorted(seats):
            w.writerow(seats[k])
    print(f"wrote {OUT} ({len(seats)} seats)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
