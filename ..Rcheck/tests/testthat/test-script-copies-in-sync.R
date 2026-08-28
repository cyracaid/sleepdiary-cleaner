# test-script-copies-in-sync.R
#
# The pipeline scripts live in inst/scripts/ (what ships with the installed
# package and what the S3 step adapters call via scripts_dir() in
# R/pipeline.R). 00_MAIN_entry.R sources scripts through run_pipeline(),
# which resolves scripts_dir() -> inst/scripts.
#
# Historical note: the repo root once carried duplicate copies of every
# inst/scripts file (source("00_MAIN_entry.R") in dev mode used the root
# copy). Those root copies were removed on 2026-08-17 (Phase 1 dedup) --
# 00_MAIN_entry.R is now a thin shim over run_pipeline() and never sources
# root scripts. The only root-level .R files that remain are the legacy dev
# entry points (00_MAIN_entry.R, 00a_setup.R) and the verify_* dev tools.
#
# What this test now guards:
#   1. inst/scripts exists and is non-empty (the shipped cleaning code).
#   2. No unexpected root-level duplicate of an inst/scripts file reappears
#      (dedup regression guard).
#   3. The Bug 2 denominator guard is present in the canonical inst/scripts
#      copy (the only copy that ships).

KNOWN_DIVERGENT <- character(0)

.find_pkg_root <- function() {
  candidates <- c(
    getwd(),
    file.path(getwd(), "..", ".."),
    file.path(getwd(), "..", "..", "..")
  )
  for (p in candidates) {
    if (file.exists(file.path(p, "DESCRIPTION")) &&
        dir.exists(file.path(p, "inst", "scripts"))) {
      return(normalizePath(p))
    }
  }
  NA_character_
}

test_that("no unexpected root-level duplicate of an inst/scripts file", {
  root <- .find_pkg_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")

  inst_dir <- file.path(root, "inst", "scripts")
  scripts  <- list.files(inst_dir, pattern = "\\.R$")
  skip_if(length(scripts) == 0, "no scripts in inst/scripts")

  # Legacy entry points are expected at root; everything else in inst/scripts
  # must NOT have a root duplicate (dedup contract).
  allowed_root <- c("00_MAIN_entry.R", "00a_setup.R")

  unexpected <- scripts[file.exists(file.path(root, scripts)) &
                          !(scripts %in% allowed_root)]
  expect_identical(
    unexpected, character(0),
    info = paste0(
      "Root-level duplicate of inst/scripts file(s) reappeared (dedup ",
      "regression): ", paste(unexpected, collapse = ", "),
      ". These live only in inst/scripts/. See the file header comment."
    )
  )
})

test_that("inst/scripts ships the canonical cleaning scripts", {
  root <- .find_pkg_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")

  inst_dir <- file.path(root, "inst", "scripts")
  required <- c(
    "process_timestamp_emadatarelease_cyra.R",
    "process_interval.R",
    "normalize_sleep_time_sequence.R",
    "calculate_sleep_time_end.R",
    "sleep_visualization.R",
    "checkforerrors_processing.R",
    "cross_participant_global_check.R"
  )
  for (s in required) {
    expect_true(
      file.exists(file.path(inst_dir, s)),
      info = paste0("Missing canonical script in inst/scripts/: ", s)
    )
  }
})

test_that("the sleep-efficiency denominator guard is present (Bug 2)", {
  root <- .find_pkg_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")

  f <- file.path(root, "inst", "scripts", "calculate_sleep_time_end.R")
  skip_if_not(file.exists(f), paste("missing:", f))
  src <- paste(readLines(f, warn = FALSE), collapse = "\n")

  # The efficiency assignment must not be a bare division.
  expect_false(
    grepl(
      "self_diffcalc_sleepefficiency_percent\\s*=\\s*self_diffcalc_totalsleeptime_minutes\\s*/",
      src
    ),
    info = paste0("Bare, unguarded division restored in ", basename(f),
                  " -- Bug 2 has regressed.")
  )

  # ...and the guard on the denominator must be present.
  expect_true(
    grepl("self_diffcalc_totaltrysleep_minutes\\s*>\\s*0", src),
    info = paste0("Denominator guard missing in ", basename(f), ".")
  )
})
