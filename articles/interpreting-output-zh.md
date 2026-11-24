# 读懂输出与审核循环（中文）

[English
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/interpreting-output.md)
· [图表 F01-F37
→](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference-zh.md)

[`run_pipeline()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/run_pipeline.md)
跑完后，两个 CSV
文件告诉你一切。本文说明怎么读它们、怎么把人工审查循环跑到收敛，以及怎么对比上一次运行做回归检查。

图表另有一页：**[逐图参考](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference-zh.md)**
讲每张图是什么意思、落在哪个文件夹、论文该放哪张。下文小节号（§1–§7）指本页；写”逐图参考
§N”的就是另一页。

目录

- [术语与定义](#s-terms)
  - [睡眠指标](#s-terms-1)
  - [记录分类：`data_category`](#s-terms-2)
  - [指标标记：`flag_severity`](#s-terms-3)
  - [“标准”（standard）](#s-terms-4)
- [1. 运行管线](#s-1)
- [2. 人工输入文件](#s-2)
  - [2.1 样例与模板文件](#s-2-1)
  - [2.2 管线写到项目根目录的文件](#s-2-2)
- [3. 人工审查循环（人话版）](#s-3)
- [4. `output/correction_status_final.csv` — 运行摘要（先看这个）](#s-4)
- [5. `output/step_flag_ledger.csv` — 每步标记追踪（第二个看）](#s-5)
  - [5.1 列布局](#s-5-1)
- [6. 回归检查（对比上次运行）](#s-6)
- [7. 快速检查卡](#s-7)
- [图表 F01-F37 —
  单独一页](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference-zh.md)

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

| 优先级 | 类别 | 判定标准 | 怎么处理 |
|:--:|----|----|----|
| 1 | `skipped_na` | 四个修正后时间戳（bed、sleep、awake、getup）中有任何一个缺失 | 排除在顺序检查之外 |
| 2 | `error` | 顺序被破坏（不满足 `bed ≤ sleep ≤ awake ≤ getup`）；或 `sleep = awake`（零时长睡眠）；或 bed→sleep、awake→getup 的间隔超过 7 小时；或 sleep→awake 跨度超过 24 小时 | 一定会被审查，确认后修正 |
| 3 | `equal_time_ok` | 顺序完整，且 bed = sleep 和/或 awake = getup（差值小于 0.01 小时，约 36 秒） | 算有效记录，不进入人工审查 |
| 4 | `unusual` | 顺序完整、不是 equal-time，但 bed→sleep 或 awake→getup 有一段间隔超过 3 小时 | 会被审查，通常原样保留 |
| 5 | `clean` | 以上都不是 | 无需处理 |
| — | `reasonable_unusual` | 经人工看过并接受的 `unusual` 记录 | 单独计数，不丢掉人工的判断 |

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

| 参数 | 作用 |
|----|----|
| `config` | 你的配置 YAML 路径（复制 `inst/config_template.yaml`，改 `data` 部分）。 |
| `include_manual_corrections` | **默认 `FALSE`。** 为 `FALSE` 时只跑算法：所有人工审查 CSV 都当作不存在，并有横幅提示没有应用人工修正。设为 `TRUE` 才会应用配置里指定的人工修正文件。默认关闭，是为了让数据集永远不会被工作目录里遗留的审查文件悄悄改掉。 |
| `skip_visualization` | 设为 `TRUE` 跳过出图（Step 9 和 Step 11）。 |
| `finalize` | 默认 `TRUE`：写出交付数据集（Step 10）。设为 `FALSE` 则清洗完就停。 |

**在配置里写明数据是什么：`data.tag`。** `real`（被试真实数据，图写进
`output/`，不会上传 GitHub）或 `synth`（合成或测试数据，图写在 `output/`
外面）。管线从不猜测。没写、而这次运行要出图时：交互运行会在一开始问一次（`r`
/ `s` / `n`
停止），只对这一次运行有效；非交互运行（`Rscript`、CI、编译文档）会报错停止，并说明要加什么。`skip_visualization = TRUE`
的运行不需要它。`RUN_INFO.txt` 和 `output/review_runs.csv`
会记录标记，以及它来自配置还是来自询问。

**`include_manual_corrections` 是函数参数，不是 YAML 设置。**
写进配置文件不会生效，必须写在调用里。YAML
只说明每个人工审查文件**在哪里**（`data.files.manual_error`
等）。由此两点：

- **如果运行时对小睡/运动、睡眠指标时长、指标接受这三步打印
  `No corrections file found () — skipping`**，括号里是空的，表示路径是被**有意清空**的：这次是只跑算法（`include_manual_corrections = FALSE`，即默认值），不是文件缺失或拼错。要应用它们，用
  `include_manual_corrections = TRUE` 重跑。
- **默认值在 1.4.7 版改变了。**
  更早的版本不需要询问就会应用配置里的人工文件。升级后，同样的
  `run_pipeline(config = "my_study.yaml")`
  不再应用它们。要复现更早的完整运行，请加上
  `include_manual_corrections = TRUE`。

两种模式下 Step 5 都会写出 `[NEW]` 审核表。

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

| CSV（配置键） | 在何处被使用 | 为什么存在 | 由谁创建 |
|----|----|----|----|
| `second_review_checklist.csv` | Step 4.75（`apply_second_review`） | 在应用修正之前，锁定此前已审查记录的二次审查共识 | 手动起草；`apply_second_review` 追加已路由的行 |
| `manual_error_corrections.csv` | Step 6（`step_apply_corrections`） | 对分类为 `error` 的记录的人工修正决定 | Step 5 写出 `[NEW]manual_error_correction_review.csv`；审查者填写 `new_value_*` 后另存为此名 |
| `manual_unusual_corrections.csv` | Step 6（`step_apply_corrections`） | 对分类为 `unusual` 的记录的人工决定 | Step 5 写出 `[NEW]manual_unusual_review.csv`；同样的审查填写流程 |
| `manual_nap_exercise_corrections.csv` | Step 6.5（`apply_nap_exercise_corrections`） | 对小睡与运动时长的修正 | 手动创建；`apply_second_review` 可能追加 |
| `manual_sleep_metric_duration_corrections.csv` | Step 6.5（`apply_sleep_metric_duration_corrections`） | 修正派生睡眠时长里剩余的内部不一致 | 手动创建 |
| `manual_metric_review_acceptances.csv` | Step 6.5（`apply_metric_review_acceptances`） | 对计算出的睡眠指标（TST、SOL、WASO、SE）的人工接受/拒绝决定 | 手动创建；`apply_second_review` 可能追加 |
| `audit_dispositions.csv` | Step 9 之后（`audit_data_integrity`） | 记录每条被改动记录处置结果的审计账本，用于可回溯性 | 由管线自身写出 |

**审计账本路径：** 私有审计账本为可选项，在配置中以
`data.files.audit_dispositions`
指定（默认为空：不启用，`audit_disposition` 全部为
`"none"`）。若指定的文件不存在，运行会报错停止，而不是静默写入
`"none"`。与人工修正文件的一致性检查使用本次运行实际采用的
`data.files.manual_metric_duration`。

**格式：** 每个文件都是纯 CSV；error/unusual 文件包含
`pid, day_num, row_id, variable, old_value_hhmm, old_value_ampm, new_value_hhmm, new_value_ampm, correction_type, confidence, reviewer_notes`（Step
5 写出的 `[NEW]` 审查文件已经预填了诊断信息—— 只需填写 `new_value_*` 和
`reviewer_notes` 列）。列模板在
`templates/template_*.csv`；`inst/extdata/stub_*.csv`
作为仅含表头的格式示例（无真实数据）随包发布。

### 2.1 样例与模板文件

不必从空白文件开始，包里提供了模板和虚拟样例数据：

| 是什么 | 在哪里 | 说明 |
|----|----|----|
| 六个审查 CSV 的仅表头模板 | `inst/extdata/stub_*.csv`（随包安装） | `stub_error_corrections.csv`、`stub_unusual_corrections.csv`、`stub_nap_exercise.csv`、`stub_metric_duration.csv`、`stub_metric_accept.csv`、`stub_second_review.csv`——列正确，没有数据行，也没有真实数据 |
| 审计处置模板 | `inst/extdata/template_audit_dispositions.csv` | 仅表头 |
| 填好示例行的模板 | GitHub 仓库里的 `templates/template_*.csv` | 虚构的示例行（例如 1001 号参与者）；**不**随安装包发布 |
| 虚拟样例数据集 | `inst/extdata/synthetic_sleep_data.rds` 和 `synthetic_ema_data.csv` | 280 行虚拟日记，没有真实参与者 |
| 虚拟数据集的配置 | `inst/extdata/synthetic_config.yaml` | 演示怎么为一份新数据映射列名 |
| 列字典 | `inst/extdata/column_dictionary.csv` | 说明交付数据里每一列的含义 |

在 R 里找到已安装的文件：

``` r
system.file("extdata", "stub_error_corrections.csv", package = "sleepcleanr")
```

把模板复制到工作目录，改成配置里期望的文件名，再填写。

### 2.2 流水线写到项目根目录的文件

除了 `output/`，一次运行还会在**项目根目录**（你传给 `project_dir`
的目录）写出若干工作文件。它们是审查循环的中间文件，不是最终结果。全部包含真实参与者行，不要提交。

| 文件 | 何时写出 | 是什么 | 怎么用 |
|----|----|----|----|
| `[NEW]manual_error_correction_review.csv` | Step 5 写出，**Step 8.5 之后重写** | 一张状态表：Step 5 的每条 `error` 记录（与 `error_df_pre` 同一批行），加上修正之后才变成错误的记录。每行说明发生了什么（`status_after_corrections`）、是否在人工文件里（`in_manual_file`）、修正前后的类别，以及 Step 8 的标记。仍需人处理的行排在最前。审核列为空 | 读 `status_after_corrections`；处理 `..._still_fails` 和 `new_after_corrections` 的行 |
| `[NEW]manual_unusual_review.csv` | Step 5 | 同上，针对 `unusual` 记录 | 填写后另存为 `manual_unusual_corrections.csv` |
| `review_status.csv` | Step 8.5 之后，每次运行覆盖 | **只需要看这一张表。** 两张 Step 5 待审表的每一行，加上修正之后才变成错误的记录；每行有一个 `review_state`（`needs_review`、`not_incorporated`、`incorporated`）和判定它的规则（`review_state_reason`）。`needs_review` 排在最前 | 处理 `needs_review` 的行；运行结束时会按你的规则打印审查是否完成 |
| `manual_error_correction_updated.csv` | Step 6 | 已应用修正的记录：**你填的** `manual_error_corrections.csv` 被流水线纳入之后的副本，`manually_corrected` 列标明哪些行真的被用上了。你自己的文件不会被改动，这是流水线的副本 | 与你的输入对照。你填了但没标 `TRUE` 的行就是没生效，要查原因。它是记录，不是新的待办清单 |
| `reasonable_unusual_records.csv` | Step 6 | 你标为”reasonable unusual record”（异常但合理，保持原样）的 `unusual` 行 | 留档：哪些被接受了 |
| `cross_participant_flagged_rows.csv` | Step 8.5 | SOL 或 WASO 明显偏离**此人自己**中位数的日子（例如多数天 5–30 分钟，某天 400 分钟） | 当作可能的录入错误来审 |
| `cross_participant_suspicious_slices.csv` | Step 8.5 | 上一个文件中那些参与者的全部天数 | 看上下文：这一天是偶发，还是此人的一贯模式 |
| `cross_participant_field_misentries.csv` | Step 8.5 | SOL 或 WASO 的数字像是填进了别的时间栏的行 | 当作可能的栏位填错来审 |

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

下面的小时数是默认值。每一个都可以在配置的 `classification.step5`
下修改（见[输入数据与配置](https://cyracaid.github.io/sleepdiary-cleaner/articles/column-mapping-zh.md)）；每次运行都会打印它实际用的值，并保存在
`output/effective_rules.csv` 里。 这些默认值的来历：Step 5
的限制记录在项目 2026 年 3 月的逻辑文档里，代码从第一次发布（2026 年 7
月）起一直使用同样的数值，直到它们变成配置项。要复现研究的结果，保留默认值。所有阈值及其依据见[Thresholds](https://cyracaid.github.io/sleepdiary-cleaner/THRESHOLDS.html)页。

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

| 列组 | 列 | 含义 |
|----|----|----|
| 身份 | `pid`, `day_num`, `row_id` | 哪个参与者、哪一天、哪一行 |
| 原始录入 | `time_bed/sleep/awake/getup_am_hhmm_ampm` | 参与者原样填写的内容（未改动） |
| 解析后时间 | `time_bed/sleep/awake/getup_corrected` | 管线目前最好的猜测 |
| 差值 | `bed_sleep_diff_h`, `sleep_awake_diff_h`, `awake_getup_diff_h`, `reasonable_temporal_order` | 上面那些规则据以触发的数字 |
| 机器判定 | `error_type`, `corrected`, `correction_type` | 哪条规则触发了；算法是否已经修正 |
| **人工填写** | `problem_humanidentified`, `solution_humanidentified`, `column_to_correct`, `correct_value`, `manually_corrected` | 空白列——写清楚哪一列错了、正确值是什么、你是否已经修正 |
| **状态**（修正之后添加） | `source`, `status_after_corrections`, `category_before_corrections`, `category_after_corrections`, `step8_flags_after_corrections` | 这一行从哪来、之后发生了什么（见下）。Step 8 标记单独报告，不改变状态 |
| **在哪里处理过**（管线添加） | `in_manual_file`, `review_resolution`, `resolved_at`, `resolved_by` | 从你的人工文件里对应的那一行带过来。四列全空表示这条记录还没人处理过 |

**怎么读这张状态表。** Step 5
先写出规则在*修正之前*的数据上标记的所有记录。Step 6–8.5 之后，管线把
`[NEW]manual_error_correction_review.csv`
重写成一张不丢任何行的表。`status_after_corrections` 取值：

| `status_after_corrections` | 含义 |
|----|----|
| `not_in_manual_file_still_fails` | 不在任何人工文件，修正之后仍不干净——要做 |
| `in_manual_file_still_fails` | 在人工文件里，但仍不干净——那次修正没有奏效 |
| `new_after_corrections` | 不在 Step 5 清单里，修正之后才变成错误 |
| `not_in_manual_file_now_passes` | 不在人工文件；规则已经修好 |
| `in_manual_file_now_passes` | 在人工文件里，现在干净 |

“干净”指最终类别是 `clean`、`equal_time_ok` 或
`reasonable_unusual`。管线只报告，不替你决定一行什么时候算做完。`step8_flags_after_corrections`
显示这一行上的 Step 8 标记（例如 SOL
过长），算不算问题由你判断。行的排列让仍需人处理的排在最前，每次运行顺序相同。`in_manual_file`、`review_resolution`、`resolved_at`、`resolved_by`
四列仍然说明一行在哪里处理过：

| 看到的情况 | 含义 |
|----|----|
| 四列全空 | 从没处理过——要做的 |
| `corrected` 加 `resolved_by` | 已处理并有记录 |
| `resolution_unknown_legacy` / `legacy` | 处理过，但没人记录是谁、什么时候（可以补上） |
| `flagged_unresolved`，或 `resolved_by` 为 `pending` | 等待确认 |

每次运行结束时，管线会打印每张待审表里各状态的行数，以及有多少条**已处理的行在自动复查之后仍然有问题**（仍是
error，或仍被标记）。改过的记录仍可能通不过复查，所以最后这个数很重要。什么时候算审查完成，由**你**在配置里写的规则决定，不由管线决定（见下面“审查状态与完成规则”）。在真实研究数据上，最终产出了
75 条 error + 37 条 unusual 的人工确认修正（见 Methods 部分 Stage 5）。

**审查状态与完成规则。**
`review_status.csv`（项目根目录）把*两张*待审表的每一行，加上修正之后才变成错误的记录，都归入且只归入一个
`review_state`。每行归入哪个状态，只由下表的规则和你配置里的 `review:`
块决定；管线只执行这些规则，运行中从不修改它们。

| `review_state` | 规则（按顺序，第一条成立的生效） |
|----|----|
| `needs_review` | 修正之后才变成错误；或在人工文件里标为待确认（`flagged_unresolved` / `resolved_by` = `pending`）；或复查仍不通过；或修正后仍缺某个时间、无法复查顺序（若它在人工文件里且 `review.missing_times_ok_after_manual: true`，则算 `incorporated`）；或——仅当 `review.step8_flags_need_review: true` 时——带有 Step 8 标记 |
| `incorporated` | 本次运行应用了针对它的人工决定，且复查通过 |
| `not_incorporated` | 本次运行没有人工决定改动它，且复查通过（规则修好了它，或本次没有应用人工修正） |

`review_state_reason` 写明每行用的是哪条规则。当 `needs_review`
的行数不超过 `review.done_when.max_needs_review`（默认
`0`）时，审查**完成**。每次运行都会打印结论；[`review_verdict()`](https://cyracaid.github.io/sleepdiary-cleaner/reference/review_verdict.md)
返回同一结论；设 `review.fail_if_not_done: true`
时，若未完成，管线会在写完全部输出后报错停止（适合
CI）。纯算法运行里不可能有 `incorporated`，打印结果会说明这一点。

每次运行还会在 `output/review_runs.csv`
里追加一行（所有运行共用一个文件，不会每次新建文件）：数据、人工文件和配置的内容哈希，`review_status.csv`
的哈希，三类计数和结论。删除并重建环境之后，比较最后两行就知道输入或结果有没有变；运行时也会打印这项比较。`Rscript validation/reproducibility.R`
会检查同一输入在新目录、新 R 进程里是否得到完全相同的输出。

**已验证数字的来源（历史记录，1.6.x 时代）：**
一次受控重跑（2026-09-29）精确量化了人工修正对最终数据集的影响：不含人工修正时，1,719
条记录有可计算的总睡眠时间，61 条仍留在 `error` 类；含人工修正时，1,729
条记录有效（净增 10），85 条记录带有人工修正，只有 3 条仍是 error。11
条被 “解锁”的记录原本是 `error` 类，修正后的时间戳让 TST
首次可以计算（293–590 分钟）；一条极端记录（TST = 10
分钟）在修正后被正确地退出了有效集合。

**1.7.1 当前口径**（2026-10-29 双人确认）：交付 error 为 **0**——评审写过
undo+重施指令的 3
条记录（2854/13、6985/7、6985/12）在引擎完整执行指令后时序全部修复；review
loop 收敛（Review DONE：100/100 incorporated，0 needs_review）；人工修正
85 条；46
条歧义自报时长带标志与原文交付（`sol/waso_selfreport_ambiguous/raw`，见
output-files 的问答表）。

## 4. `output/correction_status_final.csv` — 运行摘要（先看这个）

每次运行一行。回答”清洗是否按预期工作？”

``` r
read.csv("output/correction_status_final.csv")
```

| 列 | 它告诉你… | 检查这个 |
|----|----|----|
| `n_total` | 总记录数 | 必须等于输入行数。若更小，某处丢了记录。 |
| `run_id`、`timestamp` | 运行时间（`YYYYMMDD_HHMM` 与完整时间） | 每次运行追加一行，用它们区分各次运行。 |
| `checkpoint_first`、`checkpoint_last` | 下面 `*_first`、`*_last` 取自哪两个检查点（见表后说明） | 通常是 `A` 和 `E`。 |
| `tst_mean_h` | 平均总睡眠时间（小时） | 大多数成人研究 6.0–8.5 h 正常。若 \< 5 或 \> 10，时间戳解析或研究人群异常。 |
| `sol_mean_min` | 平均入睡潜伏期（分钟） | 10–45 min 正常。若 \> 60，人群失眠率高或 AM/PM 混淆未完全修正。 |
| `n_clean_first`、`n_clean_last`、`delta_clean` | 第一个和最后一个检查点上通过所有检查的记录数；`delta_clean = n_clean_last - n_clean_first` | `n_clean_last` 同数据多次运行应相同。`delta_clean` \> 0 表示清洗让更多记录变干净。 |
| `n_error_first`、`n_error_last`、`delta_error` | 第一个和最后一个检查点上时序不可能的记录数（如 getup 早于 bed）；`delta_error = n_error_last - n_error_first` | 看 `n_error_last`（清洗后剩余）：应 \< 总记录 1%，若 \> 5% 审查问卷设计。`n_error_first` 是清洗前，本来就偏高。`delta_error` \< 0 表示错误被消除。 |
| `n_corrected` | 经 CSV 人工修正的记录 | 应与 `manual_error_corrections.csv` 行数一致。 |
| `timestamp_issue` | 无法解析为有效时间的时间戳 | 0 正常。\> 0 表示参与者填了非标准时间格式。 |
| `duration_issue` | 超出配置阈值的睡眠指标 | 少量正常。若很大，阈值太严或数据质量有问题。 |
| `amount_flag` | 异常物质使用条目 | 应为 0 或很低。 |
| `self_reported_flag` | 自报 SOL/WASO 与计算值分歧的记录 | 指示感知偏差。看图 F29（SOL 感知偏差），见[逐图参考](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference-zh.md)。 |

**`first` 和 `last` 指什么。**
两者都是**同一次运行内**的快照，不是两次运行，也不是数据的首行和末行。流水线在五个检查点统计各类别（`data_category`）的记录数：

| ID  | 取自                                |
|-----|-------------------------------------|
| `A` | Step 4 之后（自动规范化：规则修正） |
| `B` | Step 6 之后（时间戳人工修正）       |
| `C` | Step 6.5 之后（时长修正）           |
| `D` | Step 7 之后（指标已算）             |
| `E` | Step 8 之后（自动检测，运行结束）   |

`*_first` 取第一个已完成分类的检查点（通常是 `A`），`*_last`
取最后一个检查点（通常是 `E`），具体用了哪两个写在
`checkpoint_first`、`checkpoint_last`。`delta_*` =
`last - first`。要看将用于分析的数据状态，读
`last`；要看清洗做了什么，读 `delta`。

**稳定性规则**：同一数据跑两次 → 每个数字必须相同。否则非确定性。

**关于 SOL 的说明**：上面的 `sol_mean_min` 是**原始 SOL 时长**。这和图
F29 检查的”SOL
感知偏差”（自报值与计算值之间的差距，见[逐图参考](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference-zh.md)
§5）是不同的量——两处用的参考数字不一样（这里是 10–45 分钟，那边是 15/60
分钟），因为它们衡量的根本不是同一件事。不要拿这两组数字互相对照。

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

| 标准 | 首个有数字的步骤 | 评估什么 | 关键类别 |
|----|:--:|----|----|
| `field_misentry` | 1.5 | 时长估计（SOL、WASO）是否恰好匹配时间戳——可能”填错框” | `none`, `SOL=time_sleep`, `SOL=time_bed`, `WASO=time_awake`, `WASO=time_getup` |
| `data_category` | 4 | bed → sleep → awake → getup 序列的时序与合理性 | `clean`, `error`, `unusual`, `equal_time_ok`, `skipped_na` |
| `flag_severity` | 7 | 每条记录触发多少派生指标标记 | `Clean`, `Minor (1 flag)`, `Major (2+ flags)` |
| `duration_extreme` | 7 | 生理合理界外的总睡眠时间 | `OK`, `Too short (< 3 h)`, `Too long (> 12 h)` |
| `checkforerrors` | 8 | Step 8 汇总的自动检测标记 | `TIMESTAMP_ISSUE`, `DURATION_ISSUE`, `AMOUNT_FLAG`, `SELF_REPORTED_FLAG` |

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
identical(old$n_clean_last, new$n_clean_last)
```

输入数据没变但结果不同 → 管线输出变了，需调查。

## 7. 快速检查卡

| 检查项 | 如何验证 | 通过条件 |
|----|----|----|
| 管线完成 | `file.exists("output/correction_status_final.csv")` | `TRUE` |
| TST 合理 | `tst_mean_h` 在 6–8.5 | 是 |
| SOL 合理（原始时长，非感知偏差） | `sol_mean_min` 在 10–45 | 是 |
| 错误少 | `n_error_last < 0.01 * n_total` | 是 |
| data_category 稳定 | Steps 6–8.5 计数相同 | 是 |
| flag_severity 稳定 | Steps 7–8.5 计数相同 | 是 |
| 全记录有交代 | `clean + unusual + reasonable_unusual + equal_time_ok + error + skipped_na = n_total` | 是 |
| 确定性 | 同输入 → 同输出，每次 | 是 |

## 下一页

管线画的 37 张图，一张一张记在
**[逐图参考](https://cyracaid.github.io/sleepdiary-cleaner/articles/figure-reference-zh.md)**
里：每个部分什么意思、依据什么规则画出来、健康数据长什么样、以及一段可直接用在论文里的图注。
