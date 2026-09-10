# Push the promoted arm's models and results to the GitHub release.
#
# WHY SEPARATE FROM promote_arm.R. Promotion is local and reversible; this
# publishes to a PUBLIC repository, where anything uploaded may be cached or
# indexed even if later deleted. Keeping it a second, deliberate command means
# nobody publishes by accident while regenerating a table.
#
# THE TAG IS REUSED ON PURPOSE. `shipped-models` always means "the models the
# forecast currently runs on", so links do not rot. The consequence, and it has
# bitten this ecosystem before: GitHub reports a release's createdAt from the
# TAG, so the release page will look stale while its assets are fresh. Check
# asset-level updatedAt, or read MANIFEST.json, which carries the promoting git
# SHA and timestamp. Never date the models from the release page.
#
# Requires: scripts/promote_arm.R to have run (output/shipped/MANIFEST.json).
#
# Emits PR* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

OUT <- "output"
SHIP <- file.path(OUT, "shipped")
TAG <- Sys.getenv("AUSPOL_RELEASE_TAG", "shipped-models")
MANF <- file.path(SHIP, "MANIFEST.json")
if (!file.exists(MANF))
  stop("no ", MANF, " -- run scripts/promote_arm.R first; publishing an unpromoted tree would put unverified bytes behind the shipped name")

man <- jsonlite::fromJSON(MANF)
cat(sprintf("PR1  manifest: arm %s, git %s, promoted %s\n",
            man$arm, substr(man$git_sha, 1, 8), man$promoted_at))

# REFUSE IF THE TREE HAS MOVED SINCE PROMOTION. Publishing models under a git
# SHA that no longer describes the code that produced them is exactly the
# published-vs-deployed drift documented in C:\dev\CLAUDE.md.
head_sha <- tryCatch(trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
                     error = function(e) NA_character_)
if (!identical(head_sha, man$git_sha)) {
  cat(sprintf("PR1! HEAD is %s but the manifest was written at %s.\n",
              substr(head_sha, 1, 8), substr(man$git_sha, 1, 8)))
  cat("PR1! Re-run scripts/promote_arm.R so the published artifacts and the recorded SHA agree.\n")
  if (!identical(Sys.getenv("AUSPOL_RELEASE_FORCE", "0"), "1"))
    stop("refusing to publish against a stale manifest; set AUSPOL_RELEASE_FORCE=1 only if you know why they differ")
}

# The payload. Model files are named from the manifest rather than globbed, so
# what is published is exactly what was checksummed.
models <- file.path(OUT, man$models$file)
extra <- c(file.path(SHIP, c("MANIFEST.json", "pooled-backtest.csv", "pooled-sharedetail.csv")),
           file.path(OUT, "seat-probs-vic-2026.csv"))
loo <- grep("xgb-flows-v1-loo-.*[.]model$", models, value = TRUE)
rest <- setdiff(models, loo)

# 25 one-per-election models go up as a single archive; 25 separate assets
# would make the release unreadable and the download 25 round trips.
zipf <- file.path(tempdir(), "xgb-flows-v1-loo-models.zip")
if (length(loo)) {
  if (file.exists(zipf)) unlink(zipf)
  utils::zip(zipf, loo, flags = "-qj")
  if (!file.exists(zipf)) stop("could not build ", zipf)
}
payload <- c(extra, rest, if (length(loo)) zipf)
payload <- payload[file.exists(payload)]
cat(sprintf("PR2  %d asset(s), %.1f MB total\n", length(payload),
            sum(file.size(payload)) / 1048576))

exists_rel <- system2("gh", c("release", "view", TAG), stdout = FALSE, stderr = FALSE) == 0
if (!exists_rel) {
  cat(sprintf("PR3  release %s does not exist -- create it once with `gh release create %s`, then re-run\n", TAG, TAG))
  quit(status = 1)
}
rc <- system2("gh", c("release", "upload", TAG, shQuote(payload), "--clobber"))
if (rc != 0) stop("gh release upload failed with status ", rc)
cat(sprintf("PR4  uploaded to https://github.com/peteowen1/auspol/releases/tag/%s\n", TAG))
cat("PR4  the release DATE is the tag's, not the data's -- read MANIFEST.json or asset updatedAt\n")
