<div id="main" class="col-md-9" role="main">

# 列映射、配置与数据格式（中文）

sleepcleanr 通过 YAML
配置文件完全可配置：把数据集的列名映射到管线内部变量、
调整阈值，无需修改任何 R 代码。

<div id="cb1" class="sourceCode">

``` r
library(sleepcleanr)
```

</div>

<div class="section level2">

## 安装与运行

<div id="cb2" class="sourceCode">

``` r
# 从 GitHub 安装
renv::install("cyracaid/sleepdiary-cleaner")

# 加载并运行
library(sleepcleanr)
run_pipeline()
```

</div>

</div>

<div class="section level2">

## 适配自己的数据集

<div id="cb3" class="sourceCode">

``` r
# 第 1 步：复制配置模板
library(sleepcleanr)
file.copy(system.file("config_template.yaml", package = "sleepcleanr"),
          "my_study.yaml")
```

</div>

**第 2 步：编辑 `my_study.yaml`**

文件开头只有两项必须改：

<div id="cb4" class="sourceCode">

``` yaml
data:
  files:
    main: "your_data.rds"        # 你的睡眠日记文件（.rds 或 .csv）
    extra: ""                    # 除非 StartDate 在单独文件里，否则留空
```

</div>

三种常见场景： -
**全部在一个文件**（大多数数据集）：`main: "my_data.rds"`，`extra: ""` -
**数据分两个文件**：`main: "ema_vars.rds"`，`extra: "dates.csv"` -
**你的数据是 CSV**：`main: "my_data.csv"`，`extra: ""` — `.csv`
扩展名自动检测

<div class="section level3">

### 列映射

把数据集的列名映射到管线的内部变量：

<div id="cb5" class="sourceCode">

``` yaml
column_mapping:
  identifiers:
    pid: "subject_id"          # 你的参与者 ID 列
    day_num: "study_day"       # 你的研究日数列
  timestamp:
    time_bed_hhmm: "bedtime"   # 你的就寝时间 HH:MM 列
    time_bed_ampm: "bed_ampm"  # 你的就寝 AM/PM 列
    time_sleep_hhmm: "sleeptime"
    time_sleep_ampm: "sleep_ampm"
  duration:
    sol: "sleep_onset_latency" # 你的 SOL 列（分钟）
    waso: "wake_after_onset"   # 你的 WASO 列（分钟）
  substance:
    caffeine: "caffeine_cups"
    alcohol: "alcohol_drinks"
```

</div>

</div>

<div class="section level3">

### 阈值

按你的研究人群调整检测灵敏度：

<div id="cb6" class="sourceCode">

``` yaml
classification:
  metric_validation:
    sol:
      excessive_minutes: 120   # SOL > 2h → 标记
    se:
      min_valid_percent: 0
      max_valid_percent: 100
    tst_tib_ratio:
      min_ratio: 0.5
      max_ratio: 1.0
  flag_severity:
    poor_efficiency_threshold_pct: 70   # SE < 70% → 标记
    high_sol_threshold_hours: 1         # SOL > 1h → 标记
    high_waso_threshold_hours: 1.5      # WASO > 1.5h → 标记
```

</div>

阈值依据见
`THRESHOLDS.md`——默认值对健康成人样本故意宽松；临床人群需重审。

</div>

<div class="section level3">

### 时间戳格式

<div id="cb7" class="sourceCode">

``` yaml
timestamp:
  input_format: "hh:mm AM/PM"   # 或 "HH:MM", "HH:MM:SS"
  ampm:
    enabled: true
    pm_keywords: ["PM", "pm"]
```

</div>

**第 3 步：用你的配置运行**

<div id="cb8" class="sourceCode">

``` r
run_pipeline(config = "my_study_config.yaml")
```

</div>

所有管线脚本自动读取配置；无需改 R 代码。

</div>

</div>

<div class="section level2">

## 输入数据结构

**本仓库不含原始参与者数据。** 所有含参与者数据的 CSV 都被 gitignore。
含合成数据的模板在 `templates/`。

| 列组                | 变量                                                                                                                                                | 说明                            |
|---------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| 标识符              | pid, day\_num, row\_id, participant                                                                                                                 | 参与者和记录 ID                 |
| 日期                | StartDate                                                                                                                                           | EMA 会话的日历日期              |
| 原始时间戳（HH:MM） | time\_bed\_am\_hhmm, time\_sleep\_am\_hhmm, time\_awake\_am\_hhmm, time\_getup\_am\_hhmm                                                            | 自报就寝/入睡/醒来/起床时钟时间 |
| 原始时间戳（AM/PM） | time\_bed\_am\_ampm, time\_sleep\_am\_ampm, time\_awake\_am\_ampm, time\_getup\_am\_ampm                                                            | 每个时间戳的 AM/PM 指示         |
| 原始时长            | duration\_totalmin\_sol\_estimate\_am, duration\_totalmin\_waso\_estimate\_am                                                                       | 自报 SOL 和 WASO（分钟）        |
| 小睡/运动           | duration\_totalmin\_napstoday\_PM, exercise\_PM\_totalmin\_\[Light\|Moderate\|Vigorous\|Strength\]                                                  | 自报小睡和运动时长              |
| 物质使用            | caffeinetoday\_PM\_NumCaffeinatedDrinksSnacks\_1, alcoholtoday\_PM\_NumAlcoholicDrinks\_1, nicotine\_amount\_pm\_doses, cannabis\_amount\_pm\_doses | 自报物质使用                    |
| WASO 次数           | num\_waso\_estimate\_am, num\_waso\_am                                                                                                              | 醒来次数                        |

</div>

<div class="section level2">

## 人工修正 CSV 模板

| 模板文件                                                          | 正式文件                                       | 用途                      |
|-------------------------------------------------------------------|------------------------------------------------|---------------------------|
| `templates/template_manual_error_corrections.csv`                 | `manual_error_corrections.csv`                 | 时间戳修正（AM/PM、顺序） |
| `templates/template_manual_unusual_corrections.csv`               | `manual_unusual_corrections.csv`               | 接受的异常模式            |
| `templates/template_manual_nap_exercise_corrections.csv`          | `manual_nap_exercise_corrections.csv`          | 小睡/运动时长修正         |
| `templates/template_manual_sleep_metric_duration_corrections.csv` | `manual_sleep_metric_duration_corrections.csv` | SOL/WASO 指标修正         |
| `templates/template_manual_metric_review_acceptances.csv`         | `manual_metric_review_acceptances.csv`         | 人工接受的指标标记        |
| `templates/template_second_review_checklist.csv`                  | `second_review_checklist.csv`                  | 第二人验证决定            |

</div>

<div class="section level2">

## 输出

| 文件                                                           | 内容                                                        |
|----------------------------------------------------------------|-------------------------------------------------------------|
| `output/correction_status_final.csv`                           | 每次运行摘要：n\_total, tst, sol, error/corrected/flag 计数 |
| `output/appendix_step_ledger.csv`                              | 逐步标记追踪账本                                            |
| `output/flagged_records_self_reported.csv`                     | 标为 SELF\_REPORTED\_FLAG 的记录                            |
| `latest_visualization_*/figure_index.png`                      | 所有生成图的总览                                            |
| `output/verification/real_n13990/`, `verification/synth_n280/` | 稳定、永不被覆盖的验证产物                                  |

输出结构的关键规则： - `latest_visualization_<tag>_n<rows>/`
是“最新”而非“历史”——每次可视化运行清空重建。 -
`verification/<tag>_n<rows>/` 是同级目录，永不被清空逻辑触碰。 -
真实数据输出只落在 `output/`（gitignore）；合成输出路由到 `output/`
之外。

</div>

</div>
