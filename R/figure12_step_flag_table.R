#' Figure 12 (new) — Step x Flag ledger table
#'
#' Replaces the coarse A-E bar chart. Renders one row per pipeline step and,
#' against the shared final standards, shows how each flag family is generated
#' and reduced across steps. "not computable at this step" shows as "—".
#'
#' Drop-in: replace the current Figure 12 block in sleep_visualization.R with a
#' call to `figure12_step_flag_table(cfg = cfg, output_dir = output_dir, save_png = save_png)`.
#' @export
figure12_step_flag_table <- function(cfg = NULL, output_dir = ".", save_png = NULL,
                                      filename = "12_Pipeline_Correction_Progress") {
  long <- get_step_ledger_long()
  if (nrow(long) == 0) {
    cat("⚠ Step ledger empty — did run_pipeline call init_step_ledger()/log_step()? Skipping Figure 12.\n")
    return(invisible(FALSE))
  }

  steps <- unique(long[, c("step_id", "label", "n_total", "n_corrected", "n_suppressed")])
  steps <- steps[order(as.numeric(steps$step_id)), ]

  cell <- function(sid, std, cat) {
    v <- long$count[long$step_id == sid & long$standard == std & long$category == cat]
    if (length(v) == 0) NA_integer_ else v[1]
  }

  flagged <- function(sid, std, bad) {
    vs <- vapply(bad, function(c) cell(sid, std, c), integer(1))
    if (all(is.na(vs))) NA_integer_ else sum(vs, na.rm = TRUE)
  }

  fmt <- function(x) ifelse(is.na(x), "\u2014", as.character(x))

  disp <- data.frame(
    Step        = paste0(steps$step_id, "  ", steps$label),
    N           = steps$n_total,
    `DC:error`  = vapply(steps$step_id, cell, integer(1), std = "data_category", cat = "error"),
    `DC:unusual`= vapply(steps$step_id, function(s) {
                    u <- cell(s, "data_category", "unusual")
                    ru <- cell(s, "data_category", "reasonable_unusual")
                    if (is.na(u) && is.na(ru)) NA_integer_ else sum(c(u, ru), na.rm = TRUE)
                  }, integer(1)),
    `SEV:Minor` = vapply(steps$step_id, cell, integer(1), std = "flag_severity", cat = "Minor issues (1 flag)"),
    `SEV:Major` = vapply(steps$step_id, cell, integer(1), std = "flag_severity", cat = "Major issues (2+ flags)"),
    `CFE:flag`  = vapply(steps$step_id, flagged, integer(1), std = "checkforerrors",
                         bad = c("NEEDS_REVIEW","TIMESTAMP_ISSUE","DURATION_ISSUE","AMOUNT_FLAG","SELF_REPORTED_FLAG")),
    `MISentry`  = vapply(steps$step_id, flagged, integer(1), std = "field_misentry",
                         bad = c("SOL=time_sleep","SOL=time_bed","WASO=time_awake","WASO=time_getup")),
    Corrected   = steps$n_corrected,
    Suppressed  = steps$n_suppressed,
    check.names = FALSE, stringsAsFactors = FALSE
  )

  disp_chr <- disp
  for (j in 2:ncol(disp_chr)) disp_chr[[j]] <- fmt(disp[[j]])

  tt <- gridExtra::ttheme_minimal(
    core = list(fg_params = list(hjust = 1, x = 0.95, cex = 0.72),
                bg_params = list(fill = c("grey97", "white"))),
    colhead = list(fg_params = list(cex = 0.78, fontface = "bold"))
  )
  tbl <- gridExtra::tableGrob(disp_chr, rows = NULL, theme = tt)

  title <- grid::textGrob("Figure 12: Per-Step Flag Ledger",
                    gp = grid::gpar(fontsize = 14, fontface = "bold"))
  sub <- grid::textGrob(paste0("Records in each final-standard flag category at every pipeline step. ",
                         "\u2014 = not yet computable at that step (first number = generation point). ",
                         "Corrected = data fixed; Suppressed = human-accepted."),
                  gp = grid::gpar(fontsize = 9, col = "grey30"))
  legend <- grid::textGrob(paste0("DC = data_category (temporal, Step 5)   SEV = flag_severity (metrics, Step 7)   ",
                            "CFE = checkforerrors (auto-detect, Step 8)   MISentry = field misentry (Step 1.5)"),
                     gp = grid::gpar(fontsize = 8, col = "grey45"))

  plot_obj <- gridExtra::arrangeGrob(title, sub, tbl, legend, ncol = 1,
                          heights = grid::unit.c(grid::unit(1.4, "lines"), grid::unit(2.2, "lines"),
                                           grid::unit(1, "null"), grid::unit(1.4, "lines")))

  if (is.function(save_png)) {
    save_png(plot_obj, filename, subdir = "pipeline_cleaning",
             w = 12, h = max(4, 0.42 * nrow(disp) + 3))
  } else {
    ggplot2::ggsave(file.path(output_dir, paste0(filename, ".png")),
                    plot_obj, width = 12, height = max(4, 0.42 * nrow(disp) + 3), dpi = 150)
  }
  cat("✓ Figure 12 (Per-Step Flag Ledger table) completed\n")
  invisible(TRUE)
}
