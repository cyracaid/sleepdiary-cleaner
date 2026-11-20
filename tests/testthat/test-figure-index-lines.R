# The figure index in the interpreting-output vignettes cites the line of
# inst/scripts/sleep_visualization.R where each figure is saved. Those numbers
# go stale whenever the script is edited (they were refreshed by hand on
# 2026-11-20). This test fails when a cited line no longer holds that figure,
# so the fix is to renumber, not to discover it by reading the docs.

.fig_root <- function() {
  for (p in c(getwd(), file.path(getwd(), ".."), file.path(getwd(), "..", ".."))) {
    if (file.exists(file.path(p, "DESCRIPTION")) &&
        file.exists(file.path(p, "inst", "scripts", "sleep_visualization.R")) &&
        dir.exists(file.path(p, "vignettes"))) return(normalizePath(p))
  }
  NA_character_
}

test_that("figure-index line numbers point at the line that saves the figure", {
  root <- .fig_root()
  skip_if(is.na(root), "package source root not found (installed-package run)")
  script <- readLines(file.path(root, "inst", "scripts", "sleep_visualization.R"), warn = FALSE)
  docs <- file.path(root, "vignettes",
                    c("interpreting-output.Rmd", "interpreting-output-zh.Rmd"))
  n_checked <- 0
  for (d in docs[file.exists(docs)]) {
    for (ln in readLines(d, warn = FALSE, encoding = "UTF-8")) {
      m <- regmatches(ln, regexec("(F[0-9]{2})\\.png`.*sleep_visualization\\.R:([0-9]+)", ln))[[1]]
      if (length(m) != 3) next
      fig <- m[2]; at <- as.integer(m[3])
      expect_true(at >= 1 && at <= length(script),
                  info = sprintf("%s cites line %d, past the end of the script", fig, at))
      expect_true(grepl(fig, script[at], fixed = TRUE),
                  info = sprintf("%s in %s cites sleep_visualization.R:%d, which is: %s",
                                 fig, basename(d), at, trimws(script[at])))
      n_checked <- n_checked + 1
    }
  }
  expect_gt(n_checked, 60)
})
