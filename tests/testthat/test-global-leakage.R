# test-global-leakage.R -- the legacy entry chain must not add objects to the
# global environment.
#
# Since 1.5.0 run_pipeline() keeps its objects in the package (pipeline_results()),
# so the only globals after a legacy run are the ones the runner below assigns
# itself, as a legacy user would, and one the legacy entry script defines. Anything else fails: a refactor that adds a global
# (stray counter, leftover temporary, a result left behind) is caught here.

test_that("legacy chain writes only protocol globals", {
  cfg_path <- system.file("extdata", "synthetic_config.yaml", package = "sleepcleanr")
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
    c("inst/scripts", system.file("scripts", package = "sleepcleanr")),
    pattern = "^00_MAIN_entry\\.R$", full.names = TRUE, recursive = TRUE
  )[1])

  # the two objects the runner assigns itself, as a legacy user would, and
  # multi_process, which the sourced legacy entry script 00_MAIN_entry.R defines
  # at its top level (it is the user's script, not package code)
  whitelist <- c("pipeline_config", "sleepcleanr_scripts_dir", "multi_process")

  runner <- tempfile("splleak_run_", fileext = ".R")
  writeLines(c(
    "root_pkg <- if (basename(getwd()) == 'testthat') dirname(dirname(getwd())) else getwd()",
    "# load_all only from a real source tree (.Rbuildignore present): under",
    "# R CMD check / covr the tests run against the installed package where",
    "# the probe path has a misleading DESCRIPTION; library(sleepcleanr)",
    "# below is the correct code in those environments.",
    "if (file.exists(file.path(root_pkg, '.Rbuildignore')) &&",
    "    dir.exists(file.path(root_pkg, 'R'))) {",
    "  suppressMessages(pkgload::load_all(root_pkg, quiet = TRUE))",
    "}",
    "suppressMessages(library(sleepcleanr))",
    sprintf("setwd(%s)", shQuote(sandbox)),
    sprintf("assign('sleepcleanr_scripts_dir', %s, envir = .GlobalEnv)", shQuote(scripts_dir)),
    "assign('pipeline_config', yaml::read_yaml('pipeline_config.yaml'), envir = .GlobalEnv)",
    "base0 <- ls(globalenv())",
    "res <- tryCatch({",
    "  suppressMessages(suppressWarnings(source(file.path(get0('sleepcleanr_scripts_dir'), '00_MAIN_entry.R'), local = FALSE)))",
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