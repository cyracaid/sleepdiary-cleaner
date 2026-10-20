# 输出文件一览（中文）

[English
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/output-files.md)

一次运行把文件写在三个地方：**项目文件夹**（你给的
`project_dir`）、它下面的
`output/`，以及图的文件夹。项目文件夹里的是审核用的工作文件，含参与者的行，不能提交。每张表里的文件按写出顺序排列。

## 项目文件夹（不在 `output/`）

| 文件                                      | 何时写出                       | 是什么                                                                                                                                                                                                                                                                                                                                                 |
|-------------------------------------------|--------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `cross_participant_field_misentries.csv`  | Step 1.5                       | SOL 或 WASO 的数字像填进了别的时间栏的行。在原始数据上检测                                                                                                                                                                                                                                                                                             |
| `[NEW]manual_error_correction_review.csv` | Step 5 写出，Step 8.5 之后重写 | 一张状态表：Step 5 的每条 `error` 记录，加上修正之后才变成错误的记录。列：`status_after_corrections`、`in_manual_file`、`category_before_corrections`、`category_after_corrections`、`step8_flags_after_corrections`。仍需人处理的行排在最前。见[读懂输出与审核循环](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output-zh.md) |
| `[NEW]manual_unusual_review.csv`          | Step 5                         | `unusual` 记录，审核列为空                                                                                                                                                                                                                                                                                                                             |
| `manual_error_correction_updated.csv`     | Step 6                         | 已应用修正的记录：你的 `manual_error_corrections.csv` 被流水线纳入之后的副本，`manually_corrected` 标明实际用上的行。你自己的文件不会被改动。不是待办清单                                                                                                                                                                                              |
| `reasonable_unusual_records.csv`          | Step 6                         | 你标为”reasonable unusual record”（异常但合理，保持原样）的 `unusual` 行                                                                                                                                                                                                                                                                               |
| `cross_participant_flagged_rows.csv`      | Step 8.5                       | SOL 或 WASO 明显偏离**此人自己**中位数的日子                                                                                                                                                                                                                                                                                                           |
| `cross_participant_suspicious_slices.csv` | Step 8.5                       | 上一个文件中参与者的全部天数，作上下文                                                                                                                                                                                                                                                                                                                 |

## `output/`

| 文件                                          | 何时写出    | 是什么                                                                                                                                          |
|-----------------------------------------------|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| `correction_status.csv`                       | 每个检查点  | 每个检查点（A–E）一行：各类记录的数量、平均 TST 和 SOL；每次运行追加，带 `run_id`                                                               |
| `step_flag_ledger.csv`                        | Step 9 之后 | 每行是 步骤 × 标准 × 类别：该步骤中有多少记录落入这一类（运行中记录，接近结尾写出）                                                             |
| `flagged_records_self_reported.csv`           | Step 8      | 标为 `SELF_REPORTED_FLAG` 的记录（例如 SOL 超过 120 分钟）                                                                                      |
| `corrected_ema_data.rds`                      | Step 7      | 流水线修正并算出睡眠指标之后的工作数据，所有列                                                                                                  |
| `audit_integrity_report.csv`                  | Step 9 之后 | 修正后数据与输入的完整性检查：行、列、未触及的变量、重复                                                                                        |
| `appendix_step_ledger.csv`                    | Step 9      | 图 A1 画的完整逐步账本                                                                                                                          |
| `cleaned_data_final.csv` / `.rds`             | Step 10     | **数据集 A**，面向分析的列（由列字典决定）                                                                                                      |
| `cleaned_data_prepostcorrection.csv` / `.rds` | Step 10     | **数据集 B**：修正前后的值，以及每行的审计处置                                                                                                  |
| `cleaned_data_full.rds`                       | Step 10     | 全部内容，未改动                                                                                                                                |
| `column_dictionary_gaps.csv`                  | Step 10     | 数据里有、但列字典没有描述的列                                                                                                                  |
| `correction_status_final.csv`                 | 结束时      | **运行摘要。** 每次运行追加一行。见[读懂输出与审核循环](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output-zh.html#s-4) |

## 图文件夹 `latest_visualization_<tag>_n<rows>/`

每次出图都从头重建。`<tag>` 是数据集标签（`real`、`synth`），`n`
是输入记录数。

| 项目                                    | 是什么                                         |
|-----------------------------------------|------------------------------------------------|
| `pipeline_cleaning/`、`research_ready/` | 诊断图和论文用图                               |
| `figure_index.png`                      | 全部图的总览；顶部红色块列出被跳过的图         |
| `all_figures_review.pdf`                | 每页一张图                                     |
| `figures_not_generated.csv`             | 没有生成的图及原因                             |
| `flag_distribution.csv`                 | 每条记录一行，含标记数和详情                   |
| `classification_summary.csv`            | 各最终分类的数量（只有运行产生了分类时才写出） |
| `RUN_INFO.txt`                          | 何时、哪个标签、多少条记录、哪个包版本         |

## 验证文件夹 `verification/<tag>_n<rows>/`

图被重建时**不会被清空**：自报与计算的 SOL、WASO 的 Bland-Altman
图、`threshold_validation.csv`、用于与上一次运行对照的快照，以及
`PROVENANCE.txt`。

## 重跑之前

重跑会覆盖这些文件。要保留以前的结果，先复制整个项目文件夹，在副本里运行。
