#!/usr/bin/env Rscript
# =============================================================================
# compute_disambiguation_agreement.R
#
# PURPOSE
#   Read the two independently-completed worksheets produced by
#   disambiguate_timegap_candidates.R (disambiguation_worksheet_cyra.csv,
#   disambiguation_worksheet_maia.csv) and compute real inter-rater
#   agreement between them.
#
#   This is the step that only works because the two worksheets were kept
#   separate and filled in independently -- see disambiguate_timegap_
#   candidates.R's header for why that mattered (development-evidence-
#   audit.md documents the prior failure mode this design avoids:
#   manual_error_corrections.csv's "agreement_cd_mtb" column recorded a
#   single shared/collaborative pass, not two independent codings, so
#   Cohen's kappa was never actually computable from it). Do not run this
#   script until BOTH worksheets have been filled in without either
#   reviewer seeing the other's answers.
#
# WHAT IT COMPUTES
#   - Raw agreement % (judgment_cyra == judgment_maia, case-insensitive,
#     over the rows where both gave a real judgment -- "unsure" counts as
#     a real judgment, it is not treated as missing).
#   - Cohen's kappa (unweighted) over the same rows, computed by hand from
#     the 3x3 confusion matrix (error / behavior / unsure) so there's no
#     dependency on an external package (irr / psych are not part of this
#     repo's dependency set).
#   - A confusion matrix (rows = cyra, cols = maia).
#   - The list of disagreement rows (pid, day_num, field_pair, both
#     judgments, both notes, and recurrence_signal / personal_deviation_mad
#     for context) -- these are exactly the rows worth a real discussion
#     between the two reviewers, not majority-vote or auto-resolved.
#   - Rows either file left blank (judgment == "") are reported as
#     "incomplete" and excluded from the agreement stats, not silently
#     dropped.
#
# NOTE: as of 2026-09-02 the worksheet's decision-support context is
# recurrence_signal + personal_deviation_mad (see disambiguate_timegap_
# candidates.R's v1->v2 header note for why the earlier posterior_p_error
# score was dropped -- an independent review found it added no
# discriminating power over n_recurring_similar alone), plus
# participant_prior_signal / participant_prior_n_error /
# participant_prior_n_behavior (added v4->v5 -- this participant's OTHER
# already-audited verdicts; 89.3% accurate when unanimous on the full
# corpus, but with real counter-examples, so context only, same status as
# recurrence_signal), plus sol_crosscheck_fit / sol_crosscheck_diff_min
# (added v5->v6 -- does the participant's self-reported sleep-onset-latency
# corroborate a +/-12h bed/sleep reinterpretation? validated 85% on known
# cases; "poor" flags extra scrutiny, not a behavior verdict). This script
# reads whichever context columns are present in the cyra worksheet, so it
# keeps working against older worksheets that lack the v5/v6 columns.
#
# OUTPUT
#   Prints a summary to the console and writes
#   disambiguation_agreement_report.csv (one row per candidate, both
#   judgments/notes side by side, agreement flag, decision-support context)
#   plus disambiguation_disagreements.csv (the subset that needs discussion).
#
# USAGE
#   Rscript validation/compute_disambiguation_agreement.R \
#     [cyra_csv] [maia_csv] [out_dir]
#   Defaults: disambiguation_worksheet_cyra.csv,
#             disambiguation_worksheet_maia.csv, "."
#
# PRIVACY: same as the worksheets themselves -- outputs carry real
# pid/day_num/timestamps. Never commit them. Only this script is meant to
# be committed.
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
cyra_path <- if (length(args) >= 1) args[[1]] else "disambiguation_worksheet_cyra.csv"
maia_path <- if (length(args) >= 2) args[[2]] else "disambiguation_worksheet_maia.csv"
out_dir   <- if (length(args) >= 3) args[[3]] else "."

stopifnot(file.exists(cyra_path))
stopifnot(file.exists(maia_path))

cyra <- read.csv(cyra_path, stringsAsFactors = FALSE)
maia <- read.csv(maia_path, stringsAsFactors = FALSE)

key_cols <- c("pid", "day_num", "field_pair")
stopifnot(all(key_cols %in% names(cyra)), all(key_cols %in% names(maia)))

if (nrow(cyra) != nrow(maia)) {
  stop(sprintf("Row count mismatch: %s has %d rows, %s has %d rows -- these should be the same worksheet filled in twice, not edited structurally. Re-derive from the same disambiguate_timegap_candidates.R run before comparing.",
               cyra_path, nrow(cyra), maia_path, nrow(maia)))
}

# Merge on the natural key rather than assuming row order matches -- a
# reviewer may have sorted/reordered their copy while filling it in.
# Context columns: prefer the current recurrence_signal/personal_deviation_mad/
# participant_prior_signal set (v4->v5 added the last one), but fall back to
# posterior_p_error if given an older (v1) worksheet, and simply omit any
# column an older worksheet doesn't have. v8 (2026-09-03) added the raw
# full-night columns (time_bed_am_hhmm_ampm etc.) so a disagreement can be
# read the same way manual_error_corrections.csv/manual_unusual_corrections.csv
# are -- included here first since that's what a human reads first when
# looking at a disagreement row.
context_cols <- intersect(c("time_bed_am_hhmm_ampm", "time_getup_am_hhmm_ampm",
                             "bed_sleep_diff_h", "awake_getup_diff_h",
                             "waso_selfreport_min",
                             "recurrence_signal", "personal_deviation_mad",
                             "participant_prior_signal", "participant_prior_n_error",
                             "participant_prior_n_behavior", "sol_crosscheck_fit",
                             "sol_crosscheck_diff_min", "posterior_p_error_solonly",
                             "posterior_p_error_combined", "posterior_p_error"),
                           names(cyra))
if (length(context_cols) == 0) {
  cat("NOTE: no recognized decision-support context column found in the cyra worksheet -- proceeding without it.\n")
}
cyra_j <- cyra[, c(key_cols, "judgment", "notes", context_cols)]
names(cyra_j)[names(cyra_j) %in% c("judgment", "notes")] <- c("judgment_cyra", "notes_cyra")
maia_j <- maia[, c(key_cols, "judgment", "notes")]
names(maia_j)[names(maia_j) %in% c("judgment", "notes")] <- c("judgment_maia", "notes_maia")

merged <- merge(cyra_j, maia_j, by = key_cols, all = TRUE)
if (nrow(merged) != nrow(cyra)) {
  stop(sprintf("Merge produced %d rows from two %d-row inputs -- the (pid, day_num, field_pair) key isn't unique or the two files don't cover the same candidate set. Do not proceed until this is resolved.",
               nrow(merged), nrow(cyra)))
}

norm <- function(x) tolower(trimws(x))
merged$judgment_cyra_norm <- norm(merged$judgment_cyra)
merged$judgment_maia_norm <- norm(merged$judgment_maia)

valid_labels <- c("error", "behavior", "unsure")
is_blank <- function(x) is.na(x) | x == ""

merged$status <- ifelse(
  is_blank(merged$judgment_cyra_norm) | is_blank(merged$judgment_maia_norm),
  "incomplete",
  ifelse(
    !(merged$judgment_cyra_norm %in% valid_labels) | !(merged$judgment_maia_norm %in% valid_labels),
    "invalid_label",
    "complete"
  )
)

n_incomplete <- sum(merged$status == "incomplete")
n_invalid <- sum(merged$status == "invalid_label")
if (n_incomplete > 0) {
  cat(sprintf("NOTE: %d/%d rows have a blank judgment in at least one worksheet -- excluded from agreement stats, reported separately below.\n",
              n_incomplete, nrow(merged)))
}
if (n_invalid > 0) {
  cat(sprintf("WARNING: %d row(s) have a judgment value outside {error, behavior, unsure} -- check for typos. Excluded from agreement stats.\n",
              n_invalid))
  print(merged[merged$status == "invalid_label",
               c(key_cols, "judgment_cyra", "judgment_maia")])
}

scored <- merged[merged$status == "complete", ]
merged$agree <- ifelse(merged$status == "complete",
                        merged$judgment_cyra_norm == merged$judgment_maia_norm,
                        NA)

if (nrow(scored) == 0) {
  cat("\nNo rows have valid judgments in both worksheets yet -- nothing to score. Fill in both worksheets first.\n")
} else {
  agree_vec <- scored$judgment_cyra_norm == scored$judgment_maia_norm
  raw_agreement <- mean(agree_vec)

  # Unweighted Cohen's kappa from the confusion matrix, by hand.
  labels <- valid_labels
  conf <- table(factor(scored$judgment_cyra_norm, levels = labels),
                factor(scored$judgment_maia_norm, levels = labels))
  n <- sum(conf)
  po <- sum(diag(conf)) / n
  row_marg <- rowSums(conf) / n
  col_marg <- colSums(conf) / n
  pe <- sum(row_marg * col_marg)
  kappa <- if (pe == 1) NA_real_ else (po - pe) / (1 - pe)

  cat(sprintf("\nScored %d/%d rows (both judgments present and valid).\n", nrow(scored), nrow(merged)))
  cat(sprintf("Raw agreement: %d/%d = %.1f%%\n", sum(agree_vec), length(agree_vec), 100 * raw_agreement))
  cat(sprintf("Cohen's kappa (unweighted, 3-category): %.3f\n", kappa))
  cat("\nConfusion matrix (rows = cyra, cols = maia):\n")
  print(conf)

  disagreements <- merged[merged$status == "complete" & !merged$agree,
                           c(key_cols, "judgment_cyra", "judgment_maia",
                             "notes_cyra", "notes_maia", context_cols)]
  cat(sprintf("\n%d disagreement row(s) -- needs discussion, not majority vote:\n", nrow(disagreements)))
  if (nrow(disagreements) > 0) print(disagreements)
}

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
report_cols <- c(key_cols, "judgment_cyra", "judgment_maia", "agree",
                  "notes_cyra", "notes_maia", context_cols, "status")
write.csv(merged[, report_cols], file.path(out_dir, "disambiguation_agreement_report.csv"), row.names = FALSE)
if (nrow(scored) > 0) {
  disagreements <- merged[merged$status == "complete" & !merged$agree,
                           c(key_cols, "judgment_cyra", "judgment_maia",
                             "notes_cyra", "notes_maia", context_cols)]
  write.csv(disagreements, file.path(out_dir, "disambiguation_disagreements.csv"), row.names = FALSE)
}

cat(sprintf("\nWrote %s/disambiguation_agreement_report.csv (%d rows) and disambiguation_disagreements.csv.\n",
            out_dir, nrow(merged)))
