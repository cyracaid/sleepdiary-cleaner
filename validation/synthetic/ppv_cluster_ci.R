# ppv_cluster_ci.R — 5.1: PPV curve + cluster-bootstrap CIs (recall/specificity)
# =============================================================================
# Design (validation/benchmark_design.md §5/§8, meeting decision D1-b):
#   1. regenerate the enrichment benchmark (clean n=7,000 → inject 400/cat)
#   2. run the real pipeline (run_one.R) on the corrupted data
#   3. evaluate per-ROW outcomes (L1 flag / value-correct) WITH participant id
#   4. participant-level cluster bootstrap → recall + specificity CIs
#   5. PPV curve over π = 0.5%–10% via Bayes (from recall + specificity)
#
# Outputs (validation/synthetic/results/):
#   ppv_curve.csv                — π, PPV(+2.5/97.5% bootstrap)
#   recall_specificity_ci.csv    — per-category + pooled recall/spec CI
#   cluster_bootstrap_per_row.csv — per-row outcomes used for bootstrap
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(yaml)
})

set.seed(20260817)

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")
dir.create(RES, showWarnings = FALSE, recursive = TRUE)

# ── Step 1: regenerate clean + inject ───────────────────────────────────────
clean_rds  <- file.path(SYN, "clean_plausible_enrichment_n7000.rds")
corr_rds   <- file.path(SYN, "corrupted_enrichment.rds")
truth_csv  <- file.path(SYN, "ground_truth_enrichment.csv")

if (!file.exists(clean_rds)) {
  cat("Generating clean plausible enrichment set (n=7,000)...\n")
  system2("Rscript", c(file.path(SYN, "generate_clean_data.R"),
    "--n_participants=500", "--n_days=14", "--mode=plausible",
    "--population=healthy_adult", "--seed=20260817", paste0("--out=", clean_rds)),
    stdout = TRUE, stderr = TRUE, wait = TRUE)
}
if (!file.exists(corr_rds) || !file.exists(truth_csv)) {
  cat("Injecting errors (target 400/category)...\n")
  # inject_errors.R reads error_catalog.yaml relative to cwd -> pass absolute
  system2("Rscript", c(file.path(SYN, "inject_errors.R"),
    paste0("--clean_rds=", clean_rds),
    paste0("--catalog=", file.path(SYN, "error_catalog.yaml")),
    paste0("--out_data=", corr_rds),
    paste0("--out_truth=", truth_csv),
    "--seed=20260817"),
    stdout = TRUE, stderr = TRUE, wait = TRUE)
}

gt_raw <- read.csv(truth_csv, stringsAsFactors = FALSE)
clean  <- readRDS(clean_rds)
cat("ground_truth rows:", nrow(gt_raw), " pid col:", "pid" %in% names(gt_raw),
    " error_type col:", "error_type" %in% names(gt_raw), "\n")

# ── Step 2: run pipeline ────────────────────────────────────────────────────
run_dir <- file.path(SYN, "run_ppv")
corrected_rds <- file.path(run_dir, "corrected_ema_data.rds")
review_rds    <- file.path(run_dir, "review_output.rds")

if (!file.exists(corrected_rds)) {
  cat("Running pipeline on corrupted data (run_one.R)...\n")
  out <- system2("Rscript", c(file.path(SYN, "run_one.R"),
    corr_rds, file.path(getwd(), run_dir), "ppv_ci_benchmark"),
    stdout = TRUE, stderr = TRUE, wait = TRUE)
  if (!file.exists(corrected_rds)) {
    cat(paste(tail(out, 30), collapse = "\n"), "\n")
    stop("pipeline run failed: corrected_ema_data.rds not produced")
  }
}
corrected <- readRDS(corrected_rds)
review    <- readRDS(review_rds)
raw       <- readRDS(corr_rds)   # corrupted input fed to the pipeline
cat("pipeline output rows:", nrow(corrected), "\n")

# ── Step 3: per-row outcome classification (value-correct + flagged) ────────
# L1 = flagged (needs_review_flag OR any checkforerrors) — "detected"
# L3 = final value equals ground-truth true_value — "value-correct"
d <- review$data_with_flags
flag_cols <- grep("_checkforerrors$", names(d), value = TRUE)
flag_marker <- rep(FALSE, nrow(d))
for (c in flag_cols) flag_marker <- flag_marker | (d[[c]] %in% TRUE)
flagged <- d$needs_review_flag %in% TRUE | flag_marker

# For each ground-truth injected error (exclude no_error_control = the
# specificity/clean set), decide detected = flagged OR value-corrected.
# Reuse the multi-field resolver semantics of evaluate_detection.R: swap and
# compound categories pipe-join several fields/true_values, so a naive
# single-field match would wrongly report them as value-incorrect.
DUR_FIELDS <- c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am")
TS_MAP <- c(
  time_bed_am_hhmm = "time_bed_corrected",   time_bed_am_ampm = "time_bed_corrected",
  time_sleep_am_hhmm = "time_sleep_corrected", time_sleep_am_ampm = "time_sleep_corrected",
  time_awake_am_hhmm = "time_awake_corrected", time_awake_am_ampm = "time_awake_corrected",
  time_getup_am_hhmm = "time_getup_corrected", time_getup_am_ampm = "time_getup_corrected"
)
to24 <- function(hhmm, ampm) {
  parts <- strsplit(hhmm, ":"); h <- as.integer(sapply(parts, `[`, 1)); mn <- as.integer(sapply(parts, `[`, 2))
  h24 <- ifelse(ampm == "PM" & h != 12, h + 12, ifelse(ampm == "AM" & h == 12, 0, h))
  sprintf("%02d:%02d", h24, mn)
}

value_correct <- function(gt_row) {
  rid <- gt_row$row_id
  field <- gt_row$field
  if (is.na(field) || !nzchar(field)) return(FALSE)
  rcor <- corrected[corrected$row_id == rid, , drop = FALSE]
  if (nrow(rcor) != 1) return(FALSE)

  fields <- strsplit(field, "\\|")[[1]]
  trues  <- strsplit(gt_row$true_value, "\\|")[[1]]

  # duration single-field case
  if (length(fields) == 1 && fields[1] %in% DUR_FIELDS) {
    mincalc_col <- paste0(fields[1], "_mincalc")
    got <- round(suppressWarnings(as.numeric(rcor[[mincalc_col]])))
    want <- round(suppressWarnings(as.numeric(trues[1])))
    return(!is.na(got) && !is.na(want) && got == want)
  }

  # multi-field timestamp case: every touched prefix must match its true hhmm+ampm
  ts_fields <- fields[fields %in% names(TS_MAP)]
  prefixes <- unique(sub("_(hhmm|ampm)$", "", ts_fields))
  rraw <- raw[raw$row_id == rid, , drop = FALSE]
  if (nrow(rraw) != 1) return(FALSE)
  for (p in prefixes) {
    hf <- paste0(p, "_hhmm"); af <- paste0(p, "_ampm")
    hi <- match(hf, fields); ai <- match(af, fields)
    # Fallback to the raw (corrupted-input) value for a component this
    # injection did NOT touch -- same semantics as evaluate_detection.R
    # (true_hhmm/true_ampm). ampm_swap only touches the ampm field, so the
    # hhmm component is absent from the pipe list and must come from raw.
    want_hhmm <- if (!is.na(hi)) trues[hi] else rraw[[hf]]
    want_ampm <- if (!is.na(ai)) trues[ai] else rraw[[af]]
    if (is.na(want_hhmm)) return(FALSE)
    cor_col <- TS_MAP[[hf]]
    got <- format(as.POSIXct(rcor[[cor_col]]), "%H:%M")
    want <- to24(want_hhmm, want_ampm)
    if (is.na(got) || got != want) return(FALSE)
  }
  TRUE
}

gt <- gt_raw
gt$detected_flag <- flagged[match(gt$row_id, d$row_id)]
gt$detected_flag[is.na(gt$detected_flag)] <- FALSE
gt$value_correct <- vapply(seq_len(nrow(gt)), function(i) value_correct(gt[i, ]), logical(1))
# detection = surfaced (flag) OR fixed-to-truth (value correct)
gt$detected <- gt$detected_flag | gt$value_correct

cat("\nPer-category detection (L1 flag OR value-correct):\n")
print(gt %>% group_by(error_type) %>%
  summarise(n = n(), detected = sum(detected), flag = sum(detected_flag),
            vcorrect = sum(value_correct), .groups = "drop") %>%
  mutate(detect_pct = round(100 * detected / n, 1)) %>% as.data.frame())

# ── Step 4: cluster bootstrap CI ────────────────────────────────────────────
# Clusters = participants (pid). Resample pids WITH replacement, aggregate
# detection rate within the resampled set. Pooled recall over all injected
# (non-control) errors; pooled specificity over control rows.
err <- gt[gt$error_type != "no_error_control", ]
ctrl <- gt[gt$error_type == "no_error_control", ]
cat("\ninjected errors:", nrow(err), " control rows:", nrow(ctrl), "\n")

cluster_boot <- function(df, n_boot = 2000, metric) {
  pids <- unique(df$pid)
  est <- function(idx) {
    sub <- df[df$pid %in% idx, ]
    switch(metric,
      recall = mean(sub$detected),
      specificity = mean(!sub$detected_flag))  # control: flag rate is the false-positive signal
  }
  obs <- est(pids)
  b <- replicate(n_boot, est(sample(pids, length(pids), replace = TRUE)))
  c(est = obs,
    lo = unname(quantile(b, 0.025, na.rm = TRUE)),
    hi = unname(quantile(b, 0.975, na.rm = TRUE)))
}

boot_recall <- cluster_boot(err, metric = "recall")
boot_spec   <- cluster_boot(ctrl, metric = "specificity")
cat(sprintf("Pooled recall: %.4f [%.4f, %.4f]\n", boot_recall["est"], boot_recall["lo"], boot_recall["hi"]))
cat(sprintf("Specificity (control): %.4f [%.4f, %.4f]\n", boot_spec["est"], boot_spec["lo"], boot_spec["hi"]))

# Per-category cluster-bootstrap recall CIs (n per category >= 2 clusters)
cat_ci <- lapply(sort(unique(err$error_type)), function(ct) {
  sub <- err[err$error_type == ct, ]
  pids_c <- unique(sub$pid)
  if (length(pids_c) < 2) {
    return(data.frame(category = ct, n = nrow(sub), recall = mean(sub$detected),
                      lo = NA_real_, hi = NA_real_))
  }
  est <- mean(sub$detected)
  b <- replicate(1000, {
    idx <- sample(pids_c, length(pids_c), replace = TRUE)
    mean(sub$detected[sub$pid %in% idx])
  })
  data.frame(category = ct, n = nrow(sub), recall = est,
             lo = unname(quantile(b, 0.025, na.rm = TRUE)),
             hi = unname(quantile(b, 0.975, na.rm = TRUE)))
})
cat_ci_df <- do.call(rbind, cat_ci)
cat("\nPer-category recall (cluster bootstrap CI):\n")
print(cat_ci_df, row.names = FALSE)

# ── Step 5: PPV curve via Bayes ─────────────────────────────────────────────
pi_seq <- seq(0.005, 0.10, by = 0.005)
recall <- boot_recall["est"]
spec   <- boot_spec["est"]
ppv <- function(pi) (pi * recall) / (pi * recall + (1 - pi) * (1 - spec))

# bootstrap PPV band: recompute from bootstrap draws
pids_err <- unique(err$pid); pids_ctrl <- unique(ctrl$pid)
ppv_boot <- function(n_boot = 500) {
  out <- matrix(NA_real_, nrow = length(pi_seq), ncol = n_boot)
  for (b in seq_len(n_boot)) {
    ie <- sample(pids_err, length(pids_err), replace = TRUE)
    ic <- sample(pids_ctrl, length(pids_ctrl), replace = TRUE)
    re <- mean(err$detected[err$pid %in% ie])
    sp <- mean(!ctrl$detected_flag[ctrl$pid %in% ic])
    out[, b] <- (pi_seq * re) / (pi_seq * re + (1 - pi_seq) * (1 - sp))
  }
  out
}
set.seed(20260817)
ppv_b <- ppv_boot(500)
ppv_df <- data.frame(
  pi = pi_seq,
  ppv = vapply(pi_seq, ppv, numeric(1)),
  ppv_lo = apply(ppv_b, 1, quantile, 0.025, na.rm = TRUE),
  ppv_hi = apply(ppv_b, 1, quantile, 0.975, na.rm = TRUE)
)
write.csv(ppv_df, file.path(RES, "ppv_curve.csv"), row.names = FALSE)

ci_df <- rbind(
  data.frame(metric = "recall_pooled", est = boot_recall["est"], lo = boot_recall["lo"], hi = boot_recall["hi"]),
  data.frame(metric = "specificity_control", est = boot_spec["est"], lo = boot_spec["lo"], hi = boot_spec["hi"])
)
names(ci_df) <- c("metric", "est", "lo", "hi")
cat_ci_r <- setNames(data.frame(
  metric = cat_ci_df$category, est = cat_ci_df$recall,
  lo = cat_ci_df$lo, hi = cat_ci_df$hi
), names(ci_df))
ci_df <- rbind(ci_df, cat_ci_r)
write.csv(ci_df, file.path(RES, "recall_specificity_ci.csv"), row.names = FALSE)

# per-row outcomes for the record
per_row <- data.frame(
  pid = gt$pid, row_id = gt$row_id, error_type = gt$error_type,
  field = gt$field, detected = gt$detected,
  detected_flag = gt$detected_flag, value_correct = gt$value_correct
)
write.csv(per_row, file.path(RES, "cluster_bootstrap_per_row.csv"), row.names = FALSE)

cat("\n=== PPV curve (π = 0.5%–10%) ===\n")
print(ppv_df, row.names = FALSE)
cat("\nWrote: ppv_curve.csv, recall_specificity_ci.csv, cluster_bootstrap_per_row.csv\n")
cat("\n=== [ppv_cluster_ci] Finished ===\n")
