#' Sync Human Review Status
#' @description 读取 manual_metric_review_acceptances.csv，根据人工处理痕迹自动同步 review_resolution / resolved_at / resolved_by 字段
#' @param csv_path CSV 文件路径
#' @param overwrite 是否覆盖已有字段（默认 TRUE）
#' @return 更新后的 data.frame（不可见返回）
#' @export
#' @importFrom readr read_csv write_csv
#' @importFrom dplyr rowwise mutate ungroup case_when
#' @importFrom utils globalVariables
#' @name sync_human_review_status
NULL
utils::globalVariables(c(
  "human_metric_review_note", "resolved_at", "resolved_by",
  "review_resolution", "has_human_trace"
))
sync_human_review_status <- function(csv_path = "manual_metric_review_acceptances.csv",
                                     overwrite = TRUE) {
  df <- readr::read_csv(csv_path, show_col_types = FALSE)
  
  # 确保必要列存在
  if (!"human_metric_review_note" %in% names(df)) {
    warning("缺少 human_metric_review_note 列，跳过同步")
    return(invisible(NULL))
  }
  
  # 判断是否有人工处理痕迹
  has_human_trace <- function(row) {
    has_note <- !is.na(row$human_metric_review_note) && row$human_metric_review_note != ""
    has_resolved_at <- !is.na(row$resolved_at) && row$resolved_at != ""
    has_resolved_by <- !is.na(row$resolved_by) && row$resolved_by != ""
    has_note <- !is.na(row$human_metric_review_note) && row$human_metric_review_note != ""
    any(has_note, has_resolved_at, has_resolved_by)
  }
  
  # 计算新字段
  result <- df %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      # 是否有人工处理痕迹
      has_human_trace = any(
        !is.na(human_metric_review_note) & human_metric_review_note != "",
        !is.na(resolved_at) & resolved_at != "",
        !is.na(resolved_by) && resolved_by != ""
      ),
      
      # 计算 review_resolution
      review_resolution = dplyr::case_when(
        # 已有 review_resolution 且非 legacy，保留原值（假设人工已确认）
        !is.na(review_resolution) & review_resolution != "legacy" ~ review_resolution,
        # 有处理痕迹但 resolution 为 legacy/NA -> 标记为 flagged_unresolved（待人工确认）
        has_human_trace() & (is.na(review_resolution) | review_resolution == "legacy") ~ "flagged_unresolved",
        # 无痕迹且为 legacy -> 保持 legacy
        TRUE ~ "legacy"
      ),
      
      # resolved_at: 只有 corrected 才有日期
      resolved_at = dplyr::case_when(
        review_resolution == "corrected" ~ format(Sys.Date(), "%Y-%m-%d"),
        TRUE ~ NA_character_
      ),
      
      # resolved_by
      resolved_by = dplyr::case_when(
        review_resolution == "corrected" ~ "system",
        review_resolution == "legacy" ~ "legacy",
        # 有痕迹但未标 resolved -> 待处理
        TRUE ~ "pending"
      )
    ) %>%
    dplyr::ungroup()
  
  # 回写 CSV
  if (overwrite) {
    readr::write_csv(result, csv_path)
    cat(sprintf("✓ Synced %d rows: %d corrected, %d flagged, %d legacy\n",
                nrow(result),
                sum(result$review_resolution == "corrected"),
                sum(result$review_resolution == "flagged_unresolved"),
                sum(result$review_resolution == "legacy", na.rm = TRUE)))
  }
  
  invisible(result)
}
