#!/usr/bin/env python
"""Queensland 2015 booth first preferences, for the qld2015 -> qld2017 notional prior.

Runs the parser in scripts/parse_booths_nsw_qld.py on the 2015 results file
(external/reference/ecq/raw/2015/publicResults.xml, the old results-site schema it
already reads for 2017) and writes output/booths/qld2015-booth-fp.csv with the same
columns and the same validation (89 districts, district totals against
external/elections/ecq-2015-qld-firstprefs.csv). Kept as its own script so the
NSW/Queensland job list in the parent does not change.

Run: python scripts/parse_booths_qld2015.py   (exit 1 on any validation failure)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import parse_booths_nsw_qld as P  # noqa: E402


def main():
    P.OUT.mkdir(parents=True, exist_ok=True)
    # coordinates are only for display; the notional matches venues by name, so none are needed
    fp, tcp, informal = P.parse_qld(2015, [P.venue_dir(2020), P.venue_dir(2024)])
    fp.to_csv(P.OUT / "qld2015-booth-fp.csv", index=False)
    print(f"qld2015: rows fp={len(fp)} formal votes={int(fp['votes'].sum())} informal skipped={informal}")
    print(f"  vote types: {fp.groupby('vote_type')['votes'].sum().astype(int).to_dict()}")
    bad = P.validate("qld2015", fp, tcp, 89, "external/elections/ecq-2015-qld-firstprefs.csv")
    print("FAILED" if bad else "ALL CHECKS PASSED")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
