#' Figure 12 (new) --- Step x Flag ledger table
#'
#' Replaces the coarse A-E bar chart. Renders one row per pipeline step and,
#' against the shared final standards, shows how each flag family is generated
#' and reduced across steps. "not computable at this step" shows as "---".
#'
#' Drop-in: replace the current Figure 12 block in sleep_visualization.R with a
#' call to `figure12_step_flag_table(cfg = cfg, output_dir = output_dir, save_png = save_png)`.
#' @param cfg Pipeline configuration list.
#' @param output_dir Directory for saving output PNG.
#' @param save_png Optional save function for PNG output.
#' @param filename Output PNG filename without extension.
#' @export
figure12_step_flag_table <- function(cfg = NULL, output_dir = ".", save_png = NULL,
                                      filename = "12_Pipeline_Correction_Progress") {
  long <- get_step_ledger_long()
  if (nrow(long) == 0) {
    cat("WARNING: Step ledger empty -- did run_pipeline call init_step_ledger()/log_step()? Skipping Figure 12.\n")
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

  # ── Table via grid/gtable only (gridExtra dropped from Imports) ─────────────
  # Visual contract matches the old gridExtra::tableGrob(ttheme_minimal):
  #   - column header: bold, centred in cell
  #   - body cells:    right-aligned (hjust = 1, x = 0.95), zebra-striped rows
  #   - first column (Step): left-aligned, plain weight
  nc <- ncol(disp_chr)
  nr <- nrow(disp_chr)
  zebra <- rep(c("grey97", "white"), length.out = nr)

  header_grobs <- lapply(seq_len(nc), function(j) {
    grid::textGrob(names(disp_chr)[j],
                   gp = grid::gpar(fontsize = 7.8, fontface = "bold"))
  })

  body_grobs <- vector("list", nr * nc)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      body_grobs[[(i - 1L) * nc + j]] <-
        if (j == 1L) {
          grid::textGrob(disp_chr[[j]][i], x = 0.05, hjust = 0,
                         gp = grid::gpar(fontsize = 7.2))
        } else {
          grid::textGrob(disp_chr[[j]][i], x = 0.95, hjust = 1,
                         gp = grid::gpar(fontsize = 7.2))
        }
    }
  }

  tab <- gtable::gtable(grid::unit(rep(1, nc), "null"), grid::unit(rep(1, nr + 1L), "null"))
  # zebra + header backgrounds (drawn first, z = 0)
  for (i in seq_len(nr)) {
    tab <- gtable::gtable_add_grob(tab,
      grid::rectGrob(gp = grid::gpar(fill = zebra[i], col = NA)),
      t = i + 1L, l = 1, r = nc, z = 0, clip = "off", name = paste0("zebra", i))
  }
  tab <- gtable::gtable_add_grob(tab,
    grid::rectGrob(gp = grid::gpar(fill = "grey92", col = NA)),
    t = 1L, l = 1, r = nc, z = 0, clip = "off", name = "header_bg")
  tab <- gtable::gtable_add_grob(tab, header_grobs, t = 1L, l = seq_len(nc), z = 1)
  tab <- gtable::gtable_add_grob(tab, body_grobs, t = rep(seq_len(nr) + 1L, each = nc),
                                 l = rep(seq_len(nc), nr), z = 1)

  # ── Vertical stack: title / subtitle / table / legend ───────────────────────
  title <- grid::textGrob("Figure 12: Per-Step Flag Ledger",
                    gp = grid::gpar(fontsize = 14, fontface = "bold"))
  sub <- grid::textGrob(paste0("Records in each final-standard flag category at every pipeline step. ",
                         "\u2014 = not yet computable at that step (first number = generation point). ",
                         "Corrected = data fixed; Suppressed = human-accepted."),
                  gp = grid::gpar(fontsize = 9, col = "grey30"))
  legend <- grid::textGrob(paste0("DC = data_category (temporal, Step 5)   SEV = flag_severity (metrics, Step 7)   ",
                            "CFE = checkforerrors (auto-detect, Step 8)   MISentry = field misentry (Step 1.5)"),
                     gp = grid::gpar(fontsize = 8, col = "grey45"))

  plot_obj <- gtable::gtable(grid::unit(1, "null"),
    grid::unit.c(grid::unit(1.4, "lines"), grid::unit(2.2, "lines"),
                 grid::unit(1, "null"), grid::unit(1.4, "lines")),
    name = "fig12")
  plot_obj <- gtable::gtable_add_grob(plot_obj,
    list(title, sub, tab, legend),
    t = 1:4, l = 1, z = 1)

  if (is.function(save_png)) {
    save_png(plot_obj, filename, subdir = "pipeline_cleaning",
             w = 12, h = max(4, 0.42 * nrow(disp) + 3))
  } else {
    ggplot2::ggsave(file.path(output_dir, paste0(filename, ".png")),
                    plot_obj, width = 12, height = max(4, 0.42 * nrow(disp) + 3), dpi = 150)
  }
  cat("Figure 12 (Per-Step Flag Ledger table) completed\n")
  invisible(TRUE)
}