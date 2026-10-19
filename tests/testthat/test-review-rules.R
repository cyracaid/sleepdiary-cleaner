mk_ws <- function(ids, in_file = rep("", length(ids)), res = rep("", length(ids)),
                  by = rep("", length(ids))) data.frame(
  pid = rep(1, length(ids)), day_num = ids, row_id = ids,
  in_manual_file = in_file, review_resolution = res,
  resolved_at = rep("", length(ids)), resolved_by = by, stringsAsFactors = FALSE)

final_of <- function(ids, cat) data.frame(pid = 1, day_num = ids, row_id = ids,
  data_category = cat, stringsAsFactors = FALSE)

test_that("the bundled config and the code defaults give the same rules", {
  root <- testthat::test_path("..", "..")
  f <- file.path(root, "inst", "config_default.yaml")
  if (!file.exists(f)) f <- system.file("config_default.yaml", package = "sleepcleanr")
  expect_identical(sleepcleanr::review_rules(load_config(f)), sleepcleanr::review_rules(NULL))
})

test_that("review rules reject a malformed done rule and suggestion", {
  expect_error(review_rules(list(review = list(done_when = list(max_needs_review = -1)))),
               "max_needs_review")
  expect_error(review_rules(list(review = list(suggestions = list(list(label = "x"))))),
               "non-empty 'when'")
  expect_length(review_rules(list(review = list(suggestions = list())))$suggestions, 0)
})

test_that("every row gets exactly one review_state with a reason", {
  err <- mk_ws(1:5, in_file = c("", "", "m.csv", "m.csv", "m.csv"),
               res = c("", "", "corrected", "flagged_unresolved", "corrected"))
  unu <- mk_ws(6:7, in_file = c("", "u.csv"), res = c("", "kept"))
  final <- final_of(c(1:7, 9), c("clean", "error", "clean", "clean", "error",
                                 "unusual", "unusual", "error"))
  out <- sleepcleanr:::build_unified_review_status(list(error = err, unusual = unu), final,
                                                   applied = TRUE)
  expect_equal(nrow(out), 8)
  st <- setNames(out$review_state, out$row_id)
  expect_equal(unname(st[as.character(c(1, 2, 3, 4, 5, 6, 7, 9))]),
               c("not_incorporated", "needs_review", "incorporated", "needs_review",
                 "needs_review", "not_incorporated", "incorporated", "needs_review"))
  expect_true(all(nzchar(out$review_state_reason)))
  expect_equal(out$worksheet[out$row_id == 9], "none")
  expect_equal(out$worksheet[out$row_id == 6], "unusual")
  # needs_review first, then not_incorporated, then incorporated
  expect_equal(out$review_state, sort(factor(out$review_state,
    levels = c("needs_review", "not_incorporated", "incorporated"))) |> as.character())
})

test_that("nothing is incorporated when manual corrections were not applied", {
  err <- mk_ws(1:2, in_file = c("m.csv", ""))
  out <- sleepcleanr:::build_unified_review_status(list(error = err),
    final_of(1:2, c("clean", "clean")), applied = FALSE)
  expect_false(any(out$review_state == "incorporated"))
  expect_match(out$review_state_reason[out$row_id == 1], "not applied")
})

test_that("Step 8 flags count only when the user's rule says so", {
  err <- mk_ws(1)
  final <- final_of(1, "clean")
  flags <- data.frame(pid = 1, day_num = 1, row_id = 1, needs_review_flag = TRUE,
                      auto_error_desc = "SOL excessive")
  off <- sleepcleanr:::build_unified_review_status(list(error = err), final, flags,
    rules = review_rules(NULL))
  on <- sleepcleanr:::build_unified_review_status(list(error = err), final, flags,
    rules = review_rules(list(review = list(step8_flags_need_review = TRUE))))
  expect_equal(off$review_state, "not_incorporated")
  expect_equal(on$review_state, "needs_review")
})

test_that("same input gives the same table, whatever the input row order", {
  err <- mk_ws(c(3, 1, 2))
  final <- final_of(1:3, c("error", "clean", "error"))
  a <- sleepcleanr:::build_unified_review_status(list(error = err), final)
  b <- sleepcleanr:::build_unified_review_status(list(error = err[c(2, 3, 1), ]), final[3:1, ])
  expect_identical(a, b)
})

test_that("the verdict follows the user's done rule only", {
  status <- data.frame(review_state = c("needs_review", "incorporated", "not_incorporated"))
  v0 <- review_verdict(status, cfg = list())
  expect_false(v0$done)
  expect_equal(unname(v0$counts), c(1L, 1L, 1L))
  v1 <- review_verdict(status, cfg = list(review = list(done_when = list(max_needs_review = 1))))
  expect_true(v1$done)
  expect_error(review_verdict(data.frame(review_state = "maybe"), cfg = list()), "must be one of")
  expect_output(print(v0), "NOT DONE")
})

test_that("an empty table is done and has the agreed columns", {
  out <- sleepcleanr:::build_unified_review_status(list(), final_of(1, "clean"))
  expect_equal(nrow(out), 0)
  expect_true(all(c("review_state", "review_state_reason", "worksheet") %in% names(out)))
  expect_true(review_verdict(out, cfg = list())$done)
})

test_that("suggestions come from the user's rules, first match wins", {
  df <- data.frame(auto_error_desc = c("[Metrics] SE:negative", "x", "y"),
                   sol_category = c("excessive", "excessive", "normal"),
                   se_category = "valid", tst_tib_ratio_category = "normal")
  out <- suggest_review_labels(df)
  expect_equal(out$ai_label, c("likely_real_issue", "likely_false_positive", "needs_human"))
  expect_equal(out$ai_rule, c("1", "2", "default"))
  none <- suggest_review_labels(df, review_rules(list(review = list(suggestions = list()))))
  expect_true(all(none$ai_label == "needs_human"))
  custom <- review_rules(list(review = list(suggestions = list(
    list(label = "mine", when = list(sol_category = "normal"), reason = "r")))))
  expect_equal(suggest_review_labels(df, custom)$ai_label, c("needs_human", "needs_human", "mine"))
})

test_that("the run log gets one line per run in one file and compares runs", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  writeLines("a,b\n1,2", "data.csv")
  writeLines("x", "status.csv")
  cfg <- list(data = list(files = list(main = "data.csv")),
              output = list(report = list(dir = "out")))
  v <- review_verdict(data.frame(review_state = "incorporated"), cfg = cfg)
  expect_output(sleepcleanr:::append_review_run_log(cfg, "status.csv", v, TRUE), "appended")
  expect_output(sleepcleanr:::append_review_run_log(cfg, "status.csv", v, TRUE),
                "inputs identical, review status table identical")
  log <- utils::read.csv(file.path("out", "review_runs.csv"))
  expect_equal(nrow(log), 2)
  expect_equal(list.files("out"), "review_runs.csv")
  writeLines("y", "status.csv")
  expect_output(sleepcleanr:::append_review_run_log(cfg, "status.csv", v, TRUE),
                "WARNING: same inputs gave a different")
})
