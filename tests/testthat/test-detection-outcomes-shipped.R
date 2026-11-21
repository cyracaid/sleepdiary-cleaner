# F08 reads detection_outcomes_v4_current.csv. It used to live only under
# validation/, which is not part of the package, so F08 could not be drawn from
# an installed package. Keep the shipped copy and the benchmark copy identical.

.dos_root <- function() {
  for (p in c(getwd(), file.path(getwd(), ".."), file.path(getwd(), "..", ".."))) {
    if (file.exists(file.path(p, "DESCRIPTION")) &&
        file.exists(file.path(p, "inst", "scripts", "sleep_visualization.R"))) return(normalizePath(p))
  }
  NA_character_
}

test_that("the shipped detection-outcomes table has the columns F08 reads", {
  root <- .dos_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")
  tab <- read.csv(file.path(root, "inst", "extdata", "detection_outcomes_v4_current.csv"),
                  stringsAsFactors = FALSE)
  need <- c("category", "n", "CORRECT", "FLAGGED_UNRESOLVED", "MISREPAIRED", "MISSED", "NO_MATCH")
  expect_true(all(need %in% names(tab)))
  expect_true(all(tab$n > 0))
})

test_that("the shipped copy is identical to the benchmark copy", {
  root <- .dos_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")
  a <- file.path(root, "inst", "extdata", "detection_outcomes_v4_current.csv")
  b <- file.path(root, "validation", "synthetic", "results", "detection_outcomes_v4_current.csv")
  skip_if(!file.exists(b), "validation/ not present")
  expect_identical(readLines(a), readLines(b))
})
