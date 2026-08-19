# splsleep v2.0 — 可信清洗路线图

> 核心命题：**我的 cleaning 是可信的（trustworthy）**
>
> 要做到让人引用你的 package，两件事缺一不可：
> **代码稳定（tests）→ 结果可复现（CI）**
>
> *（原第三项「效果有证据（Bland-Altman）」已于 2026-07-28 撤回，见下表。）*

**当前进度（2026-08）：** 已发布 **v1.4.3**（main 最新）。Phase 1 完成（v1.4.0
交付门 + v1.4.1/v1.4.2 验证修复 + v1.4.3 守卫）；R CMD check 三平台（ubuntu /
Windows / macOS）CI 全绿；CRAN 卫生（--as-cran 非环境问题 0）；Phase 2（分析）
暂停待论文评审。下表 Phase 1 的 S3 泛型建议为旧架构愿景 —— 实际实现采用
`run_pipeline()` 包裹 + `inst/scripts/` 单副本架构（见 ARCHITECTURE.md），
"9 步 source()" 已由 10 步 pipeline + 回归测试网替代。

---

## Phase 1 — 可信清洗地基（历史，v1.4.x 已完成）

| 优先级 | 建议 | 工作量 | 为什么 |
|:--:|------|:--:|--------|
| ⭐ | **S3 泛型架构 + 管道链** | 3-5 天 | 整个 package 的地基。9 步独立 source() 变成统一契约（`data |> step1() |> step2() |> ...`），每步自带 `summary()` / `plot()` |
| ⭐ | **testthat + GitHub Actions CI + snapshot tests** | 2-3 天 | 改代码不怕引入 bug。核心 flag / correction 逻辑全覆盖，输出快照自动对比 |
| ~~⭐~~ | ~~**Bland-Altman 分析**~~ | — | **2026-07-28 撤回。** 阈值为人为设定且 `THRESHOLDS.md` 已记录出处，不需要 BA 背书；BA 仅作后续辅助手段，不进 Phase 1 |
| ⭐ | **统计异常标记（IQR / z-score）** | 1-2 天 | 替代部分硬阈值。透明、确定性、比 ML 更合适 |
| | **轻量缺失值处理（LOCF + 原因码）** | 1 天 | 标记"为什么缺"而非直接跳过 |

**Phase 1 总计 8-12 天**，完成后 pipeline 具备完整测试覆盖 + CI + 效果验证。

---

## Phase 2 — 分析能力扩展（以后）

| 事项 | 工作量 | 说明 |
|------|:--:|------|
| 昼夜节律分析（`circadian_analysis()` 独立函数） | 2-3 天 | 相位 + 振幅，消费清洗后数据，不混入管线 |
| 贝叶斯分层模型 vignette（brms） | 2-3 天 | Rmd 文档：清洗数据 → brms 模型 → 可发表图表 |
| `targets` 增量管线 | 3-5 天 | 避免重复跑全量，依赖感知缓存 |
| JSON Schema 配置校验 | 1 天 | 当 config 复杂度增长时启用 |

---

## 明确不做（及原因）

| 建议 | 原因 |
|------|------|
| KZ 自适应滤波 | 类别错误 —— 传感器平滑算法用在自报日记数据上 |
| Rcpp 重写时间解析 | 过早优化 —— 14K 行 lubridate 毫秒级，加 C++ 编译链是负担 |
| data.table 迁移 | 规模不到 —— dplyr 在 14K 行表现完美，换 data.table 降低可读性 |
| valgrind / sanitizer | 无 C 代码可检测 —— 纯 R package |
| Isolation Forest / DBSCAN | 黑箱替代透明规则 —— 破坏管线的可解释性和审计能力 |
| brms 内嵌管线 | 分析 ≠ 清洗 —— 作为独立 vignette 更好 |
| JSON Schema（Phase 1 做） | 目前 config 面太小，文档足够；Phase 2 再考虑 |

---

## 对应建议的辩论结论（2026-07-27 三 Agent 专业评审）

| # | 建议 | 结论 |
|---|------|:--:|
| 1 | Kolmogorov-Zurbenko 滤波 | ❌ SKIP |
| 2 | 昼夜节律分析（Lomb-Scargle / Cosinor） | 🔄 ADAPT（独立函数） |
| 3 | MICE / Kalman 缺失值插补 | 🔄 ADAPT（LOCF + 原因码） |
| 4 | Isolation Forest / DBSCAN | 🔄 ADAPT（IQR/z-score） |
| 5 | Rcpp 重写时间解析 | ❌ SKIP |
| 6 | S3 泛型 + 管道抽象 | ✅ ADOPT NOW |
| 7 | data.table | ❌ SKIP |
| 8 | JSON Schema + VSCode | ⏳ ADOPT LATER |
| 9 | 贝叶斯分层模型（brms） | 🔄 ADAPT（独立 vignette） |
| 10 | Bland-Altman 分析 | 🔄 ADAPT（Phase 1 独立函数） |
| 11 | valgrind / sanitizer | ❌ SKIP |
| 12 | 增量运行 | ⏳ ADOPT LATER（targets） |
| 13 | profvis 性能基准 | 🔄 ADAPT（snapshot 测试替代） |

---

> 更新：2026-08-19 | 历史技术方案（2026-07-27 评审）已随隐私清理从仓库移除，见本文件上文与 ARCHITECTURE.md
