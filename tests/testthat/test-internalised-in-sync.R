# test-internalised-in-sync.R — R/ internalised copies stay body-identical to
# the inst/scripts originals they were carved from.
#
# The pre-commit hook + test-script-copies-in-sync.R only lock root<->inst/scripts.
# This file extends the same philosophy to the R/ internalisation: every
# function body must remain byte-identical (after parse+deparse) between the
# package copy and the legacy script copy, so a refactor of one cannot silently
# diverge from the other.

# (file, script) pairs that have been internalised. Extended per task.
pairs <- list(
  list("normalize_sequence.R", "normalize_sleep_time_sequence.R")
  , list("sleep_time_metrics.R", "calculate_sleep_time_end.R")
)

extract_funs <- function(path) {
  exprs <- parse(path)
  out <- list()
  for (e in exprs) {
    if (is.call(e) && identical(e[[1L]], as.name("<-"))) {
      nm <- as.character(e[[2L]])
      rhs <- e[[3L]]
      if (is.call(rhs) && identical(rhs[[1L]], as.name("function"))) {
        body_txt <- paste(deparse(e), collapse = "\n")
        # R/ copies drop require()/library() scaffolding (resolved via
        # @importFrom in the namespace) while legacy scripts keep it; strip
        # from both sides so the body comparison stays meaningful.
        lines <- strsplit(body_txt, "\n", fixed = TRUE)[[1]]
        lines <- lines[!grepl("^\\s*(require|library)\\(", lines)]
        out[[nm]] <- paste(lines, collapse = "\n")
      }
    }
  }
  out
}

test_that("internalised R/ functions match inst/scripts bodies", {
  root <- if (basename(getwd()) == "testthat") dirname(dirname(getwd())) else getwd()
  for (pr in pairs) {
    r_path <- file.path(root, "R", pr[[1]])
    s_path <- file.path(root, "inst", "scripts", pr[[2]])
    if (!file.exists(r_path) || !file.exists(s_path)) next
    r_fns <- extract_funs(r_path)
    s_fns <- extract_funs(s_path)
    common <- intersect(names(r_fns), names(s_fns))
    expect_true(length(common) > 0,
                info = paste("no shared function names:", pr[[1]], "vs", pr[[2]]))
    for (nm in common) {
      expect_identical(r_fns[[nm]], s_fns[[nm]],
                       info = paste("body drift:", nm, "in", pr[[1]]))
    }
  }
})
