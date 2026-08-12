# Worklog 汇总 — 2026-08-07 → 2026-08-12

**汇报稿。** 汇总本周（8-07 之后）全部 worklog，供汇报给 Maia 使用。
来源：`data_dictionary_2026-08-07.md`、`data_dictionary_audit_2026-08-07.md`、
`open_issues_2026-08-07.md`、`2026-08-09_work_log.md`、`2026-08-10_week_work_log_summary.md`、
`2026-08-12_work_log.md`（splsleep）。

---

## 一句话总结

数据字典审计定案 + v1.4.0 交付门关闭（08-07→08-10），紧接着两处生产环境 bug 补丁落地并正式发布 v1.4.1，
同时在真实数据（n=13,990）上完成了两项独立于合成测试的验证（通道B冗余验证、B1 语义确认），
并把人工双人审阅数据能不能算 Cohen's κ 这件事彻底查清楚（08-12）。

---

## 时间线

| 日期 | 事件 |
|------|------|
| 08-07 | 对 `data_dictionary.md` 逐条对照代码审计 → **FAIL**（Dataset A 对睡眠-情绪研究 incomplete） |
| 08-07 | 建 `open_issues_2026-08-07.md`：B1/B2 阻断 + S 系列严重/命名问题清单 |
| 08-09 | B1/B2 定案；S1/S2/S4/M2/M3/M6 实施；`finalize_columns()` + `column_dictionary.csv` 落地；S5 `verify_reference_fidelity.R` 完成 |
| 08-09 | v1.4.0 Phase 1 交付门关闭（affect reserved、负数导出门、Step 10 硬失败、wiring 验证） |
| 08-10 | 真实数据 snapshot 验证跑通；合成 testthat 覆盖真实 output 事故修复（沙盒化）；Git 历史 round2 匿名化 + 推送修正 |
| 08-12 | 两处生产 bug 补丁（SOL/WASO 静默误改标记、人工复核文件写入）设计、验证、落地到本地真实仓库 |
| 08-12 | 补打 `v1.4.0` tag（此前一直没打），发布 `v1.4.1`，推送到 GitHub |
| 08-12 | 通道B冗余验证（真实数据 n=13,990）+ B1 描述性分析（真实数据 n=2,735），两项均为第一梯队验证清单项目 |
| 08-12 | 查清"κ 能不能算"和"手稿里 n=47/37/84 对不上 CSV 75 行"两个遗留问题 |

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

## 实施成果（08-07 → 08-10，8 项全落地）

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

### 交付列数（截至 08-10）

- **Dataset A：36 列**（含 `record_status`）
- **Dataset B：15 列**
- **Full：134 列**
- 真实数据：13,990 行 × 上述列数

---

## 验证结果（08-10 时点，全绿）

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

## 08-07→08-10 事故与修复（诚实记录）

1. **合成 testthat 覆盖真实 output** —— 280 行合成数据覆写了 13,990 行真实交付物。
   **修复**：`test-pipeline.R` 沙盒化（project_dir 指临时目录），
   + 防再犯断言（沙盒内不得出现真实交付物）。真实交付物复验原封未动。
2. **`calculate_sleep_time_vars_end()` 隐藏写副作用** —— 函数内含
   `saveRDS(output/corrected_ema_data.rds)`，在仓库根目录调用会覆盖真实输出。
   已加 `run_sandboxed()` 保护（登记 S8，正式修法延后）。
3. **备份文件绕过 .gitignore** —— `.bak` 文件含 75 行真实修正记录未进 ignore。
   **修复**：补 `*.bak*` / `manual_*.csv.*` 等模式。

### 安全收尾（GitHub 匿名化，08-10）

- Git 历史 round2 `git-filter-repo --replace-text`：真实 pid → 假 pid 90100–90120、
  真实 row_id → 90200/90201、dump 表行 → `[redacted dump row]`、时间戳/派生值 → `[redacted]`
- 真实数据 Bland-Altman 图从全历史移除（`--invert-paths`），函数代码保留
- 推送修正：本地 tags 未同步重写版 → 重新 `--force --tags`；删除含数据祖先的旧 tag
- **结果**：GitHub main + 11 tags 全历史真实数据残留 **0**

---

## 08-12：两处生产 bug 补丁，验证后落地并正式发布 v1.4.1

### 补丁一：SOL/WASO 静默误改标记（Part A4）

- **背景**：合成 benchmark（n=400/类）测出 `field_misentry_sol`/`field_misentry_waso`（把时钟时间误填进 duration 字段）
  静默误改率 **95.8%/96.0%**——`process_interval.R` 的 MM:SS/dd:00 重解释启发式会把误填变成看似合理的小数字，
  而下游的复核状态检查（`calculate_sleep_time_end.R`）只查解析值是否**过大**，从不查是否**过小**，误填正好从这个单向盲区溜过去。
- **补丁**：`checkforerrors_processing.R` 新增 Part A4，匹配 `_correctionsmade` 里 `MM:SS|dd:00` 的重解释痕迹，命中则标记
  `needs_review_flag` 并写入 `auto_error_desc`，转人工审核。
- **效果**：SOL 静默误改 95.8% → **3.5%**（14/400，已知盲区：形如"01:XX"的值不留文本痕迹，结构性抓不到）；
  WASO 静默误改 96.0% → **0%**。0/10,000 干净数据新增假阳性，FAR_alter 保持 0/10,000。

### 补丁二：`generate_correction_files.R` 人工复核文件从未写盘

- **发现**：`[NEW]manual_error_correction_review.csv` / `[NEW]manual_unusual_review.csv` 的 `write.csv()` 调用被注释掉了，
  `run_pipeline()` 紧接着还把内存里的结果 `rm()` 掉——两个文件**从未在生产环境里被真正写出过**，
  但管线日志无条件打印"Files saved: ..."。**定性从"日志描述不准"上修为"人工复核文件生成功能完全不工作"。**
- **修复**：取消注释两处 `write.csv()`，验证在真实 n=280 全量 pipeline 上非空/符合预期地写出。

### 落地过程

两处补丁在沙盒里验证通过后，通过设备桥接直接写入用户本地真实仓库（根目录 + `inst/scripts/` 两份拷贝同步修改），
`R CMD INSTALL` 重装后在真实源码上重跑 FCR (n=10,000)、enrichment (n=7,000)、`testthat::test_dir()` 全量测试，
结果与沙盒一致：`[ FAIL 4 | WARN 51 | SKIP 1 | PASS 181]`（4 个失败为既有、与本次改动无关的两个未导出函数测试）。

### v1.4.0 补 tag + v1.4.1 发布

发现仓库一直没有给 v1.4.0 打过 tag（`DESCRIPTION` 已是 1.4.0，但 `git tag` 停在 v1.3.9）。
补打 `v1.4.0` 在正确的历史提交上，随后四次提交（两处补丁 + 版本号/NEWS.md + 今日 worklog）、
打 `v1.4.1`，`main` 分支和两个 tag 全部推送到 `github.com/cyracaid/sleepdiary-cleaner`。

---

## 08-12：两项真实数据验证（第一梯队验证清单）

### 通道B冗余验证（真实数据 n=13,990）

**逻辑**：日记里同时存在两条独立的 SOL 测量——自报时长和时间戳推算（`time_sleep − time_bed`）。
Step 4（`normalize_sleep_time_sequence.R`）的纠正逻辑**从不读取** duration 列（源码 grep 确认），
所以自报 SOL 是一条纠正算法看不到的独立判据，可以在真实数据上直接测"纠正对不对"，不构成循环论证。

**结果**（对 Step 4 纠正过的 88 条 bed/sleep 相关记录）：

| correction_type | n | 改善 | 变差 | 中位数：前→后 | P(改善) | Wilcoxon p |
|---|---|---|---|---|---|---|
| bed_sleep_swap_3h | 39 | 39 | 0 | 31 → 5 min | 100% | 4.9e-08 |
| sleep_reduce_12h_loop | 38 | 38 | 0 | 720 → 9.5 min | 100% | 3.1e-08 |
| sleep_awake_swap_3h | 10 | 3 | 7 | 5 → 90 min（变差） | 30% | 0.036 |
| **全部相关纠正** | **88** | **81** | **7** | **120 → 8.5 min** | **92.0%** | **1.3e-12** |

`bed_sleep_swap_3h` 和 `sleep_reduce_12h_loop` 在真实数据上被强力验证，`sleep_awake_swap_3h`（n=10）测出一个真实的负面结果——
机制上是修 sleep-awake 顺序问题时以牺牲 bed-sleep 顺序为代价；7 例变差里 6 例被下游时序检查抓住转人工审核，
只有 1 例（pid 90123）是真正静默变差，n 太小、按"这条规则值得再看一眼"解读，不按"这条规则坏了"解读。

### B1 描述性分析（`time_sleep` 语义确认，真实数据 n=2,735）

沿用通道B同一批数据，检验 `time_sleep` 到底问的是"熄灯"还是"睡着"——这个问题此前已由研究者在 08-09 直接确认过语义，
这次是用真实数据做的独立、数据驱动交叉验证。结果：按自报SOL分bin看中位数gap从~15分钟涨到~37.5分钟，
明确排除"熄灯"假说（那样该摁在0附近）；点对点相关性弱（R²=0.017），是总体层面的方向性支持，不是精确的个体对应，
高SOL段自报比时间戳推算长，这个模式在睡眠研究文献里本身有记录（自报潜伏期在长潜伏期时容易系统性偏长）。

---

## 08-12：两个遗留问题查清楚了

### κ 能不能算？—— 不能，而且是从一开始就不存在，不是"没找到"

v5 手稿里写"两位编码者独立审阅了全部 flagged errors 和 atypical cases"，此前算出了 raw agreement 64.0%（48/75）。
这次确认：**Cohen's κ 需要两位评分者各自独立、不受对方影响的原始标签**，而两人从一开始协作方式就是共用同一张表，
不是"各自独立标注、之后对表"——不存在一份可找的"独立原始版本"，因为这个过程本来就没有生成 κ 需要的输入。
Gwet's AC1 需要同样的输入，一并排除。**结论：只能报 raw agreement，措辞改用 "collaborative/concurrent dual-review"，
不能用 "inter-rater reliability"（哪怕加 development-time 限定语），因为这个词本身预设了独立性，这里连这点也不成立。**

### 手稿里 n=47/37/84 跟 CSV 75 行对不上，为什么？

查清楚了：手稿这句话说的其实是**两条独立的审阅记录**（flagged errors track、atypical cases track），不是同一批数据的两半：

| track | 手稿数字 | 现在的行数 | 对不对得上 |
|---|---|---|---|
| atypical cases（`manual_unusual_corrections.csv`） | n=37 | **37** | ✅ 精确对上 |
| flagged errors（`manual_error_corrections.csv`） | n=47 | **75** | ❌ 差 28 |

atypical 这条精确对上，说明手稿数字本身是真实、当初准确的；flagged errors 这条对不上，是因为这条 track 的最后修改时间
（2026-08-08）比手稿写定这句话的时间（2026-03-19）晚了近 5 个月——这 5 个月里管线新增过多轮检测规则，
"会被判定需要人工审"的记录集合本来就会随规则变严格而扩大，**不是数据丢失，是手稿数字过期了**，投稿前要用当前数字重写这句话，
两条 track 也要分开报（75+37=112，不是原来暗示的 84）。顺手把 atypical track 的一致性也算出来了：89.2% 当场一致 / 10.8% 讨论后一致
（明显高于 flagged errors 那条的 64.0%），可以作为"人工判断难度因任务类型而异"的又一个证据点。

---

## 08-12（三）：benchmark 真正进仓库、一次匿名化事故与修复、v1.4.2 发布、会议邮件改写

### benchmark 一直没进仓库——用户追问才发现

用户看到 README 里 benchmark 那一行还写着"🔲 计划中"，追问"不是做了吗"。核查后确认：合成 benchmark（`generate_clean_data.R`、`error_catalog.yaml`、`inject_errors.R`、`evaluate_fcr.R`、`evaluate_detection.R`，以及完整的 FCR/detection 结果）确实做了，而且正是这套 harness 揪出了 v1.4.1 那两个 bug——但这套代码和结果**只存在于沙盒里，从未进本地仓库、没进 GitHub，README 状态也写错了**。补齐：六个脚本 + 三份结果 CSV + 新写的 `SYNTHETIC_BENCHMARK_RESULTS.md`（完整方法、数字、诚实列出"还没做完的部分"）落到 `validation/synthetic/`；README 这一行状态改成 🟡"第一轮已完成"。

### 例行核对时顺带发现的匿名化事故

核对本地文件时发现：当天早些时候提交（`bd35065`、`e7f004b`）并推送到 GitHub 的两份 worklog 文件里混进了 7 个真实 pid（含通道B验证逐行数据表格），违反 08-10 建立的匿名化规则。用 `git rebase -i` 重写这两个 commit，把真实 pid 换成延续 90100+ 假区间的占位 ID（90121–90127），`--force-with-lease` 覆盖远程历史；`v1.4.1` tag 恰好打在被重写的那个 commit 上，一并重新打标签、force-push。**披露**：真实 pid 曾在 GitHub 上短暂公开过（当天几个小时的窗口期），这次重写只保证之后的访问者看不到，不能追溯清除这期间可能已产生的任何副本。

### v1.4.2 发布

把 benchmark 收仓库这件事本身作为一次版本发布：`DESCRIPTION`/`NEWS.md` 从 1.4.1 → 1.4.2（无清洗逻辑改动，只是补上 benchmark harness 的版本记录），打 tag、推送、建 GitHub release，`main`/tag/release 三处确认与本地同步。

### 给 Maia 的会议邮件改写

原邮件是"进度汇报"格式，改成"会议议程"格式，主体换成 benchmark 设计和结果需要一起决定的四件事：①预注册映射（confirmatory / exploratory / addendum，需要 Maia 带来预注册原文）②这次 benchmark 做到什么程度算够——完整版（recall/specificity/PPV 曲线、cluster bootstrap、multiverse；multiverse 还需要先把 3 小时交换阈值和 cross-participant MAD 常数从硬编码提到 config）还要再 2-3 周，第一轮是否已经够用于这篇论文 ③下游敏感性分析要不要现在做 ④失眠样人群误报率是健康人群 26 倍这个测出来的数字要不要写进 Limitations。手稿 κ/n=47 的修正提示保留在邮件下方。

---

## 遗留 / 下一步

| 项 | 状态 |
|----|------|
| S8 正式修法（写盘移出计算函数） | 延后 v1.4.1（可延至下版本） |
| M1 sleeponset 纯别名（B1 定案后仍存在） | 可延后 |
| M4/M5/M7/M8 命名/文档 | 可延后 |
| D1-D7 已知债 | 延后 |
| 两处 08-12 补丁的 commit/push | ✅ 已完成，`v1.4.1` 已上线 GitHub |
| 通道B冗余验证 / B1 描述性分析 | ✅ 已完成（第一梯队验证清单 5 项中的 2 项） |
| κ 独立标注 / n=47/37/84 数字差异 | ✅ 已查清（第一梯队验证清单剩余项目） |
| benchmark harness 补齐进仓库 + README 状态修正 | ✅ 已完成，`validation/synthetic/` 已上线 GitHub |
| GitHub 匿名化事故（7 个真实 pid）修复 | ✅ 已完成，历史重写并 force-push |
| v1.4.2 发布 | ✅ 已完成，`main`/tag/release 三处同步 |
| 给 Maia 的会议邮件（benchmark 设计+结果讨论） | ✅ 已改写，未提交进 git（个人草稿，按需可补提交） |
| 预注册协议（OSF） | 未开始——第一梯队验证清单最后一项，需先跟 Maia 开会决定后续 benchmark 范围 |

---

## 附：审计方法教训（方法论价值，累计）

1. **从 3 行手挑数据看分布 → 错**。看分位数（中位差正好是 0），不看样本
2. **从 1 条负值推测系统性 AM/PM 问题 → 错**。实际 1/2848 且已被标记
3. **按文件名搜不到就说「文件不在仓库」→ 错**。按内容搜一次命中
4. 内部一致性测试挡不住算法偏离参照（B1 潜伏 3 个月）→ S5 才补上外部保真度
5. **python-docx 按段落读会漏内容 → 错**。v5 手稿的关键一句话（n=47/37 出处）藏在 Track Changes 里，
   按段落文本读不到，改成直接解析 XML 原始 run 才找到——文档格式本身也可能是证据丢失的原因

> 2026-08-12 | proj_splclean | 汇报稿
