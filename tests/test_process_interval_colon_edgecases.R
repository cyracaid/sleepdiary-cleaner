source("process_interval.R")

df <- data.frame(vigorous = c("00:000", "000:45"), stringsAsFactors = FALSE)
result <- process_interval(df, "vigorous", "interval_hhmm")

if (!identical(result$vigorous[1], "00:00")) {
  stop(sprintf("Expected 00:000 to normalize to 00:00, got %s", result$vigorous[1]))
}

if (!isTRUE(result$vigorous_mincalc[1] == 0)) {
  stop(sprintf("Expected 00:000 mincalc to be 0, got %s", result$vigorous_mincalc[1]))
}

if (isTRUE(result$vigorous_checkforerrors[1])) {
  stop("Expected 00:000 not to need manual review after normalization")
}

if (!identical(result$vigorous[2], "00:45")) {
  stop(sprintf("Expected 000:45 to normalize to 00:45, got %s", result$vigorous[2]))
}

if (!isTRUE(result$vigorous_mincalc[2] == 45)) {
  stop(sprintf("Expected 000:45 mincalc to be 45, got %s", result$vigorous_mincalc[2]))
}

if (isTRUE(result$vigorous_checkforerrors[2])) {
  stop("Expected 000:45 not to need manual review after normalization")
}

cat("process_interval colon edgecase tests passed\n")
