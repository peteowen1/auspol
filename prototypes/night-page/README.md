# Election-night page prototypes (throwaway; never merged)

Answered the question in #154, "what should the live page show?". Pete, 28 Oct 2026: all three
layouts go on the page, plus a seat map, booth maps and NYT-style swing arrows. Built in #162 and #163.

- `election-night-layouts.html`: A needle, B race to 45, C seat grid, on the vic2022 booth-by-booth
  replay (`scripts/night_replay.R --tcp=1 --gap_k=5 --early=interleaved`). Template `proto.tmpl.html`.
- `election-night-maps.html`: district map with a Melbourne inset, booth map per seat, swing arrows.
  Built by `geo3.R` (ABS SED_2022 boundaries), `prep.py` (booths, 2018-22 swing), `build.py`.
