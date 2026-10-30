#!/usr/bin/env python
"""Parse the AEC election-night media feed snapshots (Detailed-Verbose zips) into
booth reporting times, per-division progress and a national progress line.

Usage:  python -I scripts/parse_aec_mediafeed.py <eventid> [--limit N]
        eventid 27966 = federal 2022, 31496 = federal 2025.

Reads external/reference/aec/mediafeed/<eventid>/*.zip (never unpacks to disk, one
zip at a time, stdlib only) and writes to output/night-feed/:
  raw-pp-fed<year>.csv.gz        every polling-place field the feed carries, CHANGE-ONLY:
                                 all items of a polling place are written at each
                                 snapshot where any of its figures changed (and at the
                                 first snapshot it appears); nothing else is dropped
  booth-returns-fed<year>.csv    one row per polling place / declaration vote type
  division-progress-fed<year>.csv  per division per snapshot
  division-fp-fed<year>.csv      per division per snapshot per first-preference candidate
  national-progress-fed<year>.csv  per snapshot
  summary-fed<year>.txt          checks and answers (printed too)
Snapshot time = the feed's own Created attribute (Canberra local time, AEST in May;
the zip filename time equals it, checked below).  Re-run from scratch when new zips land.
"""
import sys, os, re, csv, gzip, zipfile, json, statistics, collections, datetime as dt
import xml.etree.ElementTree as ET

ROOT = r"C:\dev\auspol"
EVENTS = {"27966": 2022, "31496": 2025}
VT = ["Ordinary", "Absent", "Provisional", "PrePoll", "Postal"]
DECL = ["Absent", "Provisional", "PrePoll", "Postal"]


def ln(tag):
    return tag.rsplit("}", 1)[-1]


def kids(e, name):
    return [c for c in e if ln(c.tag) == name]


def kid(e, name):
    for c in e:
        if ln(c.tag) == name:
            return c
    return None


def toint(s):
    try:
        return int(s)
    except Exception:
        try:
            return int(float(s))
        except Exception:
            return None


def votes_of(el):
    """(votes, attrs dict) of the <Votes> child of el; (None, {}) if absent."""
    v = kid(el, "Votes")
    if v is None:
        return None, {}
    return toint((v.text or "").strip()), dict(v.attrib)


def by_type(el):
    out = {}
    vbt = kid(el, "VotesByType")
    if vbt is not None:
        for v in kids(vbt, "Votes"):
            out[v.attrib.get("Type")] = (toint((v.text or "").strip()), dict(v.attrib))
    return out


def cand_info(c):
    ci = kid(c, "CandidateIdentifier")
    cid = ci.attrib.get("Id") if ci is not None else None
    name = None
    if ci is not None:
        n = kid(ci, "CandidateName")
        name = n.text if n is not None else None
    ai = kid(c, "AffiliationIdentifier")
    party = ai.attrib.get("ShortCode") if ai is not None else None
    return cid, name, party


KNOWN_ATTR = {"Historic", "Percentage", "Swing", "MatchedHistoric", "Type"}


def other_attrs(a):
    o = {k: v for k, v in a.items() if k not in KNOWN_ATTR}
    return json.dumps(o, sort_keys=True) if o else ""


def parse_zip(path, unknown_tags):
    """Return dict of everything in one snapshot."""
    with zipfile.ZipFile(path) as z:
        xml = [n for n in z.namelist() if n.startswith("xml/") and n.endswith(".xml")]
        if len(xml) != 1:
            raise ValueError("expected one xml, got %s" % xml)
        snap = {"created": None, "results_updated": None, "divs": [], "div_fp": []}
        in_house = False
        with z.open(xml[0]) as f:
            for ev, el in ET.iterparse(f, events=("start", "end")):
                t = ln(el.tag)
                if ev == "start":
                    if t == "MediaFeed":
                        snap["created"] = el.attrib.get("Created")
                    elif t == "Results":
                        snap["results_updated"] = el.attrib.get("Updated")
                    elif t == "House":
                        in_house = True
                    elif t == "Senate":
                        in_house = False
                    continue
                if t == "Contest":
                    if in_house:
                        proc_contest(el, snap, unknown_tags)
                    el.clear()
    return snap


KNOWN_CONTEST = {"ContestIdentifier", "PollingDistrictIdentifier", "Enrolment", "FirstPreferences",
                 "TwoCandidatePreferred", "TwoPartyPreferred", "PollingPlaces"}


def proc_contest(c, snap, unknown):
    for ch in c:
        if ln(ch.tag) not in KNOWN_CONTEST:
            unknown[ln(ch.tag)] += 1
    ci = kid(c, "ContestIdentifier")
    div_id = ci.attrib.get("Id")
    name = kid(ci, "ContestName").text
    pdi = kid(c, "PollingDistrictIdentifier")
    state = None
    if pdi is not None:
        si = kid(pdi, "StateIdentifier")
        state = si.attrib.get("Id") if si is not None else None
    enr = kid(c, "Enrolment")
    d = {"division_id": div_id, "division": name, "state": state,
         "shortcode": pdi.attrib.get("ShortCode") if pdi is not None else None,
         "enrolment": toint(enr.text) if enr is not None else None,
         "enrolment_close_of_rolls": enr.attrib.get("CloseOfRolls") if enr is not None else None,
         "contest_updated": c.attrib.get("Updated"), "projected": c.attrib.get("Projected")}
    for k, v in c.attrib.items():
        if k not in ("Updated", "Projected"):
            d["contest_attr_" + k] = v
    cands = {}  # candidate id -> (name, party)
    fp = kid(c, "FirstPreferences")
    if fp is not None:
        d["fp_updated"] = fp.attrib.get("Updated")
        d["fp_other_attrs"] = json.dumps({k: v for k, v in fp.attrib.items() if k not in ("Updated", "PollingPlacesReturned", "PollingPlacesExpected")}, sort_keys=True)
        d["fp_returned"] = toint(fp.attrib.get("PollingPlacesReturned"))
        d["fp_expected"] = toint(fp.attrib.get("PollingPlacesExpected"))
        for k in ("Candidate", "Ghost"):
            for cc in kids(fp, k):
                cid, nm, pty = cand_info(cc)
                v, a = votes_of(cc)
                bt = by_type(cc)
                if k == "Candidate":
                    cands[cid] = (nm, pty)
                    snap["div_fp"].append({"division_id": div_id, "division": name, "kind": k, "candidate_id": cid,
                                           "candidate": nm, "party": pty,
                                           "ballot_position": (kid(cc, "BallotPosition").text if kid(cc, "BallotPosition") is not None else ""),
                                           "elected": (kid(cc, "Elected").text if kid(cc, "Elected") is not None else ""),
                                           "votes": v, "percentage": a.get("Percentage"), "swing": a.get("Swing"),
                                           "historic": a.get("Historic"),
                                           **{("v_" + t): (bt[t][0] if t in bt else None) for t in VT}})
                    d.setdefault("_fp_cand_votes", []).append((cid, v, {t: (bt[t][0] if t in bt else 0) for t in VT}))
        for k in ("Formal", "Informal", "Total"):
            e = kid(fp, k)
            if e is not None:
                v, a = votes_of(e)
                bt = by_type(e)
                d["fp_%s" % k.lower()] = v
                d["fp_%s_pct" % k.lower()] = a.get("Percentage")
                for t in VT:
                    d["fp_%s_%s" % (k.lower(), t.lower())] = bt[t][0] if t in bt else None
    tcp = kid(c, "TwoCandidatePreferred")
    if tcp is not None:
        d["tcp_updated"] = tcp.attrib.get("Updated")
        d["tcp_maverick"] = tcp.attrib.get("Maverick", "")
        d["tcp_other_attrs"] = json.dumps({k: v for k, v in tcp.attrib.items() if k not in ("Updated", "Maverick", "PollingPlacesReturned", "PollingPlacesExpected")}, sort_keys=True)
        d["tcp_returned"] = toint(tcp.attrib.get("PollingPlacesReturned"))
        d["tcp_expected"] = toint(tcp.attrib.get("PollingPlacesExpected"))
        tc = kids(tcp, "Candidate")
        tot = 0
        for i, cc in enumerate(tc, 1):
            cid, nm, pty = cand_info(cc)
            v, a = votes_of(cc)
            bt = by_type(cc)
            tot += v or 0
            d["tcp%d_id" % i] = cid
            d["tcp%d_name" % i] = nm
            d["tcp%d_party" % i] = pty
            d["tcp%d_votes" % i] = v
            d["tcp%d_pct" % i] = a.get("Percentage")
            d["tcp%d_ordinary" % i] = bt["Ordinary"][0] if "Ordinary" in bt else None
            cands.setdefault(cid, (nm, pty))
        d["tcp_n_cands"] = len(tc)
        d["tcp_total_votes"] = tot
        d["tcp_pair"] = " v ".join(sorted((kid(kid(cc, "CandidateIdentifier"), "CandidateName").text or "") for cc in tc))
        d["tcp_pair_ids"] = "-".join(sorted(cand_info(cc)[0] for cc in tc))
    tpp = kid(c, "TwoPartyPreferred")
    if tpp is not None:
        for co in kids(tpp, "Coalition"):
            cid = kid(co, "CoalitionIdentifier")
            v, a = votes_of(co)
            d["tpp_%s_votes" % cid.attrib.get("ShortCode")] = v
    # ---- polling places
    pps = {}
    pp_el = kid(c, "PollingPlaces")
    if pp_el is not None:
        for pp in kids(pp_el, "PollingPlace"):
            pi = kid(pp, "PollingPlaceIdentifier")
            ppid = pi.attrib.get("Id")
            info = dict(pi.attrib)
            items = []  # (section, kind, cand_id, vtype, votes, hist, pct, swing, matched, other)
            for sec in ("FirstPreferences", "TwoCandidatePreferred"):
                s = kid(pp, sec)
                if s is None:
                    continue
                for e in s:
                    k = ln(e.tag)
                    cid = None
                    if k in ("Candidate", "Ghost"):
                        cid = cand_info(e)[0]
                    v, a = votes_of(e)
                    items.append((sec, k, cid, "", v, a.get("Historic"), a.get("Percentage"), a.get("Swing"),
                                  a.get("MatchedHistoric"), other_attrs(a)))
                    for t, (bv, ba) in by_type(e).items():
                        items.append((sec, k, cid, t, bv, ba.get("Historic"), ba.get("Percentage"), ba.get("Swing"),
                                      ba.get("MatchedHistoric"), other_attrs(ba)))
                for k2, v2 in s.attrib.items():
                    items.append((sec, "@" + k2, None, "", None, None, None, None, None, v2))
            for ch in pp:
                if ln(ch.tag) not in ("PollingPlaceIdentifier", "FirstPreferences", "TwoCandidatePreferred"):
                    unknown["PollingPlace/" + ln(ch.tag)] += 1
            pps[ppid] = (info, items)
    d["_pps"] = pps
    d["_cands"] = cands
    snap["divs"].append(d)


DIV_COLS = (["snapshot_time", "division_id", "division", "state", "shortcode", "enrolment", "enrolment_close_of_rolls",
             "contest_updated", "projected", "contest_attrs", "fp_updated", "fp_returned", "fp_expected", "fp_other_attrs"]
            + ["fp_%s%s" % (k, ("_" + t.lower()) if t else "") for k in ("formal", "informal", "total") for t in [""] + VT]
            + ["fp_formal_pct", "fp_informal_pct", "fp_total_pct",
               "tcp_updated", "tcp_maverick", "tcp_other_attrs", "tcp_returned", "tcp_expected", "tcp_n_cands", "tcp_pair", "tcp_pair_ids", "tcp_total_votes"]
            + ["tcp%d_%s" % (i, f) for i in (1, 2, 3) for f in ("id", "name", "party", "votes", "pct", "ordinary")]
            + ["tpp_ALP_votes", "tpp_LNC_votes", "tpp_LP_votes", "tpp_NP_votes", "tpp_LNP_votes",
               "ordinary_cand_votes_sum", "pp_fp_votes_sum", "pps_in_feed", "pps_nonzero", "cand_absent_votes",
               "cand_provisional_votes", "cand_prepoll_votes", "cand_postal_votes", "cand_votes_sum",
               "share_enrolment_counted", "tcp_pair_changed"])


def tstr(s):
    return s.replace("T", " ") if s else s


def load_final(year):
    final_booth = collections.defaultdict(lambda: collections.defaultdict(int))
    final_div_total = collections.defaultdict(int)
    with open(os.path.join(ROOT, "output", "booths-fed%d.csv" % year), encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            v = toint(r["votes"]) or 0
            final_div_total[r["district"]] += v
            if r["booth_type"] == "ordinary":
                final_booth[r["district"]][r["booth"]] += v
    return final_booth, final_div_total


def report_from_disk(year, ev, outdir, tag):
    """Rebuild summary-fed<year>.txt from the written CSVs (no re-parse). Parse-time checks are not recomputed."""
    final_booth, final_div_total = load_final(year)
    rec = {}; div_meta = {}
    with open(os.path.join(outdir, "booth-returns-fed%d%s.csv" % (year, tag)), encoding="utf-8", newline="") as f:
        for i, r in enumerate(csv.DictReader(f)):
            div_meta[r["division_id"]] = (r["division"], r["state"])
            if r["classification"].startswith("declaration"):
                continue
            r["fp_exact_flag"] = toint(r["fp_exact_flag"]) if r["fp_exact_flag"] != "" else ""
            r["joined_booths_csv"] = toint(r["joined_booths_csv"])
            rec[i] = r
    nat_rows = []
    with open(os.path.join(outdir, "national-progress-fed%d%s.csv" % (year, tag)), encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            nat_rows.append({"snapshot_time": r["snapshot_time"], "formal": int(r["formal"]), "informal": int(r["informal"]),
                             "returned": int(r["returned"]), "expected": int(r["expected"])})
    report(year, ev, len(nat_rows), nat_rows, [], [0], {}, rec, div_meta, outdir, tag,
           final_booth, final_div_total, sum(final_div_total.values()), True)


def report(year, ev, zips_n, nat_rows, failures, time_diffs, unknown, rec, div_meta, outdir, tag,
           final_booth, final_div_total, final_formal, have_div):
    # ---------------- checks & answers
    out = []
    P = out.append
    P("# summary fed%d (event %s)  zips=%d parsed=%d failures=%d" % (year, ev, zips_n, len(nat_rows), len(failures)))
    for fn, e in failures:
        P("FAILED %s %s" % (fn, e))
    if nat_rows:
        P("first snapshot %s  last snapshot %s" % (nat_rows[0]["snapshot_time"], nat_rows[-1]["snapshot_time"]))
        P("Created minus filename time: min %.0fs max %.0fs (0 means filename time == feed Created, i.e. same clock)" % (min(time_diffs), max(time_diffs)))
    P("unknown tags (counts): %s" % dict(unknown))
    pp_recs = [r for r in rec.values()]
    P("polling places in feed: %d ; ever reported FP: %d ; ever reported TCP: %d" % (
        len(pp_recs), sum(1 for r in pp_recs if r["fp_first_seen"]), sum(1 for r in pp_recs if r["tcp_first_seen"])))
    P("classification counts: %s" % dict(collections.Counter(r["classification"] or "(none)" for r in pp_recs)))
    unm = [r for r in pp_recs if r["joined_booths_csv"] == 0]
    P("join to booths-fed%d.csv by (division, name): matched %d / %d feed places; unmatched %d" % (
        year, len(pp_recs) - len(unm), len(pp_recs), len(unm)))
    unm_rep = [r for r in unm if r["fp_first_seen"]]
    P("  of unmatched, ones that reported votes: %d ; by classification: %s" % (
        len(unm_rep), dict(collections.Counter(r["classification"] or "(none)" for r in unm_rep))))
    for r in unm_rep[:60]:
        P("    UNMATCHED %s | %s | %s | last votes %s" % (r["division"], r["polling_place"], r["classification"], r["fp_votes_last"]))
    # booth names in csv not in feed
    feed_names = collections.defaultdict(set)
    for r in pp_recs:
        feed_names[r["division"]].add(r["polling_place"])
    miss = [(dv, b, v) for dv, bb in final_booth.items() for b, v in bb.items() if b not in feed_names.get(dv, set())]
    P("booths in booths-fed%d.csv (ordinary) with no feed place of that name: %d of %d (votes %d of %d)" % (
        year, len(miss), sum(len(b) for b in final_booth.values()), sum(v for _, _, v in miss),
        sum(sum(b.values()) for b in final_booth.values())))
    for dv, b, v in sorted(miss, key=lambda x: -x[2])[:40]:
        P("    CSV-ONLY %s | %s | %d votes" % (dv, b, v))
    div_names_feed = {n for n, _ in div_meta.values()}
    P("divisions: feed %d ; booths csv %d ; in feed not csv %s ; in csv not feed %s" % (
        len(div_names_feed), len(final_booth), sorted(div_names_feed - set(final_booth)), sorted(set(final_booth) - div_names_feed)))

    # last snapshot ordinary totals vs final
    last_rows = []
    if have_div:
        with open(os.path.join(outdir, "division-progress-fed%d%s.csv" % (year, tag)), encoding="utf-8", newline="") as f:
            rows = list(csv.DictReader(f))
        lastT = rows[-1]["snapshot_time"]
        last_rows = [r for r in rows if r["snapshot_time"] == lastT]
        P("last snapshot %s : divisions %d" % (lastT, len(last_rows)))
        P("division | feed pp ordinary FP sum | feed division ordinary cand sum | final ordinary (csv) | ratio pp/final | feed total all types | final all types")
        bad = 0
        tot_feed = tot_fin = 0
        for r in sorted(last_rows, key=lambda r: r["division"]):
            fin = sum(final_booth.get(r["division"], {}).values())
            fpp = int(r["pp_fp_votes_sum"] or 0)
            fdo = int(r["ordinary_cand_votes_sum"] or 0)
            tot_feed += fpp; tot_fin += fin
            ratio = fpp / fin if fin else float("nan")
            if ratio > 1.0 or ratio < 0.9:
                bad += 1
                P("  FLAG %-16s pp=%7d divord=%7d final=%7d ratio=%.3f feedall=%s finalall=%d" % (
                    r["division"], fpp, fdo, fin, ratio, r["fp_total"], final_div_total.get(r["division"], 0)))
        P("overall last-snapshot pp FP sum %d vs final ordinary %d (ratio %.4f); divisions flagged (ratio >1 or <0.9): %d" % (
            tot_feed, tot_fin, tot_feed / tot_fin if tot_fin else float("nan"), bad))
        # booths per division
        P("booths per division: feed places that reported by last snapshot vs csv ordinary booth count (diff = csv - feed)")
        diffs = []
        for r in sorted(last_rows, key=lambda r: r["division"]):
            n_rep = sum(1 for x in pp_recs if x["division"] == r["division"] and x["fp_first_seen"])
            n_csv = len(final_booth.get(r["division"], {}))
            diffs.append((r["division"], n_rep, n_csv, int(r["pps_in_feed"])))
        P("  divisions where reported-in-feed != csv: %d of %d" % (sum(1 for d in diffs if d[1] != d[2]), len(diffs)))
        for d in diffs:
            if abs(d[1] - d[2]) >= 3:
                P("    %-16s feed_reported=%d csv=%d feed_listed=%d" % (d[0], d[1], d[2], d[3]))

    # ---- reporting time by state
    def hm(s):
        return s[11:16] if s else ""

    def q(vals, p):
        vals = sorted(vals)
        if not vals:
            return None
        k = (len(vals) - 1) * p
        lo = int(k); hi = min(lo + 1, len(vals) - 1)
        return vals[lo] + (vals[hi] - vals[lo]) * (k - lo)

    def to_dt(s):
        return dt.datetime.strptime(s, "%Y-%m-%d %H:%M:%S")

    def fmt(x):
        return x.strftime("%H:%M") if x else ""
    base = dt.datetime.strptime(nat_rows[0]["snapshot_time"][:10], "%Y-%m-%d") if nat_rows else None
    P("")
    P("TABLE booth first-preference return time by state (Canberra/AEST clock; polling places that reported by last snapshot; fp_first_seen = first snapshot with non-zero votes)")
    P("state | n places | first | median | p90 | last")
    states = sorted({r["state"] for r in pp_recs})
    for scope, filt in (("ALL places", lambda r: True), ("ORDINARY places (classification none)", lambda r: not r["classification"]),
                        ("PRE-POLL centres", lambda r: r["classification"] == "PrePollVotingCentre")):
        P("  -- " + scope)
        for st in states + ["ALL"]:
            xs = [to_dt(r["fp_first_seen"]) for r in pp_recs if r["fp_first_seen"] and (st == "ALL" or r["state"] == st) and filt(r)]
            if not xs:
                continue
            secs = [(x - base).total_seconds() for x in xs]
            f = lambda s: fmt(base + dt.timedelta(seconds=s))
            P("  %s | %d | %s | %s | %s | %s" % (st, len(xs), f(min(secs)), f(q(secs, .5)), f(q(secs, .9)), f(max(secs))))
    P("  (exact-time subset: places whose division had exactly one new booth that snapshot, so Updated gives the true return time)")
    ex = [r for r in pp_recs if r["fp_exact_flag"] == 1]
    if ex:
        gaps = [(to_dt(r["fp_first_seen"]) - to_dt(r["fp_exact"])).total_seconds() for r in ex if r["fp_exact"]]
        P("  exact-time places: %d ; snapshot-minus-exact gap seconds: median %.0f, p90 %.0f, max %.0f, min %.0f" % (
            len(ex), q(gaps, .5), q(gaps, .9), max(gaps), min(gaps)))

    # Wentworth progress
    went = [r for r in (rows if have_div else []) if r["division"] == "Wentworth"]
    if went:
        P("")
        P("TABLE Wentworth (division %s) progress at clock times (latest snapshot at or before the time)" % went[0]["division_id"])
        P("time | snapshot | booths returned/expected (FP) | TCP booths | total votes (all types) | share of enrolment | share of final formal | ordinary cand sum | pp places non-zero/listed | TCP pair")
        fin_w = final_div_total.get("Wentworth", 0)
        day = went[0]["snapshot_time"][:10]
        for hh in (18, 19, 20, 21, 22, 23):
            cut = "%s %02d:00:00" % (day, hh)
            cand = [r for r in went if r["snapshot_time"] <= cut]
            if not cand:
                P("%02d:00 | none yet" % hh); continue
            r = cand[-1]
            P("%02d:00 | %s | %s/%s | %s/%s | %s | %.1f%% | %.1f%% | %s | %s/%s | %s" % (
                hh, r["snapshot_time"][11:19], r["fp_returned"], r["fp_expected"], r["tcp_returned"], r["tcp_expected"],
                r["fp_total"], 100 * float(r["share_enrolment_counted"] or 0),
                100 * int(r["fp_formal"] or 0) / fin_w if fin_w else float("nan"), r["ordinary_cand_votes_sum"],
                r["pps_nonzero"], r["pps_in_feed"], r["tcp_pair"]))
        seq = []
        for r in went:
            if not seq or seq[-1][1] != (r["tcp_pair"] or "(none)"):
                seq.append((r["snapshot_time"], r["tcp_pair"] or "(none)"))
        P("Wentworth TCP pair sequence (snapshot time first shown, pair): %s" % seq)

    # AEC TCP pair sequences: divisions where the counted pair changed
    if have_div:
        P("")
        P("TABLE divisions where the AEC changed its counted two-candidate pair on the night (first shown -> pair; final pair last)")
        bydiv = collections.defaultdict(list)
        for r in rows:
            L = bydiv[r["division"]]
            if (not L and not r["tcp_pair"]) :
                continue  # before the AEC publishes any pair
            if not L or L[-1][1] != (r["tcp_pair"] or "(none)"):
                L.append((r["snapshot_time"][11:16], r["tcp_pair"] or "(none)", r["tcp_total_votes"]))
        nchg = 0
        for dv, L in sorted(bydiv.items()):
            if len({x[1] for x in L if x[1] != "(none)"}) > 1:
                nchg += 1
                P("  %s: %s" % (dv, " -> ".join("%s [%s, tcp votes %s]" % (p, t, v) for t, p, v in L)))
        P("  divisions with a pair change: %d of %d" % (nchg, len(bydiv)))
        P("  divisions where the pair was withdrawn (blank) at some point but came back as the same pair: %d" % sum(
            1 for dv, L in bydiv.items() if len({x[1] for x in L if x[1] != "(none)"}) == 1 and any(x[1] == "(none)" for x in L)))
        P("  divisions where the last snapshot shows no pair: %d" % sum(1 for dv, L in bydiv.items() if L and L[-1][1] == "(none)"))
        # Spender v Sharma
        if year == 2022:
            hit = [r for r in went if "SPENDER" in (r["tcp_pair"] or "").upper() and "SHARMA" in (r["tcp_pair"] or "").upper()]
            if hit:
                P("Spender v Sharma first shown as the counted pair at snapshot %s (division TCP Updated %s; tcp votes then %s, booths %s/%s)" % (
                    hit[0]["snapshot_time"], hit[0]["tcp_updated"], hit[0]["tcp_total_votes"], hit[0]["tcp_returned"], hit[0]["tcp_expected"]))
            else:
                P("Spender v Sharma never appeared as the counted pair in the snapshots parsed")

    P("")
    P("TABLE national progress at clock times (latest snapshot at or before): formal = first-preference formal votes counted, all vote types")
    P("time | snapshot | formal | informal | %% of final formal (%d) | places returned/expected" % final_formal)
    if nat_rows:
        day = nat_rows[0]["snapshot_time"][:10]
        for hh in (17, 18, 19, 20, 21, 22, 23, 24, 25, 26):
            d0 = dt.datetime.strptime(day, "%Y-%m-%d") + dt.timedelta(hours=hh)
            cut = d0.strftime("%Y-%m-%d %H:%M:%S")
            cand = [n for n in nat_rows if n["snapshot_time"] <= cut]
            if cand:
                n = cand[-1]
                P("%s | %s | %d | %d | %.1f%% | %d/%d" % (d0.strftime("%d %H:%M"), n["snapshot_time"][11:19], n["formal"], n["informal"],
                                                        100.0 * n["formal"] / final_formal, n["returned"], n["expected"]))
        P("last snapshot: formal %d = %.1f%% of final formal" % (nat_rows[-1]["formal"], 100.0 * nat_rows[-1]["formal"] / final_formal))
    txt = "\n".join(out)
    print(txt)
    with open(os.path.join(outdir, "summary-fed%d%s.txt" % (year, tag)), "w", encoding="utf-8") as f:
        f.write(txt + "\n")



def main():
    argv = sys.argv[1:]
    ev = argv[0]
    limit = int(argv[argv.index("--limit") + 1]) if "--limit" in argv else None
    year = EVENTS[ev]
    indir = os.path.join(ROOT, "external", "reference", "aec", "mediafeed", ev)
    outdir = os.path.join(ROOT, "output", "night-feed")
    if "--out" in argv:
        outdir = os.path.join(outdir, argv[argv.index("--out") + 1])
    os.makedirs(outdir, exist_ok=True)
    tag = "" if limit is None else "-TEST"
    if "--report" in argv:
        report_from_disk(year, ev, outdir, tag)
        return
    zips = sorted(f for f in os.listdir(indir) if f.endswith(".zip"))
    if limit:
        zips = zips[::max(1, len(zips) // limit)]  # test mode: an evenly spaced sample across the night
    print("event", ev, "year", year, "zips", len(zips), flush=True)

    unknown = collections.Counter()
    failures = []
    raw = gzip.open(os.path.join(outdir, "raw-pp-fed%d%s.csv.gz" % (year, tag)), "wt", newline="", encoding="utf-8")
    rw = csv.writer(raw)
    rw.writerow(["snapshot_time", "division_id", "division", "polling_place_id", "polling_place", "pp_attrs",
                 "section", "kind", "candidate_id", "candidate", "party", "vote_type", "votes", "historic",
                 "percentage", "swing", "matched_historic", "other_attrs"])
    divfp_f = open(os.path.join(outdir, "division-fp-fed%d%s.csv" % (year, tag)), "w", newline="", encoding="utf-8")
    divfp_w = None
    div_f = open(os.path.join(outdir, "division-progress-fed%d%s.csv" % (year, tag)), "w", newline="", encoding="utf-8")
    div_w = None
    nat_rows = []
    state = {}     # (div_id, ppid) -> last state key
    rec = {}       # (div_id, ppid) -> record dict
    drec = {}      # (div_id, type) -> record dict (declaration vote types)
    prev_time = None
    prev_pair = {}
    time_diffs = []
    div_meta = {}

    for zi, zn in enumerate(zips):
        path = os.path.join(indir, zn)
        try:
            snap = parse_zip(path, unknown)
        except Exception as e:  # noqa
            failures.append((zn, repr(e)))
            print("FAIL", zn, repr(e), flush=True)
            continue
        T = tstr(snap["created"])
        m = re.search(r"-(\d{14})\.zip$", zn)
        fn_t = dt.datetime.strptime(m.group(1), "%Y%m%d%H%M%S")
        cr_t = dt.datetime.strptime(snap["created"], "%Y-%m-%dT%H:%M:%S")
        time_diffs.append((cr_t - fn_t).total_seconds())
        nat = collections.Counter()
        new_in_div_fp = collections.Counter()
        new_in_div_tcp = collections.Counter()
        first_events = []
        for d in snap["divs"]:
            div_id, dname = d["division_id"], d["division"]
            div_meta[div_id] = (dname, d["state"])
            cands = d.pop("_cands")
            pps = d.pop("_pps")
            fpc = d.pop("_fp_cand_votes", [])
            n_nonzero = 0
            pp_fp_sum = 0
            for ppid, (info, items) in pps.items():
                key = (div_id, ppid)
                vkey = tuple((it[0], it[1], it[2], it[3], it[4], it[6], it[7]) for it in items if not it[1].startswith("@"))
                fp_sum = sum((it[4] or 0) for it in items if it[0] == "FirstPreferences" and it[1] == "Candidate" and it[3] == "")
                formal = [it[4] for it in items if it[0] == "FirstPreferences" and it[1] == "Formal" and it[3] == ""]
                informal = [it[4] for it in items if it[0] == "FirstPreferences" and it[1] == "Informal" and it[3] == ""]
                tcp_sum = sum((it[4] or 0) for it in items if it[0] == "TwoCandidatePreferred" and it[1] == "Candidate" and it[3] == "")
                r = rec.get(key)
                if r is None:
                    r = rec[key] = {"division_id": div_id, "division": dname, "state": d["state"],
                                    "polling_place_id": ppid, "polling_place": info.get("Name"),
                                    "classification": info.get("Classification", ""),
                                    "pp_attrs": json.dumps({k: v for k, v in info.items() if k not in ("Id", "Name", "Classification")}, sort_keys=True),
                                    "listed_first": T, "fp_first_seen": "", "fp_prev_snapshot": "", "tcp_first_seen": "",
                                    "tcp_prev_snapshot": "", "changes": [], "fp_exact": "", "tcp_exact": "",
                                    "fp_exact_flag": "", "tcp_exact_flag": ""}
                last_state = state.get(key)
                changed = last_state != vkey
                if changed:
                    state[key] = vkey
                    for it in items:
                        sec, k, cid, vt, v, h, pc, sw, mh, oa = it
                        nm, pty = cands.get(cid, (None, None)) if cid else (None, None)
                        rw.writerow([T, div_id, dname, ppid, info.get("Name"),
                                     json.dumps({a: b for a, b in info.items() if a not in ("Id", "Name")}, sort_keys=True),
                                     sec, k, cid, nm, pty, vt, v, h, pc, sw, mh, oa])
                if fp_sum > 0:
                    n_nonzero += 1
                pp_fp_sum += fp_sum
                if changed:
                    if fp_sum > 0 and not r["fp_first_seen"]:
                        r["fp_first_seen"] = T
                        r["fp_prev_snapshot"] = prev_time or ""
                        r["fp_votes_first"] = fp_sum
                        r["formal_first"] = formal[0] if formal else ""
                        r["informal_first"] = informal[0] if informal else ""
                        r["fp_vector_first"] = ";".join("%s:%s" % (it[2], it[4]) for it in items if it[0] == "FirstPreferences" and it[1] == "Candidate" and it[3] == "")
                        new_in_div_fp[div_id] += 1
                        first_events.append(("fp", key))
                    elif r["fp_first_seen"]:
                        r["changes"].append(T)
                    if tcp_sum > 0 and not r["tcp_first_seen"]:
                        r["tcp_first_seen"] = T
                        r["tcp_prev_snapshot"] = prev_time or ""
                        r["tcp_votes_first"] = tcp_sum
                        r["tcp_vector_first"] = ";".join("%s:%s" % (it[2], it[4]) for it in items if it[0] == "TwoCandidatePreferred" and it[1] == "Candidate" and it[3] == "")
                        new_in_div_tcp[div_id] += 1
                        first_events.append(("tcp", key))
                r["fp_votes_last"] = fp_sum
                r["formal_last"] = formal[0] if formal else ""
                r["informal_last"] = informal[0] if informal else ""
                r["tcp_votes_last"] = tcp_sum
                r["last_change"] = T if changed else r.get("last_change", T)
            # declaration vote types (division-level VotesByType candidate sums)
            for t in DECL:
                tot = sum(cv[2].get(t, 0) or 0 for cv in fpc)
                k = (div_id, t)
                dr = drec.get(k)
                if dr is None:
                    dr = drec[k] = {"division_id": div_id, "division": dname, "state": d["state"],
                                    "polling_place_id": "", "polling_place": "[%s]" % t, "classification": "declaration:" + t,
                                    "pp_attrs": "", "listed_first": T, "fp_first_seen": "", "fp_prev_snapshot": "",
                                    "tcp_first_seen": "", "tcp_prev_snapshot": "", "changes": [], "fp_exact": "", "tcp_exact": "",
                                    "fp_exact_flag": "", "tcp_exact_flag": "", "_last": 0}
                if tot > 0 and not dr["fp_first_seen"]:
                    dr["fp_first_seen"] = T
                    dr["fp_prev_snapshot"] = prev_time or ""
                    dr["fp_votes_first"] = tot
                    dr["fp_exact"] = d.get("fp_updated", "").replace("T", " ") if d.get("fp_updated") else ""
                    dr["fp_exact_flag"] = ""
                elif dr["fp_first_seen"] and tot != dr["_last"]:
                    dr["changes"].append(T)
                dr["_last"] = tot
                dr["fp_votes_last"] = tot
            ordinary_cands = sum(cv[2].get("Ordinary", 0) or 0 for cv in fpc)
            d["ordinary_cand_votes_sum"] = ordinary_cands
            d["pp_fp_votes_sum"] = pp_fp_sum
            d["pps_in_feed"] = len(pps)
            d["pps_nonzero"] = n_nonzero
            for t in DECL:
                d["cand_%s_votes" % t.lower()] = sum(cv[2].get(t, 0) or 0 for cv in fpc)
            d["cand_votes_sum"] = sum(cv[1] or 0 for cv in fpc)
            total_all = d.get("fp_total") or 0
            d["share_enrolment_counted"] = round(total_all / d["enrolment"], 6) if d.get("enrolment") else None
            d["snapshot_time"] = T
            pair = d.get("tcp_pair_ids")
            # 1 when the counted pair differs from the last NON-blank pair shown (blank = no two-candidate count published)
            d["tcp_pair_changed"] = int(bool(pair) and prev_pair.get(div_id) not in (None, pair))
            if pair:
                prev_pair[div_id] = pair
            if div_w is None:
                div_cols = DIV_COLS
                div_w = csv.DictWriter(div_f, fieldnames=div_cols, extrasaction="raise", restval="")
                div_w.writeheader()
            div_w.writerow({k: v for k, v in d.items() if not k.startswith("contest_attr_")} | {"contest_attrs": json.dumps({k: v for k, v in d.items() if k.startswith("contest_attr_")}, sort_keys=True)})
            nat["formal"] += d.get("fp_formal") or 0
            nat["informal"] += d.get("fp_informal") or 0
            nat["total"] += d.get("fp_total") or 0
            nat["ord_cand"] += ordinary_cands
            nat["pp_fp"] += pp_fp_sum
            nat["returned"] += d.get("fp_returned") or 0
            nat["expected"] += d.get("fp_expected") or 0
            nat["tcp_returned"] += d.get("tcp_returned") or 0
            nat["divs_with_votes"] += int((d.get("fp_total") or 0) > 0)
            for t in DECL:
                nat[t.lower()] += d["cand_%s_votes" % t.lower()]
        for row in snap["div_fp"]:
            row["snapshot_time"] = T
            if divfp_w is None:
                divfp_w = csv.DictWriter(divfp_f, fieldnames=["snapshot_time"] + [k for k in row if k != "snapshot_time"], extrasaction="ignore")
                divfp_w.writeheader()
            divfp_w.writerow(row)
        # exact return time: a division's FP/TCP Updated is the time of its latest booth; if exactly one booth is new
        # in that division this snapshot, that Updated is that booth's return time
        divupd = {d["division_id"]: d for d in snap["divs"]}
        for kind, key in first_events:
            d = divupd[key[0]]
            r = rec[key]
            if kind == "fp":
                r["fp_exact"] = tstr(d.get("fp_updated")) or ""
                r["fp_exact_flag"] = int(new_in_div_fp[key[0]] == 1)
            else:
                r["tcp_exact"] = tstr(d.get("tcp_updated")) or ""
                r["tcp_exact_flag"] = int(new_in_div_tcp[key[0]] == 1)
        nat["snapshot_time"] = T
        nat["results_updated"] = tstr(snap["results_updated"])
        nat["divisions"] = len(snap["divs"])
        nat_rows.append(dict(nat))
        prev_time = T
        if zi % 20 == 0:
            print(zi, zn, T, "divs", len(snap["divs"]), "total", nat["total"], flush=True)
    raw.close(); div_f.close(); divfp_f.close()

    # ---------------- booth-returns
    allrec = list(rec.values()) + list(drec.values())
    cols = ["division", "division_id", "state", "polling_place", "polling_place_id", "classification", "pp_attrs",
            "listed_first", "fp_prev_snapshot", "fp_first_seen", "fp_exact", "fp_exact_flag", "fp_votes_first",
            "formal_first", "informal_first", "fp_vector_first", "tcp_prev_snapshot", "tcp_first_seen", "tcp_exact",
            "tcp_exact_flag", "tcp_votes_first", "tcp_vector_first", "n_changes_after_first", "change_times",
            "fp_votes_last", "formal_last", "informal_last", "tcp_votes_last", "matched_booth_name", "joined_booths_csv"]

    # join to the final results booth file
    booths_path = os.path.join(ROOT, "output", "booths-fed%d.csv" % year)
    final_booth = collections.defaultdict(lambda: collections.defaultdict(int))  # district -> booth -> ordinary votes
    final_type = collections.defaultdict(lambda: collections.defaultdict(int))
    final_div_total = collections.defaultdict(int)
    with open(booths_path, encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            v = toint(r["votes"]) or 0
            final_div_total[r["district"]] += v
            final_type[r["district"]][r["booth_type"]] += v
            if r["booth_type"] == "ordinary":
                final_booth[r["district"]][r["booth"]] += v
    for r in allrec:
        r["n_changes_after_first"] = len(r["changes"])
        r["change_times"] = ";".join(r["changes"])
        nm = r["polling_place"]
        fb = final_booth.get(r["division"], {})
        if r["classification"].startswith("declaration"):
            r["matched_booth_name"] = ""
            r["joined_booths_csv"] = ""
        elif nm in fb:
            r["matched_booth_name"] = nm
            r["joined_booths_csv"] = 1
        else:
            r["matched_booth_name"] = ""
            r["joined_booths_csv"] = 0
    allrec.sort(key=lambda r: (r["division"], r["classification"].startswith("declaration"), r["polling_place"]))
    with open(os.path.join(outdir, "booth-returns-fed%d%s.csv" % (year, tag)), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore", restval="")
        w.writeheader()
        for r in allrec:
            w.writerow(r)

    # ---------------- national progress
    final_formal = sum(final_div_total.values())
    if nat_rows:
        ncols = ["snapshot_time", "results_updated", "divisions", "divisions_with_votes", "returned", "expected",
                 "tcp_returned", "formal", "informal", "total", "ordinary_candidate_votes", "pp_fp_votes",
                 "absent", "provisional", "prepoll", "postal", "pct_of_final_formal", "final_formal_ref"]
        with open(os.path.join(outdir, "national-progress-fed%d%s.csv" % (year, tag)), "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(ncols)
            for n in nat_rows:
                w.writerow([n["snapshot_time"], n["results_updated"], n["divisions"], n["divs_with_votes"], n["returned"],
                            n["expected"], n["tcp_returned"], n["formal"], n["informal"], n["total"], n["ord_cand"],
                            n["pp_fp"], n["absent"], n["provisional"], n["prepoll"], n["postal"],
                            round(100.0 * n["formal"] / final_formal, 3), final_formal])

    report(year, ev, len(zips), nat_rows, failures, time_diffs, unknown, rec, div_meta, outdir, tag,
           final_booth, final_div_total, final_formal, div_w is not None)

if __name__ == "__main__":
    main()
