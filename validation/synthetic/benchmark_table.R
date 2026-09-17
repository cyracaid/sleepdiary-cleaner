# benchmark_table.R — paper-ready benchmark table (detection vs correction)
# =============================================================================
# Derives a single benchmark table from the committed result CSVs, with two
# fixes over the raw detection_outcomes_v4_current.csv:
#
#   (1) CONTROL ROW MISCOMPUTATION. The raw file counts the 1,609 clean-control
#       rows as MISSED (they have no injected error, so CORRECT is structurally
#       0) and reports correct_pct = 0 for them. That reads as "0% correct" when
#       it is simply "not an injected-error category". Here the control is
#       removed from the recall denominator and reported on its own FAR line.
#
#   (2) DETECTION != CORRECTION. The raw file's single correct_pct conflates
#       "the pipeline acted on it" with "it got the right answer". This table
#       keeps them separate, per the reviewer's request:
#         detected           = CORRECT + FLAGGED_UNRESOLVED + MISREPAIRED
#         correctly_detected = CORRECT
#         false_correction   = MISREPAIRED (changed, but to the wrong value)
#         missed             = MISSED (untouched, still wrong, unflagged)
#       recall  = detected / n_injected          (detection layer)
#       misrepair_rate = MISREPAIRED / n_injected (correction layer)
#       precision (pooled) = flagged injected / (flagged injected + flagged control)
#       FAR_flag / FAR_alter = from far_flag_alter.csv (control layer)
#
# Sources (all committed):
#   results/detection_outcomes_v4_current.csv  per-category outcome counts
#   results/mrr_magnitude.csv                  per-category misrepair counts
#   results/far_flag_alter.csv                 control FAR_flag / FAR_alter
#
# Output: results/benchmark_table.csv  (per-category + a CONTROL summary row)
#
# Usage: Rscript validation/synthetic/benchmark_table.R
# =============================================================================

RES <- "validation/synthetic/results"
rd  <- function(f) read.csv(file.path(RES, f), stringsAsFactors = FALSE)

det <- rd("detection_outcomes_v4_current.csv")
mrr <- rd("mrr_magnitude.csv")
far <- rd("far_flag_alter.csv")

# --- split control out of the injected-error categories ---------------------
ctrl_row <- det[det$category == "no_error_control", , drop = FALSE]
inj      <- det[det$category != "no_error_control", , drop = FALSE]

n_control <- if (nrow(ctrl_row) == 1) ctrl_row$n else NA_integer_
far_flag  <- far$n_hit[far$metric == "FAR_flag"]
far_alter <- far$n_hit[far$metric == "FAR_alter"]
far_ctrl  <- far$n_control[far$metric == "FAR_flag"]

# pooled precision: TP = flagged injected rows, FP = flagged control rows
flagged_inj  <- sum(inj$FLAGGED_UNRESOLVED) + sum(inj$MISREPAIRED)  # acted-but-not-corrected
# corrected-injected that were correct are also "flagged" in the acted sense;
# use mrr_magnitude's per-category flagged column when present for the count of
# rows the pipeline surfaced for review, else fall back to FLAGGED_UNRESOLVED.
if (all(c("error_type", "flagged") %in% names(mrr))) {
  flagged_inj <- sum(mrr$flagged[mrr$error_type != "no_error_control"])
} else {
  flagged_inj <- sum(inj$FLAGGED_UNRESOLVED)
}
pooled_precision <- if ((flagged_inj + far_flag) > 0) flagged_inj / (flagged_inj + far_flag) else NA_real_

# --- per-category table ------------------------------------------------------
out <- data.frame(
  category           = inj$category,
  n_injected         = inj$n,
  detected           = inj$CORRECT + inj$FLAGGED_UNRESOLVED + inj$MISREPAIRED,
  correctly_detected = inj$CORRECT,
  flagged_unresolved = inj$FLAGGED_UNRESOLVED,
  false_correction   = inj$MISREPAIRED,
  missed             = inj$MISSED,
  recall             = round((inj$CORRECT + inj$FLAGGED_UNRESOLVED + inj$MISREPAIRED) / inj$n, 4),
  misrepair_rate     = round(inj$MISREPAIRED / inj$n, 4),
  stringsAsFactors   = FALSE
)
out <- out[order(out$category), ]
rownames(out) <- NULL

# --- control summary row -----------------------------------------------------
ctrl <- data.frame(
  category           = "CONTROL (no_error_control)",
  n_injected         = NA_integer_,          # not injected-error; excluded from recall
  detected           = NA_integer_,
  correctly_detected = NA_integer_,
  flagged_unresolved = NA_integer_,
  false_correction   = NA_integer_,
  missed             = NA_integer_,          # the raw file's 1609 "MISSED" were a miscompute
  recall             = NA_real_,
  misrepair_rate     = NA_real_,
  stringsAsFactors   = FALSE
)

full <- rbind(out, ctrl)
# attach pooled + control metrics as extra columns (NA off the relevant rows)
full$pooled_precision <- NA_real_
full$far_flag <- NA_real_
full$far_alter <- NA_real_
full$n_control <- NA_integer_
ctrl_i <- nrow(full)
full$pooled_precision[ctrl_i] <- pooled_precision
full$far_flag[ctrl_i]  <- far_flag
full$far_alter[ctrl_i] <- far_alter
full$n_control[ctrl_i] <- far_ctrl

write.csv(full, file.path(RES, "benchmark_table.csv"), row.names = FALSE)

cat("=== Benchmark table (detection vs correction, control separated) ===\n")
print(full, row.names = FALSE)
cat(sprintf("\nPooled precision = %.4f  (flagged injected %d / (flagged injected %d + flagged control %d))\n",
            pooled_precision, flagged_inj, flagged_inj, far_flag))
cat(sprintf("Control: n=%d, FAR_flag=%d, FAR_alter=%d  (raw file reported these as MISSED -- miscompute, now fixed)\n",
            far_ctrl, far_flag, far_alter))
cat("\nWrote results/benchmark_table.csv\n")
cat("\n=== [benchmark_table] Finished ===\n")