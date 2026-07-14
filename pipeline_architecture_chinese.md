# 睡眠 EMA 数据清洗管线 — 架构文档

## 概览

原始 EMA 睡眠日记数据 → 时间戳解析 → 错误检测 → 人工修正（CSV）→ 睡眠指标计算 → 自动标记 → 诊断图表。所有人审决策均存储在 CSV 中，管线在对应步骤读取。

## 前置检查（运行前）

| 脚本 | 用途 |
|------|------|
| `00a_setup.R` | 自动检测 R 包（扫描所有 `.R` 文件的 `library()`/`require()` 调用），安装缺失包；验证输入文件是否存在。 |

## 管线步骤

### 环境要求
- R ≥ 4.2，依赖包见 `DESCRIPTION`
- 原始 EMA 数据文件（RDS + CSV 格式）

### 快速启动（使用内置默认配置）
```r
# 安装管线包
install.packages("splsleep_1.0.0.tar.gz", repos = NULL)

# 加载并运行
library(splsleep)
run_pipeline()
```

### 适配新数据集
管线通过 YAML 配置文件实现完全参数化：

```r
# 第一步：生成配置模板
library(splsleep)
file.copy(system.file("config_default.yaml", package = "splsleep"),
          "my_study_config.yaml")

# 第二步：编辑 my_study_config.yaml
#   - column_mapping:      将数据集的列名映射到管线变量
#   - classification:      调整阈值（SOL、SE、TST/TIB、flag 严重度）
#   - timestamp.format:    指定时间格式（AM/PM、24h 等）

# 第三步：使用自定义配置运行
run_pipeline(config = "my_study_config.yaml")
```

### Shell 入口
```bash
bash run.sh
```

## 管线步骤

### Step 1：加载数据
- **脚本**：`00_MAIN_entry.R`（内联）
- **输入**：`deidentified_intervalvars_forCD_111325.rds`（处理后的 R 数据）、`sber_ema_anon_20260227.csv`（原始问卷）
- **输出**：`df`（合并后含 StartDate、num_waso_am、num_waso_estimate_am）
- **作用**：加载两个数据源，合并仅存在于 CSV 中的列（开始日期、WASO 计数）

### Step 1.5：跨被试字段误填检查
- **脚本**：`cross_participant_field_misentry_check.R`
- **输出**：`cross_participant_field_misentries.csv`
- **作用**：检测 SOL/WASO 值是否与其他时间字段完全一致（跨字段填入错误）

### Step 2：处理时间戳
- **脚本**：`process_timestamp_emadatarelease_cyra.R`
- **输入**：原始时间字符串（如 "7:30 PM"）
- **输出**：`ema_data_release_timeproc`（含解析后的 POSIXct 列 + `_checkforerrors` 标记）
- **作用**：AM/PM 检测、12/24h 格式、缺失分隔符

### Step 3：处理区间时长
- **脚本**：`process_interval.R`
- **输入**：时长字符串（如 "00:30"、"90"、".5"）
- **输出**：SOL、WASO、小睡、运动的数值分钟（Light/Moderate/Vigorous/Strength）
- **作用**：解析 HH:MM、十进制小时、MM:SS，对可疑格式创建 `_checkforerrors` 标记

### Step 4：睡眠时间序列标准化
- **脚本**：`normalize_sleep_time_sequence.R`
- **输入**：解析后的时间戳（可能存在 AM/PM 错误、顺序交换）
- **输出**：`ema_data_release_timecalc`（含修正后时间戳 + `is_priority_adjusted`、`minor_order_error`）
- **作用**：决策树修复 AM/PM 混淆、轻微顺序错误、午夜环绕

### Step 5：记录分类与审阅文件生成
- **脚本**：`generate_correction_files.R`
- **输入**：标准化后的时间戳 + 时长
- **输出**：error/unusual/equal-time 分类；供人工标注的审阅 CSV
- **作用**：比较 bed→sleep→awake→getup 差值与阈值对比。生成 `[NEW]manual_error_correction_review.csv` 供人工审阅

### Step 5.5：人工审阅
审阅上一步输出的 CSV，做出修正或决定是否保留标记数据

### Step 5.75：应用 Second-Review 共识
- **脚本**：`apply_second_review.R`
- **输入**：`second_review_checklist.csv`（13 行，全部 `consensus_reached`）
- **输出**：追加到 `manual_metric_review_acceptances.csv`（anti-join 幂等）；验证 manual_error_corrections.csv 和 manual_nap_exercise_corrections.csv 中的条目已存在
- **作用**：仅写入步骤。根据 `target_csv` 将各清单行分派到对应 CSV。置于 Step 5 和 Step 6 之间，使路由到 `manual_error_corrections.csv` 的修正在同一运行中生效

### Step 6：应用人工修正并重新计算
- **脚本**：`error_unusual_sleep_time_corrections.R`（函数：`apply_manual_corrections_and_recalculate`）
- **输入 CSV**：
  - `manual_error_corrections.csv` — 睡眠时间戳修正（顺序错误、AM/PM 修复）
  - `manual_unusual_corrections.csv` — 已接受的异常模式（失眠、延迟相位）
- **输出**：`corrected_ema_data`（时间戳已修正、指标已重算、error/unusual 标记已设置）
- **作用**：读取人审决策，应用时间戳替换/交换，重新计算所有时间差，重新分类已修正记录

### Step 6.5：应用人工时长修正
- **脚本**（3 个子步骤）：
  1. `apply_nap_exercise_corrections.R` — 小睡/运动数值时长修正
  2. `apply_sleep_metric_duration_corrections.R` — SOL/WASO 指标修正（MM:SS vs HH:MM）
  3. `apply_metric_review_acceptances.R` — 标记行为人工已接受，以抑制未来标记
- **输入 CSV**：
  - `manual_nap_exercise_corrections.csv`
  - `manual_sleep_metric_duration_corrections.csv`
  - `manual_metric_review_acceptances.csv`
- **输出**：`corrected_ema_data`（含修正后的 _mincalc 值 + 已设 `human_metric_review_status`）

### Step 7：计算派生睡眠变量
- **脚本**：`calculate_sleep_time_end.R`（函数：`calculate_sleep_time_vars_end`）
- **输出**：`corrected_ema_data` + 列：SOL（分钟）、TST（分钟）、TIB（分钟）、SE（%）、sleep_onset_timestamp、waso_bout_avg
- **作用**：计算分析使用的实际睡眠指标。包含自差计算审计追踪

### Step 8：自动检测剩余错误
- **脚本**：`checkforerrors_processing.R`
- **部分**：
  - **A**：收集步骤 2-3 已存在的 `_checkforerrors` 标记
  - **B**：导入步骤 6 的 temporal error_type/unusual_type
  - **C**：根据阈值验证计算的睡眠指标（SOL、SE、TST/TIB 比率）
  - **C2**：**对人工接受的行抑制标记**（读取 `human_metric_review_status` + `manual_metric_review_acceptances.csv`）
  - **D**：创建 `checkforerrors_df`（所有剩余需审阅的标记记录）
- **输出**：`checkforerrors_df`（应用人工接受后自动检测的问题）；物质使用异常标记
- **三级分类**：TIMESTAMP_ISSUE / DURATION_ISSUE / AMOUNT_FLAG / SELF_REPORTED_FLAG / CLEAN

### Step 8.5：跨被试全局一致性检查
- **脚本**：`cross_participant_global_check.R`
- **输出**：`cross_participant_flagged_rows.csv`、`cross_participant_suspicious_slices.csv`
- **作用**：计算各被试基线（中位数 + MAD）。标记 SOL/WASO/运动偏离自身标准 ≥ 5 MAD 的天数

### Step 8.75：人工审阅
审阅 `checkforerrors_df`、`cross_participant_flagged_rows.csv`、`cross_participant_suspicious_slices.csv`
审阅上一步输出的 CSV，做出修正或决定是否保留标记数据

### 重新运行步骤 5 至 8（跳过人工审阅）使人审融入最终算法检查

### Step 9：生成图表
- **脚本**：`sleep_visualization.R`
- **输出**：`latest_visualization/` 中 27 张 PNG 诊断图
  - **pipeline_cleaning/**（9 张）：管线进度与质控（如数据质量仪表板、标记组成、管线进度、被试标记率）
  - **research_ready/**（15 张）：睡眠分析图（如睡眠变量分布、感知偏差、物质使用、睡眠规律性、睡眠构成、相关性矩阵）
- **注意**：当未发现问题时跳过自动检测图表（13-18）

### 运行后
查看 `latest_visualization/`（主目录）或按子文件夹 `pipeline_cleaning/` 和 `research_ready/` 中的图表。

## 分类系统

### data_category（Step 5 — 时序分类）
- `clean` — 未检测到时序问题
- `error` — 时序顺序无法自动修复（如起床早于就寝）
- `unusual` — 合理但异常的模式
- `equal_time_ok` — 就寝 == 起床（自动接受）
- `skipped_na` — 无睡眠数据记录
- `reasonable_unusual` — 在可接受范围内的异常

### flag_severity（Step 7 — 计算指标标记）
- **Clean** — 0 个标记
- **Minor issues（1 个标记）** — 恰好 1 个来自 {SE < 70%、SOL > 1h、WASO > 1.5h}
- **Major issues（2+ 个标记）** — 上述条件中的 2+ 个

### checkforerrors_summary（Step 8 — 自动检测）
- `TIMESTAMP_ISSUE` — 时钟时间格式错误
- `DURATION_ISSUE` — 区间/时长格式错误
- `AMOUNT_FLAG` — 物质输入异常
- `SELF_REPORTED_FLAG` — 自报 SOL/WASO 指标异常（非数据错误）
- `CLEAN` — 未发现问题
- `CLEAN (Manually Fixed)` — 曾有问题，Step 6 已修正

## 检查点系统与 Figure 12（管线进度）

管线包含检查点报告器（`report_correction_status.R`），在五个管线里程碑捕获数据状态：

| 检查点 | 位置 | 说明 |
|---|---|---|
| **A** | Step 4 后 | 标准化后，分类前（尚无 data_category） |
| **B** | Step 6 后 | 时间戳修正后 |
| **C** | Step 6.5 后 | 小睡/运动时长修正后 |
| **D** | Step 7 后 | 睡眠指标计算后（TST、SOL、WASO、SE） |
| **E** | Step 8 后 | 自动检测后（最终分类状态） |

每个检查点记录：`n_total`、`n_clean`、`n_error`、`n_unusual`、`n_equal_time`、`n_skipped`、`n_corrected`、`n_valid`、`tst_mean_h`、`sol_mean_min`，输出到 `output/correction_status.csv`。

所有检查点完成后，`final_summary()` 比较第一个有意义检查点（B）与最后一个（E），打印变化量表并保存到 `output/correction_status_final.csv`。

**Figure 12（管线修正进度）** 读取 `output/correction_status.csv`，以分组条形图可视化每个检查点的 Clean/Error/Unusual/Equal Time/Corrected 记录数。替代了原来的 flag_severity 饼图。

## 手动输入 CSV 文件

| 文件 | 读取步骤 | 用途 |
|------|----------|------|
| `manual_error_corrections.csv` | 6 | 睡眠时间戳修正（顺序、AM/PM） |
| `manual_unusual_corrections.csv` | 6 | 已接受的异常模式 |
| `manual_nap_exercise_corrections.csv` | 6.5 | 小睡/运动时长修正 |
| `manual_sleep_metric_duration_corrections.csv` | 6.5 | SOL/WASO MM:SS→分钟修正 |
| `manual_metric_review_acceptances.csv` | 6.5/8 | 人工接受的指标标记 |
| `second_review_checklist.csv` | 5.75 | 13 个单人标注决策的二次验证 |

## 输出文件

| 路径 | 内容 |
|------|------|
| `output/correction_status.csv` | 每次运行的检查点快照历史（A 到 E） |
| `output/correction_status_final.csv` | 跨检查点比较（每次运行的起始 vs 结束） |
| `output/flagged_records_self_reported.csv` | 标记为 SELF_REPORTED_FLAG 的记录及详情 |
| `latest_visualization/` | 最近一次运行的所有 PNG |
| `latest_visualization/pipeline_cleaning/` | 管线进度与质控图 |
| `latest_visualization/research_ready/` | 睡眠指标、感知偏差、物质使用图 |

## 测试覆盖

管线包含针对关键数据转换逻辑的单元测试：

| 测试文件 | 覆盖场景 |
|---|---|
| `tests/testthat/test-normalize.R` | 正常序列、AM/PM 起床错误、AM/PM 入睡错误、微序交换（< 3h）、全 NA 行、bed = getup、大间隔乱序 |
| `tests/testthat/test-interval.R` | 畸形冒号格式（"00:000" → "00:00", "000:45" → "00:45"） |
| `tests/testthat/test-pipeline.R` | 合成数据端到端冒烟测试、配置加载、列适配 |

运行：`testthat::test_package("splsleep")`

## 数据流

```
RDS + CSV ──→ Step 1 ──→ Step 2 ──→ Step 3 ──→ Step 4 ──→ Step 5（生成审阅 CSV）
                                                              ↓
                                   manual_error_corrections.csv
                                   manual_unusual_corrections.csv
                                   second_review_checklist.csv
                                                              ↓
                              Step 5.75 ──→ manual_metric_review_acceptances.csv（追加）
                                                              ↓
                              Step 6 ──→ Step 6.5 ──→ Step 7 ──→ Step 8 ──→ Step 8.5 ──→ Step 9
                                           ↑                        ↑
                              nap_exercise_corrections    manual_metric_review_acceptances
                              sleep_metric_corrections    human_metric_review_status
```

## R 包

管线打包为 R 包（`splsleep`）：
- **安装**：`devtools::install(".", dependencies = TRUE)` 或从 tarball 安装
- **运行**：`library(splsleep); run_pipeline()`
- **锁定文件**：`renv.lock` — `renv::restore()` 复现 R 环境
- **入口脚本**：`run.sh` 自动安装包后调用 `run_pipeline()`

## 关键代码修复（2026-06-23）
1. `checkforerrors_processing.R` Part C2：现在**始终读取** `manual_metric_review_acceptances.csv`（之前当路径 1 找到匹配时跳过）。对已接受行抑制**所有**标记类型（之前仅 SOL:excessive）。
2. `apply_nap_exercise_corrections.R`：修复 `isTRUE()` 错误 — CSV 将 `manually_corrected` 读取为字符 `"TRUE"` 而非逻辑型 TRUE。现使用 `tolower() %in% c("true","verified_recode")`。同时修复了 `do_not_use` 行的 NA 排除路径。
3. `error_unusual_sleep_time_corrections.R`（第 739 行）：`apply_time_instruction_case3()` 仅接受相对指令格式 `"Same day HH:MM:SS AM/PM"`，不接受绝对日期时间。

## 关键更新（2026-07-14）
1. **NEEDS_REVIEW 重命名**为 `SELF_REPORTED_FLAG`，以明确这些是基于日记的指标异常，而非数据错误。
2. **图数量**从 24 增至 27：新增管线进度（替换饼图）、被试标记率、睡眠规律性、睡眠构成、相关性矩阵。
3. **图组织**拆分为 `pipeline_cleaning/` 和 `research_ready/` 子文件夹，位于 `latest_visualization/` 内。
4. **检查点报告器**（`report_correction_status.R`）插入管线的步骤间，打印并保存每步的 clean/error/unusual/corrected 计数。
5. **R 包**创建（`splsleep`），含 `DESCRIPTION`、`NAMESPACE`、导出的 `run_pipeline()`、以及用于环境可复现性的 `renv.lock`。
6. **Agent Skill**创建（`.agents/skills/splsleep-pipeline/SKILL.md`），使 AI 助手能理解并维护管线。
7. **Figure 7 标注**现直接在图上显示标记阈值（SE < 70%、SOL > 1h、WASO > 1.5h）和 Minor/Major 计数。
8. **final_summary**更新为跳过检查点 A（尚无 data_category），比较 B→E 以获得有意义的增量。

## 文件位置
- 管线代码：`/splsleep/`（根目录）
- 审阅 CSV：`/splsleep/`（活跃）、`/splsleep/archive_intermediate_review_csvs/`（已归档中间文件）
- 输出：`/splsleep/output/`（CSV 报告）、`/splsleep/latest_visualization/`（图表）
- 工作日志：`/splsleep/worklog/weekly_plan_2026-07-13.md`
- 审计脚本：`/splsleep/audit_review_propagation.R`（交叉引用审阅 CSV 与管线输入）
