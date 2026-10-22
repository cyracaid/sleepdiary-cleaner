answers <- function(...) { a <- c(...); i <- 0; function(prompt) { i <<- i + 1; a[[i]] } }

test_that('"ask" asks y / n and uses only the answer', {
  expect_output(r <- sleepcleanr:::.resolve_include_manual("ask", ask = TRUE, read = answers("y")), "human-review")
  expect_true(r)
  expect_output(r <- sleepcleanr:::.resolve_include_manual("ASK", ask = TRUE, read = answers("x", "n")),
                "Please type y or n")
  expect_false(r)
})

test_that('"ask" stops a non-interactive session instead of deciding', {
  expect_error(sleepcleanr:::.resolve_include_manual("ask", ask = FALSE), "not interactive")
})

test_that("the other values keep their meaning", {
  f <- sleepcleanr:::.resolve_include_manual
  expect_true(f(TRUE)); expect_false(f(FALSE)); expect_true(f("y")); expect_true(f("Yes"))
  expect_false(f("n")); expect_false(f("no")); expect_false(f(NA))
})

test_that('a run with "ask" in a non-interactive session stops before anything is written', {
  dir <- withr::local_tempdir()
  cfg <- list(data = list(files = list(main = "missing.rds")))
  expect_error(run_pipeline(cfg, project_dir = dir, skip_visualization = TRUE, verbose = FALSE,
                            include_manual_corrections = "ask"), "not interactive")
  expect_length(list.files(dir), 0)
})
