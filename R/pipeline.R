scripts_dir <- function() {
  pkg_dir <- system.file("scripts", package = "splsleep")
  if (nchar(pkg_dir) > 0 && dir.exists(pkg_dir)) return(pkg_dir)
  getwd()
}

# Declare variables placed in .GlobalEnv by run_pipeline() for backward
# compatibility with the legacy source()-based steps 8 and 9.
utils::globalVariables(c(
  "corrected_ema_data", "ema_data_release_timecalc",
  "review_output", "checkforerrors_summary",
  "pipeline_config", "splsleep_scripts_dir"
))

# -- Internal helpers (used only by run_pipeline / run_setup / run_visualization) --

# Resolve data.files.main / data.files.extra, falling back to legacy
# main_rds / main_csv keys for backward compatibility.
.resolve_data_key <- function(cfg, key) {
  val <- cfg_get(key, NULL, cfg = cfg)
  if (!is.null(val) && nchar(val) > 0) return(val)

  legacy <- switch(key,
    "data.files.main"  = cfg_get("data.files.main_rds",  NULL, cfg = cfg),
    "data.files.extra" = cfg_get("data.files.main_csv", NULL, cfg = cfg)
  )
  if (!is.null(legacy) && nchar(legacy) > 0) return(legacy)
  NULL
}

.pipeline_init <- function(config, project_dir, verbose) {
  old_wd <- setwd(project_dir)
  sdir   <- scripts_dir()
  assign("splsleep_scripts_dir", sdir, envir = .GlobalEnv)

  if (is.character(config) || is.null(config)) {
    cfg <- load_config(config)
  } else if (is.list(config)) {
    cfg <- config
  } else {
    stop("config must be a file path, list, or NULL")
  }

  # Keep .GlobalEnv assignment for backward compatibility with source() steps
  assign("pipeline_config", cfg, envir = .GlobalEnv)
  assign("splsleep_loaded", TRUE, envir = .GlobalEnv)

  if (verbose) cat(sprintf("\n=== SPL Sleep Pipeline (%s) ===\n",
    if (is.null(cfg$pipeline$name)) "splsleep" else cfg$pipeline$name))
  options(splsleep.verbose = verbose)

  list(cfg = cfg, sdir = sdir, old_wd = old_wd)
}

.pipeline_cleanup <- function(old_wd) {
  options(splsleep.verbose = NULL)
  setwd(old_wd)
}

#' Run the full SPL Sleep pipeline
#'
#' Executes the complete sleep EMA data cleaning pipeline.
#' Steps 2--7 now flow through the S3 chain (v1.3.1), giving every step
#' automatic provenance tracking, contract assertions, and a 2.6x speed-up.
#' Steps that write files or read human-reviewed CSVs remain as direct
#' \code{source()} calls for backward compatibility.
#'
#' @param config Character or list. Path to a YAML config file, or a config
#'   list (from \code{load_config()}). If NULL, uses the bundled default.
#' @param project_dir Character. Path to the project root. Default ".".
#' @param skip_visualization Logical. If TRUE, skip visualization.
#' @param finalize Logical. If TRUE (default) run \code{finalize_columns()} as
#'   Step 10 and write the delivered datasets. Set FALSE to stop after the
#'   cleaning run and inspect \code{corrected_ema_data} yourself. Before v1.4
#'   this step had to be invoked by hand, which meant a plain
#'   \code{run_pipeline()} produced no Dataset A or B at all.
#' @param verbose Logical. Print progress. Default TRUE.
#'
#' @return Invisibly returns TRUE on successful completion.
#' @export
run_pipeline <- function(config = NULL, project_dir = ".", skip_visualization = FALSE,
                         finalize = TRUE, verbose = TRUE) {
  env <- .pipeline_init(config, project_dir, verbose)
  on.exit(.pipeline_cleanup(env$old_wd), add = TRUE)
  cfg  <- env$cfg
  sdir <- env$sdir

  init_step_ledger()
  source(file.path(sdir, "report_correction_status.R"), local = TRUE)

  # -- Step 1: Load data ------------------------------------------------
  if (verbose) cat("\n=== Step 1: Loading data ===\n")
  main_file <- .resolve_data_key(cfg, "data.files.main")
  extra_file <- .resolve_data_key(cfg, "data.files.extra")

  if (is.null(main_file) || nchar(main_file) == 0) {
    stop("No data file configured. Set 'data.files.main' in your config YAML.")
  }
  if (!file.exists(main_file)) {
    stop(sprintf(
      "\n  Cannot find your data file:\n    %s\n\n  Options:\n    1. Place your file at the path above, or\n    2. Edit your config YAML and change 'data.files.main' to point to your file\n\n  Accepted formats: .rds (R data) or .csv (plain text)\n  Required columns: see SCHEMA.md\n",
      main_file
    ))
  }

  is_csv <- grepl("\\.csv$", main_file, ignore.case = TRUE)
  if (verbose) cat(sprintf("  Reading %s: %s\n", if (is_csv) "CSV" else "RDS", basename(main_file)))
  if (is_csv) {
    df <- utils::read.csv(main_file, stringsAsFactors = FALSE)
  } else {
    df <- readRDS(main_file)
  }

  # Optional supplementary file (extra columns: StartDate, WASO counts)
  if (!is.null(extra_file) && nchar(extra_file) > 0 && file.exists(extra_file)) {
    if (verbose) cat(sprintf("  Reading extra: %s\n", basename(extra_file)))
    extra_df <- utils::read.csv(extra_file, stringsAsFactors = FALSE)
    if (nrow(extra_df) != nrow(df)) {
      stop(sprintf(
        "Row mismatch: extra file %s has %d rows, main data has %d. They must match 1:1 by row position.",
        basename(extra_file), nrow(extra_df), nrow(df)
      ))
    }
    if ("StartDate" %in% names(extra_df)) df$StartDate <- extra_df$StartDate
    if ("num_waso" %in% names(extra_df)) df$num_waso_am <- extra_df$num_waso
    if ("num_waso_estimate_am" %in% names(extra_df)) df$num_waso_estimate_am <- extra_df$num_waso_estimate_am
    rm(extra_df); if (verbose) gc()
  } else {
    if (verbose) cat("  No extra file -- assuming main data contains all columns\n")
  }

  if (!"StartDate" %in% names(df) && verbose) {
    message("Note: No StartDate column. Figures relying on dates will be limited.")
  }
  if (!"num_waso_estimate_am" %in% names(df) && verbose) {
    message("Note: No num_waso_estimate_am column. Average WASO bout metrics will be skipped.")
  }

  validate_schema(df, cfg, label = "Step 1 output")
  log_step(df, "1", "Load data", cfg)

  # Column adaptation -- only when the raw data uses different names than
  # the pipeline expects.  Skip if the expected columns already exist, to
  # avoid renaming already-correct names (matching the behaviour of the
  # legacy pipeline where adapt_columns never fired on first load).
  if (!is.null(cfg$column_mapping) && !is.null(config)) {
    expected <- c("time_bed_am_hhmm", "time_bed_am_ampm")
    if (!all(expected %in% names(df))) {
      df <- adapt_columns(df, cfg)
      if (verbose) cat(sprintf("Columns adapted (%d columns renamed)\n",
        sum(!expected %in% names(df))))
    }
  }

  # -- Step 1.5: Field-misentry check -----------------------------------
  .pipeline_cfg <- cfg
  source(file.path(sdir, "cross_participant_field_misentry_check.R"), local = TRUE)
  log_step(df, "1.5", "Field-misentry check", cfg)

  # -- Steps 2--4: S3 chain (timestamps -> intervals -> normalize) --------
  ema <- new_sleep_diary(df, step_id = "1.5", step_label = "Field-misentry check", cfg = cfg)

  if (verbose) cat("\n=== Steps 2--4: Parsing & normalization (S3 chain) ===\n")
  ema <- step_process_timestamps(ema)
  ema <- step_process_intervals(ema)
  ema <- step_normalize_sequence(ema)

  # Expose the normalized data for downstream steps (visualization uses this)
  ema_data_release_timecalc <- as.data.frame(ema)
  assign("ema_data_release_timecalc", ema_data_release_timecalc, envir = .GlobalEnv)

  checkpoint_A <- report_status(ema_data_release_timecalc, "After Step 4 (auto-normalize)", "A")

  # -- Step 5: Classify & generate review CSVs -------------------------
  if (verbose) cat("\n=== Step 5: Generating correction files ===\n")
  source(file.path(sdir, "generate_correction_files.R"), local = TRUE)
  suppressMessages(generated_files <- generate_correction_files(ema_data_release_timecalc))
  log_step(ema_data_release_timecalc, "5", "Classify records", cfg)

  manual_error_path   <- cfg_get("data.files.manual_error",   "manual_error_corrections.csv", cfg = cfg)
  manual_unusual_path <- cfg_get("data.files.manual_unusual", "manual_unusual_corrections.csv", cfg = cfg)
  manual_corrections <- if (file.exists(manual_error_path)) {
    # Kept as readr::read_csv rather than utils::read.csv: this file feeds the
    # Step 6 manual corrections, and readr's column-type inference differs from
    # read.csv's. Changing the parser here would change cleaning results.
    suppressMessages(readr::read_csv(manual_error_path, show_col_types = FALSE))
  } else {
    if (verbose) cat(sprintf("  [WARN] %s not found -- using empty corrections\n", manual_error_path))
    data.frame()
  }
  manual_unusual <- if (file.exists(manual_unusual_path)) {
    utils::read.csv(manual_unusual_path, fileEncoding = "UTF-8-BOM")
  } else {
    if (verbose) cat(sprintf("  [WARN] %s not found -- using empty unusual\n", manual_unusual_path))
    data.frame()
  }
  names(manual_unusual) <- gsub("^X\\.\\.\\.|^X\\.|^\\.", "", names(manual_unusual))
  rm(generated_files, generate_correction_files); if (verbose) gc()

  # -- Step 5.75: Second-review consensus ------------------------------
  if (verbose) cat("\n=== Step 5.75: Applying second-review consensus ===\n")
  source(file.path(sdir, "apply_second_review.R"), local = TRUE)
  log_step(ema_data_release_timecalc, "5.75", "Second-review consensus", cfg)

  # -- Steps 6--7: S3 chain (corrections -> metrics) ---------------------
  if (verbose) cat("\n=== Steps 6--7: Corrections & metrics (S3 chain) ===\n")
  ema <- new_sleep_diary(ema_data_release_timecalc,
    step_id = "5.75", step_label = "Second-review consensus",
    cfg = cfg, history = c(ema$history, list(ema$step)))
  ema <- step_apply_corrections(ema, manual_corrections, manual_unusual)
  ema <- step_apply_duration_corrections(ema)
  ema <- step_compute_metrics(ema)

  corrected_ema_data <- as.data.frame(ema)
  assign("corrected_ema_data", corrected_ema_data, envir = .GlobalEnv)

  checkpoint_B <- report_status(corrected_ema_data, "After Step 6 (timestamp corrections)", "B", previous = checkpoint_A)
  checkpoint_C <- report_status(corrected_ema_data, "After Step 6.5 (duration corrections)", "C", previous = checkpoint_B)
  checkpoint_D <- report_status(corrected_ema_data, "After Step 7 (metrics computed)", "D", previous = checkpoint_C)

  # -- Step 8: Auto-detection ------------------------------------------
  if (verbose) cat("\n=== Step 8: Running auto error detection ===\n")
  source(file.path(sdir, "checkforerrors_processing.R"), local = TRUE)
  assign("review_output", review_output, envir = .GlobalEnv)
  assign("checkforerrors_summary", checkforerrors_summary, envir = .GlobalEnv)

  rs <- checkforerrors_summary$review_summary
  flag_extra <- list(
    TIMESTAMP_ISSUE    = sum(rs$raw_category == "TIMESTAMP_ISSUE",    na.rm = TRUE),
    DURATION_ISSUE     = sum(rs$raw_category == "DURATION_ISSUE",     na.rm = TRUE),
    AMOUNT_FLAG        = sum(rs$raw_category == "AMOUNT_FLAG",        na.rm = TRUE),
    SELF_REPORTED_FLAG = sum(rs$raw_category == "SELF_REPORTED_FLAG", na.rm = TRUE)
  )
  checkpoint_E <- report_status(corrected_ema_data, "After Step 8 (auto-detection)", "E",
                                 previous = checkpoint_D, extra = flag_extra)

  if (sum(rs$raw_category == "SELF_REPORTED_FLAG", na.rm = TRUE) > 0) {
    needs_idx <- which(rs$raw_category == "SELF_REPORTED_FLAG")
    ndf        <- review_output$data_with_flags[needs_idx, ]
    cols <- intersect(c("pid", "day_num", "self_diffcalc_sol_minutes",
      "self_diffcalc_sleepefficiency_percent", "sol_category",
      "se_category", "tst_tib_ratio_category", "auto_error_desc"), names(ndf))
    utils::write.csv(ndf[, cols, drop = FALSE], "output/flagged_records_self_reported.csv", row.names = FALSE)
    if (verbose) cat(sprintf("  Exported %d SELF-REPORTED FLAG records\n", nrow(ndf)))
  }
  log_step(corrected_ema_data, "8", "Auto-detect", cfg)

  # -- Step 8.5: Cross-participant check -------------------------------
  if (verbose) cat("\n=== Step 8.5: Cross-participant global consistency check ===\n")
  source(file.path(sdir, "cross_participant_global_check.R"), local = TRUE)
  assign("review_output", review_output, envir = .GlobalEnv)
  log_step(corrected_ema_data, "8.5", "Cross-participant check", cfg)

  # -- Step 9: Visualization -------------------------------------------
  if (!skip_visualization) {
    if (verbose) cat("\n=== Step 9: Generating visualizations ===\n")
    source(file.path(sdir, "sleep_visualization.R"), local = TRUE)
  }

  write_step_ledger("output/step_flag_ledger.csv")

  if (file.exists(file.path(sdir, "audit_data_integrity.R"))) {
    source(file.path(sdir, "audit_data_integrity.R"), local = TRUE)
  }

  final_summary(list(A = checkpoint_A, B = checkpoint_B, C = checkpoint_C, D = checkpoint_D, E = checkpoint_E))

  # -- Step 10: Build the delivered datasets ----------------------------
  # Deliberately last, and deliberately after final_summary(): this step only
  # selects and renames columns, so if it fails the cleaning run and all its
  # reported numbers are still intact on disk and in corrected_ema_data.
  if (finalize) {
    if (verbose) cat("\n=== Step 10: Building delivered datasets ===\n")
    rv <- if (exists("review_output", inherits = TRUE) &&
              is.list(review_output) &&
              !is.null(review_output$data_with_flags)) {
      review_output$data_with_flags
    } else NULL

    # Hard fail, not a warning. The delivered datasets are the point of the
    # run: the cleaning output is preserved in corrected_ema_data.rds, so if
    # the dictionary drifts out of sync the correct fix is to stop the run
    # so CI and anyone else notices, then repair the dictionary -- not to walk
    # away with a green exit code and no delivered files.
    finalize_columns(corrected_ema_data, review_data = rv, verbose = verbose)
  }

  if (verbose) cat("\n[OK] Pipeline complete!\n")
  invisible(TRUE)
}

# -- Sub-pipeline entry points (unchanged behaviour) -------------------------

#' Run the setup-only stage (package / input-file checks)
#'
#' Checks R packages and input files without loading or cleaning data.
#'
#' @param config Character or list. Path to a config YAML, a configuration
#'   list (from \code{load_config()}), or NULL for the bundled default.
#' @param project_dir Character. Path to the project root. Default ".".
#' @return Invisibly TRUE.
#' @export
run_setup <- function(config = NULL, project_dir = ".") {
  env  <- .pipeline_init(config, project_dir, verbose = TRUE)
  on.exit(.pipeline_cleanup(env$old_wd), add = TRUE)
  # NOTE: 00a_setup.R only checks R packages / input files -- no data loaded.
  source(file.path(env$sdir, "00a_setup.R"), local = TRUE)
  cat("Setup complete. Data loaded successfully.\n")
  invisible(TRUE)
}

#' Run only the visualization stage on already-cleaned data
#'
#' Loads config + inputs and regenerates the diagnostic figures.
#'
#' @param config Character or list. Path to a config YAML, a configuration
#'   list (from \code{load_config()}), or NULL for the bundled default.
#' @param project_dir Character. Path to the project root. Default ".".
#' @return Invisibly TRUE.
#' @export
run_visualization <- function(config = NULL, project_dir = ".") {
  env  <- .pipeline_init(config, project_dir, verbose = TRUE)
  on.exit(.pipeline_cleanup(env$old_wd), add = TRUE)
  .pipeline_cfg <- env$cfg
  source(file.path(env$sdir, "sleep_visualization.R"), local = TRUE)
  invisible(TRUE)
}

#' Run the reporting stage
#'
#' @param config Character or list. Path to a config YAML, a configuration
#'   list (from \code{load_config()}), or NULL for the bundled default.
#' @param project_dir Character. Path to the project root. Default ".".
#' @return Invisibly TRUE.
#' @export
run_report <- function(config = NULL, project_dir = ".") {
  env  <- .pipeline_init(config, project_dir, verbose = TRUE)
  on.exit(.pipeline_cleanup(env$old_wd), add = TRUE)
  source(file.path(env$sdir, "report_correction_status.R"), local = TRUE)
  invisible(TRUE)
}

#' Regenerate the figure_index.png contact sheet
#'
#' @param viz_dir Character. Path to the figure run directory. Default
#'   \code{"latest_visualization"}.
#' @return Invisibly TRUE.
#' @export
run_figure_index <- function(viz_dir = "latest_visualization") {
  # generate_figure_index is defined in inst/scripts/make_figure_index.R
  # which is sourced at call time
  source(file.path(scripts_dir(), "make_figure_index.R"), local = TRUE)
  generate_figure_index(viz_dir)
  invisible(TRUE)
}
