# SPL Sleep — EMA Sleep Diary Data Cleaning Pipeline

> **[English](#english) · [中文](#中文)**

---

<a name="english"></a>

# English Version

Automated pipeline for cleaning sleep EMA diary data. Parses raw bedtime/sleep/awake/getup timestamps, detects and corrects temporal and duration errors, computes sleep metrics (TST, SOL, WASO, SE), validates self-reported durations, and generates 27 QC visualizations.

## Features

- **9-step pipeline**: raw data → timestamp parsing → interval processing → temporal correction → duration correction → metric computation → auto-detection → cross-participant consistency → visualization
- **Manual correction CSV workflow**: human review decisions stored in CSVs, re-read on each pipeline run
- **Configurable thresholds**: SOL/SE/TST-TIB flag thresholds, timestamp format, column names — all set in a YAML config file
- **Checkpoint reporter**: per-step clean/error/unusual/corrected counts printed and saved to CSV
- **27 diagnostic figures**: organized into `pipeline_cleaning/` (QC) and `research_ready/` (sleep metrics, substance use)
- **R package**: `library(splsleep); run_pipeline()` — installable, versioned, dependency-managed
- **Agent skill**: AI assistants can understand and maintain the pipeline via `.agents/skills/splsleep-pipeline/SKILL.md`

## Pipeline Architecture

```
Raw Data ──→ Step 1: Load Data ──→ Step 2: Parse Timestamps ──→ Step 3: Parse Intervals ──→ Step 4: Normalize Sequence
                                                                                                      │
                                                                                                      ▼
                                                                                             Step 5: Classify Records
                                                                                             (generates review CSVs)
                                                                                                      │
                                                                                             Step 5.75: Second Review
                                                                                                      │
                                                                                             Step 6: Apply Manual Corrections
                                                                                             (reads manual_error_corrections.csv)
                                                                                                      │
                                                                                             Step 6.5: Apply Duration Corrections
                                                                                             (nap, exercise, SOL/WASO corrections)
                                                                                                      │
                                                                                             Step 7: Compute Sleep Metrics
                                                                                             (TST, SOL, WASO, SE, TIB)
                                                                                                      │
                                                                                             Step 8: Auto-Detect Remaining
                                                                                             (TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED)
                                                                                                      │
                                                                                             Step 8.5: Cross-Participant Check
                                                                                                      │
                                                                                             Step 9: Generate 27 Figures
```

### Classification Systems

| System | Source | Categories |
|--------|--------|------------|
| `data_category` | Step 5 (temporal) | clean, error, unusual, equal_time_ok, skipped_na |
| `flag_severity` | Step 7 (metrics) | Clean, Minor (1 flag), Major (2+ flags) |
| `checkforerrors_summary` | Step 8 (auto-detect) | TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG, CLEAN |

### Figures

| Folder | Count | Content |
|--------|-------|---------|
| `pipeline_cleaning/` | 9 | Pipeline progress, data quality dashboard, flag composition, per-participant flag rate |
| `research_ready/` | 15 | Sleep variable distributions, perception bias, substance use, sleep regularity, correlation matrix |

## Quick Start

### Prerequisites

- R ≥ 4.2
- Raw EMA data files (RDS + CSV format with sleep diary timestamps)

### Install and Run

```r
# Install the package
install.packages("splsleep_1.0.0.tar.gz", repos = NULL)

# Load and run (uses built-in default configuration)
library(splsleep)
run_pipeline()
```

Or from the command line:

```bash
bash run.sh
```

### Using with Your Own Dataset

The pipeline is fully configurable via a YAML configuration file. This lets you map your dataset's column names to pipeline variables and adjust thresholds without modifying any R code.

```r
# Step 1: Generate a configuration template
library(splsleep)
file.copy(system.file("config_default.yaml", package = "splsleep"),
          "my_study_config.yaml")
```

**Step 2: Edit `my_study_config.yaml`**

The config file has three key sections:

#### Column Mapping
Map your dataset's column names to the pipeline's internal variables:

```yaml
column_mapping:
  identifiers:
    pid: "subject_id"          # your participant ID column
    day_num: "study_day"       # your day number column
  timestamp:
    time_bed_hhmm: "bedtime"   # your bedtime HH:MM column
    time_bed_ampm: "bed_ampm"  # your bedtime AM/PM column
    time_sleep_hhmm: "sleeptime"
    time_sleep_ampm: "sleep_ampm"
  duration:
    sol: "sleep_onset_latency" # your SOL column (minutes)
    waso: "wake_after_onset"   # your WASO column (minutes)
  substance:
    caffeine: "caffeine_cups"
    alcohol: "alcohol_drinks"
```

#### Thresholds
Adjust detection sensitivity for your study population:

```yaml
classification:
  metric_validation:
    sol:
      excessive_minutes: 120   # SOL > 2h → flagged
    se:
      min_valid_percent: 0
      max_valid_percent: 100
    tst_tib_ratio:
      min_ratio: 0.5
      max_ratio: 1.0
  flag_severity:
    poor_efficiency_threshold_pct: 70   # SE < 70% → flag
    high_sol_threshold_hours: 1         # SOL > 1h → flag
    high_waso_threshold_hours: 1.5      # WASO > 1.5h → flag
```

#### Timestamp Format
Specify how your timestamps are stored:

```yaml
timestamp:
  input_format: "hh:mm AM/PM"   # or "HH:MM", "HH:MM:SS"
  ampm:
    enabled: true
    pm_keywords: ["PM", "pm"]
```

**Step 3: Run with your configuration**

```r
run_pipeline(config = "my_study_config.yaml")
```

All pipeline scripts automatically read the config; no R code changes needed.

## Data Format (Text Only — Templates Provided)

**This repository contains no raw participant data, no real identifiers, and no actual study responses.** All CSV files containing participant data are excluded via `.gitignore` and purged from git history.

Template CSV files with synthetic data are in [`templates/`](templates/). Copy these to create your own correction files.

### Input Data Structure (Text Description)

#### Main Sleep Diary Data (RDS format)

| Column group | Variables | Description |
|---|---|---|
| Identifiers | pid, day_num, row_id, participant | Participant and record IDs |
| Date | StartDate | Calendar date of the EMA session |
| Raw timestamps (HH:MM) | time_bed_am_hhmm, time_sleep_am_hhmm, time_awake_am_hhmm, time_getup_am_hhmm | Self-reported bed/sleep/awake/getup clock times |
| Raw timestamps (AM/PM) | time_bed_am_ampm, time_sleep_am_ampm, time_awake_am_ampm, time_getup_am_ampm | AM/PM indicator for each timestamp |
| Raw durations | duration_totalmin_sol_estimate_am, duration_totalmin_waso_estimate_am | Self-reported SOL and WASO in minutes |
| Nap/Exercise | duration_totalmin_napstoday_PM, exercise_PM_totalmin_[Light\|Moderate\|Vigorous\|Strength] | Self-reported nap and exercise durations |
| Substance use | caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1, alcoholtoday_PM_NumAlcoholicDrinks_1, nicotine_amount_pm_doses, cannabis_amount_pm_doses | Self-reported substance use |
| WASO count | num_waso_estimate_am, num_waso_am | Number of wake bouts |

### Manual Correction CSV Templates

| Template File | Live File | Purpose |
|---|---|---|
| `templates/template_manual_error_corrections.csv` | `manual_error_corrections.csv` | Timestamp corrections (AM/PM, order) |
| `templates/template_manual_unusual_corrections.csv` | `manual_unusual_corrections.csv` | Accepted unusual patterns |
| `templates/template_manual_nap_exercise_corrections.csv` | `manual_nap_exercise_corrections.csv` | Nap/exercise duration corrections |
| `templates/template_manual_sleep_metric_duration_corrections.csv` | `manual_sleep_metric_duration_corrections.csv` | SOL/WASO metric corrections |
| `templates/template_manual_metric_review_acceptances.csv` | `manual_metric_review_acceptances.csv` | Human-accepted metric flags |
| `templates/template_second_review_checklist.csv` | `second_review_checklist.csv` | Second-person verification decisions |

Each template uses synthetic data. See the template files for column-level descriptions.

### Output CSV Structure

| File | Contents |
|---|---|
| `output/correction_status.csv` | Run history of checkpoint snapshots (A-E per run). Tracks n_clean, n_error, n_unusual, n_equal_time, n_skipped, n_corrected at each pipeline step |
| `output/correction_status_final.csv` | Per-run summary comparing first meaningful checkpoint (B) to last (E), with deltas |
| `output/flagged_records_self_reported.csv` | Records flagged as SELF_REPORTED_FLAG, with SOL/SE/ratio categories and metric values |

## Agent Skill

**Location**: `.agents/skills/splsleep-pipeline/SKILL.md`

The skill enables AI assistants to understand the pipeline architecture, run the pipeline, interpret checkpoint reports, add manual corrections, and diagnose issues.

Registered in `opencode.jsonc`:

```json
{
  "skills": {
    "splsleep-pipeline": {
      "description": "Run and maintain the sleep EMA diary data cleaning pipeline",
      "triggers": ["splsleep", "sleep pipeline", "sleep EMA", "run_pipeline"]
    }
  }
}
```

## Output Structure

| Path | Contents |
|------|----------|
| `latest_visualization/` | All PNGs from latest pipeline run |
| `latest_visualization/pipeline_cleaning/` | QC and pipeline progress figures |
| `latest_visualization/research_ready/` | Sleep metrics and analysis figures |
| `output/correction_status.csv` | Per-checkpoint snapshots over all runs |
| `output/correction_status_final.csv` | Cross-checkpoint comparisons per run |
| `output/flagged_records_self_reported.csv` | Records flagged as SELF_REPORTED_FLAG |

## Testing Coverage

The pipeline includes unit tests for critical edge cases in timestamp normalization and interval parsing:

| Tested Scenario | What It Checks |
|---|---|
| Normal sequence | bed < sleep < awake < getup with plausible gaps → no correction |
| AM/PM error on getup | getup recorded 12h late → auto-corrected by subtracting 12h |
| AM/PM error on sleep | sleep recorded 12h ahead → auto-corrected to same day |
| Minor order error | bed/sleep swapped with < 3h gap → auto-swapped |
| All-NA row | all four timestamps NA → has_na flag set, no crash |
| Bed = getup | all timestamps identical → no correction, no crash |
| Interval colon edge case | "00:000" / "000:45" → normalized to "00:00" / "00:45" |

Run tests with: `testthat::test_package("splsleep")`

## Renv Reproducibility

```r
renv::restore()
```

## License

MIT

---

<a name="中文"></a>

# 中文版本

自动化的睡眠 EMA 日记数据清洗管线：解析原始就寝/入睡/醒来/起床时间戳，检测并修正时序和时长错误，计算睡眠指标（TST、SOL、WASO、SE），验证自报时长，生成 27 张质控可视化图表。

## 功能特性

- **9 步管线**：原始数据 → 时间戳解析 → 区间处理 → 时序修正 → 时长修正 → 指标计算 → 自动检测 → 跨被试检查 → 可视化
- **人工修正 CSV 工作流**：审阅决策存储在 CSV 中，每次运行自动读取
- **可配置阈值**：SOL/SE/TST-TIB 标记阈值、时间戳格式、列名 — 全部通过 YAML 配置
- **检查点报告器**：每步的 clean/error/unusual/corrected 计数自动打印并保存为 CSV
- **27 张诊断图**：分为 `pipeline_cleaning/`（质控）和 `research_ready/`（睡眠分析）
- **R 包**：`library(splsleep); run_pipeline()` — 可安装、版本化
- **Agent 技能**：AI 助手可维护管线

## 管线架构

```
原始数据 ──→ Step 1: 加载数据 ──→ Step 2: 解析时间戳 ──→ Step 3: 解析区间 ──→ Step 4: 序列标准化
                                                                                    │
                                                                                    ▼
                                                                           Step 5: 分类记录（生成审阅 CSV）
                                                                                    │
                                                                           Step 5.75: Second Review
                                                                                    │
                                                                           Step 6: 应用人工修正（读取 manual_error_corrections.csv）
                                                                                    │
                                                                           Step 6.5: 应用时长修正
                                                                                    │
                                                                           Step 7: 计算睡眠指标（TST/SOL/WASO/SE）
                                                                                    │
                                                                           Step 8: 自动检测
                                                                                    │
                                                                           Step 8.5: 跨被试检查
                                                                                    │
                                                                           Step 9: 生成 27 张图
```

### 分类体系

| 系统 | 来源 | 类别 |
|------|------|------|
| `data_category` | Step 5（时序） | clean, error, unusual, equal_time_ok, skipped_na |
| `flag_severity` | Step 7（指标） | Clean, Minor（1 标记）, Major（2+ 标记） |
| `checkforerrors_summary` | Step 8（自动） | TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG, CLEAN |

## 快速开始

### 安装运行

```r
install.packages("splsleep_1.0.0.tar.gz", repos = NULL)
library(splsleep)
run_pipeline()
```

### 适配新数据集

```r
# 生成配置模板
file.copy(system.file("config_default.yaml", package = "splsleep"), "my_study_config.yaml")

# 编辑 my_study_config.yaml → 映射列名、调阈值、改时间格式

# 运行
run_pipeline(config = "my_study_config.yaml")
```

## 数据说明（纯文字，无真实数据）

**本仓库不含任何原始参与者数据。** 所有真实数据 CSV 已从 git 历史彻底清除。

模板文件（含假数据）在 [`templates/`](templates/)，展示列结构。

### 主要输入数据

| 列组 | 变量 | 说明 |
|------|------|------|
| 标识符 | pid, day_num, row_id | 参与者/记录 ID |
| 日期 | StartDate | EMA 会话日期 |
| 原始时间戳 | time_bed_am_hhmm (+ampm), time_sleep_am, time_awake_am, time_getup_am | 自报就寝/入睡/醒来/起床 |
| 原始时长 | duration_totalmin_sol_estimate_am, waso_estimate_am | SOL/WASO（分钟） |
| 小睡/运动 | duration_totalmin_napstoday_PM, exercise_PM_totalmin_* | 小睡和运动时长 |
| 物质使用 | caffeinetoday_PM_*, alcoholtoday_PM_*, nicotine_*, cannabis_* | 自报物质使用 |
| WASO 次数 | num_waso_estimate_am | 醒来次数 |

### 人工修正 CSV 模板

| 模板 | 对应文件 | 用途 |
|------|---------|------|
| `templates/template_manual_error_corrections.csv` | `manual_error_corrections.csv` | 时间戳修正 |
| `templates/template_manual_unusual_corrections.csv` | `manual_unusual_corrections.csv` | 异常模式接受 |
| `templates/template_manual_nap_exercise_corrections.csv` | `manual_nap_exercise_corrections.csv` | 小睡/运动时长修正 |
| `templates/template_manual_sleep_metric_duration_corrections.csv` | `manual_sleep_metric_duration_corrections.csv` | SOL/WASO 修正 |
| `templates/template_manual_metric_review_acceptances.csv` | `manual_metric_review_acceptances.csv` | 人工接受标记 |
| `templates/template_second_review_checklist.csv` | `second_review_checklist.csv` | 二次验证 |

### 输出 CSV

| 文件 | 内容 |
|------|------|
| `output/correction_status.csv` | 每次运行的检查点快照 |
| `output/correction_status_final.csv` | 检查点间对比汇总 |
| `output/flagged_records_self_reported.csv` | SELF_REPORTED_FLAG 记录详情 |

## Agent Skill

**位置**：`.agents/skills/splsleep-pipeline/SKILL.md`

AI 助手可通过此技能理解管线架构、运行管线、解读报告、添加修正。

## 许可证

MIT
