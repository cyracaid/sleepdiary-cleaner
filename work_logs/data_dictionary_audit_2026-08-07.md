# Data Dictionary 审计 — 2026-08-07

审计对象：`proj_splclean/manual_inputs/data_dictionary.md`（splsleep v1.4.0 计划）
审计方法：**不只读文档，逐条对照 `splsleep` 仓库当前代码验证**。下文每个结论都注明了代码行。

---

## Summary verdict: **FAIL** — Dataset A 对睡眠-情绪研究是 **incomplete**

Dataset A 能支撑 10 个分析里的 8 个。但研究背景明确列出的**四类核心 discrepancy 中有两类无法计算**，
而且其中一类已有一张图声称在计算它、实际算的是别的东西。

命名上有一组列名与其内容**语义相反**，会主动误导使用者。

---

## Issue 1（阻断级）：WASO discrepancy 无法计算 —— 管线从不从时间戳计算 WASO

研究目标第 4 条是 "how many times they think they woke up vs. what the timestamps imply"。

**Dataset A 里两个 WASO 列都是自报侧：**

| A # | 列 | 实际来源 |
|---|---|---|
| 16 | `waso_selfreport_minutes` | `duration_totalmin_waso_estimate_am_mincalc` —— 解析后的自报值 |
| 14 | `waso_avg_minutes` | `duration_totalmin_waso_estimate_am_mincalc_used ÷ num_waso_estimate_am`（`calculate_sleep_time_end.R:218-220`）—— **自报时长 ÷ 自报次数** |

`waso_avg_minutes` 名字像是个客观量，实际分子分母**双方都是自报**。

**全表 140 列里没有任何一个从时间戳导出的 WASO。** 这不是分配错了目的地——它不存在。
`waso_h`（第 118 行 → Full）只是 `duration_totalmin_waso_estimate_am_mincalc / 60`，仍是自报。

**更要紧的是 Figure 20B 声称在做这件事，但算错了量。**
`sleep_visualization.R:2178-2180`：

```r
obj_waso <- as.numeric(difftime(time_getup_corrected, time_awake_corrected, units = "mins"))
```

`getup − awake` 是**最终醒来之后赖床的时长**，不是 WASO。
WASO（Wake After Sleep Onset）按定义是**睡眠期之内**的清醒时间，即 sleep onset 与最终 awakening 之间。
这张图现在把"自报 WASO"和"早晨赖床时长"放在一起比，标题写 "WASO Perception Bias"。

**这是审计中唯一一个会导致错误科学结论的问题。**

**需要做的：** 先决定 WASO 能不能从现有时间戳算出来。
以当前四个时间戳（bed / sleep / awake / getup）**算不出来**——
中途醒来的时刻根本没有被采集。若确实如此，那么：
1. 承认 WASO 只有自报，Dataset A 里去掉 `waso_avg_minutes` 的客观暗示，改名为 `waso_avg_bout_selfreport_minutes`
2. Figure 20B 要么删掉，要么改标题为 "Post-awakening time in bed vs self-reported WASO"，明确它不是 WASO 对比

---

## Issue 2（阻断级）：Nap discrepancy 无法计算

研究目标第 3 条 "participant reports a nap but the timestamps don't align"。

Dataset A 有 `nap_selfreport_totalminutes`（#18），只有**时长**。
全表里**没有任何小睡时间戳**——`duration_totalmin_napstoday_PM`（第 25 行）是时长字符串，
不存在 `nap_start` / `nap_end`。

**没有小睡的发生时刻，就无法判断"与时间戳是否对齐"。** 这个研究目标当前不可达，
且不是列分配问题，是数据采集层面的缺口。**建议在文档里显式记为"数据不支持"**，
免得下游分析者花时间去找不存在的列。

---

## Issue 3（严重）：四个 `*_selfreport_ts` 列名与内容语义相反

| A # | 列名 | 实际是什么 |
|---|---|---|
| 4 | `bedtime_selfreport_ts` | `time_bed_corrected` —— **算法 + 人工修正之后**的值 |
| 5 | `sleeponset_selfreport_ts` | `self_diffcalc_sleeponset` —— 同上 |
| 6 | `awakening_selfreport_ts` | `time_awake_corrected` —— 同上 |
| 7 | `getup_selfreport_ts` | `time_getup_corrected` —— 同上 |

这四列**恰恰是被修改过的值**，81 条记录经过人工修正、更多经过算法修正。
叫 `selfreport` 说的是反话。一个新分析者会理直气壮地把它当作"参与者原始上报"来用。

真正的自报原值在 `time_bed_am_hhmm_ampm` 等（第 33-36 行），只进了 Dataset B 的 `*_precorrection`。

**建议改名：** `bedtime_final_ts` / `sleeponset_final_ts` / `awakening_final_ts` / `getup_final_ts`，
或直接沿用 `*_corrected_ts`。**在 v1.4 冻结前改，改了就再没机会。**

---

## Issue 4（严重）：`sol_minutes` 与 `sol_selfreport_minutes` 并排，但没说哪个是算的

| A # | 列 | 含义 |
|---|---|---|
| 9 | `sol_minutes` | `self_diffcalc_sol_minutes` —— 从时间戳计算 |
| 15 | `sol_selfreport_minutes` | 参与者估计 |

第 1 类核心 discrepancy（SOL 自报 vs 计算）**是可以做的**——两列都在。
但命名不对称：一个显式标 `selfreport`，另一个什么都不标。
使用者看到 `sol_minutes` 无法确定它是"总的 SOL"还是"计算的 SOL"。

**建议：** `sol_computed_minutes` vs `sol_selfreport_minutes`。成对的量应当成对命名。

同理适用于 `tst_minutes`（#8）——它也是计算值，但没有自报对照，所以问题较轻。

---

## Issue 5（中等）：`record_status` 在管线里不存在

字典第 140 行标 `**new**`，Dataset A 第 29 行把它列为交付列。

实测：`grep -r record_status` 在 `splsleep` 全部 `.R` 文件中 **0 处命中**。

这列还没写。字典对此是诚实的（标了 new），但 Dataset A 的表格没有区分
"已存在"和"待实现"，读者会以为 36 列都已就绪。

**已存在并验证过的：** `has_correction`（`calculate_sleep_time_end.R:240`，
取值确为 `none`/`algorithmic`/`manual`/`both`，与字典一致 ✓）、
`is_reasonable_unusual`（`error_unusual_sleep_time_corrections.R:1561` ✓）、
`time_in_bed_h`（`calculate_sleep_time_end.R:237` ✓）。

**建议：** Dataset A 表格加一列"状态"，区分 `已实现` / `待实现`。

---

## Issue 6（中等）：`self_diffcalc_sleeponset` 是 `time_sleep_corrected` 的纯别名，字典当成两列

`calculate_sleep_time_end.R:131`：

```r
mutate(self_diffcalc_sleeponset = time_sleep_corrected)
```

**一模一样，没有任何计算。** 但字典把它们当作两个不同的列：

- 第 73 行 `time_sleep_corrected` → **Full only**
- 第 105 行 `self_diffcalc_sleeponset` → **A + B**，且标注 "Step 7"

结果是：同一个值以两个名字存在，其中一个被标为 Step 7 产物（实为 Step 4），
而真正的源列被降级到 Full。Dataset A 拿到的值是对的，但**溯源信息是错的**——
有人想回答"sleep onset 是哪一步定下来的"，字典会把他指到 Step 7。

**建议：** 要么在管线里删掉这个别名，要么在字典里注明 "alias of `time_sleep_corrected` (Step 4)"。

---

## Issue 7（中等）：Dataset B 缺 `row_id`，与 A 的连接可能不唯一

- Dataset A 有 `row_id`（#3，注为 "Traceability key"）
- Dataset B **没有**（13 列里只有 `pid` + `day_num`）

若同一 `pid` 在同一 `day_num` 下存在多条记录，`A ⋈ B on (pid, day_num)` 会产生多对多。
管线内部一直用 `(pid, day_num, row_id)` 三元组做匹配
（见 `checkforerrors_processing.R:682`：`data$pid == rec$pid & data$day_num == rec$day_num & data$row_id == rec$row_id`），
说明**开发者自己认为两元组不足以唯一定位**。

**建议：** Dataset B 加入 `row_id`，与 A 保持同一主键。成本一列，消除整类连接歧义。

---

## Issue 8（中等）：物质使用只有数量进了 A，时刻留在 Full

Dataset A #32-35 是 `caffeine_num` / `alcohol_num` / `nicotine_doses` / `cannabis_doses`。
对应的**摄入时刻** `caffeinetoday_PM_hhmm_ampm` 等（第 37-40 行）全部 → Full。

问题 (e) "substance use counts correlate with sleep disruption" 能做。
但睡眠研究里更有解释力的问题是**"睡前几小时摄入"**——
`caffeine_num = 2` 在下午两点和在晚上十点是完全不同的暴露。

**建议：** 与其把四个 POSIXct 原样搬进 A，不如在 Step 7 派生四个
`hours_before_bed_caffeine` 之类的数值列。这比时间戳更直接可用，
且不增加 A 的时间戳列数。

---

## 逐题结论（对照审计提示的 10 个分析）

| | 分析 | 可行 | 说明 |
|---|---|---|---|
| a | 自报 SOL vs 计算 SOL | ✅ | A#9 + A#15。命名需改进，见 Issue 4 |
| b | 自报 WASO vs 计算 WASO | ❌ | **计算侧不存在**，见 Issue 1 |
| c | 四个时间戳的修正位移 | ✅ | Dataset B 全有 pre/post。溯源标注有误，见 Issue 6 |
| d | 小睡 vs 睡眠质量 | ⚠️ | 时长相关可做；**小睡 discrepancy 不可做**，见 Issue 2 |
| e | 物质使用 vs 睡眠中断 | ⚠️ | 数量可做；**时刻不在 A**，见 Issue 8 |
| f | 运动强度 vs SOL | ✅ | A#19-22 + A#9 |
| g | 算法修正 vs 人工修正 | ✅ | `has_correction` 已实现并验证 |
| h | 未解决的质量问题 | ✅ | `needs_review` + `flag_severity` + `is_error` / `is_unusual` |
| i | 追踪个体跨天 | ✅ | `pid` + `day_num` + `row_id` |
| j | 真实日历时间轴 | ⚠️ | `StartDate` 是 **character**（A#36），需自行解析。建议交付前转 Date |

**8 项可行，2 项阻断（b、d 的 discrepancy 部分）。**

---

## 冗余检查

| 问题 | 结论 |
|---|---|
| `tst_minutes` / `sleep_duration_h` / `self_diffcalc_totalsleeptime_minutes` | 同一量（后者 = 前者 ÷ 60）。**只有 `tst_minutes` 进 A** ✅ 处理正确 |
| `sol_minutes` / `sol_h` | 同一量。**只有 `sol_minutes` 进 A** ✅ |
| `num_waso_am` / `num_waso_estimate_am` | 字典已判为重复并排除 ✅ |
| **新发现** `self_diffcalc_sleeponset` / `time_sleep_corrected` | **完全相同**，字典当成两列，见 Issue 6 |
| `se_percent`(A) / `self_diffcalc_sleepefficiency_percent`(Full) | 前者 = 后者 × 100。分工正确，但注意后者名叫 percent 实为 0–1 分数——这是 column_review 的 Q1，**字典没有解决它，只是把它藏进了 Full** |

---

## 结构性

**A ⋈ B：** 可连接，键为 `pid` + `day_num`，但**不保证唯一**（见 Issue 7）。加上 `row_id` 后无歧义。

**需要同时加载 B 和 Full 的场景：**
是的，至少一个——**"这条记录被哪种算法修正改动了"**。
Dataset B 给出位移量（pre → post），但**修正机制** `correction_type`
（第 77 行，取值如 `sleep_reduce_12h_loop`、`bed_sleep_swap_3h`）只在 Full。
想回答"12 小时环修正平均把 bedtime 推移了多久"，必须同时加载 B 和 Full。

**建议：** 把 `correction_type` 加进 Dataset B。它是修正溯源数据集，
"改了多少"和"用什么规则改的"应当在同一张表里。B 从 13 列变 15 列（含 row_id），
仍然轻量，但自足。

---

## 优先级建议

**冻结 v1.4 之前必须处理（改了就没机会）：**

1. **Issue 3** — 四个 `*_selfreport_ts` 改名。语义相反的列名是最难事后补救的
2. **Issue 4** — `sol_minutes` → `sol_computed_minutes`
3. **Issue 7** — Dataset B 加 `row_id`
4. **Issue 1 的命名部分** — `waso_avg_minutes` → `waso_avg_bout_selfreport_minutes`

**发布前应处理：**

5. **Issue 1 的图** — Figure 20B 改标题或删除。**这是唯一会导致错误科学结论的问题**
6. **Issue 5** — Dataset A 表格标注实现状态
7. **Issue 6** — 别名关系写进字典
8. **Issue 2** — 把"小睡 discrepancy 数据不支持"写进文档

**可延后：**

9. **Issue 8** — 物质摄入相对睡前时长的派生列
10. `correction_type` 加进 Dataset B
11. `StartDate` 转 Date 类型

---

## 审计方法说明

本审计对照的是 `splsleep` 仓库 commit `610572f` 的代码，非文档自述。
关键结论的验证点：

- `calculate_sleep_time_end.R:131` — sleeponset 别名
- `calculate_sleep_time_end.R:218-220` — waso_avg 双侧自报
- `calculate_sleep_time_end.R:240` — has_correction 已实现
- `sleep_visualization.R:2178-2180` — Figure 20B 的 obj_waso 定义
- `checkforerrors_processing.R:682` — 管线内部用三元组匹配
- `grep -r record_status *.R R/*.R` — 0 处命中
