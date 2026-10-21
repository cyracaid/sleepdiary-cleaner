# Step 5 reads its limits from the config: the same three nights are classified
# differently when the user changes a limit, and an invalid limit stops the run.

step5_counts <- function(cfg) {
  td <- tempfile("s5"); dir.create(td); old <- setwd(td)
  on.exit({ setwd(old); unlink(td, recursive = TRUE) }, add = TRUE)
  src <- system.file("scripts", "generate_correction_files.R", package = "sleepcleanr")
  if (!nzchar(src)) src <- file.path(testthat::test_path("..", ".."), "inst", "scripts", "generate_correction_files.R")
  env <- new.env(parent = asNamespace("sleepcleanr"))
  sys.source(src, envir = env)
  t0 <- as.POSIXct("2026-01-01 22:00:00", tz = "UTC")
  mk <- function(gap_h) {
    s <- t0 + gap_h * 3600
    data.frame(time_bed_corrected = t0, time_sleep_corrected = s,
               time_awake_corrected = s + 7 * 3600, time_getup_corrected = s + 7 * 3600 + 600,
               time_bed_am_hhmm_ampm = "10:00 PM", time_sleep_am_hhmm_ampm = "x",
               time_awake_am_hhmm_ampm = "x", time_getup_am_hhmm_ampm = "x",
               stringsAsFactors = FALSE)
  }
  d <- do.call(rbind, lapply(c(1, 4, 8), mk))
  d$pid <- 1:3; d$day_num <- 1L; d$row_id <- 1:3
  for (n in c("time_bed_am_checkforerrors", "time_sleep_am_checkforerrors",
              "time_awake_am_checkforerrors", "time_getup_am_checkforerrors"))
    d[[n]] <- NA_character_
  d$corrected <- FALSE; d$correction_type <- NA_character_
  invisible(capture.output(r <- env$generate_correction_files(d, cfg = cfg)))
  c(error = nrow(r$error_df_pre), unusual = nrow(r$unusual_df_pre))
}

test_that("Step 5 uses the default limits when the config says nothing", {
  expect_equal(step5_counts(list()), c(error = 1, unusual = 1))   # 8 h is an error, 4 h unusual
})

test_that("Step 5 follows a changed limit", {
  loose <- list(classification = list(step5 = list(unusual = list(bed_to_sleep_max_hours = 5))))
  strict <- list(classification = list(step5 = list(error = list(bed_to_sleep_max_hours = 3))))
  expect_equal(step5_counts(loose), c(error = 1, unusual = 0))
  expect_equal(step5_counts(strict), c(error = 2, unusual = 0))
})

test_that("Step 5 stops on an invalid limit instead of ignoring it", {
  bad <- list(classification = list(step5 = list(error = list(bed_to_sleep_max_hours = "x"))))
  expect_error(step5_counts(bad), "must be a single number")
})
