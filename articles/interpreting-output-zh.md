# 如何读懂管线输出（中文）

[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
跑完后，两个 CSV 文件告诉你一切。本文说明怎么读它们、怎么
对比上一次运行做回归检查、以及怎么看图。

``` r
library(sleepcleanr)
```

## 术语

本文通篇会用到的**睡眠指标**：

| 术语     | 含义                                                   |
|----------|--------------------------------------------------------|
| **TIB**  | Time in Bed，卧床时间——从躺下到起床                    |
| **SOL**  | Sleep Onset Latency，入睡潜伏期——从躺下到真正睡着      |
| **TST**  | Total Sleep Time，总睡眠时间——实际睡着的时间           |
| **WASO** | Wake After Sleep Onset，睡后觉醒——入睡后夜间醒着的时间 |
| **SE**   | Sleep Efficiency，睡眠效率——卧床时间中真正睡着的百分比 |

它们之间有一个贯穿全部图表的恒等式：`TIB = TST + SOL + WASO`，
`SE = TST / TIB`。

**分类系统**——下面几乎每张图、每张表都会挂上这些标签。它们是管线内部
的专有词汇，不是睡眠科学的术语，所以第一次碰到之前值得先了解一下：

- **`data_category`**——某条记录的*时间戳*形状如何。每条记录恰好落入
  以下五类之一：`clean`（没有异常）、`unusual`（奇怪但合理，比如间隔 \>
  3 小时）、`error`（顺序不可能，或零时长睡眠）、`equal_time_ok`
  （两个相邻时间点填了同一个时刻——良性的填表习惯，不算错误）、
  `skipped_na`（必需的时间戳缺失）。完整规则和边界情况见后面的 §6.3
  关键定义。
- **`flag_severity`**——某条记录触发了多少个*派生指标*问题（睡眠效率
  过低、入睡潜伏期过长、觉醒时间过长）：`Clean`（0个）、`Minor`
  （1个）、`Major`（2个及以上）。这是一个和 `data_category`**不同**
  的系统——一条记录可以 `data_category = clean` 同时
  `flag_severity = Major`（时间戳顺序没问题，但算出来的指标看起来
  很极端），反之亦然。
- **“standard”（标准）**（如 §2 的 ledger 中所用）就是指这些评估系统
  之一。一共有五个，每个都在固定的某一步计算一次，之后不再重算。

后文会自由使用这些术语。如果在某张图里碰到不确定的词，本节和 §6.3
关键定义是两个可以回头查的地方。

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

**关于 SOL 的说明**：上面的 `sol_mean_min` 是**原始 SOL 时长**。这和 图
20 检查的”SOL 感知偏差”（自报值与计算值之间的差距，见 §6.2）是
不同的量——两处用的参考数字不一样（这里是 10–45 分钟，那边是 15/60
分钟），因为它们衡量的根本不是同一件事。不要拿这两组数字互相 对照。

## 2. `output/step_flag_ledger.csv` — 每步标记追踪（第二个看）

每行 = 步骤 × 标准 × 类别。回答”哪个步骤出现哪种标记，是否持续？”

``` r
ledger <- read.csv("output/step_flag_ledger.csv")
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

每行回答：“这一步、用这个标准、有多少记录落入这个类别？”

### 列布局

| 列            | 含义                                    |
|---------------|-----------------------------------------|
| `step_id`     | 管线步骤编号                            |
| `label`       | 步骤名称（人类可读）                    |
| `n_total`     | 管线此处的记录总数                      |
| `standard`    | 被追踪的评估系统（见下）                |
| `category`    | 该标准下的具体类别                      |
| `count`       | 该类别中的记录数（NA = 此步骤尚未计算） |
| `n_corrected` | 此步骤人工修正的记录数                  |

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

| 检查项                           | 如何验证                                            | 通过条件 |
|----------------------------------|-----------------------------------------------------|----------|
| 管线完成                         | `file.exists("output/correction_status_final.csv")` | `TRUE`   |
| TST 合理                         | `tst_mean_h` 在 6–8.5                               | 是       |
| SOL 合理（原始时长，非感知偏差） | `sol_mean_min` 在 10–45                             | 是       |
| 错误少                           | `n_error < 0.01 * n_total`                          | 是       |
| data_category 稳定               | Steps 6–8.5 计数相同                                | 是       |
| flag_severity 稳定               | Steps 7–8.5 计数相同                                | 是       |
| 全记录有交代                     | `equal_time_ok + skipped_na = n_total`              | 是       |
| 确定性                           | 同输入 → 同输出，每次                               | 是       |

## 5. 如何看图

图保存在 `latest_visualization_<tag>_n<rows>/`（每次运行覆盖——无历史）。
`figure_index.png`
总览所有图；如果有图没能生成，整张图**最顶部**会有一个红色的 “FIGURE(S)
NOT GENERATED THIS RUN”
区块，逐条列出没生成的图和原因。稳定验证产物（snapshot、Bland-Altman
图、阈值 验证）单独在 `output/verification/<tag>/`。

**第一次看这些图？** 先看 `figure_index.png` 总览，再按顺序过一遍下面 “5
张必看检查图”——它们合起来就是一次浓缩版的睡眠数据质量 QC。这里出现
的每个图号（比如 “01”、“13D”）都对应 §6.2 里的一个标题，可以直接跳过去
看完整解释。文件夹的划分（`pipeline_cleaning/` = 质控/审计图，
`research_ready/` = 为论文准备的图）只有在你决定论文放哪张图时才重要——
如果只是检查数据，按图号找就行，不用管文件夹。

**出版用图（Methods 部分）：**

| 图                  | 文件                                             | 显示什么                                                                |
|---------------------|--------------------------------------------------|-------------------------------------------------------------------------|
| **图 1 — 管线流程** | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` | 垂直流程图：raw → 解析 → 算法修正 → 人工修正 → 最终有效，各阶段计数与 % |
| **图 2 — 修正影响** | `research_ready/02_Correction_Impact.png`        | A/B delta lollipop（仅修正记录，TST & SOL）+ 一致性散点 + 前后汇总表    |

**5 张必看检查图：**

| 步骤 | 图（卡片）                   | 应该长这样                                                | 若不是？                                                  |
|:----:|------------------------------|-----------------------------------------------------------|-----------------------------------------------------------|
|  1   | **01 管线记录流** (§6.2)     | 流程平缓收窄；Clean 占主导；Error + Unusual 很小（\< 5%） | 0 处有尖峰或 Error/Unusual 占比巨大 → 上游解析/AM-PM 失败 |
|  2   | **A1 逐步标记账本** (§6.2)   | Corrected 柱只在 Step 6.5 出现，之后持平                  | Step 6.5 之后再变化 = 不稳定                              |
|  3   | **18 自动检测仪表板** (§6.2) | 标记计数与 `correction_status_final.csv` 一致             | 不一致 = 错位                                             |
|  4   | **02B 睡眠变量分布** (§6.2)  | TST 峰值在 6–8 h，SOL 右偏，WASO \< 60，SE \> 85%         | SOL 平/双峰 = AM/PM 混淆未修正                            |
|  5   | **13 错误类别分布** (§6.2)   | 多数记录 Clean/Minor；Error+Unusual \< 5%                 | 偏高 → 审查人工 CSV                                       |

## 6. 逐图参考

管线产出的每一张图都在下面记成一张自成一体的卡片：每个部分是什么意思、
它是根据什么精确规则画出来的、健康数据长什么样、异常意味着什么，以及
一段可以直接用在论文里的图注。图落在
`latest_visualization_<tag>_n<rows>/pipeline_cleaning/`（诊断用）和
`.../research_ready/`（出版用）两个文件夹里。

### 6.1 图索引

| \#      | 文件                                                      | 论文用途    | 代码来源                        | 卡片                              | 最后核对   |
|---------|-----------------------------------------------------------|-------------|---------------------------------|-----------------------------------|------------|
| **01**  | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png`          | Methods 图1 | `sleep_visualization.R:862`     | §6.2 · 管线记录流                 | 2026-09-25 |
| **02**  | `research_ready/02_Correction_Impact.png`                 | Methods 图2 | `sleep_visualization.R:1013`    | §6.2 · 修正影响                   | 2026-09-25 |
| **02B** | `research_ready/02B_Distribution_Sleep_Variables.png`     | Results     | `sleep_visualization.R:1057`    | §6.2 · 睡眠变量分布               | 2026-09-25 |
| **03**  | `research_ready/03_Sleep_Duration_Distribution.png`       | Results     | `sleep_visualization.R:1108`    | §6.2 · TST 分布                   | 2026-09-25 |
| **04**  | `research_ready/04_Sleep_Duration_vs_Time_in_Bed.png`     | Results     | `sleep_visualization.R:1163`    | §6.2 · 睡眠时长 vs 卧床时间       | 2026-09-25 |
| **04B** | `research_ready/04B_SOL_vs_Sleep_Duration.png`            | Results     | `sleep_visualization.R:1215`    | §6.2 · SOL vs 睡眠时长            | 2026-09-25 |
| **05**  | `research_ready/05_Variability_Sleep_Variables.png`       | Results     | `sleep_visualization.R:1265`    | §6.2 · 睡眠变量的变异性           | 2026-09-25 |
| **06**  | `pipeline_cleaning/06_Sleep_Duration_Post_Correction.png` | Supplement  | `sleep_visualization.R:1339`    | §6.2 · 修正后睡眠时长             | 2026-09-25 |
| **07**  | `pipeline_cleaning/07_Flag_Composition_Stacked.png`       | Supplement  | `sleep_visualization.R:1404`    | §6.2 · 标记构成堆叠图             | 2026-09-25 |
| **09**  | `research_ready/09_Bedtime_vs_Getup_Distribution.png`     | Results     | `sleep_visualization.R:1458`    | §6.2 · 就寝 vs 起床时间分布       | 2026-09-25 |
| **10**  | `pipeline_cleaning/10_Extreme_Sleep_Duration.png`         | Supplement  | `sleep_visualization.R:1514`    | §6.2 · 极端睡眠时长               | 2026-09-25 |
| **13**  | `pipeline_cleaning/13_Error_Category_Distribution.png`    | Supplement  | `sleep_visualization.R:1794`    | §6.2 · 错误类别分布               | 2026-09-25 |
| **13B** | `pipeline_cleaning/13B_Adjacent_Timestamp_Gaps.png`       | Supplement  | `sleep_visualization.R:1877`    | §6.2 · 相邻时间戳间隔             | 2026-09-25 |
| **13C** | `pipeline_cleaning/13C_Detection_Outcomes_Heatmap.png`    | Supplement  | `sleep_visualization.R:1936`    | §6.2 · 检测结果热力图             | 2026-09-25 |
| **13D** | `pipeline_cleaning/13D_Threshold_vs_Noise_Ratio.png`      | Supplement  | `sleep_visualization.R:1980`    | §6.2 · 阈值 vs 测量噪声           | 2026-09-25 |
| **14**  | `pipeline_cleaning/14_Sleep_Duration_Pre_Correction.png`  | Supplement  | `sleep_visualization.R:2051`    | §6.2 · 修正前睡眠时长             | 2026-09-30 |
| **15**  | `pipeline_cleaning/15_Error_Timeline.png`                 | Supplement  | `sleep_visualization.R:2137`    | §6.2 · 错误时间线                 | 2026-09-30 |
| **16**  | `pipeline_cleaning/16_Common_Error_Patterns.png`          | Supplement  | `sleep_visualization.R:2228`    | §6.2 · 常见错误模式               | 2026-09-30 |
| **17**  | `pipeline_cleaning/17_Top_Participants_Flags.png`         | Supplement  | `sleep_visualization.R:2307`    | §6.2 · 标记率最高的参与者         | 2026-09-25 |
| **18**  | `pipeline_cleaning/18_Auto_Detected_Dashboard.png`        | Supplement  | `sleep_visualization.R:2409`    | §6.2 · 自动检测仪表板             | 2026-09-25 |
| **20**  | `research_ready/20_SOL_Perception_Bias.png`               | Results     | `sleep_visualization.R:2637`    | §6.2 · SOL 感知偏差               | 2026-09-25 |
| **20B** | `research_ready/20B_WASO_Perception_Bias.png`             | Results     | `sleep_visualization.R:2695`    | §6.2 · WASO 感知偏差              | 2026-09-25 |
| **21**  | `research_ready/21_Substance_Use_Availability.png`        | Supplement  | `sleep_visualization.R:2767`    | §6.2 · 物质使用数据可得性         | 2026-09-25 |
| **22**  | `research_ready/22_Substance_Use_Distribution.png`        | Supplement  | `sleep_visualization.R:2870`    | §6.2 · 物质使用数值分布           | 2026-09-25 |
| **23**  | `research_ready/23_Caffeine_Consumption.png`              | Supplement  | `sleep_visualization.R:2944`    | §6.2 · 咖啡因摄入                 | 2026-09-25 |
| **24**  | `research_ready/24_Alcohol_Consumption.png`               | Supplement  | `sleep_visualization.R:2979`    | §6.2 · 酒精摄入                   | 2026-09-25 |
| **A1**  | `pipeline_cleaning/A1_Step_Flag_Ledger.png`               | Supplement  | `figure12_step_flag_table.R:15` | §6.2 · 逐步标记账本               | 2026-09-25 |
| **P26** | `pipeline_cleaning/P26_PerParticipant_Flag_Rate.png`      | Supplement  | `sleep_visualization.R:2579`    | §6.2 · 值得二次检查的参与者       | 2026-09-25 |
| **R25** | `research_ready/R25_Sleep_Regularity_Weekday_Weekend.png` | Results     | `sleep_visualization.R:3043`    | §6.2 · 睡眠规律性——工作日 vs 周末 | 2026-09-25 |
| **R26** | `research_ready/R26_Sleep_Composition_TIB_Breakdown.png`  | Results     | `sleep_visualization.R:3096`    | §6.2 · 睡眠构成——TIB 拆分         | 2026-09-25 |
| **R27** | `research_ready/R27_Sleep_Metrics_Correlation_Matrix.png` | Results     | `sleep_visualization.R:3125`    | §6.2 · 睡眠指标相关矩阵           | 2026-09-25 |

已退役的图 `08_Sleep_Duration_by_Category` 和
`12_Pipeline_Correction_Progress` 不再产出（它们回答的问题已由图 07 和
A1
回答）。`11`（标记共现图）在完整数据的标记列少于两列时跳过，原因会写在
`figure_index.png` 顶部的红色区块里。`14`、`15`、`16`
在有东西可画时都会生成
（见下面的卡片）；某次运行确实没东西可展示时（例如待审队列已清空，因为
一切都已审查过），跳过原因会明确说明。

**为论文选图——一个建议。** 上面”论文用途”这一栏是默认建议，不是定论。
对于管线支持的 Methods/Results 结构，这样分效果不错：

- **Methods 正文（2 张图）。** 01（管线记录流）——展示管线*是什么*：
  各阶段、计数、最终分类构成。02（修正影响）——展示清洗*做了什么*：
  非破坏性，只改动了确认的输入错误。这两张图正好回答审稿人最先问的
  两个问题（“你做了什么？”和”改动有多大？“），不带多余信息。
- **Results 正文（挑 3–5 张）。** 03（TST 分布）作为数据质量的锚点；
  20/20B（感知偏差）如果自报值与计算值的一致性是故事的一部分；R25
  （工作日 vs 周末）或 R26（TIB 构成）如果时间规律性/构成很重要；R27
  （相关矩阵）如果你引用了指标之间的相互关系。正文里最好不要超过五张——
  其余的放进补充材料里读起来更舒服。
- **补充材料（其余全部）。** 所有 `pipeline_cleaning/` 图（13、13B、
  13C、13D、17、18、A1、P26、06、07、10）构成审计轨迹：把它们放进一个
  标题为”数据质量与清洗审计”的补充材料里，在 Methods 里用一句话统一
  引用（“完整审计轨迹见补充材料 S1”）。物质使用相关的图（21–24）
  跟着论文报告的物质使用分析走，没有的话也放补充材料。

如果篇幅紧张，最简版：**Methods 里放 01 + 02，Results 里放 03 + 20 +
R27，其余进补充材料的审计轨迹部分。** 每一张的图注都已经写好，在下面
§6.2 每张卡片的末尾。

### 6.2 图卡片

#### 01 · 管线记录流

**文件** `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` — 生成于
`sleep_visualization.R:862`

**论文用途** Methods 图1

**每部分是什么意思** 5 个阶段的垂直流程图，每个阶段现在都自解释： Raw
Load（全部日记条目）→ Parsed（有时间戳的条目）→ Auto-Corrected （AM/PM +
顺序修正）→ Manual-Corrected（人工审查修正）→ Final Valid
（可用于分析）。每个方框 = 记录数 + 占总数的百分比；两个修正阶段还
额外显示参与者人数。

右侧的注释把每条最终记录归入以下五类之一：

| 类别               | 含义                                                                                                                                          |
|--------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| Not Reported       | bed / sleep / awake / getup 任一时间缺失                                                                                                      |
| Error (Reviewed)   | 顺序被破坏（不满足 `bed ≤ sleep ≤ awake ≤ getup`）、`sleep = awake`、某段间隔 \> 7 小时，或睡眠跨度 \> 24 小时——审查后已修正                  |
| Equal Time         | `bed == sleep` 和/或 `awake == getup`（差值 \< 0.01 小时，约 36 秒）且顺序完整——一种良性的填表习惯。（`sleep == awake` 是 ERROR，不是这个。） |
| Unusual (Accepted) | 顺序完整但有一段间隔 \> 3 小时（bed→sleep 或 awake→getup）——奇怪但可能，审查后原样保留                                                        |
| Clean              | 顺序完整，没有超过 3 小时的间隔                                                                                                               |

图上每一类旁边都印着这些标准（按上面的顺序，第一个匹配的生效），不看本页也能读懂。

底部文字 = 进入分析的原始记录百分比。

**健康外观** 流程平缓收窄；Clean 在注释里占主导；Error + Unusual 很小
（\< 5%）；修正阶段计数小（只修了真正坏掉的记录）。

**异常 →** Error/Unusual 占比巨大 → 上游 AM/PM 混淆或解析出错；数据已知
含错误但修正计数接近零 → 检测漏掉了记录。

**精确规则**

- **数据来源。** 每条原始日记一行；五个阶段是 Raw Load → Parsed →
  Algorithmic Correction → Manual Correction → Final Valid。方框计数是
  绝对记录数加上 `n_total` 的百分比。
- **右侧注释是对最终输出做的一次 `data_category` 普查。** 每条记录
  按以下优先顺序恰好分入五类之一（第一个匹配的生效，
  `R/flag_standards.R:40-70`）：
  1.  `skipped_na` — bed/sleep/awake/getup 修正后时间中有任意一个缺失。
  2.  `error` — 时序被打破（`! (bed <= sleep <= awake <= getup)`），
      或零时长睡眠（`sleep == awake`），或相邻间隔 \> 7 小时，或计算出的
      睡眠跨度 \> 24 小时。**零时长睡眠（sleep == awake）永远是
      error**，绝不是 Equal Time——一晚零总睡眠是一条坏记录，不是良性
      模式。
  3.  `equal_time_ok` — 顺序完整 且（`abs(bed − sleep) < 0.01 h` 或
      `abs(awake − getup) < 0.01 h`）。0.01 小时（约 36 秒）的容差是为了
      吸收浮点数舍入误差。内部追踪三个子类型（`equal_time_type`）：
      `bed_sleep_equal`、`awake_getup_equal`、`both_equal`。这些记录
      直接算作有效——报告”上床”和”睡着”是同一个时刻，是一种合理的
      填表习惯，不是质量问题。
  4.  `unusual` — 顺序完整、不是 equal-time，但 bed→sleep 或 awake→getup
      之间有 \> 3 小时的间隔（可疑但合理；会被审查，通常 原样保留）。
  5.  `clean` — 其余情况（顺序完整，间隔正常）。
- **底部数字** = 携带已计算睡眠指标的原始记录百分比
  （`n_valid / n_total`），即所有没有因时间缺失而被丢弃的记录。

**常见问题** - *“为什么 Equal Time 不算错误？”*
因为零入睡潜伏期是一个合理的报告。 管线把 `error`
留给内部不可能的记录（顺序被打破、零时长睡眠）。 -
*“如果两对都相等（bed==sleep 且 awake==getup）呢？”* 仍然是
`equal_time_ok`，记作 `both_equal`。 - *“0.01 小时对审查者意味着什么？”*
两个相差不到约 36 秒的时间戳被
视为相同；这个容差的存在只是为了吸收浮点误差，不是为了掩盖真实差异。

**论文图注** \> **Figure 01.**
追踪所有原始日记条目经过五个管线阶段（原始载入、 \>
时间戳解析、算法修正、人工修正、最终有效输出）的流程图，每个阶段 \>
标注记录数和百分比。侧边注释报告最终记录分类（clean、unusual \>
accepted、error reviewed、equal-time benign、not-reported）以及 \>
至少接受过一次修正的参与者比例。TST = 总睡眠时间；SOL = 入睡潜伏期。

#### 02 · 修正影响

**文件** `research_ready/02_Correction_Impact.png` — 生成于
`sleep_visualization.R:1013`

**论文用途** Methods 图2

**用途**
审计修正对数据改了多少、往哪个方向改，回答”清洗有多侵入？“。图的副标题写明了用途，并解释了每个面板怎么读。

**每部分是什么意思** 4 个面板：(A) TST 变化量棒棒糖图——每个被修正的
记录一行，x = ΔTST（分钟）；(B) SOL 同样画法；(C) 一致性散点图， 修正前
TST vs 修正后 TST（全部记录）；(D) 修正前后 TST/SOL 均值 ± 标准差
的汇总表。图注写明了共修正了多少条、总共多少条记录中的多少条。

| 标记                          | 含义                                   |
|-------------------------------|----------------------------------------|
| 橙色                          | 算法修正                               |
| 蓝色                          | 人工修正                               |
| 灰色，3% 不透明度（仅面板 C） | 未改动的记录——作为修正点背后的浅色背景 |
| 虚线对角线（面板 C）          | 1:1”无变化”参考线                      |

**没有任何修正时**
如果没有记录被改动（数据本来干净，或人工修正文件没有应用），面板 A–C
都会是空的，所以图上只显示一句话——“No record was changed by a correction
in this
run（本次运行没有记录被修正；无需修正，或人工修正文件未应用）”——加上修正前后的汇总表（此时两行数字相同）。之前那两个空白面板里写的
“No records modified” 就是这个意思。

**健康外观** 只有一小部分点偏离对角线；变化量集中在 0 附近；修正前后
均值几乎相同（非破坏性清洗）。

**异常 →** 变化量很大或行数很多 → 修正正在改变真实数据，而不只是修
录入错误；均值发生明显偏移 → 需要调查为什么”修”了这么多。

**精确规则**

- **逐条记录的修正状态**（`pre_post$status`）：若 `manually_corrected`
  为 TRUE 则为 `manual`，否则若 `corrected` 为 TRUE 则为
  `algorithmic`，否则为 `none`。一条记录不可能同时是两者——人工优先。
- **变化量**只在被修改的记录上定义：
  `ΔTST = tst_after − tst_before`（分钟），其中 `tst_before` 由原始
  解析出的时间戳计算为 `(awake − sleep) − WASO`，`tst_after` 是管线
  最终的
  `self_diffcalc_totalsleeptime_minutes`。`ΔSOL = sol_after − sol_before`
  结构相同，`sol_before = sleep − bed`。Δ 为负表示修正 缩短了该指标。
- **面板 C 一致性散点图**对*所有*记录画出 `tst_before` 对
  `tst_after`；未改动的记录以 3% 不透明度（灰色）画出，让约 99% 未
  触碰的数据呈现为对角线上的一层浅色背景，衬托出少数彩色的修正点。 虚线
  1:1 线是”无变化”参考线。
- **颜色**：橙色 = 算法修正，蓝色 = 人工修正，灰色 = 未改动。

**常见问题** - *“为什么大部分数据都落在对角线上？”*
因为修正按设计是非破坏性的： 只修正确认的输入错误（真实运行中占 0.58%
的记录）。自报值与计算值 之间的分歧作为数据保留下来，不会被抹平。 -
*“一个远离对角线、3% 不透明度的点——是 bug 吗？”* 不是——浅灰色里
也包含少数真正被修改过的记录；不透明度只是在视觉上把”未改动的大
多数”和它们分开。

**论文图注** \> **Figure 02.** (A)
每条被修正记录的总睡眠时间变化量（ΔTST，分钟） \>
棒棒糖图，按修正类型着色（橙色 = 算法，蓝色 = 人工）。(B) 入睡潜伏期 \>
同样画法（ΔSOL）。(C) 修正前后 TST 的一致性散点图；未改动记录以 3% \>
不透明度画作灰色背景。(D) 修正前后 TST 和 SOL 均值（± 标准差）汇总表。
\> 修正是非破坏性的：只改动了确认的输入错误。

#### 02B · 睡眠变量分布

**文件** `research_ready/02B_Distribution_Sleep_Variables.png` — 生成于
`sleep_visualization.R:1057`

**论文用途** Results

**每部分是什么意思** 对关键睡眠指标（TST、SOL、WASO、SE）在**最终
修正后**数据上画出的直方图 + 密度曲线。

**健康外观** TST 峰值在 6–8 h；SOL 右偏，10–45；WASO \< 60；SE \> 85%。

**异常 →** SOL 平坦/双峰 → AM/PM 混淆未被修正；SE 在 100% 处出现尖峰 →
大量”整夜都睡着”的记录。

**精确规则**

- **03（TST 分布）**用的是 `sleep_duration_h`，定义为增强版 TST：
  睡眠时段（awake − sleep）减去 WASO，即
  `TST = TIB − SOL − WASO`。它*不是*两个时钟时间的原始差值。均值画作
  蓝色实线，中位数画作橙色虚线；对于右偏的睡眠数据，均值 \> 中位数是
  预期的（长睡眠者拖出的尾巴）。
- **02B** 把 QC 检查用到的同样四个指标——TST、SOL、WASO、SE——在最终
  修正后数据上画成带密度曲线的直方图。

**常见问题** - *“为什么有两张分布图（02B 和 03）？”* 02B
是四指标质量仪表板；03 单独把 TST 拎出来，加上均值/中位数参考线，专门给
Methods 部分用。

**论文图注** \> **Figure 02B.**
最终修正后数据上，总睡眠时间（TST）、入睡潜伏期 \>
（SOL）、睡后觉醒（WASO）和睡眠效率（SE）的直方图与密度曲线。

#### 03 · TST 分布

**文件** `research_ready/03_Sleep_Duration_Distribution.png` — 生成于
`sleep_visualization.R:1108`

**论文用途** Results

**每部分是什么意思** 总睡眠时间（TST——见前文”术语”）的直方图 + 密度图。

| 标记         | 含义                   |
|--------------|------------------------|
| 红色平滑曲线 | 密度估计               |
| 蓝色实线     | 均值（标注小时数值）   |
| 橙色虚线     | 中位数（标注小时数值） |

图下方标题为 “Line shown” 的图例说明了每条线。

这里的 TST 是*增强版*定义：`TST = TIB − SOL − WASO`——不是两个时间戳
的原始时钟差值。

**健康外观** 单峰，中心在 6–8 h，均值 ≈ 中位数。

**异常 →** 均值远大于中位数 → 长睡眠者的右尾；0 处有尖峰 → 零时长记录。

**精确规则**

- **03（TST 分布）**用的是 `sleep_duration_h`，定义为增强版 TST：
  睡眠时段（awake − sleep）减去 WASO，即
  `TST = TIB − SOL − WASO`。它*不是*两个时钟时间的原始差值。均值画作
  蓝色实线，中位数画作橙色虚线；对于右偏的睡眠数据，均值 \> 中位数是
  预期的（长睡眠者拖出的尾巴）。
- **02B** 把 QC 检查用到的同样四个指标——TST、SOL、WASO、SE——在最终
  修正后数据上画成带密度曲线的直方图。

**常见问题** - *“为什么有两张分布图（02B 和 03）？”* 02B
是四指标质量仪表板；03 单独把 TST 拎出来，加上均值/中位数参考线，专门给
Methods 部分用。

**论文图注** \> **Figure 03.**
TST（小时）的直方图与密度图，标出均值（蓝）与中位数 \> （橙）。TST
计算为睡眠时段减去 WASO（TST = TIB − SOL − WASO）。

#### 04 · 睡眠时长 vs 卧床时间

**文件** `research_ready/04_Sleep_Duration_vs_Time_in_Bed.png` — 生成于
`sleep_visualization.R:1163`

**论文用途** Results

**每部分是什么意思** 卧床时间（从躺下到起床）对睡眠时长（实际睡着的 时间
= TIB − SOL − WASO）的散点图。黑线 = 线性趋势；周围的灰带 = 该
趋势的不确定范围。虚线对角线 = 不可能出现的 TST == TIB 线。

**健康外观** 点紧贴恒等线；TIB 越长散布越大（人会赖床）；没有点落在 TST
\> TIB 的区域。

**异常 →** TST \> TIB 的区域有点 → 时长算术出错（漏减了 WASO）；点云
扁平 → TIB 和 TST 脱钩（解析问题）。

**精确规则**

- **04** 画的是 TST（h）对卧床时间（h）。因为 TST = TIB − SOL −
  WASO，每个有效点都必须满足 TST ≤ TIB：落在恒等线上方的点在物理上
  不可能，说明指标算术有问题。
- **04B** 画的是 SOL（h）对 TST（h），`sol_h` 限制在 `[0, 3]` 小时—— SOL
  \> 3 小时纯粹为了画面清晰而被过滤掉（这些点已经被
  `max_sol_minutes = 180` 标记为 unusual）。颜色 = `flag_severity`。

**常见问题** - *“为什么这里 SOL 上限是 3 小时，但图 13 在 120
分钟就标记了？”* 同一个阈值，单位不同：3 小时 = 180 分钟 =
`max_sol_minutes` 分类 上限。这张图的过滤只是为了让画面可读。

**论文图注** \> **Figure 04.**
TST（小时）对卧床时间（TIB，小时）的散点图，带平滑 \>
趋势线和恒等参考线。由于构造上 TST ≤ TIB，落在恒等线上方的点在 \>
物理上不可能。

#### 04B · SOL vs 睡眠时长

**文件** `research_ready/04B_SOL_vs_Sleep_Duration.png` — 生成于
`sleep_visualization.R:1215`

**论文用途** Results

**每部分是什么意思** SOL（躺下后花多久睡着）对 TST 的散点图。每个点 =
一个日记之夜。黑线 = 线性趋势；灰带 = 趋势的不确定范围。红色虚线竖线 在
SOL = 1 小时处（标注参考值）。SOL \> 3 小时为了清晰被过滤掉。

**健康外观** 负相关（SOL 越长 TST 越短）；多数点 SOL \< 1 小时；质量
颜色均匀混杂。

**异常 →** 高 SOL 处聚集了 error/unusual 颜色的点 → 入睡时间误填模式；
SOL = 0 处出现竖条 → 零潜伏期报告（equal-time）。

**精确规则**

- **04** 画的是 TST（h）对卧床时间（h）。因为 TST = TIB − SOL −
  WASO，每个有效点都必须满足 TST ≤ TIB：落在恒等线上方的点在物理上
  不可能，说明指标算术有问题。
- **04B** 画的是 SOL（h）对 TST（h），`sol_h` 限制在 `[0, 3]` 小时—— SOL
  \> 3 小时纯粹为了画面清晰而被过滤掉（这些点已经被
  `max_sol_minutes = 180` 标记为 unusual）。颜色 = `flag_severity`。

**常见问题** - *“为什么这里 SOL 上限是 3 小时，但图 13 在 120
分钟就标记了？”* 同一个阈值，单位不同：3 小时 = 180 分钟 =
`max_sol_minutes` 分类 上限。这张图的过滤只是为了让画面可读。

**论文图注** \> **Figure 04B.** SOL（小时，为了可读性限制在 ≤ 3 小时）对
TST（小时） \> 的散点图，按 flag severity
着色。负相关（入睡潜伏期越长，睡眠越短） \> 是预期的临床模式。

#### 05 · 睡眠变量的变异性

**文件** `research_ready/05_Variability_Sleep_Variables.png` — 生成于
`sleep_visualization.R:1265`

**论文用途** Results

**每部分是什么意思** 每个睡眠变量一个小提琴图 + 内嵌箱线图，**每个
面板独立 Y 轴**。展示分布形状与离散程度。

**健康外观** TST 的小提琴大致对称；SOL/WASO 右偏；没有面板被尖峰主导。

**异常 →** 小提琴分裂成两瓣 → 双峰行为（工作日/周末，或 12 小时表盘
习惯）；宽而扁的小提琴 → 测量噪声大。

**精确规则**

- 每个睡眠变量一个小提琴图（带内嵌箱线图）；每个面板都是**独立 Y
  轴**，因为各变量量纲不同（小时 vs 百分比）。跨面板比较看的是*形状*
  （对称性、离散程度、双峰性），不是绝对数值。

**论文图注** \> **Figure 05.**
每个睡眠变量的小提琴图叠加箱线图；每个面板使用自己 \> 的 y
轴刻度，因此面板之间比较的是分布形状，而非绝对数值。

#### 06 · 修正后睡眠时长

**文件** `pipeline_cleaning/06_Sleep_Duration_Post_Correction.png` —
生成于 `sleep_visualization.R:1339`

**论文用途** Supplement

**每部分是什么意思** 按记录类别（Clean / Unusual / Manually Corrected /
Error）画出的最终睡眠时长密度曲线，取自 Step 5–6.5 之后。这回答的
问题是：人工修正有没有扭曲整体睡眠时长的分布？（被修正类别的曲线 应该和
clean 曲线重叠。）

**健康外观** 单峰，峰值在 6–8 h，0 处或 \> 12 处没有尖峰。

**异常 →** 平坦/双峰 → 12 小时/24 小时格式混杂并通过了解析；0 处有 尖峰
→ 缺失/零时长记录。

**精确规则**

- 应用人工修正后最终 `sleep_duration_h` 的密度图。和旧版图 14（仅
  自动检测）的视角对比，可以看出人工审查改变了什么。健康数据：单峰，
  众数在 6–8 h，0 处无尖峰。

**论文图注** \> **Figure 06.**
应用全部人工修正之后，最终总睡眠时间（TST，小时） \> 的密度图。以 6–8 h
为中心的单峰分布表示健康的睡眠时长；0 或 \> 12 h \>
处的尖峰表示残留的解析artifact。

#### 07 · 标记构成堆叠图

**文件** `pipeline_cleaning/07_Flag_Composition_Stacked.png` — 生成于
`sleep_visualization.R:1404`

**论文用途** Supplement

**每部分是什么意思** 堆叠直方图：x = 睡眠时长（h），y = 该区间的
记录数，填色 = `flag_severity`（见前文”术语”），图例标题为”Data
Quality”。展示质量问题是否集中在极端时长处。

| 填色  | 含义               |
|-------|--------------------|
| Clean | 0 个指标标记       |
| Minor | 1 个指标标记       |
| Major | 2 个及以上指标标记 |

不要和 `data_category` 混淆——那是另一个不同的分类系统（见 §6.3
关键定义）。

**健康外观** Clean 在每个时长区间都占主导；彩色薄片只出现在极端处 （\< 3
h、\> 12 h）和 0 处。

**异常 →** 中间时长区间出现宽的 error 带 → 系统性解析问题，而非 极端值
artifact。

**精确规则**

- **填色 = `flag_severity`**，不是 `data_category`：`Clean`（0 个指标
  标记）、`Minor`（1 个）、`Major`（2 个及以上）。一个”标记”是 {SE \<
  70%, SOL \> 1 h, WASO \> 1.5 h} 之一
  （`classification.flag_severity.*`）。x 轴为了可读性限制在 \[0, 16\]
  小时；极端时长区间落在边缘，是 Major 标记的自然聚集地。

**常见问题** - *“所以这是关于计算指标的标记，不是时间戳错误？”* 对——图
13 展示 的是时间戳/错误类别；图 07
展示的是每个睡眠时长上有多少个指标标记
同时出现。两者是不同的分类系统（`flag_severity` vs `data_category`）。

**论文图注** \> **Figure 07.** 最终睡眠时长（小时）的堆叠直方图，柱子按
flag \> severity 着色：Clean（无指标标记）、Minor（一个标记）、Major \>
（两个或更多，来自 {SE \< 70%, SOL \> 1 h, WASO \> 1.5 h}）。展示质量 \>
问题是否集中在极端时长处。

#### 09 · 就寝 vs 起床时间分布

**文件** `research_ready/09_Bedtime_vs_Getup_Distribution.png` — 生成于
`sleep_visualization.R:1458`

**论文用途** Results

**每部分是什么意思** 按一天中的小时（0–24）画出的两条密度曲线：就寝
时间分布 vs 起床时间分布（最终修正后的时间）。

**健康外观** 就寝峰值在 22:00–00:00；起床峰值在 06:00–08:00；两条
曲线重叠不多。

**异常 →** 就寝峰值在 02:00 之后 → 延迟睡眠人群或 PM/AM 解码错误；
起床峰值在 04:00 之前 → 傍晚时间被误解析。

**精确规则**

- 两条按一天中小时 \[0, 24) 画出的密度：就寝
  （`time_bed_corrected`）和起床（`time_getup_corrected`）。使用修正
  后的时间，所以跨午夜翻转过的条目会出现在它们真实的傍晚/早晨时刻。
  峰值分离（就寝约 23:00，起床约 07:00）是健康的昼夜节律信号。

**论文图注** \> **Figure 09.**
就寝和起床时钟小时（修正后时间）在一天中的密度分布。 \>
峰值分离（傍晚就寝、清晨起床）是健康的昼夜节律信号。

#### 10 · 极端睡眠时长

**文件** `pipeline_cleaning/10_Extreme_Sleep_Duration.png` — 生成于
`sleep_visualization.R:1514`

**论文用途** Supplement

**每部分是什么意思** 散点图：x = TST（h），y = 睡眠效率（%），限制在
极端时长（\< 4 h 或 \> 10 h）。

| 编码   | 含义                   |
|--------|------------------------|
| 颜色   | 数据质量               |
| 形状   | 短睡眠者 vs 长睡眠者   |
| 水平线 | SE = 85%（低效率阈值） |

**健康外观** 极端值只是少量散点；短睡眠的点多数落在合理的 SE
（60–95%）；长睡眠的点 SE 高。

**异常 →** 短睡眠点聚集在 SE 85% 以下 → 真实失眠还是测量问题；很多点
恰好在 TST = 0 或 24 → 解析失败。

**精确规则**

- **极端** = TST \< 4 h（“短”）或 TST \> 10 h（“长”）；其余为”正常
  范围”并被排除。点的形状编码短/长；颜色编码数据质量。
- SE = 85% 处的水平线是 `poor_efficiency_threshold_pct` 分类边界
  （低于它的记录会累积一个低 SE 标记）。

**常见问题** - *“4 小时和 10 小时是哪来的？”*
它们是这张图自己选的显示截断值，为了
展示尾部；比管线的生理学上限（`duration_extreme`：\< 3 h / \> 12 h）
更宽松。不要把这两套阈值弄混。

**论文图注** \> **Figure 10.**
总睡眠时间（TST，小时）对睡眠效率（SE，%）的散点图， \>
限制在极端时长（\< 4 h 短，\> 10 h 长）。点的形状编码短/长睡眠；点的 \>
颜色编码记录质量。水平线标出 SE = 85% 的低效率阈值。

#### 13 · 错误类别分布

**文件** `pipeline_cleaning/13_Error_Category_Distribution.png` — 生成于
`sleep_visualization.R:1794`

**论文用途** Supplement

**每部分是什么意思** 自动检测的错误/审查类别柱状图，带计数和百分比
标签。类别对应 `auto_error_desc` 前缀（Temporal / Metrics / Amount /
Interval / Timestamp）。

**健康外观** 一到两个类别占主导（通常是 Temporal）；所有类别绝对数量
都不大。

**异常 →** Timestamp 或 Interval 格式错误很大 → 参与者大规模使用了
非标准格式；需要检查解析规则。

**精确规则**

- **修正前的自动检测普查**：柱子是被 Step 8 检查
  （`checkforerrors_processed`）标记的记录数，按 `review_source`
  分组，它源自 `auto_error_desc` 的前缀：`[Temporal]` → Temporal
  Issues，`[Metrics]` → Metrics Issues，`[Amount]` → Amount/Input
  Flags，`[Interval]` → Interval Format Errors，`[Timestamp]` →
  Timestamp Format Errors，其余 → Other Issues。
- 副标题记录了驱动这些标记的指标验证规则：SOL \> 120 min，SE \< 0 或 \>
  100%，TST/TIB 比值 \< 0.5。

**常见问题** - *“为什么是’修正前’？”*
这张图回答的是”原始数据里有多少需要修的
东西？“——也就是管线要承担的负担。图 18 展示的是修正后的残留量。

**论文图注** \> **Figure 13.**
修正后自动检测流程标记的记录柱状图，按标记描述派生 \>
的六个审查类别分组：时序问题、指标问题、数量/录入标记、区间格式 \>
错误、时间戳格式错误、其他。计数是修正前的——展示的是管线要承担的 \>
负担。

#### 13B · 相邻时间戳间隔

**文件** `pipeline_cleaning/13B_Adjacent_Timestamp_Gaps.png` — 生成于
`sleep_visualization.R:1877`

**论文用途** Supplement

**每部分是什么意思** 相邻日记事件（bed→sleep、sleep→awake、
awake→getup）之间的间隔小时数直方图，用的是**修正前的原始时间**。 负间隔
= 后一个事件的时钟时间早于前一个。0 处有竖直参考线。

**健康外观** 间隔的质量集中在 +0.5 到 +2 小时（正值，顺序合理）；
有一个小的负值尾巴。

**异常 →** 大量负值 → 大范围顺序错误，会被规范化步骤翻转；围绕 ±12
小时的双峰 → 12 小时表盘的 AM/PM 习惯。

**精确规则**

- **间隔**是三对相邻事件（bed→sleep、sleep→awake、awake→getup）
  在修正之前、基于原始（已解码）时间戳算出的
  `later_event − earlier_event`（小时）。**负间隔** = 后一个事件的
  时钟时间早于前一个（比如同一行里 awake 01:00 却在 sleep 23:00 之
  后）——这是顺序错误或 12 小时表盘习惯的原始信号。
- 分布形态能看出哪种失败模式占主导：−1 到 −3 小时附近的负值质量 =
  顺序颠倒（会被交换步骤修正）；围绕 ±12 小时的双峰模式 = 参与者把 PM
  时间填成了 AM（会被 12 小时翻转修正， `flip_gap_hours = 12`）。

**论文图注** \> **Figure 13B.** 相邻日记事件（bed→sleep、sleep→awake、
\> awake→getup）之间时间间隔（小时）的直方图，基于修正前的原始时间戳 \>
计算。负间隔表示后一个事件的时钟时间早于前一个，是顺序错误和 12 \> 小时
AM/PM 表盘习惯的信号。

#### 13C · 检测结果热力图

**文件** `pipeline_cleaning/13C_Detection_Outcomes_Heatmap.png` — 生成于
`sleep_visualization.R:1936`

**论文用途** Supplement

**每部分是什么意思** 来自合成错误注入验证的方格热力图：行/列 = 注入的
错误类型，格子 = 检测结果计数相对众数结果。验证检测器是否在该检测的
错误上真的会触发。

**健康外观** 强对角线（注入哪里就检测到哪里）；对角线之外接近零。

**异常 →** 对角线之外有质量 → 检测器漏掉了某一类，或在干净的对照
上误报。

**精确规则**

- 数据来源：合成错误注入基准
  （`validation/synthetic/results/detection_outcomes_v4_current.csv`）。
  已知错误被注入干净数据，每个格子展示该注入类别的众数检测结果
  （`CORRECT` / `FLAGGED_UNRESOLVED` / `MISREPAIRED` ……）。`modal_n`
  参考值是最常见结果的计数；计数偏离（`n != modal_n`）的行是值得
  关注的。

**常见问题** - *“为什么要把阈值和噪声做比较？”*
小于测量噪声的阈值检测不到任何
真实信号——它会把纯噪声也标记出来。这张图展示我们的操作点安全地
高于噪声带。

**论文图注** \> **Figure 13C.**
来自合成基准的热力图，其中已知错误被注入干净记录； \>
每个格子报告一个注入错误类别的众数检测结果（正确自动修正、标记 \>
审查、或误修正）。强对角线表示检测器在被注入的错误上确实触发。

#### 13D · 阈值 vs 测量噪声

**文件** `pipeline_cleaning/13D_Threshold_vs_Noise_Ratio.png` — 生成于
`sleep_visualization.R:1980`

**论文用途** Supplement

**每部分是什么意思** 展示检测率相对**阈值/Bland-Altman 噪声比**的
柱状图；竖线 = 选定的操作点。把清洗阈值和测量噪声挂钩，而不是拍脑袋
定一个数。

**健康外观** 竖线右侧检测率高且平；选定点处没有断崖。

**异常 →** 检测率在竖线之前就下降 → 阈值落在噪声带内；应提高阈值。

**精确规则**

- 数据来源：同一份合成基准。x 轴是`阈值 / Bland-Altman 测量噪声`；
  竖线标出配置的操作点（间隔 3 小时 / 翻转 12 小时）。线右侧的点是
  安全高于噪声的阈值；线之前出现检测断崖意味着阈值落在噪声带内。

**常见问题** - *“为什么合成注入类的图要放进 QC 文件夹？”*
它们是检测数字有意义
的证据——在已知真值上验证检测器，而不是在”正确答案”本身未知的
真实数据上验证。

**论文图注** \> **Figure 13D.**
检测率随阈值/测量噪声比变化的函数图，噪声由 \> Bland-Altman
分析量化。竖线标出配置的操作点（3 小时间隔阈值、12 \>
小时翻转阈值）；线左侧的阈值落在测量噪声范围内。

#### 14 · 修正前睡眠时长

**文件** `pipeline_cleaning/14_Sleep_Duration_Pre_Correction.png` —
生成于 `sleep_visualization.R:2051`

**论文用途** Supplement

**每部分是什么意思** 两条叠加的睡眠时长密度曲线：绿色 =
没有任何自动检测标记的记录（最多抽样 5,000 条）；红色 =
被算法标记待审的记录。这是修正前的视图：只有算法，没有人工修正。副标题给出了两组的样本量。

**健康外观**
被标记的曲线更宽或发生偏移（这正是它被标记的原因），而且记录数比干净曲线少得多。

**异常 →** 被标记和干净两条曲线几乎一样 →
这些标记和时长无关（它们来自时间戳或格式规则）。

**不生成的情况** 被标记的记录里没有可用的 `sleep_duration_h`——此时
`figure_index.png` 顶部的红色区块会写 “No usable sleep_duration_h values
in the pre-correction review queue”。

**论文图注** \> **Figure 14.**
没有自动检测标记的记录（绿色，最多随机抽样 5,000
条）与被标记待审的记录（红色）在任何人工修正之前的睡眠时长（小时）密度。

#### 15 · 错误时间线

**文件** `pipeline_cleaning/15_Error_Timeline.png` — 生成于
`sleep_visualization.R:2137`

**论文用途** Supplement

**每部分是什么意思** 按月份的堆叠柱状图，统计在 Step 5/6
得到时间分类的记录：`order_error`（错误）和三种”可疑间隔”类型（`bed_sleep_suspicious`、`sleep_awake_suspicious`、`awake_getup_suspicious`）。之所以按月统计，是因为这类记录总共只有几十条；逐日的面积图会在孤立的日期之间画出倾斜的色块，容易误导。

**健康外观** 计数很小、分散在整个研究期；没有哪个月一家独大。

**异常 →** 某个月突然尖峰 → 方案变更或数据采集中断；集中在研究开始阶段 →
学习曲线或说明不清。

**精确规则**

- 数据源是 `corrected_ema_data`（`error_type` / `unusual_type` 在 Step
  5–6 才附上），**不是** `clean_df`——`clean_df` 是 Step 4
  之后、分类之前的数据框。
- 这里有标记不代表这条记录错了：大多数都审查过并原样保留（见图 02）。

**论文图注** \> **Figure 15.** 每月带有时间顺序错误或可疑间隔模式（Step
6 分类）的记录数，按模式类型区分。

#### 16 · 常见错误模式

**文件** `pipeline_cleaning/16_Common_Error_Patterns.png` — 生成于
`sleep_visualization.R:2228`

**论文用途** Supplement

**每部分是什么意思**
横向柱状图，给自动检测待审队列里出现的具体模式排名：时间顺序错误、异常睡眠模式、SOL
/ 睡眠效率 / TST-TIB 指标异常、**SOL 超过床到入睡窗口**、WASO
估计不一致、时长格式和时间戳解析问题。最后一根柱 **“Other /
unclassified”**
统计不匹配任何已命名模式的待审记录，让读者看到已命名的模式没能解释的比例。

**健康外观** 少数几个已命名模式覆盖队列的大部分；“Other / unclassified”
很小。

**异常 →** “Other / unclassified” 很大 →
新增了检测规则，却没在这里加对应标签（SOL 窗口规则就曾这样漏掉过一次）。

**不生成的情况** 所有待审记录都是 “Other /
unclassified”，或者队列已清空（因为一切都已审查过）；此时跳过原因会说明是哪一种。

**论文图注** \> **Figure 16.**
待审队列中自动检测到的最常见模式；最后一根柱汇总了不匹配任何已命名模式的记录。

#### 17 · 标记率最高的参与者

**文件** `pipeline_cleaning/17_Top_Participants_Flags.png` — 生成于
`sleep_visualization.R:2307`

**论文用途** Supplement

**每部分是什么意思** 柱状图：按算法标记记录*比率*（标记数 ÷ 天数）
排名前 15 的参与者，标注 PID。

**健康外观** 比率适中（\< 30%）；没有单个参与者一枝独秀。

**异常 →** 某个参与者比率 \> 60% → 习惯性 12 小时表盘或反复出现的
格式问题；需检查其原始填写模式。

**精确规则**

- 是*比率*，不是计数：该参与者的 `flags / days observed`。计数会
  偏向日记天数多的参与者；比率能识别出记录被不成比例标记的参与者。

**常见问题** - *“标记率高——是数据错误吗？”*
不一定。它只是标记出值得人工核查的
记录；结论来自审查，不是来自这张图本身。

**论文图注** \> **Figure 17.**
按自动检测标记率（每个观测日记天的标记数，而非原始 \> 标记计数）排名前
15 的参与者，因此日记天数少的参与者不会被过度 \> 呈现。

#### 18 · 自动检测仪表板

**文件** `pipeline_cleaning/18_Auto_Detected_Dashboard.png` — 生成于
`sleep_visualization.R:2409`

**论文用途** Supplement

**每部分是什么意思** 左侧文字面板”Key Metrics”：三个数字，每个数字下面
都有它的名称——自动检测（需要人工审查）、人工修正（已审查并修正）、总记录数。
右侧：`review_source` 各类别（Temporal Issues / Metrics Issues /
Amount/Input Flags / Interval Format Errors / Timestamp Format Errors /
Other）的饼图。

**健康外观** 被标记数远小于总数；Temporal 是最大类别；计数与
`correction_status_final.csv` 一致。

**异常 →** 计数与 CSV 不一致 → ledger/图表管线不同步；Amount 标记 偏高 →
物质使用编码问题。

**精确规则**

- **Key Metrics 面板**：`total records`、`flagged records`、
  `manually corrected count`——这三个数字必须和
  `output/correction_status_final.csv` 一致（`n_total`、 checkforerrors
  各行之和、`n_corrected`）；不一致意味着 ledger 和 图表管线不同步。
- **Review-source 柱状图**：和图 13 相同的 6 个 `review_source`
  类别，但用的是修正后的标记集合。

**论文图注** \> **Figure 18.** Key metrics
面板（总记录数、被标记记录数、人工修正 \> 记录数）搭配六个 review-source
类别的堆叠柱状图。计数必须与 \> `correction_status_final.csv` 一致。

#### 20 · SOL 感知偏差

**文件** `research_ready/20_SOL_Perception_Bias.png` — 生成于
`sleep_visualization.R:2637`

**论文用途** Results

**注意：** 这里衡量的是一个和 SOL 本身时长*不同*的量（快速检查卡里 那个
10–45 分钟的范围）——这张图衡量的是两个独立 SOL 估计值之间的
*差距*，而不是 SOL 的时长本身。

**每部分是什么意思** 绝对偏差的直方图，图上标注为
`bias = |计算得到的 SOL − 自报 SOL|`（分钟）。两条参考线，各自标注了
依据：**橙色虚线在 15 分钟**处 = 小的不一致（接近管线的 15 分钟窗口
容差，`classification.metric_validation.sol.window_tolerance_minutes`）；
**红色虚线在 60 分钟**处 = 大的不一致——这是一条纯展示用的参考线，
不是管线规则；超过它的情况值得人工看一眼。

**健康外观** 质量集中在 0 附近；尾巴小；平均偏差 \< 30 分钟。

**异常 →** 大的系统性偏移（均值远大于 0）→ 参与者误判入睡潜伏期； 双峰 →
一部分人误用了这个字段。

**精确规则**

- 客观 SOL = `time_sleep_corrected − time_bed_corrected`（分钟）； 主观
  SOL = 参与者自报的
  `duration_totalmin_sol_estimate_am`。`bias = |客观 − 主观|`。系统性
  正向偏移 = 参与者低估了自己花多久才睡着。

**论文图注** \> **Figure 20.** 客观
SOL（由修正后的就寝与入睡时间戳推导）与主观 \>
SOL（参与者自报的入睡潜伏期）之间绝对差值（分钟）的直方图。

#### 20B · WASO 感知偏差

**文件** `research_ready/20B_WASO_Perception_Bias.png` — 生成于
`sleep_visualization.R:2695`

**论文用途** Results

**每部分是什么意思**
绝对偏差直方图，`bias = |计算得到的 WASO − 自报的觉醒|`（分钟），图上标注，参考线和图
20 相同（15 分钟 / 60 分钟）。

**健康外观** 质量集中在 0 附近，尾巴小。

**异常 →** 尾巴大 → 参与者低估/高估了觉醒时段；需检查 WASO 时长
相关的修正。

**精确规则**

- 客观 WASO = 根据修正后的时间线计算得出（睡眠时段内的醒来次数）； 主观
  WASO = 参与者自报的夜间觉醒
  （`duration_totalmin_waso_estimate_am`）。和图 20 相同的
  `bias = |客观 − 主观|` 构造，只是对象换成了觉醒时间而不是入睡 潜伏期。

**论文图注** \> **Figure 20B.**
计算得到的睡后觉醒与参与者自报的夜间觉醒之间绝对 \>
差值（分钟）的直方图。

#### 21 · 物质使用数据可得性

**文件** `research_ready/21_Substance_Use_Availability.png` — 生成于
`sleep_visualization.R:2767`

**论文用途** Supplement

**每部分是什么意思** 柱状图：每种物质（咖啡因、酒精、尼古丁、大麻）
有数据的记录百分比。

**健康外观** 你的研究询问的物质有较高可得性（\> 80%）；低可得性属于
预期中的跳答模式。

**异常 →** 你测量的某种物质可得性接近零 → 列映射或采集失败。

**精确规则**

- **单位**（来自绘图配置）：咖啡因 = **杯**，酒精 = **标准杯**， 尼古丁
  = **剂**，大麻 = **剂**。
- 每根柱子 = 该物质有非 NA 报告的记录百分比。
- 你的研究测量的某种物质可得性接近零，通常意味着列映射或采集失败，
  而不是被跳过的回答。

**论文图注** \> **Figure 21.**
每种物质（咖啡因、酒精、尼古丁、大麻）含有数据的 \>
记录百分比，展示每个物质域被报告的完整程度。

#### 22 · 物质使用数值分布

**文件** `research_ready/22_Substance_Use_Distribution.png` — 生成于
`sleep_visualization.R:2870`

**论文用途** Supplement

**每部分是什么意思** 箱线图（箱体 = 中间 50% 的报告；箱内线 = 中位
数）叠加**灰色点**——每个点 = 一位参与者的一次报告，横向抖动，避免
相同数值堆成一个点。

**健康外观** 箱体紧凑，落在合理剂量上（咖啡因 0–4 杯；酒精 0–3
标准杯）；离群点少。

**异常 →** 极端离群点 → 数量标记（编码单位搞错了，比如杯 vs 罐）；
箱体很宽 → 非标准的剂量填写方式。

**精确规则**

- **单位**（来自绘图配置）：咖啡因 = **杯**，酒精 = **标准杯**， 尼古丁
  = **剂**，大麻 = **剂**。
- 箱体 = 中间 50% 的报告；箱内线 = 中位数；灰色点 = 单条报告（已抖
  动）。
- 极端值会计入 Step 8 的 `AMOUNT_FLAG`。

**论文图注** \> **Figure 22.**
每种物质报告值的箱线图叠加抖动点。单位：咖啡因 = \> 杯，酒精 =
标准杯，尼古丁和大麻 = 剂。

#### 23 · 咖啡因摄入

**文件** `research_ready/23_Caffeine_Consumption.png` — 生成于
`sleep_visualization.R:2944`

**论文用途** Supplement

**每部分是什么意思** 柱状图，**每个不同的报告值一根柱子**（0、1/3、1/2、
1、1 1/2……杯/天——离散 x 轴，柱子从不重叠），柱顶标注计数 + 百分比。
小数回答（半杯等）原样保留，并标成分数；副标题里也写明了这一点。只有一条
记录的小数值（比如 0.3）柱子很矮，但它的计数标签照样会印出来。

**健康外观** 右偏，众数在 0–1 杯。

**异常 →** 在不合理的值（≥ 10）处出现尖峰 → 单位混淆（罐 vs 杯），会计入
`AMOUNT_FLAG`。

**精确规则**

- 单位：每天**杯**数（自报列
  `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1`）。
- 每个不同值一根柱子；不做分箱，所以半杯（1.5）的报告会有自己的柱子。
- 极端值（比如 ≥ 10”杯”）会计入 Step 8 的 `AMOUNT_FLAG`，通常意味着
  源数据导出时的单位搞混了（杯 vs 罐 vs 份）。

**论文图注** \> **Figure 23.**
按自报咖啡因摄入量（杯/天）分组的记录计数。右偏、 \> 众数在 0–1
杯是预期的；在不合理值处出现尖峰表示单位混淆。

#### 24 · 酒精摄入

**文件** `research_ready/24_Alcohol_Consumption.png` — 生成于
`sleep_visualization.R:2979`

**论文用途** Supplement

**每部分是什么意思** 柱状图，每个不同的报告值（杯/天）一根柱子，和 图 23
相同的离散画法；小数回答（例如 1 1/4 杯）原样保留并标成分数。

**健康外观** 右偏，众数在 0。

**异常 →** 高值处出现尖峰 → 和咖啡因一样的单位问题；需核实
`alcoholtoday_PM` 的编码。

**精确规则**

- 单位：每天**标准杯**数（自报列
  `alcoholtoday_PM_NumAlcoholicDrinks_1`）。
- 每个不同值一根柱子，画法同图 23。
- 高值尖峰会计入 Step 8 的 `AMOUNT_FLAG`；在当作真实消费量之前先 核实
  `alcoholtoday_PM` 的编码。

**论文图注** \> **Figure 24.**
按自报酒精摄入量（标准杯/天）分组的记录计数。

#### A1 · 逐步标记账本

**文件** `pipeline_cleaning/A1_Step_Flag_Ledger.png` — 生成于
`figure12_step_flag_table.R:15`

**论文用途** Supplement

**每部分是什么意思** 网格表：每个管线步骤一行；列为
N（本次运行的记录数）、 DC:error / DC:unusual（`data_category`，Step
5）、SEV:Minor / SEV:Major （`flag_severity`，Step
7）、CFE:flag（`checkforerrors`，Step 8）、
MISentry（`field_misentry`，Step 1.5）、Corrected 和 Suppressed。灰色的
“—”
表示”这一步还算不出来”；某列第一个出现的数字就是它的生成点。表格下方的
说明把每个缩写都写全了，数字居中对齐在表头下面。读法和 §2 的 CSV ledger
一样，只是画成了图。

**健康外观** 每个标准的计数只在它对应的步骤首次出现，之后保持不变； Step
6 起 `equal_time_ok + skipped_na = n_total`。

**异常 →** 计数在首次计算步骤之后发生变化 → 管线不稳定（见 §2 的
验证规则）。

**精确规则**

- 每行 = 步骤 × 标准 × 类别。五个标准各自在固定的一步只计算一次，
  之后不再重算：`field_misentry` @ Step 1.5，`data_category` @ Step
  4，`flag_severity` @ Step 7，`duration_extreme` @ Step 7，
  `checkforerrors` @ Step 8。
- **账本恒等式（主要的合理性检查）：** Step 6 起， `data_category` 的
  `equal_time_ok + skipped_na = n_total`， `flag_severity` 的
  `Clean + Minor + Major = n_total − skipped_na`。
- 完整验证规则集见本文 §2。

**论文图注** \> **Figure A1.**
五个评估系统（字段误填、数据类别、标记严重度、极端 \>
时长、错误检查）按步骤 × 标准 × 类别的记录计数。每个标准在固定 \>
管线步骤计算一次；之后计数必须保持不变。

#### P26 · 值得二次检查的参与者

**文件** `pipeline_cleaning/P26_PerParticipant_Flag_Rate.png` — 生成于
`sleep_visualization.R:2579`

**论文用途** Supplement

**每部分是什么意思** 一张表（不是柱状图），列出标记记录比率最高的 20 位
参与者——参与者 ID、总记录数，以及 Clean / Minor / Major 的百分比——供人工
审查优先级参考；标记率 ≥ 20% 的行底色为橙色，≥ 50% 为红色。图的副标题
用当前阈值定义了 Minor（1 个标记）和 Major（2 个以上标记）。

**健康外观** 少数几个参与者的短名单；没有失控的离群者。

**异常 →** 名单很长 → 影响许多参与者的系统性问题，而非个体行为。

**精确规则**

- 和图 17 相同的比率构造（`flags / days observed`），排序后呈现为
  一份审查优先级清单，而不是质量结论。

**常见问题** - *“标记率高——是数据错误吗？”*
不一定。它只是标记出值得人工核查的 记录；结论来自审查，不是来自这张图。

**论文图注** \> **Figure P26.**
按标记记录比率排序的参与者表格，供人工审查优先 \>
级参考。高比率标记出值得人工核查的记录；这不是数据有问题的结论。

#### R25 · 睡眠规律性——工作日 vs 周末

**文件** `research_ready/R25_Sleep_Regularity_Weekday_Weekend.png` —
生成于 `sleep_visualization.R:3043`

**论文用途** Results

**每部分是什么意思** 两个并排面板——**左 = 就寝时间，右 = 起床
时间**（顶部粗体标签）——各自是按日型（工作日/周末，颜色区分）
拆分的时钟小时小提琴图 + 箱线图。

**使用的列** 就寝时间 = `time_bed_corrected`（校正后的”上床”时间戳，即
`time_bed`）；起床时间 =
`time_getup_corrected`（校正后的”离床”时间戳，即
`time_getup`）。两者都是流水线生成的列，不是原始日记列。就寝时刻早于中午的小时数会
+24，所以 y 值大于 24 表示过了午夜（如 26 = 02:00）。

**健康外观** 周末就寝时间晚约 0.5–1 小时；起床晚约 1 小时；其余分布
相似。

**异常 →** 工作日 = 周末完全一致 → day_type 被错误赋值或日期信息
丢失；周末偏移很大 → 强烈的社交时差（值得作为一个发现来报告）。

**精确规则**

- `day_type`
  由修正后的就寝时间派生：`wday(time_bed_corrected, week_start = 1) >= 6 → "Weekend"`（周六、周日），否则为
  “Weekday”（周一至周五）。小提琴图展示按日型拆分的就寝和起床时钟
  小时。一个较小（≤ 1 小时）的周末延迟是健康信号；较大的偏移是值得
  报告的社交时差。

**常见问题** - *“02:00 的就寝时间算哪一天？”* 算 `time_bed_corrected`
时间戳的 日历日——经过跨午夜翻转修正后，那就是参与者实际”上床”的那个傍晚
（比如周六晚 23:30 → 记作周六的 wday；周日 02:00 在归一化后归入
周六那一行）。

**论文图注** \> **Figure R25.**
就寝和起床时钟小时的小提琴图叠加箱线图，按日型 \>
拆分（工作日：周一至周五；周末：周六至周日，由修正后的就寝日期 \>
派生）。一个适度（≤ 1 小时）的周末延迟是预期的；较大的偏移表示 \>
社交时差。

#### R26 · 睡眠构成——TIB 拆分

**文件** `research_ready/R26_Sleep_Composition_TIB_Breakdown.png` —
生成于 `sleep_visualization.R:3096`

**论文用途** Results

**每部分是什么意思** 卧床时间构成的堆叠柱状图；图的副标题给出了每个
缩写的定义：TIB = TST（总睡眠时间——真正睡着的部分）+ SOL（入睡
潜伏期——入睡过程）+ WASO（睡后觉醒——夜间醒着的部分），以占比 形式呈现。

**健康外观** TST 是主导色块（约 TIB 的 80–90%）；SOL 和 WASO 是小 薄片。

**异常 →** SOL 或 WASO 占 TIB 超过 30% → 睡眠碎片化程度高或入睡
潜伏期长；出现负的”残差” → 时长算术有 bug。

**精确规则**

- **恒等式：** `TIB = TST + SOL + WASO`——这张图把这三个部分堆叠
  起来，画出 `sol_pct = SOL / total * 100` 等。真实公式里没有
  “残差”这一说；堆叠总和与 TIB 之间任何看起来的差距都是舍入误差。
  健康构成：TST ≈ TIB 的 80–90%，SOL 和 WASO 是小薄片。

**论文图注** \> **Figure R26.**
将卧床时间（TIB）拆分为其组成部分的堆叠柱状图： \>
总睡眠时间（TST）、入睡潜伏期（SOL）、睡后觉醒（WASO），构造上 \> TIB =
TST + SOL + WASO。健康构成中 TST 占 TIB 的 80–90%。

#### R27 · 睡眠指标相关矩阵

**文件** `research_ready/R27_Sleep_Metrics_Correlation_Matrix.png` —
生成于 `sleep_visualization.R:3125`

**论文用途** Results

**每部分是什么意思** 最终修正后数据上，TST、SOL、WASO、SE、TIB 两两
Pearson 相关系数的上三角相关图，每个格子标注系数。

| 颜色 | 含义   |
|------|--------|
| 红色 | 负相关 |
| 绿色 | 正相关 |

**健康外观** 预期的强符号：TST–SE 强正相关，SOL–SE 负相关，TST–TIB
正相关，WASO–SE 负相关。

**异常 →** 符号翻转（比如 TST–SE 变负）→ 指标定义被改动或单位混 用；接近
±1.0 → 两个指标其实是同一列。

**精确规则**

- 最终修正后数据上 TST、SOL、WASO、SE、TIB 两两的 **Pearson** 相关
  （上三角），红色 = 负，绿色 = 正，每格标注系数。
- **预期符号：** TST–SE 强正相关（睡得越多效率越高，因为定义上 SE =
  TST/TIB）；SOL–SE 负相关；TST–TIB 正相关（TIB 是 TST 所在的
  那个”盒子”）；WASO–SE 负相关。相对这些符号的翻转，是指标定义
  变动或单位混用的危险信号。

**常见问题** - *“为什么 TST–SE 相关性高得看起来理所当然？”* 因为 SE
的定义就是 TST/TIB——它们共享一个分子。把定义上相连的指标之间接近 1.0 的
相关性当作确认性结果看待，而不是新发现。

**论文图注** \> **Figure R27.** 最终修正后数据上 TST、SOL、WASO、SE、TIB
两两 \> Pearson 相关系数的上三角相关图（红 = 负，绿 =
正，每格标注系数）。 \> 预期符号：TST–SE 正相关，SOL–SE 负相关，TST–TIB
正相关，WASO–SE \> 负相关。

### 6.3 关键定义

**`equal_time_ok`（图 01，`data_category`）。** 统计两个相邻日记
时间戳结果相同、但记录本身依然有效的情况。触发条件是就寝时间 ==
入睡时间（零入睡潜伏期）**和/或**醒来时间 == 起床时间（没有赖床），
**且**整个序列仍满足 bed ≤ sleep ≤ awake ≤ getup（时序完整）。内部
追踪三个子模式（`equal_time_type`）：`bed_sleep_equal`、
`awake_getup_equal`、`both_equal`。代码用约 36 秒（0.01 小时）的
容差判定”相等”，以吸收浮点数舍入误差（`R/flag_standards.R`）。

**和 error 路径的关键区别：** sleep == awake（零时长睡眠）**永远
不会**被分类为 Equal Time——那始终是 error，因为一晚零总睡眠时长
是一条坏记录，不是良性的报告模式。Equal Time 特指参与者把两个相邻
检查点（比如”上床”和”睡着”）报告成同一个时刻的无害情况——这是
填写睡眠日记的一种常见、合理的方式。这类记录会直接算作有效，不会
进入人工审查。

**`skipped_na`。** 任何一条记录只要四个修正后时间戳中有一个缺失，
就被分类为 `skipped_na`，并被排除在时序评估之外。Step 6 起
`equal_time_ok + skipped_na = n_total` 必须成立——这个恒等式是 ledger
的主要合理性检查。

**Unusual vs Error。** `unusual` = 顺序或间隔模式可疑但合理（比如 bed 和
sleep 之间 \> 3 小时，顺序仍然正常）——会被审查，通常原样 接受。`error` =
时序不可能，或零时长睡眠——一经确认，总会被审查 并修正。

## 8. 人工输入文件与如何运行管线

### 8.1 人工修正输入 CSV

管线从工作目录读取最多七个人工审查 CSV 文件（路径在配置 YAML 的
`data.files.*` 下设置；`inst/scripts/00a_setup.R` 在启动时检查它们是否
存在并报告缺失文件）。每个文件都是*真实*参与者数据文件——要把它们 排除在
git 和发布构建之外（`.gitignore` + `.Rbuildignore` 已经覆盖了 全部）。

| CSV（配置键）                                  | 在何处被使用                                          | 为什么存在                                                  | 由谁创建                                                                                     |
|------------------------------------------------|-------------------------------------------------------|-------------------------------------------------------------|----------------------------------------------------------------------------------------------|
| `second_review_checklist.csv`                  | Step 4.75（`apply_second_review`）                    | 在应用修正之前，锁定此前已审查记录的二次审查共识            | 手动起草；`apply_second_review` 追加已路由的行                                               |
| `manual_error_corrections.csv`                 | Step 6（`step_apply_corrections`）                    | 对分类为 `error` 的记录的人工修正决定                       | Step 5 写出 `[NEW]manual_error_correction_review.csv`；审查者填写 `new_value_*` 后另存为此名 |
| `manual_unusual_corrections.csv`               | Step 6（`step_apply_corrections`）                    | 对分类为 `unusual` 的记录的人工决定                         | Step 5 写出 `[NEW]manual_unusual_review.csv`；同样的审查填写流程                             |
| `manual_nap_exercise_corrections.csv`          | Step 6.5（`apply_nap_exercise_corrections`）          | 对小睡与运动时长的修正                                      | 手动创建；`apply_second_review` 可能追加                                                     |
| `manual_sleep_metric_duration_corrections.csv` | Step 6.5（`apply_sleep_metric_duration_corrections`） | 修正派生睡眠时长里剩余的内部不一致                          | 手动创建                                                                                     |
| `manual_metric_review_acceptances.csv`         | Step 6.5（`apply_metric_review_acceptances`）         | 对计算出的睡眠指标（TST、SOL、WASO、SE）的人工接受/拒绝决定 | 手动创建；`apply_second_review` 可能追加                                                     |
| `audit_dispositions.csv`                       | Step 9 之后（`audit_data_integrity`）                 | 记录每条被改动记录处置结果的审计账本，用于可回溯性          | 由管线自身写出                                                                               |

**格式：** 每个文件都是纯 CSV；error/unusual 文件包含
`pid, day_num, row_id, variable, old_value_hhmm, old_value_ampm, new_value_hhmm, new_value_ampm, correction_type, confidence, reviewer_notes`（Step
5 写出的 `[NEW]` 审查文件已经预填了诊断信息—— 只需填写 `new_value_*` 和
`reviewer_notes` 列）。列模板在
`templates/template_*.csv`；`inst/extdata/stub_*.csv` 作为仅含表头的
格式示例（无真实数据）随包发布。

### 8.2 运行代码

**完整管线（10 阶段 + 图表）：**

``` r
library(sleepcleanr)
run_pipeline(config = "real_data_config_fixed.yaml")           # 完整运行
run_pipeline(config = "real_data_config_fixed.yaml",
             skip_visualization = TRUE)                        # 只清洗，不出图
```

或者从 shell 运行 `inst/scripts/run.sh`（若包未安装会先安装，然后用
默认配置跑
[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)）。

**可复现的人工审查链（fasttrack 审计）：** 管线运行之后，候选检测 → 审查
→ 重建这条链已经用 md5 完整性检查全程脚本化：

``` r
source("validation/reproduce_fasttrack_chain.R")   # derive → disambiguate →
                                                  # promote → rebuild; verifies
                                                  # byte-identical outputs
```

**运行前的前提条件：** 输入数据文件（`data.files.main`，`.rds` 或
`.csv`）以及 §8.1 提到的七个人工 CSV 必须存在于工作目录中；配置 YAML
指向每一个。`00a_setup` 检查会准确报告缺失了哪些文件，而不是静默失败。

### 8.3 人工审查循环（人话版）

**你的问题，回答一下：**”那一堆人工 CSV——是靠不停问 AI 生成的，还是
管线自己生成的？是什么决定一条记录需要人来看？”

答案：**管线决定，靠确定性规则——无 AI、无随机。** 每次运行 Step 5
都会重新给每条记录分类，并写出两份”请审查这些”文件。人（或作为 助手的
AI）只需要填写*正确的值应该是什么*。循环是这样运作的：

    Step 5：给全部记录分类 → 写出 [NEW]manual_error_correction_review.csv
                                和 [NEW]manual_unusual_review.csv
       ↓
    人工审查：填写 `column_to_correct` + `correct_value`（+ 备注）
       ↓
    去掉 [NEW] 前缀 → 另存为 manual_error_corrections.csv /
                         manual_unusual_corrections.csv
       ↓
    下一次管线运行：Step 6 应用你的修正，重新推导一切
       ↓
    Step 5 重新分类：已修正的记录不再是错误 → 它们从新的 [NEW]
       文件里消失。循环，直到 [NEW] 文件变空。

**什么会让一条记录进入审查堆（精确规则，按优先级）：**

*ERROR——物理上不可能，必须修正（`generate_correction_files.R:315`）：* 1.
`sleep_awake_equal_error` — 入睡时间 == 醒来时间（零时长睡眠；
记录从根本上坏了） 2. `order_error` — bed → sleep → awake → getup
的顺序被违反（比如 起床早于就寝） 3. `bed_sleep_diff_error` —
就寝和入睡相隔超过 7 小时（没有人要花 7 小时才睡着） 4.
`awake_getup_diff_error` — 醒来和起床之间超过 7 小时 5.
`sleep_awake_24h_error` — 计算出的睡眠时段超过 24 小时

*UNUSUAL——可疑但可能，值得看一眼（`:393`）：* 1.
`sleep_awake_suspicious` — 总睡眠 \< 3 小时 或 \> 15 小时 2.
`bed_sleep_suspicious` — 入睡潜伏期 \> 3 小时 3.
`awake_getup_suspicious` — 醒后赖床 \> 3 小时才起床 4.
`multiple_suspicious` — 同时命中上面好几条

*最终标签优先级：* `error` \> `equal_time` \> `unusual` \> `normal`。
Equal-time 记录会得到一个标签，但**永远不会进入审查文件**——它们是
良性的（见 §6.3）。

**一份 `[NEW]` 审查文件里有什么（列，按顺序）：**

| 列组         | 列                                                                                                                | 含义                                                         |
|--------------|-------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------|
| 身份         | `pid`, `day_num`, `row_id`                                                                                        | 哪个参与者、哪一天、哪一行                                   |
| 原始录入     | `time_bed/sleep/awake/getup_am_hhmm_ampm`                                                                         | 参与者原样填写的内容（未改动）                               |
| 解析后时间   | `time_bed/sleep/awake/getup_corrected`                                                                            | 管线目前最好的猜测                                           |
| 差值         | `bed_sleep_diff_h`, `sleep_awake_diff_h`, `awake_getup_diff_h`, `reasonable_temporal_order`                       | 上面那些规则据以触发的数字                                   |
| 机器判定     | `error_type`, `corrected`, `correction_type`                                                                      | 哪条规则触发了；算法是否已经修正                             |
| **人工填写** | `problem_humanidentified`, `solution_humanidentified`, `column_to_correct`, `correct_value`, `manually_corrected` | 末尾的空白列——写清楚哪一列错了、正确值是什么、你是否已经修正 |

**为什么这个循环会收敛：** 一条被修正的记录不再违反最初标记它的
那条规则，于是它就不会再出现在下一份 `[NEW]` 文件里。每一轮审查堆
都会变小；直到 `[NEW]` 文件变空为止。在真实研究数据上，这花了几轮
循环，最终产出 75 条 error + 37 条 unusual 的人工确认修正（见 Methods
部分 Stage 5）。

**已验证数字的来源：** 一次受控重跑（2026-09-29）精确量化了人工
修正对最终数据集的影响：不含人工修正时，1,719 条记录有可计算的
总睡眠时间，61 条仍留在 `error` 类；含人工修正时，1,729 条记录有效
（净增 10），85 条记录带有人工修正，只有 3 条仍是 error。11 条被
“解锁”的记录原本是 `error` 类，修正后的时间戳让 TST 首次可以计算
（293–590 分钟）；一条极端记录（TST = 10 分钟）在修正后被正确地
退出了有效集合。
