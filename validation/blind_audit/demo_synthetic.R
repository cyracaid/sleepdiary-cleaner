# demo_synthetic.R -- test the blind-audit tooling on the synthetic benchmark, where
# the truth is known. Two simulated annotators label each sampled row from the
# ground truth, each with 5% random label flips and 2% "unsure"; then score_audit.R
# is run on the completed sheets. If the tooling is right, the estimated precision of
# the flags and the miss rate should be close to the values computed directly from
# the ground truth (printed at the end).
#
# Usage (from the repository root, after validation/run_all.R or ppv_cluster_ci.R has
# produced validation/synthetic/run_ppv/ and ground_truth_enrichment.csv):
#   Rscript validation/blind_audit/demo_synthetic.R
syn <- "validation/synthetic"
out <- file.path(tempdir(), "blind_audit_demo")
corr_rds <- file.path(syn, "run_ppv", "corrected_ema_data.rds")
stopifnot(file.exists(corr_rds), file.exists(file.path(syn, "ground_truth_enrichment.csv")))
system2("Rscript", c("validation/blind_audit/draw_sample.R", corr_rds, out,
                     file.path(syn, "run_ppv", "review_output.rds"), "--seed=1"))

key <- read.csv(file.path(out, "KEY_do_not_share_with_annotators.csv"), stringsAsFactors = FALSE)
gt  <- read.csv(file.path(syn, "ground_truth_enrichment.csv"), stringsAsFactors = FALSE)
# annotators mark an error when the typed value is wrong; a format-only error
# (missing or misplaced colon) still reads as the intended time, so it is not one
value_cats <- setdiff(unique(gt$error_type), c("no_error_control", "format_no_colon", "format_malformed_colon"))
truth <- key$row_id %in% gt$row_id[gt$error_type %in% value_cats]

set.seed(2)
label <- function(truth) {
  y <- ifelse(truth, "Y", "N")
  flip <- runif(length(y)) < 0.05
  y[flip] <- ifelse(y[flip] == "Y", "N", "Y")
  y[runif(length(y)) < 0.02] <- "U"
  y
}
for (who in c("A", "B")) {
  f <- file.path(out, sprintf("annotation_sheet_%s.csv", who))
  s <- read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  s$error_present <- label(truth)
  s$seconds_taken <- round(rlnorm(nrow(s), log(25), 0.4))
  write.csv(s, f, row.names = FALSE, na = "")
}
cat("\n--- score_audit.R on the simulated annotations ---\n")
system2("Rscript", c("validation/blind_audit/score_audit.R", out))

cat("\n--- directly from the ground truth (what the audit should approximate) ---\n")
for (st in c("flagged", "changed", "left_alone"))
  cat(sprintf("%-10s share with a wrong value: %.1f%%\n", st, 100 * mean(truth[key$stratum == st])))
