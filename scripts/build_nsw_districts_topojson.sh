#!/usr/bin/env bash
# New South Wales Legislative Assembly districts as TopoJSON for the ITG NSW
# page map (web/nsw2027-districts.topojson, uploaded to R2 by forecast.yaml).
# Source: ABS ASGS 2022 State Electoral Divisions (the NSW 2021
# redistribution, used in 2023 and again in 2027). A copy of
# build_vic_districts_topojson.sh with the state filter changed; same
# simplification. NSW names carry no " (Region)" suffix, so `region` is null.
# Property `seat` must equal the `seat` strings in forecast-nsw2027.json --
# checked by scripts/check_nsw_districts_topojson.R.
set -euo pipefail
SRC="external/reference/boundaries/SED_2022_AUST_GDA2020.shp"
OUT="web/nsw2027-districts.topojson"
mkdir -p web
npx -y mapshaper@0.6 "$SRC" \
  -filter "STE_NAME21 == 'New South Wales' && !/No usual address|Migratory/i.test(SED_NAME22)" \
  -filter-fields SED_NAME22,SED_CODE22 \
  -rename-fields seat=SED_NAME22,code=SED_CODE22 \
  -each "var i = seat.indexOf(' ('); region = i > 0 ? seat.slice(i + 2, -1) : null; seat = i > 0 ? seat.slice(0, i) : seat" \
  -filter-fields seat,region,code \
  -rename-layers districts \
  -simplify 10% keep-shapes \
  -o "$OUT" format=topojson quantization=1e5
ls -la "$OUT"
