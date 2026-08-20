"""South Australian House of Assembly results, from the ECSA results API.

WHY THIS EXISTS. docs/reviews/onp-allocation-sa-2026-08-17.md already analysed
this election from Wikipedia's compilation of ECSA returns, and states that
"ECSA's own results site is a JavaScript application and serves no static
per-district data; there is no bulk CSV". The first half is true and the
conclusion is not: there is an undocumented API behind the application, and it
serves the official returns directly.

This replaces a third-party transcription with the primary source, and adds
what the transcription does not carry: the TWO-CANDIDATE-PREFERRED count for
every district, meaning who actually made the final two. That is the sharper
form of this election's headline. One Nation won four seats -- already known --
but it made the final two in 32 of 47 districts, while the Liberal Party fell
from 47 of 47 in 2022 to 18.

HOW IT WAS FOUND. results.ecsa.sa.gov.au is an Angular app; the HTML is 1.5KB
of nothing. The API base is a string in the main bundle:

    https://apim-ecsa-production.azure-api.net/results-display/

with two endpoints, neither documented:

    HAStatic/{YYYY-MM-DD}      districts, candidates, parties. No votes.
    HAChange/{YYYY-MM-DD}/{n}  the votes. {n} is a data VERSION, not a count
                               stage -- passing "final" returns a 400 naming
                               the parameter as `version`. Any integer returns
                               the full current state, so 0 is used.

The date must be the exact polling day in ISO form. Every other format returns
204 No Content rather than an error, so a wrong guess looks like an empty
election rather than a bad request.

READING THE VOTES. There are two preference counts and they are not
interchangeable:

    twoCandidatePref   the actual final two, whoever they were
    twoPartyPref       Labor against Liberal, computed ONLY where the final two
                       were not already Labor and Liberal

So a district has one or the other, never a meaningful both -- where the final
two ARE Labor and Liberal the two fields hold identical numbers. Reading only
twoPartyPref finds 21 of 47 districts and silently drops every seat where One
Nation displaced the Liberals, which is the whole story of this election.

Writes CSVs to external/reference/ecsa/ (gitignored, like all data here).
"""

import collections
import csv
import io
import json
import os
import urllib.request

BASE = "https://apim-ecsa-production.azure-api.net/results-display"
OUT = os.path.join("external", "reference", "ecsa")
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120 Safari/537.36")
ELECTIONS = {"2026": "2026-03-21", "2022": "2022-03-19"}


def get(path):
    req = urllib.request.Request(f"{BASE}/{path}", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=180) as r:
        body = r.read()
    if not body:
        raise SystemExit(
            f"{path} returned 204 No Content. The election date is wrong -- ECSA "
            f"answers an unknown date with an empty body rather than an error, "
            f"so this looks like an election with no results in it.")
    return json.loads(body)


def load(date):
    static, change = get(f"HAStatic/{date}"), get(f"HAChange/{date}/0")
    if change.get("electionStatus") != "final":
        print(f"  WARNING: electionStatus is {change.get('electionStatus')!r}, "
              f"not 'final'. These counts may still move.")
    party = {(s["districtName"], c["candidateId"]): c["partyId"]
             for s in static["districts"] for c in s["candidates"]}
    return change, party


def district_rows(change, party):
    rows = []
    for dis in change["districts"]:
        # HAChange names the district in `districtId`; HAStatic uses
        # `districtName`. They hold the same string.
        name = dis["districtId"]
        tcp, tpp, fp = collections.Counter(), collections.Counter(), collections.Counter()
        for pp in dis["pollingPlaces"]:
            for c in pp["pollingCandidates"]:
                p = party.get((name, c["candidateId"]), "?")
                fp[p] += c.get("formalVotes") or 0
                tcp[p] += c.get("twoCandidatePref") or 0
                tpp[p] += c.get("twoPartyPref") or 0
        for c in dis["candidates"]:
            p = party.get((name, c["candidateId"]), "?")
            fp[p] += c.get("declarationVotes") or 0
            tcp[p] += c.get("twoCandidatePrefDeclarationVotes") or 0
            tpp[p] += c.get("twoPartyPrefDeclarationVotes") or 0
        # THERE ARE THREE VOTE POOLS, NOT TWO, AND THE THIRD IS EASY TO MISS.
        # `declarations` holds the same totals as candidates.declarationVotes
        # -- summing both double-counts -- but `absentOrdinary` is separate and
        # is roughly a sixth of the vote (4,068 of 23,894 in Adelaide).
        # Omitting it put One Nation's statewide primary at 22.50% against the
        # 22.88% recorded in docs/reviews/onp-allocation-sa-2026-08-17.md from
        # an independent source, which is the only reason the gap was noticed.
        # The 2022 payload has no absentOrdinary key at all -- ECSA changed the
        # shape between elections -- so this must default rather than index.
        for blk in dis.get("absentOrdinary", []):
            for cv in blk["candidateVotes"]:
                p = party.get((name, cv["candidateId"]), "?")
                fp[p] += cv.get("votes") or 0
                tcp[p] += cv.get("twoCandidatePrefVotes") or 0
        top = tcp.most_common(2)
        if len(top) < 2:
            raise SystemExit(f"{name}: fewer than two candidates have a final "
                             f"preference count, which cannot be a completed seat.")
        pair_total = sum(v for _, v in top)
        total_fp = sum(fp.values())
        # Labor two-party share where one exists. Where the final two were
        # Labor and Liberal, twoPartyPref duplicates twoCandidatePref; where
        # they were not, twoPartyPref is the separate Labor-Liberal count.
        alp_2pp = (100 * tpp["ALP"] / (tpp["ALP"] + tpp["LIB"])
                   if tpp["ALP"] + tpp["LIB"] else None)
        rows.append(dict(
            seat=name, winner=top[0][0], runner_up=top[1][0],
            winner_2cp=round(100 * top[0][1] / pair_total, 3),
            alp_2pp="" if alp_2pp is None else round(alp_2pp, 3),
            formal=total_fp,
            **{f"fp_{p}": round(100 * v / total_fp, 3)
               for p, v in fp.items() if v and p != "?"}))
    return rows


os.makedirs(OUT, exist_ok=True)
for label, date in ELECTIONS.items():
    print(f"SA {label} ({date})")
    change, party = load(date)
    rows = district_rows(change, party)
    if len(rows) != 47:
        raise SystemExit(f"SA {label}: {len(rows)} districts, expected 47.")
    cols = sorted({k for r in rows for k in r})
    lead = ["seat", "winner", "runner_up", "winner_2cp", "alp_2pp", "formal"]
    cols = lead + [c for c in cols if c not in lead]
    path = os.path.join(OUT, f"sa{label}-districts.csv")
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, restval="")
        w.writeheader()
        w.writerows(rows)
    # ANCHOR CHECK, against figures recorded independently before this script
    # existed. It is the only thing that catches a missed vote pool: every
    # internal total is self-consistent whether or not absentOrdinary is
    # included, so nothing in this file can detect its own omission.
    fp_tot = collections.Counter()
    for r in rows:
        for k, v in r.items():
            if k.startswith("fp_"):
                fp_tot[k[3:]] += v * r["formal"] / 100
    grand = sum(fp_tot.values())
    print(f"  formal votes:   {grand:,.0f}")
    print("  statewide first preferences: " + ", ".join(
        f"{p} {100 * v / grand:.2f}%" for p, v in fp_tot.most_common(4)))
    if label == "2026":
        # From docs/reviews/onp-allocation-sa-2026-08-17.md, parsed from
        # Wikipedia's compilation of ECSA returns.
        for p, expect in (("ALP", 37.5), ("ONP", 22.9), ("GRN", 10.4)):
            got = 100 * fp_tot[p] / grand
            flag = "OK" if abs(got - expect) < 0.3 else "MISMATCH"
            print(f"    {flag}  {p}: {got:.2f}% here vs {expect}% recorded")
            if flag == "MISMATCH":
                raise SystemExit(
                    f"{p} differs from the independently recorded share by "
                    f"{abs(got - expect):.2f} points. A vote pool is missing or "
                    f"double-counted; do not use these numbers.")
    won = collections.Counter(r["winner"] for r in rows)
    made_final_two = collections.Counter()
    for r in rows:
        made_final_two[r["winner"]] += 1
        made_final_two[r["runner_up"]] += 1
    print(f"  seats won:      {dict(won.most_common())}")
    print(f"  final two in:   {dict(made_final_two.most_common())}")
    print(f"  wrote {path}")
