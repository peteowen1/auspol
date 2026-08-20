"""Full distribution of preferences, every SA district, from the ECSA API.

WHY. docs/reviews/onp-allocation-sa-2026-08-17.md estimated a preference
transfer matrix and then said what was wrong with it:

    "16 districts is not enough. 97 events spread across 28 distinct cells,
     most with n <= 2."
    "Settling the seat count needs full distribution-of-preferences tables
     across many elections -- a materially larger acquisition than the
     first-preference data, and the real blocker on the rebuild."

It had 16 districts because it parsed Wikipedia, which publishes a full
distribution for only some seats. The ECSA API carries `finalDistribution` for
ALL 47, with every exclusion round, every candidate's vote change, and -- the
part that matters -- who was still standing when each transfer happened.

That is roughly 294 exclusion events instead of 97, from the same election.
This does not fix the "one state, one election" gap, which no amount of SA data
can.

WHAT AN EXCLUSION EVENT IS. Round 0 is first preferences, not a transfer. Each
later round excludes one candidate and distributes their pile. A row here is:

    excluded party, the set of parties still standing, votes to each

conditioned on the survivor set, because the review's own numbers show the
conditioning is the whole story -- One Nation's flow to Labor moved from 19.3%
to 57.0% depending on who else remained, against the model's fixed 33.7.

EXHAUSTION. South Australia uses full preferential voting, so a ballot should
always express a further preference and transfers should sum to the excluded
pile. That is CHECKED rather than assumed: a shortfall would mean either
exhausted ballots or a misread payload, and both change the flow rates.
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
        raise SystemExit(f"{path}: 204 No Content -- wrong election date.")
    return json.loads(body)


def name_key(s):
    """A candidate name reduced to something both payloads agree on.

    THE TWO PAYLOADS USE DIFFERENT CANDIDATE IDs FOR THE SAME PERSON, and give
    no sign of it. `pollingCandidates` and HAStatic number candidates 1..n by
    ballot position within a district; `finalDistribution` uses a global id, so
    Hammond's James Murphy is candidateId 1 in one and 1350 in the other.

    Joining on the id anyway is silent: every lookup misses, every party comes
    back "?", and the output is 294 transfer events in ONE cell rather than an
    error. That is what happened on the first run.

    The formats differ too -- "MURPHY, James" against "James MURPHY" -- so both
    are reduced to a sorted set of upper-case name tokens, which is stable
    against the ordering and the comma.
    """
    return " ".join(sorted(s.replace(",", " ").upper().split()))


def transfers(change, party_by_name):
    rows, skipped = [], []
    for dis in change["districts"]:
        name = dis["districtId"]
        rounds = dis.get("finalDistribution") or []
        if len(rounds) < 2:
            skipped.append(name)
            continue
        # A candidate is "standing" for a round if they had not been excluded
        # BEFORE it. Excluded-in-this-round counts as standing, then leaves.
        gone = set()
        pty = lambda cid_name: party_by_name.get((name, name_key(cid_name)), "?")
        unknown = {c["candidateName"] for r in rounds
                   for c in r["candidateResults"]
                   if pty(c["candidateName"]) == "?"}
        if unknown:
            raise SystemExit(
                f"{name}: no party for {sorted(unknown)}. The name join between "
                f"finalDistribution and HAStatic has failed; every rate computed "
                f"from this would be pooled into one meaningless cell.")
        for rnd in rounds:
            if rnd["roundNumber"] == 0:
                continue
            res = rnd["candidateResults"]
            ex = next((c for c in res if c["isExcluded"] and c["voteChange"] < 0),
                      None)
            if ex is None:
                ex = next((c for c in res if name_key(c["candidateName"])
                           == name_key(rnd["excludedCandidateName"])), None)
            if ex is None:
                raise SystemExit(f"{name} round {rnd['roundNumber']}: cannot "
                                 f"identify the excluded candidate.")
            ex_key = name_key(ex["candidateName"])
            pile = rnd["excludedCandidateVotes"]
            by_party = collections.Counter()
            moved = 0
            for c in res:
                k = name_key(c["candidateName"])
                if k in gone or k == ex_key:
                    continue
                v = c["voteChange"] or 0
                if v > 0:
                    by_party[pty(c["candidateName"])] += v
                    moved += v
            # Survivors are the parties still standing AFTER this exclusion --
            # the choice set the transferring voters actually faced.
            survivors = sorted({pty(c["candidateName"]) for c in res
                                if name_key(c["candidateName"]) not in gone
                                and name_key(c["candidateName"]) != ex_key})
            rows.append(dict(
                seat=name, round=rnd["roundNumber"],
                excluded_party=pty(ex["candidateName"]),
                pile=pile, moved=moved, exhausted=pile - moved,
                survivors="|".join(survivors),
                **{f"to_{p}": v for p, v in by_party.items()}))
            gone.add(ex_key)
    return rows, skipped


os.makedirs(OUT, exist_ok=True)
for label, date in ELECTIONS.items():
    static, change = get(f"HAStatic/{date}"), get(f"HAChange/{date}/0")
    party_by_name = {(s["districtName"], name_key(c["candidateName"])): c["partyId"]
                     for s in static["districts"] for c in s["candidates"]}
    rows, skipped = transfers(change, party_by_name)
    if not rows:
        print(f"\nSA {label}: no finalDistribution in this payload -- ECSA "
              f"publishes full preference distributions for 2026 and not 2022, "
              f"so this election cannot contribute transfer rates.")
        continue
    print(f"\nSA {label}: {len(rows)} exclusion events across "
          f"{len({r['seat'] for r in rows})} districts")
    if skipped:
        print(f"  {len(skipped)} districts have no distribution: {', '.join(skipped)}")

    # THE CHECK THAT DECIDES WHETHER THESE RATES ARE USABLE. Full preferential
    # voting should move the whole pile; a shortfall is exhausted ballots or a
    # misread payload, and either one biases every rate computed from this.
    tot_pile = sum(r["pile"] for r in rows)
    tot_moved = sum(r["moved"] for r in rows)
    lost = tot_pile - tot_moved
    print(f"  votes excluded {tot_pile:,}, transferred {tot_moved:,}, "
          f"unaccounted {lost:,} ({100 * lost / tot_pile:.3f}%)")
    if abs(lost) > 0.01 * tot_pile:
        worst = sorted(rows, key=lambda r: -(r["pile"] - r["moved"]))[:5]
        for w in worst:
            print(f"    {w['seat']} r{w['round']}: pile {w['pile']:,} "
                  f"moved {w['moved']:,}")
        raise SystemExit(
            f"{100 * lost / tot_pile:.2f}% of transferred votes are "
            f"unaccounted for. South Australia is full preferential, so this is "
            f"a misread payload rather than exhaustion; the flow rates would be "
            f"wrong by that much.")

    cells = collections.Counter((r["excluded_party"], r["survivors"]) for r in rows)
    print(f"  distinct (excluded party, survivor set) cells: {len(cells)}")
    print(f"  cells with n >= 5: {sum(1 for c in cells.values() if c >= 5)}"
          f"; with n == 1: {sum(1 for c in cells.values() if c == 1)}")

    cols = sorted({k for r in rows for k in r})
    lead = ["seat", "round", "excluded_party", "survivors", "pile", "moved",
            "exhausted"]
    cols = lead + [c for c in cols if c not in lead]
    path = os.path.join(OUT, f"sa{label}-transfers.csv")
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols, restval=0)
        w.writeheader()
        w.writerows(rows)
    print(f"  wrote {path}")
