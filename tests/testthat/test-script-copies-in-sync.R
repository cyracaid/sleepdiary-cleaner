# test-script-copies-in-sync.R
#
# Several pipeline scripts exist in TWO places: the repository root (what
# 00_MAIN_entry.R sources in dev mode) and inst/scripts/ (what ships with the
# installed package and what the S3 step adapters call).
#
# This is not hypothetical bookkeeping. The Bug 2 denominator guard in
# calculate_sleep_time_end.R was reported as fixed but was absent from main on
# 2026-08-05 -- the likeliest cause being a fix applied to one copy while the
# other won a later merge. A silent divergence means the tests and the
# production run can execute different cleaning code.
#
# Which copy actually runs depends on how the pipeline is started:
#   run_pipeline()                -> system.file("scripts")  -> inst/scripts copy
#   source("00_MAIN_entry.R")     -> getwd()                 -> root copy
# (see sdir in 00_MAIN_entry.R and scripts_dir() in R/pipeline.R)
#
# On 2026-08-05 five scripts had drifted apart: the inst/scripts copies resolved
# their file paths through cfg_get() while the root copies still hardcoded
# filenames. Under the default config the two behaved identically, because the
# cfg_get() defaults were the same strings -- so nothing was visibly broken. The
# trap was that any config which overrode data.files.* would be honoured by one
# copy and silently ignored by the other. Those five were resolved by making the
# config-aware inst/scripts copies canonical and copying them over the root.
#
# KNOWN_DIVERGENT is deliberately empty. If a divergence is ever legitimate,
# add it here with a comment explaining why; otherwise this test should stay at
# zero and catch the next drift on the commit that introduces it.

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

test_that("no NEW divergence between root and inst/scripts copies", {
  root <- .find_pkg_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")

  inst_dir <- file.path(root, "inst", "scripts")
  scripts  <- list.files(inst_dir, pattern = "\\.R$")
  skip_if(length(scripts) == 0, "no scripts in inst/scripts")

  divergent <- character(0)
  for (s in scripts) {
    root_copy <- file.path(root, s)
    if (!file.exists(root_copy)) next
    a <- readLines(root_copy, warn = FALSE)
    b <- readLines(file.path(inst_dir, s), warn = FALSE)
    if (!identical(a, b)) divergent <- c(divergent, s)
  }

  unexpected <- setdiff(divergent, KNOWN_DIVERGENT)
  expect_identical(
    unexpected, character(0),
    info = paste0(
      "New divergence between the repo root and inst/scripts/: ",
      paste(unexpected, collapse = ", "),
      ". Work out which copy is correct before syncing them."
    )
  )

  # If a known divergence has been repaired, the allowlist is stale.
  repaired <- setdiff(KNOWN_DIVERGENT, divergent)
  expect_identical(
    repaired, character(0),
    info = paste0(
      "These files are listed in KNOWN_DIVERGENT but now match: ",
      paste(repaired, collapse = ", "),
      ". Remove them from the allowlist."
    )
  )
})

test_that("the sleep-efficiency denominator guard is present in both copies (Bug 2)", {
  root <- .find_pkg_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")

  targets <- c(
    file.path(root, "calculate_sleep_time_end.R"),
    file.path(root, "inst", "scripts", "calculate_sleep_time_end.R")
  )

  for (f in targets) {
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
  }
})
