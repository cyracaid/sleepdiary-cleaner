# 周工作汇总 — 2026-08-14 → 2026-08-19

**范围**：08-14 会议之后的全部工作，合并自 `2026-08-17_work_log.md`（§1–§19）。
**仓库**：`~/Documents/splsleep`（`cyracaid/sleepdiary-cleaner`），版本 v1.4.3。
**隐私**：本汇总**已去标识**，不含任何真实 pid。需要 pid 级明细时见
`2026-08-17_work_log.md` §19 及 `~/Documents/splsleep_paper_work/` 下的本地文件。
**英文版**：`2026-08-19_week_work_log_summary_EN.md`。

---

## 0. 本周一句话

把 v1.4.x 从"能跑"推到"能投"：补齐 benchmark 的七条证据线、在真实数据上跑完
M1–M7 审计与 Part B 静默错误扫描、修完 8 个 CI 真实缺陷、完成第二次隐私 purge、
走完 CRAN 卫生的 Phase 1–3，并在最后两天把 M4 的 922 条告警收敛成 87 条真正需要
人工判断的记录。

---

## 1. Benchmark 增强（5.1–5.7，会议列的未做项本周全部完成）

| # | 项 | 结果 |
|---|---|---|
| 5.1 | PPV 曲线 + recall/specificity CI | pooled recall **0.9871 [0.9847, 0.9896]**（闭环修复后重算 **0.9952 [0.9938, 0.9967]**）；control specificity 1.0；PPV 曲线全 π = 1.0 |
| 5.2 | L2 type-correct 分层 | swaps 0.81–1.0；field_sol 0.975；mmss 0.88；implausible 1.0；**format_no_colon 0.11 / malformed 0.07**（静默重格式化无类型痕迹）；cross_participant_spike 0.27 |
| 5.3 | FAR_flag / MRR / 误修幅度 | FAR_flag = FAR_alter = 0/2255；pooled MRR 61/4745 = **1.29%**；幅度中位数 61 min，100% 超 LoA 半宽 |
| 5.4 | Multiverse | OAT 筛 6 维 → 存活 D1(flip) + D2(swap) → 全因子 **3² = 9 规格**；mean TST 7.756–7.922 h；可分析 n 6333–6692；D2 方差 44.4% > D1 10.2% |
| 5.5 | 下游敏感性 | multiverse 下 TST 最大偏移 8.3 min，n 偏移 4.2%；B1（sleep-onset 语义）30 min；B2（WASO 门）1131 记录 |
| 5.6 | Leave-one-out 消融 | baseline recall_flag 0.565 / workload 2681（后修正为 3119）；关 D2 swap → 0.739 / 3508；关 D1 flip → 0.621 / 2947；D3/D4 无影响 |
| 5.7 | 控制条件 baseline | no-cleaning recall 0（下限）；naive-rule 0.6398 / FAR 0；pipeline 0.9871 / FAR 0 → **管线 +34.7 pp** |
| 5.4a | 参数提取重构（解锁项） | 3h 交换阈值 + cross-participant 常量 → `config_default.yaml`；默认值 = 原字面量，零行为变化；snapshot **13/13 逐位一致**，254 测试通过 |

**"243 规格"澄清**：243 是会议笔记里"OAT 后存活 4–6 维 → 3⁵"的预期上界，从未作为
结果承诺。实跑 OAT 后仅 D1、D2 移动下游量 → 3² = 9。执行正确，是文档沟通脱节。

---

## 2. M1–M7 审计（真实数据 n = 13,990，report-only）

**核心结论：AUTO_FIX = 0。** Golden combo（M1 ∧ M4 ∧ M5）在真实数据上零触发——
M5（冗余方向检查）挡住了所有候选。验证了会议判断：report-only 先行是对的。

| 方法 | 命中 | 说明 |
|---|---|---|
| M1 顺序违反 | 140 | bed_sleep 55 / sleep_awake 63 / awake_getup 21 / 组合 1 |
| M2 时钟形态 | 0 | 无 "23:30" 式时钟串 |
| M2 被重解释 | 35 | "10:30" 式 ≥4h 形态 |
| M3 自报偏差 | 0 | 无 >60 min 偏差 |
| M4 窗口非法 | **922** | 主发现：自报 SOL 超过 bed→sleep 窗口（max 225 min） |
| M5 静默恶化 | 1 | 与 08-13 worklog 披露的边界案例独立复现一致 ✅ |
| M6 跨日突变 | 1 | — |
| M7 未覆盖 note | 0 | 全部 14,338 条 note 均映射到已知机制 |

另发现 **49 条**原始顺序违反未被管线修正（落入 clean 25 / equal_time_ok 23 / error 1），
其 `needs_review_flag` 缺失 → B1/B4 候选。

### Part B 全量静默错误扫描（首次系统搜索 unknown-unknowns）

| 扫描 | 结果 |
|---|---|
| B1 静默值改动 | **0** |
| B2 冗余通道恶化 | 1（即 M5 那条） |
| B3 未覆盖 note 类型 | **0 / 14,338** |
| B4 盲区外推 | error_catalog 12 类**全部有守卫** |

---

## 3. 闭环：审计发现 → catalog → 注入 → 复验

| 新类别 | provenance | 注入后 recall | 结论 |
|---|---|---|---|
| `adjacent_swap_large_gap_left_clean` | observed + blind_spot | **1.0** | 注入形态可被捕获；真实数据的是 equal_time_ok 变体，审计发现仍成立 |
| `sol_window_contradiction` | observed + blind_spot | **0.431 → 1.0** | **盲区已关闭**：加 C4 守卫（SOL > bed→sleep 窗口 + 15 min 容差）→ 355/355 flag，control FAR 0/1609 |

补守卫后 pooled recall 重算 **0.9952 [0.9938, 0.9967]**。

---

## 4. 可复现性根因修正（#6 #7 关闭）

外部报告"消融/multiverse 不可复现"，初诊写成"无 seed 随机漂移"，**深入调查推翻初诊**：

- 管线是**确定性**的——同代码同输入重跑 3 次，消融 workload 逐位相等。
- 真因是**输入陈旧**：结果 CSV 产出早于 sol_window 守卫提交，而输入 rds 被 gitignore
  后由新 commit 重新生成 → 结果 stale，不是随机。
- 修复：新建 `spec_cache.R`，key = sha256(输入 rds + config + 归一化 overrides)，
  后续（§5）再加**代码指纹**。输入/配置/代码任一变化 → 缓存失效强制重跑，**漂移显性化**。

---

## 5. 稳健性补强（5 项）

1. **spec_cache 代码指纹**（最危险的自身漏洞）：原 key 缺 pipeline 代码 hash → 改代码
   但 config/input 不变时会命中旧结果。现加 `code_fingerprint()` = sha256(R/*.R +
   inst/scripts/*.R + 版本)。
2. **多 seed 敏感性**：4 个 seed 重跑 5.1 → pooled recall **0.9935–0.9952**（0.17 pp
   范围），FAR 全 0，cross_participant_spike **0.886–0.907** 恒为最弱类。
   **但 OAT 判定 seed 敏感**：一个 seed 存活 D1+D2，另一个仅 D1。
3. **真实数据 spec 曲线**：真实 n=13,990 上 **无维度存活**（max ΔTST 0.93 min，
   max Δn 0.70%）→ 真实数据对清理阈值不敏感。关键上下文：真实数据 analyzable_n
   仅 1719/13990（12.3%），清理面小。
4. **FAR 上界**：FAR = 0 补 rule-of-three 95% 上界 **0.186%**（0/1609），防"0 被读成
   证明为零"。
5. **L3 表达防误读**：0.486 ≠ "只修对一半"。实际 CORRECT 2619 / FLAGGED 2746（转人工）
   / MISREPAIRED 26。投稿数字用 L1 0.9952 + MRR 0.0048 + corrected-or-flagged 0.9952。

### D2 边缘性决策（双层报告）
- 事实：D2（swap 阈值）在 5 min / 1% 判定阈值边缘，跨 seed 不稳定。
- 决策：**主 spec 曲线 = robust survivors（D1-only，3 规格）**，取跨 seed 交集；
  9 规格全因子降为附录 `spec_curve_full.csv`，标注 seed-marginal 勿单独引用。
- 主曲线数字：D1 = 11/12/13 → mean TST 8.059 / 8.059 / 8.072 h，
  SOL 22.7 / 31.2 / 58.1 min，可分析 n 6660 / 6581 / 6327。

---

## 6. FDR（BH 校正）— 外部批判第 1 项

**诚实定位**：M1–M7 审计是描述性的（flag 计数，无假设检验）→ BH 正式不适用，
文档如实声明；benchmark 的 14 类别率才是可检验对象 → 在此做 BH。

方法：每类 L2 type-correct 率对固定 0.90 目标做单侧 exact binomial，14 检验 BH 校正，
另附 Wilson CI。**3 类显著低于目标（q < 0.05）**：cross_participant_spike 0.271
（q = 8.0e-116）、adjacent_swap_awake_getup 0.81（q = 2.9e-7）、ampm_swap 0.845
（q = 1.8e-3）；其余 11 类 q ≥ 0.49。三类正是已知弱项，互相印证。

---

## 7. 隐私 — 第二次 purge（Phase 0b）

- **发现**：`cluster_bootstrap_per_row.csv` 等 3 个逐行产物含 `pid` 表头。根因是
  **合成 pid 基址 1001 与真实 pid 范围重叠 8–9 个值** → 外部无法区分合成/真实。
- **处理**：(1) filter-repo 二次清历史；(2) 根因修复 `PID_BASE` 1001 → **50001**
  （与真实范围 0 重叠）；(3) .gitignore 封死 3 个逐行文件；(4) 全链路重跑验证——
  pid 是纯标签，**所有数字逐位一致**。
- **硬闸**：pre-commit hook 拒绝任何匹配敏感 pattern 的 staged 路径（.gitignore 可被
  `git add -f` 绕过，hook 才是真锁）。实测 staging 审计 CSV → commit ABORTED ✓
- **本地隔离**：FileVault 已开（整盘加密）→ 敏感文件移入 `sensitive_local/`（chmod 700）。

---

## 8. CRAN 准备 Phase 1–3 + CI

### CI：8 连红 → 全绿（8 个真实缺陷，非基础设施）
1. `.Rprofile` 无条件 source `renv/activate.R`，但 renv/ 被 gitignore → 每个 R 步崩
2. Rd 里 `\u00d7` → checkRd 未知宏 ERROR
3. 测试用 `withr::` 但 Suggests 未声明
4. 5.4a 新参数未同步 Rd → codoc mismatch
5. 聚合 Rd 页 duplicated alias + 包代码 `library()` + 非 ASCII 符号
6. smoke-legacy 在 `--as-cran` 构建树副本里卡死 → CI 降普通 check
7. `*.rds` 全局 gitignore 吞掉 `inst/extdata` 测试数据 → 加 `!` 例外
8. 删函数内 `library()` 后 verify 脚本依赖 attach 而崩

**教训**：CI 全红 ≠ 基础设施问题；`*.rds` 全局忽略会吞包数据；删函数内 `library()`
必须同步所有调用方。

### Phase 1（结构）
- 删 `run.sh`（全仓零引用）；2 个 root-only audit 脚本迁入 `validation/`。
- **修正原计划**：21 个根/inst 副本**保留**——副本是 pre-commit + `test-script-copies-in-sync.R`
  的一致性保障机制，不是冗余。

### Phase 2（CRAN 卫生，commit 7b10fb7）
- DESCRIPTION 定稿：Authors@R 规范化、ORCID 双填、Description 单段、Config/testthat/edition: 3。
- Imports 审计（以实调用为准）：删 tidyverse/scales/stringi/purrr/tibble，回补
  corrplot/magick/reshape2 → 最终 15 包全有实际用途。
- `--as-cran` 清理链：NAMESPACE importFrom 补全、globalVariables、Rd 转义、
  C locale 崩溃根因（banner 里的 Δ/→）。
- **关键防线**：`.Rbuildignore` 排除真实数据产物，已验证 tarball 不含。
- 状态：非环境问题 **0** —— 达 CRAN 提交门槛（余下 1 ERROR + 1 WARNING 纯 pdflatex 缺失）。

### 多平台 CI（CRAN 门）
matrix = [ubuntu, windows, macos]。Windows 首跑暴露唯一隐患：子进程把 `C:\Users\...`
反斜杠路径嵌入脚本，Rscript parse `\U` 报错 → `normalizePath(winslash="/")` 修复。
**三平台 R-CMD-check 全 success + pkgdown 绿。**

### Phase 3（文档收尾）
README 一致性（9-step → 10-step、multiverse 决策、真实 D1-only 数字、路径、测试数字
200+/16 文件、死链）；vignettes EN/ZH 同步；docs-dev 三份重写；图数统一为 30
（14 QC + 16 research，`steps.yaml` 为唯一事实来源）。最终 HEAD `9c1885a`，三平台 CI 全绿。

---

## 9. 外部审计跟进（08-19）

独立只读审计发现 2 项真问题，已修（commit `48a38fe`）：
1. `generate_clean_data.R` 注释含真实 pid 范围边界 → 去边界，保留 n=237。
2. 真实导出文件名硬编码 7 处 → 占位符；`real_data_spec_curve.R` 改从 config 读；
   .gitignore 精确名 → 通配。

其余 3 个 🔴 为误报（vignette "9-step" 与 Step 编号：图表节点含 Step 5.5，实际 9 节点，正确）。

**决策（记录备查）**：git 历史残留两个 deidentified 导出**文件名**，**不做 filter-repo**。
理由：文件名本身无参与者标识、文件从未被 git 追踪、无个体可关联数据泄露，仅命名痕迹；
重写会改全部 hash 并影响 3 个 tag / Release / 协作 clone，代价不成比例。
**重写门槛 = 个体可关联数据再现。** README 隐私段已注明此决定。

---

## 10. M4 922 → 188 → 87 的程序化分诊（08-19，本周收尾主线）

M4 的 922 条中，分层抽样估计约 65% 是时间戳完整性伪影、29% 是取整级分歧，
**188 条为真 mismatch**。本周对这 188 条做了六个筛法（全部可复现脚本）：

| 筛 | 结果 |
|---|---|
| A 算术相容（TIB − SOL − WASO） | **186 相容 / 0 不可能 / 2 无时间戳** |
| B 本人未 flag 日基线 | **100 ≤ 2× 本人中位数 / 87 超出** |
| C 双解读（HH:MM vs MM:SS）+ 证据门槛 | **2 确定修正 / 4 拟合但无证据 / 81 皆不合** |
| D 取整签名 | 整点值 flagged 28.2% vs 其余 3.9% → **富集 7.2×** |
| E 跨族佐证 | **22 有佐证 / 166 仅 M4** |
| F 行内格式矛盾 | **0 命中**（负结果，启发式不可推广） |

**A 的意义大于它抓到的数**：186/188 按字面值算出来都是正常夜晚 → 它们不是算术
胡话，是正常夜里的长潜伏期。这是"保留而非修正"立场最强的单项证据，直接支撑
sleep×affect 母研究的范围声明。

**E 的交叉验证**：M2_reinterpreted 命中的 4 条，与手读 `process_interval.R` L480-496
得出的结论完全一致——两条独立路径互证。

**最终分派（91 个 pid 持有 188 天）**：9 已有结论 / 1 溯源异常 / 2 修正值确定 /
15 优先审查 / 89 保留为真实变异 / 72 模糊待审。
→ **62 pid、90 天需人看**（87 天真判断 + 3 天仅确认）；**29 pid、53 天完全不用看**；
P2 内 10 个 pid 占 27 天可按人判 → 实际约 60–70 次判断。

---

## 11. MM:SS 240 分钟阈值盲区 — 发现与设计决策

`process_interval.R` 的重解读规则是**行内**的：仅当 HH:MM 读法 ≥ 240 min 才改按
MM:SS 读。行内 = 确定性、序无关、易测（这正是管线这样设计的理由），代价是看不见
"MM:SS 条目恰好小于 240"的被试。

**动机案例**：某被试三条条目按 HH:MM 均 ≥240、**已被管线重解读**（即其 MM:SS 用法
由他自己的数据证明），但另两条恰在阈值下，至今被当作 180 / 225 分钟。

### 四个选项的实测代价

| 选项 | 实测 | 结论 |
|---|---|---|
| 1 降阈值 | 240 已近真实 SOL 合理上限，flagged 集内含真实 120/180 min 潜伏期 | **否决**，代价无界 |
| 2 行内算术不可能 | 2848 可评估夜晚中仅 **2** 晚不可能；**抓不到动机案例**（180 min 在 595 min 的夜里完全可能） | **无效**——证明**行内规则解决不了此问题** |
| 3 朴素被试级（≥1 条确认即全转） | **爆炸半径 428 条**（SOL 328 / WASO 100），其中 **47 条当前 ≥60 min** 会被压成 1–3 min | **否决**：为救 6 条毁 47 条 |
| 4 严格被试级 + AUDIT-only | ≥2 条确认 + 小时位非零 + 尺度双向门槛 → 全库 **6 条 / 3 个 pid** | **采纳**，比朴素规则少 **71×** |

敏感性：要求 ≥1 条确认 → 21 条；≥2 → 6 条；≥3 → 2 条。**≥2 是拐点。**

### 为什么是 AUDIT-only（骨架保护）

被试级规则**数据集依赖**：同一行在不同子集里读法不同 → 破坏行独立性，而测试、
合成注入 benchmark、可复现性论述全建立其上。做成 AUDIT-only 后：**不改任何计算值
→ 无验证数字变动 → 无需重跑 benchmark → v1.4.x 行为逐位不变**。
机制已存在（AUTO_FIX → FLAG → AUDIT-only 三层），且有先例（`cross_participant_spike`
出于结构上类似理由被定为 AUDIT-only）。

**AUDIT-only ≠ 不修数据**：那 6 条经既有人工复核 CSV 通道修正，有 provenance、
归因到人的判断——这正是本文核心主张（清洗决策是分析决策，应显式化可审计）。
不进自动通道的是**代码规则**，不是**数据修正**。

---

## 12. 本周的自查更正记录（防止后续引用错数字）

| # | 错误 | 更正 |
|---|---|---|
| 1 | "消融/multiverse 不可复现 = 随机漂移" | 管线确定性；真因是**输入陈旧**（§4） |
| 2 | multiverse "243 规格" | 实为 **3² = 9**；243 是 OAT 前的预期上界，从未承诺（§1） |
| 3 | `time_bed/sleep` 的 AM/PM 字段按 24h 字面值读 | 实为编码 `l`/`C`；实证 **l→PM、C→AM**（中位 TIB 8.67 h，96.9% 落 4–13 h）。误报的 2 条"算术不可能"**已撤回**，改对后为 0 |
| 4 | 188 中已人工判断数 "7" | 精确 join 后为 **9** |
| 5 | 人工队列估计 "20–30 条" | 重复计算筛法重叠；**87 是诚实数字** |
| 6 | FAR = 0 的措辞 | 限定为"构造干净行零误改"，补 rule-of-three 上界 0.186% |
| 7 | L3 0.486 读作"只修对一半" | 实为 CORRECT 2619 / FLAGGED 2746 / MISREPAIRED 26 |

---

---

## 14. 本周后段补充（2026-08-19，写完上文之后）

### 14.1 数据集结构：13,990 不是日记数

| 量 | 值 |
|---|---|
| 导出总行数 | 13,990 |
| 带晨间日记时间戳的行 | **2,860** |
| distinct 参与者 | **237** |
| distinct 参与者 × 研究日 | 3,305 |
| 一个人日有多于一条日记 | **0**（每人每天恰好一条） |
| 每人日记天数 | 中位 13，范围 1–15 |
| 日记覆盖率 | 2,860 / 3,305 = **86.5%** |

旧方法学草稿写 "13,990 sleep diary records from approximately 10,000
participants"，**两半都错**：参与者是 237 不是约 10,000；13,990 是整个 EMA 导出
（含晚间与瞬时提示），只有 2,860 行是睡眠日记 —— 把 13,990 全叫"睡眠日记"高估约 5 倍。

独立互证：2,860 / 13,990 = 20.4%，与 Channel B 分析（08-12，不同路径）记录的
"20.4% has non-missing self-reported SOL" 逐位吻合。

**仓库不需要改**：README 与 vignette 里的每一处 "n = 13,990" 都指管线处理的行数，
正确。只有手稿里把这些行称作"睡眠日记"的句子是错的。全项目最接近 10,000 的量是
合成 FCR 基准（跑在 n = 10,000）—— 基准数字漂进数据集描述的可能路径。

### 14.2 cluster bootstrap：实现与描述不符

补写 bootstrap 理由时查出主证据线的一处缺陷。`ppv_cluster_ci.R` 注释写
"resample pids WITH replacement"，实现却用 `df[df$pid %in% idx, ]`。`%in%` 是集合
成员判断，被抽中两次的被试仍只贡献一次行。每次重抽实际是"约 63% 被试各计一次"的
随机子集 —— subsampling，非 bootstrap。

真实 per-row 数据两实现各 B=2000 × 5 seeds 复核：

| 实现 | pooled recall 95% CI |
|---|---|
| 正确 cluster bootstrap（保重数） | [0.9932, 0.9970] |
| 现有 `%in%` 代码 | **[0.9938, 0.9967]** |
| 已公布值 | **[0.9938, 0.9967]** — 逐位吻合 |

点估计 0.9952 不受影响；specificity 1.0 方差为零，不受影响；PPV 曲线不受影响。
只有区间受影响，且只是偏窄约 21%。三位小数下 [0.994, 0.997] → **[0.993, 0.997]**，
仅下界第三位动一格，上界不动。

**三处已修**（pooled / per-category / PPV band），改为预聚合到每被试计数再按抽中的名字
索引，保住重数。待本地 R 重跑确认；README 与 vignette 有 8 处三位小数引用要跟着改。

### 14.3 n_boot 敏感性（关闭一项写作前必补）

B ∈ {250, 500, 1000, 2000, 5000, 10000}，每档 5 个独立 seed。端点在 B = 1000 后
稳定；现用的 B = 2000 处跨 seed 极差 ≤ 2.4e-4，比区间半宽（1.9e-3）小一个数量级。
**蒙特卡洛成分相对被试间抽样变异可忽略。**

### 14.4 投稿顺序再次修订

**先 CRAN 上架 → 再 BRM → 之后 JOSS。** JOSS 并不要求 CRAN（已核官方投稿文档：
归档发生在评审通过之后），所以 CRAN 不是外部约束，是"让包先上架再投方法学论文"的
主动选择。

CRAN 现状：LICENSE 持有人、`VignetteBuilder`、knitr/rmarkdown Suggests、
`cran-comments.md` 均已就位。查出并修复一处冲突 —— `VignetteBuilder: knitr` 已声明，
但 `vignettes/` 自初始 commit 起就被 `.Rbuildignore` 排除，会导致 tarball 声明了
vignette builder 却没有 vignette。这些 vignette 是纯散文（92 KB，每个只有一个
`include = FALSE` 和一个 `eval = FALSE` chunk），最省事的修法是让它们进包，已移除
`^vignettes$`。`cran-comments.md` 因声称 0 notes（首次投稿几乎不可能）已重写。
剩余：本地 build/check 复验、win-builder、rhub。

另撤回一条：`Config/roxygen2/version` **不可疑**。roxygen2 8.0.0（2026-05）引入
`Config/roxygen2/` 命名空间取代 `RoxygenNote`，字段名与 8.x 版本号都是当前正确写法。

---

## 13. 遗留与下一步

**投稿顺序（已拍板，08-19）**：**Behavior Research Methods 先行 → JOSS 之后。**
取代 §13 的"JOSS 先行"决策，该条作废。

核实后更正了原依赖链的一处事实错误：§13 写"JOSS 要求软件已归档（CRAN + Zenodo DOI）"，
但 JOSS 官方文档的原文是归档发生在**评审通过之后**（"Upon successful completion of
the review, authors will make a tagged release … get a DOI for the archive"），
且**CRAN 从未被 JOSS 要求**。原来的 "CRAN → JOSS" 依赖不成立 →
**CRAN 现在是独立轨道，不阻塞任何一篇**。

JOSS 政策对本项目有利：官方明确预期配套关系（"Sometimes authors prepare a JOSS
publication alongside a contribution describing … methods assessment"），
所以 BRM（方法学评估）+ JOSS（软件本身）是被认可的组合，不是重复发表。
**硬义务**：投 JOSS 时须申报相关论文状态（已发表／审稿中／临近投稿）。

新依赖链：BRM（需版本冻结 + 可引用 tag，**不需 CRAN 上架**）→ JOSS（投稿时申报 BRM
状态，评审通过后再做 tagged release + Zenodo DOI）；CRAN 并行推进。
手稿主线确定为 `BRM_METHODS_SKELETON.md`；`sensitive_local/paper/` 下的 JOSS 短稿
降为后续轨道。

**CRAN 剩余**：`VignetteBuilder: knitr` + knitr/rmarkdown 未进 Suggests（10 个
vignette 声明了 `knitr::rmarkdown` 引擎）；LICENSE 的 COPYRIGHT HOLDER 与
DESCRIPTION 作者不一致（待用户提供真名）；无 `cran-comments.md`；
win-builder / rhub 未跑；`Config/roxygen2/version` 待核。

**手稿缺口**：README / vignette / skeleton 全文 grep "mood / affect / emotion /
purpose / individual variability / over-correct" **零命中** —— 即"为何保守 FLAG
而非自动拉齐"的研究目的框架从未写进任何文档。已在 `BRM_METHODS_SKELETON.md` 新增
Study-scope 小节（正文版 + README 短版两版措辞），README 暂未改动待定位置。
BRM 必补仍剩：bootstrap 理由（被试级 cluster + n_boot 敏感性）、snapshot 13/13 定义
入 Reproducibility 段、Study-scope 声明落位。

**人工队列**：P1 15 条 + P2 72 条待过（已排序）；1 条溯源异常待查；
给 Maia 的邮件已按操作顺序重写，待发。
