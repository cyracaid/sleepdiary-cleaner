# 如何读懂管线输出（中文）

[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
跑完后，两个 CSV 文件告诉你一切。本文说明怎么读它们、怎么
对比上一次运行做回归检查、以及怎么看图。

``` r
library(splsleep)
```

## 1. `output/correction_status_final.csv` — 运行摘要（先看这个）

每次运行一行。回答”清洗是否按预期工作？”

``` r
read.csv("output/correction_status_final.csv")
```

| 列                   | 它告诉你…                           | 检查这个                                                                    |
|----------------------|-------------------------------------|-----------------------------------------------------------------------------|
| `n_total`            | 总记录数                            | 必须等于输入行数。若更小，某处丢了记录。                                    |
| `tst_mean_h`         | 平均总睡眠时间（小时）              | 大多数成人研究 6.0–8.5 h 正常。若 \< 5 或 \> 10，时间戳解析或研究人群异常。 |
| `sol_mean_min`       | 平均入睡潜伏期（分钟）              | 10–45 min 正常。若 \> 60，人群失眠率高或 AM/PM 混淆未完全修正。             |
| `n_clean`            | 通过所有检查的记录                  | 同数据多次运行应相同。                                                      |
| `n_error`            | 时序不可能记录（如 getup 早于 bed） | 应 \< 总记录 1%。若 \> 5%，审查问卷设计。                                   |
| `n_corrected`        | 经 CSV 人工修正的记录               | 应与 `manual_error_corrections.csv` 行数一致。                              |
| `timestamp_issue`    | 无法解析为有效时间的时间戳          | 0 正常。\> 0 表示参与者填了非标准时间格式。                                 |
| `duration_issue`     | 超出配置阈值的睡眠指标              | 少量正常。若很大，阈值太严或数据质量有问题。                                |
| `amount_flag`        | 异常物质使用条目                    | 应为 0 或很低。                                                             |
| `self_reported_flag` | 自报 SOL/WASO 与计算值分歧的记录    | 指示感知偏差。看图 20（SOL 感知偏差）。                                     |

**稳定性规则**：同一数据跑两次 → 每个数字必须相同。否则非确定性。

## 2. `output/step_flag_ledger.csv` — 每步标记追踪（第二个看）

每行 = 步骤 × 标准 × 类别。回答”哪个步骤出现哪种标记，是否持续？”

``` r
ledger <- read.csv("output/step_flag_ledger.csv")
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

ledger 用 5 个独立评估系统：

| 标准               | 首个有数字的步骤 | 评估什么                                              | 关键类别                                                                       |
|--------------------|:----------------:|-------------------------------------------------------|--------------------------------------------------------------------------------|
| `field_misentry`   |       1.5        | 时长估计（SOL、WASO）是否恰好匹配时间戳——可能”填错框” | `none`, `SOL=time_sleep`, `SOL=time_bed`, `WASO=time_awake`, `WASO=time_getup` |
| `data_category`    |        4         | bed → sleep → awake → getup 序列的时序与合理性        | `clean`, `error`, `unusual`, `equal_time_ok`, `skipped_na`                     |
| `flag_severity`    |        7         | 每条记录触发多少派生指标标记                          | `Clean`, `Minor (1 flag)`, `Major (2+ flags)`                                  |
| `duration_extreme` |        7         | 生理合理界外的总睡眠时间                              | `OK`, `Too short (< 3 h)`, `Too long (> 12 h)`                                 |
| `checkforerrors`   |        8         | Step 8 汇总的自动检测标记                             | `TIMESTAMP_ISSUE`, `DURATION_ISSUE`, `AMOUNT_FLAG`, `SELF_REPORTED_FLAG`       |

**概念规则**：标准只计算一次、从不重算。若某标准计数在其首次计算步骤后改变，
就有问题。

**验证规则**：

1.  `field_misentry` — Step 1.5 起有数。任何 `SOL=time_bed` 或
    `WASO=time_getup` `count > 0` = 潜在跨字段污染。
2.  `data_category` — Step 6
    起数字必须**稳定**：`equal_time_ok + skipped_na = n_total`。
3.  `flag_severity` — Step 7 起 Steps 7/8/8.5 完全相同：
    `Clean + Minor + Major = n_total - skipped_na`。
4.  `duration_extreme` — `Too short + Too long` 应 \< 总记录 5%。
5.  `checkforerrors` — 仅 Step 8 有数据。

**示例（合成数据，280 行）**：

    Step 7 (Compute metrics):
      data_category:    equal_time_ok = 266, skipped_na = 14        266 + 14 = 280 ✓
      flag_severity:    Clean = 251, Minor = 28, Major = 1         251 + 28 + 1 = 280 - 14 ✓
      duration_extreme: OK = 262, Too short = 1, Too long = 0

## 3. 回归检查（对比上次运行）

`output/correction_status_old.csv`
不是任何管线脚本写的——重跑前你自己另存一份 基线：

``` r
# 重跑之前：把当前结果存成基线
file.copy("output/correction_status_final.csv", "output/correction_status_old.csv",
          overwrite = TRUE)
# ……在此重跑管线……
# 重跑之后：和基线对比
old <- read.csv("output/correction_status_old.csv")
new <- read.csv("output/correction_status_final.csv")
identical(old$tst_mean_h, new$tst_mean_h)
identical(old$sol_mean_min, new$sol_mean_min)
identical(old$n_clean, new$n_clean)
```

输入数据没变但结果不同 → 管线输出变了，需调查。

## 4. 快速检查卡

| 检查项             | 如何验证                                            | 通过条件 |
|--------------------|-----------------------------------------------------|----------|
| 管线完成           | `file.exists("output/correction_status_final.csv")` | `TRUE`   |
| TST 合理           | `tst_mean_h` 在 6–8.5                               | 是       |
| SOL 合理           | `sol_mean_min` 在 10–45                             | 是       |
| 错误少             | `n_error < 0.01 * n_total`                          | 是       |
| data_category 稳定 | Steps 6–8.5 计数相同                                | 是       |
| flag_severity 稳定 | Steps 7–8.5 计数相同                                | 是       |
| 全记录有交代       | `equal_time_ok + skipped_na = n_total`              | 是       |
| 确定性             | 同输入 → 同输出，每次                               | 是       |

## 5. 如何看图

图保存在 `latest_visualization_<tag>_n<rows>/`（每次运行覆盖——无历史）。
`figure_index.png` 总览所有图。稳定验证产物（snapshot、Bland-Altman
图、阈值 验证）单独在 `output/verification/<tag>/`。

**出版用图（Methods 部分）：**

| 图                  | 文件                                             | 显示什么                                                                |
|---------------------|--------------------------------------------------|-------------------------------------------------------------------------|
| **图 1 — 管线流程** | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` | 垂直流程图：raw → 解析 → 算法修正 → 人工修正 → 最终有效，各阶段计数与 % |
| **图 2 — 修正影响** | `research_ready/02_Correction_Impact.png`        | A/B delta lollipop（仅修正记录，TST & SOL）+ 一致性散点 + 前后汇总表    |

**5 张必看检查图：**

| 步骤 | 图                        | 应该像                                         | 若不是？                   |
|:----:|---------------------------|------------------------------------------------|----------------------------|
|  1   | **01 最终数据质量仪表板** | TST/SOL/WASO/SE 直方图钟形，无 0 或极端尖峰    | 0 尖峰 = 缺失数据/解析失败 |
|  2   | **12 管线修正进度**       | Corrected 条仅在 C（Step 6.5）出现，之后平     | C 后变化 = 不稳定          |
|  3   | **18 自动检测仪表板**     | flag 计数与 `correction_status_final.csv` 匹配 | 不匹配 = 错位              |
|  4   | **02 睡眠变量分布**       | TST 峰 6–8 h，SOL 右偏，WASO \< 60，SE \> 85%  | SOL 平/双峰 = AM/PM 混淆   |
|  5   | **19 统一质量状态**       | 多数记录 Clean/Minor；Error+Unusual \< 5%      | 高 = 审人工 CSV            |
