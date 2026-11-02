# ambiguous_flag_counts.R -- how many SOL and WASO duration entries carry the "ambiguous" flag?
#
# The flag (sol_selfreport_ambiguous, waso_selfreport_ambiguous in Dataset A) marks an entry the
# interval parser read under the MM:SS rule: a clock-looking "12:05" read as 12 min 5 s.
# Reads output/cleaned_data_final.csv (read only). Writes one PNG and prints counts only.
# Nothing is written inside the repository by default.
#
# Usage (from the repository root):
#   RENV_CONFIG_AUTOLOADER_ENABLED=FALSE Rscript validation/ambiguous_flag_counts.R [out_dir]
# Default out_dir: ~/Desktop/ambiguous_flag_counts

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[1] else file.path(path.expand("~"), "Desktop", "ambiguous_flag_counts")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

A <- read.csv("output/cleaned_data_final.csv", stringsAsFactors = FALSE)
fields <- c(SOL = "sol", WASO = "waso")
flag <- function(f) A[[paste0(f, "_selfreport_ambiguous")]] %in% c(TRUE, "TRUE")
filled <- function(f) { r <- trimws(as.character(A[[paste0(f, "_selfreport_raw")]])); !(is.na(r) | r %in% c("", "NA")) }

res <- do.call(rbind, lapply(names(fields), function(lab) {
  f <- fields[[lab]]
  data.frame(field = lab, entries = sum(filled(f)), flagged = sum(flag(f) & filled(f)),
             participants_with_a_flag = length(unique(A$pid[flag(f)])),
             participants_with_entries = length(unique(A$pid[filled(f)])))
}))
res$percent_flagged <- round(100 * res$flagged / res$entries, 2)
cat("\nAmbiguous (read as MM:SS) entries\n"); print(res, row.names = FALSE)
either <- flag("sol") | flag("waso")
both <- flag("sol") & flag("waso")
cat("\nrows flagged in either field:", sum(either), " in both:", sum(both), "\n")

png(file.path(out_dir, "ambiguous_flag_counts.png"), width = 1500, height = 1050, res = 130)
op <- par(mfrow = c(2, 2), mar = c(4.2, 4.6, 3.2, 1)); on.exit({par(op); dev.off()})
cols <- c(SOL = "steelblue", WASO = "darkorange")

# A: counts
b <- barplot(res$flagged, names.arg = res$field, col = cols[res$field], border = "white",
             ylim = c(0, max(res$flagged) * 1.25), ylab = "entries flagged ambiguous",
             main = "Ambiguous duration entries")
text(b, res$flagged, labels = paste0(res$flagged, " of ", format(res$entries, big.mark = ","),
     "\n(", res$percent_flagged, "%)"), pos = 3, cex = 0.85)

# B: how many participants
pp <- function(f) { t <- table(factor(A$pid[flag(f)])); c(`1` = sum(t == 1), `2` = sum(t == 2), `3 or more` = sum(t >= 3)) }
M <- rbind(SOL = pp("sol"), WASO = pp("waso"))
barplot(M, beside = TRUE, col = cols[rownames(M)], border = "white", ylab = "participants",
        xlab = "number of flagged days per participant",
        main = "Is it a few people or many?", legend.text = rownames(M),
        args.legend = list(x = "topright", bty = "n", cex = 0.85))

# C: by study day
days <- sort(unique(A$day_num[!is.na(A$day_num)]))
cnt <- sapply(fields, function(f) sapply(days, function(d) sum(flag(f) & A$day_num == d, na.rm = TRUE)))
matplot(days, cnt, type = "b", pch = 16, lty = 1, col = cols[colnames(cnt)], xlab = "study day",
        ylab = "entries flagged ambiguous", main = "Does it fall as people learn the form?")
legend("topright", legend = colnames(cnt), col = cols[colnames(cnt)], pch = 16, lty = 1, bty = "n", cex = 0.85)

# D: the size of what was typed (read as H:MM), only the flagged entries
sizes <- function(f) { r <- A[[paste0(f, "_selfreport_raw")]][flag(f)]; as.numeric(sapply(strsplit(r, ":"), `[`, 1)) }
hs <- lapply(fields, sizes)
hmax <- max(unlist(hs), 12)
brk <- seq(3.5, hmax + 0.5, by = 1)
hist(hs$SOL, breaks = brk, col = adjustcolor(cols[["SOL"]], 0.6), border = "white", xlab = "number before the colon (4 or more = 4 hours or more as H:MM)",
     main = "What was typed in the flagged entries", ylim = c(0, max(table(factor(unlist(hs))), 1) * 1.15))
hist(hs$WASO, breaks = brk, col = adjustcolor(cols[["WASO"]], 0.6), border = "white", add = TRUE)
legend("topright", legend = names(cols), fill = adjustcolor(cols, 0.6), border = NA, bty = "n", cex = 0.85)

cat("PNG:", file.path(out_dir, "ambiguous_flag_counts.png"), "\n")
