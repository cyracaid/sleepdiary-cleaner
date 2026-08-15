# far_flag_mrr_magnitude.R — 5.3: FAR_flag / MRR / misrepair-magnitude
# =============================================================================
# Separates the false-positive signal into FAR_flag (flagged-but-clean) and
# FAR_alter (value-altered-while-clean); computes the misrepair rate MRR
# (changed-but-wrong on injected rows) and the misrepair magnitude
# distribution (minutes, with the >LoA-half-width share). Uses the 5.1
# enrichment run artifacts (ppv_cluster_ci.R) so numbers stay consistent.
#
#   FAR_flag    = flagged / all clean-control rows            (false positives)
#   FAR_alter   = value-altered / all clean-control rows      (silent damage)
#   MRR         = MISREPAIRED / all injected rows             (wrong auto-fix)
#   magnitude   = |corrected − true| for MISREPAIRED rows (min), median/IQR/max
#
# Outputs (validation/synthetic/results/):
#   far_flag_alter.csv     — control-row FAR_flag + FAR_alter (+ per-field)
#   mrr_magnitude.csv      — per-category MRR + magnitude distribution
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(yaml)
})

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")
truth_csv <- file.path(SYN, "ground_truth_enrichment.csv")
corr_rds  <- file.path(SYN, "corrupted_enrichment.rds")
run_dir   <- file.path(SYN, "run_ppv")
corrected_rds <- file.path(run_dir, "corrected_ema_data.rds")
review_rds    <- file.path(run_dir, "review_output.rds")

stopifnot(all(file.exists(c(truth_csv, corr_rds, corrected_rds, review_rds))))

gt    <- read.csv(truth_csv, stringsAsFactors = FALSE)
raw   <- readRDS(corr_rds)
corr  <- readRDS(corrected_rds)
review <- readRDS(review_rds)
d <- review$data_with_flags

# ── Flagged + altered masks on ALL rows ─────────────────────────────────────
flag_cols <- grep("_checkforerrors$", names(d), value = TRUE)
flag_marker <- rep(FALSE, nrow(d))
for (c in flag_cols) flag_marker <- flag_marker | (d[[c]] %in% TRUE)
flagged <- d$needs_review_flag %in% TRUE | flag_marker

# altered: any of the 4 corrected timestamps differs from raw by >1s
t_cols <- c("time_bed_corrected","time_sleep_corrected","time_awake_corrected","time_getup_corrected")
# raw input has *_am_hhmm + *_am_ampm; rebuild a comparable "raw corrected" baseline
# is overkill -- instead reuse prepost-style change detection via corrected cols only
# is impossible without raw timestamps. Use the FCR approach: compare raw hhmm/ampm
# against formatted corrected values.
r_hhmm <- c("time_bed_am_hhmm","time_sleep_am_hhmm","time_awake_am_hhmm","time_getup_am_hhmm")
r_ampm <- c("time_bed_am_ampm","time_sleep_am_ampm","time_awake_am_ampm","time_getup_am_ampm")
to24 <- function(hhmm, ampm) {
  parts <- strsplit(hhmm, ":"); h <- as.integer(sapply(parts, `[`, 1)); mn <- as.integer(sapply(parts, `[`, 2))
  h24 <- ifelse(ampm == "PM" & h != 12, h + 12, ifelse(ampm == "AM" & h == 12, 0, h))
  sprintf("%02d:%02d", h24, mn)
}
altered <- rep(FALSE, nrow(d))
for (k in seq_along(r_hhmm)) {
  rk <- raw[raw$row_id == d$row_id, c(r_hhmm[k], r_ampm[k]), drop = FALSE]
  if (nrow(rk) != 1) next
  raw24 <- to24(rk[[1]], rk[[2]])
  got24 <- format(as.POSIXct(d[[t_cols[k]]]), "%H:%M")
  altered <- altered | (!is.na(raw24) & !is.na(got24) & raw24 != got24)
}
altered[is.na(altered)] <- FALSE

# ── FAR on clean-control rows ───────────────────────────────────────────────
ctrl_ids <- gt$row_id[gt$error_type == "no_error_control"]
ctrl <- d[d$row_id %in% ctrl_ids, ]
n_ctrl <- nrow(ctrl)
far_flag <- sum(flagged[d$row_id %in% ctrl_ids])
far_alter <- sum(altered[d$row_id %in% ctrl_ids])

cat(sprintf("\nFAR_flag = %d/%d = %.4f\n", far_flag, n_ctrl, far_flag / n_ctrl))
cat(sprintf("FAR_alter = %d/%d = %.4f\n", far_alter, n_ctrl, far_alter / n_ctrl))

far_df <- data.frame(
  metric = c("FAR_flag", "FAR_alter"),
  n_control = n_ctrl, n_hit = c(far_flag, far_alter),
  rate = c(far_flag / n_ctrl, far_alter / n_ctrl)
)
write.csv(far_df, file.path(RES, "far_flag_alter.csv"), row.names = FALSE)

# ── MRR + magnitude on injected rows ────────────────────────────────────────
# reuse the 5.1 value_correct classification for "changed to truth" and add
# "changed but wrong" (MISREPAIRED) = value differs from true AND differs from
# corrupted input. Reload the per-row outcomes from 5.1.
per_row <- read.csv(file.path(RES, "cluster_bootstrap_per_row.csv"), stringsAsFactors = FALSE)
err <- per_row[per_row$error_type != "no_error_control", ]

# MISREPAIRED: changed-from-corrupted AND not value-correct. We approximate
# "changed-from-corrupted" as (corrected value differs from true) — the
# magnitude of the wrong fix. Recompute directly from gt + corrected.
DUR_FIELDS <- c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am")
TS_MAP <- c(
  time_bed_am_hhmm = "time_bed_corrected",   time_bed_am_ampm = "time_bed_corrected",
  time_sleep_am_hhmm = "time_sleep_corrected", time_sleep_am_ampm = "time_sleep_corrected",
  time_awake_am_hhmm = "time_awake_corrected", time_awake_am_ampm = "time_awake_corrected",
  time_getup_am_hhmm = "time_getup_corrected", time_getup_am_ampm = "time_getup_corrected"
)

# outcome + magnitude (minutes) per injected row
classify <- function(gt_row) {
  rid <- gt_row$row_id; field <- gt_row$field
  if (is.na(field) || !nzchar(field)) return(c(kind = "MISSED", mag = NA_real_))
  rcor <- corr[corr$row_id == rid, , drop = FALSE]
  rraw <- raw[raw$row_id == rid, , drop = FALSE]
  if (nrow(rcor) != 1 || nrow(rraw) != 1) return(c(kind = "NO_MATCH", mag = NA_real_))
  fields <- strsplit(field, "\\|")[[1]]
  trues  <- strsplit(gt_row$true_value, "\\|")[[1]]
  corr_vals <- character(0); true_vals <- character(0); raw_vals <- character(0)
  if (length(fields) == 1 && fields[1] %in% DUR_FIELDS) {
    mc <- paste0(fields[1], "_mincalc")
    corr_vals <- as.character(round(suppressWarnings(as.numeric(rcor[[mc]]))))
    true_vals <- as.character(round(suppressWarnings(as.numeric(trues[1]))))
    raw_vals  <- as.character(round(suppressWarnings(as.numeric(gt_row$original_value))))
  } else {
    ts <- fields[fields %in% names(TS_MAP)]
    prefixes <- unique(sub("_(hhmm|ampm)$", "", ts))
    for (p in prefixes) {
      hf <- paste0(p, "_hhmm"); af <- paste0(p, "_ampm")
      hi <- match(hf, fields); ai <- match(af, fields)
      wh <- if (!is.na(hi)) trues[hi] else rraw[[hf]]
      wa <- if (!is.na(ai)) trues[ai] else rraw[[af]]
      cc <- TS_MAP[[hf]]
      corr_vals <- c(corr_vals, format(as.POSIXct(rcor[[cc]]), "%H:%M"))
      true_vals <- c(true_vals, to24(wh, wa))
      raw_vals  <- c(raw_vals, to24(rraw[[hf]], rraw[[af]]))
    }
  }
  if (length(corr_vals) == 0 || any(is.na(corr_vals)) || any(is.na(true_vals))) {
    return(c(kind = if (isTRUE(d$needs_review_flag[match(rid, d$row_id)])) "FLAGGED" else "MISSED", mag = NA_real_))
  }
  correct <- all(corr_vals == true_vals)
  changed  <- any(corr_vals != raw_vals)
  # precedence matches evaluate_detection.R: CORRECT > FLAGGED > MISREPAIRED > MISSED
  is_flagged <- isTRUE(d$needs_review_flag[match(rid, d$row_id)]) |
                any(vapply(flag_cols, function(c) isTRUE(d[[c]][match(rid, d$row_id)]), logical(1)))
  if (correct) return(c(kind = "CORRECT", mag = 0))
  if (is_flagged) return(c(kind = "FLAGGED", mag = NA_real_))
  if (changed) {
    # magnitude: for duration use minutes; for timestamps use |corr - true| in min
    if (length(corr_vals) == 1 && !is.na(suppressWarnings(as.numeric(corr_vals))) &&
        !is.na(suppressWarnings(as.numeric(true_vals)))) {
      mag <- abs(as.numeric(corr_vals) - as.numeric(true_vals))
    } else {
      ct <- as.POSIXct(paste("2000-01-01", corr_vals[1])); tt <- as.POSIXct(paste("2000-01-01", true_vals[1]))
      mag <- abs(as.numeric(ct - tt, units = "mins")); if (is.na(mag)) mag <- 0
    }
    return(c(kind = "MISREPAIRED", mag = mag))
  }
  if (is_flagged) return(c(kind = "FLAGGED", mag = NA_real_))
  c(kind = "MISSED", mag = NA_real_)
}

cls <- do.call(rbind, lapply(seq_len(nrow(gt)), function(i) {
  r <- classify(gt[i, ])
  data.frame(row_id = gt$row_id[i], error_type = gt$error_type[i],
             kind = r["kind"], mag = as.numeric(r["mag"]), stringsAsFactors = FALSE)
}))

mrr_df <- cls %>%
  filter(error_type != "no_error_control") %>%
  group_by(error_type) %>%
  summarise(
    n = n(),
    misrepaired = sum(kind == "MISREPAIRED"),
    flagged = sum(kind == "FLAGGED"),
    correct = sum(kind == "CORRECT"),
    missed = sum(kind == "MISSED"),
    mrr = mean(kind == "MISREPAIRED"),
    mag_median = suppressWarnings(median(mag[kind == "MISREPAIRED"], na.rm = TRUE)),
    mag_iqr = suppressWarnings(IQR(mag[kind == "MISREPAIRED"], na.rm = TRUE)),
    mag_max = suppressWarnings(max(mag[kind == "MISREPAIRED"], na.rm = TRUE)),
    mag_gt_loa = suppressWarnings(mean(mag[kind == "MISREPAIRED"] > 6.5, na.rm = TRUE)),  # LoA half-width ~13min/2
    .groups = "drop"
  ) %>% as.data.frame()

cat("\n=== MRR + misrepair magnitude (per category) ===\n")
print(mrr_df, row.names = FALSE)
cat("\nLoA half-width used for >LoA share: 6.5 min (baseline noise median 13 min / 2)\n")

write.csv(mrr_df, file.path(RES, "mrr_magnitude.csv"), row.names = FALSE)

# pooled MRR
pool <- cls %>% filter(error_type != "no_error_control")
cat(sprintf("\nPooled MRR = %d/%d = %.4f\n", sum(pool$kind == "MISREPAIRED"), nrow(pool),
            mean(pool$kind == "MISREPAIRED")))
mag <- pool$mag[pool$kind == "MISREPAIRED"]
if (length(mag) > 0) {
  cat(sprintf("Pooled magnitude: median %.1f min, IQR [%.1f, %.1f], max %.1f, >LoA %.1f%%\n",
              median(mag), quantile(mag, 0.25), quantile(mag, 0.75), max(mag),
              100 * mean(mag > 6.5)))
}

write.csv(cls, file.path(RES, "mrr_per_row.csv"), row.names = FALSE)
cat("\n=== [far_flag_mrr_magnitude] Finished ===\n")
