# .read_manual_csv(): the same result in every locale, and never a silently
# shortened table.

test_that("a plain ASCII file is read in full", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("pid,day_num,row_id,note", "1,1,10,ok", "1,2,11,also ok"), f)
  out <- .read_manual_csv(f)
  expect_equal(nrow(out), 2)
  expect_equal(out$row_id, c(10, 11))
})

test_that("a UTF-8 BOM in front of the first column name is removed", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("pid,day_num,row_id\n1,1,10\n")), f)
  out <- .read_manual_csv(f)
  expect_equal(names(out)[1], "pid")
  expect_equal(nrow(out), 1)
})

test_that("non-ASCII text does not shorten the table, whatever the session locale", {
  f <- withr::local_tempfile(fileext = ".csv")
  # "caf\u00e9" and a Chinese note, written as explicit UTF-8 bytes
  cafe <- as.raw(c(0x63, 0x61, 0x66, 0xc3, 0xa9))
  zh   <- as.raw(c(0xe4, 0xb8, 0xad, 0xe6, 0x96, 0x87))
  writeBin(c(charToRaw("pid,day_num,row_id,note\n1,1,10,\""), cafe,
             charToRaw("\"\n1,2,11,\""), zh,
             charToRaw("\"\n1,3,12,plain\n")), f)
  out <- .read_manual_csv(f)
  expect_equal(nrow(out), 3)
  expect_equal(out$row_id, c(10, 11, 12))
  expect_equal(out$note[3], "plain")
  # the text itself survives only where the session can represent it
  if (l10n_info()[["UTF-8"]]) {
    expect_identical(enc2utf8(out$note[1]), "caf\u00e9")
    expect_identical(enc2utf8(out$note[2]), "\u4e2d\u6587")
  }
})

test_that("bytes that are not valid UTF-8 never give a silently short table", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeBin(c(charToRaw("pid,day_num,row_id,note\n1,1,10,\"bad "),
             as.raw(0xff),
             charToRaw(" byte\"\n1,2,11,fine\n1,3,12,fine\n")), f)
  res <- tryCatch(nrow(.read_manual_csv(f)), error = function(e) "error")
  # either every row is read (3) or the run refuses; never fewer rows
  expect_true(identical(res, 3L) || identical(res, "error"))
})
