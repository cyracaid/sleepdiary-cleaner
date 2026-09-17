# Tests: data-first API (clean_sleep_diary) + column auto-guess + invariants
# =============================================================================

# ---- guess_column_mapping: decisions are recorded, never silent -------------
test_that("guess_column_mapping matches common synonyms with exact rules", {
  g <- guess_column_mapping(c("subject", "day", "bedtime", "sleep_onset", "wakeup",
                              "getup", "sol", "waso"))
  dec <- g$decisions
  expect_equal(dec$internal_col[which(dec$user_col == "subject")], "pid")
  expect_equal(dec$internal_col[which(dec$user_col == "day")], "day_num")
  expect_equal(dec$internal_col[which(dec$user_col == "bedtime")], "time_bed_hhmm")
  expect_equal(dec$internal_col[which(dec$user_col == "sleep_onset")], "time_sleep_hhmm")
  expect_equal(dec$internal_col[which(dec$user_col == "wakeup")], "time_awake_hhmm")
  expect_equal(dec$internal_col[which(dec$user_col == "getup")], "time_getup_hhmm")
  expect_equal(dec$internal_col[which(dec$user_col == "sol")], "sol")
  expect_equal(dec$internal_col[which(dec$user_col == "waso")], "waso")
  expect_true(all(dec$status[dec$internal_col %in% c("pid","sol")] == "matched"))
  expect_true(all(dec$match_rule[dec$confidence == 1] == "exact_name"))
})

test_that("guess_column_mapping records absent required fields (fail-loud)", {
  g <- guess_column_mapping(c("subject", "day", "bedtime"))
  dec <- g$decisions
  expect_true("sol" %in% dec$internal_col[dec$status == "absent"])
  expect_true("waso" %in% dec$internal_col[dec$status == "absent"])
  expect_true("time_awake_hhmm" %in% dec$internal_col[dec$status == "absent"])
  # nothing silently mapped for absent fields
  expect_null(g$mapping$duration$sol)
})

test_that("guess_column_mapping marks ambiguous ties, never silently picks", {
  g <- guess_column_mapping(c("bedtime", "bed_time", "sleep_onset", "sol"))
  dec <- g$decisions
  amb <- dec[dec$status == "ambiguous", ]
  expect_true(all(amb$user_col %in% c("bedtime", "bed_time")))
  expect_true(grepl("bedtime", amb$candidate_set[1]))
  expect_null(g$mapping$timestamp$time_bed_hhmm)
})

# ---- clean_sleep_diary: dry-run writes nothing but the dry-run manifest ------
test_that("clean_sleep_diary dry_run stops before cleaning, writes dry-run manifest only", {
  d <- system.file("extdata", "synthetic_sleep_data.rds", package = "sleepcleanr")
  tmp <- tempfile("csd_dry"); dir.create(tmp)
  res <- clean_sleep_diary(d, dry_run = TRUE, project_dir = tmp)
  expect_null(res$cleaned)
  expect_true(is.data.frame(res$guesses) || nrow(res$guesses) == 0)
  expect_true("dry_run_manifest_json" %in% names(res$outputs))
  expect_true(file.exists(res$outputs$dry_run_manifest_json))
  # no cleaned dataset, no run manifest
  expect_false(file.exists(file.path(tmp, "output", "cleaned_data_final.csv")))
  expect_false(any(grepl("^run_manifest", list.files(file.path(tmp, "output"), all.files = TRUE))))
  # raw input untouched
  expect_true(file.exists(d))
})

# ---- clean_sleep_diary: full run returns the 6-field contract ---------------
test_that("clean_sleep_diary full run returns 6-field contract with manifest", {
  d <- system.file("extdata", "synthetic_sleep_data.rds", package = "sleepcleanr")
  tmp <- tempfile("csd_run"); dir.create(tmp)
  res <- clean_sleep_diary(d, project_dir = tmp, skip_visualization = TRUE)
  expect_true(is.data.frame(res$cleaned))
  expect_true(nrow(res$cleaned) > 0)
  expect_true(is.list(res$config))
  expect_true(is.data.frame(res$guesses))
  expect_true(is.data.frame(res$ledger))
  expect_true(all(c("cleaned_csv", "ledger_csv", "manifest_json") %in% names(res$outputs)))
  expect_true(is.list(res$manifest))
  expect_true(all(c("package_version", "commit", "timestamp_utc", "input", "environment",
                    "config", "steps", "outputs") %in% names(res$manifest)))
  expect_true(file.exists(res$outputs$manifest_json))
  # hash identity present; path is auxiliary
  expect_true(nchar(res$manifest$input$md5) == 32)
  expect_true(isTRUE(res$manifest$input$path_recorded))
  # manifest json is valid
  m <- jsonlite::fromJSON(res$outputs$manifest_json)
  expect_true(is.list(m$input))
})

test_that("clean_sleep_diary data.frame input works and never touches raw", {
  df <- data.frame(
    subject = c(1,1,1,1,1,1,1,2,2,2,2,2,2,2),
    day = c(1,2,3,4,5,6,7,1,2,3,4,5,6,7),
    bedtime = c("22:00","23:00","21:00","22:30","23:30","22:00","21:30","22:00","23:00","21:00","22:30","23:30","22:00","21:30"),
    bedtime_ampm = rep("PM", 14),
    sleep_onset = c("22:30","23:30","21:30","23:00","00:00","22:30","22:00","22:30","23:30","21:30","23:00","00:00","22:30","22:00"),
    sleep_ampm = rep("PM", 14),
    wakeup = c("06:00","07:00","05:30","06:30","07:30","06:00","05:00","06:00","07:00","05:30","06:30","07:30","06:00","05:00"),
    wakeup_ampm = rep("AM", 14),
    getup = c("06:30","07:30","06:00","07:00","08:00","06:30","05:30","06:30","07:30","06:00","07:00","08:00","06:30","05:30"),
    getup_ampm = rep("AM", 14),
    sol = c(30,45,20,25,40,35,50,30,45,20,25,40,35,50),
    waso = c(15,10,25,20,5,30,12,15,10,25,20,5,30,12),
    StartDate = rep("2026-01-01", 14),
    duration_totalmin_napstoday_PM = rep(0, 14),
    caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1 = rep(0, 14),
    alcoholtoday_PM_NumAlcoholicDrinks_1 = rep(0, 14),
    nicotine_amount_pm_doses = rep(0, 14),
    cannabis_amount_pm_doses = rep(0, 14),
    stringsAsFactors = FALSE)
  raw_before <- df
  tmp <- tempfile("csd_df"); dir.create(tmp)
  res <- clean_sleep_diary(df, project_dir = tmp, skip_visualization = TRUE)
  expect_identical(df, raw_before)   # raw input never modified
  expect_true(is.data.frame(res$cleaned))
  expect_false(res$manifest$input$path_recorded)  # in-memory: path is NA/auxiliary
  expect_true(is.na(res$manifest$input$path))
})

# ---- run_pipeline(data = NULL) invariant: zero change vs no-data call --------
test_that("run_pipeline data=NULL is invariant (identical outputs to old call)", {
  d <- system.file("extdata", "synthetic_sleep_data.rds", package = "sleepcleanr")
  cfg0 <- file.path(system.file("extdata", package = "sleepcleanr"), "synthetic_config.yaml")
  a <- tempfile("inv_a"); b <- tempfile("inv_b")
  dir.create(a); dir.create(b)
  # copy fixture + rewrite config with sandbox-relative paths (same pattern as
  # test-pipeline.R) so both runs resolve inputs against their project_dir
  for (f in c("synthetic_sleep_data.rds", "synthetic_ema_data.csv")) {
    file.copy(file.path(dirname(cfg0), f), a, overwrite = TRUE)
    file.copy(file.path(dirname(cfg0), f), b, overwrite = TRUE)
  }
  cfg <- yaml::read_yaml(cfg0)
  cfg$data$files$main  <- "synthetic_sleep_data.rds"
  cfg$data$files$extra <- "synthetic_ema_data.csv"
  yaml::write_yaml(cfg, file.path(a, "config.yaml"))
  yaml::write_yaml(cfg, file.path(b, "config.yaml"))
  run_pipeline(config = file.path(a, "config.yaml"), project_dir = a, skip_visualization = TRUE)
  run_pipeline(config = file.path(b, "config.yaml"), project_dir = b, skip_visualization = TRUE, data = NULL)
  fa <- file.path(a, "output", "cleaned_data_final.csv")
  fb <- file.path(b, "output", "cleaned_data_final.csv")
  la <- file.path(a, "output", "step_flag_ledger.csv")
  lb <- file.path(b, "output", "step_flag_ledger.csv")
  expect_true(file.exists(fa) && file.exists(fb))
  expect_identical(read.csv(fa), read.csv(fb))
  expect_identical(read.csv(la), read.csv(lb))
})