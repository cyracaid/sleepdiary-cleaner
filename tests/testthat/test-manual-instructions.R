# Instructions in the manual files that the correction engine cannot read are
# reported (console and review_status.csv), never skipped in silence.

test_that("values the engine reads are recognised, others are named", {
  ok <- c("Same day 10:00:00 AM", "Same day 22:30", "Minus 12 hours", "Plus 12 hours",
          "10:00", "10:00:00", "2022-01-15 06:00:00", "2022-01-15 06:00", NA, "")
  for (v in ok) expect_equal(sleepcleanr:::manual_value_problem(v), "", info = v)
  expect_match(sleepcleanr:::manual_value_problem("Set time_awake equal to time_getup"),
               "value not understood")
  expect_match(sleepcleanr:::manual_value_problem("15/01/2022 06:00"), "value not understood")
})

test_that("column names must be the full corrected names", {
  expect_equal(sleepcleanr:::manual_column_problem("time_bed_corrected, time_sleep_corrected"), "")
  expect_match(sleepcleanr:::manual_column_problem("time_bed, time_sleep"),
               "column name not understood: time_bed, time_sleep")
  expect_match(sleepcleanr:::manual_column_problem("time_bed_corrected, time_sleep"),
               "not understood: time_sleep \\(")
})

test_that("text instructions are recognised by the phrases the engine reads", {
  ok <- c("Undo correction", "Bed time AM/PM conversion", "Perform sleep-awake switch",
          "awake/getup switch", "Change sleep time into 23:30", "Minus 12 hours",
          "Align awake time's hour to getup time's hour", "perform awake-getup swap")
  for (t in ok) expect_equal(sleepcleanr:::manual_text_problem(t), "", info = t)
  expect_match(sleepcleanr:::manual_text_problem("Swap awake/getup corrected values"),
               "no instruction recognised")
})

test_that("a full date-time value sets the time", {
  t0 <- as.POSIXct("2022-01-15 10:45:00", tz = "UTC")
  expect_equal(sleepcleanr:::apply_time_instruction_case3(t0, "2022-01-15 06:00:00"),
               as.POSIXct("2022-01-15 06:00:00", tz = "UTC"))
  expect_equal(sleepcleanr:::apply_time_instruction_case3(t0, "2022-01-14 23:05"),
               as.POSIXct("2022-01-14 23:05:00", tz = "UTC"))
})

test_that("every unreadable instruction in the manual files is listed", {
  err <- data.frame(
    pid = c(1, 2, 3, 4, 5), day_num = c(1, 2, 3, 4, 5), row_id = c(11, 12, 13, 14, 15),
    solution_humanidentified = c("", "", "Swap awake/getup corrected values", "Perform sleep-awake switch", ""),
    column_to_correct = c("time_bed, time_sleep", "time_awake_corrected", "", "", "time_awake_corrected"),
    correct_value = c("Minus 12 hours", "Set time_awake equal to time_getup", "", "", "Same day 08:00"),
    column_to_correct_2 = c("", "time_getup_corrected", "", "", ""),
    correct_value_2 = c("", "2022-01-15 10:45:00", "", "", ""),
    stringsAsFactors = FALSE)
  unu <- data.frame(pid = 6, day_num = 6, row_id = 16,
    problem_humanidentified = "Manual unusual: check", column_to_adjust = "time_sleep",
    correction_value = "Minus 12 hours", stringsAsFactors = FALSE)
  p <- sleepcleanr:::manual_instruction_problems(err, unu)
  expect_equal(sort(paste(p$pid, p$field)),
               sort(c("1 column_to_correct", "2 correct_value", "3 solution_humanidentified",
                      "6 column_to_adjust")))
  expect_equal(p$file[p$pid == "6"], "manual_unusual_corrections")
  expect_equal(nrow(sleepcleanr:::manual_instruction_problems(err[4:5, ], NULL)), 0)
  expect_equal(nrow(sleepcleanr:::manual_instruction_problems(data.frame(), NULL)), 0)
})

test_that("a record with an unreadable instruction is needs_review with the reason", {
  ws <- data.frame(pid = c(1, 2), day_num = c(1, 2), row_id = c(11, 12),
                   in_manual_file = c("m.csv", "m.csv"), review_resolution = c("corrected", "corrected"),
                   resolved_at = "", resolved_by = "", stringsAsFactors = FALSE)
  final <- data.frame(pid = c(1, 2), day_num = c(1, 2), row_id = c(11, 12),
                      data_category = c("clean", "clean"), stringsAsFactors = FALSE)
  nu <- data.frame(file = "manual_error_corrections", pid = "1", day_num = "1", row_id = "11",
                   field = "column_to_correct", value = "time_bed",
                   problem = "column name not understood: time_bed", stringsAsFactors = FALSE)
  out <- sleepcleanr:::build_unified_review_status(list(error = ws), final, applied = TRUE,
                                                   not_understood = nu)
  expect_equal(out$review_state[out$row_id == 11], "needs_review")
  expect_match(out$review_state_reason[out$row_id == 11], "not understood and skipped: column_to_correct")
  expect_equal(out$review_state[out$row_id == 12], "incorporated")
  # not applied: nothing was read, nothing to report
  out2 <- sleepcleanr:::build_unified_review_status(list(error = ws), final, applied = FALSE,
                                                    not_understood = nu)
  expect_false(any(grepl("not understood", out2$review_state_reason)))
})
