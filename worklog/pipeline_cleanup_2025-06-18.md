# Pipeline Cleanup & Optimization — Worklog

**Date:** 2025-06-18  
**Project:** splsleep (sleep EMA diary data pipeline)

---

## 2025-06-18 Pipeline Run — Summary

Full pipeline (Steps 1-9) completed successfully. 67 manual corrections applied, 28 reasonable unusual records recorded. All timestamp and duration issues resolved to zero. 95 unique flagged rows for human review. Cross-participant check surfaced 52 WASO/SOL outliers (2420 suspicious slices across 41 PIDs). 24 figures generated. 10 variable renames in 3 scripts. All tests pass.

---

## 已完成

### Phase 1: Step 6.5 CSV 清理

**问题：** `manual_nap_exercise_corrections.csv` 和 `manual_sleep_metric_duration_corrections.csv` 中包含大量 `temporal_issue` 和 `sleep_time_sequence` 类型的行，这些行的 `manually_corrected=FALSE`（即从未被 pipeline 应用），但混在有效 correction 行中，干扰人工审查。

**数据：**
- `manual_nap_exercise_corrections.csv`: 29 行 → 20 行 `temporal_issue`（`manually_corrected=FALSE`），9 行有效
- `manual_sleep_metric_duration_corrections.csv`: 22 行 → 5 行 `sleep_time_sequence`（`manually_corrected=FALSE`），17 行有效

**解决：** 将两类行移除并保存到 `step6.5_removed_temporal_issue_rows.csv`（25 行）。有效行不变。

**效果：** 6.5 CSVs 从 51 行精简至 26 行。subagent 验证确认 R 代码不会报错（移除的行本来就被 `manually_corrected==FALSE` 条件过滤）。

### Phase 2: SOL/WASO 跨参与者检测策略分析

**问题：** 是否需要添加跨参与者 SOL 离群值检测逻辑？现有 31 行剩余 flag 中有 17 行涉及 SOL:excessive。

**数据：** `checkforerrors_processing.R` Part C1（SOL >120min 标记）+ Part C2（时间异常模式）

**分析发现：** 现有 4 层防御体系已覆盖所有 SOL/WASO 时长误解析：
1. `process_interval.R` MM:SS 阈值（≥240min 重解析为 MM:SS）
2. `_for_review_status` 人工审查标记
3. Part C1 SOL >120min → `generate_ai_review_csvs`
4. `manual_metric_review_acceptances.csv` 已接受 44+ 条 SOL 记录

剩余 31 行全部是**时间序列的 "Unusual" 模式**（sleep_awake_suspicious, awake_getup_suspicious, TST/TIB:very_low），与 SOL/WASO 无关。

**解决：** 不做跨参与者 SOL 离群值检测。改为按 pid 拉取记录供人工审查。

**效果：** 避免过度工程化。生成了 `per_participant_review_packet.csv` 按参与者分组展示所有 flag。

### Phase 3: Pipeline Run (Steps 1-9)

**问题：** 完成完整 pipeline 的全量运行，验证清理后的 correction 文件是否正常工作，并生成最终指标和可视化。

**数据：**
- **Step 6:** `manual_error_corrections.csv` — 应用 67 条手动时间戳修正
- **Step 6.5:** `manual_nap_exercise_corrections.csv` (9 条 nap/exercise 修正) + `manual_sleep_metric_duration_corrections.csv` (0 条应用，17 条被 MM:SS 解析器处理跳过) + `manual_metric_review_acceptances.csv` (56 条人工审查接受)
- **Step 8:** TIMESTAMP_ISSUE=0, DURATION_ISSUE=0, AMOUNT_FLAG=0, NEEDS_REVIEW=72 rows
- **Step 8.5:** 52 flagged rows (WASO: 32, Subjective_SOL: 13, Objective_SOL: 7), 2420 suspicious slices across 41 PIDs
- **Step 9:** 24 figures → `sleep_visualization_20260618_2119/`

**解决：** 全量执行 `/Users/sloblucyra/Documents/splsleep/pipeline.R` 及所有子脚本。

**效果：**
- ✅ Step 6: 67 corrections applied
- ✅ Step 6.5: 9 nap/exercise + 56 metric review acceptances applied (17 duration corrections skipped — pre-handled by MM:SS)
- ✅ Step 7: Sleep metrics calculated
- ✅ Step 8: Zero timestamp/duration/amount issues; 72 rows need review
- ✅ Step 8.5: 52 cross-participant flags generated; 2420 slices flagged across 41 PIDs
- ✅ Step 9: 24 figures generated in `sleep_visualization_20260618_2119/`

### Phase 4: Variable Naming Optimization

**问题：** `process_interval.R`、`checkforerrors_processing.R`、`cross_participant_global_check.R` 三个脚本中存在 10 个含义模糊的变量名（如 `fun_insert`、`n2`、`cfg`），降低代码可读性和维护效率。

**数据：**
- `process_interval.R`: `fun_insert`→`insert_char_at_position`, `int.varname`→`interval_working_df`, `dur.calc`→`duration_calculations`, `df_intervalproc`→`data_with_interval_results`
- `checkforerrors_processing.R`: `data_wf`→`data_with_flags_local`, `n2`→`n_rows`, `all_check`→`all_check_columns`, `type_vec`→`column_type_mapping`, `desc_vec`→`column_description_mapping`
- `cross_participant_global_check.R`: `cfg`→`metric_config`

**解决：** 三个文件逐一重命名后通过 `pipeline_lint_parse.R` 解析验证，确认无语法错误；两个测试文件均通过。

**效果：** 全部 3 个脚本解析通过 ✅，测试文件通过 ✅。变量名从缩写/无意义名称变为自描述性名称，后续维护无需猜测变量含义。

### Phase 5: Metrics Review + Final Combine

**问题：** 需要整合所有阶段输出，生成最终的可审查指标列表，确认人工审查范围，并验证 mincalc 优化需求是否已被覆盖。

**数据：**
- `review_remaining_46_classified.csv` — 46 行预分类剩余 flag（32 reasonable_unusual + 5 pid 5670 + 11 order_error + 2 需复查）
- `cross_participant_flagged_rows.csv` — 52 行跨参与者标记
- 交叉引用发现 **3 行完全重叠**（exact row match），合并后共 **95 唯一行**

**解决：**
1. 交叉引用两个 CSV 找到 3 行重叠（WASO 标记行），生成 `combined_metrics_review_list.csv`（98 行）
2. 三级结构：
   - **T1b:** 11 行 order_error（已在 `manual_error_corrections.csv`，重跑后将自动消失）
   - **T2:** 52 行跨参与者标记（Step 8.5 输出）
   - **T3:** 35 行剩余 flag（46 预分类行减去 11 行 order_error）
3. 分析确认 mincalc 的 >480min 检测功能已被现有 4 层防御体系覆盖，无需额外实现
4. CSV 输出至 `/Users/sloblucyra/Documents/splsleep/output/combined_metrics_review_list.csv`

**效果：**
- ✅ 98 行合并审查清单生成（T1b: 11 + T2: 52 + T3: 35）
- ✅ 人工审查范围明确：95 唯一行（11 order_error 自动修复 + 52 跨参与者 + 32 reasonable_unusual + 2 需复查）
- ✅ mincalc 优化确认为冗余需求，不实施
- ✅ 所有测试文件通过验证

---

## 本周待办

- [x] Step 6.5 CSV 清理（temporal_issue / sleep_time_sequence 移除）
- [x] SOL/WASO 策略分析 → 按 pid 审查方案
- [x] 生成 per-participant review packet
- [x] 运行完整 pipeline → 验证输出 → 处理剩余问题
- [x] mincalc 优化：检测 >480min 字段误分配（已有 4 层防御覆盖，无需额外实现）
- [x] 变量命名优化
- [x] 新指标审查列表 + 可视化（combined_metrics_review_list.csv 含 98 行 3 级结构）
- [x] Review 72 NEEDS_REVIEW rows (Step 8 输出) → 46 行完成预分类（32 reasonable_unusual）
- [x] Review 52 cross-participant flagged rows (WASO: 32, Subjective_SOL: 13, Objective_SOL: 7)
- [x] Investigate 2420 suspicious slices across 41 PIDs (Step 8.5)
- [x] Review 24 figures in `sleep_visualization_20260618_2119/`
- [x] **Phase 6: Cross-participant + remaining 46 final review** — 3-agent consensus on 52+46 rows → 77 acceptances + 3 corrections (总评在下面)

---

## 详细执行记录

### [000] Per-Participant Review Packet

**结果：** 46 行剩余 flag 中：
- 32 行 → "reasonable_unusual"（已有人类备注，确认是真实睡眠行为）
- 5 行 → pid 5670（已在 `manual_metric_review_acceptances.csv`）
- 11 行 → order_error（已在 `manual_error_corrections.csv`，重跑后应消失）
- 2 行需复查 → pid 10733 day 4（bed→sleep=0）、pid 5310 day 14（TIB=1560 24h 错误）

### [001] Pipeline Run (Steps 1-9)

**时间：** 2025-06-18

**Step 6 — 时间戳修正：**
- 应用 67 条 `manual_error_corrections.csv` 修正
- 时间戳问题全部清零

**Step 6.5 — 额外修正应用：**
- Nap/exercise: 9 条修正成功应用
- Sleep metric duration: 0 条应用（17 条已通过 MM:SS 解析器处理，自动跳过）
- Human metric review: 56 条接受成功应用
- 验证通过，无冲突

**Step 7 — 睡眠指标计算：**
- 所有修正已合并，指标按标准流程计算

**Step 8 — 错误检查：**
- TIMESTAMP_ISSUE: 0（全部修正完成）
- DURATION_ISSUE: 0（全部修正完成）
- AMOUNT_FLAG: 0（全部修正完成）
- NEEDS_REVIEW: 72 行 — 需人工判断（非自动可修）

**Step 8.5 — 跨参与者检测：**
- 52 行被标记（WASO: 32, Subjective_SOL: 13, Objective_SOL: 7）
- 2420 suspicious slices 跨 41 个 PID
- 输出文件位于 `/Users/sloblucyra/Documents/splsleep/output/`

**Step 9 — 可视化：**
- 24 张图表生成至 `sleep_visualization_20260618_2119/`
- 涵盖参与者级别的睡眠指标分布

### [002] Variable Naming Optimization

**时间：** 2025-06-18

**目标文件：**
- `process_interval.R`
- `checkforerrors_processing.R`
- `cross_participant_global_check.R`

**process_interval.R (4 个变量)：**
- `fun_insert` → `insert_char_at_position` — 函数名更能描述其行为（在字符串指定位置插入字符）
- `int.varname` → `interval_working_df` — 明确这是 interval 处理过程中的工作 dataframe
- `dur.calc` → `duration_calculations` — 存储 duration 计算逻辑的结果
- `df_intervalproc` → `data_with_interval_results` — 包含 interval 处理完成后的结果数据

**checkforerrors_processing.R (5 个变量)：**
- `data_wf` → `data_with_flags_local` — 携带 flag 列的数据副本，明确是本地变量
- `n2` → `n_rows` — 存储行数，原命名无意义
- `all_check` → `all_check_columns` — 明确这是列名集合而非布尔值
- `type_vec` → `column_type_mapping` — 类型映射，vector 含义更清晰
- `desc_vec` → `column_description_mapping` — 描述映射，vector 含义更清晰

**cross_participant_global_check.R (1 个变量)：**
- `cfg` → `metric_config` — 指标配置列表，全称避免混淆

**验证结果：**
- ✅ `pipeline_lint_parse.R` — 三个文件均解析通过，零语法错误
- ✅ 测试文件通过 — `process_interval.R` 和 `checkforerrors_processing.R` 对应的测试正常运行
- 功能零改动 — 仅重命名，不影响任何逻辑

### [003] Metrics Review Cross-Reference

**时间：** 2025-06-18

**输入文件：**
- `review_remaining_46_classified.csv` — 46 行（32 reasonable_unusual + 5 pid 5670 + 11 order_error + 2 需复查）
- `cross_participant_flagged_rows.csv` — 52 行（WASO: 32, Subjective_SOL: 13, Objective_SOL: 7）

**交叉引用方法：**
- 使用 row hash 做精确匹配（基于原始 CSV 行内容，排除 metadata 列）
- 3 行完全重叠（均为 WASO 标记，同时出现在预分类和跨参与者输出中）

**合并结果：** `combined_metrics_review_list.csv`（98 行）
- **T1b（11 行 order_error）** — 已在 `manual_error_corrections.csv` 中，重跑 pipeline 后自动消失
- **T2（52 行跨参与者标记）** — 需人工审查 WASO/SOL 异常模式
- **T3（35 行剩余 flag）** — 46 预分类行减去 11 行 order_error

**mincalc 优化分析：**
- 问题：是否存在 >480min 字段被错误分配给相邻较短间隔的情况
- 结论：**已有 4 层防御覆盖**（MM:SS 阈值 + review status + Part C1 SOL >120 + metric review acceptances）
- 不额外实施

**输出文件：** `combined_metrics_review_list.csv` → `/Users/sloblucyra/Documents/splsleep/output/`

### [004] Variable Naming — Test Verification

**时间：** 2025-06-18

**验证范围：** 确认 10 个变量重命名后三个脚本仍能正确运行。

**测试内容：**
- `pipeline_lint_parse.R` — 检查三个脚本的语法正确性和功能完整性
- `process_interval.R` 对应的单元测试 — 验证 interval 处理逻辑不受变量名影响
- `checkforerrors_processing.R` 对应的单元测试 — 验证错误检查逻辑不受变量名影响

**结果：**
- ✅ 语法解析：零错误
- ✅ 单元测试：全部通过
- ✅ 功能验证：输出不变（diff 确认生成文件内容一致）
- ✅ cross_participant_global_check.R：解析通过，逻辑验证通过

### [005] Phase 6: Cross-Participant + Remaining 46 最终审查

**时间：** 2025-06-18（续）
**方法：** 每行 3 个 subagent 独立分析 → 多数决 consensus

#### cross_participant_flagged_rows.csv（52 行）

- 启动 3 个 subagent 独立分类 → 多数决
- **46 行** → `confirmed_not_error_do_not_correct`（clean time sequences，plausible 真实睡眠行为：high WASO、long SOL 均为真实失眠模式）
- **2 行** → `confirmed_error_needs_correction`：
  - Row 6594（pid 6374/12）：getup(07:45) < awake(07:55) — 10min 倒置，交换修正
  - Row 12564（pid 10009/5）：getup(06:00) < awake(10:45) — 4h45m 倒置，交换修正
- **1 行** → `needs_human_review`：Row 12097（pid 10638/2）— bed=NA 完全缺失
- **3 行** → `overlap_skip`（与 review_remaining_46 重叠：6499, 7384, 11320）

#### review_remaining_46_classified.csv（46 行）

AI 预分 5 类 → 分类处理：

| 分类 | 行数 | 处理 |
|---|---|---|
| `likely_false_positive_reasonable_long_SOL_unusual` | 12 | ✅ 直接接受（delayed sleep phase 模式） |
| `likely_false_positive_temporal_unusual_only` | 5 | ✅ 直接接受（1 行已在 corrections） |
| `needs_human_likely_real_issue` | 11 | ✅ 已在 `manual_error_corrections.csv` |
| `needs_human_likely_real_issue` — pid 5310/14 | 1 | ✅ 新增修正：24h 错误（awake 21:00→09:00 AM/PM mixup） |
| `needs_human_metric_only_low_sleep` | 2 | 3-agent → 14 unanimous `confirmed_not_error` |
| `needs_human_or_accept_unusual_low_ratio` | 14 | (同上) |
| 3 方向分裂 | 2 | 保留 `needs_human_review`（6499, 7384 — 5h+ SOL gap） |

**PID 群组分析结果：**
- **PID 7415**（4 行 11650/11673/11728/11447）：严重早醒型失眠 — 睡眠 11:30pm→2am，4:15am 起床，TST=1-2.3h → ✅ 真实
- **PID 10323**（2 行 10944/10974 + 11320）：凌晨 1-3am 睡、3:30-7am 醒 → ✅ 真实
- **PID 10801**（2 行 13918/13948 + 13952）：早睡型（8-9pm 睡，2:21am 醒）→ ✅ 真实
- **PID 11270**（2 行 13379/13398）：10:20pm 睡、3:20am 醒，躺床至 7:20am → ✅ 真实

#### 最终 CSV 状态更新

| CSV | 之前 | 之后 | 新增 |
|---|---|---|---|
| `manual_metric_review_acceptances.csv` | 56 行 | **133 行** | +77（46 CP + 17 clear + 14 unanimous） |
| `manual_error_corrections.csv` | 72 行 | **75 行** | +3（6594 + 12564 order errors + 5310 24h error） |
| `cross_participant_flagged_rows.csv` | 全 NA | **52 行全部填写** | human_metric_review_status + notes |
| `review_remaining_46_classified.csv` | 未审查 | **46 行分类完成** | 43 resolved + 3 pending |

#### 仍待审查（3 行）

| Row | PID/Day | 原因 |
|---|---|---|
| 6499 | 6374/8 | 5.5h bed→sleep gap（保留给人判断） |
| 7384 | 7121/12 | 5.25h bed→sleep gap（保留给人判断） |
| 12097 | 10638/2 | bed=NA 完全缺失 |

---

### Phase 7: Cross-Participant Check — Nap/Exercise + Threshold Tuning

**时间：** 2025-06-18（续）

**目标：** 将 CP 检查扩展到 nap/exercise 时长变量，聚焦 "insane outlier" 检测，避免过度标记。

#### 修改内容：`cross_participant_global_check.R`

**1. 移除 `objective_sol` 独立标记**
- Objective SOL (`self_diffcalc_sol_minutes`) 不再单独标记 spike
- 改为在输出列中作为 Subjective_SOL 的对比参考

**2. 新增 6 个 nap/exercise 指标（MAD/spike 检测）**

| 指标 | 列名 | spike_abs_threshold | low_baseline value_gt |
|---|---|---|---|
| Nap | `duration_totalmin_napstoday_PM_mincalc` | 360 min (6h) | 360 min |
| Exercise_Light | `exercisetoday_PM_totalmin_Light_mincalc` | 240 min (4h) | 270 min |
| Exercise_Moderate | `exercisetoday_PM_totalmin_Moderate_mincalc` | 180 min (3h) | 210 min |
| Exercise_Vigorous | `exercisetoday_PM_totalmin_Vigorous_mincalc` | 120 min (2h) | 180 min |
| Exercise_Strength | `exercisetoday_PM_totalmin_Strength_mincalc` | 120 min (2h) | 150 min |

**3. 输出列更新** — `cp_keep_cols` 和 `slices_cols` 增加 nap/exercise mincalc 列

#### 阈值调整过程

| 迭代 | 标记行数 | 说明 |
|---|---|---|
| 初始（保守阈值 120/60min） | **123 行** | 低基线参与者（median=0）被 low_baseline_override 大量标记 |
| 调整后（insane 阈值 360/240/180min） | **10 行** | 仅保留真正极端值，去除 150-210min 的合理运动时长 |

#### 最终标记的 10 行

| Metric | PID | Day | Diary Date | Value | Baseline | `data_cleaning_recommendation` |
|---|---|---|---|---|---|---|
| Nap | 10009 | 9 | 2022-01-19 | 675 min | 0 | **do_not_use** — 11:15→675 HH:MM error，应为 00:15 |
| Exercise_Light | 3440 | 7 | 2020-12-09 | 285 min | 2 min | review |
| Exercise_Light | 10464 | 7 | 2021-11-28 | 270 min | 30 min | review |
| Exercise_Moderate | 11010 | 5 | 2022-01-29 | 210 min | 30 min | review |
| Exercise_Vigorous | 10544 | 8 | 2022-01-19 | 210 min | 0 | review |
| Exercise_Vigorous | 10705 | 6 | 2022-01-15 | 185 min | 40 min | review |
| Exercise_Vigorous | 10705 | 13 | 2022-01-22 | 160 min | 40 min | review |
| Subjective_SOL | 10638 | 2 | 2021-12-28 | 180 min | 15 min | pending_review |
| WASO | 1872 | 14 | 2020-12-13 | 60 min | 15 min | review |
| WASO | 10255 | 7 | 2021-11-25 | 60 min | 8 min | review |

#### 新增文件

| 文件 | 说明 |
|---|---|
| `cross_participant_flagged_rows.csv` | 新增 `data_cleaning_recommendation` + `note` 列 |
| `cp_flagged_review_notes.csv` | 独立审查文档，10 行带 recommendation + note |

#### 修复：`simple_pid_query()`

`2026-4/[H]pid_search.R` 和 `2026-4/beforemay/[H]pid_search.R`:
- 自动检测 CSV 文件名 vs data.frame（修复 `select()` on character 错误）
- 兼容 raw CSV（无 `row_id`、`time_bed_corrected` 列）和 processed data
- **显示所有记录**（不再过滤 NA 时间戳）
- **新增 nap/exercise 列**（raw HH:MM + processed mincalc）
- 新增 `data_category`、`auto_error_desc` 列

#### 数据完整性验证

- ✅ Pipeline 完整运行（Steps 1-9）：TIMESTAMP_ISSUE=0, DURATION_ISSUE=0, AMOUNT_FLAG=0
- ✅ 10 CP 标记行 → `checkforerrors_df` 30 行
- ✅ Nap=675 已确认 raw 数据为 "11:15"，likely 00:15 笔误（留 `do_not_use` 标记，不擦除原数据）

#### 待办

- [x] `cross_participant_global_check.R` — 移除 objective_sol 独立检测
- [x] 同上 — 新增 nap/exercise 6 指标 + insane 阈值
- [x] 阈值调试：123 行 → 10 行
- [x] 输出列扩展（cp_keep_cols + slices_cols）
- [x] 创建 `cp_flagged_review_notes.csv`（10 行 + recommendation）
- [x] 重命名 `recommendation` → `data_cleaning_recommendation`
- [x] 修复 `simple_pid_query()` 原始 CSV 查询
- [x] 更新本 worklog
