mk_data <- function() {
  data.frame(
    pid = c(1, 2), day_num = c(1, 1), row_id = c(1, 2),
    duration_totalmin_sol_estimate_am_mincalc = c(900, 10.5),
    duration_totalmin_sol_estimate_am_checkforerrors = c(TRUE, TRUE),
    duration_totalmin_sol_estimate_am_correctionsmade = c(NA, "sleep metric duration MM:SS threshold conversion"),
    manually_corrected = FALSE, problem_description = NA_character_,
    stringsAsFactors = FALSE)
}
mk_corr <- function(path) {
  utils::write.csv(data.frame(
    pid = c(1, 2, 3, 1), day_num = c(1, 1, 1, 1), row_id = c(1, 2, 3, 1),
    variable = "duration_totalmin_sol_estimate_am",
    corrected_mincalc = c(15, 3, 7, 20),
    manually_corrected = c(TRUE, TRUE, TRUE, FALSE),
    problem_humanidentified = "p", solution_humanidentified = "s",
    stringsAsFactors = FALSE), path, row.names = FALSE)
}

test_that("every manual row that is not applied is listed with its reason", {
  d <- tempfile("na"); dir.create(d); f <- file.path(d, "corr.csv"); mk_corr(f)
  cfg <- list(data = list(files = list(manual_metric_duration = f)),
              output = list(report = list(dir = file.path(d, "out"))))
  out <- capture.output(res <- sleepcleanr:::apply_sleep_metric_duration_corrections(mk_data(), cfg = cfg))
  na <- utils::read.csv(file.path(d, "out", "manual_corrections_not_applied.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(na), 3)
  expect_setequal(na$reason, c("parser_already_converted_MMSS", "no_unique_row_match",
                               "row_not_marked_manually_corrected"))
  expect_equal(res$duration_totalmin_sol_estimate_am_mincalc[1], 15)     # applied
  expect_equal(res$duration_totalmin_sol_estimate_am_mincalc[2], 10.5)   # parser kept
  expect_true(any(grepl("by reason", out)))
  unlink(d, recursive = TRUE)
})

test_that("the option lets the manual row win over the parser", {
  d <- tempfile("na"); dir.create(d); f <- file.path(d, "corr.csv"); mk_corr(f)
  cfg <- list(data = list(files = list(manual_metric_duration = f)),
              output = list(report = list(dir = file.path(d, "out"))),
              manual_corrections = list(manual_overrides_parser = TRUE))
  invisible(capture.output(res <- sleepcleanr:::apply_sleep_metric_duration_corrections(mk_data(), cfg = cfg)))
  na <- utils::read.csv(file.path(d, "out", "manual_corrections_not_applied.csv"), stringsAsFactors = FALSE)
  expect_false("parser_already_converted_MMSS" %in% na$reason)
  expect_equal(res$duration_totalmin_sol_estimate_am_mincalc[2], 3)
  unlink(d, recursive = TRUE)
})

test_that("the file is written, header only, when every row was applied", {
  d <- tempfile("na"); dir.create(d); f <- file.path(d, "corr.csv")
  utils::write.csv(data.frame(pid = 1, day_num = 1, row_id = 1,
    variable = "duration_totalmin_sol_estimate_am", corrected_mincalc = 15,
    manually_corrected = TRUE, problem_humanidentified = "p", solution_humanidentified = "s"),
    f, row.names = FALSE)
  cfg <- list(data = list(files = list(manual_metric_duration = f)),
              output = list(report = list(dir = file.path(d, "out"))))
  invisible(capture.output(sleepcleanr:::apply_sleep_metric_duration_corrections(mk_data(), cfg = cfg)))
  na <- utils::read.csv(file.path(d, "out", "manual_corrections_not_applied.csv"))
  expect_equal(nrow(na), 0)
  unlink(d, recursive = TRUE)
})
