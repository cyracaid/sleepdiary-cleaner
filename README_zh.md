# SPL Sleep — 睡眠 EMA 日记数据清洗管线

自动化的睡眠 EMA 日记数据清洗管线：解析原始就寝/入睡/醒来/起床时间戳，检测并修正时序和时长错误，计算睡眠指标（总睡眠时间、入睡潜伏期、入睡后醒来时间、睡眠效率），验证自报时长，生成 27 张质控可视化图表。

## 功能特性

- **9 步管线**：原始数据 → 时间戳解析 → 区间处理 → 时序修正 → 时长修正 → 指标计算 → 自动检测 → 跨被试一致性检查 → 可视化
- **人工修正 CSV 工作流**：审阅决策存储在 CSV 中，每次运行自动读取
- **可配置阈值**：SOL/SE/TST-TIB 标记阈值、时间戳格式、列名 — 全部通过 YAML 配置文件设置
- **检查点报告器**：每步的 clean/error/unusual/corrected 计数自动打印并保存为 CSV
- **27 张诊断图**：分为 `pipeline_cleaning/`（质控）和 `research_ready/`（睡眠指标、物质使用）
- **R 包**：`library(splsleep); run_pipeline()` — 可安装、版本化、依赖管理
- **Agent 技能**：AI 助手可通过 `.agents/skills/splsleep-pipeline/SKILL.md` 理解并维护管线

## 管线架构

```
原始数据 ──→ Step 1: 加载数据 ──→ Step 2: 解析时间戳 ──→ Step 3: 解析区间 ──→ Step 4: 序列标准化
                                                                                    │
                                                                                    ▼
                                                                           Step 5: 分类记录
                                                                           (生成审阅 CSV)
                                                                                    │
                                                                           Step 5.75: Second Review
                                                                                    │
                                                                           Step 6: 应用人工修正
                                                                           (读取 manual_error_corrections.csv)
                                                                                    │
                                                                           Step 6.5: 应用时长修正
                                                                           (小睡、运动、SOL/WASO 修正)
                                                                                    │
                                                                           Step 7: 计算睡眠指标
                                                                           (TST、SOL、WASO、SE、TIB)
                                                                                    │
                                                                           Step 8: 自动检测剩余问题
                                                                           (TIMESTAMP/DURATION/AMOUNT/SELF-REPORTED)
                                                                                    │
                                                                           Step 8.5: 跨被试检查
                                                                                    │
                                                                           Step 9: 生成 27 张图
```

### 分类体系

| 系统 | 来源 | 类别 |
|------|------|------|
| `data_category` | Step 5（时序） | clean, error, unusual, equal_time_ok, skipped_na |
| `flag_severity` | Step 7（指标） | Clean, Minor（1 个标记）, Major（2+ 个标记） |
| `checkforerrors_summary` | Step 8（自动检测） | TIMESTAMP_ISSUE, DURATION_ISSUE, AMOUNT_FLAG, SELF_REPORTED_FLAG, CLEAN |

### 图表

| 文件夹 | 数量 | 内容 |
|--------|------|------|
| `pipeline_cleaning/` | 9 | 管线进度、数据质量仪表板、标记组成、被试标记率 |
| `research_ready/` | 15 | 睡眠变量分布、感知偏差、物质使用、睡眠规律性、相关性矩阵 |

## 快速开始

### 环境要求

- R ≥ 4.2
- 原始 EMA 数据文件（含睡眠日记时间戳的 RDS + CSV 格式）

### 安装并运行

```r
# 安装管线包
install.packages("splsleep_1.0.0.tar.gz", repos = NULL)

# 加载并运行（使用内置默认配置）
library(splsleep)
run_pipeline()
```

或在命令行：

```bash
bash run.sh
```

### 适配新数据集

管线通过 YAML 配置文件实现完全参数化，无需修改任何 R 代码。

```r
# 第一步：生成配置模板
library(splsleep)
file.copy(system.file("config_default.yaml", package = "splsleep"),
          "my_study_config.yaml")
```

**第二步：编辑 `my_study_config.yaml`**

配置文件包含三个关键部分：

#### 列名映射
将数据集的列名映射到管线内部变量：

```yaml
column_mapping:
  identifiers:
    pid: "subject_id"          # 你的参与者 ID 列
    day_num: "study_day"       # 你的天数编号列
  timestamp:
    time_bed_hhmm: "bedtime"   # 就寝时间 HH:MM 列
    time_bed_ampm: "bed_ampm"  # 就寝时间 AM/PM 列
    time_sleep_hhmm: "sleeptime"
    time_sleep_ampm: "sleep_ampm"
  duration:
    sol: "sleep_onset_latency" # SOL 列（分钟）
    waso: "wake_after_onset"   # WASO 列（分钟）
  substance:
    caffeine: "caffeine_cups"
    alcohol: "alcohol_drinks"
```

#### 阈值调整
根据研究人群调整检测灵敏度：

```yaml
classification:
  metric_validation:
    sol:
      excessive_minutes: 120   # SOL > 2 小时 → 标记
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

#### 时间戳格式
指定数据的存储格式：

```yaml
timestamp:
  input_format: "hh:mm AM/PM"   # 或 "HH:MM"、"HH:MM:SS"
  ampm:
    enabled: true
    pm_keywords: ["PM", "pm"]
```

**第三步：使用自定义配置运行**

```r
run_pipeline(config = "my_study_config.yaml")
```

所有管线脚本自动读取配置；无需修改 R 代码。

## 数据格式（纯文字说明 — 附模板）

**本仓库不含任何原始参与者数据、真实标识符和实际研究应答。** 所有含参与者数据的 CSV 文件已通过 `.gitignore` 排除在版本控制之外，并已从 git 历史中彻底清除。

你可以在 [`templates/`](templates/) 目录中找到 CSV 模板文件，展示预期列结构（使用合成假数据）。复制这些模板即可创建自己的修正文件。

### 输入数据结构（文字说明）

#### 主睡眠日记数据（RDS 格式）
一个预处理的 R 数据框，每人每天一行。每行包含：

| 列组 | 变量 | 说明 |
|---|---|---|
| 标识符 | pid, day_num, row_id, participant | 参与者和记录 ID |
| 日期 | StartDate | EMA 会话的日历日期 |
| 原始时间戳 (HH:MM) | time_bed_am_hhmm, time_sleep_am_hhmm, time_awake_am_hhmm, time_getup_am_hhmm | 自报就寝/入睡/醒来/起床时间 |
| 原始时间戳 (AM/PM) | time_bed_am_ampm, time_sleep_am_ampm, time_awake_am_ampm, time_getup_am_ampm | 每个时间戳的 AM/PM 指示 |
| 原始时长 | duration_totalmin_sol_estimate_am, duration_totalmin_waso_estimate_am | 自报 SOL 和 WASO（分钟） |
| 小睡/运动 | duration_totalmin_napstoday_PM, exercise_PM_totalmin_[Light\|Moderate\|Vigorous\|Strength] | 自报小睡和运动时长 |
| 物质使用 | caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1, alcoholtoday_PM_NumAlcoholicDrinks_1, nicotine_amount_pm_doses, cannabis_amount_pm_doses | 自报物质使用 |
| WASO 次数 | num_waso_estimate_am, num_waso_am | 醒来次数 |

#### 原始 EMA CSV
一个 CSV 文件，具有相同的参与者-天结构，包含来自 EMA 调查平台的额外原始应答列。补充 RDS 的关键列：

| 列 | 说明 |
|---|---|
| StartDate | EMA 会话开始日期 |
| num_waso, num_waso_estimate_am | WASO 次数 |
| 各种物质使用应答 | 原始文本/数字输入 |

### 人工修正 CSV 格式（模板可用）

所有人工修正文件遵循一致的结构：参与者标识符 + 天数编号 + 修正指令。
**带有合成数据的模板文件在 [`templates/`](templates/) 中** — 复制它们来创建你自己的文件：

| 模板文件 | 对应实际文件 | 用途 |
|---|---|---|
| `templates/template_manual_error_corrections.csv` | `manual_error_corrections.csv` | 时间戳修正（AM/PM、顺序） |
| `templates/template_manual_unusual_corrections.csv` | `manual_unusual_corrections.csv` | 已接受的异常模式 |
| `templates/template_manual_nap_exercise_corrections.csv` | `manual_nap_exercise_corrections.csv` | 小睡/运动时长修正 |
| `templates/template_manual_sleep_metric_duration_corrections.csv` | `manual_sleep_metric_duration_corrections.csv` | SOL/WASO 时长修正 |
| `templates/template_manual_metric_review_acceptances.csv` | `manual_metric_review_acceptances.csv` | 人工接受的指标标记 |
| `templates/template_second_review_checklist.csv` | `second_review_checklist.csv` | 二次验证决策 |

#### 各列详细说明

##### `manual_error_corrections.csv`
包含人工审阅者输入的时间戳修正。每行指定：
- **pid, day_num, row_id**：标识记录
- **variable**：要修正的时间戳变量（如 time_bed_am、time_sleep_am）
- **old_value_hhmm, old_value_ampm**：原始值
- **new_value_hhmm, new_value_ampm**：修正值
- **correction_type**：修复类型（如 "order_error"、"ampm_fix"）
- **confidence**：审阅者置信度
- **reviewer_notes**：自由文本备注

##### `manual_unusual_corrections.csv`
被判断为生理上合理的异常时间模式：
- **pid, day_num, row_id**：标识记录
- **unusual_type**：类别（如 "short_sleep"、"delayed_phase"）
- **sleep_duration_h**：观察到的睡眠时长
- **notes**：审阅者理由

##### `manual_nap_exercise_corrections.csv`
修复小睡/运动条目中的时长解析错误：
- **pid, day_num, row_id**：标识记录
- **variable**：要修正的时长变量
- **old_value**：原始解析值（字符串）
- **new_value**：修正值（数值分钟）
- **correction_type**："MMSS_recode"（如 "06:30" → 6.5 分钟）或 "decimal_fix"

##### `manual_sleep_metric_duration_corrections.csv`
修复 HH:MM 被误解析为 MM:SS 的 SOL/WASO 时长条目：
- **pid, day_num, row_id**：标识记录
- **variable**："duration_totalmin_sol_estimate_am" 或 "duration_totalmin_waso_estimate_am"
- **original_mincalc**：修正前的值
- **corrected_value**：修正后的值
- **mmss_threshold_applied**：是否应用了 MM:SS→分钟转换

##### `manual_metric_review_acceptances.csv`
人工审阅者判断为可接受（非错误）的自动检测标记行：
- **pid, day_num, row_id**：标识记录
- **human_metric_review_status**："confirmed_not_error_do_not_correct"
- **auto_error_desc**：原始自动检测描述
- **reviewer_id**：批准人
- **review_date**：批准日期

##### `second_review_checklist.csv`
单人标注决策的二次验证：
- **target_csv**：决策适用的修正 CSV
- **pid, day_num, row_id**：标识记录
- **original_assessment**：第一位审阅者的决定
- **consensus_reached**：TRUE/FALSE
- **final_action**：如 "apply_correction"、"mark_as_accepted"

### 衍生/输出 CSV 格式

| 文件 | 内容 |
|---|---|
| `output/correction_status.csv` | 每次运行的检查点快照历史（每步 A-E 的 n_clean、n_error、n_unusual、n_equal_time、n_skipped、n_corrected） |
| `output/correction_status_final.csv` | 每次运行的摘要，比较第一个有意义检查点（B）与最后一个（E），含变化量 |
| `output/flagged_records_self_reported.csv` | 标记为 SELF_REPORTED_FLAG 的记录，含 SOL/SE/比率类别和指标值 |

## Agent Skill

本项目包含一个 AI agent skill，用于 AI 辅助管线维护：

**位置**：`.agents/skills/splsleep-pipeline/SKILL.md`

该技能使 AI 助手能够：
- 理解管线架构、文件结构和数据流
- 运行管线并解读检查点报告
- 添加人工修正并重新生成图表
- 诊断清洗过程中的问题

与 opencode 或兼容的 AI 工具配合使用时，该技能在 `opencode.jsonc` 中注册：

```json
{
  "skills": {
    "splsleep-pipeline": {
      "description": "运行和维护睡眠 EMA 日记数据清洗管线",
      "triggers": ["splsleep", "sleep pipeline", "sleep EMA", "run_pipeline"]
    }
  }
}
```

## 输出结构

| 路径 | 内容 |
|------|------|
| `latest_visualization/` | 最近一次运行的所有 PNG |
| `latest_visualization/pipeline_cleaning/` | 质控和管线进度图 |
| `latest_visualization/research_ready/` | 睡眠指标和分析图 |
| `output/correction_status.csv` | 所有运行的检查点快照历史 |
| `output/correction_status_final.csv` | 每次运行的跨检查点比较 |
| `output/flagged_records_self_reported.csv` | 标记为 SELF_REPORTED_FLAG 的记录 |

## Renv 可复现性

项目包含 `renv.lock` 文件，用于精确复现 R 环境：

```r
renv::restore()
```

确保所有包版本与开发环境一致。

## 许可证

MIT
