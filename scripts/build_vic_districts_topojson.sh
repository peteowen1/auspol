#!/usr/bin/env bash
# Victorian Legislative Assembly districts as TopoJSON for the ITG Politics
# page map (web/vic2026-districts.topojson, uploaded to R2 by forecast.yaml).
# Source: ABS ASGS 2022 State Electoral Divisions (the VEC's 2021
# redistribution, used in 2022 and again in 2026). Static: rerun only if the
# boundaries or the simplification change. Property `seat` must equal the
# `seat` strings in forecast-vic2026.json -- checked by
# scripts/check_vic_districts_topojson.R.
set -euo pipefail
SRC="external/reference/boundaries/SED_2022_AUST_GDA2020.shp"
OUT="web/vic2026-districts.topojson"
mkdir -p web
# Victoria only; drop the ABS's non-geographic codes (no usual address,
# migratory), which carry no polygon. The ABS name is "Albert Park (Southern
# Metropolitan)": split into seat and region (upper-house region). Keep code; ~10% of vertices keeps
# district shapes readable at page scale and the file well under 1 MB.
npx -y mapshaper@0.6 "$SRC" \
  -filter "STE_NAME21 == 'Victoria' && !/No usual address|Migratory/i.test(SED_NAME22)" \
  -filter-fields SED_NAME22,SED_CODE22 \
  -rename-fields seat=SED_NAME22,code=SED_CODE22 \
  -each "var i = seat.indexOf(' ('); region = i > 0 ? seat.slice(i + 2, -1) : null; seat = i > 0 ? seat.slice(0, i) : seat" \
  -filter-fields seat,region,code \
  -rename-layers districts \
  -simplify 10% keep-shapes \
  -o "$OUT" format=topojson quantization=1e5
ls -la "$OUT"
