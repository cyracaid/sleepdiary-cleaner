# Second-Review 集成 — 工作日志

**日期：** 2026-07-09
**项目：** splsleep（睡眠 EMA 日记数据清洗管线）

---

## 2026-07-09 — Second-Review 共识集成与管线自动化

### 摘要
将 second_review_checklist 的 13 条共识决策写入管线。创建 3 个自动化脚本：`apply_second_review.R`（Step 5.75）、`00a_setup.R`（环境检查）、`run.sh`（一键运行）。将 `00_MAIN_entry.R` 中硬编码的 pid=4024 修正迁移至 `manual_nap_exercise_corrections.csv`。对 `metrics_ai_review.csv` 中剩余的 16 行单 reviewer 记录批量标注 `(two reviewer consensus)`。管线现为 10 步，通过 `target_csv` 列实现显式路由。

---

### 阶段 A：Second-Review Checklist 路由

**目标：** 实施 `second_review_checklist.csv` 中 13 条记录的第三方审核。

#### 决策表

| 决策类型 | 数量 | target_csv | 操作 |
|---------|------|------------|------|
| confirmed_not_error_do_not_correct | 11 | `manual_metric_review_acceptances` | anti-join 追加 |
| correction（6985 day8 awake→getup） | 1 | `manual_error_corrections` | 仅验证（已手工录入） |
| recode（10009 day9 nap 675→75） | 1 | `manual_nap_exercise_corrections` | 仅验证（已手工录入） |

#### 为什么是 Step 5.75，不是 Step 6 或 Step 6.5

放在 Step 5 和 Step 6 之间是为了让路由到 `manual_error_corrections.csv` 的修正（如 pid=6985 day8）在同一轮管线运行中被 Step 6 读取。如果放在 Step 6 之后，这些修正要到下一次运行才会生效。

#### 路由机制

为 `second_review_checklist.csv` 新增 `target_csv` 列——用显式列代替从 `decision_type` 或 `pipeline_status_before_review` 做文本推断。同时将 `current_status` 重命名为 `pipeline_status_before_review`。

---

### 阶段 B：新增自动化脚本

| 脚本 | 步骤 | 用途 |
|------|------|------|
| `apply_second_review.R` | 5.75 | 只写共识应用器：读取 checklist → 3 路分发 via anti-join |
| `00a_setup.R` |（运行前）| 通过正则扫描 `library()`/`require()` 自动检测 R 包；验证 8 个必要输入文件是否存在 |
| `run.sh` |（运行器）| `set -euo pipefail` → `00a_setup.R` → `00_MAIN_entry.R` |

#### `apply_second_review.R` 设计
- `append_with_antijoin()` 辅助函数：读现有 CSV → 按 (pid, day_num, row_id) anti-join → 只追加不重复的行
- 路由 A（`manual_metric_review_acceptances`）：实际追加，标注 `source = "second_review"` 和 `date_added`
- 路由 B（`manual_error_corrections`）：仅验证——打印预期行供操作员确认
- 路由 C（`manual_nap_exercise_corrections`）：仅验证——相同模式

---

### 阶段 C：硬编码修正迁移

从 `00_MAIN_entry.R` 第 72 行移除硬编码：
```r
# 之前：
ema_data_release_timeproc$exercisetoday_PM_totalmin_Moderate[3992] <- "01:30"

# 之后：
# 注：pid=4024 硬编码修正已迁移至 manual_nap_exercise_corrections.csv
```

添加到 `manual_nap_exercise_corrections.csv`：
`pid=4024, day=3, row=3992, variable=exercisetoday_PM_totalmin_Moderate, corrected_mincalc=90`

`manually_corrected` 列使用 `verified_recode`（而非 `TRUE`），以区别于人工审核录入的条目。

---

### 阶段 D：16 行单 Reviewer 记录批量标注

对 `metrics_ai_review.csv` 中所有尚无 `(two reviewer consensus)` 标注的 16 行进行批量更新。这些行结构上与已标注的 46 行相同，均为 interval-trust boundary case（SOL=0、awake=getup、或低 SOL 值）。所有行的 `human_decision` 均为 `confirmed_not_error_do_not_correct`（单 reviewer 审核）。批量标注后该文件达到 62/62 行全部标注。

#### 16 行分类

| 模式 | 数量 | PID |
|------|------|-----|
| SOL=0 | 4 | 2714 d12, 2835 d5, 4481 d7, 6374 d13 |
| awake=getup | 4 | 2835 d5/d12, 3200 d2, 6374 d13 |
| SOL 5–120（其他边界） | 8 | 1036 d11, 3200 d7, 6143 d1, 6032 d10, 6805 d9, 7078 d5, 9696 d3, 10929 d2, 11419 d10, 11863 d14 |

---

### 阶段 E：三方交叉验证

三个子代理独立审查了所有改动：

| 代理 | 聚焦点 | 发现 |
|------|--------|------|
| 管线完整性 | 步骤编号、source 依赖链 | Step 5.75 位置正确；所有 source() 目标已验证 |
| CSV 交叉引用 | checklist → target CSV 一致性 | 13 行 checklist 全部有对应目标；anti-join key 唯一；正确使用 `verified_recode` |
| 文档审计 | `pipeline_architecture.md` vs 代码 | 10/11 条声明验证通过；唯一出入是文档声称 24 张图（实际 C2 压制全部标记时输出 20 张） |

---

### 修改的文件

| 文件 | 变更 |
|------|------|
| `00_MAIN_entry.R` | 新增 Step 5.75（source apply_second_review.R）；移除第 72 行硬编码；步骤数更新为 10 |
| `metrics_ai_review.csv` | 16 行批量标注 `(two reviewer consensus)` → 62/62 完成 |
| `second_review_checklist.csv` | 新增 `target_csv` 列；`current_status` → `pipeline_status_before_review` |
| `manual_nap_exercise_corrections.csv` | 新增 pid=4024 条目（从硬编码迁移） |
| `pipeline_architecture.md` | 步骤表、数据流图、CSV 表新增 Step 5.75 |

### 新建的文件

| 文件 | 大小 | 用途 |
|------|------|------|
| `apply_second_review.R` | ~80 行 | Step 5.75 — 只写共识应用器 |
| `00a_setup.R` | ~55 行 | 运行前环境检查 |
| `run.sh` | ~8 行 | 一键运行 bash 脚本 |

### 最终清单

| 文件 | 状态 | 详情 |
|------|------|------|
| `second_review_checklist.csv` | ✅ 13 行，全部 consensus_reached，含 target_csv | |
| `apply_second_review.R` | ✅ 已创建 | anti-join 幂等，3 路分发 |
| `00a_setup.R` | ✅ 已创建 | 自动装包，验证输入文件 |
| `run.sh` | ✅ 已创建 | set -euo pipefail |
| `metrics_ai_review.csv` | ✅ 62/62 已标注 | |
| `manual_nap_exercise_corrections.csv` | ✅ 12 行（新增 pid=4024） | |
| `00_MAIN_entry.R` | ✅ 已插入 Step 5.75，移除硬编码 | |
| `pipeline_architecture.md` | ✅ 已更新 | |
| 管线步骤 | **10 步**（1, 1.5, 2, 3, 4, 5, **5.75**, 6, 6.5, 7, 8, 8.5, 9） | |
