# User-defined review rules, the review status table, the review verdict and the
# run log.
#
# Every rule that decides what counts as "incorporated", "not incorporated",
# "needs review" or "done" is read from the config (`review:` block). The code
# only applies those rules; it never changes them during a run. The defaults
# below are the values written in inst/config_default.yaml, so a config without
# a `review:` block behaves exactly like the bundled default.

.review_defaults <- list(
  done_when = list(max_needs_review = 0),
  step8_flags_need_review = FALSE,
  missing_times_ok_after_manual = FALSE,
  fail_if_not_done = FALSE,
  suggestions = list(
    list(
      label = "likely_real_issue",
      when = list(auto_error_desc_matches = "SE:negative|TST/TIB:exceeds_1|SOL:negative"),
      reason = paste("Mathematically impossible sleep metric (negative SE, TST/TIB > 1, or",
                     "negative SOL); likely needs timestamp or WASO/TST review.")
    ),
    list(
      label = "likely_false_positive",
      when = list(sol_category = "excessive", se_category = "valid",
                  tst_tib_ratio_category = c("normal", "normal_low")),
      reason = paste("SOL exceeds 120 min, but other sleep metrics are internally plausible;",
                     "likely real long sleep latency rather than input error.")
    )
  ),
  suggestion_default = list(
    label = "needs_human",
    reason = paste("Metric flag needs human review because the values are unusual but not",
                   "automatically classifiable from available fields.")
  )
)

#' The review rules in force for a config
#'
#' Reads the `review:` block of a config and fills any key the config leaves out
#' with the bundled default. Nothing else decides these values.
#'
#' @param cfg A configuration list from [load_config()], or NULL for the defaults.
#' @return A list with `max_needs_review`, `step8_flags_need_review`,
#'   `missing_times_ok_after_manual`,
#'   `fail_if_not_done`, `suggestions` and `suggestion_default`.
#' @export
review_rules <- function(cfg = NULL) {
  r <- if (is.null(cfg)) list() else config_get(cfg, "review", list())
  if (!is.list(r)) r <- list()
  d <- .review_defaults
  max_nr <- r$done_when$max_needs_review %||% d$done_when$max_needs_review
  if (!is.numeric(max_nr) || length(max_nr) != 1 || is.na(max_nr) || max_nr < 0)
    stop("review.done_when.max_needs_review must be one number >= 0", call. = FALSE)
  out <- list(
    max_needs_review = as.numeric(max_nr),
    step8_flags_need_review = isTRUE(r$step8_flags_need_review %||% d$step8_flags_need_review),
    missing_times_ok_after_manual = isTRUE(r$missing_times_ok_after_manual %||% d$missing_times_ok_after_manual),
    fail_if_not_done = isTRUE(r$fail_if_not_done %||% d$fail_if_not_done),
    # An explicit empty list in the config means "no suggestions": keep it.
    suggestions = if ("suggestions" %in% names(r)) (r$suggestions %||% list()) else d$suggestions,
    suggestion_default = utils::modifyList(d$suggestion_default, r$suggestion_default %||% list())
  )
  for (i in seq_along(out$suggestions)) {
    s <- out$suggestions[[i]]
    if (!is.list(s) || is.null(s$label) || !is.list(s$when) || length(s$when) == 0)
      stop(sprintf("review.suggestions[[%d]] needs a label and a non-empty 'when'", i), call. = FALSE)
  }
  out
}

#' Label rows with the first user-defined suggestion rule they match
#'
#' Applies `review.suggestions` from the config, in the order written there. Each
#' rule's `when` is a set of conditions that must all hold: `<column>_matches`
#' is a regular expression on that column; any other key is a column whose value
#' must be one of the listed values. A row that matches no rule gets
#' `review.suggestion_default`. A suggestion is never a decision: the row stays
#' open until a person fills in `human_decision`.
#'
#' @param df A data frame.
#' @param rules Output of [review_rules()]; defaults to the bundled rules.
#' @return `df` with `ai_label`, `ai_reason` and `ai_rule` (the rule's position
#'   in `review.suggestions`, or "default").
#' @export
suggest_review_labels <- function(df, rules = review_rules(NULL)) {
  n <- nrow(df)
  label <- rep(NA_character_, n)
  reason <- rep(NA_character_, n)
  rule <- rep(NA_character_, n)
  for (i in seq_along(rules$suggestions)) {
    s <- rules$suggestions[[i]]
    hit <- rep(TRUE, n)
    for (key in names(s$when)) {
      v <- s$when[[key]]
      if (grepl("_matches$", key)) {
        col <- sub("_matches$", "", key)
        x <- if (col %in% names(df)) as.character(df[[col]]) else rep(NA_character_, n)
        hit <- hit & !is.na(x) & grepl(v, x)
      } else {
        x <- if (key %in% names(df)) as.character(df[[key]]) else rep(NA_character_, n)
        hit <- hit & !is.na(x) & x %in% as.character(unlist(v))
      }
    }
    take <- hit & is.na(label)
    label[take] <- s$label
    reason[take] <- s$reason %||% ""
    rule[take] <- as.character(i)
  }
  none <- is.na(label)
  label[none] <- rules$suggestion_default$label
  reason[none] <- rules$suggestion_default$reason
  rule[none] <- "default"
  df$ai_label <- label
  df$ai_reason <- reason
  df$ai_rule <- rule
  df
}

# -- Review status table ------------------------------------------------------

.review_states <- c("needs_review", "not_incorporated", "incorporated")

# Status rows for one Step 5 worksheet. Same five statuses as
# build_review_status_table(); a record kept as "unusual" passes on the unusual
# worksheet (reviewed and kept as reported) but not on the error worksheet.
.worksheet_status <- function(ws, worksheet, final) {
  ws <- .rp_clean_names(ws)
  if (nrow(ws) == 0) return(NULL)
  for (nm in .rp_added_cols) if (!nm %in% names(ws)) ws[[nm]] <- rep("", nrow(ws))
  k <- .rp_key(ws)
  ca <- as.character(final$data_category)[match(k, .rp_key(final))]
  ok <- if (identical(worksheet, "unusual")) c(.rp_ok_categories, "unusual") else .rp_ok_categories
  passes <- !is.na(ca) & ca %in% ok
  handled <- !is.na(ws$in_manual_file) & ws$in_manual_file != ""
  ws$worksheet <- worksheet
  ws$status_after_corrections <- ifelse(handled,
    ifelse(passes, "in_manual_file_now_passes", "in_manual_file_still_fails"),
    ifelse(passes, "not_in_manual_file_now_passes", "not_in_manual_file_still_fails"))
  ws$category_before_corrections <- worksheet
  ws$category_after_corrections <- ifelse(is.na(ca), "", ca)
  ws
}

# Bind data frames whose columns differ; missing columns are filled with NA.
.bind_fill <- function(lst) {
  lst <- lst[!vapply(lst, is.null, logical(1))]
  if (length(lst) == 0) return(data.frame())
  cols <- unique(unlist(lapply(lst, names)))
  do.call(rbind, lapply(lst, function(d) {
    for (nm in setdiff(cols, names(d))) d[[nm]] <- rep(NA, nrow(d))
    d[, cols, drop = FALSE]
  }))
}

#' One review status table for both Step 5 worksheets
#'
#' Every row of the error and unusual worksheets, plus every record that is an
#' error after the corrections but was on neither worksheet, gets exactly one
#' `review_state` and a `review_state_reason` saying which rule put it there:
#'
#' \describe{
#'   \item{needs_review}{a person still has to look: the record fails the re-check
#'     after corrections, became an error after corrections, is marked pending in
#'     the manual file, has a time missing after corrections (unless it is in a
#'     manual file and `review.missing_times_ok_after_manual` is true), or (only
#'     if `review.step8_flags_need_review` is true) has a Step 8 flag;}
#'   \item{incorporated}{a manual decision for the record was applied in this run
#'     and the record passes the re-check;}
#'   \item{not_incorporated}{no manual decision changed the record in this run and
#'     it passes the re-check (fixed by the rules alone, or the manual files were
#'     not applied).}
#' }
#'
#' @param ws_list List with `error` and `unusual` annotated worksheets.
#' @param final Corrected data with `pid`, `day_num`, `row_id`, `data_category`.
#' @param flags Optional Step 8 data with `needs_review_flag`, `auto_error_desc`.
#' @param rules Output of [review_rules()].
#' @param applied Were manual corrections applied in this run?
#' @return A data frame ordered needs_review, not_incorporated, incorporated, then
#'   by worksheet, pid, day_num, row_id (locale-independent order).
#' @noRd
build_unified_review_status <- function(ws_list, final, flags = NULL,
                                        rules = review_rules(NULL), applied = TRUE) {
  final <- .rp_clean_names(final)
  parts <- list(.worksheet_status(ws_list[["error"]], "error", final),
                .worksheet_status(ws_list[["unusual"]], "unusual", final))

  on_sheet <- unlist(lapply(parts, .rp_key))
  fkey <- .rp_key(final)
  is_err <- as.character(final$data_category) %in% "error"
  nw <- final[is_err & !(fkey %in% on_sheet), , drop = FALSE]
  if (nrow(nw) > 0) {
    keep <- intersect(c("pid", "day_num", "row_id", "error_type"), names(nw))
    nw <- nw[, keep, drop = FALSE]
    for (nm in .rp_added_cols) nw[[nm]] <- ""
    nw$worksheet <- "none"
    nw$status_after_corrections <- "new_after_corrections"
    nw$category_before_corrections <- "not_on_step5_list"
    nw$category_after_corrections <- "error"
    parts <- c(parts, list(nw))
  }
  out <- .bind_fill(parts)
  front <- c("pid", "day_num", "row_id", "worksheet", "review_state", "review_state_reason",
             "status_after_corrections", "in_manual_file", "category_before_corrections",
             "category_after_corrections", "step8_flags_after_corrections")
  if (nrow(out) == 0) {
    x <- as.data.frame(stats::setNames(replicate(length(front), character(0), simplify = FALSE), front),
                       stringsAsFactors = FALSE)
    return(x)
  }
  rownames(out) <- NULL
  for (nm in .rp_added_cols) { v <- as.character(out[[nm]]); v[is.na(v)] <- ""; out[[nm]] <- v }

  k <- .rp_key(out)
  step8 <- rep("", nrow(out))
  if (!is.null(flags)) {
    flags <- .rp_clean_names(flags)
    i <- match(k, .rp_key(flags))
    on <- if ("needs_review_flag" %in% names(flags)) flags$needs_review_flag[i] %in% TRUE else rep(FALSE, nrow(out))
    desc <- if ("auto_error_desc" %in% names(flags)) as.character(flags$auto_error_desc)[i] else rep("", nrow(out))
    desc[is.na(desc)] <- ""
    step8 <- ifelse(on, ifelse(nzchar(desc), desc, "flagged"), "")
  }
  out$step8_flags_after_corrections <- step8

  st <- out$status_after_corrections
  handled <- out$in_manual_file != ""
  res <- tolower(out$review_resolution)
  pending <- handled & (res == "flagged_unresolved" | tolower(out$resolved_by) == "pending")
  legacy <- handled & grepl("legacy", res)
  fails <- st %in% c("not_in_manual_file_still_fails", "in_manual_file_still_fails")

  state <- rep(NA_character_, nrow(out))
  why <- rep(NA_character_, nrow(out))
  set <- function(cond, s, r) {
    take <- cond & is.na(state)
    state[take] <<- s
    why[take] <<- r
  }
  set(st == "new_after_corrections", "needs_review", "error after corrections; not on the Step 5 lists")
  set(pending, "needs_review", "marked pending (flagged_unresolved) in the manual file")
  # A time missing after corrections (data_category skipped_na) means the order
  # cannot be re-checked. Whether a handled row like that counts as done is the
  # user's rule: review.missing_times_ok_after_manual.
  missing <- out$category_after_corrections %in% "skipped_na"
  set(missing & handled & applied & rules$missing_times_ok_after_manual, "incorporated",
      paste("manual decision applied; a time is missing after corrections, so the order",
            "cannot be re-checked (review.missing_times_ok_after_manual: true)"))
  set(missing & handled, "needs_review",
      "in a manual file, but a time is missing after corrections, so the order cannot be re-checked")
  set(missing, "needs_review",
      "not in a manual file, and a time is missing, so the order cannot be re-checked")
  set(fails & handled, "needs_review", "in a manual file but still fails the re-check")
  set(fails, "needs_review", "not in a manual file and still fails the re-check")
  set(rules$step8_flags_need_review & nzchar(step8), "needs_review",
      "passes the re-check but has a Step 8 flag (review.step8_flags_need_review: true)")
  set(handled & applied & legacy, "incorporated",
      "manual decision applied and passes the re-check (legacy row: no record of who/when)")
  set(handled & applied, "incorporated", "manual decision applied and passes the re-check")
  set(handled & !applied, "not_incorporated",
      "in a manual file, but manual corrections were not applied in this run")
  set(rep(TRUE, nrow(out)), "not_incorporated", "passes the re-check on the rules alone; no manual decision")
  out$review_state <- state
  out$review_state_reason <- why

  out <- out[, c(front, setdiff(names(out), front)), drop = FALSE]
  o <- order(match(out$review_state, .review_states),
             match(out$worksheet, c("error", "unusual", "none")),
             as.character(out$pid), suppressWarnings(as.numeric(out$day_num)),
             suppressWarnings(as.numeric(out$row_id)), method = "radix")
  out <- out[o, , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Is the review done, by the user's rule?
#'
#' Counts the rows of a review status table in each state and compares the
#' number of `needs_review` rows with `review.done_when.max_needs_review`. The
#' answer depends only on the table and the config.
#'
#' @param status A review status table (as written to `review_status.csv`), or
#'   NULL for the last run's (from [pipeline_results()]).
#' @param cfg A configuration list, or NULL for the last run's config.
#' @return A list of class `review_verdict` with `done` (TRUE/FALSE), `counts`
#'   (named integer: needs_review, not_incorporated, incorporated), `rule` and
#'   `manual_applied` (NA when not known).
#' @export
review_verdict <- function(status = NULL, cfg = NULL) {
  res <- pipeline_results()
  if (is.null(status)) status <- res$review_status
  if (is.null(cfg)) cfg <- res$pipeline_config
  if (is.null(status)) stop("No review status table: run run_pipeline() first or pass one.", call. = FALSE)
  rules <- review_rules(cfg)
  s <- as.character(status$review_state)
  if (any(!s %in% .review_states))
    stop("review_state must be one of: ", paste(.review_states, collapse = ", "), call. = FALSE)
  counts <- vapply(.review_states, function(x) sum(s == x), integer(1))
  structure(list(
    done = counts[["needs_review"]] <= rules$max_needs_review,
    counts = counts,
    rule = sprintf("done when needs_review <= %s", format(rules$max_needs_review)),
    manual_applied = attr(status, "manual_applied") %||% NA
  ), class = "review_verdict")
}

#' @export
print.review_verdict <- function(x, ...) {
  cat(sprintf("Review %s (%s)\n", if (x$done) "DONE" else "NOT DONE", x$rule))
  for (nm in names(x$counts)) cat(sprintf("  %-17s %d\n", nm, x$counts[[nm]]))
  if (isFALSE(x$manual_applied))
    cat("  Manual corrections were not applied in this run: nothing could be incorporated.\n")
  invisible(x)
}

#' Write the review status table and print the verdict
#' @noRd
write_unified_review_status <- function(ws_list, final, flags, cfg, applied, verbose = TRUE) {
  rules <- review_rules(cfg)
  out <- build_unified_review_status(ws_list, final, flags, rules, applied)
  file <- cfg_get("output.review.status_file", "review_status.csv", cfg = cfg)
  utils::write.csv(out, file, row.names = FALSE, na = "")
  attr(out, "manual_applied") <- applied
  v <- review_verdict(out, cfg)
  .sc_set("review_status", out)
  .sc_set("review_verdict", v)
  if (verbose) {
    cat(sprintf("\n  [review status] %d row(s) in %s\n", nrow(out), file))
    print(v)
  }
  invisible(list(status = out, verdict = v, file = file))
}

# -- Run log -----------------------------------------------------------------

.md5_file <- function(path) {
  if (is.null(path) || length(path) != 1 || is.na(path) || !nzchar(path) || !file.exists(path)) return("")
  unname(tools::md5sum(path))
}

# Hash of the config without data file paths (paths differ between machines;
# the files' contents are hashed separately).
.md5_config <- function(cfg) {
  cfg$data$files <- NULL
  tmp <- tempfile(fileext = ".yaml")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(yaml::as.yaml(cfg), tmp, useBytes = TRUE)
  .md5_file(tmp)
}

#' Append one line for this run to the review run log
#'
#' One file for every run, never a new file per run. Each line records what went
#' in (content hashes of the data, manual files and config) and what came out
#' (hash of the review status table, the counts and the verdict), so two runs can
#' be compared after the environment was deleted and rebuilt.
#' @noRd
append_review_run_log <- function(cfg, status_file, verdict, applied, verbose = TRUE) {
  f <- cfg$data$files
  path <- file.path(cfg_get("output.report.dir", "output", cfg = cfg),
                    cfg_get("output.review.run_log", "review_runs.csv", cfg = cfg))
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  row <- data.frame(
    run_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    sleepcleanr_version = as.character(utils::packageVersion("sleepcleanr")),
    manual_applied = applied,
    data_tag = (.sc_get("data_tag_info") %||% list(tag = ""))$tag,
    data_tag_source = (.sc_get("data_tag_info") %||% list(source = "not needed (no figures)"))$source,
    data_main_md5 = .md5_file(f$main),
    data_extra_md5 = .md5_file(f$extra),
    manual_error_md5 = .md5_file(f$manual_error),
    manual_unusual_md5 = .md5_file(f$manual_unusual),
    manual_nap_exercise_md5 = .md5_file(f$manual_nap_exercise),
    manual_metric_duration_md5 = .md5_file(f$manual_metric_duration),
    manual_metric_accept_md5 = .md5_file(f$manual_metric_accept),
    second_review_md5 = .md5_file(f$second_review),
    config_md5 = .md5_config(cfg),
    review_status_md5 = .md5_file(status_file),
    n_needs_review = verdict$counts[["needs_review"]],
    n_not_incorporated = verdict$counts[["not_incorporated"]],
    n_incorporated = verdict$counts[["incorporated"]],
    done_rule = verdict$rule,
    done = verdict$done,
    stringsAsFactors = FALSE
  )
  new_file <- !file.exists(path)
  utils::write.table(row, path, sep = ",", row.names = FALSE, col.names = new_file,
                     append = !new_file, qmethod = "double")
  if (verbose) {
    cat(sprintf("  [review log] appended this run to %s\n", path))
    if (!new_file) {
      prev <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character"),
                       error = function(e) NULL)
      if (!is.null(prev) && nrow(prev) >= 2) {
        a <- prev[nrow(prev) - 1, ]; b <- prev[nrow(prev), ]
        ins <- setdiff(grep("_md5$", names(prev), value = TRUE), "review_status_md5")
        same_in <- all(a[ins] == b[ins])
        same_out <- identical(a$review_status_md5, b$review_status_md5)
        cat(sprintf("  [review log] vs previous run: inputs %s, review status table %s\n",
                    if (same_in) "identical" else "changed",
                    if (same_out) "identical" else "changed"))
        if (same_in && !same_out)
          cat("  [review log] WARNING: same inputs gave a different review status table.\n")
      }
    }
  }
  invisible(path)
}
