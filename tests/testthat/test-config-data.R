context("Config — data.files.main/extra and column mapping")

test_that("main: RDS without extra works", {
  skip_if_not_installed("yaml")
  tmp   <- file.path(tempdir(), "test_config")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE))

  # Create a minimal RDS with required columns
  df <- data.frame(
    pid = 1:3, day_num = 1:3,
    time_bed_am_hhmm    = c("22:30", "23:00", "21:45"),
    time_bed_am_ampm    = c("PM", "PM", "PM"),
    time_sleep_am_hhmm  = c("23:00", "23:30", "22:00"),
    time_sleep_am_ampm  = c("PM", "PM", "PM"),
    time_awake_am_hhmm  = c("06:30", "07:00", "05:45"),
    time_awake_am_ampm  = c("AM", "AM", "AM"),
    time_getup_am_hhmm  = c("07:00", "07:30", "06:15"),
    time_getup_am_ampm  = c("AM", "AM", "AM"),
    duration_totalmin_sol_estimate_am  = c(30, 30, 15),
    duration_totalmin_waso_estimate_am = c(10, 5, 0),
    StartDate = c("2026-01-01", "2026-01-02", "2026-01-03"),
    num_waso_estimate_am = c(1, 2, 0),
    stringsAsFactors = FALSE
  )
  saveRDS(df, file.path(tmp, "main.rds"))

  # Config: main only, no extra
  cfg <- list(
    pipeline = list(name = "test"),
    data = list(files = list(
      main  = file.path(tmp, "main.rds"),
      extra = ""
    ))
  )

  result <- splsleep:::load_config(NULL)
  # Verify key resolution via .resolve_data_key
  main_val <- splsleep:::.resolve_data_key(cfg, "data.files.main")
  extra_val <- splsleep:::.resolve_data_key(cfg, "data.files.extra")
  expect_true(file.exists(main_val))
  expect_equal(extra_val, NULL)
})

test_that("main: CSV (not RDS) is detected and loaded", {
  skip_if_not_installed("yaml")
  tmp   <- file.path(tempdir(), "test_config_csv")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE))

  df <- data.frame(
    pid = 1:2, day_num = 1:2,
    time_bed_am_hhmm = c("22:30", "23:00"),
    time_bed_am_ampm = c("PM", "PM"),
    time_sleep_am_hhmm = c("23:00", "23:30"),
    time_sleep_am_ampm = c("PM", "PM"),
    time_awake_am_hhmm = c("06:30", "07:00"),
    time_awake_am_ampm = c("AM", "AM"),
    time_getup_am_hhmm = c("07:00", "07:30"),
    time_getup_am_ampm = c("AM", "AM"),
    duration_totalmin_sol_estimate_am = c(30, 30),
    duration_totalmin_waso_estimate_am = c(10, 5),
    stringsAsFactors = FALSE
  )
  write.csv(df, file.path(tmp, "main.csv"), row.names = FALSE)

  # CSV auto-detection check
  is_csv <- grepl("\\.csv$", file.path(tmp, "main.csv"), ignore.case = TRUE)
  expect_true(is_csv)
})

test_that("main RDS + extra CSV merges correctly", {
  skip_if_not_installed("yaml")
  tmp   <- file.path(tempdir(), "test_config_extra")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE))

  df_main <- data.frame(
    pid = 1:3, day_num = 1:3,
    time_bed_am_hhmm = c("22:30", "23:00", "21:45"),
    time_bed_am_ampm = c("PM", "PM", "PM"),
    time_sleep_am_hhmm = c("23:00", "23:30", "22:00"),
    time_sleep_am_ampm = c("PM", "PM", "PM"),
    time_awake_am_hhmm = c("06:30", "07:00", "05:45"),
    time_awake_am_ampm = c("AM", "AM", "AM"),
    time_getup_am_hhmm = c("07:00", "07:30", "06:15"),
    time_getup_am_ampm = c("AM", "AM", "AM"),
    duration_totalmin_sol_estimate_am = c(30, 30, 15),
    duration_totalmin_waso_estimate_am = c(10, 5, 0),
    stringsAsFactors = FALSE
  )
  saveRDS(df_main, file.path(tmp, "main.rds"))

  df_extra <- data.frame(
    StartDate = c("2026-01-01", "2026-01-02", "2026-01-03"),
    num_waso = c(1, 2, 0),
    num_waso_estimate_am = c(1, 2, 0),
    stringsAsFactors = FALSE
  )
  write.csv(df_extra, file.path(tmp, "extra.csv"), row.names = FALSE)

  cfg <- list(
    pipeline = list(name = "test"),
    data = list(files = list(
      main  = file.path(tmp, "main.rds"),
      extra = file.path(tmp, "extra.csv")
    ))
  )

  main_val <- splsleep:::.resolve_data_key(cfg, "data.files.main")
  extra_val <- splsleep:::.resolve_data_key(cfg, "data.files.extra")
  expect_true(file.exists(main_val))
  expect_true(file.exists(extra_val))
})

test_that("legacy main_rds / main_csv keys still work", {
  skip_if_not_installed("yaml")
  cfg <- list(
    pipeline = list(name = "test"),
    data = list(files = list(
      main_rds = "/path/to/old.rds",
      main_csv = ""
    ))
  )
  # Legacy fallback in .resolve_data_key
  main_val <- splsleep:::.resolve_data_key(cfg, "data.files.main")
  extra_val <- splsleep:::.resolve_data_key(cfg, "data.files.extra")
  expect_equal(main_val, "/path/to/old.rds")
  expect_equal(extra_val, NULL)
})

test_that("missing file gives friendly error", {
  cfg <- list(
    pipeline = list(name = "test"),
    data = list(files = list(main = "/nonexistent/path.rds", extra = ""))
  )
  err <- tryCatch({
    if (!file.exists(cfg$data$files$main)) {
      stop(sprintf("Cannot find your data file: %s", cfg$data$files$main))
    }
  }, error = function(e) e$message)
  expect_match(err, "Cannot find your data file")
})

test_that("column mapping transforms user columns to internal names", {
  skip_if_not_installed("yaml")
  df <- data.frame(
    subj_id = 1:3,
    study_day = 1:3,
    bed_time = c("22:30", "23:00", "21:45"),
    bed_ampm = c("PM", "PM", "PM"),
    stringsAsFactors = FALSE
  )
  cfg <- list(
    column_mapping = list(
      identifiers = list(pid = "subj_id", day_num = "study_day"),
      timestamp   = list(time_bed_hhmm = "bed_time", time_bed_ampm = "bed_ampm")
    )
  )
  result <- splsleep::adapt_columns(df, cfg)
  expect_true("pid" %in% names(result))
  expect_true("day_num" %in% names(result))
  expect_true("time_bed_am_hhmm" %in% names(result))
  expect_true("time_bed_am_ampm" %in% names(result))
  expect_false("subj_id" %in% names(result))
  expect_false("bed_time" %in% names(result))
})
