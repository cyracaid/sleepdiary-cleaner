#' Clean a sleep diary: data-first entry point
#'
#' One-call entry for new users: give it a file or a data.frame, get back the
#' cleaned data plus a full provenance manifest. No config file required --
#' column names are inferred (\code{guess_column_mapping()}) and every schema
#' decision is recorded, never silently guessed.
#'
#' The returned object is a stable 6-field list:
#' \describe{
#'   \item{cleaned}{Cleaned Dataset A as a data.frame. NULL when \code{dry_run = TRUE}.}
#'   \item{config}{The full effective config used (defaults + overrides).}
#'   \item{guesses}{Per-column mapping decisions from \code{guess_column_mapping()}.}
#'   \item{ledger}{Per-step row-count ledger (step_id, label, n_rows).}
#'   \item{outputs}{Named list of output file paths.}
#'   \item{manifest}{The provenance manifest (also written to \code{outputs$manifest_json}).}
#' }
#'
#' @param data Character or data.frame. Path to a .csv / .rds / .xlsx file, or
#'   an in-memory data.frame. Ignored columns are left untouched; the raw input
#'   is never modified.
#' @param config Character or list or NULL. YAML config path, config list, or
#'   NULL to use the bundled defaults (recommended for first runs).
#' @param dry_run Logical. If TRUE, stop after input hashing + schema
#'   detection + column mapping + config resolution: print the mapping preview
#'   and write \code{dry_run_manifest.json}, but do NOT run the pipeline and do
#'   NOT write any cleaned dataset.
#' @param project_dir Character. Working directory for the run (default ".").
#' @param ... Additional arguments passed to \code{run_pipeline()}.
#'
#' @return A 6-field list (see Description).
#' @export
clean_sleep_diary <- function(data, config = NULL, dry_run = FALSE,
                              project_dir = ".", ...) {
  # -- 1. Input hashing (hash is identity; path is auxiliary) ---------------
  if (is.character(data) && length(data) == 1) {
    if (!file.exists(data)) stop("Data file not found: ", data)
    input_path <- data
    input_basename <- basename(data)
    input_size <- file.info(data)$size
    input_md5 <- unname(tools::md5sum(data))
    input <- switch(tolower(tools::file_ext(data)),
      csv  = utils::read.csv(data, stringsAsFactors = FALSE),
      rds  = readRDS(data),
      xlsx = {
        if (!requireNamespace("readxl", quietly = TRUE)) {
          stop("Package 'readxl' is required for .xlsx input. Install with: install.packages('readxl')")
        }
        readxl::read_excel(data)
      },
      stop("Unsupported file type: ", data, " (use .csv, .rds, or .xlsx)")
    )
    path_recorded <- TRUE
  } else if (is.data.frame(data)) {
    input_path <- NA_character_
    input_basename <- "in-memory data.frame"
    input_size <- as.numeric(utils::object.size(data))
    tmp <- tempfile(fileext = ".rds")
    saveRDS(data, tmp)
    input_md5 <- unname(tools::md5sum(tmp))
    unlink(tmp)
    input <- data
    path_recorded <- FALSE
  } else {
    stop("'data' must be a file path (.csv/.rds/.xlsx) or a data.frame")
  }

  # -- 2. Config resolution ---------------------------------------------------
  cfg <- if (is.null(config)) {
    load_config()
  } else if (is.character(config)) {
    load_config(config)
  } else if (is.list(config)) {
    config
  } else {
    stop("'config' must be a YAML path, a list, or NULL")
  }

  # -- 3. Column mapping: explicit config wins; else guess (recorded) --------
  # The bundled default config carries Stanford-specific mappings; those are
  # only meaningful for that lab's schema. For a data-first run, "explicit"
  # means the USER supplied a mapping (via a config path/list), not the bundled
  # default -- otherwise a generic external file would be force-mapped onto
  # Stanford column names and fail loudly for no reason.
  user_supplied_cfg <- !is.null(config) && !identical(config, "default")
  explicit <- user_supplied_cfg && !is.null(cfg$column_mapping) &&
    any(vapply(cfg$column_mapping, function(sec) {
      is.list(sec) && any(!vapply(sec, is.null, logical(1)))
    }, logical(1)))
  if (explicit) {
    guesses <- NULL
    guess_df <- data.frame()
  } else {
    g <- guess_column_mapping(names(input))
    guess_df <- g$decisions
    cfg$column_mapping <- g$mapping
    cat("\n[clean_sleep_diary] Inferred column mapping (recorded in manifest; not silent):\n")
    print(guess_df[guess_df$status != "no_match", ], row.names = FALSE)
    absent <- guess_df$internal_col[guess_df$status == "absent"]
    if (length(absent) > 0) {
      cat(sprintf("\n[clean_sleep_diary] No input column matched required field(s): %s\n",
                  paste(absent, collapse = ", ")))
    }
    guesses <- g
  }

  # Apply the (explicit or guessed) mapping now. run_pipeline re-validates the
  # schema AFTER adapt_columns, so the mapping must land before the call.
  if (!is.null(cfg$column_mapping)) {
    input <- adapt_columns(input, cfg)
    # adapt_columns() renamed the mapped user columns to their canonical long
    # form (e.g. "sol" -> "duration_totalmin_sol_estimate_am"). The config's
    # column_mapping still points at the user names, and file-based sourced
    # steps (Step 1.5 field misentry) resolve columns THROUGH that mapping --
    # so sync the mapping values to the canonical names the data now carries.
    CAN <- c(
      time_bed_hhmm = "time_bed_am_hhmm", time_bed_ampm = "time_bed_am_ampm",
      time_sleep_hhmm = "time_sleep_am_hhmm", time_sleep_ampm = "time_sleep_am_ampm",
      time_awake_hhmm = "time_awake_am_hhmm", time_awake_ampm = "time_awake_am_ampm",
      time_getup_hhmm = "time_getup_am_hhmm", time_getup_ampm = "time_getup_am_ampm",
      sol = "duration_totalmin_sol_estimate_am", waso = "duration_totalmin_waso_estimate_am",
      nap = "duration_totalmin_napstoday_PM", waso_count = "num_waso_estimate_am",
      caffeine = "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1",
      alcohol = "alcoholtoday_PM_NumAlcoholicDrinks_1",
      date_bed = "StartDate")
    for (sec in names(cfg$column_mapping)) {
      for (k in names(cfg$column_mapping[[sec]])) {
        v <- cfg$column_mapping[[sec]][[k]]
        if (!is.null(v) && !is.na(v) && k %in% names(CAN)) {
          cfg$column_mapping[[sec]][[k]] <- unname(CAN[[k]])
        }
      }
    }
  }

  # -- 4. Manifest assembly ---------------------------------------------------
  commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
                     error = function(e) NULL)
  commit <- if (length(commit) == 1 && nzchar(commit)) commit else NULL  # NULL = not a git repo / unavailable
  si <- utils::sessionInfo()
  env_info <- list(
    R = si$R.version$version.string,
    platform = si$platform,
    packages = sort(vapply(si$otherPkgs, function(x) as.character(x$Version), character(1)))
  )
  manifest <- list(
    package_version = tryCatch(as.character(utils::packageVersion("sleepcleanr")),
                               error = function(e) "unknown"),
    commit = commit,
    timestamp_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    seed = NULL,
    dry_run = isTRUE(dry_run),
    input = list(
      basename = input_basename,
      md5 = input_md5,
      size_bytes = input_size,
      path = input_path,
      path_recorded = path_recorded
    ),
    environment = env_info,
    config = cfg,
    column_mapping = guess_df,
    steps = data.frame(),
    outputs = list()
  )

  # -- 5. dry_run: STOP here, write only dry_run_manifest.json ---------------
  if (isTRUE(dry_run)) {
    out_dir <- file.path(project_dir, "output")
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    manifest_path <- file.path(out_dir, "dry_run_manifest.json")
    jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE)
    cat(sprintf("\n[dry_run] Stopped after config resolution. Wrote %s (no data written).\n",
                manifest_path))
    return(list(
      cleaned = NULL,
      config = cfg,
      guesses = guess_df,
      ledger = data.frame(),
      outputs = list(dry_run_manifest_json = manifest_path),
      manifest = manifest
    ))
  }

  # -- 6. Run the pipeline ---------------------------------------------------
  # Data-first runs still execute file-based sourced steps (Step 1.5 field
  # misentry, Step 5 correction files) that re-read data.files.main from disk.
  # The adapted input is written to an internal copy inside project_dir (the
  # user's raw file / data.frame is never modified) and the config points at
  # that copy; provenance of the ORIGINAL input is preserved in the manifest.
  internal_copy <- file.path(project_dir, "input_adapted.rds")
  dir.create(project_dir, showWarnings = FALSE, recursive = TRUE)
  saveRDS(input, internal_copy)
  cfg$data$files$main <- "input_adapted.rds"

  run_pipeline(config = cfg, project_dir = project_dir, ...)

  # -- 7. Collect outputs + ledger -------------------------------------------
  out_dir <- file.path(project_dir, "output")
  ledger_path <- file.path(out_dir, "step_flag_ledger.csv")
  ledger_df <- if (file.exists(ledger_path)) {
    read.csv(ledger_path, stringsAsFactors = FALSE)
  } else {
    data.frame()
  }
  cleaned_path <- file.path(out_dir, "cleaned_data_final.csv")
  cleaned_df <- if (file.exists(cleaned_path)) {
    utils::read.csv(cleaned_path, stringsAsFactors = FALSE)
  } else {
    data.frame()
  }
  manifest$steps <- ledger_df
  manifest$outputs <- list(
    cleaned_csv = cleaned_path,
    ledger_csv = ledger_path,
    manifest_json = NA_character_
  )

  manifest_path <- file.path(out_dir, sprintf("run_manifest_%s.json",
    format(Sys.time(), tz = "UTC", "%Y%m%d_%H%M%S")))
  jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE)
  manifest$outputs$manifest_json <- manifest_path

  cat(sprintf("\n[clean_sleep_diary] Manifest: %s\n", manifest_path))

  list(
    cleaned = cleaned_df,
    config = cfg,
    guesses = guess_df,
    ledger = ledger_df,
    outputs = manifest$outputs,
    manifest = manifest
  )
}