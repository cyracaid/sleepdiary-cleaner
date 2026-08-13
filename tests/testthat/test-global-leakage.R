# test-global-leakage.R — assert the legacy chain writes only its protocol objects.
#
# The source()d scripts (00_MAIN_entry.R + step scripts) share data through
# .GlobalEnv by design: pipeline_config / splsleep_scripts_dir / corrected_ema_data
# / review_output / checkforerrors_summary / reasonable_unusual_df are the
# explicit assign() protocol, and a handful of top-level working objects
# (clean_df, error_df, ...) are the legacy chain's accepted data-passing style.
#
# What this test guards against: a refactor that silently adds a NEW global
# (stray counter, leftover temporary, or an object that should have been local
# to a step) without it being an intentional part of the contract. The
# whitelist is the frozen contract; anything outside it fails.

test_that("legacy chain writes only protocol globals", {
  cfg_path <- system.file("extdata", "synthetic_config.yaml", package = "splsleep")
  if (cfg_path == "") cfg_path <- file.path(getwd(), "inst", "extdata", "synthetic_config.yaml")
  skip_if_not(file.exists(cfg_path), "synthetic_config.yaml not found")

  sandbox <- tempfile("splleak_")
  dir.create(sandbox, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(sandbox, recursive = TRUE, force = TRUE), add = TRUE)

  src_data <- dirname(cfg_path)
  file.copy(file.path(src_data, "synthetic_sleep_data.rds"), sandbox, overwrite = TRUE)
  file.copy(file.path(src_data, "synthetic_ema_data.csv"), sandbox, overwrite = TRUE)
  cfg <- yaml::read_yaml(cfg_path)
  cfg$data$files$main  <- "synthetic_sleep_data.rds"
  cfg$data$files$extra <- "synthetic_ema_data.csv"
  yaml::write_yaml(cfg, file.path(sandbox, "pipeline_config.yaml"))

  scripts_dir <- dirname(list.files(
    c("inst/scripts", system.file("scripts", package = "splsleep")),
    pattern = "^00_MAIN_entry\\.R$", full.names = TRUE, recursive = TRUE
  )[1])

  whitelist <- c(
    "pipeline_config", "splsleep_scripts_dir", "splsleep_loaded",
    "corrected_ema_data", "ema_data_release_timecalc", "review_output",
    "checkforerrors_summary", "reasonable_unusual_df", "multi_process",
    # error_unusual publishes its result set via list2env(..., .GlobalEnv):
    "equal_time_df", "error_df", "unusual_df", "clean_df", "correction_summary",
    "substance_decimal_anomalies", "checkforerrors_processed",
    "raw_csv_data", "data_with_flags_local"
  )

  runner <- tempfile("splleak_run_", fileext = ".R")
  writeLines(c(
    "suppressMessages(pkgload::load_all(getwd(), quiet = TRUE))",
    sprintf("setwd(%s)", shQuote(sandbox)),
    sprintf("assign('splsleep_scripts_dir', %s, envir = .GlobalEnv)", shQuote(scripts_dir)),
    "assign('pipeline_config', yaml::read_yaml('pipeline_config.yaml'), envir = .GlobalEnv)",
    "base0 <- ls(globalenv())",
    "res <- tryCatch({",
    "  suppressMessages(suppressWarnings(source(file.path(get0('splsleep_scripts_dir'), '00_MAIN_entry.R'), local = FALSE)))",
    "  TRUE",
    "}, error = function(e) e)",
    "if (!isTRUE(res)) { cat('LEAK_FAIL:', conditionMessage(res), '\n'); quit(status = 1) }",
    "leaks <- setdiff(setdiff(ls(globalenv()), base0), c('res', 'base0'))",
    "cat('LEAKED:', paste(leaks, collapse = ' | '), '\n')",
    "quit(status = 0)"
  ), runner, useBytes = TRUE)

  out <- system2(file.path(R.home("bin"), "Rscript"), shQuote(runner),
                 stdout = TRUE, stderr = TRUE)
  unlink(runner)

  expect_false(any(grepl("LEAK_FAIL", out)),
               paste(c("legacy chain errored:", out), collapse = "\n"))

  leaked_line <- grep("^LEAKED:", out, value = TRUE)
  leaked <- if (length(leaked_line)) trimws(strsplit(sub("^LEAKED: ", "", leaked_line[1]), "|", fixed = TRUE)[[1]]) else character(0)
  leaked <- setdiff(leaked, "")

  unexpected <- setdiff(leaked, whitelist)
  expect_equal(unexpected, character(0),
               info = paste("unexpected globals after legacy run:",
                            paste(unexpected, collapse = ", ")))
})