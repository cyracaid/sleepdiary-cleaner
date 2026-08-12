# Worklog 汇总 — 2026-08-07 → 2026-08-10

**汇报稿。** 汇总本周（8-07 之后）全部 worklog，供下次汇报直接使用。
来源：`data_dictionary_2026-08-07.md`、`data_dictionary_audit_2026-08-07.md`、
`open_issues_2026-08-07.md`、`2026-08-09_work_log.md`（splsleep）。

---

## 一句话总结

数据字典审计定案 + v1.4.0 交付门关闭：**B1/B2 两个阻断级决策已定，
8 项修复/验证全部落地，真实数据全绿验证，仓库已匿名化保安全。**

---

## 时间线

| 日期 | 事件 |
|------|------|
| 08-07 | 对 `data_dictionary.md` 逐条对照代码审计 → **FAIL**（ Dataset A 对睡眠-情绪研究 incomplete） |
| 08-07 | 建 `open_issues_2026-08-07.md`：B1/B2 阻断 + S 系列严重/命名问题清单 |
| 08-09 | B1/B2 定案；S1/S2/S4/M2/M3/M6 实施；`finalize_columns()` + `column_dictionary.csv` 落地；S5 `verify_reference_fidelity.R` 完成 |
| 08-09 | v1.4.0 Phase 1 交付门关闭（affect reserved、负数导出门、Step 10 硬失败、wiring 验证） |
| 08-10 | 真实数据 snapshot 验证跑通；合成 testthat 覆盖真实 output 事故修复（沙盒化）；Git 历史 round2 匿名化 + 推送修正 |

---

## 关键决策（汇报必讲）

### B1：`sleeponset` 不加自报 SOL ✅ 结案

- **问题**：参照实现在 sleeponset 上 `+ SOL`，splsleep 不加。
  若加，Mean TST 从 **7.71h → 7.23h**（系统性偏移约 29 分钟）。
- **定案**：`time_sleep` 问的是「你几点睡着」，即入睡时刻本身 → **不加 SOL**。
  加了就是把同一段入睡延迟计两次。splsleep 实现正确，代码零改动。
- **依据**：SCHEMA 定义 + 参照实现自身第 47/49 行内部矛盾 + 问卷语义（研究者确认）。

### B2：TST 缺 WASO 导致 NA ✅ 结案（选 C）

- **问题**：约 1,127 条记录有完整时间戳，却因缺自报 WASO 而无 TST。
- **定案**：选 C —— **零代码改动**，字典标注 `sleepperiod_minutes` 为 TST 上界。
  那 1,127 条没丢（sleepperiod 有值，差额即未知 WASO，可做敏感性分析）。

### 连带：`sleepperiod` ≡ `trysleep`（构造相同）✅

- 不加 SOL 后两者是**同一个表达式**。为避免「表里两列一样」，
  曾考虑给 sleeponset 加回 SOL 以制造差异 → **否决**（拿算法迁就列表）。
- **Dataset A 删 `trysleep_minutes`**，保留 `sleepperiod_minutes`。
- 写入 Methods 的一句话：日记未采集夜间中途醒来时刻，
  「睡眠期」与「尝试入睡期」不可区分，按构造相同。

### S7：AM/PM 归一化规则改造 → 决定不做 ✅

- 规则 4.1/4.2 会猜错「哪个时间戳错了」（3 条里 2 条人被算法对）。
- **决定不实施**：管线能跑、数字正常、即将交付，不为其理论收益换核心算法。
- 已有的 75 条人工裁定 = ground truth 验证集，将来若做有回测基准。

---

## 实施成果（8 项全落地）

| # | 项 | 成果 |
|---|----|------|
| S1 | 计算侧 WASO 进 Dataset A | `awake_getup_diff_h × 60` → `waso_computed_minutes`，解决单位不一致（原为小时） |
| S2 | Figure 20B 标题 | 改为 "Self-Reported Nighttime Wakefulness vs Post-Awakening Time in Bed"，消除「同一量两种测法」误导 |
| S3 | `record_status` 实现 | `finalize_columns.R` 六档映射 `.RECORD_STATUS_MAP`，未知档 stop()；A 交付该列 |
| S4 | Dataset B 主键唯一 | 加 `row_id`，与 A 同主键消除多对多 |
| S5 | 算式快照 | `verify_reference_fidelity.R`：8 算式契约 + 守卫，`--strict` 16/16，可进 CI |
| S6 | `correction_type` 溯源 | 字典 description 加 CAVEAT（只记算法动作、人工覆盖后不重写） |
| M2/M3 | 命名对称 | `sol_computed_minutes`、`waso_avg_bout_selfreport_minutes` |
| M6 | B 自足 | `correction_type` 加入 Dataset B，B = 15 列 |

### 交付列数（最终）

- **Dataset A：36 列**（含 `record_status`）
- **Dataset B：15 列**
- **Full：134 列**
- 真实数据：13,990 行 × 上述列数

---

## 验证结果（全绿）

| 验证 | 结果 |
|------|------|
| testthat 全量 | **190 pass / 0 fail / 1 skip**（skip = 无真实 output 时隔离断言，合理） |
| `verify_finalize_columns` | 41/41（字典 ↔ 交付列：列名/单位/主键） |
| `verify_reference_fidelity --strict` | 16/16（算式契约 + 保真登记：4 MATCHES / 4 刻意 DEVIATION 均有文档） |
| `verify_delivery_wiring` | 有真实 output 时 31/31（无 output 优雅跳过） |
| `verify_v1_3_snapshot --config 真数据` | 13/13，126 列 byte-level 一致（S3 链 vs 旧路径 bit-identical） |

真实数据基线（改动前后一致）：Total 13,990 | Clean 1,908 | Unusual 31 |
Equal 903 | Skipped NA 11,142 | Corrected 81 | **Mean TST 7.71 h (SD 1.27)** |
**Mean SOL 28.8 min**。唯一变化 = 修一条 getup 归一时序倒挂记录（row 8502）使 Error 7→6、WASO computed 负值 1→0。

---

## 真数据实测发现（两个 WASO 的关系）

- 1,723 行两列皆非 NA：**中位数皆 10 min、Q3 皆 20 min**（边际一致）
- 但逐行相关系数 **r = 0.013**（不相关）→ 不可互替，必须当两个变量处理
- 解读 A：单夜感知不准，群体分布对（discrepancy 研究本身即结论）
- 解读 B：自报值重度取整（5/10/20）衰减了相关系数
- 负值仅 1/2,848 条（-716 min，起床早于醒来），已被标 `error`，无需守卫

---

## 事故与修复（诚实记录）

1. **合成 testthat 覆盖真实 output** —— 280 行合成数据覆写了 13,990 行真实交付物。
   **修复**：`test-pipeline.R` 沙盒化（project_dir 指临时目录），
   + 防再犯断言（沙盒内不得出现真实交付物）。真实交付物复验原封未动。
2. **`calculate_sleep_time_vars_end()` 隐藏写副作用** —— 函数内含
   `saveRDS(output/corrected_ema_data.rds)`，在仓库根目录调用会覆盖真实输出。
   已加 `run_sandboxed()` 保护（登记 S8，正式修法延后）。
3. **备份文件绕过 .gitignore** —— `.bak` 文件含 75 行真实修正记录未进 ignore。
   **修复**：补 `*.bak*` / `manual_*.csv.*` 等模式。

---

## 安全收尾（GitHub 匿名化）

- Git 历史 round2 `git-filter-repo --replace-text`：真实 pid → 假 pid 90100–90120、
  真实 row_id → 90200/90201、dump 表行 → `[redacted dump row]`、时间戳/派生值 → `[redacted]`
- 误伤修复：测试代码合成值 `-716/60` 被误替 → 已还原
- 真实数据 Bland-Altman 图从全历史移除（`--invert-paths`），函数代码保留
- 推送修正：本地 tags 未同步重写版 → 重新 `--force --tags`；删除含数据祖先的旧 tag
- **结果**：GitHub main + 11 tags 全历史真实数据残留 **0**
- **本地**：splsleep 保留真实数据版 worklog（不 push），worktree 干净
- **待办**：备份 bundle（含真实数据）使用后应删除

---

## 遗留 / 下一步

| 项 | 状态 |
|----|------|
| S8 正式修法（写盘移出计算函数） | 延后 v1.4.1 |
| M1 sleeponset 纯别名（B1 定案后仍存在） | 可延后 |
| M4/M5/M7/M8 命名/文档 | 可延后 |
| D1-D7 已知债 | 延后 |
| `finalize_columns()` 接入 `run_pipeline()` | 核实是否已完成（§五 step 8） |
| 备份 bundle 删除 | 汇报前确认 |

---

## 附：审计方法教训（方法论价值）

1. **从 3 行手挑数据看分布 → 错**。看分位数（中位差正好是 0），不看样本
2. **从 1 条负值推测系统性 AM/PM 问题 → 错**。实际 1/2848 且已被标记
3. **按文件名搜不到就说「文件不在仓库」→ 错**。按内容搜一次命中
4. 内部一致性测试挡不住算法偏离参照（B1 潜伏 3 个月）→ S5 才补上外部保真度

> 2026-08-10 | proj_splclean | 汇报稿