# seed_sensitivity.R — multi-seed robustness of benchmark conclusions
# =============================================================================
# Issue #2 from robustness review: all benchmark numbers come from a SINGLE
# injection seed (20260812/20260817). A reviewer will ask whether pooled
# recall ~0.995, the 3 weak categories, and the multiverse OAT survival
# decision (D1+D2 -> 9 specs) are stable under different generated datasets.
#
# Design: for each of N seeds, regenerate clean (mode=plausible) + inject
# (same catalog, same n=7,000), run the real pipeline, evaluate pooled
# recall + per-category recall. Seeds 20260812/20260817 are the original two;
# additional seeds are new. OAT survival is the heavy part (13 pipeline runs
# per seed) so we check it on a SUBSET: the two original seeds + one new.
#
# Output: results/seed_sensitivity.csv
#   seed, pooled_recall, recall_lo, recall_hi, n_injected,
#   per-category recall columns for the 3 weak categories (L2-relevant ones:
#   cross_participant_spike, adjacent_swap_awake_getup, ampm_swap),
#   oat_survivors (comma list)
# =============================================================================

suppressPackageStartupMessages({ library(dplyr); library(yaml) })

SYN <- "validation/synthetic"
RES <- file.path(SYN, "results")
source(file.path(SYN, "spec_cache.R"))

SEEDS <- c(20260812, 20260817, 20260901, 20260915)
OAT_SEEDS <- c(20260817, 20260915)   # heavy OAT on original + one fresh seed

to24 <- function(hhmm, ampm) {
  parts <- strsplit(hhmm, ":"); h <- as.integer(sapply(parts, `[`, 1)); mn <- as.integer(sapply(parts, `[`, 2))
  h24 <- ifelse(ampm == "PM" & h != 12, h + 12, ifelse(ampm == "AM" & h == 12, 0, h))
  sprintf("%02d:%02d", h24, mn)
}
TS_MAP <- c(
  time_bed_am_hhmm = "time_bed_corrected",   time_bed_am_ampm = "time_bed_corrected",
  time_sleep_am_hhmm = "time_sleep_corrected", time_sleep_am_ampm = "time_sleep_corrected",
  time_awake_am_hhmm = "time_awake_corrected", time_awake_am_ampm = "time_awake_corrected",
  time_getup_am_hhmm = "time_getup_corrected", time_getup_am_ampm = "time_getup_corrected"
)
DUR_FIELDS <- c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am")

# value_correct evaluator (mirrors ppv_cluster_ci.R semantics)
value_correct <- function(gt_row, corrected, raw) {
  rid <- gt_row$row_id; field <- gt_row$field
  if (is.na(field) || !nzchar(field)) return(FALSE)
  rcor <- corrected[corrected$row_id == rid, , drop = FALSE]
  if (nrow(rcor) != 1) return(FALSE)
  fields <- strsplit(field, "\\|")[[1]]
  trues  <- strsplit(gt_row$true_value, "\\|")[[1]]
  if (length(fields) == 1 && fields[1] %in% DUR_FIELDS) {
    got <- round(suppressWarnings(as.numeric(rcor[[paste0(fields[1], "_mincalc")]])))
    want <- round(suppressWarnings(as.numeric(trues[1])))
    return(!is.na(got) && !is.na(want) && got == want)
  }
  ts_fields <- fields[fields %in% names(TS_MAP)]
  prefixes <- unique(sub("_(hhmm|ampm)$", "", ts_fields))
  rraw <- raw[raw$row_id == rid, , drop = FALSE]
  if (nrow(rraw) != 1) return(FALSE)
  for (p in prefixes) {
    hf <- paste0(p, "_hhmm"); af <- paste0(p, "_ampm")
    hi <- match(hf, fields); ai <- match(af, fields)
    want_hhmm <- if (!is.na(hi)) trues[hi] else rraw[[hf]]
    want_ampm <- if (!is.na(ai)) trues[ai] else rraw[[af]]
    if (is.na(want_hhmm)) return(FALSE)
    got <- format(as.POSIXct(rcor[[TS_MAP[[hf]]]]), "%H:%M")
    want <- to24(want_hhmm, want_ampm)
    if (is.na(got) || got != want) return(FALSE)
  }
  TRUE
}

run_seed <- function(seed, run_oat = FALSE) {
  cat(sprintf("\n########## SEED %d ##########\n", seed))
  clean_rds  <- file.path(SYN, sprintf("clean_seed%d.rds", seed))
  corr_rds   <- file.path(SYN, sprintf("corrupted_seed%d.rds", seed))
  truth_csv  <- file.path(SYN, sprintf("ground_truth_seed%d.csv", seed))
  run_dir    <- file.path(SYN, sprintf("run_seed%d", seed))

  if (!file.exists(corr_rds)) {
    system2("Rscript", c(file.path(SYN, "generate_clean_data.R"),
      "--n_participants=500", "--n_days=14", "--mode=plausible",
      "--population=healthy_adult", sprintf("--seed=%d", seed), sprintf("--out=%s", clean_rds)),
      stdout = TRUE, stderr = TRUE, wait = TRUE)
    system2("Rscript", c(file.path(SYN, "inject_errors.R"),
      sprintf("--clean_rds=%s", clean_rds),
      sprintf("--catalog=%s", file.path(SYN, "error_catalog.yaml")),
      sprintf("--out_data=%s", corr_rds), sprintf("--out_truth=%s", truth_csv),
      sprintf("--seed=%d", seed)),
      stdout = TRUE, stderr = TRUE, wait = TRUE)
  }
  if (!file.exists(file.path(run_dir, "corrected_ema_data.rds"))) {
    system2("Rscript", c(file.path(SYN, "run_one.R"), corr_rds, run_dir, sprintf("seed%d", seed)),
      stdout = TRUE, stderr = TRUE, wait = TRUE)
  }
  corrected <- readRDS(file.path(run_dir, "corrected_ema_data.rds"))
  review    <- readRDS(file.path(run_dir, "review_output.rds"))
  raw       <- readRDS(corr_rds)
  gt        <- read.csv(truth_csv, stringsAsFactors = FALSE)
  d <- review$data_with_flags

  flag_cols <- grep("_checkforerrors$", names(d), value = TRUE)
  fm <- rep(FALSE, nrow(d)); for (c in flag_cols) fm <- fm | (d[[c]] %in% TRUE)
  flagged <- d$needs_review_flag %in% TRUE | fm

  gt$detected_flag <- flagged[match(gt$row_id, d$row_id)]
  gt$detected_flag[is.na(gt$detected_flag)] <- FALSE
  gt$value_correct <- vapply(seq_len(nrow(gt)), function(i) value_correct(gt[i, ], corrected, raw), logical(1))
  gt$detected <- gt$detected_flag | gt$value_correct

  err <- gt[gt$error_type != "no_error_control", ]
  ctrl <- gt[gt$error_type == "no_error_control", ]
  recall <- mean(err$detected)
  cat(sprintf("pooled recall: %.4f (n=%d), control FAR_flag: %d/%d\n",
              recall, nrow(err), sum(flagged[d$row_id %in% ctrl$row_id]), nrow(ctrl)))

  cat_rec <- err %>% group_by(error_type) %>%
    summarise(n = n(), rec = mean(detected), .groups = "drop") %>% as.data.frame()

  # OAT survival decision for this seed (13 extra pipeline runs; only for OAT_SEEDS)
  survivors <- NA_character_
  if (run_oat) {
    dims <- list(
      D1 = list(key = "timestamp.sequence.max_gap_hours",            levels = c(11, 12, 13), default = 12),
      D2 = list(key = "normalize.swap_threshold_hours",              levels = c(1, 3, 6),    default = 3),
      D3 = list(key = "classification.metric_validation.sol.excessive_minutes", levels = c(90, 120, 180), default = 120),
      D4 = list(key = "classification.flag_severity.poor_efficiency_threshold_pct", levels = c(60, 70, 80), default = 70),
      D5 = list(key = "classification.metric_validation.waso.excessive_hours",   levels = c(1.0, 1.5, 2.0), default = 1.5),
      D6 = list(key = "classification.metric_validation.tst_tib_ratio.min_ratio", levels = c(0.4, 0.5, 0.6), default = 0.5)
    )
    base_ov <- lapply(dims, function(x) x$default)
    dim2key <- function(ov) { out <- list(); for (nm in names(ov)) out[[dims[[nm]]$key]] <- ov[[nm]]; out }
    base <- run_spec_once(sprintf("seed%d_BASE", seed), dim2key(base_ov), input_rds = corr_rds)
    if (!is.null(base)) {
      keep <- names(dims)
      for (nm in names(dims)) {
        d_tst <- d_n <- d_fl <- 0
        for (lv in setdiff(dims[[nm]]$levels, dims[[nm]]$default)) {
          ov <- base_ov; ov[[nm]] <- lv
          s <- run_spec_once(sprintf("seed%d_%s=%g", seed, nm, lv), dim2key(ov), input_rds = corr_rds)
          if (is.null(s)) next
          d_tst <- max(d_tst, abs(s$mean_tst_h - base$mean_tst_h) * 60)
          d_n   <- max(d_n, abs(s$analyzable_n - base$analyzable_n) / base$analyzable_n * 100)
          d_fl  <- max(d_fl, abs(s$n_flagged - base$n_flagged) / max(base$n_flagged, 1) * 100)
        }
        if (d_tst < 5 && d_n < 1 && d_fl < 1) keep <- setdiff(keep, nm)
      }
      if (length(keep) == 0) keep <- "D2"
      survivors <- paste(keep, collapse = ",")
      cat("  OAT survivors:", survivors, "\n")
    }
  }

  weak <- cat_rec %>% filter(error_type %in% c("cross_participant_spike",
              "adjacent_swap_time_awake_am_time_getup_am", "ampm_swap"))
  w <- setNames(rep(NA_real_, 3), c("cross_participant_spike", "adjacent_swap_awake_getup", "ampm_swap"))
  for (i in seq_len(nrow(weak))) {
    nm <- weak$error_type[i]
    if (nm == "adjacent_swap_time_awake_am_time_getup_am") nm <- "adjacent_swap_awake_getup"
    w[nm] <- weak$rec[i]
  }
  data.frame(
    seed = seed,
    pooled_recall = recall,
    n_injected = nrow(err),
    ctrl_far_flag = sum(flagged[d$row_id %in% ctrl$row_id]) / nrow(ctrl),
    cross_participant_spike = w["cross_participant_spike"],
    adjacent_swap_awake_getup = w["adjacent_swap_awake_getup"],
    ampm_swap = w["ampm_swap"],
    oat_survivors = survivors,
    stringsAsFactors = FALSE
  )
}

res <- lapply(SEEDS, function(s) run_seed(s, run_oat = s %in% OAT_SEEDS))
out <- do.call(rbind, res)
cat("\n=== Multi-seed sensitivity ===\n")
print(out, row.names = FALSE)

write.csv(out, file.path(RES, "seed_sensitivity.csv"), row.names = FALSE)
cat("\nWrote seed_sensitivity.csv\n")
cat("\n=== [seed_sensitivity] Finished ===\n")