Subject: sleepcleanr weekly update + questions before JOSS

Hi Maia,

Worklog attached (2026-10-01_WORKLOG_EN.md). This week:

- v1.4.7 is out; v1.4.8 is pushed and waits for CI before release.
- Tests: 498 pass, 0 fail. Real-data run in a scratch copy completes; Corrected is still 85.
- Fixed figure layout problems; every missing figure now shows a reason.
- [NEW] review worksheets now show where each row was already handled, plus an end-of-run summary.
- KAIST and Manchester datasets run end to end (format check only; no known errors in either).
- Checked the release package and all pushed history: no participant data was ever pushed.
- README no longer says the package is on CRAN (it isn't).

I need your input on these, which block JOSS:

1. The package builds on 2023 lab scripts written by others. Who wrote them, does the lab have a rule on open-source release, and can we get the originals? I want to credit them and confirm the MIT licence is OK.
2. Is it OK to name the lab and James in the paper? I've left it blank.
3. Please check the AI-use statement in the worklog (DeepSeek and Claude; we made the design decisions and reviewed all changes).
4. Our first public commit is 15 July 2026, though work began in Sept 2025. JOSS wants ~6 months of public history. OK to explain in the cover letter?
5. 5 rows in the error worksheet are handled but still flagged after re-check. Can you look at them?

Nothing is submitted yet.

Thanks,
Cai
