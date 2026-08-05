# 输出列清单 —— 待审定

> **原则：这个文档是我们自行决策的依据。不改管线代码，先讨论确认。**
>
> 审核完成后，你会有一个明确的"final 输出列清单"和"需要改名/调整的列清单"。

---

## 输出策略（建议）

最终输出拆为两个文件 + 一个映射表：

| 文件 | 内容 |
|------|------|
| `cleaned_data_final.csv/rds` | 精选 25-35 列，分析用 |
| `cleaned_data_full.csv/rds` | 完整管线输出（100+ 列），追溯/调试用 |
| `column_map.csv` | 列间映射表（原始列→过程列→最终列） |

---

## 一、必须保留的列（提案，请逐项审定）

这些是任何人拿到数据后做分析都需要用到的。

### A. 标识与键

| 列名 | 来源 | 说明 | 审定 |
|------|------|------|:--:|
| `pid` | Step 1 | 参与者 ID | ⬜ |
| `day_num` | Step 1 | 研究天编号 | ⬜ |
| `row_id` | Step 4 | 行号（追溯用 key） | ⬜ |

### B. 最终时间值（已校正）

| 列名 | 来源 | 说明 | 审定 |
|------|------|------|:--:|
| `time_bed_corrected` | Step 4→6 | 最终上床时间（POSIXct） | ⬜ |
| `time_sleep_corrected` | Step 4→6 | 最终入睡时间（POSIXct） | ⬜ |
| `time_awake_corrected` | Step 4→6 | 最终醒来时间（POSIXct） | ⬜ |
| `time_getup_corrected` | Step 4→6 | 最终起床时间（POSIXct） | ⬜ |

### C. 核心睡眠指标（Step 7 计算）

| 列名 | 来源 | 说明 | 审定 |
|------|------|------|:--:|
| `self_diffcalc_sol_minutes` | Step 7 | SOL（入睡潜伏期，分钟） | ⬜ |
| `self_diffcalc_totalsleeptime_minutes` | Step 7 | TST（总睡眠时间，分钟）**主结果变量** | ⬜ |
| `self_diffcalc_timeinbed_minutes` | Step 7 | TIB（在床时间，分钟） | ⬜ |
| `self_diffcalc_sleepperiod_minutes` | Step 7 | 睡眠期（adjusted sleep onset 到醒来） | ⬜ |
| `self_diffcalc_totaltrysleep_minutes` | Step 7 | 尝试入睡总时长（SE 分母） | ⬜ |
| `self_diffcalc_sleepefficiency_percent` | Step 7 | 睡眠效率（0-1 比例）⚠ **命名误导：实际是 fraction** | ⬜ |
| `avg_waso_estimate_am_minutes` | Step 7 | 平均 WASO 片段时长 | ⬜ |

### D. 修正追踪列（谁能回答"这条被改过吗？"）

| 列名 | 来源 | 说明 | 审定 |
|------|------|------|:--:|
| `corrected` | Step 4 | 算法自动修正（AM/PM 翻转、时间对调） | ⬜ |
| `correction_type` | Step 4 | 算法修正类型文本（如 `"sleep_reduce_12h_loop"`） | ⬜ |
| `manually_corrected` | Step 6/8 | 人工通过 CSV 修正 | ⬜ |
| `is_reasonable_unusual` | Step 6 | 人工看过标记为"合理异常" | ⬜ |

> **待建新列：** `has_correction` = `corrected | manually_corrected`（一键知道是否被改过）

### E. 分类与标记

| 列名 | 来源 | 说明 | 审定 |
|------|------|------|:--:|
| `data_category` | Step 6 | ❌ **会议决定删除** — 内部标签 | — |
| `is_error` | Step 6 | 是否 error（待移除/已修正） | ⬜ |
| `error_type` | Step 6 | 具体错误类型文本 | ⬜ |
| `is_unusual` | Step 6 | 是否异常模式 | ⬜ |
| `unusual_type` | Step 6 | 异常类型文本 | ⬜ |
| `equal_time_type` | Step 6 | 哪些时间对相等 | ⬜ |
| `flag_severity` | viz 层→待提升 | Clean / Minor / Major（基于 SOL/SE/WASO 阈值） | ⬜ |

### F. 自动检测标记（Step 8）

| 列名 | 来源 | 说明 | 审定 |
|------|------|------|:--:|
| `needs_review_flag` | Step 8 | 综合 flag（任何问题） | ⬜ |
| `auto_error_desc` | Step 8 | 所有问题的文本描述 | ⬜ |
| `caffeine_value_checkforerrors` | Step 8 | 咖啡因输入异常 | ⬜ |
| `alcohol_value_checkforerrors` | Step 8 | 酒精输入异常 | ⬜ |
| `nicotine_value_checkforerrors` | Step 8 | 尼古丁输入异常 | ⬜ |
| `cannabis_value_checkforerrors` | Step 8 | 大麻输入异常 | ⬜ |

### G. 物质使用量

| 列名 | 来源 | 说明 | 审定 |
|------|------|------|:--:|
| `caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1` | Step 1 | 咖啡因摄入量 | ⬜ |
| `alcoholtoday_PM_NumAlcoholicDrinks_1` | Step 1 | 酒精摄入量 | ⬜ |
| `nicotine_amount_pm_doses` | Step 1 | 尼古丁摄入量 | ⬜ |
| `cannabis_amount_pm_doses` | Step 1 | 大麻摄入量 | ⬜ |

### H. 时长（mincalc）

| 列名 | 来源 | 说明 | 审定 |
|------|------|------|:--:|
| `duration_totalmin_sol_estimate_am_mincalc` | Step 3 | SOL 参与者自估（分钟） | ⬜ |
| `duration_totalmin_waso_estimate_am_mincalc` | Step 3 | WASO 参与者自估（分钟） | ⬜ |
| `num_waso_estimate_am` | Step 1 | WASO 片段数 | ⬜ |

### I. 公共契约列（promoted from viz → Step 7）

| 列名 | 当前位置 | 值 | 审定 |
|------|----------|-----|:--:|
| `sleep_duration_h` | viz 层 | TST（小时）= `self_diffcalc_totalsleeptime_minutes / 60` | ⬜ |
| `sol_h` | viz 层 | SOL（小时）= `self_diffcalc_sol_minutes / 60` | ⬜ |
| `waso_h` | viz 层 | WASO（小时） | ⬜ |
| `sleep_efficiency_pct` | viz 层 | SE × 100（真正的百分比 0-100） | ⬜ |
| `time_in_bed_h` | viz 层 | TIB（小时） | ⬜ |

---

## 二、保留在 full 但不进 final 的列（供追溯）

### J. 原始时间字符串（hhmm + ampm）

| 列名 | 说明 | 审定 |
|------|------|:--:|
| `time_bed_am_hhmm` / `time_bed_am_ampm` | 原始输入（上床） | ⬜ |
| `time_sleep_am_hhmm` / `time_sleep_am_ampm` | 原始输入（入睡） | ⬜ |
| `time_awake_am_hhmm` / `time_awake_am_ampm` | 原始输入（醒来） | ⬜ |
| `time_getup_am_hhmm` / `time_getup_am_ampm` | 原始输入（起床） | ⬜ |
| `caffeinetoday_PM_hhmm` / `caffeinetoday_PM_ampm` | 咖啡因时间 | ⬜ |
| `alcoholtoday_PM_hhmm` / `alcoholtoday_PM_ampm` | 酒精时间 | ⬜ |
| `nicotine_amount_pm_hhmm` / `nicotine_amount_pm_ampm` | 尼古丁时间 | ⬜ |
| `cannabis_amount_pm_hhmm` / `cannabis_amount_pm_ampm` | 大麻时间 | ⬜ |
| `StartDate` | 问卷日期字符串 | ⬜ |

### K. 解析后 POSIXct 时间

| 列名 | 说明 | 审定 |
|------|------|:--:|
| `time_bed_am_hhmm_ampm` | 解析后上床 POSIXct | ⬜ |
| `time_sleep_am_hhmm_ampm` | 解析后入睡 POSIXct | ⬜ |
| `time_awake_am_hhmm_ampm` | 解析后醒来 POSIXct | ⬜ |
| `time_getup_am_hhmm_ampm` | 解析后起床 POSIXct | ⬜ |

### L. 解析/修正标记

| 列名 | 说明 | 审定 |
|------|------|:--:|
| `time_bed_am_checkforerrors` 等 8 列 | Step 2 解析警告 | ⬜ |
| `duration_totalmin_sol_estimate_am_checkforerrors` 等 7 列 | Step 3 间隔解析警告 | ⬜ |
| `duration_totalmin_sol_estimate_am_correctionsmade` 等 7 列 | Step 3 修正日志 | ⬜ |
| `has_na` | 是否有 NA 时间 | ⬜ |
| `caffeine_input_anomaly` / `alcohol_input_anomaly` / ... | Step 8 异常类型文本 | ⬜ |

### M. 合理性标记（Step 6）

| 列名 | 说明 | 审定 |
|------|------|:--:|
| `order_correct` | bed<sleep<awake<getup | ⬜ |
| `reasonable_temporal_order` | 同 order_correct（人类可读名） | ⬜ |
| `reasonable_sleep_latency` | 入睡潜伏期 ≤7h | ⬜ |
| `reasonable_time_in_bed_after_waking` | 醒来到起床 ≤7h | ⬜ |
| `reasonable_sleep_duration` | 睡眠时长 ≤24h | ⬜ |
| `bed_sleep_diff_h` / `sleep_awake_diff_h` / `awake_getup_diff_h` | 时间差（小时） | ⬜ |
| `bed_sleep_equal` / `awake_getup_equal` | 时间对是否相等 | ⬜ |
| `sleep_awake_suspicious` / `bed_sleep_suspicious` / `awake_getup_suspicious` | 可疑标记 | ⬜ |

### N. Step 8 review 列（checkforerrors_summary 里的）

| 列名 | 说明 | 审定 |
|------|------|:--:|
| `sol_category` | SOL 分类文本 | ⬜ |
| `se_category` | SE 分类文本 | ⬜ |
| `se_is_insane_negative` | SE < -1000 | ⬜ |
| `tst_tib_ratio_category` | TST/TIB 比值分类 | ⬜ |
| `sleep_awake_diff_min` | 睡眠期（分钟） | ⬜ |

### O. 不应出现在任何输出中的（中间过程）

| 列名 | 说明 | 审定 |
|------|------|:--:|
| `time_bed_manual` / `time_sleep_manual` / `time_awake_manual` / `time_getup_manual` | Step 6 人工修正暂存列 | ⬜ 应排除 |
| `num_waso_am` | 与 `num_waso_estimate_am` 重复 | ⬜ |
| 所有 `exercisetoday_PM_totalmin_*` 原始字符串 | 改为只保留 `_mincalc` + `_correctionsmade` | ⬜ |
| `duration_totalmin_napstoday_PM` 原始字符串 | 同上 | ⬜ |

---

## 三、有待决策的问题

### Q1: `self_diffcalc_sleepefficiency_percent` 命名误导

列名叫 `percent` 但存的是 0-1 比例，真正百分比 `sleep_efficiency_pct` 在 viz 层。建议：

| 选项 | 说明 |
|------|------|
| A | 重命名 `self_diffcalc_sleepefficiency_percent` → `self_diffcalc_sleepefficiency_fraction` |
| B | 不改名，只在 SCHEMA.md 说明 |
| **审定** | ⬜ A / ⬜ B |

### Q2: `data_category` 从 final 移除 → 用什么替代分类信息？

| 选项 | 说明 |
|------|------|
| A | 不提供替代，用 `is_error` + `is_unusual` + `corrected` 等组合判断 |
| B | 保留但改名（如 `record_status`）并精简取值 |
| C | 新建一列 `record_status` 合并关键信息 |
| **审定** | ⬜ A / ⬜ B / ⬜ C |

### Q3: viz 层 flag 列要不要提升到 final？

列：`flag_duration_extreme`, `flag_poor_efficiency`, `flag_high_sol`, `flag_high_waso`, `flag_issue_count`, `flag_severity`

当前在 viz 层才计算。如果保留：需要迁移到 Step 7/8；否则：只在 full 里有。

| 选项 | 说明 |
|------|------|
| A | `flag_severity` 提升到 final，其余留在 viz/full |
| B | 全部提升到 final |
| C | 全部留在 full（final 不需要） |
| **审定** | ⬜ A / ⬜ B / ⬜ C |

### Q4: 列名太长 —— 要不要统一缩短？

如 `self_diffcalc_totalsleeptime_minutes` → `tst_minutes`，`caffeinetoday_PM_NumCaffeinatedDrinksSnacks_1` → `caffeine_count`

| 选项 | 说明 |
|------|------|
| A | 保留原名（不引入改名风险） |
| B | final 输出用短名，full 保留原名 |
| C | 全部改为短名（需全管线统一） |
| **审定** | ⬜ A / ⬜ B / ⬜ C |

### Q5: `has_correction` 和 `correction_type` 合并

当前：
- `corrected` (Step 4) = 算法修正
- `correction_type` (Step 4) = 算法修正类型字符串
- `manually_corrected` (Step 6) = 人工修正

建议新增一个统一的列：

```r
has_correction = corrected | manually_corrected       # 任何修正
correction_source = case_when(                         # 修正来源
  corrected & manually_corrected ~ "both",
  corrected ~ "algorithmic",
  manually_corrected ~ "manual",
  TRUE ~ "none"
)
```

| 选项 | 说明 |
|------|------|
| A | 新增合并列 + 保留原有列 |
| B | 只新增合并列，删原有列 |
| C | 不要合并列，沿用原有列 |
| **审定** | ⬜ A / ⬜ B / ⬜ C |

### Q6: 原始 RDS 里的数百 EMA 列（mood, stress, context…）

| 选项 | 说明 |
|------|------|
| A | 全部保留在 full（不影响 final） |
| B | 只保留已确认要用的，其余删 |
| **审定** | ⬜ A / ⬜ B |

---

## 四、执行步骤（审定后）

1. 你审定每项 → 我生成**明确列清单**
2. 写一个 `finalize_columns()` 函数：
   - 输入：`corrected_ema_data` + `checkforerrors_processed`
   - 输出：`cleaned_data_final`（精选列）+ `cleaned_data_full`（全列）
   - 生成 `column_map.csv`
   - 不修改管线代码
3. Figure 改造基于新列名

---

> **现状：代码一行没改。等你审定每项后再说。**
