# 如何读懂管线输出（中文）

[English
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output.md)

[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
跑完后，两个 CSV
文件告诉你一切。本文说明怎么读它们、怎么对比上一次运行做回归检查、以及怎么看图。

第 1–3 节讲怎么运行管线和准备人工输入文件；第 4–7 节讲两个输出
CSV、回归检查和快速检查卡；第 8–9 节讲怎么看图。

目录

- [术语与定义](#s-terms)
  - [睡眠指标](#s-terms-1)
  - [记录分类：`data_category`](#s-terms-2)
  - [指标标记：`flag_severity`](#s-terms-3)
  - [“标准”（standard）](#s-terms-4)
- [1. 运行管线](#s-1)
- [2. 人工输入文件](#s-2)
  - [2.1 样例与模板文件](#s-2-1)
- [3. 人工审查循环（人话版）](#s-3)
- [4. `output/correction_status_final.csv` — 运行摘要（先看这个）](#s-4)
- [5. `output/step_flag_ledger.csv` — 每步标记追踪（第二个看）](#s-5)
  - [5.1 列布局](#s-5-1)
- [6. 回归检查（对比上次运行）](#s-6)
- [7. 快速检查卡](#s-7)
- [8. 如何看图](#s-8)
- [9. 逐图参考](#s-9)
  - [9.1 图索引](#s-9-1)
  - [9.2 管线清洗图卡片（`pipeline_cleaning/`）（15 张）](#s-9-2)
    - [01 · 管线记录流](#c-01)
    - [06 · 修正后睡眠时长](#c-06)
    - [07 · 标记构成堆叠图](#c-07)
    - [10 · 极端睡眠时长](#c-10)
    - [13 · 错误类别分布](#c-13)
    - [13B · 相邻时间戳间隔](#c-13b)
    - [13C · 检测结果热力图](#c-13c)
    - [13D · 阈值 vs 测量噪声](#c-13d)
    - [14 · 修正前睡眠时长](#c-14)
    - [15 · 错误时间线](#c-15)
    - [16 · 常见错误模式](#c-16)
    - [17 · 标记率最高的参与者](#c-17)
    - [18 · 自动检测仪表板](#c-18)
    - [A1 · 逐步标记账本](#c-a1)
    - [P26 · 值得二次检查的参与者](#c-p26)
  - [9.3 研究结果图卡片（`research_ready/`）（16 张）](#s-9-3)
    - [02 · 修正影响](#c-02)
    - [02B · 睡眠变量分布](#c-02b)
    - [03 · TST 分布](#c-03)
    - [04 · 睡眠时长 vs 卧床时间](#c-04)
    - [04B · SOL vs 睡眠时长](#c-04b)
    - [05 · 睡眠变量的变异性](#c-05)
    - [09 · 就寝 vs 起床时间分布](#c-09)
    - [20 · SOL 感知偏差](#c-20)
    - [20B · WASO 感知偏差](#c-20b)
    - [21 · 物质使用数据可得性](#c-21)
    - [22 · 物质使用数值分布](#c-22)
    - [23 · 咖啡因摄入](#c-23)
    - [24 · 酒精摄入](#c-24)
    - [R25 · 睡眠规律性——工作日 vs 周末](#c-r25)
    - [R26 · 睡眠构成——TIB 拆分](#c-r26)
    - [R27 · 睡眠指标相关矩阵](#c-r27)

## 术语与定义

后面的表格和图用到的词，都在这里一次讲清。

### 睡眠指标

| 术语     | 含义                                                   |
|----------|--------------------------------------------------------|
| **TIB**  | Time in Bed，卧床时间——从躺下到起床                    |
| **SOL**  | Sleep Onset Latency，入睡潜伏期——从躺下到真正睡着      |
| **TST**  | Total Sleep Time，总睡眠时间——实际睡着的时间           |
| **WASO** | Wake After Sleep Onset，睡后觉醒——入睡后夜间醒着的时间 |
| **SE**   | Sleep Efficiency，睡眠效率——卧床时间中真正睡着的百分比 |

它们之间有一个贯穿全部图表的恒等式：`TIB = TST + SOL + WASO`，`SE = TST / TIB`。

### 记录分类：`data_category`

它描述一条记录的*时间戳*长什么样。每条记录恰好属于下面某一类，按下表的优先级依次判断，先匹配到的生效。

| 优先级 | 类别                 | 判定标准                                                                                                                                                           | 怎么处理                   |
|:------:|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------|
|   1    | `skipped_na`         | 四个修正后时间戳（bed、sleep、awake、getup）中有任何一个缺失                                                                                                       | 排除在顺序检查之外         |
|   2    | `error`              | 顺序被破坏（不满足 `bed ≤ sleep ≤ awake ≤ getup`）；或 `sleep = awake`（零时长睡眠）；或 bed→sleep、awake→getup 的间隔超过 7 小时；或 sleep→awake 跨度超过 24 小时 | 一定会被审查，确认后修正   |
|   3    | `equal_time_ok`      | 顺序完整，且 bed = sleep 和/或 awake = getup（差值小于 0.01 小时，约 36 秒）                                                                                       | 算有效记录，不进入人工审查 |
|   4    | `unusual`            | 顺序完整、不是 equal-time，但 bed→sleep 或 awake→getup 有一段间隔超过 3 小时                                                                                       | 会被审查，通常原样保留     |
|   5    | `clean`              | 以上都不是                                                                                                                                                         | 无需处理                   |
|   —    | `reasonable_unusual` | 经人工看过并接受的 `unusual` 记录                                                                                                                                  | 单独计数，不丢掉人工的判断 |

- **Equal Time 不算错误。**
  把”上床”和”睡着”（或”醒来”和”起床”）填成同一个钟点，是填写睡眠日记时常见、无害的方式。它被记为
  `bed_sleep_equal`、`awake_getup_equal` 或
  `both_equal`（`equal_time_type`）。
- **`sleep = awake` 永远是 error。**
  一晚零睡眠是一条坏记录，不是无害的习惯，所以它绝不会是 Equal Time。
- **0.01 小时的容差** 只用来吸收浮点数舍入误差，不会掩盖真实的差别。
- **合理性检查：** 这六类合计等于 `n_total`（账本用它做检查，见
  §5）。规则的代码在 `R/flag_standards.R`。

### 指标标记：`flag_severity`

它统计一条记录触发了多少个派生指标的问题：睡眠效率低于
70%、入睡潜伏期超过 1 小时、睡后觉醒超过 1.5 小时（默认值，在
`classification.flag_severity.*` 里设置）。`Clean` = 0 个标记，`Minor` =
1 个，`Major` = 2 个及以上。

它和 `data_category` 是**不同的系统**：一条记录可以在 `data_category`
里是 `clean`，在 `flag_severity` 里是
`Major`（顺序没问题，但算出来的指标很极端）。这三类合计也等于
`n_total`。

### “标准”（standard）

账本（§5）里的”标准”指五个评估系统之一：`field_misentry`、`data_category`、`flag_severity`、`duration_extreme`、`checkforerrors`。每个标准在固定的某一步计算一次，之后不再重算。

## 1. 运行管线

先准备好输入（见 §2），再运行：

``` r
library(sleepcleanr)
run_pipeline(config = "my_study.yaml", include_manual_corrections = TRUE)  # 完整运行
run_pipeline(config = "my_study.yaml", skip_visualization = TRUE)          # 只清洗，不出图
```

| 参数                         | 作用                                                                                                                                                                                                                      |
|------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `config`                     | 你的配置 YAML 路径（复制 `inst/config_template.yaml`，改 `data` 部分）。                                                                                                                                                  |
| `include_manual_corrections` | **默认 `FALSE`。** 为 `FALSE` 时只跑算法：所有人工审查 CSV 都当作不存在，并有横幅提示没有应用人工修正。设为 `TRUE` 才会应用配置里指定的人工修正文件。默认关闭，是为了让数据集永远不会被工作目录里遗留的审查文件悄悄改掉。 |
| `skip_visualization`         | 设为 `TRUE` 跳过出图（Step 9 和 Step 11）。                                                                                                                                                                               |
| `finalize`                   | 默认 `TRUE`：写出交付数据集（Step 10）。设为 `FALSE` 则清洗完就停。                                                                                                                                                       |

也可以在 shell 里运行
`inst/scripts/run.sh`（包没装会先安装，然后用默认配置跑
[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)）。

**运行前：** 输入数据文件（`data.files.main`，`.rds` 或 `.csv`）以及 §2
提到的人工 CSV 必须存在于工作目录；配置 YAML 指向其中每一个。`00a_setup`
检查会准确报告缺了哪些文件，而不是静默失败。

**进阶——可复现的人工审查链（fasttrack 审计）。** 管线运行之后，“候选检测
→ 审查 → 重建”这条链已经用 md5 完整性检查全程脚本化（仅仓库源码可用）：

``` r
source("validation/reproduce_fasttrack_chain.R")   # derive → disambiguate →
                                                  # promote → rebuild; verifies
                                                  # byte-identical outputs
```

## 2. 人工输入文件

管线从工作目录读取最多七个人工审查 CSV 文件（路径在配置 YAML 的
`data.files.*` 下设置；`inst/scripts/00a_setup.R`
在启动时检查它们是否存在并报告缺失文件）。每个文件都是*真实*参与者数据文件——要把它们排除在
git 和发布构建之外（`.gitignore` + `.Rbuildignore` 已经覆盖了全部）。

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
`templates/template_*.csv`；`inst/extdata/stub_*.csv`
作为仅含表头的格式示例（无真实数据）随包发布。

### 2.1 样例与模板文件

不必从空白文件开始，包里提供了模板和虚拟样例数据：

| 是什么                    | 在哪里                                                              | 说明                                                                                                                                                                                                      |
|---------------------------|---------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 六个审查 CSV 的仅表头模板 | `inst/extdata/stub_*.csv`（随包安装）                               | `stub_error_corrections.csv`、`stub_unusual_corrections.csv`、`stub_nap_exercise.csv`、`stub_metric_duration.csv`、`stub_metric_accept.csv`、`stub_second_review.csv`——列正确，没有数据行，也没有真实数据 |
| 审计处置模板              | `inst/extdata/template_audit_dispositions.csv`                      | 仅表头                                                                                                                                                                                                    |
| 填好示例行的模板          | GitHub 仓库里的 `templates/template_*.csv`                          | 虚构的示例行（例如 1001 号参与者）；**不**随安装包发布                                                                                                                                                    |
| 虚拟样例数据集            | `inst/extdata/synthetic_sleep_data.rds` 和 `synthetic_ema_data.csv` | 280 行虚拟日记，没有真实参与者                                                                                                                                                                            |
| 虚拟数据集的配置          | `inst/extdata/synthetic_config.yaml`                                | 演示怎么为一份新数据映射列名                                                                                                                                                                              |
| 列字典                    | `inst/extdata/column_dictionary.csv`                                | 说明交付数据里每一列的含义                                                                                                                                                                                |

在 R 里找到已安装的文件：

``` r
system.file("extdata", "stub_error_corrections.csv", package = "sleepcleanr")
```

把模板复制到工作目录，改成配置里期望的文件名，再填写。

## 3. 人工审查循环（人话版）

**常见疑问：**”那一堆人工 CSV——是靠不停问 AI
生成的，还是管线自己生成的？是什么决定一条记录需要人来看？”

答案：**管线决定，靠确定性规则——无 AI、无随机。** 每次运行 Step 5
都会重新给每条记录分类，并写出两份”请审查这些”文件。人（或作为助手的
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
    Step 5 会列出规则在修正之前的数据上标记的所有记录，所以你已经处理过的
       行也会再列一遍。新增的四列告诉你每一行（如果有）在哪里处理过；运行结束
       时还会打印一段汇总。循环，直到没有未处理的行、也没有仍然有问题的行
       （见"怎么知道做完了"）。

**什么会让一条记录进入审查堆（精确规则，按优先级）：**

*ERROR——物理上不可能，必须修正（`generate_correction_files.R:315`）：* 1.
`sleep_awake_equal_error` — 入睡时间 ==
醒来时间（零时长睡眠；记录从根本上坏了） 2. `order_error` — bed → sleep
→ awake → getup 的顺序被违反（比如起床早于就寝） 3.
`bed_sleep_diff_error` — 就寝和入睡相隔超过 7 小时（没有人要花 7
小时才睡着） 4. `awake_getup_diff_error` — 醒来和起床之间超过 7 小时 5.
`sleep_awake_24h_error` — 计算出的睡眠时段超过 24 小时

*UNUSUAL——可疑但可能，值得看一眼（`:393`）：* 1.
`sleep_awake_suspicious` — 总睡眠 \< 3 小时或 \> 15 小时 2.
`bed_sleep_suspicious` — 入睡潜伏期 \> 3 小时 3.
`awake_getup_suspicious` — 醒后赖床 \> 3 小时才起床 4.
`multiple_suspicious` — 同时命中上面好几条

*最终标签优先级：* `error` \> `equal_time` \> `unusual` \> `normal`。
Equal-time
记录会得到一个标签，但**永远不会进入审查文件**——它们是良性的（见
术语与定义）。

**一份 `[NEW]` 审查文件里有什么（列，按顺序）：**

| 列组                         | 列                                                                                                                | 含义                                                                 |
|------------------------------|-------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------|
| 身份                         | `pid`, `day_num`, `row_id`                                                                                        | 哪个参与者、哪一天、哪一行                                           |
| 原始录入                     | `time_bed/sleep/awake/getup_am_hhmm_ampm`                                                                         | 参与者原样填写的内容（未改动）                                       |
| 解析后时间                   | `time_bed/sleep/awake/getup_corrected`                                                                            | 管线目前最好的猜测                                                   |
| 差值                         | `bed_sleep_diff_h`, `sleep_awake_diff_h`, `awake_getup_diff_h`, `reasonable_temporal_order`                       | 上面那些规则据以触发的数字                                           |
| 机器判定                     | `error_type`, `corrected`, `correction_type`                                                                      | 哪条规则触发了；算法是否已经修正                                     |
| **人工填写**                 | `problem_humanidentified`, `solution_humanidentified`, `column_to_correct`, `correct_value`, `manually_corrected` | 空白列——写清楚哪一列错了、正确值是什么、你是否已经修正               |
| **在哪里处理过**（管线添加） | `in_manual_file`, `review_resolution`, `resolved_at`, `resolved_by`                                               | 从你的人工文件里对应的那一行带过来。四列全空表示这条记录还没人处理过 |

**怎么知道做完了。** `[NEW]`
文件总是列出规则在*修正之前*的数据上标记的所有记录，所以它不会缩到空。要看新增的四列：

| 看到的情况                                          | 含义                                         |
|-----------------------------------------------------|----------------------------------------------|
| 四列全空                                            | 从没处理过——要做的                           |
| `corrected` 加 `resolved_by`                        | 已处理并有记录                               |
| `resolution_unknown_legacy` / `legacy`              | 处理过，但没人记录是谁、什么时候（可以补上） |
| `flagged_unresolved`，或 `resolved_by` 为 `pending` | 等待确认                                     |

每次运行结束时，管线会打印每张待审表里各状态的行数，以及有多少条**已处理的行在自动复查之后仍然有问题**（仍是
error，或仍被标记）。改过的记录仍可能通不过复查，所以最后这个数很重要。当没有未处理或待确认的行、也没有仍有问题的行时，就做完了。在真实研究数据上，最终产出了
75 条 error + 37 条 unusual 的人工确认修正（见 Methods 部分 Stage 5）。

**已验证数字的来源：**
一次受控重跑（2026-09-29）精确量化了人工修正对最终数据集的影响：不含人工修正时，1,719
条记录有可计算的总睡眠时间，61 条仍留在 `error` 类；含人工修正时，1,729
条记录有效（净增 10），85 条记录带有人工修正，只有 3 条仍是 error。11
条被 “解锁”的记录原本是 `error` 类，修正后的时间戳让 TST
首次可以计算（293–590 分钟）；一条极端记录（TST = 10
分钟）在修正后被正确地退出了有效集合。

## 4. `output/correction_status_final.csv` — 运行摘要（先看这个）

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

**关于 SOL 的说明**：上面的 `sol_mean_min` 是**原始 SOL 时长**。这和图
20 检查的”SOL 感知偏差”（自报值与计算值之间的差距，见
§9.3）是不同的量——两处用的参考数字不一样（这里是 10–45 分钟，那边是
15/60 分钟），因为它们衡量的根本不是同一件事。不要拿这两组数字互相对照。

## 5. `output/step_flag_ledger.csv` — 每步标记追踪（第二个看）

每行 = 步骤 × 标准 × 类别。回答”哪个步骤出现哪种标记，是否持续？”

``` r
ledger <- read.csv("output/step_flag_ledger.csv")
library(dplyr)
ledger %>% filter(!is.na(count)) %>% arrange(step_id, standard)
```

每行回答：“这一步、用这个标准、有多少记录落入这个类别？”

### 5.1 列布局

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

**概念规则**：标准只计算一次、从不重算。若某标准计数在其首次计算步骤后改变，就有问题。

**验证规则**：

1.  `field_misentry` — Step 1.5 起有数。任何 `SOL=time_bed` 或
    `WASO=time_getup` `count > 0` = 潜在跨字段污染。
2.  `data_category` — Step 6
    起数字必须**稳定**：`clean + unusual + reasonable_unusual + equal_time_ok + error + skipped_na = n_total`。
3.  `flag_severity` — Step 7 起 Steps 7/8/8.5 完全相同：
    `Clean + Minor + Major = n_total`。
4.  `duration_extreme` — `Too short + Too long` 应 \< 总记录 5%。
5.  `checkforerrors` — 仅 Step 8 有数据。

**示例（合成数据，280 行）**：

    Step 7 (Compute metrics):
      data_category:    equal_time_ok = 266, skipped_na = 14        266 + 14 = 280 ✓
      flag_severity:    Clean = 251, Minor = 28, Major = 1         251 + 28 + 1 = 280 - 14 ✓
      duration_extreme: OK = 262, Too short = 1, Too long = 0

## 6. 回归检查（对比上次运行）

`output/correction_status_old.csv`
不是任何管线脚本写的——重跑前你自己另存一份基线：

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

## 7. 快速检查卡

| 检查项                           | 如何验证                                                                              | 通过条件 |
|----------------------------------|---------------------------------------------------------------------------------------|----------|
| 管线完成                         | `file.exists("output/correction_status_final.csv")`                                   | `TRUE`   |
| TST 合理                         | `tst_mean_h` 在 6–8.5                                                                 | 是       |
| SOL 合理（原始时长，非感知偏差） | `sol_mean_min` 在 10–45                                                               | 是       |
| 错误少                           | `n_error < 0.01 * n_total`                                                            | 是       |
| data_category 稳定               | Steps 6–8.5 计数相同                                                                  | 是       |
| flag_severity 稳定               | Steps 7–8.5 计数相同                                                                  | 是       |
| 全记录有交代                     | `clean + unusual + reasonable_unusual + equal_time_ok + error + skipped_na = n_total` | 是       |
| 确定性                           | 同输入 → 同输出，每次                                                                 | 是       |

## 8. 如何看图

图保存在 `latest_visualization_<tag>_n<rows>/`（每次运行覆盖——无历史）。
`figure_index.png`
总览所有图；如果有图没能生成，整张图**最顶部**会有一个红色的 “FIGURE(S)
NOT GENERATED THIS RUN”
区块，逐条列出没生成的图和原因。稳定验证产物（snapshot、Bland-Altman
图、阈值验证）单独在 `output/verification/<tag>/`。

**第一次看这些图？** 先看 `figure_index.png` 总览，再按顺序过一遍下面 “5
张必看检查图”——它们合起来就是一次浓缩版的睡眠数据质量
QC。这里出现的每个图号（比如 “01”、“13D”）都对应 §9.2 或 §9.3
里的一个标题，可以直接跳过去看完整解释。文件夹的划分（`pipeline_cleaning/`
= 质控/审计图， `research_ready/` =
为论文准备的图）只有在你决定论文放哪张图时才重要——
如果只是检查数据，按图号找就行，不用管文件夹。

**出版用图（Methods 部分）：**

| 图                  | 文件                                             | 显示什么                                                                |
|---------------------|--------------------------------------------------|-------------------------------------------------------------------------|
| **图 1 — 管线流程** | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` | 垂直流程图：raw → 解析 → 算法修正 → 人工修正 → 最终有效，各阶段计数与 % |
| **图 2 — 修正影响** | `research_ready/02_Correction_Impact.png`        | A/B delta lollipop（仅修正记录，TST & SOL）+ 一致性散点 + 前后汇总表    |

**5 张必看检查图：**

| 步骤 | 图（卡片）                   | 应该长这样                                                | 若不是？                                                  |
|:----:|------------------------------|-----------------------------------------------------------|-----------------------------------------------------------|
|  1   | **01 管线记录流** (§9.2)     | 流程平缓收窄；Clean 占主导；Error + Unusual 很小（\< 5%） | 0 处有尖峰或 Error/Unusual 占比巨大 → 上游解析/AM-PM 失败 |
|  2   | **A1 逐步标记账本** (§9.2)   | Corrected 柱只在 Step 6.5 出现，之后持平                  | Step 6.5 之后再变化 = 不稳定                              |
|  3   | **18 自动检测仪表板** (§9.2) | 标记计数与 `correction_status_final.csv` 一致             | 不一致 = 错位                                             |
|  4   | **02B 睡眠变量分布** (§9.3)  | TST 峰值在 6–8 h，SOL 右偏，WASO \< 60，SE \> 85%         | SOL 平/双峰 = AM/PM 混淆未修正                            |
|  5   | **13 错误类别分布** (§9.2)   | 多数记录 Clean/Minor；Error+Unusual \< 5%                 | 偏高 → 审查人工 CSV                                       |

## 9. 逐图参考

管线产出的每一张图都在下面记成一张自成一体的卡片：每个部分是什么意思、它是根据什么精确规则画出来的、健康数据长什么样、异常意味着什么，以及一段可以直接用在论文里的图注。图落在
`latest_visualization_<tag>_n<rows>/pipeline_cleaning/`（诊断用）和
`.../research_ready/`（出版用）两个文件夹里。

### 9.1 图索引

| \#      | 文件                                                      | 论文用途    | 代码来源                        | 卡片                                        | 最后核对   |
|---------|-----------------------------------------------------------|-------------|---------------------------------|---------------------------------------------|------------|
| **01**  | `pipeline_cleaning/01_Pipeline_Flow_Diagram.png`          | Methods 图1 | `sleep_visualization.R:862`     | [§9.2 · 管线记录流](#c-01)                  | 2026-09-25 |
| **02**  | `research_ready/02_Correction_Impact.png`                 | Methods 图2 | `sleep_visualization.R:1013`    | [§9.3 · 修正影响](#c-02)                    | 2026-09-25 |
| **02B** | `research_ready/02B_Distribution_Sleep_Variables.png`     | Results     | `sleep_visualization.R:1057`    | [§9.3 · 睡眠变量分布](#c-02b)               | 2026-09-25 |
| **03**  | `research_ready/03_Sleep_Duration_Distribution.png`       | Results     | `sleep_visualization.R:1108`    | [§9.3 · TST 分布](#c-03)                    | 2026-09-25 |
| **04**  | `research_ready/04_Sleep_Duration_vs_Time_in_Bed.png`     | Results     | `sleep_visualization.R:1163`    | [§9.3 · 睡眠时长 vs 卧床时间](#c-04)        | 2026-09-25 |
| **04B** | `research_ready/04B_SOL_vs_Sleep_Duration.png`            | Results     | `sleep_visualization.R:1215`    | [§9.3 · SOL vs 睡眠时长](#c-04b)            | 2026-09-25 |
| **05**  | `research_ready/05_Variability_Sleep_Variables.png`       | Results     | `sleep_visualization.R:1265`    | [§9.3 · 睡眠变量的变异性](#c-05)            | 2026-09-25 |
| **06**  | `pipeline_cleaning/06_Sleep_Duration_Post_Correction.png` | Supplement  | `sleep_visualization.R:1339`    | [§9.2 · 修正后睡眠时长](#c-06)              | 2026-09-25 |
| **07**  | `pipeline_cleaning/07_Flag_Composition_Stacked.png`       | Supplement  | `sleep_visualization.R:1404`    | [§9.2 · 标记构成堆叠图](#c-07)              | 2026-09-25 |
| **09**  | `research_ready/09_Bedtime_vs_Getup_Distribution.png`     | Results     | `sleep_visualization.R:1458`    | [§9.3 · 就寝 vs 起床时间分布](#c-09)        | 2026-09-25 |
| **10**  | `pipeline_cleaning/10_Extreme_Sleep_Duration.png`         | Supplement  | `sleep_visualization.R:1514`    | [§9.2 · 极端睡眠时长](#c-10)                | 2026-09-25 |
| **13**  | `pipeline_cleaning/13_Error_Category_Distribution.png`    | Supplement  | `sleep_visualization.R:1794`    | [§9.2 · 错误类别分布](#c-13)                | 2026-09-25 |
| **13B** | `pipeline_cleaning/13B_Adjacent_Timestamp_Gaps.png`       | Supplement  | `sleep_visualization.R:1877`    | [§9.2 · 相邻时间戳间隔](#c-13b)             | 2026-09-25 |
| **13C** | `pipeline_cleaning/13C_Detection_Outcomes_Heatmap.png`    | Supplement  | `sleep_visualization.R:1936`    | [§9.2 · 检测结果热力图](#c-13c)             | 2026-09-25 |
| **13D** | `pipeline_cleaning/13D_Threshold_vs_Noise_Ratio.png`      | Supplement  | `sleep_visualization.R:1980`    | [§9.2 · 阈值 vs 测量噪声](#c-13d)           | 2026-09-25 |
| **14**  | `pipeline_cleaning/14_Sleep_Duration_Pre_Correction.png`  | Supplement  | `sleep_visualization.R:2051`    | [§9.2 · 修正前睡眠时长](#c-14)              | 2026-09-30 |
| **15**  | `pipeline_cleaning/15_Error_Timeline.png`                 | Supplement  | `sleep_visualization.R:2137`    | [§9.2 · 错误时间线](#c-15)                  | 2026-09-30 |
| **16**  | `pipeline_cleaning/16_Common_Error_Patterns.png`          | Supplement  | `sleep_visualization.R:2228`    | [§9.2 · 常见错误模式](#c-16)                | 2026-09-30 |
| **17**  | `pipeline_cleaning/17_Top_Participants_Flags.png`         | Supplement  | `sleep_visualization.R:2307`    | [§9.2 · 标记率最高的参与者](#c-17)          | 2026-09-25 |
| **18**  | `pipeline_cleaning/18_Auto_Detected_Dashboard.png`        | Supplement  | `sleep_visualization.R:2409`    | [§9.2 · 自动检测仪表板](#c-18)              | 2026-09-25 |
| **20**  | `research_ready/20_SOL_Perception_Bias.png`               | Results     | `sleep_visualization.R:2637`    | [§9.3 · SOL 感知偏差](#c-20)                | 2026-09-25 |
| **20B** | `research_ready/20B_WASO_Perception_Bias.png`             | Results     | `sleep_visualization.R:2695`    | [§9.3 · WASO 感知偏差](#c-20b)              | 2026-09-25 |
| **21**  | `research_ready/21_Substance_Use_Availability.png`        | Supplement  | `sleep_visualization.R:2767`    | [§9.3 · 物质使用数据可得性](#c-21)          | 2026-09-25 |
| **22**  | `research_ready/22_Substance_Use_Distribution.png`        | Supplement  | `sleep_visualization.R:2870`    | [§9.3 · 物质使用数值分布](#c-22)            | 2026-09-25 |
| **23**  | `research_ready/23_Caffeine_Consumption.png`              | Supplement  | `sleep_visualization.R:2944`    | [§9.3 · 咖啡因摄入](#c-23)                  | 2026-09-25 |
| **24**  | `research_ready/24_Alcohol_Consumption.png`               | Supplement  | `sleep_visualization.R:2979`    | [§9.3 · 酒精摄入](#c-24)                    | 2026-09-25 |
| **A1**  | `pipeline_cleaning/A1_Step_Flag_Ledger.png`               | Supplement  | `figure12_step_flag_table.R:15` | [§9.2 · 逐步标记账本](#c-a1)                | 2026-09-25 |
| **P26** | `pipeline_cleaning/P26_PerParticipant_Flag_Rate.png`      | Supplement  | `sleep_visualization.R:2579`    | [§9.2 · 值得二次检查的参与者](#c-p26)       | 2026-09-25 |
| **R25** | `research_ready/R25_Sleep_Regularity_Weekday_Weekend.png` | Results     | `sleep_visualization.R:3043`    | [§9.3 · 睡眠规律性——工作日 vs 周末](#c-r25) | 2026-09-25 |
| **R26** | `research_ready/R26_Sleep_Composition_TIB_Breakdown.png`  | Results     | `sleep_visualization.R:3096`    | [§9.3 · 睡眠构成——TIB 拆分](#c-r26)         | 2026-09-25 |
| **R27** | `research_ready/R27_Sleep_Metrics_Correlation_Matrix.png` | Results     | `sleep_visualization.R:3125`    | [§9.3 · 睡眠指标相关矩阵](#c-r27)           | 2026-09-25 |

`11`（标记共现图）在完整数据的标记列少于两列时跳过，原因会写在
`figure_index.png` 顶部的红色区块里。`14`、`15`、`16`
在有东西可画时都会生成（见下面的卡片）；某次运行确实没东西可展示时（例如待审队列已清空，因为一切都已审查过），跳过原因会明确说明。

> **仅供参考。**
> 下面的建议只是一个起点，不是规定；具体选哪些图取决于你论文要讲的内容和期刊的限制。

**为论文选图——一个建议。**
上面”论文用途”这一栏是默认建议，不是定论。对于管线支持的 Methods/Results
结构，这样分效果不错：

- **Methods 正文（2 张图）。**
  01（管线记录流）——展示管线*是什么*：各阶段、计数、最终分类构成。02（修正影响）——展示清洗*做了什么*：非破坏性，只改动了确认的输入错误。这两张图正好回答审稿人最先问的两个问题（“你做了什么？”和”改动有多大？“），不带多余信息。
- **Results 正文（挑 3–5 张）。** 03（TST 分布）作为数据质量的锚点；
  20/20B（感知偏差）如果自报值与计算值的一致性是故事的一部分；R25
  （工作日 vs 周末）或 R26（TIB 构成）如果时间规律性/构成很重要；R27
  （相关矩阵）如果你引用了指标之间的相互关系。正文里最好不要超过五张——
  其余的放进补充材料里读起来更舒服。
- **补充材料（其余全部）。** 所有 `pipeline_cleaning/` 图（13、13B、
  13C、13D、17、18、A1、P26、06、07、10）构成审计轨迹：把它们放进一个标题为”数据质量与清洗审计”的补充材料里，在
  Methods 里用一句话统一引用（“完整审计轨迹见补充材料
  S1”）。物质使用相关的图（21–24）跟着论文报告的物质使用分析走，没有的话也放补充材料。

如果篇幅紧张，最简版：**Methods 里放 01 + 02，Results 里放 03 + 20 +
R27，其余进补充材料的审计轨迹部分。** 每一张的图注都已经写好，在下面
§9.2 和 §9.3 每张卡片的末尾。

### 9.2 管线清洗图卡片（`pipeline_cleaning/`）

#### 01 · 管线记录流

**文件** `pipeline_cleaning/01_Pipeline_Flow_Diagram.png` — 生成于
`sleep_visualization.R:862`

**论文用途** Methods 图1

**每部分是什么意思** 5 个阶段的垂直流程图，每个阶段都自解释： Raw
Load（全部日记条目）→ Parsed（有时间戳的条目）→ Auto-Corrected （AM/PM +
顺序修正）→ Manual-Corrected（人工审查修正）→ Final Valid
（可用于分析）。每个方框 = 记录数 +
占总数的百分比；两个修正阶段还额外显示参与者人数。

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

**健康外观** 流程从原始记录到有效记录平缓收窄；侧边说明里 Clean
最大，Error 加 Unusual 合计不到约
5%；两个修正阶段的数字都很小——说明只有确实出错的记录被修正，其余数据按填写原样保留。

**异常 →** Error/Unusual 占比很大，通常是上游的 AM/PM
混淆或解析问题，而不是真有成千上万个坏夜晚；已知有错误的数据里修正数几乎为零，则说明检测漏掉了记录。

**精确规则**

- **统计的是什么。** 每一行原始日记记录算一条（真实运行里是 13,990
  条）。五个方框是依次经过的阶段：全部载入、有时间戳的记录、被规则修正的记录（AM/PM
  和顺序修复）、被人工修正的记录、可用于分析的记录。所有百分比都以原始总数为分母。
- **侧边的分类怎么来的。**
  每条最终记录恰好落入一类，自上而下依次判断：未报告、错误、等时、少见、干净，先匹配到的生效。确切规则在”术语与定义”里，图上每一类旁边也印着。
- **最下面那行**（“x%
  的原始记录进入分析”）是四个时间戳都齐全、因而算得出睡眠指标的记录占原始记录的比例。
- **有修正的参与者**是至少有一条记录被修正的参与者数，分母是全部参与者。

**常见问题**

为什么 Equal Time 不算错误？

入睡潜伏期为零（或一醒就起床）是合理的报告。管线把 `error`
留给写出来就不可能的记录：顺序被打破，或零睡眠。

如果两对都相等（bed = sleep 且 awake = getup）呢？

仍然是 `equal_time_ok`，记作 `both_equal`。

0.01 小时对审查者意味着什么？

相差不到约 36
秒的两个时间戳算同一个。这个容差只用来吸收浮点数舍入，不会掩盖真实差别。

为什么将近 80% 的记录是”未报告”？这是问题吗？

意思是这些行至少缺了四个时间中的一个（比如那天没填日记）。管线从不猜测缺失的时间。是否算问题，取决于你的研究设计和预期的回收率——拿它和你的预期比一比。

图里”Error (Reviewed)“只有 3 条，但图 2 显示修正了 77 条，哪个对？

都对。图 1 给最终数据分类：修好的错误不再是错误，所以这一类只剩 3 条。图
2 数的是一路上被改动过的记录。

**论文图注**

> **Figure 01.**
> 追踪所有原始日记条目经过五个管线阶段（原始载入、时间戳解析、算法修正、人工修正、最终有效输出）的流程图，每个阶段标注记录数和百分比。侧边注释报告最终记录分类（clean、unusual
> accepted、error reviewed、equal-time
> benign、not-reported）以及至少接受过一次修正的参与者比例。TST =
> 总睡眠时间；SOL = 入睡潜伏期。

#### 06 · 修正后睡眠时长

**文件** `pipeline_cleaning/06_Sleep_Duration_Post_Correction.png` —
生成于 `sleep_visualization.R:1339`

**论文用途** Supplement

**每部分是什么意思** 按记录类别（Clean / Unusual / Manually Corrected /
Error）画出的最终睡眠时长密度曲线，取自 Step 5–6.5
之后。这回答的问题是：人工修正有没有扭曲整体睡眠时长的分布？（被修正类别的曲线应该和
clean 曲线重叠。）

**健康外观** 只有一个平滑的峰，位于 6–8 小时，0 处和 12
小时以上没有堆积——这是正常夜间睡眠的形状，也说明人工修正没有扭曲整体分布。

**异常 →** 曲线平坦或出现两个峰，说明 12 小时制和 24
小时制的时间格式没被解析干净；0
处出现尖峰，说明有缺失或零时长的记录漏了进来。

**精确规则**

- **画的是什么。** 每一类记录（Clean、Unusual、Manually
  Corrected、Error）的最终
  `sleep_duration_h`（TST，小时）的平滑曲线。每条曲线按自己的面积缩放，所以比的是形状，不是高度；副标题写明了每条曲线依据多少条记录。
- **包含哪些记录。**
  只有算得出睡眠时长的记录，而且只有这四类。被人工修正过的记录一律显示为
  Manually Corrected，不管它原来属于哪一类。
- **它的用途。** 检查人工修正有没有扭曲整体分布：可以和图 14 对照，图 14
  是没做任何人工修正之前的同类曲线。

**常见问题**

为什么这里的记录数比图 1 里”可用于分析”的数量少得多？

图 6 只画 Clean、Unusual、Manually Corrected 和 Error 这几类。Equal Time
记录（良性的）和 Not Reported 记录（算不出时长）不在里面。

为什么 Unusual 的曲线和 Clean 的不一样？

Unusual 记录是按”间隔异常”这条规则挑出来的，不是随机样本。它们不必长得像
Clean，不一样也不代表它们是错的。

人工修正的曲线在最短和最长两端有额外的小包，这是问题吗？

人工修正的记录本来就是因为坏了才被挑出来的，所以极端时长在其中占比偏高。值得逐条打开看，但光凭这些小包不能说明修正有错。

**论文图注**

> **Figure 06.**
> 应用全部人工修正之后，最终总睡眠时间（TST，小时）的密度图。以 6–8 h
> 为中心的单峰分布表示健康的睡眠时长；0 或 \> 12 h
> 处的尖峰表示残留的解析artifact。

#### 07 · 标记构成堆叠图

**文件** `pipeline_cleaning/07_Flag_Composition_Stacked.png` — 生成于
`sleep_visualization.R:1404`

**论文用途** Supplement

**每部分是什么意思** 堆叠直方图：x = 睡眠时长（h），y =
该区间的记录数，填色 = `flag_severity`（见前文”术语”），图例标题为”Data
Quality”。展示质量问题是否集中在极端时长处。

| 填色  | 含义               |
|-------|--------------------|
| Clean | 0 个指标标记       |
| Minor | 1 个指标标记       |
| Major | 2 个及以上指标标记 |

不要和 `data_category` 混淆——那是另一个不同的分类系统（见 术语与定义
关键定义）。

**健康外观**
每个时长区间里，绿色（Clean）部分都最大。橙色和红色的薄片（指标被标记的记录）主要出现在极端处——3
小时以下、12 小时以上——以及 0
处。这是预期的：极端时长正是最容易触发睡眠效率、入睡潜伏期、睡后觉醒阈值的情形。

**异常 →**
中间时长区间也出现一大片橙色或红色，说明是系统性的解析问题，而不是个别极端记录。

**精确规则**

- **颜色的含义。** 填充色是 `flag_severity`，不是
  `data_category`：Clean（没有指标标记）、Minor（1 个标记）、Major（2
  个及以上）。一个标记指下列之一：睡眠效率低于 70%、入睡潜伏期超过 1
  小时、睡后觉醒超过 1.5 小时（在 `classification.flag_severity.*`
  里设置）。
- **柱子是什么。**
  每根柱子数的是睡眠时长落在该区间的记录数；颜色把每根柱子按严重程度拆开。
- **被截掉的部分。** x 轴显示 0 到 16 小时；时长为 0 或 20
  小时及以上的记录没有画。
- **角落里的框** 重复写明了阈值以及 Minor、Major
  的记录数，所以不看本页也能读懂这张图。

**常见问题**

所以这里说的是指标标记，不是时间戳错误？

对。图 13 讲的是时间戳和格式问题；图 7
显示每个睡眠时长上出现了多少指标标记。它们是两套不同的系统（`flag_severity`
对 `data_category`）。

为什么彩色的薄片集中在两端？

睡得特别短或特别长，恰好最容易让睡眠效率、入睡潜伏期或夜间觉醒越过阈值，所以标记自然会聚在那里。那里的标记是提示你去看，不是结论。

可以改阈值吗？

可以，在配置文件的 `classification.flag_severity.*`
下。图角落的框读的是当前值，所以始终是对的。

**论文图注**

> **Figure 07.** 最终睡眠时长（小时）的堆叠直方图，柱子按 flag severity
> 着色：Clean（无指标标记）、Minor（一个标记）、Major （两个或更多，来自
> {SE \< 70%, SOL \> 1 h, WASO \> 1.5
> h}）。展示质量问题是否集中在极端时长处。

#### 10 · 极端睡眠时长

**文件** `pipeline_cleaning/10_Extreme_Sleep_Duration.png` — 生成于
`sleep_visualization.R:1514`

**论文用途** Supplement

**每部分是什么意思** 散点图：x = TST（h），y =
睡眠效率（%），限制在极端时长（\< 4 h 或 \> 10 h）。

| 编码   | 含义                   |
|--------|------------------------|
| 颜色   | 数据质量               |
| 形状   | 短睡眠者 vs 长睡眠者   |
| 水平线 | SE = 85%（低效率阈值） |

**健康外观**
极端值只是一小撮散点。短睡眠点（三角形）大多落在中等的睡眠效率（约
60–95%），长睡眠点（圆点）的效率较高——它们更像合理的少见夜晚，而不是计算出来的假象。

**异常 →** 很多短睡眠点的睡眠效率低于
85%，可能是真实的失眠，也可能是测量问题——需要逐条看那些记录；正好落在
TST = 0 或 24 小时的点，则指向解析失败。

**精确规则**

- **显示的是什么。** 只显示极端值：TST 低于 4
  小时（三角形，“短睡眠”）或高于 10
  小时（圆点，“长睡眠”）的记录，中间的都不画。颜色是数据质量类别。
- **虚线** 在睡眠效率 85%
  处，是取自临床经验值的读图参考。管线自己的标记用的是
  70%（`poor_efficiency_threshold_pct`），所以一个点可以低于 85%
  但没被标记。
- **两套界限。** 4 小时和 10 小时是这张图自己的显示界限，比管线的
  `duration_extreme` 界限（低于 3 小时、高于 12
  小时）宽松，后者是另一项检查。

**常见问题**

4 小时和 10 小时是怎么来的？

是为了显示分布的两端而选的显示界限，不是管线的生理界限（`duration_extreme`：低于
3 小时、高于 12 小时）；不要把两套混在一起。

低于 85% 这条线的点，说明这条记录有问题吗？

不。这条线只是读图参考。睡眠效率低加时长短，可能是真的睡得很差，也可能是测量问题，或是需要核对的日记条目——光看这张图分不出来。

为什么点这么少？

只画 4–10
小时范围之外的记录，而大多数夜晚都在这个范围里。点少是预期的、健康的样子。

**论文图注**

> **Figure 10.**
> 总睡眠时间（TST，小时）对睡眠效率（SE，%）的散点图，限制在极端时长（\<
> 4 h 短，\> 10 h
> 长）。点的形状编码短/长睡眠；点的颜色编码记录质量。水平线标出 SE = 85%
> 的低效率阈值。

#### 13 · 错误类别分布

**文件** `pipeline_cleaning/13_Error_Category_Distribution.png` — 生成于
`sleep_visualization.R:1794`

**论文用途** Supplement

**每部分是什么意思**
自动检测的错误/审查类别柱状图，带计数和百分比标签。类别对应
`auto_error_desc` 前缀（Temporal / Metrics / Amount / Interval /
Timestamp）。

**健康外观** 一两个类别占大头（通常是 Metric Threshold 或
Temporal），而且每个类别的绝对数量都不大——待审队列很短，原因集中在少数几种。

**异常 →** Timestamp Format 或 Interval Format
的柱子很高，说明参与者成批地用了非标准格式填写；应先检查解析规则，再逐条审查记录。

**精确规则**

- **柱子数的是什么。** 在做任何人工修正之前，Step 8
  的自动检查标记出的记录，按问题种类分组。种类由检查信息的前缀决定：`[Temporal]`
  时序问题，`[Metrics]` 指标阈值，`[Amount]` 数量/输入标记，`[Interval]`
  时长格式，`[Timestamp]` 时间戳格式；其余为”Other”。
- **副标题** 写明了喂给 Metric Threshold 这一组的指标规则：SOL 超过 120
  分钟、睡眠效率低于 0 或高于 100%、TST/TIB 比值低于 0.5。
- **柱子下面的两张表**
  解释类别：第一张列出每个类别、严重程度和通俗说明；第二张按检查结果给记录计数（比如
  SELF_REPORTED_FLAG、CLEAN）。

**常见问题**

为什么叫”修正前”？

它回答的是”原始数据里有哪些需要关注的东西？“——也就是管线要承担的工作量。图
18 显示的是之后仍被标记的部分。

柱子里的记录就是错的吗？

不是。它表示自动检查希望有人看一眼。很多被标记的记录只是自报值和计算值不一致，管线有意把它们当作数据保留。

为什么有一根柱子比其他的高很多？

通常是某一条规则一次抓到了很多记录。一根柱子独大，意味着有一个常见原因；先查那个原因。

“Other Issue”是什么？

它收集的是检查信息不以五个已知前缀之一开头的被标记记录。实际上这些通常是被”时长重新解读”检查标记出来的记录（信息前缀
`[DurationReinterp]`）：某个 SOL 或 WASO
的值，可能是用错了格式填的（比如把”分:秒”当成了”时:分”）。

**论文图注**

> **Figure 13.**
> 修正后自动检测流程标记的记录柱状图，按标记描述派生的六个审查类别分组：时序问题、指标问题、数量/录入标记、区间格式错误、时间戳格式错误、其他。计数是修正前的——展示的是管线要承担的负担。

#### 13B · 相邻时间戳间隔

**文件** `pipeline_cleaning/13B_Adjacent_Timestamp_Gaps.png` — 生成于
`sleep_visualization.R:1877`

**论文用途** Supplement

**每部分是什么意思** 相邻日记事件（bed→sleep、sleep→awake、
awake→getup）之间的间隔小时数直方图，用的是**修正前的原始时间**。负间隔
= 后一个事件的时钟时间早于前一个。0 处有竖直参考线。

**健康外观** 多数间隔落在 +0.5 到 +2
小时之间——正数表示事件顺序符合预期。有一小段负数尾巴是正常的：负间隔表示后一个事件的钟点比前一个还早，是顺序错误或
12 小时制 AM/PM 弄反的特征。

**异常 →**
负间隔占很大比例，说明普遍存在顺序错误，规整步骤会把它们翻转过来；在 ±12
小时附近出现两个堆，则指向 12 小时钟面的 AM/PM 习惯。

**精确规则**

- **间隔是什么。** 对相邻的三对时间——bed 到 sleep、sleep 到 awake、awake
  到
  getup——间隔是后一个时间减前一个时间，单位小时，在原始（已解码）时间上计算，还没有做任何修正。
- **负间隔** 表示后一个事件的钟点比前一个事件还早（比如同一行里醒来是
  01:00，入睡却是 23:00）。这是顺序错误或 12 小时制 AM/PM
  弄反的原始特征。
- **红色色带** 标出 −3 到 −6
  小时的间隔，这个范围定义了验证工作里的”AM/PM
  解码或字段互换候选”；带内的数量印在带上。
- **怎么读形状。** 大约 −1 到 −3
  小时的负值堆，指向顺序互换（由互换步骤修复）；在 ±12
  小时附近出现两个堆，指向把 PM 时间填成了 AM（由 12
  小时翻转步骤修复）。

**常见问题**

为什么在修正之前画？

因为它要显示原始填写是什么样。修正之后负间隔大多没了，画出来就看不到管线解决的问题了。

为什么三个面板的坐标不一样？

每一对时间的典型大小不同：bed→sleep 和 awake→getup
的间隔通常在一两个小时以内，而 sleep→awake 是整晚（约 6–10
小时）。每个面板按自己的数据缩放。

红色带里的数字，说明有这么多记录是错的吗？

不完全是。它数的是原始间隔落在这个范围、因此看起来像 AM/PM
或互换候选的记录。其中有些是真实的长间隔，是不是错误，要由规则和审查来决定。

**论文图注**

> **Figure 13B.** 相邻日记事件（bed→sleep、sleep→awake、
> awake→getup）之间时间间隔（小时）的直方图，基于修正前的原始时间戳计算。负间隔表示后一个事件的时钟时间早于前一个，是顺序错误和
> 12 小时 AM/PM 表盘习惯的信号。

#### 13C · 检测结果热力图

**文件** `pipeline_cleaning/13C_Detection_Outcomes_Heatmap.png` — 生成于
`sleep_visualization.R:1936`

**论文用途** Supplement

**每部分是什么意思**
来自合成错误注入基准的热力图。每一行是一种被故意注入干净记录的错误类型；每一列是管线对它做了什么：`CORRECT`（修对了）、`FLAGGED_UNRESOLVED`（检测到但交给人处理，没有自动修）、`MISREPAIRED`（修错了）、`MISSED`（没检测到）、`NO_MATCH`。每个格子是该错误类型的记录中出现这种结果的百分比。副标题写明了注入的行数和类别数。

**健康外观** 每一行的颜色几乎都落在 `CORRECT` 或
`FLAGGED_UNRESOLVED`——错误要么被正确修好，要么被检测到并交给人——而
`MISREPAIRED`、`MISSED`、`NO_MATCH` 接近
0。有些错误类型只会被标记、从不自动修（比如填错字段），这是设计使然：管线对不能安全修复的东西选择标记，而不是猜。

**异常 →** `MISREPAIRED`
有颜色，说明自动修错了——比不动这条记录还糟。`MISSED`
有颜色，说明这种错误根本没被检测到。

**精确规则**

- **数据从哪来。**
  合成错误注入基准（`validation/synthetic/results/detection_outcomes_v4_current.csv`）：把已知的错误注入干净数据，再在结果上跑管线。因为正确答案是已知的，每个结果都能被打上标签。
- **一个格子是什么。** 对某种注入的错误类型，`n` 是注入的行数；格子是
  `count / n × 100`。所以每一行加起来约为 100%。
- **五种结果。** `CORRECT` 修对了；`FLAGGED_UNRESOLVED`
  检测到但交给人处理、没有修；`MISREPAIRED` 修错了；`MISSED`
  没检测到；`NO_MATCH` 这条注入的行没能和管线输出里的某一行一一对上。
- **文件缺失时**（工作目录里没有它），这张图会被跳过，原因显示在图索引的顶部。

**常见问题**

为什么合成注入的图会放在 QC 文件夹里？

它是检测数字有意义的证据：检测器是拿已知的真值来检验的，而真实数据里”正确答案”是不可知的。

FLAGGED_UNRESOLVED 算失败吗？

不算。它表示管线发现了问题，但不想猜着去修，把决定留给人。对某些错误类型（比如值填到了错误的字段），这正是设计的行为。

哪种颜色最让人担心？

MISREPAIRED。自动修错比不动这条记录更糟，因为它悄悄改了数据，没人察觉。其次是
MISSED：错误留在数据里没被发现。

这张图能告诉我真实数据里有多少错误吗？

不能。它是在故意放进错误的合成数据上做的测试。它告诉你每个检测器有多可靠，而不是你自己的数据里有多少错误。

**论文图注**

> **Figure 13C.**
> 来自合成基准的热力图，已知错误被注入干净记录。行是被注入的错误类型，列是管线的处理结果（修对、标记待审、修错、漏检），每个格子是该错误类型的记录中出现该结果的百分比。

#### 13D · 阈值 vs 测量噪声

**文件** `pipeline_cleaning/13D_Threshold_vs_Noise_Ratio.png` — 生成于
`sleep_visualization.R:1980`

**论文用途** Supplement

**每部分是什么意思**
横向柱状图，每根柱子对应一个能和自报值对照检验的清洗阈值（SOL 和 WASO
的阈值；没有自报对应值的阈值，比如睡眠效率，不画，副标题会写明省略了几个）。柱子长度
= 阈值 ÷ 测量噪声，其中噪声是自报值与管线根据时间戳算出的值之间
Bland-Altman 95% 一致性界限的半宽。虚线标出 2×（临界）和 3×（安全）。

**健康外观** 柱子在 3×
或更长：阈值远高于自报值和计算值之间的正常分歧，所以被它标记的记录，不太可能只是因为测量噪声而被标记。在
2× 到 3× 之间属于临界。

**异常 →** 柱子短于
2×，说明阈值落在典型的测量分歧之内：它标记的记录可能仅仅是噪声造成的，所以把这个标记当作”值得看一眼”的提示，而不是出错的证据——并考虑调高阈值。

**精确规则**

- **每根柱子是什么。**
  一个清洗阈值除以测量噪声。只画能和自报值对照检验的阈值（SOL 和 WASO
  的阈值）；副标题会写明省略了几个别的，比如睡眠效率。
- **“噪声”指什么。**
  自报值和管线根据时间戳算出的值永远不会完全一致。它们典型的分歧，就是
  Bland-Altman 95% 一致性界限的半宽，这就是噪声。
- **怎么分级。** 至少 5× 保守，至少 3× 安全，至少 2× 临界，低于 2×
  落在噪声之内。虚线在 2× 和 3×。
- **用的是现场数字。** 由
  [`validate_thresholds()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/validate_thresholds.md)（`R/bland_altman.R`）用本次运行的数据计算，不是来自合成基准。

**常见问题**

为什么要把阈值和噪声比较？

比测量噪声还小的阈值检测不到任何真实的东西——它只会标记纯噪声。这张图显示每个阈值高出噪声多少。

有一根柱子低于 2×，一定要改阈值吗？

不一定。它的意思是被这个阈值标记的记录，可能仅仅因为噪声就被标记了，所以把那些标记当作”去看一眼”的提示，而不是出错的证据。调高阈值是一种办法；保留阈值、再去审查被标记的记录是另一种。

为什么没有睡眠效率和 TST/TIB？

它们没有可对照的自报值，所以估计不出噪声。副标题会写明省略了几个阈值。

**论文图注**

> **Figure 13D.** 每个清洗阈值除以 Bland-Altman
> 测量噪声（自报值与计算值之间 95% 一致性界限的半宽）。虚线标出
> 2×（临界）和 3×（安全）。

#### 14 · 修正前睡眠时长

**文件** `pipeline_cleaning/14_Sleep_Duration_Pre_Correction.png` —
生成于 `sleep_visualization.R:2051`

**论文用途** Supplement

**每部分是什么意思** 两条叠加的睡眠时长密度曲线：绿色 =
没有任何自动检测标记的记录（最多抽样 5,000 条）；红色 =
被算法标记待审的记录。这是修正前的视图：只有算法，没有人工修正。副标题给出了两组的样本量。

**健康外观**
被标记（红色）的曲线更宽或发生偏移——这正是这些记录被标记的原因——而且它依据的记录数比干净（绿色）曲线少得多。

**异常 →**
两条曲线几乎一样，说明这些标记和睡眠时长无关，它们来自时间戳或格式规则。

**精确规则**

- **两组记录。** 绿色是没有任何自动标记的记录的随机样本（最多 5,000
  条）；红色是自动检查标记出的、并且有可用睡眠时长的全部记录。
- **在任何人工修正之前。**
  这里只用算法的标记，不应用人工修正，所以曲线显示的是自动检查看到的东西。
- **可以和图 6 对照**，图 6 是人工审查之后的同类曲线。

**常见问题**

为什么绿色只是样本？

没被标记的记录比被标记的多得多；最多画 5,000
条，既能保持曲线好读，又不改变它的形状。副标题给出了两组的样本量。

两条曲线很像，是问题吗？

不一定，但这说明标记并不是由睡眠时长驱动的——它们来自时间戳或格式规则。

这张图什么时候不生成？

当没有任何被标记的记录有可用的睡眠时长时。图索引的顶部会写明这一点。

**论文图注**

> **Figure 14.** 没有自动检测标记的记录（绿色，最多随机抽样 5,000
> 条）与被标记待审的记录（红色）在任何人工修正之前的睡眠时长（小时）密度。

#### 15 · 错误时间线

**文件** `pipeline_cleaning/15_Error_Timeline.png` — 生成于
`sleep_visualization.R:2137`

**论文用途** Supplement

**每部分是什么意思** 按月份的堆叠柱状图，统计在 Step 5/6
得到时间分类的记录：`order_error`（错误）和三种”可疑间隔”类型（`bed_sleep_suspicious`、`sleep_awake_suspicious`、`awake_getup_suspicious`）。之所以按月统计，是因为这类记录总共只有几十条；逐日的面积图会在孤立的日期之间画出倾斜的色块，容易误导。

**健康外观**
计数很小，分散在整个研究期，没有哪个月一家独大——这类少见模式只是偶尔出现，并不集中在某一段时间。

**异常 →**
某个月突然尖峰，指向方案变更或数据采集中断；集中在研究开始阶段，指向学习曲线或说明不清。

**精确规则**

- **哪些记录。**
  带有时序分类的记录：顺序错误（`order_error`）或三种”可疑间隔”之一（bed→sleep、sleep→awake、awake→getup）。每条记录需要有就寝时间戳，才能放到日历上。
- **为什么按月。**
  这类记录总共只有几十条。按日画的面积图会在孤立的日子之间画出斜的色块，暗示并不存在的趋势，所以这张图按月计数。
- **数据来源。** `corrected_ema_data`，分类就存在那里。`clean_df`
  是分类之前的较早数据框，没有这些列。
- **标记不是结论。** 这些记录大多审查过并原样保留（见图 2）。

**常见问题**

某个月出现尖峰意味着什么？

提示那段时间发生了变化——方案变更、技术问题，或一批新参与者。看看尖峰是由哪一类模式构成的，以及涉及哪些参与者。

柱子为什么有不同颜色？

每种颜色是一种模式类型：`order_error`、`bed_sleep_suspicious`、`sleep_awake_suspicious`、`awake_getup_suspicious`。图下方的图例写明了它们。

我的有些记录没有日期，它们会从图里消失吗？

会。没有就寝时间戳的记录没法放到日历上，所以不画。

**论文图注**

> **Figure 15.** 每月带有时间顺序错误或可疑间隔模式（Step 6
> 分类）的记录数，按模式类型区分。

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

**健康外观** 少数几个已命名的模式覆盖了队列的大部分，“Other /
unclassified” 很小——说明检测原因都描述得清楚。

**异常 →** “Other / unclassified”
很大，说明有检测规则在这张图里没有对应的标签。

**精确规则**

- **排的是什么。**
  自动检查标记出的记录队列，按其信息里发现的具体模式分类排序：时序顺序错误、异常睡眠模式、SOL
  / 睡眠效率 / TST-TIB 指标异常、SOL 超过床到入睡窗口、WASO
  估计不一致、时长格式和时间戳解析问题。
- **“Other / unclassified”。**
  不匹配任何已命名模式的被标记记录。这根柱永远画在最后，这样你能看到已命名的模式没能解释的比例。
- **什么时候跳过。** 如果每条被标记的记录都是 “Other /
  unclassified”，或者队列里什么都没有（比如一切都已审查过），这张图就不画，原因列在图索引的顶部。

**常见问题**

“SOL exceeds bed-to-sleep window”是什么意思？

自报的入睡用时，比就寝和入睡两个时间戳之间的时间还长，再加上一个小容差（`window_tolerance_minutes`，默认
15 分钟）。这两个报告互相矛盾，所以需要人看一眼。

“Other / unclassified”很高是坏事吗？

它是关于这张图本身的信号，不是关于你数据的：检测器给出了这张图没有标签的原因。值得弄清楚它们是什么。

这和图 13 一样吗？

它们用的是同一批被标记的记录，但分组方式不同。图 13 按检查的种类分组；图
16 给每条信息里的具体模式命名。

**论文图注**

> **Figure 16.**
> 待审队列中自动检测到的最常见模式；最后一根柱汇总了不匹配任何已命名模式的记录。

#### 17 · 标记率最高的参与者

**文件** `pipeline_cleaning/17_Top_Participants_Flags.png` — 生成于
`sleep_visualization.R:2307`

**论文用途** Supplement

**每部分是什么意思** 柱状图：按算法标记记录*比率*（标记数 ÷ 天数）排名前
15 的参与者，标注 PID。

**健康外观** 比率不高（约 30%
以下），也没有哪位参与者远高于其他人——标记分布得很分散，不集中在某个人的日记里。

**异常 →** 某位参与者超过约 60%，通常是一种习惯（比如总是按 12
小时钟面填时间）或反复出现的格式错误；去看他的原始记录，找出规律。

**精确规则**

- **比率是什么。**
  对每位参与者，用被自动检查标记的记录数，除以这位参与者拥有的日记天数。显示最高的
  15 个比率，每根柱子标注 `标记数 / 天数`。
- **为什么用比率而不是数量。** 参与者被观察的时长不同。75 天里 5
  个标记（7%）和 5 天里 5 个标记（100%）不是一回事。
- **它的用途。** 找出日记值得看一眼的人。这张图并不说明这些记录有错。

**常见问题**

为什么柱高是百分比，标签却有两个数字？

柱高是百分比比率；标签在此基础上重复写出原始的
`标记数/天数`，让你看到它依据多少数据。几天里的高比率，证据比很多天里的中等比率弱。

排第一的参与者有问题吗？

不一定。高比率通常意味着一种习惯（比如总是按 12
小时钟面填时间）或反复出现的格式错误。先打开这个人的原始记录，看清规律，再做任何决定。

这和图 P26 有什么不同？

图 17 按自动检查的标记排名（只有算法，人工审查之前）。图 P26
按修正后数据的最终指标标记（`flag_severity`）排名。

**论文图注**

> **Figure 17.**
> 按自动检测标记率（每个观测日记天的标记数，而非原始标记计数）排名前 15
> 的参与者，因此日记天数少的参与者不会被过度呈现。

#### 18 · 自动检测仪表板

**文件** `pipeline_cleaning/18_Auto_Detected_Dashboard.png` — 生成于
`sleep_visualization.R:2409`

**论文用途** Supplement

**每部分是什么意思** 左侧文字面板”Key
Metrics”：三个数字，每个数字下面都有它的名称——自动检测（需要人工审查）、人工修正（已审查并修正）、总记录数。右侧：`review_source`
各类别（Temporal Issues / Metrics Issues / Amount/Input Flags / Interval
Format Errors / Timestamp Format Errors / Other）的饼图。

**健康外观** 被标记的记录远少于总记录数；最大的一块通常是 Temporal 或
Metrics 问题；数字与 `correction_status_final.csv` 一致。

**异常 →** 数字和 CSV 对不上，说明账本和表格的流程错位了；Amount/Input
一块很大，指向物质使用的编码问题。

**精确规则**

- **左侧。**
  三个总览数字，每个下面写了名称：算法标记的记录（需要人工审查）、已被人工修正的记录、总记录数。
- **右侧。**
  被标记记录按审查来源分的饼图：Temporal、Metrics、Amount/Input、Interval
  Format、Timestamp Format、Other。每一块标出数量和占比。
- **一致性检查。** 数字应该和 `correction_status_final.csv`
  一致；控制台还会检查有没有已修正的记录仍被标记。

**常见问题**

做了那么多人工工作，为什么被标记的数不是零？

被标记的数是未处理的队列：自动检查标记出、既没有被修正、也没有被审查者接受的记录。只有每条被标记的记录都处理完了，它才会归零。旁边”已修正”的数字是人工修好的那些。

某一块很大时我该怎么办？

打开对应的卡片：Metrics 一块大，去看图
13D（阈值高于噪声吗？）；Amount/Input 一块大，去看物质使用的编码（图
22–24）；Temporal 一块大，去看图 13B 和 15。

饼图不好读，为什么还用饼图？

它只有几块，任务是一眼看出哪个来源占主导。要看精确数字，用每块上印的数量，或者看图
13。

**论文图注**

> **Figure 18.** Key metrics
> 面板（总记录数、被标记记录数、人工修正记录数）搭配六个 review-source
> 类别的堆叠柱状图。计数必须与 `correction_status_final.csv` 一致。

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
表示”这一步还算不出来”；某列第一个出现的数字就是它的生成点。表格下方的说明把每个缩写都写全了，数字居中对齐在表头下面。读法和
§5 的 CSV ledger 一样，只是画成了图。

**健康外观** 每一列的数字在计算它的那一步第一次出现，之后保持不变。从
Step 6 起，`data_category` 的六类合计等于 `n_total`；从 Step 7
起，`flag_severity` 的三类合计等于 `n_total`。

**异常 →** 数字在首次计算的那一步之后又变了，说明管线不稳定（见 §5
的验证规则）。

**精确规则**

- **每个管线步骤一行。**
  各列是五个评估系统，每个都在固定的一步算一次：`DC`（`data_category`，Step
  5）、`SEV`（`flag_severity`，Step 7）、`CFE`（`checkforerrors`，Step
  8）、`MISentry`（`field_misentry`，Step 1.5），再加上 Corrected 和
  Suppressed。
- **破折号表示”还算不出来”。**
  某列第一个出现的数字就是它的生成点；之后数字应该保持不变。
- **值得检查的两个恒等式。** 从 Step 6 起，`data_category`
  的六类合计等于记录数；从 Step 7 起，`flag_severity`
  的三类合计也是。规则清单在 §5。

**常见问题**

为什么后面几行的数字不变？

每个标准只算一次，不再重算。如果某个数字在首次产生它的那一步之后又变了，说明管线里有东西不稳定。

Corrected 和 Suppressed 有什么区别？

Corrected 是数据被改动过的记录数。Suppressed
是经人看过并接受的标记，它们不再需要关注，但数据没有改。

CFE:flag 这一列数的是什么？为什么和图 13 不一样？

从 Step 8 起，它按自动检查汇总表里的每种结果（比如
SELF_REPORTED_FLAG）给记录计数，这张汇总表也是
`correction_status_final.csv`
背后的那张。这张汇总是在人工接受的记录被撤回之前建的，所以仍然把它们算在内（真实运行里是
85 条），同时把”时长重新解读”的标记归成了干净（39 条）。图 13
数的是未处理的队列，所以图 13 是 226，这一列是 272。Step 8
之前显示破折号，因为那时检查还没有运行。

同样的信息在哪个文件里？

`output/step_flag_ledger.csv`（见 §5）。这张图就是把那张表画成了图。

**论文图注**

> **Figure A1.**
> 五个评估系统（字段误填、数据类别、标记严重度、极端时长、错误检查）按步骤
> × 标准 ×
> 类别的记录计数。每个标准在固定管线步骤计算一次；之后计数必须保持不变。

#### P26 · 值得二次检查的参与者

**文件** `pipeline_cleaning/P26_PerParticipant_Flag_Rate.png` — 生成于
`sleep_visualization.R:2579`

**论文用途** Supplement

**每部分是什么意思** 一张表（不是柱状图），列出标记记录比率最高的 20
位参与者——参与者 ID、总记录数，以及 Clean / Minor / Major
的百分比——供人工审查优先级参考；标记率 ≥ 20% 的行底色为橙色，≥ 50%
为红色。图的副标题用当前阈值定义了 Minor（1 个标记）和 Major（2
个以上标记）。

**健康外观** 名单很短，也没有哪位参与者远高于其他人。

**异常 →**
名单很长，说明是影响许多参与者的系统性问题，而不是个别人的行为。

**精确规则**

- **列出了谁。** 自己记录中被 `flag_severity`（Minor 加
  Major）标记的比例最高的 20 位参与者。这个比例是 100% 减去 Clean
  的百分比。
- **颜色。** 标记率达到 20% 或以上的行底色为橙色，50%
  或以上为红色。健康的数据集里不会有行被染色。
- **不是质量结论。**
  标记表示一条记录和自动预期不同，其中包括管线有意保留的”自报值与计算值不一致”。

**常见问题**

某位参与者标记率很高，他的数据是错的吗？

不一定。这张表说的是先检查谁的记录；结论要看记录本身，而不是这张表。

为什么我的图里没有人被染色？

颜色从 20%
起算。如果每位参与者都低于它，这张表就在按预期工作——没有谁特别突出。

这和图 17 有什么不同？

图 17
按人工审查之前的自动检查标记排名；这张表按修正后数据的最终指标标记（`flag_severity`）排名。

**论文图注**

> **Figure P26.**
> 按标记记录比率排序的参与者表格，供人工审查优先级参考。高比率标记出值得人工核查的记录；这不是数据有问题的结论。

### 9.3 研究结果图卡片（`research_ready/`）

#### 02 · 修正影响

**文件** `research_ready/02_Correction_Impact.png` — 生成于
`sleep_visualization.R:1013`

**论文用途** Methods 图2

**用途**
审计修正对数据改了多少、往哪个方向改，回答”清洗有多侵入？“。图的副标题写明了用途，并解释了每个面板怎么读。

**每部分是什么意思** 4 个面板：(A) TST
变化量棒棒糖图——每个被修正的记录一行，x = ΔTST（分钟）；(B) SOL
同样画法；(C) 一致性散点图，修正前 TST vs 修正后 TST（全部记录）；(D)
修正前后 TST/SOL 均值 ±
标准差的汇总表。图注写明了共修正了多少条、总共多少条记录中的多少条。

| 标记                            | 含义                                   |
|---------------------------------|----------------------------------------|
| ● 橙色                          | 算法修正                               |
| ● 蓝色                          | 人工修正                               |
| ● 灰色，3% 不透明度（仅面板 C） | 未改动的记录——几乎透明，衬在修正点背后 |
| 虚线对角线（面板 C）            | 1:1”无变化”参考线                      |

**没有任何修正时**
如果没有记录被改动（数据本来干净，或人工修正文件没有应用），面板 A–C
都会是空的，所以图上只显示一句话——“No record was changed by a correction
in this
run（本次运行没有记录被修正；无需修正，或人工修正文件未应用）”——加上修正前后的汇总表（此时两行数字相同）。

**健康外观** 大多数点落在虚线对角线上，上面两个面板里的线很短、集中在 0
附近，表里修正前后的均值也很接近。这说明清洗是非破坏性的：它只改了少数记录，而不是整份数据。

**异常 →**
线很长或被修正的记录占比很大，说明修正正在改变真实数据，而不只是修录入错误；修正前后均值明显偏移，则需要追问为什么”修”了这么多。

**精确规则**

- **谁算”被修改”。** 每条记录有一个状态：被人工修正触及过的是
  `manual`，否则被规则改过的是 `algorithmic`，否则是
  `none`。一条记录不会同时是两者；manual 优先。
- **上面两个面板画什么。**
  只画被修改的记录，每条一行，按改动的大小排序。ΔTST = 修正后 TST −
  修正前 TST（分钟），ΔSOL 同理。负的线表示修正把这个值变短了。
- **“修正前”指什么。** “修正前”的值是用原始解析出的时间戳重新算的（TST =
  awake − sleep − WASO，SOL = sleep − bed）；“修正后”是管线最终的数字。
- **散点图**
  把全部记录的修正前（x）对修正后（y）画出来。没改动的记录画得几乎透明，所以在对角线后面形成一条淡淡的带，衬出少数彩色的被修改点。
- **表格** 给出 TST 和 SOL
  修正前后的均值与标准差；图注写明了总共多少条记录里改了多少条。

**常见问题**

为什么大部分数据都落在对角线上？

修正按设计是非破坏性的：只修正确认的输入错误（真实运行中约占 0.6%
的记录）。自报值与计算值之间的差异作为数据保留，不会被抹平。

淡淡的点可以离对角线很远吗？

没改动的记录应该落在对角线上。淡点偏离对角线，说明一条没被标记为修正的记录，它的”修正前”值（用原始时间戳重算）和”修正后”值（管线的最终数字）不一样。这张图说不出原因；请打开那条记录看一看。

为什么很多被修正的记录正好是 ±720 分钟？

720 分钟就是 12 小时。AM/PM 翻转会让一个钟点正好变 12
小时，导出的时长也就正好变 12 小时，所以 AM/PM 修复会堆在同一个长度上。

长长的线说明修正错了吗？

不。大的变化通常说明修掉了一个大的输入错误，比如差了 12
小时。修正对不对是在审查里定的，不是这张图；这张图显示的是改动有多大。

为什么有这张表？

它让你一眼看出”平均值变了吗？“。如果修正前后的均值接近，说明清洗没有让整体数据发生偏移。

**论文图注**

> **Figure 02.** (A)
> 每条被修正记录的总睡眠时间变化量（ΔTST，分钟）棒棒糖图，按修正类型着色（橙色
> = 算法，蓝色 = 人工）。(B) 入睡潜伏期同样画法（ΔSOL）。(C) 修正前后
> TST 的一致性散点图；未改动记录以 3% 不透明度画作灰色背景。(D) 修正前后
> TST 和 SOL 均值（±
> 标准差）汇总表。修正是非破坏性的：只改动了确认的输入错误。

#### 02B · 睡眠变量分布

**文件** `research_ready/02B_Distribution_Sleep_Variables.png` — 生成于
`sleep_visualization.R:1057`

**论文用途** Results

**每部分是什么意思**
对关键睡眠指标（TST、SOL、WASO、SE）在**最终修正后**数据上画出的直方图 +
密度曲线。

**健康外观** TST 的峰在 6–8 小时，SOL 右偏（多数人 10–45
分钟内入睡，少数要久得多），WASO 在约 60 分钟以下，睡眠效率在 85%
以上——这是正常睡眠日记会呈现的形状。

**异常 →** SOL 很平或有两个峰，提示 AM/PM 混淆没被修正；睡眠效率恰好堆在
100%，提示有很多”整夜没醒”的记录，值得看一看。

**精确规则**

- **画的是什么。**
  五个小面板，每个指标一个：睡眠时长、卧床时间、WASO、SOL
  和睡眠效率，用的是最终修正后的数据。每个面板有自己的坐标（面板之间的尺度不能比）。
- **柱子和曲线。** 绿色柱子是直方图（40
  个分箱）；红色曲线是同一批数据的平滑版本。两者都用密度尺度，所以每个面板的面积都是
  1。
- **单位。** 时长用小时，睡眠效率用百分比，和其他图一致。

**常见问题**

为什么每个面板的 x 轴不一样？

每个指标有自己的自然尺度——时长用小时，效率用百分比——所以每个面板按自己的数据缩放。不要在面板之间比较横向宽度。

SOL 有一小段负值，是错误吗？

SOL
为负，说明某条记录里入睡时间早于就寝时间。这种情况很少；这些记录会被顺序检查查到。左边缘有几个负值值得看一眼，但几个点不会改变整体的样子。

为什么睡眠效率堆在 100%？

睡眠效率按定义不会超过 100%，很多没有夜醒、没有入睡延迟的夜晚会落在 100%
或接近 100%。恰好在 100% 有一根高柱很常见；只有特别高时才值得看一眼。

这和图 5 有什么不同？

图 2B 显示每个分布的形状（每个值有多常见）。图 5
用小提琴加箱线图显示离散程度，更容易一眼比较中位数和离散。

**论文图注**

> **Figure 02B.**
> 最终修正后数据上，总睡眠时间（TST）、入睡潜伏期（SOL）、睡后觉醒（WASO）和睡眠效率（SE）的直方图与密度曲线。

#### 03 · TST 分布

**文件** `research_ready/03_Sleep_Duration_Distribution.png` — 生成于
`sleep_visualization.R:1108`

**论文用途** Results

**每部分是什么意思** 总睡眠时间（TST——见前文”术语”）的直方图 + 密度图。

| 标记           | 含义                   |
|----------------|------------------------|
| ● 红色平滑曲线 | 密度估计               |
| ● 蓝色实线     | 均值（标注小时数值）   |
| ● 橙色虚线     | 中位数（标注小时数值） |

图下方标题为 “Line shown” 的图例说明了每条线。

这里的 TST
是*增强版*定义：`TST = TIB − SOL − WASO`——不是两个时间戳的原始时钟差值。

**健康外观** 一个峰，中心在 6–8
小时，均值和中位数很接近。单峰而且对称，是健康样本的样子。

**异常 →**
均值远大于中位数，说明右侧有一条很长的尾巴（睡得特别久的人）；0
处有尖峰，说明有零时长记录。

**精确规则**

- **这里的 TST 是什么。**
  增强版定义：睡眠期减去睡后觉醒，`TST = TIB − SOL − WASO`（存为
  `sleep_duration_h`）。它不是两个钟点的原始差值。
- **几条线。** 蓝色实线 = 均值，橙色虚线 = 中位数，红色 =
  平滑密度；图例”Line shown”写明了它们，两个数值也印在里面。
- **偏度。**
  对睡眠数据来说，均值通常比中位数略高，因为右边有睡得特别久的人形成的尾巴。
- **角落的 `n`** 是算得出 TST 的记录数。

**常见问题**

为什么有两张分布图（02B 和 03）？

02B 是五个指标的小面板总览。图 03 把 TST
单独拿出来，并标出均值和中位数，这是论文里通常的第一张图。

为什么 TST 不是入睡到醒来之间的时间？

因为夜里常常有入睡之后醒着的时间。管线会把这部分（WASO）减掉，所以 TST
只算真正睡着的时间。

我的均值和中位数差很远，这意味着什么？

差距说明分布是偏的：一条很长（或很短）的尾巴把均值从中位数拉开了。看看直方图哪一侧有尾巴，再看图
10 和图 06。

这些曲线包含被人工修正的记录吗？

包含。这是最终修正后的数据，所以被修正的记录按修正后的值计入。

**论文图注**

> **Figure 03.**
> TST（小时）的直方图与密度图，标出均值（蓝）与中位数（橙）。TST
> 计算为睡眠时段减去 WASO（TST = TIB − SOL − WASO）。

#### 04 · 睡眠时长 vs 卧床时间

**文件** `research_ready/04_Sleep_Duration_vs_Time_in_Bed.png` — 生成于
`sleep_visualization.R:1163`

**论文用途** Results

**每部分是什么意思** 卧床时间（从躺下到起床）对睡眠时长（实际睡着的时间
= TIB − SOL − WASO）的散点图。黑线 = 线性趋势；周围的灰带 =
该趋势的不确定范围。虚线对角线 = 不可能出现的 TST == TIB 线。

**健康外观**
点贴近虚线（1:1）分布，卧床时间越长散得越开（人会躺着醒着）；没有 TST
超过卧床时间的点，那是不可能的。

**异常 →** 点落在线上方（TST \> TIB），说明时长计算出了错，比如没减去
WASO；点云毫无形状，说明 TIB 和 TST 脱钩了，通常是解析问题。

**精确规则**

- **画的是什么。** 卧床时间（x）对总睡眠时间（y），只画卧床时间低于 24
  小时、TST 在 0 到 20 小时之间的记录。颜色是数据质量类别。
- **不可能线。** 虚线对角线是 TST = TIB。因为 TST = TIB − SOL −
  WASO，任何有效的点都不会在它上方。
- **趋势线** 是普通的直线拟合，带着不确定性范围；副标题印着相关系数
  `r`。
- **视野** 为了好读，两个坐标轴都截在 0–16
  小时；统计用的是范围内的全部点。

**常见问题**

虚线上方的点意味着什么？

那意味着睡的时间比卧床时间还长，这是不可能的。它指向时长计算的问题，比如没有减去
WASO。健康的数据里不应该有这样的点。

为什么卧床时间越长，点云散得越开？

卧床时间越长的人，常常有一部分时间是醒着的，所以睡眠并不像卧床时间增长得那么快。这是正常的散开，不是噪声。

我看到虚线上方有几个点，该怎么办？

它们按记录来说是不可能的（睡的时间比卧床时间还长），通常是解析出了差错或时间戳有问题。在数据里筛选
`sleep_duration_h > time_in_bed_h` 就能找到它们，再逐条手工检查。

为什么坐标轴截在 16 小时？

为了保持图好读。有几个极端点在视野之外，但仍然算在统计里。

**论文图注**

> **Figure 04.**
> TST（小时）对卧床时间（TIB，小时）的散点图，带平滑趋势线和恒等参考线。由于构造上
> TST ≤ TIB，落在恒等线上方的点在物理上不可能。

#### 04B · SOL vs 睡眠时长

**文件** `research_ready/04B_SOL_vs_Sleep_Duration.png` — 生成于
`sleep_visualization.R:1215`

**论文用途** Results

**每部分是什么意思** SOL（躺下后花多久睡着）对 TST 的散点图。每个点 =
一个日记之夜。黑线 = 线性趋势；灰带 = 趋势的不确定范围。红色虚线竖线在
SOL = 1 小时处（标注参考值）。SOL \> 3 小时为了清晰被过滤掉。

**健康外观** 呈负相关——入睡越久，睡得越少；多数点的 SOL 在 1
小时以下；质量颜色是均匀混合的，而不是聚成一团。

**异常 →** 高 SOL 处聚集着 Error/Unusual
颜色，提示有入睡时间填错的模式；SOL = 0
处有一条竖线，是零入睡潜伏期的报告方式（equal-time 记录）。

**精确规则**

- **画的是什么。** 入睡潜伏期（x，小时）对总睡眠时间（y），只画 SOL 在 0
  到 3 小时之间的记录。颜色是数据质量类别。
- **红色点线** 标出 SOL = 1 小时，也就是管线的”入睡潜伏期过长”指标标记。
- **趋势线** 是普通的直线拟合，带着不确定性范围。
- **3 小时的截断** 只是为了让图好读；它是显示选择，不是管线规则。

**常见问题**

为什么这里把 SOL 截在 3 小时，而别的图用的数字不同？

有几个不同的数字，各司其职：3 小时是这张图的显示界限；1 小时是
`flag_severity` 的阈值（红色点线）；图 13 的指标检查标记 SOL 超过 120
分钟。它们是故意分开的。

SOL = 0 处的那条竖线是什么？

报告入睡前没有任何延迟的参与者（或把就寝和入睡填成同一个时间的人）。这些条目就是”术语与定义”里讲的等时报告。

趋势线几乎是平的，这有问题吗？

不一定。在很多样本里，入睡用时和睡多久之间的联系很弱。灰色的带显示了斜率有多不确定。

**论文图注**

> **Figure 04B.** SOL（小时，为了可读性限制在 ≤ 3 小时）对
> TST（小时）的散点图，按 flag severity
> 着色。负相关（入睡潜伏期越长，睡眠越短）是预期的临床模式。

#### 05 · 睡眠变量的变异性

**文件** `research_ready/05_Variability_Sleep_Variables.png` — 生成于
`sleep_visualization.R:1265`

**论文用途** Results

**每部分是什么意思** 每个睡眠变量一个小提琴图 +
内嵌箱线图，**每个面板独立 Y 轴**。展示分布形状与离散程度。

**健康外观** TST 的小提琴大致对称；SOL 和 WASO
右偏（小值很多、大值很少）；没有哪个面板被孤立的尖峰主导。

**异常 →** 小提琴分成两瓣，说明混合了两种行为（比如工作日与周末，或 12
小时钟面习惯）；又宽又平，说明测量噪声大。

**精确规则**

- **画的是什么。**
  每个指标一把小提琴（睡眠时长、卧床时间、WASO、SOL、睡眠效率），里面有个小箱线，显示中位数和数据的中间一半。每个面板有自己的纵轴。
- **怎么读小提琴。**
  每个高度上的宽度，是有这个值的记录有多少；宽的地方记录多，窄的地方记录少。
- **箱线** 显示中位数（线）和中间 50%
  的值；离群点没有单独画，因为小提琴已经显示了两端的尾巴。

**常见问题**

小提琴和里面的箱线有什么区别？

小提琴显示整个分布的形状；里面的箱线给出两个可以一眼比较的数字：中位数和数据的中间一半。

有一把小提琴鼓出了两个包，这是什么意思？

有两种行为混在一起——比如工作日与周末，或 12 小时制与 24
小时制的填写混用。在相信单个汇总数字之前，先看图 R25 或解析步骤。

为什么上端或下端有一条又长又细的线？

少数极端记录拉长了范围。那条细线就是这些尾巴；值得到图 10 里看一看。

**论文图注**

> **Figure 05.** 每个睡眠变量的小提琴图叠加箱线图；每个面板使用自己的 y
> 轴刻度，因此面板之间比较的是分布形状，而非绝对数值。

#### 09 · 就寝 vs 起床时间分布

**文件** `research_ready/09_Bedtime_vs_Getup_Distribution.png` — 生成于
`sleep_visualization.R:1458`

**论文用途** Results

**每部分是什么意思**
按一天中的小时（0–24）画出的两条密度曲线：就寝时间分布 vs
起床时间分布（最终修正后的时间）。

**健康外观** 就寝时间的峰在 22:00–00:00 左右，起床时间的峰在 06:00–08:00
左右，两条曲线重叠很少——这是常见的昼夜规律。

**异常 →** 就寝峰出现在 02:00 之后，说明有睡眠时相延迟的人群，或 PM/AM
解码出错；起床峰出现在 04:00 之前，说明晚上的时间被解析成了早晨。

**精确规则**

- **画的是什么。**
  钟点（0–24）的两条平滑曲线：就寝时间（绿）和起床时间（橙），用的是修正后的时间戳。
- **首尾相接。** 横轴从 0 到 24
  小时，所以午夜前后的就寝时间被劈成两段：午夜之前的部分在右端，午夜之后的部分在左端。
- **包含哪些记录。** 同时有就寝时间和起床时间的记录。

**常见问题**

为什么就寝时间的曲线在图的两端都出现？

因为横轴是 0 到 24 小时的钟点。23:30 的就寝在右端，00:30
的就寝在左端，所以同一个夜间的峰被画成了两段。

就寝峰出现在凌晨意味着什么？

要么确实有睡眠时相延迟的一群人，要么是 AM/PM
解码错误把晚上的时间变成了早晨的时间。可以对照图 13B。

这和工作日/周末那张图一样吗？

不一样。这张图把所有天合在一起；图 R25 按工作日和周末拆开。

**论文图注**

> **Figure 09.**
> 就寝和起床时钟小时（修正后时间）在一天中的密度分布。峰值分离（傍晚就寝、清晨起床）是健康的昼夜节律信号。

#### 20 · SOL 感知偏差

**文件** `research_ready/20_SOL_Perception_Bias.png` — 生成于
`sleep_visualization.R:2637`

**论文用途** Results

**注意：** 这里衡量的是一个和 SOL 本身时长*不同*的量（快速检查卡里那个
10–45 分钟的范围）——这张图衡量的是两个独立 SOL 估计值之间的
*差距*，而不是 SOL 的时长本身。

**每部分是什么意思** 绝对偏差的直方图，图上标注为
`bias = |计算得到的 SOL − 自报 SOL|`（分钟）。两条参考线，各自标注了依据：**橙色虚线在
15 分钟**处 = 小的不一致（接近管线的 15
分钟窗口容差，`classification.metric_validation.sol.window_tolerance_minutes`）；
**红色虚线在 60 分钟**处 =
大的不一致——这是一条纯展示用的参考线，不是管线规则；超过它的情况值得人工看一眼。

**健康外观** 大部分集中在 0 附近，只有一小段尾巴，平均偏差在约 30
分钟以下：自报的入睡潜伏期和计算出来的基本一致。

**异常 →** 整体大幅偏移（均值远大于
0），说明参与者对自己入睡要多久的判断有偏差；出现两个峰，说明有一部分参与者用这个字段的方式不同。

**精确规则**

- **两个 SOL 值。** 客观 SOL
  由修正后的时间算出，`time_sleep_corrected − time_bed_corrected`，单位分钟。主观
  SOL 是参与者在 `duration_totalmin_sol_estimate_am`
  里报告的值。`bias = |客观 − 主观|`。
- **包含哪些记录。** 只有两个值都存在的记录。
- **视野。** x 轴显示 0–200 分钟，所以更大的差异没有画（R
  会给出被去掉的行的警告）。
- **两条虚线** 是读图参考：15 分钟接近管线的 15 分钟窗口容差；60
  分钟是显示参考，不是规则。

**常见问题**

差值大就是错误吗？

不一定。人们对自己用了多久入睡的估计并不精确，常常取整数（5、10、15、30
分钟），这就是直方图里有尖峰的原因。这个差距作为数据保留；60
分钟线只是标出值得看一眼、可能输入有误的情况。

为什么柱子这么尖？

自报值会集中在整数上。5 的倍数处的尖峰是取整的指纹，不是噪声。

有些差值没显示，是数据被藏起来了吗？

为了好读，x 轴到 200 分钟为止，更大的差值在图外。它们仍然在数据里；R
会用警告告诉你有多少行没有画进图里。

偏差是哪个方向的？

图上是绝对差，所以看不出是多报还是少报。要看方向，得用那两列自己算带符号的差。

**论文图注**

> **Figure 20.** 客观 SOL（由修正后的就寝与入睡时间戳推导）与主观
> SOL（参与者自报的入睡潜伏期）之间绝对差值（分钟）的直方图。

#### 20B · WASO 感知偏差

**文件** `research_ready/20B_WASO_Perception_Bias.png` — 生成于
`sleep_visualization.R:2695`

**论文用途** Results

**每部分是什么意思**
两个不同量之间绝对差的直方图：自报的夜间清醒时间（WASO），和日记里显示的最终醒来到起床之间的时间（`getup − awake`）。图的
caption 印着 `bias = |computed − self-reported|`（分钟），参考线和图 20
一样，在 15 和 60 分钟。

**健康外观** 大部分集中在 0
附近，只有一小段尾巴。因为这两个量是不同的时间窗口，这主要说明夜间清醒和醒后赖床之间差多少，而不是人们报告得有多准。

**异常 →**
尾巴很长，说明很多参与者的夜间清醒时间和醒后赖床时间差距很大。这有信息量，不是错误；只有怀疑填写有问题时，才去查
WASO 时长的修正。

**精确规则**

- **这两个值不是同一件事。** 这里的客观值是
  `time_getup_corrected − time_awake_corrected`，单位分钟——最终醒来之后在床上待的时间。主观值是参与者报告的夜间清醒时间（`duration_totalmin_waso_estimate_am`，以”时:分”格式写的才会读取）。
- **所以这个差距不是单纯的报告误差。**
  两个数字覆盖的是不同的时间窗口；图的副标题写明了这一点。这种不一致是有信息量的，不是需要修的东西。
- **构造和图 20 相同。** `bias = |客观 − 主观|`，取两个值都存在的记录，x
  轴 0–200 分钟，虚线参考在 15 和 60 分钟。

**常见问题**

为什么要比较两个不同的东西？

管线没有夜间清醒的另一种直接度量，所以能用时间戳得到的最接近的量，是最终醒来到起床之间的时间。图里明确写了窗口不同；它是一致性检查，不是验证。

这里差距大，说明日记有错吗？

不。一个人夜里可能长时间醒着，但起床很快；也可能只醒一次却赖床很久。两种情况差距都会很大，而两个数字都没有错。

为什么用的记录比图 20 少？

只有自报 WASO 写成”时:分”格式的行才能被读取，所以有些行会被丢掉。

**论文图注**

> **Figure 20B.**
> 计算得到的睡后觉醒与参与者自报的夜间觉醒之间绝对差值（分钟）的直方图。

#### 21 · 物质使用数据可得性

**文件** `research_ready/21_Substance_Use_Availability.png` — 生成于
`sleep_visualization.R:2767`

**论文用途** Supplement

**每部分是什么意思**
柱状图：每种物质（咖啡因、酒精、尼古丁、大麻）有数据的记录百分比。

**健康外观** 你的研究询问过的物质可得性高（约 80%
以上）；其他物质可得性低是预期的跳过模式（没问，或没回答）。

**异常 →** 你确实测量过的物质可得性接近零，指向列映射或数据采集的问题。

**精确规则**

- **每根柱子是什么。**
  有这种物质数值的日记行占全部日记行的百分比（咖啡因、酒精、尼古丁、大麻）。标签给出数量、百分比和报告值的范围。
- **分母是所有的行，**
  包括根本没有物质条目的天数，所以对只在部分天数、或只在晚上的调查里才问的项目，百分比会很低。
- **单位。** 咖啡因是杯，酒精是标准杯，尼古丁和大麻是剂量。

**常见问题**

为什么咖啡因只有约 11%？参与者肯定都喝咖啡。

百分比以全部日记行为分母，而只有回答了物质问题的行才有数值。所以低百分比通常反映的是这个问题被问或被答的频率，而不是人们摄入这种物质的频率。

有一种物质是 0%，是错误吗？

意思是那一列没有任何一行有值。如果你的研究没有问这一项，这是预期的；如果问了，就要怀疑列映射或数据导出。

标签里的范围能告诉我什么？

报告值的最小和最大。最大值特别大，提示单位弄混了；见图 22–24。

**论文图注**

> **Figure 21.**
> 每种物质（咖啡因、酒精、尼古丁、大麻）含有数据的记录百分比，展示每个物质域被报告的完整程度。

#### 22 · 物质使用数值分布

**文件** `research_ready/22_Substance_Use_Distribution.png` — 生成于
`sleep_visualization.R:2870`

**论文用途** Supplement

**每部分是什么意思** 箱线图（箱体 = 中间 50% 的报告；箱内线 =
中位数）叠加**灰色点**——每个点 =
一位参与者的一次报告，横向抖动，避免相同数值堆成一个点。

**健康外观** 箱子很紧凑，数值合理（咖啡因 0–4 杯，酒精 0–3
杯），离群点很少。

**异常 →**
极端离群点通常是单位问题（杯与份），并会触发数量标记；箱子很宽，说明用量不规范。

**精确规则**

- **画的是什么。**
  每种有数据的物质一个箱子：箱子是报告的中间一半，里面的线是中位数，灰色圆点是单独的报告，横向散开，让相同的值不会叠成一个点。
- **哪些物质。** 只有至少有一个值的；没有数据的物质不画。
- **单位。** 咖啡因是杯，酒精是标准杯；尼古丁和大麻是剂量。
- **极端值** 会触发 Step 8 的数量标记。

**常见问题**

为什么箱子这么扁？

当大多数人报告的都是同样的几个值（比如 1 或 2
杯）时，数据的中间一半就很窄。箱子扁说明大多数报告是一致的。

为什么灰色圆点排成一行一行的？

报告是整数或整齐的数，所以很多点的高度相同。横向的散开只是让它们不至于正好叠在一起。

有一个点远高于其他点，是错误吗？

它是候选。很大的值往往意味着单位弄混了（杯与份），会触发数量标记，但也可能真是个重度日。去看那条记录。

**论文图注**

> **Figure 22.** 每种物质报告值的箱线图叠加抖动点。单位：咖啡因 =
> 杯，酒精 = 标准杯，尼古丁和大麻 = 剂。

#### 23 · 咖啡因摄入

**文件** `research_ready/23_Caffeine_Consumption.png` — 生成于
`sleep_visualization.R:2944`

**论文用途** Supplement

**每部分是什么意思** 柱状图，**每个不同的报告值一根柱子**（0、1/3、1/2、
1、1 1/2……杯/天——离散 x 轴，柱子从不重叠），柱顶标注计数 +
百分比。小数回答（半杯等）原样保留，并标成分数；副标题里也写明了这一点。只有一条记录的小数值（比如
0.3）柱子很矮，但它的计数标签照样会印出来。

**健康外观** 右偏，多数报告在 0–1 杯——少数重度日，多数轻度日。

**异常 →** 在不合理的数值处（10
杯或以上）出现尖峰，通常是单位混淆（罐与杯），并会触发 `AMOUNT_FLAG`。

**精确规则**

- **每个不同的报告值一根柱子，**
  不分箱，在离散轴上按数值顺序排列，所以每个值都有自己的柱子，柱子不会重叠。小数回答（比如半杯）保留自己的柱子，并标成分数。
- **单位和列。** 每天杯数，来自
  `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1`。
- **标签。** 每根柱子显示它的数量和占非缺失报告的比例。
- **极端值**（比如 10 或以上）会触发 Step 8 的
  `AMOUNT_FLAG`，往往意味着单位弄混了（杯、罐或份）。

**常见问题**

为什么坐标轴上有 1/2、1 1/2 和 0.3？

因为有人用分数回答，这张图保留了每一个报告值。半杯和一杯半标成分数；其他值按数据里写的显示（比如
0.3）。

某个小数值的柱子非常矮，它消失了吗？

没有。只有一条或几条记录报告的值，柱子会很矮，但它的数量仍然印在上面。

为什么最常见的值是 1 杯而不是 0？

只统计有报告的日子，而大多数报告是 1 或 2 杯。没有人回答的日子不是
0，而是缺失。

什么算可疑的值？

任何特别大的，比如 10
杯或以上。通常是把罐或份当成杯填进去了；这样的记录会得到数量标记。

**论文图注**

> **Figure 23.** 按自报咖啡因摄入量（杯/天）分组的记录计数。右偏、众数在
> 0–1 杯是预期的；在不合理值处出现尖峰表示单位混淆。

#### 24 · 酒精摄入

**文件** `research_ready/24_Alcohol_Consumption.png` — 生成于
`sleep_visualization.R:2979`

**论文用途** Supplement

**每部分是什么意思** 柱状图，每个不同的报告值（杯/天）一根柱子，和图 23
相同的离散画法；小数回答（例如 1 1/4 杯）原样保留并标成分数。

**健康外观** 右偏，多数报告集中在最低的几个数上。

**异常 →** 高数值处出现尖峰，和咖啡因一样有单位问题；请核对
`alcoholtoday_PM` 的编码。

**精确规则**

- **构造和图 23 相同。**
  离散轴上每个不同的报告值一根柱子，按数值顺序；小数回答保留并标成分数。
- **单位和列。** 每天标准杯数，来自
  `alcoholtoday_PM_NumAlcoholicDrinks_1`。
- **标签。** 每根柱子显示它的数量和占非缺失报告的比例。
- **高值** 会触发 Step 8 的
  `AMOUNT_FLAG`；把它们当作真实的饮酒量之前，先核对这一列的编码。

**常见问题**

为什么没有 0 杯的柱子？

如果 0 处没有柱子，说明没有任何记录报告了 0
杯。没有回答的日子是缺失，不是 0，这张图分不出没喝酒的日子和缺失的日子。

为什么第一根柱子比其他的高这么多？

大多数报告是最小的量（一杯）。分布是右偏的：很多轻度日，少数重度日。

什么是标准杯？

一个固定的酒精量，作为单位，让啤酒、葡萄酒和烈酒可以比较。如果参与者回答的是没有这个定义的”杯”，大数值要谨慎对待。

**论文图注**

> **Figure 24.** 按自报酒精摄入量（标准杯/天）分组的记录计数。

#### R25 · 睡眠规律性——工作日 vs 周末

**文件** `research_ready/R25_Sleep_Regularity_Weekday_Weekend.png` —
生成于 `sleep_visualization.R:3043`

**论文用途** Results

**每部分是什么意思** 两个并排面板——**左 = 就寝时间，右 =
起床时间**（顶部粗体标签）——各自是按日型（工作日/周末，颜色区分）拆分的时钟小时小提琴图 +
箱线图。

**使用的列** 就寝时间 = `time_bed_corrected`（校正后的”上床”时间戳，即
`time_bed`）；起床时间 =
`time_getup_corrected`（校正后的”离床”时间戳，即
`time_getup`）。两者都是流水线生成的列，不是原始日记列。就寝时刻早于中午的小时数会
+24，所以 y 值大于 24 表示过了午夜（如 26 = 02:00）。

**健康外观** 周末的就寝时间比工作日晚约 0.5–1 小时，起床晚约 1
小时，其余形状相似——这是典型的、幅度不大的周末偏移。

**异常 →** 工作日和周末的分布完全一样，说明 `day_type`
分错了，或日期被丢掉了；周末偏移特别大，则是社交时差，值得作为一个发现来报告。

**精确规则**

- **用的是哪些列。** 就寝时间来自 `time_bed_corrected`，起床时间来自
  `time_getup_corrected`。两者都是管线生成的修正后时间戳，不是原始日记列。
- **工作日还是周末。**
  按就寝时间戳所在的日历日判断：周六、周日是”Weekend”，周一到周五是”Weekday”。午夜之后的就寝时间带的是第二天的日期。
- **大于 24 的小时数。** 中午之前的就寝小时数会加 24，所以 y 值大于 24
  表示过了午夜（26 = 02:00）。
- **画的是什么。**
  每种日型一把小提琴加一个箱线，分别画就寝时间和起床时间；黑点是中位数。

**常见问题**

凌晨 02:00 的就寝算哪一天？

算就寝时间戳上的那一天。经过管线对午夜的处理，周日凌晨 02:00
的就寝带的是周日的日期，所以算周末的夜晚；周五夜里 01:00 算周六。

周五晚上算周末的夜晚吗？

只有就寝时间过了午夜才算，因为那时带的是周六的日期。周五 23:30
就寝算工作日。这直接来自上面的规则，和其他研究比较时值得记住。

为什么 y 值会超过 24？

这样刚过午夜的就寝时间（比如 01:00）就紧挨着
23:00，而不是跑到坐标轴的最下面。25 表示 01:00。

周末偏移多大算正常？

一个小的偏移——周末晚最多约一小时——是常见的模式。大得多的偏移是社交时差，值得作为一个发现报告。

**论文图注**

> **Figure R25.**
> 就寝和起床时钟小时的小提琴图叠加箱线图，按日型拆分（工作日：周一至周五；周末：周六至周日，由修正后的就寝日期派生）。一个适度（≤
> 1 小时）的周末延迟是预期的；较大的偏移表示社交时差。

#### R26 · 睡眠构成——TIB 拆分

**文件** `research_ready/R26_Sleep_Composition_TIB_Breakdown.png` —
生成于 `sleep_visualization.R:3096`

**论文用途** Results

**每部分是什么意思**
卧床时间构成的堆叠柱状图；图的副标题给出了每个缩写的定义：TIB =
TST（总睡眠时间——真正睡着的部分）+ SOL（入睡潜伏期——入睡过程）+
WASO（睡后觉醒——夜间醒着的部分），以占比形式呈现。

**健康外观** TST 是最大的一块（约占卧床时间的 80–90%），SOL 和 WASO
是很小的两段。

**异常 →** SOL 或 WASO 占卧床时间超过
30%，说明睡眠严重碎片化或入睡特别慢；如果出现负的余量，则是时长计算的
bug。

**精确规则**

- **这根条是什么。**
  卧床时间里三个部分各占的平均份额：总睡眠时间（TST）、入睡潜伏期（SOL）和睡后觉醒（WASO）。对每条记录，三部分除以它们的和，再把这些份额在记录之间取平均。
- **恒等式。**
  `TIB = TST + SOL + WASO`，所以三段正好填满整根条，没有余量；任何极小的缝隙都是舍入。
- **包含哪些记录。** 三个值都有、且 TST 大于 0
  的记录；副标题给出了数量。

**常见问题**

这是汇总分钟数的平均，还是每条记录份额的平均？

每条记录份额的平均：每条记录权重相同，不管它多长。汇总版本（所有记录每部分的总分钟数）会让更长的夜晚权重更大，结果可能略有不同。

为什么 SOL 和 WASO 这么小？

多数夜晚里，入睡和夜醒只占卧床时间的一小部分，所以 TST 占主导。SOL 或
WASO 那段很大，说明那些记录睡眠碎片化或入睡很慢。

为什么用一根条而不是饼图？

一根条便于把各段并排比较，小的段也读得清楚，而饼图会把小块挤在一起。

**论文图注**

> **Figure R26.**
> 将卧床时间（TIB）拆分为其组成部分的堆叠柱状图：总睡眠时间（TST）、入睡潜伏期（SOL）、睡后觉醒（WASO），构造上
> TIB = TST + SOL + WASO。健康构成中 TST 占 TIB 的 80–90%。

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

**健康外观** 符号符合生理：TST 与 SE 强正相关，SOL 与 SE 负相关，TST 与
TIB 正相关，WASO 与 SE 负相关。

**异常 →** 符号反了（比如 TST 与 SE
为负），说明某个指标的定义被改了或单位混了；两个并非互相推算出来的指标相关系数几乎正好是
±1，说明它们其实是同一列。（WASO 与 SE 强负相关是构造使然，因为 SE 是用
WASO 算出来的。）

**精确规则**

- **每个格子是什么。** TST、SOL、WASO、SE、TIB 中两个指标的 Pearson
  相关系数，在五个值都齐全的记录上计算；副标题给出了记录数。
- **颜色。** 红色是负，绿色是正，越接近 −1 或 +1
  颜色越深。只显示上三角；对角线永远是 1。
- **定义上的联系。**
  有些指标对在定义上就联系在一起：`SE = TST / TIB`、`TIB = TST + SOL + WASO`，所以它们的相关性有一部分是构造出来的。

**常见问题**

为什么 TST 和 SE 的相关性这么高？

SE 是由 TST 定义出来的（SE = TST /
TIB），所以它们共享信息。把定义上相连的指标之间的高相关，当作数字前后一致的确认，而不是新发现。

WASO 和 SE 几乎是 −1，这可疑吗？

不可疑。SE 是用 WASO
算出来的，所以很强的负相关是构造出来的。只有两个并非互相推算出来的指标之间出现接近
±1，才可疑。

符号和我预期的相反，说明什么？

某个指标的定义被改了，或者单位混了（比如分钟和小时）。在解读这张图之前，先检查喂给那个指标的列。

相关性能说明因果吗？

不能。它只说明这些记录里两个指标是一起变化的。说不出为什么，而且它只在五个值都齐全的记录上计算。

**论文图注**

> **Figure R27.** 最终修正后数据上 TST、SOL、WASO、SE、TIB 两两 Pearson
> 相关系数的上三角相关图（红 = 负，绿 =
> 正，每格标注系数）。预期符号：TST–SE 正相关，SOL–SE 负相关，TST–TIB
> 正相关，WASO–SE 负相关。
