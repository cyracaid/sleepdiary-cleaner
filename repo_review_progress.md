# sleepdiary-cleaner —— 进度存档 & 评审意见

> 仓库：https://github.com/cyracaid/sleepdiary-cleaner
> 存档时间：2026-07-17　|　评审时 GitHub main 版本：v1.1.2（最新提交 `699c201`）

---

## ⚠️ 0. 最要紧：本地新工作可能没进 GitHub（先处理这个）

翻完**完整 20 条提交历史 + 所有分支**后确认：这几轮做的 `log_step` / `flag_standards` /
新版 Figure 12 / `flag_severity` 归位，**整个 git 历史里一行都没有**。远程只有 `main`
一个分支。

也就是说，本地报告过的"17/17 测试全绿、ledger 276 行、新 Figure 12 跑通"——
**那批工作只在本地，从没 push 上来**。GitHub 上 main 仍是旧状态：
- Figure 12 还是旧的"三面板表"（读 `correction_status.csv`）
- `00_MAIN_entry.R` 还是旧的 checkpoint A–E（5 个检查点）
- `flag_severity` 还在 `sleep_visualization.R`（viz 层）计算
- 没有 `flag_standards.R` / `log_step.R` / `figure12_step_flag_table.R` / `test-flag-standards.R`

### 立刻要做的核对

```bash
cd /你的本地仓库
git status        # 这些文件是 untracked(红) 还是 modified？
git stash list    # 会不会被 stash 了
git branch        # 是不是提交在别的本地分支没 push
```

如果 `git status` 里这些文件是红色 untracked = 还没进版本控制，赶紧：

```bash
git add R/flag_standards.R R/log_step.R R/figure12_step_flag_table.R \
        tests/testthat/test-flag-standards.R \
        calculate_sleep_time_end.R sleep_visualization.R 00_MAIN_entry.R
git commit -m "Add per-step flag ledger (log_step + flag_standards), new Figure 12 table, move flag_severity to Step 7"
git push
```

**在确认这批工作安全落盘前，下面的评价只针对 GitHub 上的旧版本。**

---

## 1. 专业度评价（基于当前 main）

**总体：8/10** —— 在"个人/实验室科研代码"里明显偏上，远超典型研究生代码。

### 真正拉开差距的地方（多数科研代码没有）
- **提交历史规范**：20 条 commit，信息具体（如 "Fix schema type validation,
  process_timestamp df[[col]] bug"），迭代轨迹清晰；专门有一条
  `purge real data from history` 处理数据隐私。
- **工程化信号齐全**：正经 R 包结构（DESCRIPTION/NAMESPACE/man）、`renv.lock` 锁依赖、
  GitHub Actions 的 R-CMD-check、`.opencode` 的 agent skill。
- **文档分层清晰**：双语 README + `SCHEMA.md`（显式列契约）+ `THRESHOLDS.md`（阈值出处）
  + 中英架构文档。
- **schema 校验器**：把隐性列契约变显式、缺列时开头就大声报错，可靠性加分。

### 扣分项（相对"专业软件"而非"科研代码"）
- **测试偏薄**：只有 3 个测试文件（interval/normalize/pipeline）；核心的三层 flag
  判定逻辑没有单元测试（本地写的 `test-flag-standards` 正好补这个，但没 push）。
- **单数据集耦合**：仍有 233 处硬编码列名（schema 校验缓解了，但没消除）。
- **已知结构问题在 main 上还没修**（因为修复没 push）：Figure 12 仍是三面板表、
  `flag_severity` 仍在 viz 层。

### 一句话定位
就 GitHub 当前状态：一个**规范、可复现、可交接、隐私干净、有 CI 有文档**的科研数据
管线，专业度高于平均科研代码；离"通用开源工具"还差跨数据集验证和更厚的测试。
本地那批没 push 的改动，恰恰是把它从 8 分往 9 分推的关键一步。

---

## 2. 名词解释：schema 是什么

**schema（模式）= 一份"数据应该长什么样"的规格说明**：这个 pipeline 期望输入有哪些列、
每列叫什么、什么类型、哪些必须有、哪些可选。

- 类比：像报名表的"要求单"——必填姓名(文字)/年龄(数字)/生日(日期)，可选电话；
  收表时先对照检查，缺必填项当场拦下。
- 项目里对应 `SCHEMA.md` + `validate_schema.R`：数据进来先对照规范列清单查一遍，
  缺列/错名/错类型就**大声报错并列出缺哪列**，而不是跑到中途悄悄变 NA。
- 为什么"缓解"硬编码：没消灭硬编码，但把契约摆明面、开头即查——列对不上时
  **第一步就知道**，而非中途莫名出错。

---

## 3. 待办清单（按优先级）

1. **[最高] 确认并 push 本地新工作**（见 §0）—— 别让 log_step/flag_standards/新
   Figure 12/flag_severity 归位丢失。
2. **push 后补测试**：把 `test-flag-standards.R` 一起提交，让 `devtools::test()`
   覆盖三层 flag 判定。
3. **落地 flag_severity 的"公共契约列"修复**：在 `calculate_sleep_time_end.R`(Step 7)
   产出标准列 `sleep_efficiency_pct` / `sol_h` / `waso_h`（由 Step 7 内部
   `self_diffcalc_*` 列换算，SOL/WASO 分钟 ÷60），评估器不动。改法方向是"让底层步骤
   满足契约"，不是"让评估器迁就 Step 7 列名"。
4. **验证收尾**：`devtools::document()` → `load_all()` → `test()` 全绿 →
   `bash run.sh` → 确认新 Figure 12 的 SEV 列从 Step 7 行开始出数字（之前为 "—"）、
   `output/step_flag_ledger.csv` 生成。
5. **[可选，中期] 补文档**：把 `sleep_efficiency_pct/sol_h/waso_h` 三个公共契约列
   写进 `SCHEMA.md` 的 derived 段，注明由 Step 7 产出。
6. **[可选，长期] 若要走"通用工具"方向**：跨 1–2 个外部数据集验证，逐步替换 233 处
   硬编码列名；否则保持"[某研究]可复现管线"定位即可，不必背这个包袱。

---

## 4. 已完成 / 已交付（供回顾）

- ✅ `validate_schema.R` + `SCHEMA.md`（schema 校验器 + 显式列契约）
- ✅ `THRESHOLDS.md`（阈值默认值/依据/适用人群）
- ✅ AM/PM 12h 阈值外置为 `flip_gap_hours`（保留 `hours(12)` 平移量）
- ✅ 版本升到 v1.1.x
- 🟡 `flag_standards.R` / `log_step.R` / `figure12_step_flag_table.R` /
  `test-flag-standards.R`（本地已写、本地跑通，**待确认是否已 push**）
- 🟡 flag_severity 归位 Step 7 + 公共契约列换算（**待落地/验证**）
