#' Build the analysis-facing datasets from the full pipeline output
#'
#' Splits the pipeline output into two delivered datasets plus the full
#' archive, driven entirely by `inst/extdata/column_dictionary.csv`.
#'
#' The dictionary is the single source of truth for three things that used to
#' drift apart: the column whitelist, the rename mapping, and the data
#' dictionary itself. Adding a column means editing one CSV row, not three
#' places.
#'
#' @param data        The pipeline output (`corrected_ema_data`).
#' @param review_data Optional. `review_output$data_with_flags`. Step 8 creates
#'   its flags on a copy and never writes them back to `corrected_ema_data`
#'   (see `00_MAIN_entry.R`, Step 8), so columns such as `needs_review_flag`
#'   are only reachable through this object. The dictionary's `source_object`
#'   field records which columns need it.
#' @param dict_path   Path to the column dictionary CSV. Defaults to the copy
#'   shipped in `inst/extdata`.
#' @param output_dir  Directory for the delivered files.
#' @param write       Write files to disk. Set FALSE to inspect the return
#'   value without touching the filesystem.
#' @param verbose     Print a summary.
#' @return Invisibly, a list with `final` (Dataset A), `prepost` (Dataset B)
#'   and `full` (everything, unchanged).
#' @export
finalize_columns <- function(data,
                             review_data = NULL,
                             dict_path   = NULL,
                             output_dir  = "output",
                             write       = TRUE,
                             verbose     = TRUE) {

  stopifnot(is.data.frame(data))

  # ---- 1. Load the dictionary ------------------------------------------------
  if (is.null(dict_path)) {
    dict_path <- system.file("extdata", "column_dictionary.csv", package = "splsleep")
    if (!nzchar(dict_path)) {
      dict_path <- file.path("inst", "extdata", "column_dictionary.csv")  # dev mode
    }
  }
  if (!file.exists(dict_path)) stop("Column dictionary not found: ", dict_path)
  dict <- utils::read.csv(dict_path, stringsAsFactors = FALSE,
                          colClasses = "character", na.strings = NULL)

  required_fields <- c("source_column", "source_object", "default_if_absent",
                       "name_a", "name_b", "transform", "unit", "status",
                       "description")
  missing_fields <- setdiff(required_fields, names(dict))
  if (length(missing_fields)) {
    stop("Dictionary is missing required field(s): ",
         paste(missing_fields, collapse = ", "))
  }

  promised    <- dict[nzchar(dict$name_a) | nzchar(dict$name_b), ]
  implemented <- promised[promised$status == "implemented", ]
  pending     <- promised[promised$status == "pending", ]
  reserved    <- promised[promised$status == "reserved", ]

  if (nrow(pending) && verbose) {
    message("  [finalize_columns] ", nrow(pending),
            " column(s) marked 'pending' and not yet built: ",
            paste(pending$source_column, collapse = ", "))
  }

  # ---- 2. Resolve each column to its source object ----------------------------
  if (!is.null(review_data)) {
    stopifnot(is.data.frame(review_data))
    if (nrow(review_data) != nrow(data)) {
      stop("review_data has ", nrow(review_data), " rows but data has ",
           nrow(data), ". They must be row-aligned -- Step 8 works on a plain ",
           "copy of corrected_ema_data, so any mismatch means something ",
           "reordered or filtered the rows.")
    }
  }

  # ---- 2b. Derive record_status (S3) -----------------------------------------
  # record_status is the analysis-facing name for data_category. It is derived
  # here, in the delivery layer, rather than in the pipeline: the pipeline
  # currently runs and its numbers are signed off, so a purely presentational
  # rename has no business touching it.
  #
  # Six levels, not the five originally sketched. reasonable_unusual is a real
  # data_category level (error_unusual_sleep_time_corrections.R:1570 assigns it)
  # and means "a human looked at this unusual record and accepted it" -- which
  # is not the same claim as "unusual". Folding the two together would discard
  # a human judgement, so it keeps its own level.
  #
  # An unknown level stops the build. Mapping it to NA instead would let a new
  # pipeline category leak into the delivered data as a silent blank.
  .RECORD_STATUS_MAP <- c(
    clean              = "clean",
    error              = "error",
    unusual            = "unusual",
    reasonable_unusual = "reasonable_unusual",
    equal_time_ok      = "equal_time",
    skipped_na         = "not_reported"
  )

  if (!"record_status" %in% names(data) && "data_category" %in% names(data)) {
    dc      <- as.character(data$data_category)
    unknown <- setdiff(unique(dc[!is.na(dc)]), names(.RECORD_STATUS_MAP))
    if (length(unknown)) {
      stop("data_category has level(s) with no record_status mapping: ",
           paste(unknown, collapse = ", "),
           "\nAdd them to .RECORD_STATUS_MAP in R/finalize_columns.R. ",
           "Leaving them unmapped would ship blanks in a status column.")
    }
    data$record_status <- unname(.RECORD_STATUS_MAP[dc])
  }

  .resolve <- function(i) {
    cn  <- implemented$source_column[i]
    obj <- implemented$source_object[i]
    src <- if (identical(obj, "review_output")) review_data else data
    if (!is.null(src) && cn %in% names(src)) return(list(ok = TRUE, value = src[[cn]]))

    # Absent. A declared default means the column is legitimately optional --
    # e.g. is_reasonable_unusual is only created when at least one reasonable
    # unusual record exists, so it is missing on datasets that have none.
    dflt <- implemented$default_if_absent[i]
    if (nzchar(dflt)) {
      v <- switch(dflt,
                  "TRUE"  = TRUE,
                  "FALSE" = FALSE,
                  "NA"    = NA,
                  suppressWarnings({
                    num <- as.numeric(dflt); if (is.na(num)) dflt else num
                  }))
      return(list(ok = TRUE, value = rep(v, nrow(data)), defaulted = TRUE))
    }
    list(ok = FALSE, obj = obj)
  }

  resolved <- lapply(seq_len(nrow(implemented)), .resolve)

  bad <- which(!vapply(resolved, function(r) r$ok, logical(1)))
  if (length(bad)) {
    need_review <- vapply(resolved[bad], function(r) identical(r$obj, "review_output"), logical(1))
    msg <- paste0("Dictionary promises column(s) that are not available:\n  ",
                  paste(implemented$source_column[bad], collapse = "\n  "))
    if (any(need_review) && is.null(review_data)) {
      msg <- paste0(msg,
        "\n\nSome of these live in review_output$data_with_flags, not in ",
        "corrected_ema_data.\nPass them with: ",
        "finalize_columns(data, review_data = review_output$data_with_flags)")
    } else {
      msg <- paste0(msg, "\nEither the pipeline changed or the dictionary is stale.")
    }
    stop(msg)
  }

  defaulted <- implemented$source_column[
    vapply(resolved, function(r) isTRUE(r$defaulted), logical(1))]
  if (length(defaulted) && verbose) {
    message("  [finalize_columns] filled from declared defaults (absent in this run): ",
            paste(defaulted, collapse = ", "))
  }

  # ---- 3. Reverse check: columns the dictionary does not describe -------------
  # Written to a file, not the console. The raw EMA passthrough alone is
  # hundreds of columns, so a console warning would be noise and would be
  # trained away within a week -- which is exactly how a genuinely new pipeline
  # column goes unnoticed.
  known <- names(data)
  if (!is.null(review_data)) known <- union(known, names(review_data))
  unmapped <- setdiff(known, dict$source_column)
  if (length(unmapped) && write) {
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    gaps_path <- file.path(output_dir, "column_dictionary_gaps.csv")
    utils::write.csv(data.frame(column = unmapped, stringsAsFactors = FALSE),
                     gaps_path, row.names = FALSE)
    if (verbose) {
      message("  [finalize_columns] ", length(unmapped),
              " column(s) not described by the dictionary -> ", gaps_path)
    }
  }

  # ---- 4. Assemble ------------------------------------------------------------
  .build <- function(name_field) {
    keep <- which(nzchar(implemented[[name_field]]))
    if (!length(keep)) return(data[0, 0, drop = FALSE])

    out <- lapply(keep, function(i) {
      v  <- resolved[[i]]$value
      tf <- implemented$transform[i]
      if (!identical(tf, "none") && nzchar(tf)) {
        # Only "x<number>" is supported. A silent no-op here would ship wrong
        # units -- the exact failure that left WASO in hours next to a column
        # measured in minutes.
        if (!grepl("^x[0-9.]+$", tf)) {
          stop("Unsupported transform '", tf, "' for column ",
               implemented$source_column[i])
        }
        v <- as.numeric(v) * as.numeric(sub("^x", "", tf))
      }
      v
    })
    names(out) <- implemented[[name_field]][keep]
    as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
  }

  final   <- .build("name_a")
  prepost <- .build("name_b")

  # ---- 4a. Affect-layer passthrough -----------------------------------------
  # The study has an emotion/affect EMA layer (pos_affect, neg_affect,
  # stress_today_pm, copestress_today_pm, ...) that is NOT part of the sleep
  # cleaning pipeline: it is not parsed, flagged, imputed or corrected here,
  # and its columns are not in the whitelist. The cleaner must nevertheless
  # never drop them silently.
  #
  # Rows in the dictionary marked status == 'reserved' declare affect columns
  # by their real survey name. If such a column is present in the pipeline
  # output, it is passed through to Dataset A untouched. If it is absent
  # there is nothing to pass -- no empty column is fabricated. Column names
  # matching the affect family that are not yet listed are also passed through
  # so a renamed survey item cannot be silently destroyed.
  .AFFECT_PATTERN <-
    "^(pos_affect|neg_affect|stress_today_pm|copestress_today_pm)$|_affect_|_affect$|_mood_|_mood$|_stress_|_stress$"
  affect_in <- intersect(names(data), c(reserved$source_column,
                                        grep(.AFFECT_PATTERN, names(data),
                                             value = TRUE)))
  affect_cols <- setdiff(affect_in, names(final))
  if (length(affect_cols)) {
    if (write) {
      dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    }
    final <- cbind(final,
                   data[, affect_cols, drop = FALSE])
    if (verbose) {
      cat("  [finalize_columns] affect-layer passthrough (cleaner does not touch): ",
          paste(affect_cols, collapse = ", "), "\n", sep = "")
    }
  }

  # ---- 4b. Export guard: nothing impossible in the delivered files --------
  # A human analyst filtering on record_status != 'error' should never see a
  # negative duration or an absurd sleep metric. The pipeline classifies
  # negatives as errors, but that classification is being relied on, not
  # enforced -- a negative value that leaked into a non-error row would ship
  # silently. That is exactly how row 8502's -716-minute WASO once escaped.
  #
  # Which rows are guarded: the ANALYSABLE rows, i.e. everything except
  # 'error' and 'not_reported'. not_reported (skipped_na) rows are, by
  # definition, missing a whole night -- on real data some of them still carry
  # a derived sleepperiod from the fragments that were filled, and that value
  # is arithmetic noise, not a signal. Guarding those rows would fail the
  # build on data the study will not analyse. error rows are the pipeline's
  # job to carry; the guard exists for what leaks PAST the filter, so if
  # record_status is missing entirely, every non-NA value is still checked.
  # Guard only the numeric 'minutes' columns; category/status columns are left
  # alone.
  .METRIC_MINUTES_COLS <- c("tst_minutes", "sol_computed_minutes",
      "se_percent", "tib_minutes", "sleepperiod_minutes",
      "waso_computed_minutes", "waso_selfreport_minutes",
      "waso_avg_bout_selfreport_minutes", "sol_selfreport_minutes",
      "nap_selfreport_total_minutes", "exercise_light_minutes",
      "exercise_moderate_minutes", "exercise_vigorous_minutes",
      "exercise_strength_minutes")
  .metric_cols <- intersect(.METRIC_MINUTES_COLS, names(final))
  if (length(.metric_cols) > 0) {
    status_col <- if ("record_status" %in% names(final)) "record_status"
                  else if ("data_category" %in% names(final)) "data_category"
                  else NULL
    for (nm in .metric_cols) {
      if (!is.numeric(final[[nm]])) next
      val <- if (!is.null(status_col) && status_col %in% names(final)) {
        final[[nm]][!final[[status_col]] %in% c("error", "not_reported")]
      } else final[[nm]]
      if (any(!is.na(val) & val < 0)) {
        stop("Export guard (finalize_columns): '", nm, "' contains negative ",
             "value(s) in analyzable rows (record_status neither error nor ",
             "not_reported). A negative duration is impossible; investigate ",
             "before shipping. (This is the guard that would catch the row ",
             "8502 type of bug.)")
      }
    }
  }

  # ---- 5. Write ---------------------------------------------------------------
  if (write) {
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    utils::write.csv(final,   file.path(output_dir, "cleaned_data_final.csv"),
                     row.names = FALSE)
    utils::write.csv(prepost, file.path(output_dir, "cleaned_data_prepostcorrection.csv"),
                     row.names = FALSE)
    saveRDS(final,   file.path(output_dir, "cleaned_data_final.rds"))
    saveRDS(prepost, file.path(output_dir, "cleaned_data_prepostcorrection.rds"))
    saveRDS(data,    file.path(output_dir, "cleaned_data_full.rds"))
  }

  if (verbose) {
    cat(sprintf("\n  Dataset A (cleaned_data_final):             %d rows x %d cols\n",
                nrow(final), ncol(final)))
    cat(sprintf("  Dataset B (cleaned_data_prepostcorrection):  %d rows x %d cols\n",
                nrow(prepost), ncol(prepost)))
    cat(sprintf("  Full archive:                                %d rows x %d cols\n",
                nrow(data), ncol(data)))
  }

  invisible(list(final = final, prepost = prepost, full = data))
}
