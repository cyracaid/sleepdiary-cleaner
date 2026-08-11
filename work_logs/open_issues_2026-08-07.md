# splsleep 待决问题清单 — 2026-08-07

本文汇总 2026-08-05 → 08-07 讨论中发现的、**尚未解决**的问题。
每条注明证据行号、当前状态、以及需要谁来决定。

对照代码版本：`splsleep` commit `610572f`
参照实现：`R01_online_sleepdiary_manualclean` 的 `calculate_sleep_time_vars.R`

---

## 优先级总览

| 级别 | 数量 | 说明 |
|---|---|---|
| 🔴 阻断 | 0（B1、B2 均已结案） | 影响主要结局指标数值，必须先定 |
| 🟠 严重 | **1 未结**（S8 仅缓解，正式修法延后）<br>已结案：S1–S6<br>已评估决定不做：S7 | 影响数据交付可用性 |
| 🟡 中等 | 8 | 影响可理解性 / 可维护性 |
| ⚪ 已知债 | 6 | 记录在案，可延后 |

---

## 🔴 阻断级

### ~~B1~~ 已结案（2026-08-09）：`sleeponset` 不加自报 SOL

**参照实现**（截图第 49 行）：

```r
self_diffcalc_sleeponset = lubridate::minutes(duration_totalmin_sol_estimate_am_mincalc)
                           + time_sleep_am_hhmm_ampm
```

**splsleep 现状**（`calculate_sleep_time_end.R:131`）：

```r
mutate(self_diffcalc_sleeponset = time_sleep_corrected)   # 没有 + SOL
```

代码注释给的理由：`"should not be added here or SOL gets double-counted"`。

**连锁影响：**

```
sleepperiod = time_awake − sleeponset        （167 行，公式与参照一致）
TST         = sleepperiod − WASO             （192 行）
```

sleeponset 提前了「自报 SOL」那么多 → sleepperiod 变长 → **TST 变长同样多**。

按真实数据 Mean SOL = 28.8 min 估算：
**当前 Mean TST 7.71h，按参照算法应约为 7.23h —— 差约 29 分钟。**

**这不是估算误差，是系统性偏移，方向单一。**

**需要决定的是问卷原题的语义：**

| 若 `time_sleep_am` 问的是 | 则 | 谁对 |
|---|---|---|
| "你几点上床准备睡 / 熄灯" | 需要 + SOL 才到真正入睡时刻 | **参照实现对** |
| "你几点睡着的" | 已经是入睡时刻，再加 SOL 是重复 | **splsleep 现状对** |

**注意参照实现自身的内部张力：** 它第 47 行把 `time_sleep − time_bed` 算作 SOL
（`self_diffcalc_sol_minutes`），这个读法下 `time_sleep` 已是入睡时刻；
但第 49 行又给它加了一次自报 SOL。**两行对 `time_sleep` 的假设不一致。**
改 splsleep 的人很可能正是发现了这一点。

**决定人：** 需要查问卷原题，或问 Maia。这是本清单唯一一个**外部依赖**。

**在定下来之前，`tst_minutes` 不应作为 "primary outcome" 交付。**

---

### B2. TST 的 WASO 信任门 —— 偏离参照，且吃掉 1,127 条记录

**参照实现**（第 57 行）：

```r
self_diffcalc_totalsleeptime_minutes = self_diffcalc_sleepperiod_minutes
                                       - duration_totalmin_waso_estimate_am_mincalc
```

直接相减，无门。

**splsleep 现状**（`calculate_sleep_time_end.R:172-192`）：新增四道检查，
不通过则 `_used = NA_real_`，导致 `sleepperiod − NA = NA`：

| 检查 | 参照有吗 |
|---|---|
| WASO 缺失 | 行为相同（NA 传播） |
| 解析标记异常 `_checkforerrors` | ❌ 新增 |
| WASO > sleepperiod | ❌ 新增 |
| WASO < 0 | ❌ 新增 |

**样本量影响**（从 08-06 真实数据运行输出反推）：

| 量 | 数值 | 来源 |
|---|---|---|
| 有 awake + getup 时间戳 | 2,856 | Figure 20B `Objective WASO non-NA` |
| 自报 WASO 解析成功 | 1,730 | Figure 20B `Subjective WASO parsed` |
| **有效 TST** | **1,729** | 检查点 `Valid records` |

**1,729 ≈ 1,730 —— 有效 TST 数几乎精确等于自报 WASO 解析数。**
约 **1,127 条记录有完整时间戳，却因缺 WASO 而没有 TST。**

**待验证**（一条命令）：

```r
d <- readRDS("output/corrected_ema_data.rds")
sum(!is.na(d$time_awake_corrected) & !is.na(d$time_getup_corrected) &
    is.na(d$self_diffcalc_totalsleeptime_minutes))
table(d$waso_duration_for_metrics_status, useNA = "always")
```

**三个选项：**

| | 做法 | 后果 |
|---|---|---|
| a | 保持现状 | 诚实保守，主分析 n = 1,729 |
| b | 缺失按 0 处理 | n 涨到 2,856，但 TST 系统性高估，**不推荐** |
| c | 文档说明用 `sleepperiod_minutes` 兜底 | **零代码改动**。TST ≤ sleepperiod，差额即未知 WASO，可做敏感性分析 |

**建议 c。** 那 1,127 条并没有丢——`sleepperiod_minutes`（Dataset A #12）对它们有值，
是 TST 的上界。字典里把这层关系写清楚即可。

---

## 🟠 严重

### ~~S1~~ 已结案（2026-08-09）：Dataset A 缺「计算侧 WASO」，但该列已存在于 Full

> **已实施。** 字典新增 `awake_getup_diff_h → waso_computed_minutes`（`transform=x60`），
> 由 `verify_finalize_columns.R` 两条断言守住（存在 + 单位换算）。
> 真实数据实测见 `2026-08-09_work_log.md` §六。


研究目标之一是 WASO 的自报 vs 计算 discrepancy。**两侧的值都已存在**，只是计算侧没接进 A：

| | 列 | 位置 | 单位 |
|---|---|---|---|
| 自报侧 | `waso_selfreport_minutes` | ✅ Dataset A #16 | 分钟 |
| **计算侧** | **`awake_getup_diff_h`** | ❌ Full（字典第 93 行） | **小时** |

计算侧定义（`error_unusual_sleep_time_corrections.R:1447`）：

```r
awake_getup_diff_h = ifelse(!has_na,
    difftime(getup_corrected, awake_corrected, units = "hours"), NA_real_)
```

**这就是本研究操作定义下的 WASO（`getup − awake`）。**

**三个问题：**
1. 在 Full，Dataset A 内做不了 discrepancy 分析
2. 名字 `awake_getup_diff_h` 看不出是 WASO
3. **单位是小时，自报侧是分钟 —— 直接相减会差 60 倍**

**建议：** 提升到 Dataset A，命名 `waso_computed_minutes`，值 `= awake_getup_diff_h × 60`。

**同一个量在代码里有三个名字**，这是我审计时没认出它的原因：

| 位置 | 叫法 |
|---|---|
| `error_unusual_...R:1447` | `awake_getup_diff_h` |
| `error_unusual_...R:467`（注释） | "Calculated time-in-bed-after-waking" |
| `sleep_visualization.R:2166`（注释） | "客观 WASO" |

**建议统一为 WASO 口径**，因为那是本研究的操作定义。

---

### ~~S2~~ 已结案（2026-08-09，commit `239e858`）：两个不同的量共用 "WASO" 之名


本管线里有**两个不同的时间段**都被叫作 WASO：

```
 22:30      23:00                                     06:30      07:15
   │          │                                         │          │
  bed       sleep ────────── 睡眠期 ──────────────── awake ──── getup
              │◄── 自报 WASO 在这段之内 ───────────►│◄─ 相减值 ─►│
                                                              在这段之外
```

| | 测什么 | 位置 | 用在哪 |
|---|---|---|---|
| 自报 WASO | 夜里醒着多久 | 睡眠期**之内** | **算 TST**（192 行） |
| `getup − awake` | 醒后还躺多久 | 睡眠期**之外** | discrepancy 分析 |

**两者不能互相替代** —— TST 是「从睡眠期里减掉」，只能减掉在这段里面的量。
把 `getup − awake` 代进 TST 公式会减掉一个不在窗口内的时长。

**Figure 20B 把它们并列为「主观 WASO」vs「客观 WASO」**，
暗示是同一个量的两种测法。**这是唯一一处会导致读者误解的图。**

**建议：** 图标题与轴标签明确两者是不同时段，或改为
"Self-reported nighttime wakefulness vs post-awakening time in bed"。

---

### S3. `record_status` 尚未实现，但已列入 Dataset A

> **已结案（2026-08-09）**：`finalize_columns.R:77-109` 实现 `.RECORD_STATUS_MAP`
> （data_category → record_status 六档映射，未知档 `stop()`），Dataset A 交付
> `record_status` 列并写字典说明（EXCLUDE 'error'）。`verify_finalize_columns.R`
> 有断言守住状态列必须存在。CSV status 全列 implemented，无 pending。

- 字典第 140 行标 `**new**`
- Dataset A 第 29 行列为交付列，取值 `clean / error / unusual / equal_time / not_reported`
- 实测：`grep -r record_status *.R R/*.R` → **0 处命中**（当时）

**当时建议：** Dataset A 表格加「状态」列，区分 `已实现` / `待实现`。
读者现在会以为 36 列都已就绪。（随 `finalize_columns()` 落地而完成）

**已验证确实存在的：** `has_correction`（`calculate_sleep_time_end.R:240`，
取值 `none/algorithmic/manual/both`，与字典一致 ✅）、
`is_reasonable_unusual`（`error_unusual_...R:1561` ✅）、
`time_in_bed_h`（`calculate_sleep_time_end.R:237` ✅）。

---

### ~~S4~~ 已结案（2026-08-09）：Dataset B 缺 `row_id`，与 A 的连接可能不唯一

> **已实施。** B 加 `row_id`（15 列）。`verify_finalize_columns.R` 断言
> 「A ⋈ B on (pid, day_num, row_id) 行数不变」，testthat 同步一条。


- Dataset A 有 `row_id`（#3，注为 "Traceability key"）
- Dataset B 只有 `pid` + `day_num`

管线内部一律用三元组匹配（`checkforerrors_processing.R:682`）：

```r
data$pid == rec$pid & data$day_num == rec$day_num & data$row_id == rec$row_id
```

**开发者自己认为两元组不足以唯一定位。** A ⋈ B on (pid, day_num) 存在多对多风险。

**状态：已确认要改。** 成本一列。

---

### ~~S5~~ 已结案（2026-08-09）：snapshot 测试挡不住算法偏离

`verify_v1_3_snapshot.R` 比对的是 **splsleep 旧路径 vs splsleep 的 S3 链**
（脚本自述："The S3 chain is bit-identical to the old pipeline"）。

**它证明重构没改变结果，不证明 splsleep 忠实于参照实现。**
B1 的 sleeponset 偏离在 snapshot 建立之前就存在，两边都带着它，比对当然一致。

**建议：** 增加一个**对参照实现**的算式快照——把八个指标的算式（而非结果）
钉成测试。B1/B2 定案后加，否则会把当前的偏离一起钉死。

### ✅ 已结案（2026-08-09）：`verify_reference_fidelity.R`

详见 `2026-08-09_work_log.md` §九。**纯新增文件，管线零改动。**

```
默认模式    15 passed, 0 failed   4 identical, 4 deviating, 0 unreviewed
--strict    15 passed, 0 failed
```

- **Part 1 算式契约** —— 8 条算式 + 3 条守卫 + 3 条单位换算。
  改动 `calculate_sleep_time_end.R` 而不同步更新此脚本，构建即红
- **Part 2 保真登记** —— 对基线逐条比对完成：
  4 条相同；4 条偏离全部刻意且有文档（B1、B2 信任门、SE 除零守卫、bout 守卫）

**基线位置**（一度被我误判为「不在仓库」，实为按文件名检索失败）：

```
archive/2026-07-25/spl_pipeline_package_2026-05-19/splsleep/calculate_sleep_time_end.R
```

**保留：** 该文件是 splsleep 自己的 2026-05-19 祖先版本，不是上游
`R01_online_sleepdiary_manualclean`（截图第 49 行为 `+ time_sleep_am_hhmm_ampm`，
archive 为 `+ time_sleep_corrected`，同血统非同文件）。
**故本验证证明的是「算式未从起点漂移」，不是「忠实于上游」。**

`--strict` 现可进 CI。日后若取得上游文件，
用 `SPLSLEEP_REFERENCE_IMPL=` 换基线重跑并重新裁定登记表。

---

### S6. `correction_type` 在被人工覆盖后不失效 —— Dataset B 的溯源字段会说谎

> **已结案（2026-08-09）**：字典 `correction_type` description 已加
> "CAVEAT: records only the ALGORITHMIC action and is never rewritten when a
> later manual correction overrides it"。字段行为未变；
> 16 条 `has_correction = "both"` 的溯源歧义已在字典中显式声明。

**新增 2026-08-09。** 详细复盘见 `2026-08-09_work_log.md` §七。

`row_id 12078`：算法把 `sleep` 减了 12h（`sleep_reduce_12h_loop`），
人工把 sleep 改了回去、转而给 `bed` 加 12h。
**那次算法修正已被完全撤销，数据里没有它的痕迹，
`correction_type` 却至今写着 `sleep_reduce_12h_loop`。**

影响面：16 条 `has_correction = "both"` 的记录。

**这条直接打在 M6 上。** M6 把 `correction_type` 放进 Dataset B 是为了让 B 自足回答
"用什么规则改的"——对这 16 条，它给的答案是错的。

**建议：** 人工覆盖的行给 `correction_type` 加后缀（如 `+ manual_override`），
或在字典 description 中明写该字段仅记录算法动作、可能已被人工撤销。
**后者零代码改动，应先做。**

### S7. AM/PM 归一化规则会猜错「哪个时间戳错了」

**新增 2026-08-09。** 详细复盘见 `2026-08-09_work_log.md` §七。

`normalize_sleep_time_sequence.R:134`（4.1）与 `:158`（4.2）各自写死了假设：

> *"the user likely recorded **getup** with the wrong AM/PM"*（4.1）
> *"the user likely recorded **sleep** with the wrong AM/PM"*（4.2）

**规则只看一对时间戳，不拿另外两个当锚点交叉验证。**

全量筛查（`manually_corrected & corrected & correction_type 含 12h_loop`）共 3 条：

| row_id | 算法怪谁 | 实际错谁 | 人工是否改全 | 最终 |
|---|---|---|---|---|
| 8502 | getup | **awake** | ❌ 只改了 awake | `error` |
| 8827 | sleep | 原始值即垃圾（`awake = "0"`） | — | `error` |
| 12078 | sleep | **bed** | ✅ | `clean` |

**3 条里人工推翻算法 2 条，两次人都对。** 4.1 若看一眼 `bed = 04:27`，
就能排除「awake = 00:13」这个读法（人不可能在上床前 4 小时醒）。

**2026-08-09 决定：不实施。** 见 `2026-08-09_work_log.md` §八。

管线目前能跑、数字正常、即将交付，**不为「未来可能少一点人工审核」换掉核心算法。**
影响面 3 条记录：2 条已被正确标记为 `error`，1 条（12078）人工已改对，
另 1 条（8502）已由 ② 修复。**真实风险为零，只有理论风险。**

本条降级为「已知设计局限」，不再是待办。

**另：`row_id 8502` 是唯一真正没修好的记录**（人工改了 awake，
保留了算法基于旧 awake 减过 12h 的 getup）。正确值可推：`getup = 12:17`。
它带 `error_type = order_error`，不会静默进入分析。

### S8. `calculate_sleep_time_vars_end()` 有隐藏的写副作用

**新增 2026-08-09。** 写 S5 验证脚本时踩到。

函数名与文档都说它是「计算睡眠指标」，但 `return()` 之前是：

```r
dir.create("output", showWarnings = FALSE)
saveRDS(cleaned_data, "output/corrected_ema_data.rds")
```

**在仓库根目录调用它，就会用传入的数据覆盖 `output/corrected_ema_data.rds`。**

S5 脚本传的是 3 行 fixture。若当时跑通，刚跑完的 13,990 行真实输出就没了。
`dplyr::case_when()` 因 fixture 缺 `corrected` 列先报错才挡住 ——
**这是运气，不是设计。**

影响面不止验证脚本。任何人想：

- 对该函数写单元测试
- 拿子集重算指标
- 并行跑两份数据（synth / real）

都会静默互相覆盖，且没有任何提示。

**当前缓解：** `verify_reference_fidelity.R` 用 `run_sandboxed()`
把每次调用 `setwd()` 到临时目录，并加了一条断言 —— 沙箱漏了就红。
**这只保护了这一个调用点。**

**正式修法（需动管线，按研究者原则暂不实施）：** 把写盘移出计算函数，
交给调用方；或加 `output_path = NULL` 参数，默认不写。

---

## 🟡 中等

### M1. `self_diffcalc_sleeponset` 是 `time_sleep_corrected` 的纯别名，字典当成两列

`calculate_sleep_time_end.R:131` 无条件赋值，无任何计算。但字典：

- 第 73 行 `time_sleep_corrected` → **Full only**
- 第 105 行 `self_diffcalc_sleeponset` → **A + B**，标注 "Step 7"

同一个值两个名字，源列被降级，别名标成 Step 7（实为 Step 4 定下）。
**Dataset A 拿到的值是对的，但溯源信息是错的。**

⚠️ 此条与 B1 强相关：若 B1 决定恢复 `+ SOL`，别名关系即消失，本条自动解决。
**应在 B1 之后处理。**

### M2. `sol_minutes` 与 `sol_selfreport_minutes` 命名不对称

| A # | 列 | 含义 |
|---|---|---|
| 9 | `sol_minutes` | 从时间戳计算 |
| 15 | `sol_selfreport_minutes` | 参与者估计 |

一个显式标 `selfreport`，另一个什么都不标。使用者无法确定 `sol_minutes` 是"总的"还是"计算的"。

**建议：** `sol_computed_minutes` vs `sol_selfreport_minutes`。成对的量成对命名。

### M3. `waso_avg_minutes` 名字未体现其为自报派生

`= duration_totalmin_waso_estimate_am_mincalc_used ÷ num_waso_estimate_am`（217-220 行），
**分子分母皆为自报**。不是错误（它本就是"平均每次醒多久"的自报估计），
但名字看不出来。**建议：** `waso_avg_bout_selfreport_minutes`。

### M4. 物质摄入时刻只在 Full

Dataset A #32-35 是数量，对应的摄入时刻
（`caffeinetoday_PM_hhmm_ampm` 等，字典第 37-40 行）全在 Full。

`caffeine_num = 2` 在下午两点和晚上十点是完全不同的暴露。

**建议：** 与其搬四个 POSIXct 进 A，不如在 Step 7 派生
`hours_before_bed_caffeine` 之类的数值列，更直接可用。

### M5. `StartDate` 是 character

Dataset A #36。要画真实日历时间轴需自行解析。**建议交付前转 Date。**

### M6. `correction_type` 只在 Full，Dataset B 无法自足

B 给出位移量（pre → post），但**用什么规则改的**
（`correction_type`，取值如 `sleep_reduce_12h_loop`）在 Full。

想回答"12 小时环修正平均把 bedtime 推移了多久"，必须同时加载 B 和 Full。

**建议：** `correction_type` 加进 Dataset B。它是修正溯源数据集，
"改了多少"和"用什么规则改的"应在同一张表。

**已实施（2026-08-09），但随后发现该字段本身不可靠 —— 见 S6。**

### M7. `self_diffcalc_sleepefficiency_percent` 名为 percent 实为 0–1 分数

column_review 的 Q1。字典**没有解决它，只是把它放进了 Full**（第 114 行），
Dataset A 用的是 `se_percent`（0–100，第 119 行）。

分工本身合理，但 Full 里那个误导性的名字仍然存在，
任何直接用 Full 的人还会踩到。

### M8. 两个 TST 均值口径 / 两个 "Clean" 口径

| | 口径 A | 口径 B |
|---|---|---|
| Mean TST | 7.71h（检查点，分母 1,729 valid） | 7.69h（统计摘要） |
| Clean | 1,908（`data_category`） | 13,659（`flag_severity`） |

**同词两义，图上极易误读。** 会上被问到必须答得出分母是什么。

---

## ⚪ 已知债（已记录，可延后）

| # | 项 | 说明 |
|---|---|---|
| D1 | `output/` 仍全局共享 | 图已隔离（`latest_visualization_<tag>_n<rows>/`），但 CSV/RDS 未隔离。跑一次测试，`output/` 就变回 280 行 |
| D2 | Figure 13-18 在真实数据上不生成 | **非缺陷**：103 条候选已全部人工接受，待复核队列为空。已加解释性输出（待验证） |
| D3 | `run.sh` 两个毛病 | 版本检查用 `library()` 成功与否判断（包过期时照样成功）；`upgrade = "never"` 是无效参数。**很可能是已安装包停留在 1.1.0 的原因** |
| D4 | Δ / → 在 PNG 渲染失败 | Figure 12 列头四处 `conversion failure`。`ragg` 已装，`device = ragg::agg_png` 可解 |
| D5 | 🟡 三项 NULL 加固未做 | `data_category` NA 静默归 "Other"（两处）、`ensure_marking_columns()` 裸 NA 补字符列、Figure 8 缺 `is.data.frame()`。另有第四处同类（`sleep_visualization.R:326`）。当前分类计数正好等于 13,990，无 NA，不触发 |
| D6 | 配置 `output.figure` 段是死代码 | 无任何代码读取。比没有配置更糟——看起来能配，改了没反应 |
| D7 | `proj_splclean` 归档 | 同步后已无独有内容。建议改名加 `_ARCHIVED_` 前缀而非删除：改名后路径失效会立刻报错，删除做不到 |

---

## 附：本轮审计中我判断错误的三处（记录以便追溯）

诚实起见，以下是我先给出、后被推翻的结论：

| # | 我说的 | 实际 | 错在哪 |
|---|---|---|---|
| 1 | 四个 `*_selfreport_ts` 命名与内容相反 | **命名正确** | `selfreport` 标的是数据来源模态（日记自报，相对 actigraphy/PSG），不是"未经修改"。我把领域术语按管线视角误读了 |
| 2 | WASO discrepancy 无法计算 | **两侧都存在** | 我用教科书定义（WASO = 睡眠期内清醒）否定了本研究的操作定义（`getup − awake`），因而没认出 `awake_getup_diff_h` 就是计算侧 |
| 3 | TST 应改用 `getup − awake` | **不应该** | 两者位置不同：TST 是从睡眠期里减，只能减在这段里面的量。代入会减掉窗口外的时长 |

**教训：** 领域操作定义优先于通用定义。遇到命名/定义分歧，先确认研究方的定义，再判断对错。

---

## 建议处理顺序

1. **B1** —— 查问卷原题，定 sleeponset 是否 `+ SOL`。**这是唯一的外部依赖，最该先启动**
2. **B2** —— 跑验证命令确认 1,127 条缺口，选 a/b/c（建议 c）
3. **S4** —— Dataset B 加 `row_id`（已同意，可立即做）
4. **S1** —— `awake_getup_diff_h × 60` → Dataset A `waso_computed_minutes`
5. **S3** —— 字典标注实现状态
6. **S2** —— Figure 20B 改标题
7. **M2 / M3** —— 命名对称化（**冻结 v1.4 前，改了就没机会**）
8. **S5** —— B1/B2 定案后，加对参照实现的算式快照
9. 其余按需

---

> 2026-08-07 | 对照 commit `610572f`
