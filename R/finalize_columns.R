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
