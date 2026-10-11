# demo_simulate.R -- test the typing-task chain end to end with simulated participants.
# Each simulated participant types the truth, with these per-field error rates: AM/PM
# swapped 4%, sleep and awake transposed 1.5% of entries, a missing colon 2%, a period for
# the colon 1%, a clock time typed in a duration field 1%. Not a result about people.
# Usage (from the repository root): Rscript validation/typing_task/demo_simulate.R
set.seed(20261011)
sc <- read.csv("validation/typing_task/scenarios.csv", stringsAsFactors = FALSE)
out <- file.path(tempdir(), "typing_demo"); dir.create(out)
flip <- function(a) ifelse(a == "AM", "PM", "AM")
for (p in sprintf("P%02d", 1:30)) {
  r <- data.frame(participant_id = p, scenario_id = sc$scenario_id, stringsAsFactors = FALSE)
  for (k in c("bed", "sleep", "awake", "getup")) {
    r[[paste0(k, "_time")]] <- sub(" (AM|PM)$", "", sc[[paste0(k, "_text")]])
    r[[paste0(k, "_ampm")]] <- sc[[paste0(k, "_ampm")]]
    sw <- runif(nrow(sc)) < 0.04; r[[paste0(k, "_ampm")]][sw] <- flip(r[[paste0(k, "_ampm")]][sw])
    mc <- runif(nrow(sc)) < 0.02; r[[paste0(k, "_time")]][mc] <- sub(":", "", r[[paste0(k, "_time")]][mc])
    dt <- runif(nrow(sc)) < 0.01; r[[paste0(k, "_time")]][dt] <- sub(":", ".", r[[paste0(k, "_time")]][dt])
  }
  tr <- runif(nrow(sc)) < 0.015
  tmp <- r$sleep_time[tr]; r$sleep_time[tr] <- r$awake_time[tr]; r$awake_time[tr] <- tmp
  tmp <- r$sleep_ampm[tr]; r$sleep_ampm[tr] <- r$awake_ampm[tr]; r$awake_ampm[tr] <- tmp
  r$sol_typed <- as.character(sc$sol_min); r$waso_typed <- as.character(sc$waso_min)
  ck <- runif(nrow(sc)) < 0.01; r$sol_typed[ck] <- sub(" (AM|PM)$", "", sc$sleep_text[ck])
  r$seconds <- 30
  write.csv(r, file.path(out, paste0("typing_task_", p, ".csv")), row.names = FALSE)
}
system2("Rscript", c("validation/typing_task/score_typing_task.R", out))
