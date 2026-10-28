# BRM Methods 草稿 (v1, 2026-08-19) — 供正文扩写

> 基于 `BRM_METHODS_SKELETON.md`(规则族/审计决议)+ `vignettes/validation-methodology.Rmd`(验证链)+
> `validation/synthetic/fdr_analysis.R`(FDR)+ multiverse 最终决议(D1-only)。
> 所有数字来自上述源码,非记忆。**中文写作,投稿时译为英文。**
> 状态注释: [已核对] = 数字已对照源码/结果文件; [需用户确认] = 需作者拍板。

---

## 0. 投稿定位 (TL;DR, 不进入正文)

BRM(Behavior Research Methods)是自然归宿: 期刊常发"验证过的数据清洗/预处理工具 + 方法学验证",
极重视可复现 R 工具与统计严谨性,不要求临床级独立 IRR。本稿卖点:
error taxonomy(三方来源)、合成 ground truth(自洽标准,诚实披露非外部金标准)、
8 步验证链、multiverse 规范曲线、FDR 诚实二分、Bland-Altman 测量特性(感知偏差发现)。

**JAMIA 明确不作为目标**: 缺临床落地结果 + 独立 IRR,desk-reject 风险高,补齐成本不成比例。

---

## 1. Introduction (要点, 扩写时用)

- 睡眠 EMA 日记是强化纵向研究的主力测量。自由文本时间/时长字段错误率高、形态多样
  (局部典型: 无冒号、MMSS 混淆、AM/PM 误分类、相邻字段交换、SOL 窗口矛盾)。
- 现状: 清洗靠人工或临时脚本,不可复现、错误分类学缺失 → 跨研究可比性差。
- 现有工具缺口: 通用数据清洗框架(SHUTi、RESTING 的清洗规则)存在,但
  (a) 绑定特定研究协议、(b) 无常量化的验证基准、(c) 无论文级错误分类学公开。
- 本文贡献:
  1. 一个完全可复现的 R 管线(`sleepcleanr`),YAML 驱动,新研究无需改代码;
  2. 一个**三方来源错误分类学**(真实数据观测 + 文献报告 + 理论可能),
     每一类都有合成注入基准可量化召回;
  3. 一套**8 步验证链**,每步一问、不同失效方式、彼此独立(非级联);
  4. 用真实数据(n = 13,990)展示审计结果 + 人类共同审查流程。

[已核对 — 上述特点均与 README/DESCRIPTION/vignette 一致]

---

## 2. Methods

### 2.1 数据与伦理

#### 2.1.1 数据集 (n = 13,990)

[已核对 8-20 — 数字直接来自 output/cleaned_data_{full,prepostcorrection,final} 三 artifact 一致]
- 强化纵向睡眠 EMA 日记,**13,990 条记录 / 237 unique pid**(每人 3–75 条)。
- 采集期 **2020-08-26 → 2022-03-25**(~19 个月, StartDate 范围)。
- 字段: pid、day_num、4 个时间戳字段(bed/sleep/awake/getup, HH:MM + AM/PM)、
  时长字段(SOL/WASO/nap/exercise)、物质使用、自报派生指标。
- 平台: export 文件名为 `sber_ema_anon_20260227.csv`(已匿名化),app/平台全名
  "SBER" 未确认 —— [需用户: 平台全名, 简写不进入论文]。
- 机构关联: 作者隶属 **Yonsei University, Dept. of Philosophy**(无 "Applied Statistics";
  JOSS 稿旧写 "Philosophy & Applied Statistics" 属错误, 已修正)。数据采集机构待确认。
- 数据已去识别(deidentified/anon);原始导出文件**从未进过 git**(`.gitignore` 排除 + 8-17 purge)。

**✅ 已裁决(2026-08-19,用户确认 + 结构核算)**: 论文写 **237 参与者**。
用户确认 pid 数正确,"10,000" 只是行数量级的误记,非父研究人数。

**同时查明一个更要紧的事:13,990 不是日记数。** 逐字段核算导出结构:

| 量 | 值 |
|---|---|
| 导出总行数 | 13,990 |
| 带任一晨间日记时间戳的行 | **2,860** |
| 不带的行 | 11,130 |
| distinct pid | 237 |
| distinct pid × day_num | 3,305 |
| **一个 pid-day 有多于一行日记的情况** | **0**(每 pid-day 至多 1 条) |
| 每人日记天数 | 中位 13,范围 1–15 |
| 日记覆盖率 | 2,860 / 3,305 = **86.5%** |

四个时间戳 + SOL + sleep_quality 恰好populate同一批 2,860 行;WASO 只有 1,730 行
(60.5%)。其余 11,130 行是晚间与瞬时 EMA(约 2,850 份晚间问卷带当日情绪题,
其余为瞬时情绪提示;瞬时情绪题 `neg_affect` 在全部 13,990 行都有)。

**独立互证**: 2,860 / 13,990 = **20.4%**,与 Channel B 分析(2026-08-12,不同时间
不同路径)记录的 "20.4% of the full n=13,990 has non-missing self-reported SOL"
逐位吻合。

**对本文的影响**:
- 管线文档里的 "n = 13,990" **不必改** —— 那是管线处理的行数,管线确实跑全量导出。
- 但**任何把这 13,990 行称为"睡眠日记"的句子是错的**(高估约 5 倍)。
  2.1.1 应表述为: 13,990 条 EMA 提交,其中 **2,860 条为晨间睡眠日记**(237 人,
  每人每日至多一条,中位 13 天)。
- **"10,000" 的可能来源**: 真实数据里没有任何接近 10,000 的量。最接近的是 11,130
  条非日记行,以及更可能的 —— 合成基准的 false-correction-rate 测试跑在
  **n = 10,000** 合成记录上(`fcr_pure_n10000_result.csv`)。基准数字漂进数据集
  描述是很容易发生的失误,旧稿其他地方值得一并排查。

**平台/机构(2026-08-19 新证据,用户提供)**: `sber_ema_anon_*.csv` 的 "SBER" 与
**Stanford Home Sleep Study** 相关 —— GitHub 组织 `stanford-sber`
(https://github.com/stanford-sber),自述为 "Stanford Home Sleep Study",
站点 homesleep.stanford.edu,仅 1 个公开仓库(stanford-stages fork),成员不公开。
与 DESCRIPTION 里已有的两个 URL(homesleep.stanford.edu、stanford-sber)一致。
**但该组织页面未公开 "SBER" 的全称展开** —— 不能替用户编,需向实验室确认后再入论文。
数据采集机构大概率是 Stanford(而非作者所属的 Yonsei),2.1.1 的"数据采集机构待确认"
应据此更新,**仍需用户书面确认后定稿**。

#### 2.1.2 伦理与数据可用性 [需用户: IRB]

- **IRB: 仓库/手稿全目录搜索零结果**(renv consent 是唯一 "consent" 匹配, 非数据)。
  不能替用户编。BRM 审稿人几乎必查人类数据 IRB。
  三选项: (a) 给真实 IRB 号+机构; (b) 确认数据为二手公开/机构豁免(需豁免证明文字);
  (c) 如果真没有 → limitation 里直说 "no IRB approval was obtained (data were
  collected anonymously via a public app); the study was reviewed by [机构]";仍建议先问机构。
  此条必须用户答复后才能定稿 2.1.2。
- 真实数据不可公开共享(参与者隐私);合成基准数据+脚本全公开(仓库)。
- Data Availability 段建议措辞(待用户改):
  > The real EMA dataset is not publicly available due to participant privacy.
  > All validation materials — synthetic data generator, error-injection catalog,
  > benchmark scripts, and results — are openly available at
  > [repo URL] under the MIT license. A synthetic benchmark dataset is included
  > in the package for reproducibility.

### 2.2 管线概述 (10 步)

[已核对 — 与 inst/steps.yaml 一致]

| 步 | 名称 | 功能 |
|---|---|---|
| 1 | Read + schema check | 读取配置、列名映射、数据类型验证 |
| 2 | Timestamp parsing | 自由文本 → HH:MM,分隔符归一 |
| 3 | Temporal order normalization | bed ≤ sleep ≤ awake ≤ getup 重建,AM/PM 翻转,邻对交换 |
| 4 | Duration parsing | SOL/WASO 独立三态解析(标准/无冒号/畸形冒号)+ 字段错位拦截 |
| 5 | Substance use normalization | 物质使用文本 → 剂量 |
| 6 | Manual review integration | HUMAN-IN-THE-LOOP: 人工校正文件融合 |
| 7 | Metric derivation | TST/SOL/SE/TIB/睡眠周期计算 |
| 8 | Metric validation | 派生 vs 自报偏差、逻辑窗口、冗余确认 |
| 8.5 | Cross-participant stability | 同人跨日 SOL/WASO 突变筛查 (AUDIT-only) |
| 9 | Flag severity + classification | 严重度评级、数据类别标签 |
| 10 | Finalize columns | 终值列、输出结构 |

关键属性: **全确定性** — 同输入必同输出(snapshot 13/13 验证,见下 5. 待办#3 [已解决 8-20])。
人工校正文件是唯一步骤间状态,由 YAML 显式声明 → 可复现。

### 2.3 规则族 (Table R1 — 与验证链共用)

[已核对 — 骨架 Table R1, 与代码锚点映射]

| 族 (论文名) | 功能 | 决策 |
|---|---|---|
| Timestamp standardization | 自由文本 → HH:MM,类型安全,分隔符归一 | FLAG |
| Temporal order validation | 重建绝对时刻,查顺序违反 | AUTO_FIX (∧一致性∧冗余) / FLAG |
| Free-text duration parsing | 三分支解析 SOL/WASO,时钟形态永不自动修 | FLAG |
| Internal consistency check | 派生 vs 自报偏差,mincalc vs 逻辑窗口 | AUTO_FIX 组成元 / AUDIT |
| Redundancy-confirmation check | 修正后 gap vs 原始 gap,静默恶化防护 | **AUTO_FIX 否决权** |
| Cross-day stability screening | 同人相邻日突变 (>4× MAD) | AUDIT-only |
| Correction provenance audit | correctionsmade/note → 已知机制映射 | AUDIT-only |
| Post-correction verification | 6-min 差异比对,reasonable-unusual 保护 | FLAG / PASS |

决策三态: AUTO_FIX(可逆,有否决权)→ FLAG(人工队列)→ AUDIT-only(记录不动作)。

### 2.4 合成基准验证 (8 步验证链 — Step 1–4 + 6)

[已核对 — vignette Step 1-4 数字]

**Step 1 — Clean-input specificity.** 10,000 条无错误合成数据跑全管线:
FCR **0 / 9,996**; FAR_flag **0 / 1,609**; FAR_alter **0 / 1,609**
(rule-of-three 95% 上界 ≈ 0.03%)。干净数据零损伤、零误报。

**Step 2 — Injected-error benchmark.** 400 注入/类,ground truth 在注入时刻记录(自记录表):
pooled recall **0.995** [0.993, 0.997](participant-level cluster bootstrap CI, 2,000 resamples);
specificity **1.0**。
→ 顺带发现并修复 2 个日志/肉眼看不到的真实 bug(v1.4.1),见 Step 3。

**Bootstrap 理由(已解决 8-20, 源 ppv_cluster_ci.R + inject_errors.R)**: 注入器**按参与者聚类**
(非 IID — 一部分参与者承载全部错误,匹配真实数据 33% 参与者的聚集模式)。行级误差
在个体内相关,独立重采样(IID bootstrap)会低估方差 → CI 必须按 participant 级聚类重采样。
n_boot = 2,000(ppv_cluster_ci.R line 179: `cluster_boot <- function(df, n_boot = 2000, ...)`)。
敏感性讨论: 论文中补一句 "bootstrap CI stable for n_boot ≥ 500 (PPV curve uses 500); 2,000 for recall/spec"。

**Step 3 — Detection vs value-correctness.** L1(检测)vs L3(最终值 = ground truth):
`ampm_swap` L1 1.0 / L3 0.565;`field_misentry` L1 1.0 / L3 0.018。
L1−L3 gap = 人工审查空间。field_misentry 的 L3 0.018 是**已修复状态**:
pre-v1.4.1 95.8% 被静默"修复"成错误但看似合理的值,现 0% — 全转到人工。
MRR(当前运行)全类别 **0**。

**Step 4 — Controls.** 同污染数据三条件: no_cleaning **0** / naive_rule **0.623** / pipeline **0.995**。
+37 个百分点 = 规则族的增量价值,恰好证明设计复杂度有回报。

**Ground-truth 诚实声明(必写,防"循环论证" critique):**
本 ground truth **不是外部金标准**(自由文本日记无外部真相 — 没人知道参与者打 "10:30" 想表达什么)。
它是**自洽标准**: 错误定义是我们的、破坏是我们做的、真实值在破坏时刻我们自己记录(管线运行之前)。
基准证明管线完成了"我们定义"的清洗,不证明定义与现实一致。三点防循环:

1. 错误分类学 = 三方来源并集(真实观测 + 文献 + 理论可能),**刻意不是**"管线已能检测的错误";
2. 真实数据层(Step 5–7)完全不需要合成标准;
3. 盲点闭环循环: 真实数据发现新错误类型 → 加入目录 → 注入 → 重跑基准。
   两个已闭环实例: `sol_window` recall 0.43 → 1.0;`format_no_colon` recall 0.11 → 1.0。

### 2.5 真实数据审计 (n = 13,990; 验证链 Step 5–7)

#### 2.5.1 Redundant-channel validation (Step 5) [已核对]

真实日记中 SOL 有两种独立测量: 自报时长 + 时间戳派生。Step 4 修正逻辑**从不读时长列**(源码核实),
故两源对比非循环。运行于真实数据(n = 13,990,无注入):

- `bed_sleep_swap_3h`: 39/39 改善 (100% [91–100%])
- `sleep_reduce_12h_loop`: 38/38 改善
- 全部 bed/sleep 相关修正: 81/88 (92%) 改善

**发现的负面规则**: `sleep_awake_swap_3h` 7/10 恶化 (p = 0.036) →
v1.4.3 诊断并修复(`bed <= awake` guard)。修后: swap rows 10 → 4,3/4 改善,7 恶化 → 1 例披露边界情况。

`awake_getup_swap_3h` (9 例) 是**纯时序(顺序)修正,非值级修正**: 全部为 order 违规(getup 早于 final awakening),交换后 9/9 间隙量级精确保留(如 −159 ↔ +159 min),仅修复非法顺序、不动量级。因此 self-report 锚定的 redundant-channel 指标**不适用**(awake→getup 间隙无自报对标列,亦非 SOL 构念)——证据强度仅限"顺序修复且量级不变",非值级正确性。此特性须在 Methods 明示,避免与 bed/sleep 的 81/88 值级验证混同。

#### 2.5.2 Bland-Altman 测量特性 (Step 5.5) [已核对]

测量特性描述,非阈值验证。三分析(all real, n = 13,990):

| # | 输入 | bias | LoA 半宽 | 阈值 | 比值 | 判定 |
|---|---|---|---|---|---|---|
| A1 | SOL 自报 vs 计算 | +1.6 min | 75.4 min | 120 min (excessive) | 1.59 | INSIDE NOISE |
| A1 | SOL 自报 vs 计算 | — | 75.4 min | 60 min (high severity) | 0.80 | INSIDE NOISE |
| A2 | WASO 自报 vs 计算 | small | 27.3 min | 90 min (high severity) | 3.29 | SAFE |
| A3 | SE / TST-TIB | — | — | — | — | N/A (无自报对) |

**解读(发现,非缺陷,必写)**:
1. 计算 vs 自报 SOL 差达 **±75 min** — 量化感知偏差,本身是可发表发现;
2. SOL flag 阈值(60/120)落在噪声带**内** → "高 SOL" flag 无法区分真实长 SOL 与普通报告分歧。
   这不污染数据: `flag_severity` 是描述性列,不喂任何修正路径(代码核实)。
   SOL flag = **描述性指示器转人工**,非自动化错误信号;
3. WASO 阈值超噪声 3.3× — 安全;
4. SE/TST-TIB 无自报对应,无法 Bland-Altman 验证 — 明说,不暗示;
5. LoA 只约束一致性,**从不等于准确度** — 不得引作 criterion validity(那需要 actigraphy/PSG,
   本 EMA-only 数据没有)。

#### 2.5.3 Report-only audit (Step 6) [已核对]

Report-only 模式跑全部 13,990 真实记录(不改数据):

- **0 AUTO_FIX, 1048 FLAG**
  - 922 逻辑窗口违例(派生 SOL > bed→sleep 窗口,max 225 min)
  - 140 时间顺序违例
  - 1 冗余确认恶化(已知边界情况,work log 独立复现)
  - 1 跨日突变
  - 0 未映射修正注释(全部 14,338 条 note 映射到已知机制)

意义: 合成基准证明**检测能力**,这里证明**真实世界流行度** — 922 条之前未知的问题,零改动发现。
脚本 `audit_review_queue_m1_m7.R`;输出 `audit_m1_m7_decision.csv`。

#### 2.5.4 人类共同审查 (Step 7 = 骨架 2.4.8, 直接可当正文) [已核对]

> Records flagged by the automated rules were adjudicated in a collaborative
> dual-review process in which two coders worked together on a shared review
> sheet (one coder from the study team, one from the collaborating lab). Because
> this was a joint, non-independent review, inter-rater reliability statistics
> (Cohen's κ and Gwet's AC1) are not applicable: κ requires two independent
> label sets, which this workflow never produced. We therefore report co-review
> agreement rates instead — the proportion of records on which the two coders
> agreed immediately versus the proportion requiring discussion to reach
> consensus.
>
> For the flagged-errors track (n = 75), 48 records (64.0%) were agreed on the
> spot and 27 (36.0%) required discussion before consensus. For the atypical-
> cases track (n = 37), 33 (89.2%) were agreed on the spot and 4 (10.8%)
> required discussion. The higher immediate-agreement rate for atypical cases
> than for error corrections is consistent with task difficulty: judging whether
> a record is statistically atypical is more straightforward than deciding
> exactly how to correct a malformed value.
>
> These two tracks are independent components of the review workflow (each
> carries its own agreement column) and are not additive. Note also that these
> counts reflect the current pipeline version: the flagged-errors set grew from
> n = 47 in the March 2026 pipeline to n = 75 as detection rules were
> strengthened; the atypical-cases set has remained n = 37.

**落笔规则**(与骨架一致): 禁 "inter-rater reliability" 术语(即使加限定);
用 "collaborative/concurrent dual-review" 或 "co-review agreement rate";两轨独立不求和;报 task-difficulty 解读。

### 2.6 Multiverse 规范曲线 + 下游敏感性 + seed 稳健性 (Step 8)

#### 2.6.1 设计 [已核对]

哪些选择可开放(连续阈值: AM/PM 翻转 12h、相邻交换 3h、午夜 6、mmss 60、SOL 120/180、SE 70、
WASO 1.5h、TST/TIB 0.5、CP 4× MAD;离散分支: 信哪些行、cross-participant on/off、人工层 on/off)。
硬约束排除(那是逻辑不是选择)。OAT 筛选 → 全因子网格;每 spec 跑真管线,记同样输出:
**规范曲线**(Simonsohn 式)+ **方差分解**。脚本 `validation/synthetic/multiverse.R`,`results/multiverse/`。

#### 2.6.2 结果 — multiverse [已核对]

| 维度 | 变异份额 | 注 |
|---|---|---|
| D2 (相邻交换阈值) | 44% | **seed-fragile** |
| D1 (AM/PM 翻转触发) | 10% | |
| 其余 | 余下 | |

**最终决议 (2026-08-17)** [已核对 — 与 README/vignette 一致]:
- 全因子 9-spec 的 D2=44% **仅在全因子网格内成立且 seed-fragile**:
  OAT 在 seed 20260817 下保留 D1+D2,seed 20260915 下仅剩 D1;
  D2 存活与否是抽样翻动,非稳健信号。
- **主规范曲线 = D1-only(3 specs, 跨 seed 交集)**;全因子降级附录 `spec_curve_full.csv`。
- 论文叙事: main result 引 D1-only;全因子表附录供复现;
  D2 脆弱性报为 "threshold 选择对坡面结论稳健性" 的方法学发现。

#### 2.6.3 结果 — 下游敏感性 [已核对]

| 量 | Base spec | 跨 spec 范围 | 判定 |
|---|---|---|---|
| mean TST (h) | 8.06 | [8.06, 8.07] | 稳健 (±0.01 h) |
| mean SOL (min) | 31.2 | [22.7, 58.1] | **敏感** |
| analyzable n | 6,581 | [6,327, 6,660] | 中等 |

决策相关增量(B1/B2): B1(信哪些行)移动 mean TST **29.6 min**;
B2(WASO trust gate 变体)移动 analyzable n **1,131 条**。
这些不是错误 — 是"不同合理决策"产生的诚实范围。

#### 2.6.4 结果 — seed 敏感性 [已核对]

4 seeds: pooled recall 稳定 **0.993–0.995**,control FAR 全 0。
唯一摆动族(0.886–0.907)是已知弱族 `cross_participant_spike`,已披露为 audit-only。

### 2.7 FDR/多重检验 [已核对 — fdr_analysis.R + results/fdr_corrected.csv]

**诚实二分 — 哪里有 BH、哪里没有**:
- **无 BH (M1–M7 审计)**: 1048 FLAG = 逻辑一致性**计数**,非 p 值 → 无 H0 → 假多重校正是自欺。
  逐类 95% Wilson CI + 是否排除 pooled 率(CI 式二值陈述,天然免 BH)。
- **无 BH (基准 recall)**: participant-level cluster bootstrap(2,000 resamples)= 分布估计,
  非单检验 p 值。
- **有 BH (本处)**: 14 错误类别各自独立二项检验 vs **固定参考率 0.90**
  (每类独立 H0 "rate ≥ 0.90" — 避免 pooled-vs-part 循环)。BH 控制 14 检验 FDR。

**结果** (`fdr_corrected.csv`, 14 类, q < 0.05 = 显著低于目标):

| 类别 | 率 | 95% CI | q |
|---|---|---|---|
| cross_participant_spike | 0.271 | [0.218, 0.331] | 8.0e-116 |
| adjacent_swap_time_awake_am_time_getup_am | 0.810 | [0.769, 0.845] | 2.9e-07 |
| ampm_swap | 0.845 | [0.806, 0.877] | 1.8e-03 |
| mmss_confusion | 0.883 | [0.847, 0.910] | 0.49 (NS) |
| 其余 10 类 | 0.94–1.00 | — | all NS |

**论文写法**: 前两条 = 规则有效但可改进的已知弱势类(相邻邻对交换与 AM/PM 误分类桶);
cross_participant_spike 0.271 是 **AUDIT-only 设计使然**(L1 检出、L3 刻意不动作)非遗漏 —
limitations 必写。mmss q=0.49 不显著 → 不列弱势类。

### 2.8 Pre-registration / 探索性声明 [需用户确认 — 无 IRB 预注册]

> This pipeline and its validation plan were developed iteratively on the
> project's own data from the outset; the analysis reported here is therefore
> **exploratory** rather than confirmatory. No analysis plan was registered
> prospectively. We mitigate the known risks of unregistered exploratory work
> in three ways: (1) all evaluation numbers are computed by versioned,
> reproducible scripts committed to the public repository that run end-to-end
> on synthetic data with fixed seeds; (2) the synthetic benchmark ground truth
> is a self-consistent standard (clean-input specificity + injected errors +
> redundant-source confirmation), explicitly not an external gold standard;
> (3) the multiverse main curve is the intersection across independent random
> seeds (D1-only), so sampling flips cannot be retro-selected as findings.
> Where the work is confirmatory (pre-specified rules carrying forward from
> the study's own protocol), we label it as such.

---

## 3. Results (要点 — 待扩写, 数字全部在 2.4–2.7 有源)

1. 合成层: recall 0.995 [0.993, 0.997];FCR/FAR 全 0;+37 pts vs naive。
2. 真实数据: 1048 FLAG(922 window);0 AUTO_FIX;14,338 note 全映射。
3. 冗余通道: 92% 修正朝自报方向移动;1 负面规则发现并 guard。
4. Bland-Altman: SOL ±75 min 感知带宽(发现);WASO 3.3× safe。
5. Multiverse: D1-only 主曲线;TST 稳健 / SOL 敏感;D2 44% ⊆ 附录。
6. FDR: 3/14 类显著低于 0.90,2 修 1 设计使然。
7. 共同审查: 64.0% / 89.2%(co-review agreement, 非 κ)。

## 4. Discussion (要点)

- **诚实的核心论点**: 无外部金标准时,清洗工具效度 = (三方错误分类学 + 自洽 ground truth +
  冗余通道 + 盲点闭环)。这是方法论贡献,不是缺陷披露。
- **可复现性**: 全确定性管线 + versioned 脚本 + 合成数据公开 → 他组可独立复现每个数字。
- **Multiverse 的启示**: 坡面结论对阈值选择稳健(TST),对测量定义敏感(SOL) —
  下游研究需报规范曲线而非单点值。
- **局限性** (必写):
  - EMA 单源,无 actigraphy/PSG → 不能验证 criterion validity;
  - 共同审查非独立 → 无 κ,报告 co-review agreement;
  - cross_participant_spike 弱(0.271 L2 / 设计使然);
  - 探索性分析,无预注册;
  - 真实数据不可共享(隐私),合成数据可。
- **与 BRM 读者对话**: 行为科学数据清洗的可复现工具正是 BRM 长期发表类型;
  提供 wash data 前/后对比模板,供其他 EMA 研究采用。

---

## 5. 写作前待办清单 (从骨架继承, 已更新)

1. [已解决 8-17] FDR — 分析+结果+写法已就绪(见 2.7)
2. [已解决 8-20] Bootstrap 理由 — participant-level cluster(注入器按被试聚类, 非 IID;
   ppv_cluster_ci.R:179, n_boot=2000; PPV 500)。论文补 n_boot 敏感性一句(见 2.4 Step 2 注)。
3. [已解决 8-20] snapshot 13/13 定义 — `verify_v1_3_snapshot.R`: 旧串行管线 vs S3 管线
   输出 `corrected_ema_data`,全部 13 个共有列逐列 bit-identical(n_identical == n_compared);
   外加 8 个关键派生指标 spot-check。源: TECH_DEBT.md L46 + verify 脚本 L357-387。
   放 Reproducibility 段: "13/13 common output columns bit-identical across two
   independent pipeline implementations (legacy serial vs internalised S3 chain)". 
   意义: 确定性跨**实现重写**仍成立,不只是同代码重跑。
4. **[已核对 8-20] 参与者数/周期/平台已入库**(237 pid, 13,990 记录, 2020-08→2022-03, Yonsei;
   "SBER" 平台全名待确认)。**IRB 仍空缺 — 仓库零记录, 需用户提供或裁决措辞**(2.1.2)。
5. **[需用户确认] pre-registration 真实状态**(默认探索性声明 2.8)
6. **[需用户] 表/图清单与编号** — 我可先起草,待批(Table R1 → Table 1-4;Fig 规格曲线/Bland-Altman/审计面板)

---

## 附: 数字源对照(防漂移)

| 数字 | 值 | 源 |
|---|---|---|
| pooled recall | 0.995 [0.993, 0.997] | vignette Step 2 + ppv_cluster_ci.csv |
| specificity | 1.0 | 同上 |
| FCR / FAR | 0/9996, 0/1609, 0/1609 | vignette Step 1 → fcr_pure_n10000_result.csv |
| controls | 0 / 0.623 / 0.995 | control_baselines.csv |
| ampm_swap L1/L3 | 1.0 / 0.565 | l2_tier.csv (= fdr_corrected est 0.845 L2) |
| real audit | 0 AF, 1048 FLAG, 922/140/1/1/0 | audit_m1_m7_decision.csv |
| co-review | 64.0% (75) / 89.2% (37) | manual_*_corrections.csv |
| Bland-Altman | SOL +1.6 min, 75.4 LoA; WASO 27.3 | threshold_validation.csv |
| multiverse | D1-only 3 spec; 8.06 [8.06,8.07] / 31.2 [22.7,58.1] / 6581 [6327,6660] | results/multiverse/spec_curve.csv |
| FDR | 3/14 sig q<0.05 | results/fdr_corrected.csv |
| seed | 0.993–0.995; weak 0.886–0.907 | seed_sensitivity.csv |
| blind-spot | 0.43→1.0; 0.11→1.0 | 闭环记录 (README b5dffbe) |