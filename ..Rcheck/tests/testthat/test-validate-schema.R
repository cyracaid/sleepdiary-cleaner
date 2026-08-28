# input schema validator: loud failure on missing required columns, alias
# tolerance for config-mapped names, and type checking.

.min_cfg <- function(duration_sol = "duration_totalmin_sol_estimate_am") {
  list(
    timestamp = list(ampm = list(enabled = TRUE)),
    column_mapping = list(
      duration = list(sol = duration_sol, waso = "duration_totalmin_waso_estimate_am")
    )
  )
}

.min_df <- function() {
  data.frame(
    pid = 1, day_num = 1,
    time_bed_am_hhmm = "22:00", time_sleep_am_hhmm = "22:30",
    time_awake_am_hhmm = "07:00", time_getup_am_hhmm = "07:30",
    time_bed_am_ampm = "PM", time_sleep_am_ampm = "PM",
    time_awake_am_ampm = "AM", time_getup_am_ampm = "AM",
    duration_totalmin_sol_estimate_am = "15",
    duration_totalmin_waso_estimate_am = "10",
    stringsAsFactors = FALSE
  )
}

test_that("complete frame passes validation", {
  expect_true(validate_schema(.min_df(), .min_cfg()))
})

test_that("missing required SOL stops loudly and names the column", {
  d <- .min_df(); d$duration_totalmin_sol_estimate_am <- NULL
  expect_error(validate_schema(d, .min_cfg()), "sol")
})

test_that("mapped alias satisfies the requirement (MM:SS-era export shape)", {
  # raw export stores SOL under duration_sol_estimate_am_hhmm; config maps it
  d <- .min_df()
  d$duration_totalmin_sol_estimate_am <- NULL
  d$duration_sol_estimate_am_hhmm <- "10:30"
  expect_true(validate_schema(d, .min_cfg(duration_sol = "duration_sol_estimate_am_hhmm")))
})

test_that("row_id is not required as input (pipeline creates it)", {
  d <- .min_df()
  expect_true(validate_schema(d, .min_cfg()))
})

test_that("numeric pid column passes; non-numeric pid fails type check", {
  d <- .min_df(); d$pid <- as.character("A1")
  expect_error(validate_schema(d, .min_cfg()), "pid")
})