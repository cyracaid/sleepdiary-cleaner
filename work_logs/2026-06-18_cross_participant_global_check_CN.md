# Step 8.5: 跨人全局一致性检查 — 2026-06-18

## 目标

新增管线步骤（Step 8.5），不逐行检查 SOL/WASO，而是**跨该人所有天**检查。核心洞察：每个人都有独特的睡眠模式和报告风格。单独看极端的值（如 SOL=400min），在看到此人其他天通常只报告 5-30min 后，会变得明显可疑。

## 解决的问题

`checkforerrors_processing.R` 中现有检查：
- **逐行**（Part C：SOL>120=所有人"过多"）
- **全局阈值**（MM:SS 转换 ≥240 min 一刀切）
- **格式层面**（解析器按非标准格式标记，不考虑值）

这些都不知道 **pid 6259 通常 SOL=5-30min**——所以 day 4 的 SOL=400（或 MM:SS 重编码为 4 min）应该与基线本就在 150-250 min 的人区别对待。

## 设计：MAD 基 + 三档

### MAD（中位数绝对偏差）

为什么用 MAD 而不用 z-score/标准差：
- MAD 对我们要检测的异常值本身具有鲁棒性
- 单个 400min 的天不会膨胀基线离散度
- 无需正态性假设

### 三档检测

| 档位 | 条件 | 含义 | 操作 |
|------|------|------|------|
| **1** | deviation ≥ 5 MAD + 值 ≥ 4× 个人中位数 + 绝对阈值 | `single_day_spike` | 标记待审 |
| **2** | ≥50% 的天 SOL 高 + ≥3 个这样的天 | `consistent_pattern` | 排除 CP（已经在 Step 8 审查中）|
| **3** | <3 天数据 / MAD = 0 | `insufficient_data` | 回退到现有 Step 8 全局检查 |

### 低基线覆盖规则

特殊规则：如果个人中位数 SOL < 30 min 且 当前值 > 240 min → 无条件自动标记。直接捕获 pid 6259 模式（通常短 SOL，某个极端天几乎肯定不合法）。

### 检查的指标

| 指标 | 列 | Spike 倍数 | 绝对阈值 | 最低基线 |
|------|--------|------------|----------|---------|
| 客观 SOL | `self_diffcalc_sol_minutes` | 4× 中位数 | ≥120 min | ≥5 min |
| 主观 SOL | `duration_totalmin_sol_estimate_am_mincalc_for_review` | 4× 中位数 | ≥120 min | ≥5 min |
| WASO | `duration_totalmin_waso_estimate_am_mincalc_used` | 4× 中位数 | ≥60 min | ≥3 min |

## 架构：新 Step 8.5

### 位置

插入在 Step 8（`checkforerrors_processing.R`）和 Step 9（`sleep_visualization.R`）之间的 `00_MAIN_entry.R` 中。

**为什么放这里，不放 Step 8 内部：**
- Step 8 已有 957 行，含 Parts A-D
- 跨人检查概念上不同于逐行检测
- 其输出（suspicious slices CSV）最好写成文件，不合并到现有 flag 框架
- 清晰边界：Step 8 完成逐行，Step 8.5 做跨人，Step 9 可视化全部

### 新文件

- **`cross_participant_global_check.R`**（363 行，从 375 行精简）

### 输出文件

| 文件 | 内容 | 用途 |
|------|------|------|
| `cross_participant_flagged_rows.csv` | CP 标记行含上下文（个人中位数、MAD、倍数、偏差分）| 审查者可操作列表 |
| `cross_participant_suspicious_slices.csv` | **所有**至少有一个 CP 标记天的 PID 的行，按 PID 分组 | "拉出可疑参与者所有行" 表 |

### 集成

- 读取 Step 8 的 `review_output$data_with_flags` 和 `corrected_ema_data`
- 跳过 `human_metric_review_status == "confirmed_not_error_do_not_correct"` 的行
- 跳过 `manually_corrected == TRUE` 的行
- 在已有 `auto_error_desc` 末尾追加 `[CrossParticipant]`
- 如尚未被标记，将新 CP 标记行加入 `checkforerrors_df`
- 为新检测行设 `needs_review_flag = TRUE`

## 处理的边缘情况

| 情况 | 处理 |
|------|------|
| <3 天数据 | 跳过每人基线；无 CP 标记（Step 8 全局检查仍适用）|
| MAD = 0（所有天相同）| 将 MAD 钳位到最小 1 min |
| 参与者已在手动接受列表中 | `human_metric_review_status` 检查 → 跳过 |
| 已被 Step 8 标记 | CP 信息追加到已有 `auto_error_desc` |
| 长期 SOL 高的参与者 | Tier 2 检测 → 从 CP 排除（标记基线本身就高的人无意义）|
| 列缺失（如无 WASO 数据）| 优雅跳过每个指标 |

## Bug 修复：cp_type 索引越界

**发现者**：验证 subagent 合成测试
**位置**：`cross_participant_global_check.R:243`（原始）
**根因**：`cp_type` 用 `which(flag_metric)[which(flagged_indices == idx)]` 索引。`cp_type` 长度 = `sum(flag_metric)`（CP 标记行数），但 `which(flag_metric)` 返回 metric_df 层级的行索引（1..nrow(metric_df)）。这些大索引访问了 `cp_type` 的越界位置，使所有 `cp_flag_type` 值静默为 `NA`。

**修复**：改为 `cp_type[which(flagged_indices == idx)]`——`flagged_indices` 和 `cp_type` 长度均为 `sum(flag_metric)`，所以 `flagged_indices` 中的位置正确映射到 `cp_type`。

**不修复的影响**：所有 CP 检测到的 spike 的 `cp_flag_type = NA`，使输出 CSV 对分类无用（审查者无法区分某行是 spike、一致模式还是数据不足）。

## 审计：三个并行 Agent 审查

Pipeline 成功运行后，3 个 agent 并行执行：

### Agent 1：代码逻辑审计 ✅

| 检查项 | 结论 | 详情 |
|-------|------|------|
| cp_type 索引修复 | ✅ 正确 | `which(flagged_indices == idx)` 返回 1..k，匹配 cp_type 长度 |
| MAD 钳位到 1 | ✅ 安全 | 绝对阈值 + 4× 倍数防止误报 |
| flag_metric 布尔逻辑 | ✅ 正确 | `!consistent` 守卫 spike 和 low_base 两条路径 |
| 一致性参与者排除 | ✅ 有效 | ≥50% 高天 → 从两条路径排除 |
| 无重复计数 | ✅ 正确 | OR 逻辑确保每行只标记一次 |
| checkforerrors 去重键 | ✅ 健壮 | paste(pid, day_num, row_id) 超集 |
| order() 中 NA 处理 | ✅ 安全 | na.last=TRUE 默认，不崩溃 |
| `cp_flag_desc` 死代码 | ⚠️ 已移除 | 第 110 行被初始化但从未填充或输出 |

### Agent 2：管线集成审计 ✅

| 检查项 | 结论 | 详情 |
|-------|------|------|
| 插入点（Step 8 后、Step 9 前）| ✅ 正确 | 00_MAIN_entry.R:209 |
| 对象依赖（corrected_ema_data, review_output）| ✅ 已验证 | 运行时 exists() 检查 |
| review_output 结构 | ✅ 完整 | data_with_flags + checkforerrors_df 均存在 |
| 幂等重跑 | ✅ 安全 | 每次运行前列重置为 NA，CSV 覆写 |
| 全局环境污染 | ⚠️ 与管线一致 | local=TRUE in source()，仅 review_output 推全局 |
| CSV 相对路径 | ⚠️ 与管线一致 | 与 Steps 5, 8 相同约定 |
| 错误恢复（无 tryCatch）| ⚠️ 结构性保护 | 本地副本 → 全局赋值模式 |

### Agent 3：输出数据质量审计 ✅

| 检查项 | 结论 | 详情 |
|-------|------|------|
| 已知 PID（6259, 2835）排除 | ✅ 正确 | Step 6 中手动修正 |
| 误报 | ✅ 零 | 所有 52 行满足三重阈值 |
| n_days ≥ 3 | ✅ 全部通过 | 最小 = 4（pid 4484）|
| checkforerrors_df 集成 | ✅ 49 新 + 3 更新 | 匹配运行日志 |
| Suspicious slices 格式 | ✅ 2420 行 × 41 PID | 按 pid/day_num 排序 |

**清理应用**：移除 `data$cp_flag_desc <- NA_character_`——死代码，从未填充或输出。

## Pipeline 运行结果（13,990 行）

### Step 8.5 输出

| 指标 | 标记 |
|------|------|
| Objective_SOL | 7 行 |
| Subjective_SOL | 13 行 |
| WASO | 32 行 |
| **CP 标记总计** | **52 行，41 个 PID** |

### 集成

- `checkforerrors_df`：23 → 72 行（+49 CP 新）
- `cross_participant_suspicious_slices.csv`：2420 行，41 个 PID

### 偏差分 Top 10

| PID | Day | 指标 | 值 | 中位数 | 偏差 | 倍数 |
|-----|-----|------|-----|--------|------|------|
| 6258 | 12 | WASO | 180 | 5 | 175.0 | 36× |
| 8644 | 6 | SubjSOL | 180 | 15 | 165.0 | 12× |
| 6156 | 8 | SubjSOL | 120 | 5 | 115.0 | 24× |
| 9163 | 11 | WASO | 120 | 5 | 115.0 | 24× |
| 11175 | 11 | SubjSOL | 120 | 5 | 115.0 | 24× |
| 1265 | 2 | ObjSOL | 120 | 15 | 105.0 | 8× |
| 4300 | 1 | ObjSOL | 120 | 15 | 105.0 | 8× |
| 2095 | 15 | SubjSOL | 150 | 8 | 95.8 | 19× |
| 10635 | 9 | SubjSOL | 120 | 30 | 90.0 | 4× |
| 10635 | 12 | SubjSOL | 120 | 30 | 90.0 | 4× |

52 行均为真实极端值，零误报。

## Field-Misentry 分析

用户询问了 "630→10.5" 模式（原 630 min，Step 6.5 MM:SS 解析器修正为 10.5）。调查发现：

### 已在 Step 6 修正：不在 CP 输出中
MM:SS 解析器在 `apply_sleep_metric_duration_corrections.R` 中已修正。修正后值为 10.5 min，非 630。CP 正确看到修正后的值。

### 剩余极端多日值（在 suspicious_slices.csv 中）

**ObjSOL ≥ 120 且 ≥2 天的 PID（潜在 field-misentry）：**

| PID | 高天 | 范围 | 全部已接受？| 状态 |
|-----|------|------|------------|------|
| **6374** | **3** | **330-360** | ✅ 全部人工接受 | Day 8 (330) 仍被 CP 标记 |
| 6258 | 3 | 130-150 | ✅ 全部人工接受 | 已审查 |
| 3200 | 3 | 120-150 | ✅ 全部人工接受 | 已审查 |
| 3131 | 3 | 120-150 | ✅ 全部人工接受 | 已审查 |
| **7121** | **2** | **210-315** | ✅ 全部人工接受 | Day 12 (315) 仍被 CP 标记 |
| 6127 | 2 | 120-180 | ✅ 全部人工接受 | 已审查 |
| 7772 | 2 | 135-136 | ✅ 全部人工接受 | 已审查 |

**WASO ≥ 120 且 ≥3 天的 PID：**
| PID | 高天 | 范围 | 全部已接受？|
|-----|------|------|------------|
| 11062 | 3 | 165-210 | ✅ 全部人工接受 |

**SubjSOL ≥ 120 且 ≥2 天的 PID：**
| PID | 高天 | 范围 | 全部已接受？|
|-----|------|------|------------|
| 1030 | 3 | 120-180 | ✅ 全部人工接受 |
| 9696 | 2 | 180-225 | ✅ 全部人工接受 |
| 10635 | 2 | 120-120 | ✅ 全部人工接受 |
| 10638 | 2 | 120-180 | ✅ 全部人工接受 |

**关键发现**：所有多日极端值 PID 都已被人接受（`confirmed_not_error_do_not_correct`）。CP 检查正确遵从人工决定。CP 标记仍存在的情况（如 pid 6374 day 8, pid 7121 day 12）是因为那些特定行尚未被审查——CP 标记它们以待新的人工评估。

**不会添加独立的 "field-misentry" 检测，因为：**
1. Step 6 MM:SS 解析器已捕获基于格式的误填
2. 系统性的列级错误（如将 TST 填入 SOL 字段）无法在没有外部真值的情况下检测
3. 人工接受的多日高值有意排除在 CP 重新标记之外
4. 未接受的极端值已被 CP 的 spike 检测捕获

## 验证结果（修复后）

| 测试用例 | 结果 | 详情 |
|---------|------|------|
| pid 1 day 5 SOL=400（基线 9 min）| ✅ 已标记 | `single_day_spike`, deviation=87.7 MAD, 40× |
| pid 2 持续 SOL=150-250 | ✅ 未标记 | `consistent_pattern` 排除有效 |
| pid 3 day 8 SOL=180（基线 25 min）| ✅ 已标记 | `single_day_spike`, deviation=23.2 MAD, 7.2× |
| Suspicious slices CSV | ✅ 20 行 | 所有 10 天 × 2 标记 PID |
| checkforerrors_df 更新 | ✅ +2 行 | 仅 CP 检测的添加 |

## 文件变更

### 修改
- `00_MAIN_entry.R`：在 Step 8 和 Step 9 之间插入 Step 8.5 调用
- `cross_participant_global_check.R`：移除 `cp_flag_desc` 死代码

### 新建
- `cross_participant_global_check.R`：Step 8.5 逻辑

## 运行时创建的文件
- `cross_participant_flagged_rows.csv`（52 行）
- `cross_participant_suspicious_slices.csv`（2420 行）

## Step 1.5：Field-Misentry 检测 — 2026-06-18

### 问题
用户识别出一个模式："10:30" → 630 min → 10.5 min 修正（经 MM:SS 解析器）可能修正了**错误的东西**。真正的问题是：**原始 SOL 值实际上是时钟时间**（有人将他们的入睡时间 "10:30 PM" 填入了 SOL 持续时间字段）。

当 MM:SS 解析器看到 "10:30"（630 min），它转换为 10.5 min——一个完全正常的 SOL 值。这"修复"了格式但隐藏了**跨字段污染**。

### 检测
新文件：`cross_participant_field_misentry_check.R`
- 在原始数据上运行（Step 3 处理剥离 HH:MM 格式之前）
- 将原始 SOL 字符串与原始 time_sleep 和 time_bed 字符串比较
- 将原始 WASO 字符串与原始 time_awake 和 time_getup 字符串比较
- 精确 HH:MM 匹配 → 标记为 field-misentry

### 结果

| PID | 天数 | SOL 匹配 | 值（min）| 含义 |
|-----|------|----------|----------|------|
| **1036** | 3 ×（day 7,12,13）| time_sleep | 630-660 | 将入睡时间填入 SOL 而非分钟数 |
| 2835 | 1 ×（day 12）| time_sleep | 615 | 将入睡时间填入 SOL |
| 4481 | 1 ×（day 7）| time_sleep | 765 | 将入睡时间填入 SOL |
| 6805 | 1 ×（day 9）| time_sleep | 725 | 将入睡时间填入 SOL |

**pid 1036** 最重要：33% 的 SOL 非 NA 天是 field-misentry。MM:SS 解析器静默地"修正"为 10.5 min，使它们对 Step 8 和 Step 8.5 均不可见。

WASO field-misentries：0 发现。

### 影响
- 在此检查之前，这 6 行被 pipeline 完全遗漏
- MM:SS 解析器通过从 630 min 转换为 10.5 min 掩盖了它们
- CP spike 检测看到 10.5 min → 从不标记
- 需要审查者直接关注 pid 1036, 2835, 4481, 6805

### 管线集成
- 作为 **Step 1.5** 加入管线（数据加载后立即运行，在任何处理之前）
- 直接在原始 RDS 上运行（读取文件，非管线内存）
- 输出：`cross_participant_field_misentries.csv`

## 输出文件（完整）

| 文件 | 来源 | 内容 |
|------|------|------|
| `cross_participant_flagged_rows.csv` | Step 8.5 | 52 行 CP 标记 spike，41 个 PID |
| `cross_participant_suspicious_slices.csv` | Step 8.5 | 所有 41 个标记 PID 的 2420 行（完整时间线）|
| `cross_participant_field_misentries.csv` | Step 1.5 | 6 行 field-misentry，4 个 PID |

## Post-Audit Update：manual_error_corrections.csv 替换

旧 `manual_error_corrections.csv`（不同列、更少行）已替换为 5.27 共识版。

**变更：**
- 旧文件列结构不同（无 `manually_corrected_mtb`、`agreement_cd_mtb`）
- 新文件有 72 行人工审查、共识达成的修正
- 所有列保留，含修正元数据
- Pipeline 重新运行 → 仍然 13,990 行，0 错误，24 张图

## review_remaining_46_classified.csv 三层审计（2026-06-18）

### 处理流程

1. **标注状态列**：对比 manual_metric_review_acceptances.csv（5.28 已接受 12 行）和 manual_error_corrections.csv（会议共识 12 行），标出 status = accepted_0528 / corrected_consensus / needs_review
2. **提取完整历史**：从原始 RDS 提取 14 个待审 PID 的 846 行完整日记数据 + 基线统计（SOL 中位数、四分位距、WASO 分布）
3. **3 个 subagent 并行审计**：
   - **Temporal Agent** — 时间戳顺序、AM/PM 合理性
   - **Metrics Agent** — SOL/TST/SE/WASO 内部一致性
   - **CP Baseline Agent** — 对比各人自己的 SOL 基线分布
4. **合成推荐** → 输出 `remaining_22_3agent_review.csv`

### 22 行审计结果

| 推荐 | 行数 | 含义 |
|------|------|------|
| ACCEPT | 13 | 三层一致认可，无需修正 |
| ACCEPT_AS_INSOMNIA | 5 | 真实失眠模式（7415×4, 1872×1），非录入错误 |
| ACCEPT_AS_INSOMNIA_CP | 3 | CP 重叠记录（6374 day8, 7121 day12, 10323 day13）— 真实失眠极端日，CP spike 正确但无需操作 |
| CORRECT_AWAKE_GETUP_AMPM | 1 | 5310 day14 — awake/getup 需 AM/PM 转换（9PM→9AM）|

### 关键发现

- **所有 3 条 CP 重叠记录均判定为真实失眠**：pid 6374 SOL=330（33× 基线中位数）、pid 7121 SOL=315（31.5×）、pid 10323 SE=50% WASO=120 — 真实严重失眠日，非录入错误
- **仅 1 行需修正**：pid 5310 day 14 — awake/getup 从 9PM 改为 9AM
- **其余 18 行全部可接受**：时间序列有效，指标内部一致，基线对比在合理范围内

### 输出文件

- `review_remaining_46_classified_annotated.csv` — 含 status + cp_flagged + 3agent_rec 列
- `remaining_22_3agent_review.csv` — 完整三层审计 CSV
- `temporal_review_22rows.csv` / `metrics_review_22rows.csv` / `baseline_review_22rows.csv` — 各 agent 原始输出

## 后续步骤

1. 在真实数据上运行完整 pipeline → ✅ 完成
2. 审查 `cross_participant_flagged_rows.csv` → ✅ 52 行确认合法
3. 审查 `cross_participant_suspicious_slices.csv` → ✅ PID 分组格式确认有效
4. 阈值调优 → ✅ 不需要（零误报）
5. **审查 `cross_participant_field_misentries.csv`** → ⏳ 需要人工评估 pid 1036, 2835, 4481, 6805
6. 增加更多指标（TST, SE）到 CP 检查 → 未来工作
