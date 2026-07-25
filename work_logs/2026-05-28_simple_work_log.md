# 2026-05-28 工作日志（技术简版）

## 核心目标

本次工作的核心不是单纯降低 Figure 18 的数字，而是先区分两类不同层级的数据质量问题：

1. `_checkforerrors` flag  
   这是 timestamp / interval parser 在原始变量处理阶段产生的格式或解析标记。它主要说明某个原始输入值是否被 parser 认为有格式问题或无法可靠解析。

2. Figure 18 / `review_output$checkforerrors_df`  
   这是 `checkforerrors_processing.R` 在后续阶段综合 temporal logic、computed sleep metrics、manual corrections、manual acceptances 后生成的 review list。它不等同于 `_checkforerrors=TRUE`。

因此，本轮工作先清理 parser-level `_checkforerrors` flag，再解释 Figure 18 中剩下的 temporal / metric review rows。

## 1. AM/PM heuristic false positives 清理

早期 `_checkforerrors` 中有大量 AM/PM heuristic 标记，例如：

- `evening var h<6 marked AM (likely PM)`
- `morning var h>3 marked PM (likely AM)`

这些标记来自 `process_timestamp_emadatarelease_cyra.R` 中 timestamp parser 的启发式判断。但在 sleep diary 中，凌晨 1:00-5:59 的 bed/sleep time 可能是真实 AM，早晨 4:00-11:59 的 awake/getup time 也可能是真实 AM。因此这些 heuristic 会制造大量 false positives。

本轮修改：

- 在 `process_timestamp_emadatarelease_cyra.R` 中移除上述 AM/PM heuristic error flag 生成逻辑。
- 保留真正的数据 normalization / correction 逻辑，例如 h=12 相关转换。
- 在 `checkforerrors_processing.R` 中删除旧的 `uncertainty_patterns` 过滤逻辑，因为上游不再生成这些 heuristic warning。
- 更新 Part A 注释，使其只处理真正 unresolved 或 structural 的 `_checkforerrors`。

结果：

- timestamp-format 类 false positives 被移除。
- 后续 pipeline 重跑中 `TIMESTAMP_ISSUE = 0`。

## 2. Interval parser 与 `_mincalc` 修复

第二个主要问题是 interval duration 的 `_mincalc` 解析。

典型问题：

- exercise duration 中 `08:00` 被 parser 当作 8 小时，得到 480 min；但实际可能是 8 min。
- `6:30` 被 parser 当作 390 min；在部分 exercise 上下文中可能是 6 分 30 秒，即 6.5 min。
- `12:30` 被 parser 当作 750 min；在部分 exercise 上下文中可能是 12.5 min。
- SOL/WASO 中 `10:30` 被解析成 630 min；但更像 10 分 30 秒，即 10.5 min。
- malformed zero/minute values 例如 `00:000`、`000:45` 原本会进入 `colon but wrong format`，导致 `_mincalc = NA` 和 `_checkforerrors=TRUE`。

技术决策：

- 不把所有 exercise duration 全局强制按 MM:SS 解析。
- 原因是 `6:30` 这类值有语义歧义：可能是 6.5 min，也可能是真实 6.5 h。
- 采用三层结构：
  1. `process_interval.R` 保持通用 parser。
  2. `checkforerrors_processing.R` Part A3 用 structural rules flag 异常值，例如 exercise > 360 min、nap > 720 min、unresolved parse error。
  3. Step 6.5 用 manual correction table 处理人工确认的 duration correction。

### SOL/WASO MM:SS threshold conversion

在 `process_interval.R` 中，对以下字段加入 MM:SS threshold conversion：

- `duration_totalmin_sol_estimate_am`
- `duration_totalmin_waso_estimate_am`

规则：

- 如果 HH:MM 解析结果大于等于 240 min；
- 且 hour/minute 形态符合 MM:SS；
- 则按 `minutes + seconds / 60` 解释。

例子：

- `10:30`: 原本 630 min，现在解释为 10.5 min。
- `05:00`: 原本 300 min，现在解释为 5 min。

同时保留 audit note：

- `sleep metric duration MM:SS threshold conversion`

### malformed colon edge cases

在 `process_interval.R` 的 Branch 3 中加入精确规则。该分支处理 “has colon but does not match clean `dd:dd`” 的格式。

新增规则：

- `00:000` -> `00:00`, `_mincalc = 0`
- `000:45` -> `00:45`, `_mincalc = 45`
- 更一般地，`000:dd` -> `00:dd`

新增测试文件：

- `tests/test_process_interval_colon_edgecases.R`

测试覆盖：

- `00:000` 应 normalize 为 `00:00`，mincalc 为 0，不再 flag。
- `000:45` 应 normalize 为 `00:45`，mincalc 为 45，不再 flag。

验证：

- edge case 测试通过。
- 全 pipeline 重跑后，`_checkforerrors == TRUE` cell total 从 7 降到 0。

## 3. Step 6.5：duration manual correction 架构

本轮在 `00_MAIN_entry.R` 中加入 Step 6.5，使 timestamp correction 和 duration correction 分开。

更新后的流程：

1. Step 6: apply timestamp manual corrections
2. Step 6.5: apply duration manual corrections
3. Step 7: calculate sleep variables
4. Step 8: run auto error detection / Figure 18 review

Step 6.5 包含：

### `apply_nap_exercise_corrections.R`

- 读取 `manual_nap_exercise_corrections.csv`。
- 应用人工确认的 nap/exercise duration corrections。
- 更新对应 raw/mincalc 值。
- 已确认修正的记录可标记为 `manually_corrected=TRUE`。
- 当前读取 29 条 correction records。
- 实际应用 9 条。
- 跳过 20 条 review-only / temporal_issue / `manually_corrected=FALSE` 记录。

代表性 correction：

- pid 1527 day 2: Moderate `0:208333333` -> 12.5 min
- pid 9616 day 3: Moderate `0:041666667` -> 2.5 min
- pid 3299 day 8: Light `08:00` -> 8 min
- pid 6153 day 1/2/12: Light `6:30` -> 6.5 min
- pid 9267 day 10/12: Light `12:30` -> 12.5 min

### `apply_sleep_metric_duration_corrections.R`

- 读取 `manual_sleep_metric_duration_corrections.csv`。
- 用于 SOL/WASO duration correction。
- 当前该表有 22 条：
  - 16 条 SOL duration correction
  - 1 条 WASO duration correction
  - 5 条 `sleep_time_sequence` review-only / unresolved rows
- 如果 parser 已经通过 MM:SS threshold conversion 正确处理，则跳过旧 manual override，避免覆盖 parser-derived value。

### `apply_metric_review_acceptances.R`

- 读取 `manual_metric_review_acceptances.csv`。
- 用于标记人工确认合理的 metric warnings。
- 配合 `checkforerrors_processing.R` Part C2 suppress repeated metric warnings。

## 4. `checkforerrors_processing.R` 更新

本轮对 `checkforerrors_processing.R` 的主要更新包括：

- Part A 不再把 AM/PM heuristic warning 当作 timestamp issue。
- 排除 non-sleep-relevant `_checkforerrors` columns，例如 exercise、nap、substance timestamp 的大量格式性假阳性。
- 使用 Part A3 对 nap/exercise 做 structural check：
  - negative value
  - excessive nap > 720 min
  - excessive exercise > 360 min
  - unresolved parse error
- Part B 从已有 `error_type` / `unusual_type` 导入 temporal rows。
- Part C 检查 computed sleep metrics：
  - SOL excessive / negative
  - sleep efficiency negative / >100
  - TST/TIB ratio very_low / exceeds_1
  - SOL/WASO duration input 是否可信
- Part C2 读取 `manual_metric_review_acceptances.csv`，suppress 人工确认合理的 metric warnings。

最新验证中：

- `TIMESTAMP_ISSUE = 0`
- `DURATION_ISSUE = 0`
- `AMOUNT_FLAG = 0`
- `_checkforerrors == TRUE = 0`

## 5. Manual metric review acceptances

本轮整理了 `manual_metric_review_acceptances.csv`。

用途：

- 有些 rows 会被 metric algorithm flag，但人工检查后认为 raw/corrected timestamp sequence 合理，不需要修改。
- 这些 rows 应被记录为 accepted，而不是每次 pipeline 都重新进入 review list。

当前表结构为 13 列：

- `pid`
- `day_num`
- `row_id`
- `time_bed_am_raw_display`
- `time_sleep_am_raw_display`
- `time_awake_am_raw_display`
- `time_getup_am_raw_display`
- `time_bed_corrected_display`
- `time_sleep_corrected_display`
- `time_awake_corrected_display`
- `time_getup_corrected_display`
- `human_metric_review_status`
- `human_metric_review_note`

当前记录数：

- 44 条人工 accepted metric warnings。

`checkforerrors_processing.R` Part C2 已兼容新表结构：

- 只要求 `pid` / `day_num` / `row_id` 作为匹配键。
- 读取 `human_metric_review_status` 和 `human_metric_review_note`。
- 如果没有旧的 pattern column，则默认按 SOL excessive 等 metric warning 处理。

## 6. Timestamp manual correction 个案

本轮继续处理了几条 first-step timestamp correction，写入 `manual_error_corrections.csv`。

### pid 2854 day 13 row_id 2303

问题：

- bed/sleep 经过 normalization 后接近 equal，但 AM/PM 方向不合理。
- raw awake 早于 getup，应恢复。

Correction：

- `time_bed_corrected, time_sleep_corrected` -> `Minus 12 hours`
- `time_awake_corrected` -> `Same day 10:45:00 AM`

验证：

- final bed/sleep: `2020-11-16 22:45`
- final awake/getup: `2020-11-17 10:45` / `2020-11-17 10:50`
- row 不再 flagged。

### pid 10846 day 12 row_id 12621

问题：

- `bed_sleep_diff_error`
- SOL excessive

人工判断：

- bed 应设为 sleep。
- bed=sleep 可接受。

Correction：

- `time_bed_corrected` -> `Plus 12 hours`
- `time_bed_corrected` -> `Same day 08:00:00 AM`

验证：

- final bed/sleep/awake/getup 均为 `2022-01-17 08:00`
- SOL = 0
- `data_category = equal_time_ok`
- row 不再出现在 review list。

### pid 10989 day 14 row_id 12826

问题：

- `bed_sleep_diff_error`
- SOL excessive

Correction：

- `time_bed_corrected` -> `Same day 11:00:00 AM`

验证：

- final bed/sleep: `2022-01-23 11:00`
- awake/getup: `2022-01-23 11:03`
- SOL = 0
- row 不再 flagged。

### pid 6805 day 1 row_id 7380

处理：

- 曾测试 first-step timestamp correction。
- 后来根据人工判断撤回。
- 从 `manual_error_corrections.csv` 删除。
- 在 `manual_sleep_metric_duration_corrections.csv` 中保留为 unresolved review-only case。

当前状态：

- `correction_type = unknown_how_to_correct_needs_human_review`
- `manually_corrected = FALSE`
- 不自动改 bed/sleep。

原因：

- `12:00 PM` 的 noon/midnight interpretation 仍有歧义，不能自动修正。

## 7. 最新 pipeline 验证结果

最新全 pipeline 重跑结果：

- Total records: **13,990**
- `_checkforerrors == TRUE` cell total: **0**
- `TIMESTAMP_ISSUE`: **0**
- `DURATION_ISSUE`: **0**
- `AMOUNT_FLAG`: **0**
- `CLEAN (Manually Fixed)`: **65**
- `review_output$checkforerrors_df`: **31 rows**

解释：

- parser-level `_checkforerrors` flag 已清零。
- Figure 18 剩余 31 rows 不是 parser `_checkforerrors` 问题。
- 剩余 rows 属于 temporal / metric 层面的 algorithmic review，需要后续逐条判断：
  - 是否需要 timestamp correction；
  - 是否应进入 manual metric acceptance；
  - 是否是合理异常；
  - 是否需要保留 unresolved。

## 总结

本轮工作的主要技术成果是将 parser-level `_checkforerrors` 和 Figure 18 algorithmic review 分离。我们清理了 AM/PM heuristic false positives，细化了 exercise interval 规则，修复了 SOL/WASO `_mincalc` 解析错误，并增加了 malformed interval edge case 处理。最终 `_checkforerrors == TRUE` 已降为 0。后续工作将集中在 Figure 18 中剩余的 31 条 temporal / metric review rows 上。
