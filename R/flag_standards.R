#' Shared flag-standard evaluators (single source of truth)
#'
#' One place that defines every "final standard" the pipeline judges records
#' against, so ANY step can be evaluated against the SAME criteria. Each
#' evaluator follows the rule:
#'   1. if the authoritative column already exists -> read it (post-step truth,
#'      including human relabels like `reasonable_unusual` and suppressions);
#'   2. else if the prerequisite columns exist -> compute a provisional label;
#'   3. else -> return NA ("not computable at this step").

`%||%` <- function(a, b) if (is.null(a)) b else a

.cfg_num <- function(cfg, path, default) {
  val <- tryCatch(Reduce(function(x, k) x[[k]], strsplit(path, ".", fixed = TRUE)[[1]], cfg),
                  error = function(e) NULL)
  if (is.null(val) || is.na(val)) default else as.numeric(val)
}

.has <- function(df, cols) all(cols %in% names(df))

.diff_h <- function(a, b) as.numeric(difftime(a, b, units = "hours"))

#' Evaluate data_category (temporal classification)
#'
#' Authoritative from Step 5. Categories: clean | error | unusual | equal_time_ok |
#' reasonable_unusual | skipped_na.
#' @export
eval_data_category <- function(df, cfg = NULL) {
  n <- nrow(df)
  if ("data_category" %in% names(df)) return(as.character(df$data_category))

  ts <- c("time_bed_corrected", "time_sleep_corrected",
          "time_awake_corrected", "time_getup_corrected")
  if (!.has(df, ts)) return(rep(NA_character_, n))

  bed <- df$time_bed_corrected; sleep <- df$time_sleep_corrected
  awake <- df$time_awake_corrected; getup <- df$time_getup_corrected

  bed_sleep_diff_h   <- .diff_h(sleep, bed)
  awake_getup_diff_h <- .diff_h(getup, awake)
  sleep_awake_diff_h <- .diff_h(awake, sleep)

  has_na <- is.na(bed) | is.na(sleep) | is.na(awake) | is.na(getup)
  temporal_order_ok <- (bed <= sleep) & (sleep <= awake) & (awake <= getup)

  bed_sleep_equal   <- abs(bed_sleep_diff_h)   < 0.01
  awake_getup_equal <- abs(awake_getup_diff_h) < 0.01
  is_equal_time     <- (bed_sleep_equal | awake_getup_equal) & temporal_order_ok

  sleep_awake_equal_error <- abs(sleep_awake_diff_h) < 0.01
  order_error <- !temporal_order_ok & !sleep_awake_equal_error
  bed_sleep_diff_error   <- abs(bed_sleep_diff_h) > 7 & !order_error & !is_equal_time & !sleep_awake_equal_error
  awake_getup_diff_error <- abs(awake_getup_diff_h) > 7 & !order_error & !bed_sleep_diff_error & !is_equal_time & !sleep_awake_equal_error
  sleep_awake_24h_error  <- abs(sleep_awake_diff_h) > 24 & !order_error & !bed_sleep_diff_error & !awake_getup_diff_error & !is_equal_time & !sleep_awake_equal_error
  is_error <- order_error | bed_sleep_diff_error | awake_getup_diff_error | sleep_awake_24h_error | sleep_awake_equal_error

  bed_sleep_susp   <- bed_sleep_diff_h   > 3 & !is_error & !is_equal_time
  awake_getup_susp <- awake_getup_diff_h > 3 & !is_error & !is_equal_time
  is_unusual <- (bed_sleep_susp | awake_getup_susp) & !is_error & !is_equal_time

  out <- rep("clean", n)
  out[is_unusual]     <- "unusual"
  out[is_equal_time]  <- "equal_time_ok"
  out[is_error]       <- "error"
  out[has_na]         <- "skipped_na"
  out
}

#' Evaluate flag_severity (computed metric flags)
#'
#' Prereq: Step 7 metrics. Clean (0) | Minor issues (1 flag) | Major issues (2+ flags).
#' @export
eval_flag_severity <- function(df, cfg = NULL) {
  n <- nrow(df)
  if ("flag_severity" %in% names(df)) return(as.character(df$flag_severity))
  if (!.has(df, c("sleep_efficiency_pct", "sol_h", "waso_h"))) return(rep(NA_character_, n))

  se_thr   <- .cfg_num(cfg, "classification.flag_severity.poor_efficiency_threshold_pct", 70)
  sol_thr  <- .cfg_num(cfg, "classification.flag_severity.high_sol_threshold_hours", 1)
  waso_thr <- .cfg_num(cfg, "classification.flag_severity.high_waso_threshold_hours", 1.5)

  poor <- ifelse(!is.na(df$sleep_efficiency_pct), df$sleep_efficiency_pct < se_thr, FALSE)
  hsol <- ifelse(!is.na(df$sol_h),  df$sol_h  > sol_thr,  FALSE)
  hwas <- ifelse(!is.na(df$waso_h), df$waso_h > waso_thr, FALSE)
  cnt  <- poor + hsol + hwas
  out <- ifelse(cnt == 0, "Clean",
         ifelse(cnt == 1, "Minor issues (1 flag)", "Major issues (2+ flags)"))
  out
}

#' Evaluate duration_extreme (separate from severity count)
#' @export
eval_duration_extreme <- function(df, cfg = NULL) {
  n <- nrow(df)
  if (!("sleep_duration_h" %in% names(df))) return(rep(NA_character_, n))
  ifelse(is.na(df$sleep_duration_h), NA_character_,
    ifelse(df$sleep_duration_h < 3,  "Too short (<3h)",
    ifelse(df$sleep_duration_h > 12, "Too long (>12h)", "OK")))
}

#' Evaluate checkforerrors (auto-detection flags)
#'
#' Prereq: Step 8. TIMESTAMP_ISSUE | DURATION_ISSUE | AMOUNT_FLAG |
#' SELF_REPORTED_FLAG | CLEAN | NEEDS_REVIEW.
#' @export
eval_checkforerrors <- function(df, cfg = NULL) {
  n <- nrow(df)
  for (col in c("checkforerrors_summary", "raw_category")) {
    if (col %in% names(df)) return(as.character(df[[col]]))
  }
  if ("needs_review_flag" %in% names(df)) {
    return(ifelse(isTRUE(df$needs_review_flag) | df$needs_review_flag %in% TRUE,
                  "NEEDS_REVIEW", "CLEAN"))
  }
  rep(NA_character_, n)
}

#' Evaluate field_misentry (cross-participant field misentry, Step 1.5)
#' @export
eval_field_misentry <- function(df, cfg = NULL) {
  n <- nrow(df)
  need <- c("duration_totalmin_sol_estimate_am", "duration_totalmin_waso_estimate_am",
            "time_sleep_am_hhmm", "time_bed_am_hhmm",
            "time_awake_am_hhmm", "time_getup_am_hhmm")
  if (!.has(df, need)) return(rep(NA_character_, n))
  sol <- as.character(df$duration_totalmin_sol_estimate_am)
  was <- as.character(df$duration_totalmin_waso_estimate_am)
  mis_sol_sleep <- !is.na(sol) & sol == as.character(df$time_sleep_am_hhmm)
  mis_sol_bed   <- !is.na(sol) & sol == as.character(df$time_bed_am_hhmm)
  mis_waso_awake<- !is.na(was) & was == as.character(df$time_awake_am_hhmm)
  mis_waso_getup<- !is.na(was) & was == as.character(df$time_getup_am_hhmm)
  ifelse(mis_sol_sleep, "SOL=time_sleep",
    ifelse(mis_sol_bed, "SOL=time_bed",
    ifelse(mis_waso_awake, "WASO=time_awake",
    ifelse(mis_waso_getup, "WASO=time_getup", "none"))))
}

#' Evaluate ALL standards, returning per-record label data frame.
#' @export
evaluate_all_standards <- function(df, cfg = NULL) {
  data.frame(
    data_category    = eval_data_category(df, cfg),
    flag_severity    = eval_flag_severity(df, cfg),
    duration_extreme = eval_duration_extreme(df, cfg),
    checkforerrors   = eval_checkforerrors(df, cfg),
    field_misentry   = eval_field_misentry(df, cfg),
    stringsAsFactors = FALSE
  )
}

#' Fixed category vocabularies for the ledger
STANDARD_LEVELS <- list(
  data_category  = c("clean", "unusual", "reasonable_unusual", "equal_time_ok",
                     "error", "skipped_na"),
  flag_severity  = c("Clean", "Minor issues (1 flag)", "Major issues (2+ flags)"),
  duration_extreme = c("OK", "Too short (<3h)", "Too long (>12h)"),
  checkforerrors = c("CLEAN", "NEEDS_REVIEW", "TIMESTAMP_ISSUE", "DURATION_ISSUE",
                     "AMOUNT_FLAG", "SELF_REPORTED_FLAG"),
  field_misentry = c("none", "SOL=time_sleep", "SOL=time_bed",
                     "WASO=time_awake", "WASO=time_getup")
)

#' Tally one standard's labels into a fixed-level count vector.
#' Returns all-NA (named by levels) if the label vector is entirely NA.
tally_standard <- function(labels, levels) {
  if (all(is.na(labels))) return(setNames(rep(NA_integer_, length(levels)), levels))
  tab <- table(factor(labels, levels = levels))
  setNames(as.integer(tab), levels)
}
