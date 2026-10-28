# BRM 预投稿评审记录 (2026-10-05)

来源：opencode 会话，以"第一次看到这个 repo、本身做 behavioral methods /
psychometrics / EMA / quantitative methods 的 BRM reviewer"视角审。
用途：投稿前 checklist，非最终正文。关联：`BRM_STYLE_NOTES_2026-10-01.md`。

总判断一句话：**工程成熟度够，方法学效度不够。现在投 BRM 会被拒。核心问题：验证是自证的，不是独立的。**

---

# A. 精炼预审意见

## A1. 致命问题（不改必拒）

1. **循环验证**。合成基准的 ground truth = 你自己注入的错误。等于测"管线能否检出自己设计的错误类别"。BRM 审稿人第一条就问 external validity。论文自己承认 "no external gold standard exists"。必须补：至少一个**带独立人工金标准**的真实数据集（第三方标注者定 label），报真 precision/recall。

2. **头条数字误导**。`recall 0.995` 是 **detection/flag recall**，不是 correction-correct recall。看 per-category 表：`adjacent_swap_time_sleep_am_time_awake_am` 400 detected / **0 correctly detected**，`implausible_duration` 400/0，`sol_window_contradiction` 355/0。真实"改对率"远低于 0.995。BRM 一眼看穿。→ 把 **correction-level recall 作主指标**，detection 只作辅助，README/paper 的第一数字换成它。

3. **阈值 sweep 全平**（1–5h 全 recall 0.995、FAR 0）。说明合成基准**无法区分阈值**。那"validated operating points (3h/12h)"没有任何证据支撑，selection rule 沦为任意。→ 要么设计能区分阈值的基准，要么老实说阈值来自领域惯例而非本验证。

4. **人工环节太弱**。co-review agreement 64%（n=75），且因"协作式共享工作表"拒绝报 κ。BRM 要独立编码者 + κ/ICC。64% 本身偏低。→ 找独立标注者，重跑，报 κ。

5. **已知缺陷被埋**。`cross_participant_spike` misrepair 0.093、value-correct 0。这是真实弱点，藏在 "honest caveats"。→ 提到正文，给缓解方案或明确限定适用范围。

6. **事实/版本不一致**（审稿人红灯）：
   - `DESCRIPTION` 1.4.9 / `paper.md` 1.4.7 / README 1.4.8。**[已修 2026-10-05：三处现均为 1.4.9，见 D]**
   - 数据来自 Stanford Psychophysiology Lab，但作者单位 Yonsei + Columbia。机构归属、IRB、data use agreement 必须写清。
   - README 承认 v1.4.0 有 96% silent-misrepair bug。这本身是好故事（基准抓到了 bug），但现在表述像自我辩白，反而暴露前期验证不稳。→ 改成"验证发现了真实缺陷并修复"的正面叙述。

7. **可用性未达 BRM 要求**：未上 CRAN、无 Zenodo DOI（有 `.zenodo.json` 没发）。BRM 要 permanent availability。

## A2. 方法论补强

- **对比现有工具**：`pointblank`/`validate`/`dataMaid`、R 里的睡眠评分包、手洗基线、naive rule（现在只有 0.623 一个）。定量表。
- **外部效度**：Baigutanova 数据集只是 feasibility（无 ground truth）。明确写"不是精度验证"——已经在 paper 里写了，好——但 BRM 会要一个真金标准。
- **可用性研究**：非作者研究者跑一遍，测 time-to-clean、agreement、有没有漏逃错误。这是 BRM 软件论文的加分项。
- 自造术语（L1/L3、SPEC、FCR、M4/M1/M5）**开头统一定义**，别散落。
- "convergence-guaranteed review cycle" 是断言，没证。→ 给证明或删。

## A3. 论文定位（战略）

- **`paper.md` 是 JOSS 格式**（Summary / Statement of need）。BRM 结构不同（Intro / Related work / Method / Validation study / Results / Discussion / Availability）。**二选一，别两头下注**。
- 更优路线：工具发 **JOSS**（拿 DOI、低成本），再用一篇 BRM 实证论文证明**下游影响**——清洗 choice 如何改变 sleep–affect 关联估计。BRM 更吃这个。"D2 = 46% variation" 已经是很好的引子。
- README 语气过度营销（emoji、满屏 bold、"9-step"、"publication-quality"）。BRM 审稿人反感。→ 降调为中性事实。
- repo 有 `.opencode/skill`、`opencode.jsonc`、根目录 3 个 ad-hoc `verify_*.R`、30+ 图。显得像 AI 生成的产品仓。→ paper 只引冻结 tag；~~`verify_*.R` 移进 `tests/` 或删~~ **[撤回 2026-10-05：CI 直接调用这三个脚本（`R-CMD-check.yaml` 71-73 行），不能移动或删除，见 D]**。

## A4. 发布清单

- Zenodo release + DOI + 更新 `CITATION.cff`。
- 冻结论文版本 tag，对应 `renv.lock`。
- Codecov badge 是 orange，给实际覆盖率数字。
- CRAN 提交（或明确说明为何不投）。

## A5. 真正卖点（别被淹没）

human-in-the-loop + **per-record correction provenance ledger** + **fail-loud column guessing**。BRM 喜欢可复现工作流。把这三样做成论文主线，砍掉 30 张图的噪音。

优先级：先做 #1/#2/#3（外部金标准 + correction-level recall + 阈值区分），过审门槛；#4 第二轮审稿意见；其余整洁度。

---

# B. BRM reviewer 全景评审（长版）

## B1. 十维评分

| Reviewer 维度         |                         判断 |
| ------------------- | -----------------------------: |
| 软件工程规范              |                     **8.5/10** |
| 可复现性                |                       **9/10** |
| documentation       |                     **8.5/10** |
| testing             |                       **9/10** |
| auditability        |                       **9.5/10** |
| 方法学严谨性              |                       **8/10** |
| external validity   |                     **6.5/10** |
| generalizability    |                       **6/10** |
| BRM paper readiness |                     **7.5/10** |
| 最危险的问题              | **"是不是只适用于你们这个 sleep study？"** |

repo 最大短板不是代码质量，而是"怎么证明这个方法值得成为 methods paper"。

BRM 近期专门发表自身 computational reproducibility 研究（DOI 10.3758/s13428-024-02501-5），发现很多论文虽给 GitHub/code/data，第三方用时仍遇 documentation / dependency / 可运行性 / 理解门槛问题，强调 clear documentation + low technical entry point + maintained/reusable resources。本 repo 恰好在解决这些。

结论：不要再加代码功能。把最后 20% 精力砸在**"证明它不是一个漂亮的 lab-specific pipeline"**。

## B2. 第一印象 / 方法学哲学

- pipeline 概览 + human-in-the-loop 定位对 BRM 胃口。
- 没包装成 "AI automatically cleans"，而强调**机器发现候选问题，人决定是否真错**，决策留在 audit trail。flag 不被静默清除。→ 这是核心 methodological contribution 之一。
- 真正卖点不是 308 tests，而是 **"如何避免 cleaning algorithm 改变真实心理信号？"** 例：Bedtime 23:00 / Sleep onset 01:30 / SOL 150min，纯数据工程师会 fix，behavioral researcher 会说"这人真的可能躺 2.5h"。
- 值得写进 Introduction/Methods 的哲学：**data cleaning ≠ making data look plausible**。

## B3. reviewer 会马上问："How do you know your algorithm is correct?"

recall = .995 不能证明规则"正确"，只证明在你设计的 injected-error benchmark 里找得到你注入的错误。Reviewer: **"What about errors you did not think of?"** → 需要 independent external datasets，不是 500 tests → 700 tests。

## B4. External validation = Major Revision #1

已有 two public diary datasets + adaptation scripts，是好基础。但要从"we also ran it on two public datasets"升级成真正的 external validation experiment：

```
Dataset A → same sleepcleanr → no threshold tuning → performance/flags/corrections
Dataset B → same sleepcleanr → no threshold tuning → performance/flags/corrections
```

关键句（对 reviewer 心理冲击大）：**"No dataset-specific threshold tuning was performed."**

理想做 leave-one-dataset-out：Dataset1 建规则 / Dataset2 external validation / Dataset3 second external。两个 external 已很好。paper 明确 development data vs validation data，别混说 "we validated across datasets"。

## B5. Thresholds 攻击点

README 已写"thresholds are references, not gospel"，好。但 reviewer 仍问 Why 3h / Why 12h / Why not 2h/4h。必须形成表：

| Rule | Threshold | Rationale | Development data | External validation |
|---|---|---|---|---|
| adjacent timestamp swap | 3 h | ... | Dataset X | Dataset Y |
| AM/PM inversion | 12 h | ... | X | Y |
| duration plausibility | ... | ... | X | Y |

## B6. "accuracy" 定义要小心

synthetic errors ≠ real-world errors。现实可能是 23:17 / 23:71 / 2:30 PM / 00:45，或 participant intended one thing 却 entered another。Reviewer 会要求：clarify what constitutes ground truth and how error injection represents naturally occurring diary errors。

validation 拆四层讲清楚：

```
Tier 1  Synthetic known errors        → 能否检出已知错误？
Tier 2  Real-world redundant info     → 修正是否提升与独立/冗余信号一致性？
Tier 3  External datasets             → 能否泛化？
Tier 4  Human reviewer agreement      → 独立人是否同意分类？
```

repo 实际已在往这个结构走，paper 要讲得极清楚。

## B7. human-review component 升级

64–89% agreement 有意思。但 reviewer 会问 "What exactly is agreement?"：agreement on error presence / error type / correction？Cohen's κ / raw agreement / weighted κ？Methods 人会盯。若只是 percentage agreement，别硬包装成 reliability coefficient，老实写 raw agreement，数据允许就补 Cohen's κ / Krippendorff's α。

## B8. 增一个小但杀伤力大的实验：naive cleaning vs sleepcleanr

现有 no cleaning=0 / naive rule=0.623 / sleepcleanr=0.995，有价值但只是数字。做成正式 benchmark：

```
Method 1 No cleaning
Method 2 Naive automated rules
Method 3 sleepcleanr
```
比 error detection / false correction / silent misrepair / metric distortion / sensitivity / specificity。

重点 **metric distortion**：最终用户要的是 valid TST/SOL/WASO/SE，不是 "clean data"。做：
```
raw → naive cleaning → sleep metrics
vs
raw → sleepcleanr   → sleep metrics
```
看各清洗策略改变指标多少。这直接把 paper 从"这里有个 R package"提升成"**不同清洗策略会实质改变 behavioural sleep 估计，我们提供 minimize unjustified corrections 的透明框架**"。很 BRM。

## B9. scope 定位

package 明确 sleep diary / EMA，没问题。别卖 "a comprehensive sleep diary cleaning tool"，卖：**a reproducible framework for transparent quality control and human-audited correction of longitudinal sleep-diary data**。真方法学贡献 = transparent + auditable + human-in-the-loop + reproducible；TST/SOL/WASO/SE 只是功能。

## B10. 少加功能

已太多：R package / YAML / schema / synthetic fixtures / validation / external datasets / vignettes / tests / CI / renv / citation / Zenodo metadata / changelog / 双语文档 / audit ledger / 诊断图。再加 figure 31/32、helper、auto-rule、wrapper → reviewer 不会更 impressed，甚至说 "over-engineered"。进入 **freeze feature development → validation + paper mode**。

## B11. README 问题

首页 information overload，数字烟花（1,048 records / 0 silent misrepairs / 0 AUTO_FIX / 9-step / 0.995 recall / 92% improved / 308 tests / 30+ figures）。第一屏压成三个核心 claim：

1. **What is it?** Reproducible R pipeline for cleaning longitudinal sleep diary data.
2. **What is novel?** Human-in-the-loop correction with an auditable correction ledger.
3. **What evidence supports it?** Synthetic benchmark + real-data audit + external datasets + reproducible test suite.

建议 README 结构：
```
# sleepcleanr
One-sentence definition.
[badges]
## Why sleep diary cleaning is difficult
## What sleepcleanr does            (diagram)
## What makes it different          1. Human-in-the-loop 2. No silent corrections 3. Full audit trail 4. Configurable thresholds 5. Reproducible validation
## Validation                       (TABLE: Synthetic / Real-world / External 1 / External 2 / Human review)
## Quick start
## Output
## Documentation
## Citation
## Limitations
```
**必须加 Limitations**：thresholds require study-specific validation / not intended to infer participant intent / cannot recover unobserved information / some corrections require human review / developed initially for intensive longitudinal sleep diary data / not a substitute for study-specific QC。reviewer 会觉得你知道自己在做什么。

## B12. 10 分钟第三方运行测试

找一个完全没参与项目的人：clone → install → run example → 理解 output → run external dataset → reproduce one validation number。记录 time to first successful run / time to understand output / time to reproduce benchmark / errors。可写进 paper："A new user was able to reproduce the demonstration pipeline without developer assistance."

## B13. 不要让 "Stanford" 成为主要卖点

Stanford 是 provenance，不是 validation。叙事链：developed in a real longitudinal study → abstracted into a general package → tested on synthetic + real + external datasets。

## B14. 模拟 review report

**Strengths**
1. addresses a practically important but under-standardized problem in intensive longitudinal sleep research.
2. human-in-the-loop design methodologically well motivated.
3. explicit audit trail / non-destructive correction architecture strong.
4. extensive testing and synthetic validation.
5. well documented, designed with reproducibility in mind.

**Major concerns**
1. generalizability of cleaning rules beyond development dataset.
2. rationale and empirical basis for predefined thresholds.
3. synthetic benchmark may overestimate performance on naturally occurring errors.
4. human-review agreement should be defined more precisely.
5. quantify how alternative cleaning strategies affect downstream sleep metrics.
6. distinction between software engineering quality and methodological validity made explicit.

不是 reject 型，是典型的 "I see a publishable methods contribution here. Now prove it."

## B15. 优先级

- 🔴 P0 必做：**External dataset validation** + 明确 no threshold tuning / no rule modification。
- 🔴 P0 必写：**validation 设计成四层**（Synthetic → Real-world redundant → External → Human agreement）。
- 🟠 P1 强推：**Naive cleaning vs sleepcleanr**，重点 metric distortion / silent misrepair。
- 🟠 P1 强推：**Threshold rationale table**，别让 3h/12h 像"作者觉得差不多"。
- 🟡 P2 最后：**README 减肥**——从"我做了很多东西"变成"我解决了一个明确的方法学问题，证据链完整"。

## B16. 最终定位判断

不必因它是 software 就改投 JOSS。若 external validation + downstream metric impact + methodological framing 做扎实，BRM 是合理目标。BRM scope 本就是 experimental psychology 的 methods/techniques/computational tools，且对 research assets 要求越来越偏"别人能否拿走、合理时间内复现和继续使用"。本 repo 已明显高于普通 GitHub research repo。

差的就是 **validation design + paper framing** 一道门：从"一个非常认真、完整的 sleep cleaning package"推到"一个有明确 methodological claim、并用 independent evidence 证明这个 claim 的 behavioral-methods paper"。

参考：
- BRM scope: https://www.psychonomic.org/page/brm
- BRM computational reproducibility: https://doi.org/10.3758/s13428-024-02501-5
- repo: https://github.com/cyracaid/sleepdiary-cleaner

---

# C. 第三轮外部建议评估 (2026-10-05)

四份外部建议：① 隐藏资产清单；② 投稿动作清单；③ finetuneR 教程"偷师"；
④ de Leeuw 拒稿案例 + Hussain 争议。下面只记**合成判断**，不照录。

## C0. 投稿形态决策 —— Regular Article（Original Manuscript）

**结论：投 BRM 走 Regular Article，不投 Tutorial Special Collection。**

理由：
1. 核心资产是**方法学证据**（silent-misrepair 发现、metric distortion "不洗差 ~86 min"、
   redundant-channel 设计、correction-level recall 0.49 vs detection 1.0），
   属"提出并验证一个框架"，非"分步指南"。Tutorial 骨架会浪费这些证据。
2. **JOSS 已占软件/how-to 位**（等 6 个月公开史）。若 BRM 也写成 Tutorial（工具指南），
   两篇高度重复：JOSS 需声明相关 BRM 工作且不得再带新结果。分工应为
   **JOSS = 软件，BRM = 方法** → BRM 应是方法论文。
3. 验证密度（9 步链 + 外部数据 + sweep）匹配 Original Manuscript，超出 Tutorial 期望。
4. Tutorial 是 special collection（有 call/截止）；Regular 常年开放。BRM 周期 8–11 个月。

**补偿**：Original Manuscript 里加一段**完整案例走查**（一条被 flag 的记录 →
检测 → 工作表 → 人工决策 → 记录），拿回 Tutorial 的可读性。

**反向条件**：若要"快 + 促采用"且愿把验证压成点缀 → 可走 Tutorial；但与 JOSS 分工冲突，不推荐。

## C1. 事实核对（仓库实测，纠正建议中的错误）

| 建议说 | 实际 |
|---|---|
| "1.4.5 是 CRAN resubmission，可能 pending" | `cran-comments.md` = **first submission**；NEWS 已删 CRAN claim。**当前不在 CRAN** |
| "已有 .zenodo.json 和 DOI placeholder" | `.zenodo.json` 在，但**无任何 DOI 字段/placeholder**。DOI 完全没 mint |
| "让审稿人 `source("validation/run_all.R")`" | **该文件不存在**。目前散落 `.R`，无一键入口 |
| "仓库里没有论文手稿（阻塞项）" | 部分对：repo 只有 JOSS `paper.md`；**BRM 方法正文已存在**于 `splsleep_paper/10_methods_BRM/`（未入库） |
| "把 Baigutanova 外部验证当强证据" | 仓库自述：该运行 **0 错误/0 修正**，**无法区分"没错"与"漏检"**，只能标 feasibility |

## C2. 新增可执行项 N1–N9（前两轮未列）

- **N1** 把"**可审计清洗管线**"命名为方法学贡献（不是功能）。README/论文开头立为设计原则。
- **N2** external validation 提到 Results **独立一层**（受 C1 caveat 限定，标 feasibility）。
- **N3** redundant-channel 验证立为**可发表设计模式**（不依赖外部 ground truth）。仓库已有 80/81。
- **N4** "检测而非修正"补**睡眠 EMA 文献定位**。
- **N5** 建 `validation/run_all.R` **一键复现入口**（审稿人约 20 分钟试用）。
- **N6** **TOP Level 2 可复现性附录**：无私有数据可重跑的数字（合成/外部）+ 命令 + 预期输出；
  不可重跑的（n=13,990 真实数据）明确列出。
- **N7** **工程一致性小节**（借 de Leeuw 拒稿教训）：引 1.3.0 **bit-identical 280×95**、
  1.3.3 脚本副本同步、1.4.3 `sleep_awake_swap_3h` guard、1.4.7 跨平台/时区修复。
- **N8** **比较性论断降调**（借 Hussain 争议）：用 B1 correction-level recall + B2 metric
  distortion **主动示弱**，不做"A 优于 B"的强断言。
- **N9** **CRAN 透明说明 + co-maintainer 计划**。

## C3. 与暂缓项的冲突（要决策）

- 建议把**阈值 sweep 做核心图** = B4（暂缓）。⚠️ `operating_point_sweep.csv` 20 点
  **全平**（recall 0.9949–0.9957，far 0）→ 只能证"**对阈值不敏感**"，**不能**证
  "3h/12h **有效**"。照建议直接当"阈值有效性"证据 → 会被 Hussain 式批评打。**必须改口径**。
- 建议把**外部验证提为核心** = B3（暂缓，需 Figshare 数据）。

## C4. 合并优先级 P0–P2

- **P0（过审门槛）**：
  1. BRM 手稿（Tutorial 骨架 → Regular Article 骨架，基于现有底稿，不从头写）。
  2. `validation/run_all.R` + TOP L2 附录（N5/N6）。
- **P1（手稿级）**：N1/N3/N4 叙事与文献定位；N2 external validation 独立 Results 层；
  N7 工程一致性小节；N8 比较性论断降调。
- **P2（发布/合规）**：Zenodo release + DOI；Declarations（Ethics/Consent/Data/Code/COI）；
  N9 CRAN 透明说明。
- **仍暂缓**：B3（需下 Figshare 数据）、B4（需重设计 + 改口径）。

## C5. 待拍板问题

1. 投稿形态：Regular Article（C0 建议）已确认？→ 待用户最终确认。
2. 手稿写在哪：`splsleep_paper/`（副本区）继续，还是规范化后移进 repo？（repo 不能进私有数据）
3. B3/B4 是否解锁：建议至少做 **B4 重写口径版**（"阈值不敏感"而非"阈值有效"）。
4. Zenodo：现在 release 拿 DOI？需确认仓库/账号联通。
5. P0-2（`run_all.R` + L2 附录）先做？纯仓库工作，无数据风险。

---

# D. 状态对账 (2026-10-05 执行后)

不改写 A/B/C 的原判断，只在此标出后来发生了什么。A/B/C 里仅修了三处硬错误
（A3 的 `verify_*.R`、A1.6 的版本、B1 的错字），并在原处标注。

图例：✅ 完成　🔧 改了口径　❌ 撤回　⏸ 未做/暂缓　❓ 未核实

| 条目 | 当时的判断 | 现状 |
|---|---|---|
| A1.2 detection vs correction recall | 头条 0.995 误导 | ✅ 已量化：correction-level recall **0.486**，50.9% 只 flag 不修，0.5% 误修（`validation/synthetic/results/correction_level_recall.csv`）；README 已改口径。✅ 两张表**来自同一次运行**（5,391 条注入、1,609 条对照），已对齐：0.995 = 被 flag 或改对 5,365/5,391；L1=1.0 = 管线动过的全部行（含 26 条误修）。旧文里的 4,736/4,745 是更早的基准构成，已在 README、paper.md、README_results 更正 |
| A1.3 阈值扫描全平 | 不能证明 3h/12h 有效 | 🔧 NEWS 已更正：只说明"对阈值不敏感"，不再写 validated operating point |
| A1.4 κ / 独立标注者 | 需要 | ⏸ 未做。VALIDATION_REPORT 仍是 co-review agreement 64.0%（n=75） |
| A1.5 cross_participant_spike 弱点 | 提到正文 | ⏸ 已在 `validation/README.md` 与验证 vignette 说明，**论文正文未写** |
| A1.6 版本不一致 | 1.4.9/1.4.7/1.4.8 | ✅ DESCRIPTION、README、CITATION.cff、paper.md 现均 1.4.9。⏸ **机构归属/IRB/data use agreement 仍未写清**，PI 同意点名未得 |
| A1.7 / A4 Zenodo + DOI | 没有 | ✅ 已发布：概念 DOI **10.5281/zenodo.23077702**，v1.4.9 版本 DOI 10.5281/zenodo.23077703；已写入 `CITATION.cff`、`inst/CITATION`、README。⚠ 本节 C1 写的"DOI 完全没 mint"是指仓库文件当时没有，Zenodo 上其实已有 |
| A3 `verify_*.R` ad-hoc → 移走/删 | 移走 | ❌ **撤回**：CI 直接调用（`R-CMD-check.yaml` 71-73 行） |
| A3 paper.md 是 JOSS 格式 → "二选一" | 二选一 | 🔧 被 C0 取代：paper.md 是 JOSS 线（但 JOSS 要求仓库公开满 6 个月，最早约 2027-01-15，且要有研究影响），BRM 另写方法稿 |
| A4 Codecov | orange，给数字 | ❓ 他处报 79.06%，我未能核实 |
| A5 / B11 README 去营销 + Limitations | | ✅ 已做；另外 README "Real study data: 0 automatic fixes" 一句**不实**（那是只读审计的数），已改为真实修正数（规则 93 行、审阅人另 75 行；待复查队列 226 / 307） |
| A8 convergence-guaranteed | 给证明或删 | ✅ paper.md 已无此说法 |
| A10 esmtools | 收窄 | ✅ paper.md 已收窄；`BRM_INTRO_DISCUSSION_OUTLINE_DRAFT.md` 里只写到"通用 ESM 预处理框架存在、我们解决更窄问题"，**esmtools 论文本身没读** ❓ |
| B8 naive vs sleepcleanr metric distortion | 做 | ✅ `metric_distortion.csv`：不清洗 TST −86 分钟、SOL +191 分钟；用管线后 TST +11、**SOL 仍 +47.6 分钟**（67.9 vs 干净 20.3）。⏸ 论文须如实写残余偏差 |
| redundant-channel 数字 | 81/88 (92%) | 🔧 现为 **80/81 (98.8%)**（`validation/redundant_channel_check.R`）；旧数是规则加守卫前的 8 月分析 |
| B3 external validation | 暂缓 | ⏸ 仍是 feasibility（KAIST、Manchester 均无已知错误） |
| B4 阈值设计 | 暂缓 | ⏸ 重设计未做；口径已改（见 A1.3） |
| N5 `validation/run_all.R` | P0 | ✅ 已写并实测：在临时副本里按种子重生成 9 张合成表，与已提交结果逐表比较，**9/9 逐位一致**（sleepcleanr 1.4.9）。⏸ 较长的脚本（multiverse、l2_tier、seed_sensitivity、operating_point_sweep、evaluate_fcr）未纳入、未重跑 |
| N9 CRAN | 透明说明 | ⏸ 不在 CRAN。`R CMD check --as-cran` 0 error / 0 warning / 2 NOTE（New submission；代码里写 `.GlobalEnv` 的 `assign`）；LICENSE 为 GitHub 识别保留完整 MIT 文本，CRAN 会要两行 stub |

## C5 五个问题的当前状态

1. 投稿形态 Regular Article：⏸ 用户尚未明确确认（主线定 BRM，形态未定）。
2. 手稿位置：🔧 已在 `~/Documents/splsleep_paper/` 建编号文件夹（复制，未删原件），含 `10_methods_BRM/current/`；未入库。
3. B3/B4：B4 口径版已做，B3 仍暂缓。
4. Zenodo：✅ 已完成（见上）。
5. `run_all.R` + L2 附录：⏸ 进行中。

## 新增、未在 A/B/C 里的发现

- 真实数据运行里规则自动修正 93 行（其中 10 行也被审阅人修过），审阅人另修 75 行；
  结果与"0 automatic fixes"相反，已更正。
- `[NEW]` 复查表新增的四列首次在真实数据上暴露出一个自己的匹配缺陷（人工文件里
  row_id 为空的行被误报为未处理），已修（v1.4.8）。

## D2. 2026-10-06 追加

- ✅ 真实错误率臂：`validation/synthetic/low_prevalence.R`（5% 注入：99.4% 被 flag 或改对、0 条干净行被 flag 或改动、每 1,000 行约 29.7 条待复查），已并入 `run_all.R`，**10/10 张表重生成逐位一致**
- ✅ 盲审工具：`validation/blind_audit/`（抽样、标注指南、κ 与漏检率估计），在合成数据上测试通过；⏸ **未在真实数据上运行，需要两位不参与写规则的标注者**
- ✅ 阈值口径写进 `THRESHOLDS.md`；`CONTRIBUTING.md` 说明 `verify_*.R` 由 CI 调用
- ⏸ 全局环境写入：已评估（`docs-dev/GLOBALENV_REFACTOR_ASSESSMENT.md`，13 个文件、14 处写、17 处读），建议单独分支、后续版本做，未改
- ⏸ 下游影响分析、第二个基线、机构/伦理声明：已写计划或带空白的草稿，等人和数据
