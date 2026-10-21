# Rules that decide which records go to human review, and what counts as clean.
#
# These used to be written into the code (7 h, 24 h, 3 h, 15 h) in four places
# that had to be kept in step. They are read from the config here, with the old
# values as the defaults, so one set of numbers is used by Step 5 (which records
# go to the review worksheets), by the recalculation after manual corrections and
# by the category evaluators. A value that is present but is not a single number
# stops the run with a message; it is never replaced silently.

.sc_rule_defaults <- list(
  bed_sleep_error      = 7,   # |sleep - bed| above this many hours is an error
  awake_getup_error    = 7,   # |getup - awake| above this is an error
  sleep_awake_error    = 24,  # |awake - sleep| above this is an error
  sleep_awake_min      = 3,   # sleep period below this is unusual
  sleep_awake_max      = 15,  # sleep period above this is unusual
  bed_sleep_unusual    = 3,   # sleep - bed above this is unusual
  awake_getup_unusual  = 3    # getup - awake above this is unusual
)

# config key under classification.step5 for each rule
.sc_rule_keys <- c(
  bed_sleep_error     = "classification.step5.error.bed_to_sleep_max_hours",
  awake_getup_error   = "classification.step5.error.awake_to_getup_max_hours",
  sleep_awake_error   = "classification.step5.error.sleep_to_awake_max_hours",
  sleep_awake_min     = "classification.step5.unusual.sleep_to_awake_min_hours",
  sleep_awake_max     = "classification.step5.unusual.sleep_to_awake_max_hours",
  bed_sleep_unusual   = "classification.step5.unusual.bed_to_sleep_max_hours",
  awake_getup_unusual = "classification.step5.unusual.awake_to_getup_max_hours"
)

.sc_clean_categories_default <- c("clean", "equal_time_ok", "reasonable_unusual")

.sc_step5_thresholds <- function(cfg = NULL) {
  if (is.null(cfg)) cfg <- .sc_config()
  out <- .sc_rule_defaults
  for (nm in names(.sc_rule_keys)) {
    v <- config_get(cfg, .sc_rule_keys[[nm]], NULL)
    if (is.null(v)) next
    if (!is.numeric(v) || length(v) != 1L || is.na(v))
      stop("Config value ", .sc_rule_keys[[nm]], " must be a single number (hours); got: ",
           paste(format(v), collapse = ", "), call. = FALSE)
    out[[nm]] <- v
  }
  out
}

# The final data_category values that count as "no longer needs a person".
.sc_clean_categories <- function(cfg = NULL) {
  if (is.null(cfg)) cfg <- .sc_config()
  v <- config_get(cfg, "review.clean_categories", NULL)
  if (is.null(v)) return(.sc_clean_categories_default)
  v <- unlist(v)
  if (!is.character(v) || length(v) == 0L || anyNA(v))
    stop("Config value review.clean_categories must be a list of category names", call. = FALSE)
  v
}
