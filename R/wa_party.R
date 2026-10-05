# Western Australian party codes -> party names, ONE copy.
#
# WESTERN AUSTRALIA PUBLISHES A CODE AND NO PARTY NAME. classify_party() works
# mostly on names, so a bare code reaches few of its rules and lands in OTH --
# silently, because OTH is a legitimate class rather than an error. In 2025
# that swallowed the Nationals' six won seats, 27 independents, the Shooters in
# 26 districts and Australian Christians in 54.
#
# So each code is expanded to a party NAME before classifying. The values are
# the strings the WAEC itself publishes in LASeatsByParty (scripts/
# fetch_preferences_wa.R's WF1c refuses any that is not).
#
# This map used to live inside scripts/fetch_preferences_wa.R only, and
# scripts/build_candidacies.R classified the bare abbreviation instead, so the
# candidate corpus and the per-seat results disagreed on class (wa2001 had no
# One Nation candidates at all: PHO went to OTH). Both now call these.
WA_PARTY <- c(
  # 1996-2008 the commission wrote "Australian Labor Party" and "NATIONAL
  # PARTY"; from 2013 "WA Labor" and "THE NATIONALS". The spelling moves, so
  # WF1c checks names against the union across elections, not one election.
  ALP    = "Australian Labor Party", LIB  = "Liberal Party",
  NP     = "NATIONAL PARTY",         NAT  = "THE NATIONALS",
  NATS   = "The Nationals WA",       GRN  = "The Greens (WA)",
  IND    = "Independent",
  # One Nation appears under THREE codes across the eight elections, which is
  # the single most important thing this map gets right: PHO in 2001 is 54
  # candidates and ONP in 2005 is 45, and either one lost to OTH would remove
  # most of the One Nation preference evidence Western Australia exists to add.
  PHO    = "Pauline Hanson's ONE NATION",
  ONP    = "ONE NATION",
  PHON   = "Pauline Hanson's One Nation",
  # Christian and other minor-right.
  AC     = "Australian Christians",  ACP  = "Australian Christians",
  CDP    = "Christian Democratic Party WA",
  CTA    = "Call To Australia (WA)", FFP  = "Family First",
  CEC    = "CITIZENS ELECTORAL COUNCIL",
  NCO    = "New Country Party",      AFP  = "Australia First Party",
  SFF    = "SFFPWA",                 SFFP = "Shooters, Fishers and Farmers",
  LDP    = "Liberal Democrats",      Libertarian = "Libertarian",
  # Everything below lands in OTH, and does so deliberately rather than by
  # falling through: see WF6, which prints the OTH members every run.
  AD     = "Australian Democrats",   DEM  = "Australian Democrats",
  AJP    = "Animal Justice Party",   AMP  = "Australian Marijuana Party",
  APP    = "The Australian People's Party",
  ARP    = "Australian Reform Party WA",
  CLM    = "CALM Resistance Movement",
  FLUX   = "Flux The System!",       LCWA = "Legalise Cannabis Party WA",
  LFC    = "Liberals For Climate",   MBP  = "Micro Business Party",
  SA     = "Socialist Alliance",
  SAPSOC = "SUSTAINABLE AUSTRALIA PARTY - STOP OVERDEVELOPMENT / CORRUPTION",
  SPPk   = "Stop Pedophiles! Protect kiddies!",
  WAP    = "WESTERN AUSTRALIA PARTY",
  # NO MANDATORY VACCINATION ran 59 candidates in 2021 and WAxit 48. Both are
  # right-populist in flavour and both sit in OTH because no rule names them.
  # Moving them is a modelling decision with real consequences for the OTH row
  # of the flow matrix, so it is left for a measured one rather than taken here.
  NMV    = "NO MANDATORY VACCINATION", WAXIT = "WAxit")

# Classify WA party codes through WA_PARTY. A code with no entry is returned in
# `unmapped` and falls back to classify_party(code, code), the abbreviation
# rule; it is never silently OTH -- the caller must print or stop on `unmapped`
# (a code the abbreviation rule does not recognise either reads as success).
# Blank/NA codes are independents. A code that is already a full name (the WAEC
# JSON gives "Independent" where it has none) is classified as that name.
# Returns list(party =, unmapped =).
wa_classify_codes <- function(codes) {
  cd <- ifelse(is.na(codes) | !nzchar(trimws(codes)), "IND", trimws(codes))
  nm <- unname(WA_PARTY[cd])
  has <- !is.na(nm)
  party <- rep(NA_character_, length(cd))
  party[has] <- classify_party(nm[has], cd[has])
  if (any(!has)) party[!has] <- classify_party(cd[!has], cd[!has])
  list(party = party,
       unmapped = sort(unique(cd[!has & party == "OTH"])))
}
