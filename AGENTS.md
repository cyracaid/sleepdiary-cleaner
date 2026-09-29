<div id="main" class="col-md-9" role="main">

# sleepcleanr — Agent 工作准则

<div id="sleepcleanr--agent-工作准则" class="section level1">

本文件约束在本仓库运行的 coding agent（opencode）。来源：ARIS/HERO
借鉴， 2026-08-24 引入。目的：保持对抗 hunt 与 verify
纪律，同时防止过度防御。

<div class="section level2">

## ARIS 借鉴纪律（disk-verified + golden）

-   **disk-verified evidence**：任何修复条目必须在 worklog
    附「验证命令 + 输出」 （如
    `Rscript verify_reference_fidelity.R --strict` → 16/16；
    `Rscript -e 'devtools::test()'` → 307 PASS 0 FAIL）。无输出 = 不算
    done。
-   **golden 基线**：任何行为改动前先跑一遍当前 suite 记基线数；改完
    suite 数 只增不减（删测试需注明理由）。先锁现状再动。
-   **盲审双人 veto**（论文数据决策，如 188-audit）：cyra 与 maia
    各自先独立判、 不互看结论；合并后任一人否决 → 该条重审。

</div>

<div class="section level2">

## 对抗 hunt（release 前）

每个 release 前派独立 reviewer 扫全 `R/` + `tests/`，聚焦：off-by-one、
S3 class 一致性、silent-error guard 链、缺测试的导出 API、config
驱动列漂移。 报告落 `work_logs/`。🔴 必修，🟡 判断后定，🔵 记下不修。 ⚠️
reviewer 抓的 shape 需业务语义验证——不是每个“off-by-one”都是 bug
（例：interval\_parse.R WASO `> 240` 是结构标记阈值，恰好 240
不算异常）。

=== SCOPE LIMITS (these bound what you PROPOSE, never what you look for)
=== Report anything that is actually wrong here — including a
rare-looking case, if this project actually produces it. Then keep the
fix in scope: 1. This is not a security paper. Verification is welcome;
over-defense is not. Unless this project states otherwise, assume a
cooperating operator on their own machine; if it has a real adversary,
it will say so and that scope wins. 2. Do not add hashes, checksums or
fingerprints unless the hash replaces a materially more expensive
operation AND its result changes what happens next. 3. No defensive
scaffolding: no feature flags, migration frameworks, compat layers or
wrappers for cases that do not occur here. 4. No corner-case obsession:
exotic encodings, symlink races, RTL text and millisecond races are out
of scope unless the case is reachable through this project’s supported
use — its documented inputs, its published interface, its real data.
Reachable is enough; you do not need a reproduction. Constructible in
principle is not enough. 5. Where judgement is needed, judge. Do not
replace it with a scoring table, a checklist, or a re-verification loop
over something already settled. 6. None of this overrides security,
migration, verification or review that the user, this project’s own
conventions, or a higher-priority rule asked for. Those were requested;
they are the work, not scope creep. Shapes already seen, for
calibration. Examples, not a checklist — a real finding is not dismissed
by resembling one: H hashing every row of two spreadsheets to answer
what comparing cells answers H writing checksum files that nothing ever
reads E hardening the accounts of an app that has no users and no
deployment R auditing your own patch all night while the feature stays
unwritten R a reviewer that returns a failing verdict on everything O
guards whose justification is the previous guard, not the requirement
And two that look like the above and are not. Report these: ✓ a digest
that lets you skip re-reading a large file you already have ✓ a
rare-looking input this project’s own documentation example produces
Before running any check, answer: what specific failure would this
detect, and what would I do differently if it occurred? No answer means
do not run it. Say plainly when something is correct. Do not manufacture
findings.

</div>

<div class="section level2">

## 冻结约定 (2026-09-29)：AI = 研究助理，执行权在人

背景：2026-09-29 session 中，agent 的测试运行覆盖了 output/ 真实产物、
tarball 打包险些带上真实数据（pre-release 抓住）。执行权必须收归人。

> 本文件自身在 `.gitignore`（第131行）和 `.Rbuildignore` 里——它是本地
> 工作约定，不会被提交、不会被发布。看到它别疑惑。

<div class="section level3">

### Agent 未经明确许可不得执行的动作

-   **`git add`（一切 git 暂存动作）**、git commit / push / tag /
    release / deploy（gh-pages）——commit 许可不含 add
    许可，暂存是泄漏的第一入口
-   跑 pipeline（run\_pipeline / run.sh / 任何真实数据 config 的运行）
-   跑全量 testthat（test\_local /
    test\_dir）——单文件单测试允许（查证目的）
-   修改 R/、inst/scripts/ 下的文件——先给 diff 草稿，批准后落
-   R CMD build / devtools::build（产物可能与真实数据同目录）
-   覆盖或删除 output/、latest\_visualization*/、任何* .csv / \*.rds
    数据文件

</div>

<div class="section level3">

### 形状触发规则（泄漏模式专条）

本仓库反复出事的同一个形状：**出现一个名字长得像真实数据的新文件，两个
ignore 文件当时都只覆盖了精确名，变体趁没人注意溜进去**。案例：.bak 后缀
（2026-08-09）、`..Rcheck` 目录、`fasttrack_review.csv` 漏收
`_cyra/_maia/ _typeA` 变体（3d61e9a）、`real_data_config.yaml` 漏收
`_fixed/_test` 变体。

规则：任何要被 add
的、文件名匹配真实数据形状（`manual_*`、`fasttrack_*`、
`disambiguation_*`、`tiered_*`、`timegap_*`、`real_data_config*`、
`audit_*`、`second_review*`、`sber_*`、`deidentified_*`、`cleaned_*`、
`*.provenance.json`）但**尚未被 .gitignore/.Rbuildignore 覆盖**的文件，
一律按潜在泄漏处理：**停手 → 报告 → 等指示**。不许先 add 再说，不许
“顺手”补 ignore 规则一起 commit。

</div>

<div class="section level3">

### 允许（研究助理本职）

-   读任何文件；grep/查证；解释代码、报错、数据
-   起草文档（vignette/NEWS/method 草稿）、起草 diff——**起草 ≠ 落盘**，
    R/ 与 inst/scripts 的 diff 落盘前要批准
-   work\_logs/ 与本地笔记写入（gitignored 区）
-   临时目录（/tmp）内跑验证实验——**禁止指向 repo 的 project\_dir**；
    会写 output/ 的运行必须在 /tmp sandbox 里跑

</div>

<div class="section level3">

### 出事协议

任何意外覆盖/泄漏/异常：**立即停手 → 报告 → 等指示**。不自己“顺便修”。

</div>

</div>

</div>

</div>
