# F20 reads reversal_injection_outcomes.csv. Keep the table, its two copies and
# the form labels in sleep_visualization.R in step.

.rio_root <- function() {
  for (p in c(getwd(), file.path(getwd(), ".."), file.path(getwd(), "..", ".."))) {
    if (file.exists(file.path(p, "DESCRIPTION")) &&
        file.exists(file.path(p, "inst", "scripts", "sleep_visualization.R"))) return(normalizePath(p))
  }
  NA_character_
}

test_that("F20 table has the columns the figure reads and a label for every form", {
  root <- .rio_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")
  tab <- read.csv(file.path(root, "inst", "extdata", "reversal_injection_outcomes.csv"),
                  stringsAsFactors = FALSE)
  need <- c("form", "n_injected", "flagged_or_corrected_pct", "ci_low", "ci_high",
            "corrected_pct", "wrong_repairs", "n_clean", "n_clean_altered")
  expect_true(all(need %in% names(tab)))
  script <- paste(readLines(file.path(root, "inst", "scripts", "sleep_visualization.R"), warn = FALSE),
                  collapse = "\n")
  for (f in tab$form) expect_true(grepl(paste0(f, " = \""), script, fixed = TRUE), info = f)
  expect_true(all(tab$wrong_repairs <= tab$n_injected))
  expect_true(all(tab$ci_low <= tab$flagged_or_corrected_pct & tab$flagged_or_corrected_pct <= tab$ci_high))
})

test_that("the two copies of the F20 table are identical", {
  root <- .rio_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")
  a <- file.path(root, "inst", "extdata", "reversal_injection_outcomes.csv")
  b <- file.path(root, "validation", "synthetic", "results", "reversal_injection_outcomes.csv")
  skip_if(!file.exists(b), "validation/ not present")
  expect_identical(readLines(a), readLines(b))
})
