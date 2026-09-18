#!/usr/bin/env Rscript
# =============================================================================
# validation/promote_fasttrack_for_review.R
#
# PURPOSE
#   Turn disambiguate_timegap_candidates.R's fast-track output into the file
#   the human-review step (and rebuild_fasttrack_complete.R downstream)
#   actually reads: manual_disambiguation_fasttrack.csv.
#
#   Before this script existed, that handoff was a manual copy/rename done
#   by hand outside any script (see
#   work_logs/2026-09-09_EMAIL_TO_MAIA_validation_update.md, which attaches
#   "manual_disambiguation_fasttrack.csv" without recording which run of
#   disambiguate_timegap_candidates.R it came from). That gap is exactly
#   what made the raw_row_id / AM-PM debugging session hard to fully trace
#   back -- 2026-09-18.
#
#   This script makes the handoff a real, auditable pipeline step: it
#   copies disambiguation_worksheet_tiered_fasttrack.csv through UNCHANGED
#   (no columns added, no rows dropped or reordered) and writes a
#   provenance sidecar recording exactly which source file (and its md5)
#   it was promoted from and when.
#
# INPUT
#   - disambiguation_worksheet_tiered_fasttrack.csv (from
#     disambiguate_timegap_candidates.R)
#
# OUTPUT
#   - manual_disambiguation_fasttrack.csv
#   - manual_disambiguation_fasttrack.csv.provenance.json
#
# USAGE
#   Rscript validation/promote_fasttrack_for_review.R \
#     [in_path] [out_path]
#   Defaults: disambiguation_worksheet_tiered_fasttrack.csv,
#             manual_disambiguation_fasttrack.csv
# =============================================================================

args     <- commandArgs(trailingOnly = TRUE)
in_path  <- if (length(args) >= 1) args[[1]] else "disambiguation_worksheet_tiered_fasttrack.csv"
out_path <- if (length(args) >= 2) args[[2]] else "manual_disambiguation_fasttrack.csv"

source("validation/provenance_helpers.R")

stopifnot(file.exists(in_path))

if (file.exists(out_path)) {
  cat(sprintf(
    "NOTE: %s already exists and will be overwritten. If it has reviewer\n",
    out_path
  ))
  cat("judgments/notes filled in, back it up first -- this script does not merge, it replaces.\n")
}

df <- read.csv(in_path, stringsAsFactors = FALSE, check.names = FALSE)
cat(sprintf("Promoting %d rows from %s -> %s\n", nrow(df), in_path, out_path))

write_csv_with_provenance(
  df, out_path,
  script_path = "validation/promote_fasttrack_for_review.R",
  inputs = in_path,
  notes = paste0(
    "Pure promotion for human single-reviewer confirmation -- content ",
    "unchanged from disambiguate_timegap_candidates.R's fasttrack_rows ",
    "(sol_crosscheck_fit == 'good' subset of the needs-review worksheet)."
  )
)

cat("Done. Wrote:", out_path, "and", paste0(out_path, ".provenance.json"), "\n")
