#' Canonical input schema validator
#'
#' Single source of truth for raw input columns. Call right after
#' adapt_columns() so missing/misnamed columns fail loudly.
#'
#' Design: each schema entry is a LOGICAL field resolved through the config
#' column_mapping. The validator accepts EITHER the mapped internal key OR the
#' raw default name, tolerating the current config-key vs hardcoded-name mismatch.
#' @export
validate_schema <- function(data, config, label = "raw EMA input (post-adaptation)") {
  SCHEMA <- list(
    list(field = "pid",            default = "pid",                                  type = "numeric",   required = TRUE),
    list(field = "day_num",        default = "day_num",                              type = "numeric",   required = TRUE),
    # row_id is created by the pipeline, not required as input
    list(field = "time_bed_hhmm",  default = "time_bed_am_hhmm",                      type = "any", required = TRUE),
    list(field = "time_sleep_hhmm", default = "time_sleep_am_hhmm",                    type = "any", required = TRUE),
    list(field = "time_awake_hhmm",default = "time_awake_am_hhmm",                   type = "any", required = TRUE),
    list(field = "time_getup_hhmm",default = "time_getup_am_hhmm",                   type = "any", required = TRUE),
    list(field = "time_bed_ampm",  default = "time_bed_am_ampm",                     type = "any", required = "ampm"),
    list(field = "time_sleep_ampm",default = "time_sleep_am_ampm",                   type = "any", required = "ampm"),
    list(field = "time_awake_ampm",default = "time_awake_am_ampm",                   type = "any", required = "ampm"),
    list(field = "time_getup_ampm",default = "time_getup_am_ampm",                   type = "any", required = "ampm"),
    list(field = "sol",            default = "duration_totalmin_sol_estimate_am",    type = "any", required = TRUE),
    list(field = "waso",           default = "duration_totalmin_waso_estimate_am",   type = "any", required = TRUE),
    list(field = "date_bed",       default = "StartDate",                            type = "any", required = FALSE),
    list(field = "waso_count",     default = "num_waso_estimate_am",                 type = "any",   required = FALSE),
    list(field = "nap",            default = "duration_totalmin_napstoday_PM",       type = "any",   required = FALSE),
    list(field = "caffeine",       default = "caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1", type = "any", required = FALSE),
    list(field = "alcohol",        default = "alcoholtoday_PM_NumAlcoholicDrinks_1",  type = "any",   required = FALSE)
  )

  uses_ampm <- isTRUE(tryCatch(config_get(config, "timestamp")$ampm$enabled, error = function(e) TRUE))

  resolve_name <- function(field, default, cfg) {
    mapping <- tryCatch(config_get(cfg, "column_mapping", list()), error = function(e) list())
    for (section in names(mapping)) {
      if (field %in% names(mapping[[section]])) {
        val <- mapping[[section]][[field]]
        if (!is.null(val) && !is.na(val) && nzchar(val)) return(val)
      }
    }
    default
  }

  req_list <- list(); opt_list <- list(); type_spec <- list()
  for (s in SCHEMA) {
    is_req <- if (identical(s$required, "ampm")) uses_ampm else isTRUE(s$required)
    candidates <- unique(c(s$field, resolve_name(s$field, s$default, config), s$default))
    if (is_req) req_list[[s$field]] <- candidates
    else        opt_list[[s$field]] <- candidates
    for (cand in candidates) if (cand %in% names(data)) type_spec[[cand]] <- s$type
  }

  missing_req <- names(req_list)[!vapply(req_list, function(cand) any(cand %in% names(data)), logical(1))]
  if (length(missing_req) > 0) {
    details <- vapply(missing_req, function(f) {
      sprintf("  - %-16s (expected one of: %s)", f, paste(req_list[[f]], collapse = " | "))
    }, character(1))
    stop(sprintf("Schema validation FAILED for %s.\n%s required column(s) missing:\n%s\nFix column_mapping in config.",
                 label, length(missing_req), paste(details, collapse = "\n")), call. = FALSE)
  }

  missing_opt <- names(opt_list)[!vapply(opt_list, function(cand) any(cand %in% names(data)), logical(1))]
  if (length(missing_opt) > 0) {
    warning(sprintf("%s: optional columns missing (features skipped): %s", label, paste(missing_opt, collapse = ", ")), call. = FALSE)
  }
  if (length(type_spec) > 0) validate_column_types(data, type_spec, label = label)
  invisible(TRUE)
}
