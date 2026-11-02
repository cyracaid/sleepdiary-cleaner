# raw_time_distribution.R -- what do people type in the self-reported SOL and WASO fields?
#
# Reads output/cleaned_data_final.csv (read only) and, for each of SOL and WASO, splits the raw
# text into plain numbers (minutes), colon entries (H:MM / MM:SS-looking) and everything else.
# For colon entries it plots the hour part, the minute part, and the entry read as a clock time
# next to the participant's own recorded times of day, so you can see whether the values sit
# where bedtimes / sleep onsets (SOL) or wake-ups / get-ups (WASO) sit.
#
# Writes PNG files and prints counts only (digit patterns are masked: "11:45" -> "99:99").
# Nothing is written inside the repository by default.
#
# Usage (from the repository root):
#   RENV_CONFIG_AUTOLOADER_ENABLED=FALSE Rscript validation/raw_time_distribution.R [out_dir]
# Default out_dir: ~/Desktop/raw_time_distribution

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else file.path(path.expand("~"), "Desktop", "raw_time_distribution")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

A <- read.csv("output/cleaned_data_final.csv", stringsAsFactors = FALSE)

# explicit format: as.POSIXct() on a character vector guesses the format from the first element,
# and a date-only first element (midnight) would silently drop every time of day
parse_ts <- function(x) {
  i <- !is.na(x) & x != "" & nchar(x) == 10
  x[i] <- paste(x[i], "00:00:00")
  as.POSIXct(strptime(x, "%Y-%m-%d %H:%M:%S", tz = "UTC"))
}
tod_hours <- function(t) as.numeric(format(t, "%H")) + as.numeric(format(t, "%M")) / 60

own_times <- list(
  sol  = list(Bedtime = tod_hours(parse_ts(A$bedtime_selfreport_ts)),
              `Sleep onset` = tod_hours(parse_ts(A$sleeponset_selfreport_ts))),
  waso = list(Awakening = tod_hours(parse_ts(A$awakening_selfreport_ts)),
              `Get-up` = tod_hours(parse_ts(A$getup_selfreport_ts)))
)

summarise_field <- function(field) {
  raw <- trimws(as.character(A[[paste0(field, "_selfreport_raw")]]))
  raw[raw %in% c("", "NA")] <- NA
  amb <- A[[paste0(field, "_selfreport_ambiguous")]] %in% c(TRUE, "TRUE")
  kind <- ifelse(is.na(raw), "missing",
          ifelse(grepl("^[0-9]+(\\.[0-9]+)?$", raw), "plain number",
          ifelse(grepl("^[0-9]{1,2}:[0-9]{2}$", raw), "colon H:MM / MM:SS",
          ifelse(grepl("^[0-9]+:[0-9]{2}:[0-9]{2}$", raw), "colon with seconds", "other"))))
  cat("\n==", toupper(field), "self-report: what was typed ==\n")
  print(table(kind))
  cat("flagged ambiguous (read as MM:SS by the pipeline):", sum(amb), "\n")
  oth <- raw[kind == "other"]
  if (length(oth)) {
    cat("patterns among 'other' (digits masked):\n")
    print(head(sort(table(gsub("[0-9]", "9", oth)), decreasing = TRUE), 12))
  }
  list(raw = raw, kind = kind, amb = amb)
}

plot_field <- function(field, label) {
  s <- summarise_field(field)
  png(file.path(out_dir, paste0(field, "_raw_distribution.png")), width = 1500, height = 1050, res = 130)
  op <- par(mfrow = c(2, 2), mar = c(4.2, 4.2, 3, 1)); on.exit({par(op); dev.off()})

  # A: plain numbers
  pn <- as.numeric(s$raw[s$kind == "plain number"])
  if (length(pn)) {
    hist(pmin(pn, 241), breaks = seq(0, 245, by = 5), col = "grey70", border = "white",
         main = paste0(label, ": plain numbers (n = ", length(pn), ")"),
         xlab = "minutes (bars of 5; last bar = 240 or more)")
  } else {
    plot.new(); title(main = paste0(label, ": plain numbers (n = 0)"))
    text(0.5, 0.5, "every non-missing entry is typed as H:MM,\nso there are no plain numbers", cex = 0.9)
  }

  # colon entries
  ci <- s$kind %in% c("colon H:MM / MM:SS", "colon with seconds")
  p <- strsplit(s$raw[ci], ":")
  h <- as.numeric(sapply(p, `[`, 1)); m <- as.numeric(sapply(p, `[`, 2))
  amb <- s$amb[ci]
  cols <- ifelse(amb, "firebrick", "steelblue")

  # B: hour part (hour 0 is the normal "00:MM" duration and is left out so the tail is visible)
  if (length(h)) {
    keep <- h >= 1
    if (any(keep)) {
      hb <- table(factor(h[keep], levels = 1:max(12, h[keep])), factor(amb[keep], levels = c(FALSE, TRUE)))
      barplot(t(hb), col = c("steelblue", "firebrick"), border = "white",
              main = paste0(label, ": first number of colon entries, 1 or more\n(", sum(h == 0), " entries start with 0 and are left out; n shown = ", sum(keep), ")"),
              xlab = "first number (hours if read as H:MM)", ylab = "entries", cex.main = 0.9,
              legend.text = c("kept as typed", "read as MM:SS (flagged)"), args.legend = list(x = "topright", bty = "n", cex = 0.8))
    } else { plot.new(); title(main = paste0(label, ": every entry starts with 0")) }
  } else plot.new()

  # C: minute part
  if (length(m)) {
    mb <- table(factor(m, levels = 0:59))
    barplot(mb, col = "grey70", border = "white", main = paste0(label, ": colon entries, part after the colon"),
            xlab = "second number (a real MM:SS would be spread evenly; spikes at 0, 15, 30, 45 look like clock times)",
            ylab = "entries", cex.lab = 0.8)
  } else plot.new()

  # D: the implausible entries (first number >= 4: 4 hours or more if read as H:MM) read as a clock time.
  # Typed without AM/PM, so everything is folded onto a 12-hour dial (10:30 can be 10:30 am or pm).
  big <- h >= 4
  clock <- (h[big] %% 12) + m[big] / 60
  own <- lapply(own_times[[field]], function(v) v %% 12)
  dens <- lapply(own, function(v) { v <- v[!is.na(v)]; if (length(v)) hist(v, breaks = seq(0, 12, by = 1), plot = FALSE) else NULL })
  d1 <- hist(clock, breaks = seq(0, 12, by = 1), plot = FALSE)
  ymax <- max(d1$density, unlist(lapply(dens, function(d) if (!is.null(d)) d$density)), 0.01)
  plot(NULL, xlim = c(0, 12), ylim = c(0, ymax * 1.1), xlab = "hour on a 12-hour dial (am/pm ignored; 0 = 12 o'clock)",
       ylab = "share (density)", cex.main = 0.9,
       main = paste0(label, ": the ", sum(big), " entries of 4 hours or more, as a clock time,\nvs the participants' own times (12-hour dial)"))
  if (sum(big)) rect(d1$breaks[-length(d1$breaks)], 0, d1$breaks[-1], d1$density, col = adjustcolor("firebrick", 0.5), border = "white")
  lc <- c("black", "darkgreen")
  for (k in seq_along(dens)) if (!is.null(dens[[k]]))
    lines(dens[[k]]$mids, dens[[k]]$density, type = "s", col = lc[k], lwd = 2)
  legend("topright", bty = "n", cex = 0.8, lwd = c(8, rep(2, length(dens))),
         col = c(adjustcolor("firebrick", 0.5), lc[seq_along(dens)]),
         legend = c("typed values >= 4:00", paste("own", names(own))))
  cat("PNG:", file.path(out_dir, paste0(field, "_raw_distribution.png")), "\n")
}

# before vs after the pipeline's correction. "Before" reads the raw text the naive way (a plain
# number is minutes, H:MM is hours and minutes); "after" is the delivered numeric minutes.
plot_before_after <- function(field, label) {
  raw <- trimws(as.character(A[[paste0(field, "_selfreport_raw")]]))
  raw[raw %in% c("", "NA")] <- NA
  after <- suppressWarnings(as.numeric(A[[paste0(field, "_selfreport_minutes")]]))
  before <- rep(NA_real_, length(raw))
  pl <- !is.na(raw) & grepl("^[0-9]+(\\.[0-9]+)?$", raw)
  before[pl] <- as.numeric(raw[pl])
  co <- !is.na(raw) & grepl("^[0-9]{1,3}:[0-9]{2}$", raw)
  pp <- strsplit(raw[co], ":")
  before[co] <- as.numeric(sapply(pp, `[`, 1)) * 60 + as.numeric(sapply(pp, `[`, 2))
  ok <- !is.na(before) & !is.na(after)
  chg <- ok & abs(before - after) > 0.5
  cat("\n==", toupper(field), "before vs after the correction ==\n")
  cat("rows with a usable raw value and a delivered value:", sum(ok), "\n")
  cat("rows whose value changed:", sum(chg), "\n")
  if (any(chg)) {
    cat("changed rows, by size of the change (minutes removed):\n")
    print(table(cut(before[chg] - after[chg], c(-Inf, 0, 60, 240, 720, Inf),
                    labels = c("increased", "0-60", "60-240", "240-720", "720+"))))
  }
  cat("before: median", median(before[ok]), " mean", round(mean(before[ok]), 1), " max", max(before[ok]),
      " | after: median", median(after[ok]), " mean", round(mean(after[ok]), 1), " max", max(after[ok]), "\n")
  cat("values of 240 minutes or more -- before:", sum(before[ok] >= 240), " after:", sum(after[ok] >= 240), "\n")

  png(file.path(out_dir, paste0(field, "_before_after.png")), width = 1500, height = 1000, res = 130)
  op <- par(mfrow = c(2, 2), mar = c(4.2, 4.2, 3, 1)); on.exit({par(op); dev.off()})
  hist(pmin(before[ok], 725), breaks = seq(0, 730, by = 10), col = "grey70", border = "white",
       main = paste0(label, " BEFORE: raw text read naively (n = ", sum(ok), ")"),
       xlab = "minutes (bars of 10; last bar = 720 or more)")
  hist(pmin(after[ok], 725), breaks = seq(0, 730, by = 10), col = "steelblue", border = "white",
       main = paste0(label, " AFTER: delivered minutes"), xlab = "minutes (bars of 10; last bar = 720 or more)")
  hist(pmin(before[ok], 245), breaks = seq(0, 250, by = 5), col = "grey70", border = "white",
       main = paste0(label, " BEFORE, zoom 0-240"), xlab = "minutes (bars of 5)")
  hist(pmin(after[ok], 245), breaks = seq(0, 250, by = 5), col = "steelblue", border = "white",
       main = paste0(label, " AFTER, zoom 0-240"), xlab = "minutes (bars of 5)")
  cat("PNG:", file.path(out_dir, paste0(field, "_before_after.png")), "\n")
}

plot_field("waso", "WASO")
plot_field("sol", "SOL")
plot_before_after("waso", "WASO")
plot_before_after("sol", "SOL")
cat("\nDone. Figures are in", out_dir, "\n")
