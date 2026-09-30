scripts_dir <- function() {
  pkg_dir <- system.file("scripts", package = "sleepcleanr")
  if (nchar(pkg_dir) > 0 && dir.exists(pkg_dir)) return(pkg_dir)
  getwd()
}

# Declare variables placed in .GlobalEnv by run_pipeline() for backward
# compatibility with the legacy source()-based steps 8 and 9.
utils::globalVariables(c(
  "corrected_ema_data", "ema_data_release_timecalc",
  "review_output", "checkforerrors_summary",
  "pipeline_config", "sleepcleanr_scripts_dir",
  # functions sourced from inst/scripts at runtime (report_correction_status.R)
  "report_status", "final_summary", "generate_correction_files", "generate_figure_index"
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
  assign("sleepcleanr_scripts_dir", sdir, envir = .GlobalEnv)

  if (is.character(config) || is.null(config)) {
    cfg <- load_config(config)
  } else if (is.list(config)) {
    cfg <- config
  } else {
    stop("config must be a file path, list, or NULL")
  }

  # Keep .GlobalEnv assignment for backward compatibility with source() steps
  assign("pipeline_config", cfg, envir = .GlobalEnv)
  assign("sleepcleanr_loaded", TRUE, envir = .GlobalEnv)

  if (verbose) cat(sprintf("\n=== SPL Sleep Pipeline (%s) ===\n",
    if (is.null(cfg$pipeline$name)) "sleepcleanr" else cfg$pipeline$name))
  options(sleepcleanr.verbose = verbose)

  list(cfg = cfg, sdir = sdir, old_wd = old_wd)
}

.pipeline_cleanup <- function(old_wd) {
  options(sleepcleanr.verbose = NULL)
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
#' @param data Data frame. Optional data-first entry: supply the raw data
#'   directly instead of reading \code{data.files.main} from the config.
#'   When NULL (default) the pipeline reads from the config exactly as before
#'   (\code{data = NULL} is the backward-compatible zero-change path). When
#'   supplied, the file-reading branch of Step 1 is skipped and the config's
#'   column_mapping is applied to \code{data}. Used by
#'   \code{clean_sleep_diary()}.
#' @param include_manual_corrections Logical or character. Controls whether
#'   HUMAN-REVIEW corrections are applied to the data. \strong{Default FALSE}:
#'   the pipeline runs algorithmic-only -- every human-review file
#'   (manual_error/unusual/nap_exercise/sleep_metric_duration/
#'   metric_review_acceptances/second_review) is treated as absent, Step 5
#'   still generates the [NEW] review worksheets for inspection, and a
#'   prominent banner states that no human corrections were applied. TRUE:
#'   apply the manual-correction files configured in the config YAML
#'   (the pre-2026-09-29 behaviour). The strings "ask" / "y" / "n" / "yes" /
#'   "no" are also accepted: "ask" prompts interactively (in an interactive
#'   session only; in a non-interactive session it degrades to FALSE with a
#'   notice). The point of the default-off switch: a package user must
#'   OPT IN to human corrections so that a dataset can never be silently
#'   modified by review files left over in the working directory.
#'
#' @return Invisibly returns TRUE on successful completion.
#' @export
run_pipeline <- function(config = NULL, project_dir = ".", skip_visualization = FALSE,
                         finalize = TRUE, verbose = TRUE, data = NULL,
                         include_manual_corrections = FALSE) {
  env <- .pipeline_init(config, project_dir, verbose)
  on.exit(.pipeline_cleanup(env$old_wd), add = TRUE)
  cfg  <- env$cfg
  sdir <- env$sdir

  init_step_ledger()
  source(file.path(sdir, "report_correction_status.R"), local = TRUE)

  # -- Step 1: Load data ------------------------------------------------
  if (verbose) cat("\n=== Step 1: Loading data ===\n")
  if (is.null(data)) {
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
  } else {
    # Data-first entry (clean_sleep_diary): caller supplies the data.frame.
    if (!is.data.frame(data)) {
      stop("'data' must be a data.frame (or NULL to read data.files.main from the config).")
    }
    df <- data
    if (verbose) cat(sprintf("  Using provided data.frame (%d rows x %d cols)\n", nrow(df), ncol(df)))
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
  pipeline_config <- cfg
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

  # STRICT PATH MATCHING: manual_error_path / manual_unusual_path are used
  # exactly as configured, with a plain file.exists() check below -- no
  # fuzzy/near-miss filename lookup of any kind. (An earlier version of this
  # code auto-substituted a similarly-named file when the exact one was
  # missing; that was removed on request -- searching for "close enough"
  # filenames is a guess, and a wrong guess here means the pipeline silently
  # runs on the wrong -- or un-reviewed -- corrections file. If the exact
  # path isn't found, fix the path or the filename; nothing here will do
  # that automatically.)
  manual_error_path   <- cfg_get("data.files.manual_error",   "manual_error_corrections.csv", cfg = cfg)
  manual_unusual_path <- cfg_get("data.files.manual_unusual", "manual_unusual_corrections.csv", cfg = cfg)

  # REQUIRE MANUAL CORRECTIONS (2026-09-25): for a study that has completed
  # human review, silently continuing with 0 manual corrections is not a
  # degraded-but-usable result -- it is a wrong result that looks identical
  # to a correct one (right columns, right row count, "[OK] Pipeline
  # complete!", no error). That is exactly the failure mode that let a run
  # without manual_error_corrections.csv / manual_unusual_corrections.csv
  # complete and be mistaken for the fully-corrected dataset. This flag lets
  # a study's own config (e.g. real_data_config.yaml) turn the soft
  # [WARN]-and-continue into a hard stop, WITHOUT changing the default
  # behaviour for every other user of this package -- many legitimately have
  # no manual review yet (first exploratory run, algorithmic-only workflow,
  # the bundled synthetic demo) and must not be broken by this. Default FALSE
  # preserves the original soft-fallback behaviour everywhere this key is
  # absent or explicitly false.
  # ---------------------------------------------------------------------
  # MANUAL-CORRECTIONS GATE (2026-09-29): human-review files are applied
  # ONLY when the caller explicitly opts in. Default FALSE = algorithmic-
  # only run; the [NEW] review worksheets from Step 5 are still generated
  # for inspection, but nothing human-reviewed touches the data. This makes
  # silent correction impossible: the data can only be changed by a
  # human-review file if the caller asked for it by name.
  #
  # Ask-when-missing (2026-09-29, user design): when corrections ARE opted
  # into but a configured review file is absent, the pipeline asks once --
  # "skip the missing files and continue algorithmic-only?" -- instead of
  # either silently continuing or dying without dialogue. In a
  # non-interactive session nobody can answer, so the run stops hard rather
  # than skip silently; data.require_manual_corrections keeps controlling
  # that non-interactive stop.
  .include_val <- if (is.character(include_manual_corrections))
    tolower(trimws(include_manual_corrections)) else include_manual_corrections
  if (.include_val %in% c("y", "yes", "ask")) {
    .include_manual <- TRUE
  } else if (.include_val %in% c("n", "no")) {
    .include_manual <- FALSE
  } else {
    .include_manual <- isTRUE(.include_val)
  }
  if (.include_manual) {
    .missing_manual <- c(
      if (!file.exists(manual_error_path))   manual_error_path,
      if (!file.exists(manual_unusual_path)) manual_unusual_path
    )
    if (length(.missing_manual) > 0 && interactive()) {
      cat(sprintf(paste0(
        "\n*** Manual-correction file(s) configured in your YAML were NOT found:%s",
        "\n    %s%s",
        "\nSkip manual corrections and continue as an ALGORITHMIC-ONLY run?%s",
        "(y = skip and continue / n = stop) : "), "\n",
        paste(.missing_manual, collapse = "\n    "), "\n", "\n"))
      .ans <- tolower(trimws(readline()))
      if (.ans %in% c("y", "yes")) {
        .include_manual <- FALSE
        cat("  -> skipping manual corrections (your 'y' answer).\n")
      } else {
        stop(sprintf(paste0(
          "Manual-correction file(s) not found at their exact configured ",
          "paths:\n    %s\nRun stopped at your request (the 'n' answer). ",
          "Place the file(s) at the paths above or set ",
          "include_manual_corrections = FALSE for an explicitly ",
          "algorithmic-only run."),
          paste(.missing_manual, collapse = "\n    ")))
      }
    }
  }
  if (!.include_manual) {
    # Algorithmic-only run: blank out every human-review path for this run.
    # Step 5 has already written the [NEW] worksheets; they are untouched.
    cfg$data$files$manual_error           <- ""
    cfg$data$files$manual_unusual         <- ""
    cfg$data$files$manual_nap_exercise    <- ""
    cfg$data$files$manual_metric_duration <- ""
    cfg$data$files$manual_metric_accept   <- ""
    cfg$data$files$second_review          <- ""
    # The path variables above were already resolved from the pre-gate cfg;
    # blank them too so the Step-6 readers see "no file" rather than the
    # configured path.
    manual_error_path   <- ""
    manual_unusual_path <- ""
    assign("pipeline_config", cfg, envir = .GlobalEnv)
    if (verbose) cat(sprintf(
      paste0("\n%s\n*   MANUAL CORRECTIONS NOT INCLUDED%s",
             "*   This run is ALGORITHMIC-ONLY: no human-review file touched the data.%s",
             "*   The [NEW] review worksheets from Step 5 were still generated for%s",
             "*   your inspection. To apply human corrections, rerun with:%s",
             "*       run_pipeline(..., include_manual_corrections = TRUE)%s%s\n"),
      strrep("*", 74), "\n", "\n", "\n", "\n", "\n", strrep("*", 74)))
  } else if (verbose) {
    cat("\nManual corrections INCLUDED (include_manual_corrections = TRUE):",
        "applying the human-review files configured in the YAML.\n")
  }

  # The require-manual guard is only meaningful when human corrections ARE
  # intended: in an explicitly algorithmic-only run an absent manual file is
  # the caller's informed choice, not a silent accident.
  .require_manual <- .include_manual &&
    isTRUE(cfg_get("data.require_manual_corrections", FALSE, cfg = cfg))
  if (.require_manual) {
    .missing <- c(
      if (!file.exists(manual_error_path))   manual_error_path,
      if (!file.exists(manual_unusual_path)) manual_unusual_path
    )
    if (length(.missing) > 0) {
      stop(sprintf(
        paste0(
          "data.require_manual_corrections is TRUE in this config, but the ",
          "following required manual-review file(s) were not found at their ",
          "exact configured path:\n    %s\n",
          "Refusing to run with silently-empty manual corrections -- this ",
          "would complete without error and produce a dataset that LOOKS ",
          "fully corrected but is missing every human-reviewed fix. Place ",
          "the real file(s) at the exact path(s) above (this pipeline does ",
          "not search for similarly-named files), or set ",
          "data.require_manual_corrections: false in this config if an ",
          "algorithmic-only run is actually intended."
        ),
        paste(.missing, collapse = "\n    ")
      ))
    }
  }

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
  # Show, on every row of the [NEW] worksheets, where (if anywhere) it has
  # already been handled in the manual files. Non-fatal.
  .review_ws <- tryCatch(
    annotate_review_worksheets(manual_corrections, manual_unusual, verbose),
    error = function(e) {
      if (verbose) cat("  [review worksheets] not annotated:", conditionMessage(e), "\n")
      list()
    })
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
    utils::write.csv(ndf[, cols, drop = FALSE],
                     file.path(cfg_get("output.report.dir", "output", cfg = cfg),
                               cfg_get("output.report.flagged_self_reported",
                                       "flagged_records_self_reported.csv", cfg = cfg)),
                     row.names = FALSE)
    if (verbose) cat(sprintf("  Exported %d SELF-REPORTED FLAG records\n", nrow(ndf)))
  }
  # The auto-detection labels (raw_category) live in checkforerrors_summary,
  # not in corrected_ema_data, so the ledger used to see no labels for the
  # checkforerrors standard and recorded NA at every step. Hand the ledger a
  # copy with the labels attached (matched on pid/day_num/row_id); the pipeline
  # data itself is not modified.
  .with_cfe_labels <- function(df) {
    rs <- checkforerrors_summary$review_summary
    need <- c("pid", "day_num", "row_id")
    if (is.data.frame(rs) && all(need %in% names(rs)) && all(need %in% names(df))) {
      idx <- match(do.call(paste, c(df[need], sep = "|")),
                   do.call(paste, c(rs[need], sep = "|")))
      df$raw_category <- as.character(rs$raw_category)[idx]
    }
    df
  }
  log_step(.with_cfe_labels(corrected_ema_data), "8", "Auto-detect", cfg)

  # -- Step 8.5: Cross-participant check -------------------------------
  if (verbose) cat("\n=== Step 8.5: Cross-participant global consistency check ===\n")
  source(file.path(sdir, "cross_participant_global_check.R"), local = TRUE)
  assign("review_output", review_output, envir = .GlobalEnv)
  log_step(.with_cfe_labels(corrected_ema_data), "8.5", "Cross-participant check", cfg)

  # After the re-check of the corrected data: how many handled rows are still a
  # problem? Print only; nothing is written and the data are not touched.
  tryCatch(
    print_review_summary(.review_ws, corrected_ema_data, review_output$data_with_flags,
                         applied = .include_manual, verbose = verbose),
    error = function(e) if (verbose) cat("  [review progress] skipped:", conditionMessage(e), "\n")
  )

  # -- Step 9: Visualization -------------------------------------------
  if (!skip_visualization) {
    if (verbose) cat("\n=== Step 9: Generating visualizations ===\n")
    source(file.path(sdir, "sleep_visualization.R"), local = TRUE)
    # The script resolves its own output directory from the data tag
    # (real / synth / unknown). Remember it so Step 11 indexes the directory
    # the figures were actually written to, instead of re-guessing the tag.
    viz_dir <- output_dir
  }

  write_step_ledger(file.path(cfg_get("output.report.dir", "output", cfg = cfg),
                              "step_flag_ledger.csv"))

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

  # -- Step 11: Generate figure_index contact sheet ---------------------------
  if (!skip_visualization) {
    if (verbose) cat("\n=== Step 11: Generating figure index ===\n")
    # viz_dir was set in Step 9 (the directory sleep_visualization.R wrote to).
    tryCatch(
      run_figure_index(viz_dir),
      error = function(e) {
        if (verbose) cat("[WARNING] figure_index generation failed:\n", conditionMessage(e), "\n")
        # Non-fatal: figures are already generated, just missing the contact sheet
      }
    )
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
  pipeline_config <- env$cfg
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

#' Run the complete pipeline on bundled synthetic demo data
#'
#' Convenience function that runs the full pipeline using the synthetic
#' EMA diary dataset bundled with sleepcleanr. Useful for testing, demos,
#' and validation without needing real data.
#'
#' Synthetic data includes deliberately injected errors across all rule categories
#' to benchmark detection and correction performance. Results are written to
#' \code{output/latest_visualization_synth_nXXX/} in the current working directory.
#'
#' @param project_dir Character. Path to the project root (where output/ will be created).
#'   Default ".".
#' @param verbose Logical. Print progress. Default TRUE.
#'
#' @return Invisibly TRUE on successful completion.
#' @export
#'
#' @examples
#' \dontrun{
#'   # Run the full pipeline on synthetic data in the current directory
#'   run_synthetic_demo()
#'
#'   # Run in a specific directory
#'   run_synthetic_demo(project_dir = "~/my_sleepcleanr_run")
#' }
run_synthetic_demo <- function(project_dir = ".", verbose = TRUE) {
  # Locate bundled synthetic data and config
  data_main <- system.file("extdata", "synthetic_sleep_data.rds", package = "sleepcleanr")
  data_extra <- system.file("extdata", "synthetic_ema_data.csv", package = "sleepcleanr")
  cfg_path <- system.file("extdata", "synthetic_config.yaml", package = "sleepcleanr")

  if (data_main == "" || data_extra == "" || cfg_path == "") {
    stop("Bundled synthetic data or config not found. Is sleepcleanr correctly installed?")
  }

  if (verbose) {
    cat("\n=== Running sleepcleanr on Bundled Synthetic Demo Data ===\n")
    cat("Data: ", data_main, "\n")
    cat("      ", data_extra, "\n")
    cat("Config:", cfg_path, "\n\n")
  }

  # Load config and override data paths to point to bundled files
  cfg <- load_config(cfg_path)
  cfg$data$files$main <- data_main
  cfg$data$files$extra <- data_extra
  # Clear manual correction stubs (they don't exist in bundled package)
  cfg$data$files$manual_error <- NULL
  cfg$data$files$manual_unusual <- NULL
  cfg$data$files$manual_nap_exercise <- NULL
  cfg$data$files$manual_metric_duration <- NULL
  cfg$data$files$manual_metric_accept <- NULL
  cfg$data$files$second_review <- NULL

  # Run the full pipeline
  run_pipeline(config = cfg, project_dir = project_dir, verbose = verbose)
}

