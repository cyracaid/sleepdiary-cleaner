# test-smoke-legacy-entry.R — smoke test for the legacy 00_MAIN_entry entry point.
#
# run_pipeline() (test-pipeline.R) is the packaged entry and is exercised end
# to end there. But 00_MAIN_entry.R is the legacy "master control" script that
# users in the wild source() and run non-interactively; it walks the same 10
# steps through a DIFFERENT code path (.run_pipeline_internal()), which
# re-sources every step script itself. That path can rot independently of the
# package wrapper (global-object handoffs, step ordering, PDF device calls),
# so we smoke it directly.
#
# Key difference from test-pipeline.R: we must NOT set sleepcleanr_loaded in the
# test process (that would suppress the auto-run guard) and we must source the
# script in a subprocess so its auto-run branch fires exactly as it does for a
# real user.

test_that("00_MAIN_entry auto-runs the full legacy chain on synthetic data", {
  cfg_path <- system.file("extdata", "synthetic_config.yaml", package = "sleepcleanr")
  if (cfg_path == "") cfg_path <- file.path(getwd(), "inst", "extdata", "synthetic_config.yaml")
  skip_if_not(file.exists(cfg_path), "synthetic_config.yaml not found")

  # Same sandbox discipline as test-pipeline.R: a legacy run writes every
  # artifact to the working directory, so it must run in a throwaway dir.
  sandbox <- tempfile("splsmoke_")
  dir.create(sandbox, recursive = TRUE, showWarnings = FALSE)
  # Windows tempfile() returns backslashes; the runner script embeds this path
  # verbatim, and Rscript would parse "\U"/"\T" as escapes ("'\U' used without
  # hex digits"). Normalize every path we inject into the subprocess script.
  sandbox  <- normalizePath(sandbox, winslash = "/")
  on.exit(unlink(sandbox, recursive = TRUE, force = TRUE), add = TRUE)

  src_data <- dirname(cfg_path)
  for (f in c("synthetic_sleep_data.rds", "synthetic_ema_data.csv")) {
    file.copy(file.path(src_data, f), sandbox, overwrite = TRUE)
  }
  cfg <- yaml::read_yaml(cfg_path)
  cfg$data$files$main  <- "synthetic_sleep_data.rds"
  cfg$data$files$extra <- "synthetic_ema_data.csv"
  yaml::write_yaml(cfg, file.path(sandbox, "synthetic_config.yaml"))

  # The legacy script reads its config location via pipedenv setup files
  # (00a_setup.R / pipeline init). Compute what .run_pipeline_internal sees:
  # sdir <- get0("sleepcleanr_scripts_dir", .GlobalEnv, ifnotfound = getwd())
  # and config comes from load_config(NULL) unless overridden. Simplest robust
  # bridge: run in a fresh R subprocess that mirrors a real non-interactive
  # user - setwd(sandbox), pre-wire sleepcleanr_scripts_dir + a local config
  # override file, then source the script and expect the auto-run branch.
  #
  # The legacy chain expects sleepcleanr_loaded ABSENT (auto-run) but scripts_dir
  # PRESENT (it locates step scripts). We satisfy both: sleepcleanr_scripts_dir is
  # set by the runner, sleepcleanr_loaded is never created.

  scripts_dir <- dirname(list.files(
    c("inst/scripts", system.file("scripts", package = "sleepcleanr")),
    pattern = "^00_MAIN_entry\\.R$", full.names = TRUE, recursive = TRUE
  )[1])
  scripts_dir <- normalizePath(scripts_dir, winslash = "/")

  # Config discovery: legacy setup reads pipeline_config.yaml in cwd first
  # (see 00a_setup.R / load_config) - write one pointing at sandbox data.
  local_cfg <- cfg
  yaml::write_yaml(local_cfg, file.path(sandbox, "pipeline_config.yaml"))

  runner <- tempfile("splsmoke_run_", fileext = ".R")
  writeLines(c(
    # Force UTF-8: R CMD check runs the sandbox subprocess under the check
    # session charset (ASCII on macOS CI), and 00_MAIN_entry's checkpoint
    # banner prints Δ/→ (U+0394/U+2192) — mbcsToSbcs chokes on those in C
    # locale and the auto-run exits non-zero before writing artifacts.
    "suppressWarnings(tryCatch(Sys.setlocale('LC_CTYPE', 'en_US.UTF-8'), error = function(e) NULL))",
    "root_pkg <- ''",
    "probe <- getwd()",
    "repeat {",
    "  if (file.exists(file.path(probe, 'DESCRIPTION'))) { root_pkg <- probe; break }",
    "  up <- dirname(probe)",
    "  if (up == probe) break",
    "  probe <- up",
    "}",
    "# load_all only when a source tree is reachable: under R CMD check the",
    "# test runs from .../Rcheck/tests/testthat with no DESCRIPTION above it,",
    "# and the installed package (library(sleepcleanr)) is the correct code anyway.",
    "if (nzchar(root_pkg)) suppressMessages(pkgload::load_all(root_pkg, quiet = TRUE))",
    "library(sleepcleanr)",
    sprintf("setwd(%s)", shQuote(sandbox)),
    sprintf("assign('sleepcleanr_scripts_dir', %s, envir = .GlobalEnv)",
            shQuote(scripts_dir)),
    # Legacy entry reads .GlobalEnv$pipeline_config (get0 in Step 1);
    # mirror what run_pipeline()'s init does so the chain runs identically.
    # load_config() is internal to the package, so parse the yaml directly.
    "assign('pipeline_config', yaml::read_yaml('synthetic_config.yaml'), envir = .GlobalEnv)",
    "options(warn = 1)",
    "time0 <- Sys.time()",
    "res <- tryCatch(source(file.path(get0('sleepcleanr_scripts_dir'), '00_MAIN_entry.R'), local = FALSE),",
    "                 error = function(e) e)",
    "if (inherits(res, 'error')) {",
    "  cat('SMOKE_FAIL:', conditionMessage(res), '\n')",
    "  quit(status = 1)",
    "}",
    "cat('SMOKE_OK', round(as.numeric(difftime(Sys.time(), time0, units = 'secs')), 1), 'sec\n')",
    "quit(status = 0)"
  ), runner, useBytes = TRUE)

  out <- system2(file.path(R.home("bin"), "Rscript"), shQuote(runner),
                 stdout = TRUE, stderr = TRUE)
  unlink(runner)

  expect_true(any(grepl("SMOKE_OK", out)),
              paste(c("legacy entry auto-run failed:", out), collapse = "\n"))

  # The chain must have produced its canonical artifacts inside the sandbox.
  expect_true(file.exists(file.path(sandbox, "output", "step_flag_ledger.csv")),
              "step_flag_ledger.csv should exist (written by legacy chain)")
  expect_true(file.exists(file.path(sandbox, "output", "correction_status_final.csv")),
              "correction_status_final.csv should exist")
})