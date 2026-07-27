#' Per-step flag ledger (log_step)
#'
#' Intercepts EVERY pipeline step and records, against the shared final
#' standards (see flag_standards.R), how many records fall in each flag category
#' at that step. Produces the data behind the new Figure 12 step x flag table.
#'
#' Two kinds of reduction are tracked separately:
#'   - n_corrected : rows fixed by a manual/auto correction (data changed)
#'   - n_suppressed: rows a human accepted as not-an-error (label withdrawn,
#'                   data unchanged)

.step_ledger_env <- new.env(parent = emptyenv())

#' Start a fresh ledger (call once at the top of run_pipeline).
#' @export
init_step_ledger <- function() {
  assign("rows", list(), envir = .step_ledger_env)
  invisible(TRUE)
}

#' Record the flag state after a step.
#'
#' @param df       Data frame in its state AFTER the step.
#' @param step_id  Short ordered id, e.g. "1", "1.5", "2", ... "8.5".
#' @param label    Human-readable step name.
#' @param cfg      Config list (for thresholds).
#' @param verbose  Logical. Print progress messages. Default: TRUE.
#' @return invisibly the row that was appended.
#' @export
log_step <- function(df, step_id, label, cfg = NULL, verbose = TRUE) {
  if (!exists("rows", envir = .step_ledger_env)) init_step_ledger()
  labels <- evaluate_all_standards(df, cfg)

  counts <- list()
  for (std in names(STANDARD_LEVELS)) {
    counts[[std]] <- tally_standard(labels[[std]], STANDARD_LEVELS[[std]])
  }

  n_corrected  <- if ("manually_corrected" %in% names(df))
    sum(df$manually_corrected %in% TRUE, na.rm = TRUE) else NA_integer_
  n_suppressed <- if ("human_metric_review_status" %in% names(df))
    sum(df$human_metric_review_status %in% "confirmed_not_error_do_not_correct", na.rm = TRUE) else NA_integer_

  row <- list(
    step_id = step_id, label = label, n_total = nrow(df),
    n_corrected = n_corrected, n_suppressed = n_suppressed,
    counts = counts
  )
  rows <- get("rows", envir = .step_ledger_env)
  rows[[length(rows) + 1]] <- row
  assign("rows", rows, envir = .step_ledger_env)

  if (verbose) {
    dc <- counts$data_category
    computed <- names(counts)[vapply(counts, function(x) !all(is.na(x)), logical(1))]
    cat(sprintf("  [log_step %-4s] %-38s n=%d | computable: %s\n",
                step_id, label, nrow(df), paste(computed, collapse = ", ")))
  }
  invisible(row)
}

#' Flatten the ledger into a long data frame
#' @export
get_step_ledger_long <- function() {
  rows <- if (exists("rows", envir = .step_ledger_env))
    get("rows", envir = .step_ledger_env) else list()
  out <- list()
  for (r in rows) {
    for (std in names(r$counts)) {
      cnt <- r$counts[[std]]
      out[[length(out) + 1]] <- data.frame(
        step_id = r$step_id, label = r$label, n_total = r$n_total,
        standard = std, category = names(cnt), count = as.integer(cnt),
        n_corrected = r$n_corrected, n_suppressed = r$n_suppressed,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(out) == 0) return(data.frame())
  do.call(rbind, out)
}

#' Wide ledger for one standard
#' @param standard Character. The standard to pivot wide. Default: "data_category".
#' @export
get_step_ledger_wide <- function(standard = "data_category") {
  long <- get_step_ledger_long()
  if (nrow(long) == 0) return(data.frame())
  sub <- long[long$standard == standard, ]
  steps <- unique(sub[, c("step_id", "label", "n_corrected", "n_suppressed")])
  cats <- STANDARD_LEVELS[[standard]]
  mat <- matrix(NA_integer_, nrow = nrow(steps), ncol = length(cats),
                dimnames = list(NULL, cats))
  for (i in seq_len(nrow(steps))) {
    si <- sub[sub$step_id == steps$step_id[i], ]
    for (cc in cats) {
      v <- si$count[si$category == cc]
      if (length(v)) mat[i, cc] <- v
    }
  }
  cbind(steps, as.data.frame(mat, check.names = FALSE))
}

#' Persist the ledger to CSV (long form)
#' @param path Character. Output CSV file path.
#' @export
write_step_ledger <- function(path = "output/step_flag_ledger.csv") {
  long <- get_step_ledger_long()
  if (nrow(long) == 0) { warning("Step ledger is empty."); return(invisible(FALSE)) }
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(long, path, row.names = FALSE)
  invisible(TRUE)
}
