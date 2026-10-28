# BRM Methods 骨架 — 规则族（描述性命名，编号为代码锚点）

> **投稿顺序已定(2026-08-19)**: **Behavior Research Methods 先行 → JOSS 之后。**
> 取代早前 worklog §13 的"JOSS 先行"决策。本文件即 BRM 手稿主线。
> 核实要点: JOSS 的归档要求(tagged release + Zenodo DOI)发生在**评审通过之后**,
> **CRAN 从未被 JOSS 要求** → CRAN 是独立轨道,不阻塞 BRM。JOSS 官方明确预期
> "a JOSS publication alongside a contribution describing … methods assessment",
> 故 BRM + JOSS 是被认可的组合;**但投 JOSS 时须申报 BRM 的状态**。
> BRM 投稿前建议至少打一个 tag,让手稿有确定的可引用版本。

**定位**: 2.4 节「真实数据审计」主体；合成基准验证 (2.3) 与审计 (2.4) 共用同一张规则族表。
**命名原则**: 论文正文用描述性名称；`(Rule M1)` 式编号仅作代码/审计输出回溯锚点，不承担论文叙事。

---

## 规则族总表 (Table R1)

| 族（论文名） | 功能 | 输入 | 输出 | 决策 | 锚定依据 | 代码锚点 |
|------|------|------|------|------|----------|----------|
| **Timestamp standardization** | 自由文本 → HH:MM，类型安全，分隔符归一，AM/PM 校正 | 原始 `*_am` | 格式统一字符时间戳 | FLAG (coercion 风险) | 工程安全层（无共识标准） | `process_timestamp()` |
| **Temporal order validation** | 重建绝对时刻，查 bed≤sleep≤awake≤getup 违反 | 4 时间戳 | 邻对违反表 | AUTO_FIX (∧一致性∧冗余) / FLAG | CSD 时间轴语义 | `normalize_sleep_time_sequence()` |
| **Free-text duration parsing** | 三分支解析 SOL/WASO 串（标准/无冒号/畸形冒号） | 原始时长串 | `_mincalc` + 形态分类 | FLAG (时钟形态永不自动修) | 手动 entry 心理学 (mmss) | `process_interval()` |
| **Internal consistency check** | 派生 SOL−自报偏差；mincalc vs 逻辑窗口 | 派生+自报值 | 偏差/窗口非法表 | AUTO_FIX 组成元之一 / AUDIT | CSD: SOL 定义域 | `calculate_sleep_time_vars()` |
| **Redundancy-confirmation check** | 修正后 gap vs 原始 gap，哪个更近自报（静默恶化防护） | 双 gap + 自报 | 恶化候选表 | **AUTO_FIX 否决权** | 冗余信息一致性原理 | Channel B 逻辑 |
| **Cross-day stability screening** | 同 pid 相邻 day SOL/WASO 突变 | 时间序列 | 突变表 (>4× MAD) | AUDIT-only | 睡眠日间稳定性 | `cross_participant_*` |
| **Correction provenance audit** | 全部 correctionsmade/note → 已知机制映射 | note 列 | 覆盖表，未覆盖=盲区候选 | AUDIT-only | 可审计性 | `audit_m1_m7_notes_inventory` |
| **Post-correction verification** | 6-min 差异比对、reasonable-unusual 保护、终值派生 | 修正后全量 | 7 指标终值 + PASS/FLAG | FLAG (>6min) / PASS | CSD 派生定义 / ±6min 精度 | `verify_sleep_calculations()` |

**决策三态**: AUTO_FIX（可逆、有否决权）→ FLAG（人工队列）→ AUDIT-only（记录不动作）。
**关键论文句**: 规则全部确定性 —— 同输入必同输出（13/13 snapshot 验证），故 IRR/κ 不适用，可靠性由合成层 ground truth + 三方来源错误分类学承载。

---

## 2.4.x 子节结构（真实数据审计主体）

### 2.4.1 Timestamp Standardization
- 全部 `*_am` 列强制 `HH:MM` 字符 + 类型安全（hms/difftime→char 防静默秒/分钟错位）
- 分隔符归一（`.`/`;`→`:`）、`"H:MM"`/`"H"`→`"0H:MM"`/`"0H:00"`
- AM/PM 校正循环：PM 24h 表示 −12h；午夜边界变量（bed、sleep）专用处理（PM+12h→保留12→AM 修正）
- 工程安全层，无共识标准可锚 → 只 FLAG，不修
- **合成验证链接**: mmss_confusion 类 (recall 0.990)

### 2.4.2 Temporal Order Validation
- 仅 complete-case；两阶段：Stage 1 交叉日/AM/PM 误分类（相邻 ≥12h → 迭代 −12h）；Stage 2 微反转（<3h → 交换邻点）
- `correction_type` 全链审计
- AUTO_FIX 允许，**但须一致性∧冗余共证**（Golden combo）—— 防御静默恶化
- **合成验证链接**: 顺序违反错误类

### 2.4.3 Free-text Duration Parsing
- 三分支：标准 `dd:dd`（>10h+00→重解释为分钟）、无冒号（4位插冒号/3位→FLAG/2-1位=分钟）、畸形冒号（`d:d:dd`、`:0000`、`ddd:d`→模式重组）
- 时钟形态 → 永不自动修 → FLAG 人工（field_misentry 源头拦截）
- `_mincalc` / `_checkforerrors` / `_correctionsmade` 三列追踪
- **合成验证链接**: format_no_colon (0.11 盲区, 已闭环→1.0)、重解释类

### 2.4.4 Internal Consistency + Redundancy Confirmation（多信号融合）
- 自报偏差: 派生 SOL − 自报 SOL >60min → 可疑（仅审计）
- 逻辑窗口: mincalc SOL > bed→sleep 窗口 → 非法（真实 n=13,990 主发现 922 条）
- 冗余方向: 修正后 gap 更远离自报 → 静默恶化候选（真实数据挡下 139/140 候选交换 —— **安全阀**）
- 触发组合 Venn 诊断面板图（Figure 5 变体）

### 2.4.5 Cross-day Stability Screening
- 同 pid 相邻 day，SOL/WASO 突变 > 4× MAD（默认 `spike_multiplier=4`）→ FLAG
- AUDIT-only；真实数据 1 命中 (单一 participant-day 极端突变)

### 2.4.6 Correction Provenance Audit（盲区盘查）
- 全部 correctionsmade/note 类型提取 → 映射 interval_parse 已知机制
- 未覆盖 note = 盲区候选 → 注入器回填（闭环：sol_window recall 0.43→1.0）
- 真实数据 14,338 条 note 全映射 ✅

### 2.4.7 Post-correction Verification
- 发布仅限 FULL_CORRECT_PASS 记录
- 6-min 差异比对（派生区间 vs 自报时长）+ reasonable-unusual 保护（`is_unusual←FALSE` 防过滤，独立归档）
- 7 指标终值派生仅在此步后

### 2.4.8 Human Review Workflow（D7 正式并入，可直接扩写成段）

Records flagged by the automated rules were adjudicated in a collaborative
dual-review process in which two coders worked together on a shared review
sheet (one coder from the study team, one from the collaborating lab). Because
this was a joint, non-independent review, inter-rater reliability statistics
(Cohen's κ and Gwet's AC1) are not applicable: κ requires two independent
label sets, which this workflow never produced. We therefore report co-review
agreement rates instead — the proportion of records on which the two coders
agreed immediately versus the proportion requiring discussion to reach
consensus.

For the flagged-errors track (n = 75), 48 records (64.0%) were agreed on the
spot and 27 (36.0%) required discussion before consensus. For the atypical-
cases track (n = 37), 33 (89.2%) were agreed on the spot and 4 (10.8%)
required discussion. The higher immediate-agreement rate for atypical cases
than for error corrections is consistent with task difficulty: judging whether
a record is statistically atypical is more straightforward than deciding
exactly how to correct a malformed value.

These two tracks are independent components of the review workflow (each
carries its own agreement column) and are not additive. Note also that these
counts reflect the current pipeline version: the flagged-errors set grew from
n = 47 in the March 2026 pipeline to n = 75 as detection rules were
strengthened; the atypical-cases set has remained n = 37.

**落笔规则**：禁 "inter-rater reliability" 术语（即使加限定）；用
"collaborative/concurrent dual-review" 或 "co-review agreement rate"；两轨独立不求和
（75+37≠84）；报 task-difficulty 解读；数据源 `manual_error_corrections.csv`
（agreement_cd_mtb，08-08 n=75）+ `manual_unusual_corrections.csv`
（cd_mtb_Consenssus，07-14 n=37）。

---

## 2.3 合成基准 ↔ 规则族映射（Table 1 横排改法）

把 Table 1 从「16 错误类 × 指标」重组为「规则族 → 注入错误类 → recall/spec/FAR」：

```
Timestamp standardization → format 类 (no_colon, mmss, delimiter)
Temporal order validation → sequence 类 (order_violation, cross_day, ampm)
Free-text duration parsing → string-parse 类 (reinterpret, hundred_digits)
Internal consistency → deviation 类 (sol_deviation) + window 类 (sol_window)
Redundancy confirmation → redundancy 类 (channel_b 冲突)
Cross-day stability → cross-day 类 (cross_participant_spike: 0.907 ⚠)
Provenance audit → note 类 (unmapped_note)
Post-correction verification → verify 类 (post_correction_discrepancy)
```

卖点句: "每族规则都在合成层有对应注入错误类可测 → recall 即规则效度证据，弥补无外部 gold standard。"

---

## 已知口径（写稿时锁定）

| 项 | 值 | 来源 |
|----|----|------|
| pooled recall | **0.995** [0.993, 0.997] | ppv_cluster_ci 重跑确认 2026-08-20 (participant-level cluster bootstrap, B=2,000; per-category B=1,000) |
| specificity | 1.0 | 同上 |
| FAR | 0/1609 | far_flag_alter.csv |
| control: no_cleaning / naive_rule / pipeline | 0 / **0.623** / **0.995** | control_baselines.csv（0.640/0.987 为旧版，已废弃） |
| 真实审计 | 0 AUTO_FIX, 1048 FLAG, 922 window, 140 order, 1 redundancy, 1 cross-day | audit_m1_m7_decision.csv |
| 盲点已闭环 | sol_window recall 0.43→1.0; format_no_colon 0.11→1.0 | 闭环记录 |
| 弱势类 | cross_participant_spike 0.907 L1（L3=0 设计使然，AUDIT-only）; mmss 0.990 | limitations 必写 |
| Bland-Altman SOL | bias +1.6 min, LoA 半宽 75.4 min → SOL 阈值 ratio 1.59/0.80 INSIDE NOISE | threshold_validation.csv |
| Bland-Altman WASO | LoA 半宽 27.3 min → WASO 阈值 ratio 3.29 SAFE | 同上 |
| SOL flag 下游 | 纯描述性列（`cleaned_data$flag_severity`），零 AUTO_FIX 链路（已代码验证）| R/flag_standards.R |

**Bland-Altman 层决议**（2026-08-16，Maia README §1.4）：
- 定位 = **测量特性描述**，非阈值验证
- SOL INSIDE NOISE 是**设计合理性的证据**（为什么 SOL 必须走人工），不是缺陷
- 论文写：SOL flag = 描述性高值标注 → 人工 review，非自动化错误信号；WASO 3.3× 过噪声
- ±75min SOL 一致性带宽 = 感知偏差量化发现（README Fig 20/20B），Discussion 报带宽不报比值
- 禁用把 LoA 当 accuracy 的表述

**Q1–Q4 决议**（2026-08-16，Maia README §9）：
- **消融（5.6）**: swap-off recall 上升 = flag-only 口径假象（AUTO_FIX 不进 flag 队列，`l2_tier_leave_one_out.R:138`）→ 降级补充材料 + 脚注注明口径；主证据 = multiverse
- **cross_participant_spike**: 保持 AUDIT-only + 披露；L3=0 设计使然；阈值 **4× MAD**（`spike_multiplier=4`），骨架/README 已统一
- **seed 敏感性**: 跨 seed recall 0.993–0.995 稳定，弱族 0.886–0.907 摆动 → 正文报主 seed + 稳定性句
- **对照口径**: naive 0.623 / pipeline 0.995（0.987 废弃）

**Multiverse 主曲线（2026-08-17 最终决议，取代上文 D2=44% 表述）**：
- 全因子 9-spec（D1–D6 × 3 levels）降级为**附录**（`spec_curve_full.csv`）；主曲线 = **D1-only 3 specs**（跨 seed 交集稳健）。
- 理由: D2（swap threshold）**seed-fragile** — seed 20260817 下 D1+D2 存活，seed 20260915 下仅 D1 存活；D2 存活与否是抽样翻动，非稳健信号。主曲线取两 seed 交集 = D1 only。
- 结果（D1-only，val band = 跨 spec 极值）: mean TST 8.059 h [8.059, 8.072]，mean SOL 31.2 min [22.7, 58.1]，analyzable n 6,581 [6,327, 6,660]。
- 论文叙事: main result 永远引 D1-only；全因子表作附录供复现；D2 脆弱性在 Discussion 报为"threshold 选择对坡面结论稳健性"的发现。

---

## 8-步验证链映射（vignette validation-methodology 与规则族对接）

手稿 Methods 用独立于规则族（Table R1）的**验证链**叙事，每步一问、不同失效方式、彼此独立（非级联）:

```
Step 1  Clean-input specificity ── 10,000 error-free 记录, 期望零改动/零 flag (FCR)
Step 2  Injected-error benchmark ── 注入 25 类错误, pooled recall 0.995 [0.993, 0.997]
Step 3  Detection vs value-correctness ── L1 (检测) vs L3 (值正确) gap
Step 4  Controls ── no_cleaning 0 / naive_rule 0.623 / pipeline 0.995
Step 5  Redundant-channel validation ── 双重修正源比对, corrections 必须移动值
Step 5.5 Bland-Altman (3 analyses) ── SOL LoA 半宽 ±75.4 min (感知带宽, 非 accuracy)
Step 6  Report-only audit ── 真实数据: 0 AUTO_FIX, 1048 FLAG
Step 7  Human co-review agreement ── 64.0% (n=75) / 89.2% (n=37)
Step 8  Multiverse + downstream + seeds ── D1-only 主曲线 + seed 交集稳健性
```

**步骤 6 与规则族的关系**: 1048 FLAG 是 8 族规则的**逻辑一致性计数**（非 p 值、非假设检验）→ 见下方 FDR 段"哪里有 BH、哪里没有"。

---

## FDR/多重检验 — 已完成（2026-08-17，`validation/synthetic/fdr_analysis.R`）

**哪里有 BH、哪里没有（诚实声明，防审稿人反咬）**：
- **无 BH**: M1–M7 审计的 1048 FLAG = 逻辑一致性计数，非 p 值 → 无 H0 → 假多重校正。逐类 95% Wilson CI + 是否排除 pooled 率（CI 式二值陈述，不需要 BH）。
- **有 BH**: 14 错误类别各自的独立二项检验 vs **固定参考率 0.90**（每类是独立 H0 "rate ≥ 0.90"）。现实意义: 类别率显著低于目标 0.90 = 校验基准承诺的优先复现点。BH 控制 14 检验的 FDR。
- 基准 recall 用 participant-level cluster bootstrap CI（2,000 resamples），分布估计非单检验 p 值。

**BH 校正结果（`results/fdr_corrected.csv`，14 类，q<0.05 = 显著低于 0.90）**：

| 类别 | 率 | 95% CI | q (vs 0.90) |
|---|---|---|---|
| cross_participant_spike | 0.271 | [0.218, 0.331] | 8.0e-116 |
| adjacent_swap_time_awake_am_time_getup_am | 0.810 | [0.769, 0.845] | 2.9e-07 |
| ampm_swap | 0.845 | [0.806, 0.877] | 1.8e-03 |
| mmss_confusion | 0.883 | [0.847, 0.910] | 0.49 (NS) |
| 其余 10 类 | 0.94–1.00 | CI 含 1 或显著高于目标 | all NS |

**论文写法**: 头两条（swap-getup 0.81 / ampm_swap 0.845）是**规则有效但可改进的已知弱势类**（注入的相邻邻对交换与 AM/PM 误分类桶）；cross_participant_spike 0.271 是 **AUDIT-only 设计使然**（L1 检出、L3 刻意不动作），不是遗漏 — Discussion limitations 必写。mmss 0.883 q=0.49 不显著 → 不列弱势类。

---

## Pre-registration / confirmatory-exploratory 声明（BRM 投稿必补，全仓此前零匹配）

**推荐措辞（可整体贴入手稿开头 Registration 小节，需用户确认真实状态后再定稿）**:

> This pipeline and its validation plan were developed iteratively on the
> project's own data from the outset; the analysis reported here is therefore
> **exploratory** rather than confirmatory. No analysis plan was registered
> prospectively. We mitigate the known risks of unregistered exploratory
> work in three ways: (1) all evaluation numbers are computed by versioned,
> reproducible scripts (`validation/synthetic/`, committed to the public
> repository) that run end-to-end on synthetic data with fixed seeds;
> (2) the synthetic benchmark ground truth is a *self-consistent* standard
> (clean-input specificity + injected errors + redundant-source
> confirmation), explicitly not an external gold standard — see "what this
> ground truth is and is not"; (3) the multiverse main curve is the
> *intersection* across independent random seeds (D1-only), so sampling
> flips cannot be retro-selected as findings. Where the work is
> confirmatory (pre-specified rules carrying forward from the study's own
> protocol), we label it as such.

**落到论文的位置**: 引言尾/方法开头一段 + Methods 第一句 "All analyses are exploratory; no prospective registration (see Discussion for implications)." 若用户实际有 IRB 或分析计划预注册，则改写为确认式陈述。

---

## 必补（写作前，更新后仅剩 2 项）

1. **Bootstrap 理由**: 被试内相关 → participant-level cluster; n_boot 敏感性
2. **snapshot 13/13** 定义放 Reproducibility 段
3. **FDR** 已由上一节覆盖（分析 + 结果 + 论文写法已就绪）
---

## Study-scope statement: why plausible variability is FLAGged, not "corrected" (BRM 投稿必补，README/vignette/本文件均零命中)

**现状核实（2026-08-19）**: grep 遍 `README.md` / `vignettes/validation-methodology.Rmd`(-zh) /
本文件，"mood / affect / emotion / purpose / individual variability / over-correct"
类研究目的框架语言 **零命中**（唯一命中是 "reserved affect-layer columns"，只是列
schema 备注，不是研究目的陈述）。真实数据本身已带 mood/affect 列
(`pos_today_pm_even`, `negative_today_pm`, `activated_today_pm`,
`sleepy_today_pm`, `stress_today_pm`)，确认这是一项 sleep×affect EMA 研究；
`validation-design.md` 里也明确 sleep×affect 模型是 **Paper 2**，当前论文范围只是
清洗管线本身——但"为什么管线选择保守的 FLAG 而不是 auto-normalize 掉自报/时间戳
分歧"这个理由，目前完全没有写进任何手稿或 README。

**推荐措辞**（放 Discussion/Limitations 或新开一个 Scope 小节，可直接引用
922/188 的数字，与 §M4 的 FLAG 阈值设计段落呼应）:

> A design choice underlying this pipeline's conservative FLAG-over-AUTO_FIX
> posture deserves explicit statement: because these diaries were collected
> for a study of the association between sleep and same-day affect,
> between-person and within-person variability in reported sleep-onset
> latency is not noise to be minimized — it is the signal the parent study
> is designed to detect. The pipeline therefore does not attempt to bring
> self-reported SOL into agreement with the timestamp-derived window when
> both values are individually plausible; doing so would risk shrinking the
> genuine variability that later relates to affect. Of the 922 M4 window
> flags in the real dataset, our manual audit (n = 69 stratified sample)
> attributes ~65% to timestamp-completeness artifacts (no distinct
> sleep-onset timestamp entered) and ~29% to rounding-level disagreement
> between self-report and derived timestamps — both are candidates for
> correction or exclusion from the analytic sample. The remaining ~6-9%
> (n = 188 in the real dataset) are retained as genuine values requiring
> individual review. Corrections (13 of the 188) are limited to timestamp-
> level order/AM-PM fixes; plausible large SOL values are left untouched
> precisely because removing them would bias the sleep–affect associations
> the parent study exists to estimate.
>
> *Honesty note: of the 13 corrected rows, 9 proceeded without a standing
> human confirmation (they carry a correction_type but no manual-review
> record). These are timestamp-level swaps/12h reductions, not SOL-value
> edits, but the paper should state this rather than imply all corrections
> were human-verified. See §M4 audit (28 corrected records, Channel B:
> 1 worsened = the known pid-6490 boundary case).*

**短版（面向 README/GitHub 读者，非投稿正文）**:

> This pipeline treats plausible sleep-timing variability as signal, not
> noise, consistent with its intended use in sleep–affect association
> studies — it flags disagreements for human review rather than silently
> normalizing them toward internal consistency.

**放置建议**: (a) BRM 正文 Discussion/Limitations，就近引用 2.4.x FLAG 阈值设计；
(b) README intro 段或新开 "Design Philosophy" 小节放短版——README 是 CRAN/GitHub
公开文档，改动前需用户确认放哪一段，本次先不动 README，只在这里落一版可直接采用
的措辞。

**关联核实（同日）**: 对 188 条真 mismatch 做了"睡眠相关时间字段漏填、被自动补成
00:00"排查——用真实数据 `sber_ema_anon_20260227.csv`（按 pid+day+sol_raw 精确匹配
去重，187/188 唯一确认匹配）逐条检查 `time_bed_am_hhmm` / `time_sleep_am_hhmm` /
`time_awake_am_hhmm` / `time_getup_am_hhmm` 四个字段：**0/187 出现 00:00 或空白**。
这个假说不解释 188 里的任何一条——00:00/漏填的问题已经被更早一层的"window=0"
排除掉了（65% 那类），没有渗漏进这 188。唯一的副产物异常：pid 9129/day7，审计
CSV 里 `sol_raw="00:15"`，但真实数据字段显示 `15:00`（疑似小时/分钟位置颠倒的
录入异常，值得单独记一笔，不属于本次排查目标）。

## 必补（写作前，更新后仅剩 3 项）

1. **Bootstrap 理由**: 被试内相关 → participant-level cluster; n_boot 敏感性
2. **snapshot 13/13** 定义放 Reproducibility 段
3. **Study-scope 声明**（上方新增）: 需确认放 Discussion 还是新开 Scope 小节，
   README 短版需用户拍板放哪

---

# 必补三项 — 已补(2026-08-19)

## 补 1 — Bootstrap 理由 + n_boot 敏感性

### 🔴 补写过程中发现一个实现与描述不符的问题(必须先决定)

`validation/synthetic/ppv_cluster_ci.R` 的 `cluster_boot()` 注释写的是
"Resample pids WITH replacement",但实现是:

```r
idx <- sample(pids, length(pids), replace = TRUE)
sub <- df[df$pid %in% idx, ]          # <- %in% 是集合成员判断
```

`%in%` **不保留重复**:一个 pid 被抽中两次,它的行仍然只进入一次。所以每次重抽
实际得到的是"**约 63.3% 的被试各计一次**"的随机子集(实测平均 316.3/500 个 cluster),
这是 subsampling,不是有放回的 cluster bootstrap。

**用真实的 per-row 数据两种实现各跑 2000×5 seeds 复核**(脚本
`boot_n_sensitivity.py`,输入 `results/cluster_bootstrap_per_row.csv`):

| 实现 | pooled recall 95% CI |
|---|---|
| A 正确的 cluster bootstrap(按重数计) | [0.9932, 0.9970] |
| B 现有代码 `%in%` 语义 | **[0.9938, 0.9967]** |
| 仓库/README 已公布值 | **[0.9938, 0.9967]** |

B 与已公布值**逐位吻合** → 确认已公布 CI 来自 `%in%` 实现。点估计
0.995177 两者相同(不受影响);specificity = 1.0 方差为零,完全不受影响。

**影响**:区间偏窄约 21%(半宽 0.00145 → 0.00190)。结论方向不变,但**论文若写
"participant-level cluster bootstrap",描述与实现不符** —— BRM 是方法学期刊,
这正是审稿人会查的地方。

**同一 `%in%` 模式还出现在**:per-category recall CI 循环、`ppv_boot()`。

**两个出路(需拍板)**:
- (a) **修实现**(推荐):改成按重数取行,例如预先 `split(df, df$pid)` 后
  `do.call(rbind, splits[idx])`。代价:pooled CI 0.9938→0.9932 / 0.9967→0.9970,
  per-category CI 与 PPV band 一并微动,需重跑并更新 README/vignette 的引用数字。
  点估计与 specificity 不动,主结论不动。
- (b) 保留实现,把方法如实描述为 subsampling(每次重抽约 63% 的被试各计一次)。
  代价:非标准做法,仍需向审稿人解释为何不用标准 cluster bootstrap。

**建议 (a)** —— 一处代码修正换取"描述=实现",且移动的数字极小。

### ✅ 已采纳 (a),代码已修(2026-08-19)

`validation/synthetic/ppv_cluster_ci.R` 三处全部改为**保重数**的实现:预先
`split()` 成每被试 (sum, count),再用抽中的名字索引(R 对重复名索引会返回重复项),
既保重数又比 B 次重新 subset 数据框快得多。改动点:`cluster_boot()`(pooled)、
per-category CI 循环、`ppv_boot()`。原逻辑连同"为什么 `%in%` 是错的"写进了代码注释。

**⚠ 本环境无 R,未能执行验证。用户须本地重跑 `Rscript validation/synthetic/ppv_cluster_ci.R`。**
重跑后应得到(Python 独立复算,R 的 RNG 流不同,末位可能有出入):

| 量 | 旧(已公布) | **新(预期)** |
|---|---|---|
| pooled recall 点估计 | 0.9952 | **0.9952(不变)** |
| pooled recall 95% CI | [0.9938, 0.9967] | **[0.9932, 0.9970]** |
| 三位小数表述 | [0.994, 0.997] | **[0.993, 0.997]**(仅下界第三位动) |
| specificity | 1.0 [1.0, 1.0] | **完全不变**(每次重抽都是 1.0) |
| PPV 曲线与带 | 全 π = 1.0 | **完全不变**(specificity 恒 1 → PPV 恒 1,带宽 0) |

per-category recall CI(预期,B=1000):cross_participant_spike 0.9068
[0.8675, 0.9415]、mmss_confusion 0.9900 [0.9796, 0.9976],其余 12 类点估计 1.0
CI [1.0, 1.0]。完整表见 `expected_ci_after_bootstrap_fix.txt`。

**重跑后需同步的引用位置(8 处,全部是三位小数 [0.994, 0.997] → [0.993, 0.997])**:
`README.md` L810 / L868 / L1650 / L1700、
`vignettes/validation-methodology.Rmd` L48 / L106、
`vignettes/validation-methodology-zh.Rmd` L41 / L91。
另 `BRM_METHODS_DRAFT.md` L162 / L355 / L403 与本文件两处也要跟着改。

**注意**:upper bound 三位小数不动(0.997),只有 lower bound 0.994 → 0.993。

### n_boot 敏感性(已跑,可直接写进论文)

`boot_n_sensitivity.py`,n_boot ∈ {250, 500, 1000, 2000, 5000, 10000},
每档 5 个独立 RNG seed,记录两个 CI 端点跨 seed 的蒙特卡洛离散度:

| n_boot | mean lo | mean hi | lo 跨 seed 极差 | hi 跨 seed 极差 |
|---|---|---|---|---|
| 250 | 0.993203 | 0.996959 | 0.000481 | 0.000237 |
| 500 | 0.993197 | 0.997040 | 0.000306 | 0.000344 |
| 1000 | 0.993217 | 0.997036 | 0.000244 | 0.000042 |
| **2000（现用）** | **0.993235** | **0.997023** | **0.000238** | **0.000040** |
| 5000 | 0.993216 | 0.996972 | 0.000134 | 0.000137 |
| 10000 | 0.993198 | 0.996954 | 0.000102 | 0.000140 |

(此表用正确的按重数实现算,故与已公布值有上述系统差)

**结论**:端点在 n_boot ≥ 1000 后已稳定到小数点后第三位;n_boot = 2000 时跨 seed
极差 ≤ 2.4e-4,比区间半宽(约 1.9e-3)小一个数量级。**蒙特卡洛成分不是不确定性的
主要来源,被试间抽样才是。** 提高到 10000 只把极差再压到 1.0e-4,不改变任何结论。

### 推荐正文措辞(Statistical approach)

> Confidence intervals for recall and specificity were obtained by a
> participant-level cluster bootstrap: participants — not records — were
> resampled with replacement, because diary days are nested within participants
> and repeated days from the same person are not independent. Treating rows as
> independent would understate the uncertainty, since a participant who
> systematically mis-formats entries contributes many correlated observations.
> Intervals are percentile-based (2.5th and 97.5th) over B = 2,000 resamples.
> We verified that B is not a limiting factor: repeating the procedure under
> five independent random seeds at B ∈ {250, 500, 1,000, 2,000, 5,000, 10,000},
> the interval endpoints stabilize by B = 1,000, and at B = 2,000 vary across
> seeds by at most 2.4 × 10⁻⁴ — an order of magnitude below the interval
> half-width (1.9 × 10⁻³). The Monte-Carlo component is therefore negligible
> relative to between-participant sampling variability. Specificity was
> estimated on the constructed-clean control rows, where the observed value is
> 1.0 with zero variance across all resamples; the accompanying rule-of-three
> upper bound (0.186%, from 0/1,609) is reported so that a point estimate of
> zero is not read as a proof of zero.

---

## 补 2 — "snapshot 13/13" 定义(放 Reproducibility 段)

**13 是什么**:`verify_v1_3_snapshot.R` 断言的检查总数,用于证明 v1.3.0 引入的 S3
封装层与其取代的 v1.2.0 脚本式管线在同一份合成数据上产出**逐位一致**的结果。

逐项拆解(实读脚本得出,2 + 2 + 1 + 8 = 13):

| # | 组 | 检查 |
|---|---|---|
| 1 | 维度 | 行数相同 |
| 2 | 维度 | 列数相同 |
| 3 | 列名 | 无仅旧管线独有的列 |
| 4 | 列名 | 无仅 S3 链独有的列 |
| 5 | 值 | **全部共有列逐值相同**(汇总为 1 项:`n_identical == n_compared`) |
| 6–13 | 关键派生量点检 | `self_diffcalc_sol_minutes`、`self_diffcalc_sleepefficiency_percent`、`self_diffcalc_totalsleeptime_minutes`、`self_diffcalc_timeinbed_minutes`、`sleep_efficiency_pct`、`sol_h`、`waso_h`、`sleep_duration_h` 各 1 项 |

第 5 项是实质门槛(覆盖所有共有列);6–13 是对最终会进入分析的派生指标的冗余点检 ——
即使某个中间列的比较逻辑出错,这 8 项也会独立捕获。

**它被用作什么**:任何触碰清洗逻辑的重构的**放行闸**。5.4a 参数提取重构
(把 3 小时交换阈值与 cross-participant 常量移进 YAML)正是以 13/13 逐位一致
作为"零行为变化"的证据通过的。

### 推荐正文措辞(Reproducibility)

> Refactoring that touches cleaning logic is gated on a snapshot test. The
> package retains the pre-refactor script-based implementation alongside the
> current S3 chain and runs both over the same bundled synthetic dataset,
> asserting thirteen checks: identical row and column counts, no column present
> in only one implementation, value-level identity across every shared column,
> and eight redundant spot checks on the derived sleep metrics that enter
> downstream analysis (SOL, sleep efficiency, total sleep time, time in bed, and
> their unit variants). A refactor is accepted only at 13/13. This is how the
> configuration refactor — which moved previously hard-coded thresholds into a
> YAML file to enable the specification-curve analysis — was demonstrated to be
> behaviour-preserving rather than merely believed to be.

---

## 补 3 — Study-scope 声明落位

**决定**:放 **Discussion 开头的独立小段**(不新开 Scope 小节,不放 Methods)。

理由:(1) 它解释的是**为什么阈值这样定**,读者要先看过 2.4 的 FLAG 规则才能理解;
(2) 放 Methods 会读成"研究目的",而本文的研究对象是管线不是睡眠—情绪关联,
容易让审稿人误以为本文要报关联结果;(3) 放 Discussion 开头可以自然引出
limitations(MM:SS 阈值盲区、188 条人工队列),形成"设计取向 → 已知代价"的顺承。

正文措辞见本文件上方 "Study-scope statement" 小节(已写好,直接采用)。
README 短版待用户决定是否放、放哪里 —— 本次不动 README。

---

## 必补清单 — 全部关闭

1. ~~Bootstrap 理由 + n_boot 敏感性~~ ✅ 已补(附带发现 `%in%` 实现问题,待拍板 a/b)
2. ~~snapshot 13/13 定义~~ ✅ 已补(13 项逐条拆解 + Reproducibility 措辞)
3. ~~Study-scope 声明落位~~ ✅ 已定(Discussion 开头独立小段)

**新增待办(由补 1 引出)**:~~`ppv_cluster_ci.R` cluster bootstrap 实现修正~~ ✅ 代码已修
(3 处)。**剩余:用户本地重跑 + 同步 8 处三位小数引用**(见上表)。
