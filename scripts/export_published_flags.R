# Print `export NAME='value'` for every published switch the caller left unset,
# for scripts/rebuild_forecasts.sh to eval once at the start.
#
# WHY. The harnesses apply scripts/published_flags.R themselves
# (scripts/harness_defaults.R), but the xgb fit scripts (stages 3-5) only read
# the environment, so a switch whose code default differs from its published
# value silently ran at the default there. Found 2026-10-02: v57 shipped with
# AUSPOL_STATE_NOTIONAL=1 in base_pred but x_notional_adj = 0 for every state
# pair in the xgb layer, because R/state_notional.R defaults to "0" and the
# final rebuild set nothing in the environment.
source("scripts/published_flags.R")
for (n in names(PUBLISHED_FLAGS)) {
  if (!nzchar(Sys.getenv(n, unset = ""))) cat(sprintf("export %s='%s'\n", n, gsub("'", "", PUBLISHED_FLAGS[[n]])))
}
