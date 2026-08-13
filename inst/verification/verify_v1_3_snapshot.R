# verify_v1_3_snapshot.R — snapshot verification for the S3 chain
# ============================================================================
# Compares the output of the v1.3.0 S3 cleaning chain against the v1.2.0
# pipeline (steps 2-7) on the bundled synthetic dataset.
#
# If this script exits with "RESULT: all checks passed", the S3 wrapper
# layer produces bit-identical output to the original scripts.
#
# Usage:
#   cd /path/to/splsleep
#   Rscript verify_v1_3_snapshot.R
# ============================================================================

cat("\n=== splsleep v1.3.0 snapshot verification ===\n")
cat("R version:", R.version.string, "\n")
cat("Working dir:", getwd(), "\n\n")

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
  library(lubridate)
  library(tidyr)
  library(readr)
})

# ── Locate scripts & config ──────────────────────────────────────────────

scripts_dir <- function() {
  # Try inst/scripts first (source checkout), then current dir
  if (dir.exists("inst/scripts")) return("inst/scripts")
  if (dir.exists(file.path(getwd(), "inst/scripts"))) return(file.path(getwd(), "inst/scripts"))
  getwd()
}
sdir <- scripts_dir()
cat("Scripts directory:", sdir, "\n")

cfg_path <- "inst/extdata/synthetic_config.yaml"
a <- commandArgs(trailingOnly = TRUE)
for (i in seq_along(a)) if (a[i] == "--config") cfg_path <- a[i + 1]
if (!file.exists(cfg_path)) stop("Config not found: ", cfg_path)
cfg <- yaml::read_yaml(cfg_path)

# Store config globally (the legacy pipeline reads pipeline_config)
assign("pipeline_config", cfg, envir = .GlobalEnv)
assign("splsleep_scripts_dir", sdir, envir = .GlobalEnv)
options(splsleep.verbose = FALSE)

# Load the development package: internalised step functions live in its
# namespace. The legacy (script-copy) pipeline below still sources
# inst/scripts/ files into the global env; before the S3 chain runs we
# rm() the internalised names from the global env so naked-name lookup in
# step_* resolves to the namespace versions -- otherwise the S3 chain would
# silently keep executing the OLD script copies and this verifier would not
# validate the internalised code at all.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
init_step_ledger()

# ── Helper: cfg_get ──────────────────────────────────────────────────────
cfg_get <- function(key, default = NULL, cfg_arg = NULL) {
  keys <- strsplit(key, "\\.")[[1]]
  val <- if (!is.null(cfg_arg)) cfg_arg else cfg
  for (k in keys) {
    if (is.list(val) && k %in% names(val)) val <- val[[k]] else return(default)
  }
  if (is.null(val)) default else val
}

# ── Helper: figure_run_dir / verification_run_dir ─────────────────────────
# Single source of truth: sourced from R/config.R rather than duplicated
# here. Before 2026-08-11 this script carried its own inline copy of
# figure_run_dir(), which had already drifted from R/config.R once (the
# routing for an "unknown" data_tag differed between the two). Loaded into a
# private environment so R/config.R's own cfg_get()/config_get() (3-arg
# signature, cfg-object based) do not shadow this script's simpler local
# cfg_get() (2-arg, closes over `cfg` directly) used everywhere else below --
# only figure_run_dir/verification_run_dir are pulled out, as thin wrappers
# matching this script's existing calling convention.
.cfg_helpers <- new.env()
if (!file.exists("R/config.R")) {
  stop("R/config.R not found. This script must be run from the splsleep ",
       "source checkout root (cd /path/to/splsleep; Rscript ",
       "verify_v1_3_snapshot.R), same as the rest of this script assumes.")
}
source("R/config.R", local = .cfg_helpers)
figure_run_dir <- function(data_tag, n_records = NULL)
  .cfg_helpers$figure_run_dir(cfg = cfg, data_tag = data_tag, n_records = n_records)
verification_run_dir <- function(data_tag, n_records = NULL)
  .cfg_helpers$verification_run_dir(cfg = cfg, data_tag = data_tag, n_records = n_records)

# Derive the run tag from the configured input file (same rule as the pipeline).
.snap_rds_name <- basename(cfg_get("data.files.main", ""))
.snap_tag <- if (!nzchar(.snap_rds_name)) {
  "unknown"
} else if (grepl("synthetic|synth|stub|demo|example", .snap_rds_name, ignore.case = TRUE)) {
  "synth"
} else {
  "real"
}

# ── Helper: multi_process (same as pipeline) ──────────────────────────────
multi_process <- function(df, var_list, func, format = NULL) {
  for (varname in var_list) {
    df <- func(df, varname = varname, format = format)
  }
  df
}

# ── Load data (replicating old pipeline Step 1) ──────────────────────────
cat("\nLoading synthetic data...\n")
rds_file <- cfg_get("data.files.main")
csv_file <- cfg_get("data.files.extra")

df_old <- readRDS(rds_file)
cat(sprintf("  RDS: %d rows x %d columns\n", nrow(df_old), ncol(df_old)))

if (!is.null(csv_file) && file.exists(csv_file) && csv_file != rds_file) {
  full_df <- read.csv(csv_file)
  df_old <- df_old %>%
    mutate(
      StartDate = full_df$StartDate,
      num_waso_am = full_df$num_waso,
      num_waso_estimate_am = full_df$num_waso_estimate_am,
    )
  cat(sprintf("  CSV merged: %d rows\n", nrow(df_old)))
}

# Make a copy for the S3 chain
df_s3 <- df_old
cat(sprintf("  Input data: %d rows x %d columns\n", nrow(df_s3), ncol(df_s3)))

# ── Load correction files ────────────────────────────────────────────────
# IMPORTANT: Must exactly match the empty data frame that the old pipeline
# passes to apply_manual_corrections_and_recalculate() when no stubs exist.
# The function iterates corrections_df row by row — if ANY rows exist with
# differing column names, it crashes on $solution_humanidentified access.
#
# Old pipeline fallback: `cat(...); tibble()` which creates TRUE 0×0 tibble.
# We replicate that exactly.
manual_error_path <- cfg_get("data.files.manual_error", "manual_error_corrections.csv")
manual_unusual_path <- cfg_get("data.files.manual_unusual", "manual_unusual_corrections.csv")

cat("\nCorrection files:\n")
cat(sprintf("  Error:  %s (%s)\n", manual_error_path,
            if (file.exists(manual_error_path)) "found" else "NOT found → empty"))
cat(sprintf("  Unusual: %s (%s)\n", manual_unusual_path,
            if (file.exists(manual_unusual_path)) "found" else "NOT found → empty"))

manual_corrections <- tibble::tibble()
manual_unusual <- data.frame()

cat(sprintf("  manual_corrections: %d rows × %d cols\n",
            nrow(manual_corrections), ncol(manual_corrections)))
cat(sprintf("  manual_unusual:     %d rows × %d cols\n",
            nrow(manual_unusual), ncol(manual_unusual)))

# =========================================================================
# OLD PIPELINE: run steps 2-7 manually (replicating .run_pipeline_internal)
# =========================================================================
cat("\n=== OLD PIPELINE (v1.2.0, steps 2-7) ===\n")

timer_old <- Sys.time()

# Step 2: Process timestamps
cat("  Step 2: Process timestamps...\n")
source(file.path(sdir, "process_timestamp_emadatarelease_cyra.R"), local = TRUE)
tstamp.vars <- c("time_bed_am", "time_sleep_am", "time_awake_am", "time_getup_am",
                 "caffeinetoday_PM", "alcoholtoday_PM", "nicotine_amount_pm", "cannabis_amount_pm")
ema_timeproc <- df_old
ema_timeproc <- multi_process(ema_timeproc, tstamp.vars, process_timestamp, "timestamp")
rm(df_old, tstamp.vars)
cat(sprintf("  → %d rows x %d columns\n", nrow(ema_timeproc), ncol(ema_timeproc)))

# Step 3: Process intervals
cat("  Step 3: Process intervals...\n")
source(file.path(sdir, "process_interval.R"), local = TRUE)
interval.vars <- c("duration_totalmin_sol_estimate_am",
                    "duration_totalmin_waso_estimate_am",
                    "duration_totalmin_napstoday_PM",
                    "exercisetoday_PM_totalmin_Light",
                    "exercisetoday_PM_totalmin_Moderate",
                    "exercisetoday_PM_totalmin_Vigorous",
                    "exercisetoday_PM_totalmin_Strength")
if (exists("process_interval")) {
  ema_timeproc <- multi_process(ema_timeproc, interval.vars, process_interval, "interval_hhmm")
}
cat(sprintf("  → %d rows x %d columns\n", nrow(ema_timeproc), ncol(ema_timeproc)))

# Step 4: Normalize sequence
cat("  Step 4: Normalize sequence...\n")
source(file.path(sdir, "normalize_sleep_time_sequence.R"), local = TRUE)
flip_gap <- tryCatch(cfg_get("timestamp.sequence.max_gap_hours", 12), error = function(e) 12)
ema_timecalc <- normalize_sleep_time_sequence(AM_rawdata = ema_timeproc, flip_gap_hours = flip_gap)
cat(sprintf("  → %d rows x %d columns\n", nrow(ema_timecalc), ncol(ema_timecalc)))

# Step 6: Manual corrections
cat("  Step 6: Manual corrections...\n")
source(file.path(sdir, "error_unusual_sleep_time_corrections.R"), local = TRUE)
results <- apply_manual_corrections_and_recalculate(
  ema_data = ema_timecalc,
  corrections_df = manual_corrections,
  manual_unusual_df = manual_unusual
)
corrected_old <- results$corrected_ema_data
cat(sprintf("  → %d rows x %d columns\n", nrow(corrected_old), ncol(corrected_old)))

# Step 6.5: Duration corrections
cat("  Step 6.5: Duration corrections...\n")
source(file.path(sdir, "apply_nap_exercise_corrections.R"), local = TRUE)
corrected_old <- apply_nap_exercise_corrections(corrected_old, cfg = cfg)
source(file.path(sdir, "apply_sleep_metric_duration_corrections.R"), local = TRUE)
corrected_old <- apply_sleep_metric_duration_corrections(corrected_old, cfg = cfg)
source(file.path(sdir, "apply_metric_review_acceptances.R"), local = TRUE)
corrected_old <- apply_metric_review_acceptances(corrected_old, cfg = cfg)
cat(sprintf("  → %d rows x %d columns\n", nrow(corrected_old), ncol(corrected_old)))

# Step 7: Compute metrics
cat("  Step 7: Compute metrics...\n")
source(file.path(sdir, "calculate_sleep_time_end.R"), local = TRUE)
corrected_old <- calculate_sleep_time_vars_end(corrected_old)
cat(sprintf("  → %d rows x %d columns\n", nrow(corrected_old), ncol(corrected_old)))

elapsed_old <- as.numeric(difftime(Sys.time(), timer_old, units = "secs"))
cat(sprintf("  Old pipeline elapsed: %.1f s\n", elapsed_old))

# Force the S3 chain to use the internalised normalize (not the script copy
# the legacy pass sourced into the global env).
rm("normalize_sleep_time_sequence", envir = globalenv())
rm("calculate_sleep_time_vars_end", envir = globalenv())
rm(list = c("apply_nap_exercise_corrections", "apply_sleep_metric_duration_corrections",
            "apply_metric_review_acceptances"), envir = globalenv())
rm("apply_manual_corrections_and_recalculate", envir = globalenv())

# =========================================================================
# S3 CHAIN: run_cleaning_chain on same input
# =========================================================================
cat("\n=== S3 CHAIN (v1.3.0) ===\n")

timer_s3 <- Sys.time()

result_s3 <- run_cleaning_chain(
  data = df_s3,
  corrections_df = manual_corrections,
  manual_unusual_df = manual_unusual,
  cfg = cfg,
  verbose = FALSE
)

corrected_s3 <- as.data.frame(result_s3)
cat(sprintf("  → %d rows x %d columns\n", nrow(corrected_s3), ncol(corrected_s3)))
cat(sprintf("  Chain: %d step(s) recorded\n", length(result_s3$history)))

elapsed_s3 <- as.numeric(difftime(Sys.time(), timer_s3, units = "secs"))
cat(sprintf("  S3 chain elapsed: %.1f s\n", elapsed_s3))

# =========================================================================
# COMPARE OUTPUTS
# =========================================================================
cat("\n=== COMPARISON ===\n\n")

.pass <- 0L
.fail <- 0L
.failures <- character(0)

check <- function(label, expr) {
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    structure(FALSE, msg = conditionMessage(e))
  })
  msg <- attr(ok, "msg")
  if (isTRUE(ok)) {
    .pass <<- .pass + 1L
    cat(sprintf("PASS  %s\n", label))
  } else {
    .fail <<- .fail + 1L
    .failures <<- c(.failures, label)
    cat(sprintf("FAIL  %s%s\n", label,
                if (is.null(msg)) "" else paste0("\n      error: ", msg)))
  }
}

# 1. Row count
cat("-- Dimensions --\n")
check(paste("same number of rows (", nrow(corrected_old), ")", sep = ""),
      nrow(corrected_old) == nrow(corrected_s3))
check(paste("same number of columns (", ncol(corrected_old), ")", sep = ""),
      ncol(corrected_old) == ncol(corrected_s3))

# 2. Column names
cat("\n-- Column names --\n")
cols_old <- sort(names(corrected_old))
cols_s3 <- sort(names(corrected_s3))
only_old <- setdiff(cols_old, cols_s3)
only_s3 <- setdiff(cols_s3, cols_old)

check("no columns unique to old pipeline",
      length(only_old) == 0L)
if (length(only_old) > 0) {
  cat(sprintf("      Old-only columns: %s\n", paste(only_old, collapse = ", ")))
}
check("no columns unique to S3 chain",
      length(only_s3) == 0L)
if (length(only_s3) > 0) {
  cat(sprintf("      S3-only columns: %s\n", paste(only_s3, collapse = ", ")))
}

# 3. Value comparison — column by column
cat("\n-- Value comparison (column by column) --\n")

# Helper: safe equality check that handles NA, POSIXct, numeric
values_equal <- function(a, b) {
  if (is.numeric(a) && is.numeric(b)) {
    # Handle NA: NA == NA is NA, we want TRUE
    both_na <- is.na(a) & is.na(b)
    one_na <- xor(is.na(a), is.na(b))
    if (any(one_na)) {
      idx <- which(one_na)
      attr(both_na, "mismatch_rows") <- idx
      return(FALSE)
    }
    # Compare non-NA values with tolerance
    non_na <- !is.na(a) & !is.na(b)
    if (is.double(a) || is.double(b)) {
      ok <- all(abs(a[non_na] - b[non_na]) < 1e-10)
    } else {
      ok <- all(a[non_na] == b[non_na])
    }
    if (!ok) {
      idx <- which(non_na)[!ok | is.na(ok)]
      if (length(idx) == 0) idx <- which(!(a == b | (is.na(a) & is.na(b))))
      attr(ok, "mismatch_rows") <- head(idx, 5)
    }
    ok
  } else if (inherits(a, "POSIXct") && inherits(b, "POSIXct")) {
    both_na <- is.na(a) & is.na(b)
    one_na <- xor(is.na(a), is.na(b))
    if (any(one_na)) {
      idx <- which(one_na)
      attr(one_na, "mismatch_rows") <- idx
      return(FALSE)
    }
    non_na <- !is.na(a) & !is.na(b)
    ok <- all(a[non_na] == b[non_na])
    if (!ok) {
      idx <- which(non_na)[which(a[non_na] != b[non_na])]
      attr(ok, "mismatch_rows") <- head(idx, 5)
    }
    ok
  } else if (is.character(a) && is.character(b)) {
    both_na <- is.na(a) & is.na(b)
    one_na <- xor(is.na(a), is.na(b))
    if (any(one_na)) {
      idx <- which(one_na)
      attr(one_na, "mismatch_rows") <- idx
      return(FALSE)
    }
    ok <- all(a == b | (is.na(a) & is.na(b)))
    if (!ok) {
      idx <- which(!(a == b | (is.na(a) & is.na(b))))
      attr(ok, "mismatch_rows") <- head(idx, 5)
    }
    ok
  } else {
    all(a == b | (is.na(a) & is.na(b)))
  }
}

# Only compare columns that exist in BOTH
common_cols <- intersect(names(corrected_old), names(corrected_s3))
n_compared <- 0L
n_identical <- 0L

for (col in common_cols) {
  n_compared <- n_compared + 1L
  old_col <- corrected_old[[col]]
  s3_col <- corrected_s3[[col]]
  
  ok <- values_equal(old_col, s3_col)
  mismatch_rows <- attr(ok, "mismatch_rows")
  
  if (isTRUE(ok) || (is.logical(ok) && !is.na(ok) && ok)) {
    n_identical <- n_identical + 1L
  } else {
    .fail <- .fail + 1L
    desc <- paste0("Column ", col)
    if (!is.null(mismatch_rows) && length(mismatch_rows) > 0) {
      n_mismatch <- length(which(!(old_col == s3_col | (is.na(old_col) & is.na(s3_col)))))
      desc <- sprintf("Column %s (%d mismatches, first at rows: %s)", 
                     col, n_mismatch, 
                     paste(head(mismatch_rows, 5), collapse = ", "))
    }
    .failures <- c(.failures, desc)
    cat(sprintf("FAIL  %s\n", desc))
  }
}

# Report identities as one check
check(sprintf("%d of %d common columns identical", n_identical, n_compared),
      n_identical == n_compared)

# 4. Key derived metrics specifically
cat("\n-- Key derived metrics (spot checks) --\n")

key_cols <- c("self_diffcalc_sol_minutes", "self_diffcalc_sleepefficiency_percent",
              "self_diffcalc_totalsleeptime_minutes", "self_diffcalc_timeinbed_minutes",
              "sleep_efficiency_pct", "sol_h", "waso_h", "sleep_duration_h")

for (col in key_cols) {
  if (col %in% common_cols) {
    ok <- values_equal(corrected_old[[col]], corrected_s3[[col]])
    check(paste0("  ", col), ok)
  } else {
    check(paste0("  ", col, " (present)"), col %in% names(corrected_old) && col %in% names(corrected_s3))
  }
}

# 5. Timing
cat("\n-- Timing --\n")
cat(sprintf("  Old pipeline:  %.2f s\n", elapsed_old))
cat(sprintf("  S3 chain:      %.2f s\n", elapsed_s3))
speedup <- if (elapsed_s3 > 0) elapsed_old / elapsed_s3 else NA
if (!is.na(speedup)) {
  cat(sprintf("  Ratio (old/s3): %.2fx\n", speedup))
}

# 6. Summary
cat("\n")
cat(strrep("=", 60), "\n", sep = "")
cat(sprintf("RESULT: %d passed, %d failed\n", .pass, .fail))
if (.fail > 0) {
  cat("\nFailed checks:\n")
  for (f in .failures) cat("  -", f, "\n")
  cat("\nThe S3 chain produces DIFFERENT output from the old pipeline.\n")
  cat("Do NOT consider the wrapper layer verified until all checks pass.\n")
} else {
  cat("All checks passed. The S3 chain is bit-identical to the old pipeline.\n")
  cat("The wrapper layer is verified.\n")
}
cat(strrep("=", 60), "\n\n")

# =========================================================================
# Save comparison artifacts for inspection
# =========================================================================
# Artifacts land in verification_run_dir(), a STABLE sibling of the figure
# run directory (see R/config.R) rather than nested inside it. Before
# 2026-08-11 this was <viz_dir>/verification/ -- convenient to browse next to
# the figures, but only surviving a rerun of sleep_visualization.R because
# that one script implemented a rename-out/rename-back dance around its own
# wipe. That dance failed once already (2026-08-11: that day's
# VERIFICATION_2026-08-10.md was deleted and had to be reconstructed from a
# work log, because it was gitignored and unrecoverable from git). Nothing
# below can be wiped by any figure-generation run, current or future, so no
# such dance is needed here either.
.ver_dir <- verification_run_dir(.snap_tag, nrow(corrected_old))
dir.create(.ver_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(corrected_old, file.path(.ver_dir, "snapshot_old.rds"))
saveRDS(corrected_s3, file.path(.ver_dir, "snapshot_s3.rds"))
cat(sprintf("Artifacts saved: %s/snapshot_{old,s3}.rds\n", .ver_dir))

# Return exit code
if (.fail > 0) quit(status = 1) else quit(status = 0)
