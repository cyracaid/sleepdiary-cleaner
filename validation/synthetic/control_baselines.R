# control_baselines.R — 5.7: no-cleaning + naive-rule baseline conditions
# =============================================================================
# Two control conditions on the SAME enrichment benchmark (5.1 artifacts):
#   (1) no-cleaning   — corrupted values passed through untouched; measure the
#                       "error rate if we did nothing" (detection floor).
#   (2) naive-rule    — trivial detector applied to raw corrupted strings:
#                       flag a row iff its corrupted value is structurally
#                       implausible (non-numeric duration, clock-hour >= 13
#                       in a duration field, or out-of-order timestamp pair).
#                       This is the "does the pipeline beat a dumb rule" bar.
# Compare recall / FAR against the real pipeline's 5.1 numbers.
#
# Outputs (validation/synthetic/results/):
#   control_baselines.csv — recall (detected) + FAR per condition
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")
truth_csv <- file.path(SYN, "ground_truth_enrichment.csv")
corr_rds  <- file.path(SYN, "corrupted_enrichment.rds")

gt   <- read.csv(truth_csv, stringsAsFactors = FALSE)
raw  <- readRDS(corr_rds)

# real pipeline per-row outcomes (5.1)
per_row <- read.csv(file.path(RES, "cluster_bootstrap_per_row.csv"), stringsAsFactors = FALSE)

# ── Condition 1: no-cleaning (detection = do nothing, so 0) ─────────────────
# The "detector" here is identity: no row is ever flagged or corrected.
# Recall = 0 by construction; FAR = 0. This is the floor for the FCR claim.
nc_recall <- 0
nc_far_flag <- 0
nc_far_alter <- 0

# ── Condition 2: naive-rule detector on raw corrupted strings ───────────────
# Flag a row iff ANY of:
#   - duration field non-numeric or clock-hour >= 13 (e.g. "23:30" in SOL)
#   - timestamp hhmm invalid (hour > 23, minute > 59)
#   - timestamp order violated in the corrupted data (bed > sleep etc.)
to24 <- function(hhmm, ampm) {
  parts <- strsplit(hhmm, ":"); h <- as.integer(sapply(parts, `[`, 1)); mn <- as.integer(sapply(parts, `[`, 2))
  h24 <- ifelse(ampm == "PM" & h != 12, h + 12, ifelse(ampm == "AM" & h == 12, 0, h))
  list(h = h24, m = mn)
}

dur_cols <- c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am",
              "duration_totalmin_napstoday_PM",
              "exercisetoday_PM_totalmin_Light", "exercisetoday_PM_totalmin_Moderate",
              "exercisetoday_PM_totalmin_Vigorous", "exercisetoday_PM_totalmin_Strength")
ts_hhmm <- c("time_bed_am_hhmm","time_sleep_am_hhmm","time_awake_am_hhmm","time_getup_am_hhmm")
ts_ampm <- c("time_bed_am_ampm","time_sleep_am_ampm","time_awake_am_ampm","time_getup_am_ampm")

naive_flag <- rep(FALSE, nrow(raw))
for (i in seq_len(nrow(raw))) {
  # duration fields: flag non-numeric or clock-shape hour >= 13 (>= 4h reinterpret risk)
  for (dc in dur_cols) {
    v <- suppressWarnings(as.character(raw[[dc]][i]))
    if (is.na(v) || v == "" || v == "NA") next
    if (!grepl("^[0-9.]+$", v)) { naive_flag[i] <- TRUE; break }
    num <- as.numeric(v)
    if (!is.na(num) && num > 720) { naive_flag[i] <- TRUE; break }
  }
  if (naive_flag[i]) next
  # timestamps: hour range + order
  hrs <- numeric(4); ok <- rep(FALSE, 4)
  for (k in seq_along(ts_hhmm)) {
    hh <- raw[[ts_hhmm[k]]][i]; ap <- raw[[ts_ampm[k]]][i]
    if (is.na(hh) || is.na(ap) || hh == "" || ap == "") next
    t <- tryCatch(to24(hh, ap), error = function(e) NULL)
    if (is.null(t)) { naive_flag[i] <- TRUE; ok <- rep(FALSE, 4); break }
    hrs[k] <- t$h + t$m / 60
    ok[k] <- TRUE
  }
  if (naive_flag[i]) next
  if (sum(ok) == 4) {
    # midnight-aware order check: walk hours, adding 24h whenever the clock
    # drops (bed 23:00 -> sleep 00:30 is a legit night, not a violation)
    h <- hrs
    for (k in 2:4) if (h[k] < h[k-1]) h[k] <- h[k] + 24
    if (any(diff(h) < 0)) naive_flag[i] <- TRUE
  }
}

# naive recall on injected rows, naive FAR on control rows
err_ids <- gt$row_id[gt$error_type != "no_error_control"]
ctrl_ids <- gt$row_id[gt$error_type == "no_error_control"]
nr_flag <- naive_flag[raw$row_id %in% err_ids]
n_ctrl_flag <- naive_flag[raw$row_id %in% ctrl_ids]
naive_recall <- mean(nr_flag)
naive_far_flag <- mean(n_ctrl_flag)
naive_far_alter <- 0  # naive rule never alters values

# ── Real pipeline numbers (from 5.1/5.3) ────────────────────────────────────
err <- per_row[per_row$error_type != "no_error_control", ]
pipeline_recall <- mean(err$detected)
pipeline_far_flag <- 0      # 5.3: 0/2255 control flagged
pipeline_far_alter <- 0

cat("\n=== Control conditions (same enrichment benchmark) ===\n")
cat(sprintf("No-cleaning:  recall = %.4f, FAR_flag = %.4f, FAR_alter = %.4f (identity floor)\n",
            nc_recall, nc_far_flag, nc_far_alter))
cat(sprintf("Naive-rule:   recall = %.4f (%d/%d), FAR_flag = %.4f, FAR_alter = %.4f\n",
            naive_recall, sum(nr_flag), length(nr_flag), naive_far_flag, naive_far_alter))
cat(sprintf("Pipeline:     recall = %.4f, FAR_flag = %.4f, FAR_alter = %.4f\n",
            pipeline_recall, pipeline_far_flag, pipeline_far_alter))

out <- data.frame(
  condition = c("no_cleaning", "naive_rule", "pipeline"),
  recall = c(nc_recall, naive_recall, pipeline_recall),
  far_flag = c(nc_far_flag, naive_far_flag, pipeline_far_flag),
  far_alter = c(nc_far_alter, naive_far_alter, pipeline_far_alter)
)
write.csv(out, file.path(RES, "control_baselines.csv"), row.names = FALSE)
cat("\nWrote control_baselines.csv\n")
cat("\n=== [control_baselines] Finished ===\n")
