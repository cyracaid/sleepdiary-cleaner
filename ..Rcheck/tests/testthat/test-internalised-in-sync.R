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
  , list("correction_appliers.R", "apply_nap_exercise_corrections.R")
  , list("correction_appliers.R", "apply_sleep_metric_duration_corrections.R")
  , list("correction_appliers.R", "apply_metric_review_acceptances.R")
  , list("manual_corrections.R", "error_unusual_sleep_time_corrections.R")
)

# deparse can render the same UTF-8 source as either raw bytes or <U+XXXX>
# escapes depending on how parse() tagged the string's encoding. Normalise
# both representations to the same form before comparing, so the gate is
# immune to encoding-tag flapping (a real source of false results).
normalize_deparse <- function(d) {
  repeat {
    m <- regexpr("<U\\+[0-9A-Fa-f]{4}>", d)
    if (m == -1) break
    hit <- regmatches(d, m)
    code <- strtoi(sub("^<U\\+", "", sub(">$", "", hit)), 16)
    d <- gsub(hit, intToUtf8(code), d, fixed = TRUE)
  }
  enc2utf8(d)
}

extract_funs <- function(path) {
  exprs <- parse(path)
  out <- list()
  for (e in exprs) {
    if (is.call(e) && identical(e[[1L]], as.name("<-"))) {
      nm <- as.character(e[[2L]])
      rhs <- e[[3L]]
      if (is.call(rhs) && identical(rhs[[1L]], as.name("function"))) {
        out[[nm]] <- normalize_deparse(paste(deparse(e), collapse = "\n"))
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
